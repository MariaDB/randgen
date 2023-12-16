# Copyright (C) 2023 MariaDB
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
  my $status;
  my $vardir = $server->vardir;
  my $datadir = $server->datadir;
  my $port = $server->port;
  my $basename= $server->serverVariable('log_bin_basename');

  my $binlog_utility= DBServer::MariaDB::_find(undef,
                       [$reporter->server->serverVariable('basedir')],
                       osWindows()?["client/Debug","client/RelWithDebInfo","client/Release","bin"]:["client","bin"],
                       osWindows()?("mariadb-binlog.exe","mysqlbinlog.exe"):("mariadb-binlog","mysqlbinlog")
  );

  unless ($binlog_utility) {
    sayError("BinlogDump: Could not find mariadb-binlog. Status will be set to ENVIRONMENT_FAILURE");
    return STATUS_ENVIRONMENT_FAILURE;
  }

  my $cmd= "$binlog_utility --no-defaults --verbose --verbose --base64-output=DECODE-ROWS $basename.0* > $vardir/binlog_events.txt";
  say("BinlogDump: Dumping binary log events into the file $vardir/binlog_events.txt");
  say($cmd);
  $status = system("LD_LIBRARY_PATH=\$MSAN_LIBS:\$LD_LIBRARY_PATH $cmd");
  if ($status != STATUS_OK) {
    sayError("BinlogDump: Dumping binary logs finished with an error: ".($status >> 8));
    return STATUS_CRITICAL_FAILURE;
  } else {
    say("BinlogDump: dumping binary logs finished successfully");
    return STATUS_OK;
  }
}

sub type {
  return REPORTER_TYPE_SUCCESS;
}


1;
