# Copyright (C) 2023, 2026 MariaDB
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
# Goal: simple check that mysqlbinlog works on the produced logs
#################

package GenTest::Reporter::BinlogDump;

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
  my $log_bin= $reporter->server->serverVariable('log_bin');
  if ($log_bin eq '0' or $log_bin eq 'OFF') {
    sayWarning("BinlogDump: Binary logging is not enabled");
    return STATUS_OK;
  }
  my $mysql56_temporal_format= $reporter->server->serverVariable('mysql56_temporal_format');
  if ($mysql56_temporal_format eq '0' or $mysql56_temporal_format eq 'OFF') {
    sayWarning("BinlogDump: Due to MDEV-32929 mysqlbinlog does not work with mysql56_temporal_format=OFF");
    return STATUS_OK;
  }
  my $encrypt_binlog= $reporter->server->serverVariable('encrypt_binlog');
  if ($encrypt_binlog eq '1' or $encrypt_binlog eq 'ON') {
    sayWarning("BinlogDump: mysqlbinlog cannot read encrypted binary logs from the disk");
    return STATUS_OK;
  }
  my $status;
  my $vardir = $server->vardir;
  my $datadir = $server->datadir;
  my $port = $server->port;
  my $basename= $server->serverVariable('log_bin_basename');
  my $binlog_directory= $server->serverVariable('binlog_directory');

  my $binlog_utility= DBServer::MariaDB::_find(undef,
                       [$reporter->server->serverVariable('basedir')],
                       osWindows()?["client/Debug","client/RelWithDebInfo","client/Release","bin"]:["client","bin"],
                       osWindows()?("mariadb-binlog.exe","mysqlbinlog.exe"):("mariadb-binlog","mysqlbinlog")
  );

  unless ($binlog_utility) {
    sayError("BinlogDump: Could not find mariadb-binlog. Status will be set to ENVIRONMENT_FAILURE");
    return STATUS_ENVIRONMENT_FAILURE;
  }

  my $client = DBServer::MariaDB::_find(undef,
    [$reporter->server->serverVariable('basedir')],
    osWindows()?["client/Debug","client/RelWithDebInfo","client/Release","bin"]:["client","bin"],
    osWindows()?"mysql.exe":"mysql"
  );

  unless ($client) {
    sayError("BinlogDump: Could not find mysql client. Status will be set to ENVIRONMENT_FAILURE");
    return STATUS_ENVIRONMENT_FAILURE;
  }
  $client .= " -uroot --host=127.0.0.1 --port=$port --protocol=tcp";

  my $binlog_pattern = '';
  if ($basename) {
    $binlog_pattern = "$basename.[0-9][0-9][0-9][0-9][0-9][0-9]"
  } elsif ($binlog_directory) {
    $binlog_pattern = "$binlog_directory/binlog-[0-9][0-9][0-9][0-9][0-9][0-9].ibb"
  } else {
    $binlog_pattern = "binlog-[0-9][0-9][0-9][0-9][0-9][0-9].ibb"
  }
  unless ($binlog_pattern =~ /^\//) {
    $binlog_pattern = "$datadir/$binlog_pattern"
  }

  my @binlog_files = glob("$binlog_pattern");
  my $cmd= "$binlog_utility --no-defaults --verbose --verbose @binlog_files > $vardir/binlog_events.txt";
  say("BinlogDump: Dumping events from $binlog_pattern binary logs into the file $vardir/binlog_events.txt");
  say($cmd);
  $status = system("LD_LIBRARY_PATH=\$MSAN_LIBS:\$LD_LIBRARY_PATH $cmd");
  if ($status != STATUS_OK) {
    sayError("BinlogDump: Dumping binary logs finished with an error: ".($status >> 8));
    # Currently returns a rather bogus error ERROR: File is an empty pre-allocated binlog, contains no data yet
    return STATUS_CRITICAL_FAILURE;
  } else {
    say("BinlogDump: dumping binary logs finished successfully");
  }

  $status = $server->stopServer();
  if ($status != STATUS_OK) {
    sayError("BinlogDump: Shutdown failed. Status will be set to ".status2text($status));
    return $status;
  }

  my $tmpvardir = $vardir.'_'.time().'_tmp';
  move($vardir,$tmpvardir);

  say("Creating a clean database...");
  $server->createDatadir();

  move($tmpvardir,$vardir.'/vardir_orig');
  say("Starting a new server ...");
  $status = $server->startServer();

  if ($status > STATUS_OK) {
    sayError("BinlogDump: Server startup finished with an error");
    return $status;
  }
  # MDEV-31756 - NOWAIT in DDL makes binary logs difficult or impossible to replay
  system("cat $vardir/vardir_orig/binlog_events.txt | sed -e 's/NOWAIT//g' > $vardir/binlog_events_adjusted");

  # Cannot apply binlog events with transaction_read_only
  $reporter->connection->execute("SET GLOBAL tx_read_only= OFF");

  say("Feeding binary log events of the original server to the new one");
  # We need --force here because there can be events in the error log
  # written with error codes
  $status = system("$client --force --binary-mode < $vardir/binlog_events_adjusted") >> 8;
  if ($status > STATUS_OK) {
    sayError("BinlogDump: Feeding binary logs to the server finished with an error");
    return STATUS_RECOVERY_FAILURE;
  }
}

sub type {
  return REPORTER_TYPE_SUCCESS;
}


1;
