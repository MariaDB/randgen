# Copyright (C) 2025 MariaDB
# Use is subject to license terms.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
# USA

package GenTest::Reporter::PurgeBinaryLogs;

require Exporter;
@ISA = qw(GenTest::Reporter);

use Data::Dumper;

use strict;
use GenUtil;
use GenTest;
use Constants;
use GenTest::Reporter;

use DBServer::MariaDB;

my $first_reporter;

sub monitor {
  my $reporter = shift;
    status($reporter);
}

sub report {
  my $reporter = shift;
    status($reporter);
}

sub status {
  my $reporter = shift;

  alarm(3600);

  $first_reporter = $reporter if not defined $first_reporter;
  return STATUS_OK if $reporter ne $first_reporter;

  my $master = $reporter->properties->server_specific->{1}->{server};
  my $slave = $reporter->properties->server_specific->{2}->{server};
  my $slave_conn = $slave->connection;
  unless ($slave_conn) {
    sayError("PurgeBinaryLogs: reporter could not connect to the replica");
    return STATUS_SERVER_UNAVAILABLE;
  }

# We are using Relay_Master_Log_File and not Master_Log_File due to MDEV-4698
  my $logs = $slave_conn->get_columns_by_name('SHOW REPLICA STATUS');
  if ($slave_conn->err) {
    sayError("PurgeBinaryLogs: Got error trying to get Relay_Master_Log_File from slave status: ".$slave_conn->print_error);
    return STATUS_REPLICATION_FAILURE;
  }
  my $purge_limit;
  if ($logs && scalar(@$logs)) {
    $purge_limit = "TO '".$logs->[0]->{Relay_Master_Log_File}."'";

  } else {
    say('PurgeBinaryLogs: Slave status is empty, assuming no replication');
    $purge_limit = 'BEFORE NOW()';
  }
  my $master_conn = $reporter->connection;
  unless ($master_conn) {
    sayError("PurgeBinaryLogs: failed to connect to the primary");
    return STATUS_SERVER_UNAVAILABLE;
  }
  $logs = $master_conn->query("SHOW BINARY LOGS");
  say("PurgeBinaryLogs: Running flush and purging binary logs $purge_limit. Logs before flush and purge: " . Dumper $logs);
  $master_conn->execute('FLUSH BINARY LOGS');
  if ($master_conn->err) {
    if ($master_conn->err == 1205 || $master_conn->err == 1213) {
      sayWarning("FLUSH BINARY LOGS failed with ".$master_conn->err." which is apparently allowed");
      return STATUS_OK;
    } else {
      sayError("PurgeBinaryLogs: FLUSH BINARY LOGS failed: " . $master_conn->print_error);
      return STATUS_CRITICAL_FAILURE;
    }
  }
  $master_conn->execute("PURGE BINARY LOGS $purge_limit");
  if ($master_conn->err) {
    sayWarning("PurgeBinaryLogs: PURGE BINARY LOGS $purge_limit failed: " . $master_conn->print_error);
  }
  $logs = $master_conn->query("SHOW BINARY LOGS");
  say("PurgeBinaryLogs: Logs after flush and purge: " . Dumper $logs);
  return STATUS_OK;
}

sub type {
  return REPORTER_TYPE_PERIODIC;
}

1;
