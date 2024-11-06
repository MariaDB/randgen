# Copyright (C) 2013 Monty Program Ab
# Copyright (C) 2020, 2024 MariaDB
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


#################
# Goal: check that binary logs contents correctly reflects the server data.
#
# The reporter switches the server into read-only mode, takes a data dump,
# shuts down the server, starts a new clean one, feeds binary log from
# the first server to the new one, takes a data dump again,
# and compares two dumps.
#################

package GenTest::Reporter::BinlogConsistency;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use GenUtil;
use GenTest;
use Constants;
use GenTest::Reporter;
use File::Copy;

use DBServer::MariaDB;

my $first_reporter;

sub report {
  my $reporter = shift;

  $first_reporter = $reporter if not defined $first_reporter;
  return STATUS_OK if $reporter ne $first_reporter;

  my $server = $reporter->properties->server_specific->{1}->{server};
  my $secure_timestamp= $reporter->server->serverVariable('secure_timestamp');
  if ($secure_timestamp eq 'YES') {
    sayWarning("BinlogConsistency: Cannot run with secure_timestamp=YES");
    return STATUS_OK;
  }
  my $status;
  my $vardir = $server->vardir;
  my $datadir = $server->datadir;
  my $port = $server->port;

  my $client = DBServer::MariaDB::_find(undef,
    [$reporter->server->serverVariable('basedir')],
    osWindows()?["client/Debug","client/RelWithDebInfo","client/Release","bin"]:["client","bin"],
    osWindows()?"mysql.exe":"mysql"
  );

  unless ($client) {
    sayError("BinlogConsistency: Could not find mysql client. Status will be set to ENVIRONMENT_FAILURE");
    return STATUS_ENVIRONMENT_FAILURE;
  }

  $client .= " -uroot --host=127.0.0.1 --port=$port --protocol=tcp";


  my $binlog_utility= DBServer::MariaDB::_find(undef,
                       [$reporter->server->serverVariable('basedir')],
                       osWindows()?["client/Debug","client/RelWithDebInfo","client/Release","bin"]:["client","bin"],
                       osWindows()?"mysqlbinlog.exe":"mysqlbinlog");

  unless ($binlog_utility) {
    sayError("BinlogConsistency: Could not find mysqlbinlog. Status will be set to ENVIRONMENT_FAILURE");
    return STATUS_ENVIRONMENT_FAILURE;
  }

  my $conn = $reporter->connection;

  unless (defined $conn) {
    sayError("BinlogConsistency: Could not connect to the server, nothing to dump. Status will be set to ENVIRONMENT_FAILURE");
    return STATUS_ENVIRONMENT_FAILURE;
  }

  my $binlog = $conn->get_value("SHOW BINARY LOGS");
  $binlog=~ s/^([^\.]*)\..*/$1/;

  unless (-e "$vardir/data/$binlog.000001") {
    sayWarning("The first binary log not found, probably logs were purged, cannot check consistency");
    return STATUS_OK;
  }

  say("Dumping the original server...");
  $status = $reporter->dump_all($vardir."/original.dump");
  if ($status > STATUS_OK) {
    sayError("BinlogConsistency: mysqldump finished with an error");
    return $status;
  }

  $status = $server->stopServer();
  if ($status != STATUS_OK) {
    sayError("Shutdown failed. Status will be set to ENVIRONMENT_FAILURE");
    return STATUS_ENVIRONMENT_FAILURE;
  }

  my $tmpvardir = $vardir.'_'.time().'_tmp';
  move($vardir,$tmpvardir);

  say("Starting a new server ...");
  say("Creating a clean database...");
  $server->createDatadir();

  move($tmpvardir,$vardir.'/vardir_orig');
  my $status = $server->startServer();

  if ($status > STATUS_OK) {
    sayError("BinlogConsistency: Server startup finished with an error");
    return $status;
  }

  # MDEV-31756 - NOWAIT in DDL makes binary logs difficult or impossible to replay
  my $cmd= "$binlog_utility --no-defaults $vardir/vardir_orig/data/$binlog.[0-9][0-9][0-9][0-9][0-9][0-9] | sed -e 's/NOWAIT//g' > $vardir/vardir_orig/binlog_events";
  say("Dumping binary log events (with adjustments) into a file...");
  sayDebug($cmd);
  $status = system("LD_LIBRARY_PATH=\$MSAN_LIBS:\$LD_LIBRARY_PATH $cmd");
  if ($status != STATUS_OK) {
    sayError("BinlogConsistency: Dumping binary logs finished with an error: ".($status >> 8));
    return STATUS_CRITICAL_FAILURE;
  }

  # Cannot apply binlog events with transaction_read_only
  $reporter->connection->execute("SET GLOBAL tx_read_only= OFF");

  say("Feeding binary log events of the original server to the new one");
  # We need --force here because there can be events in the error log
  # written with error codes
  $status = system("$client --force --binary-mode < $vardir/vardir_orig/binlog_events") >> 8;
  if ($status > STATUS_OK) {
    sayError("BinlogConsistency: Feeding binary logs to the server finished with an error");
    return STATUS_RECOVERY_FAILURE;
  }

  say("Dumping the new server...");
  $status = $reporter->dump_all($vardir."/restored.dump");
  if ($status > STATUS_OK) {
    sayError("BinlogConsistency: mysqldump finished with an error");
    return $status;
  }

  say("Comparing SQL dumps between servers...");
  $status = system("diff -a -u $vardir/vardir_orig/original.dump.sorted $vardir/restored.dump.sorted") >> 8;

  unlink("$vardir/vardir_orig/original.dump.sorted");
  unlink("$vardir/restored.dump.sorted");

  if ($status == STATUS_OK) {
    say("No differences were found between servers.");
    return STATUS_OK;
  } else {
    sayError("Servers have diverged.");
    return STATUS_RECOVERY_FAILURE;
  }
}

sub dump_all {
  my ($reporter, $dumpfile) = @_;
  my $server = $reporter->properties->server_specific->{1}->{server};

  my @databases= $server->nonSystemDatabases();

  # no-create-info is needed because some table options don't survive server restart (e.g. AUTO_INCREMENT for InnoDB tables)
  # force is needed e.g. for views which reference invalid tables
  my $dump_result = $server->dumpdb(\@databases, $dumpfile);

  # We don't check "real" mysqldump exit code, because it might be bad due to view problems etc.,
  # but we still want to continue. But if sort fails, that's really bad because it must mean the file doesn't exist,
  # or something equally fatal.
  $dump_result = system("sort $dumpfile > $dumpfile.sorted");
  if ($dump_result > 0) {
    sayError("BinlogConsistency: dump returned error code $dump_result. Status will be set to ENVIRONMENT_FAILURE");
    return STATUS_ENVIRONMENT_FAILURE;
  }
}

sub type {
  return REPORTER_TYPE_SUCCESS;
}


1;
