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

  my $logs = $slave_conn->get_columns_by_name('SHOW REPLICA STATUS', 'Master_Log_File');
  my $master_log;
  if ($logs && scalar(@$logs)) {
    $master_log = $logs->[0]->{Master_Log_File};
  }
  unless ($master_log) {
    sayError("PurgeBinaryLogs: failed to get the current master log from slave status");
    return STATUS_REPLICATION_FAILURE;
  }
  my $master_conn = $reporter->connection;
  unless ($master_conn) {
    sayError("PurgeBinaryLogs: failed to connect to the primary");
    return STATUS_SERVER_UNAVAILABLE;
  }
  $logs = $master_conn->query("SHOW BINARY LOGS");
  say("PurgeBinaryLogs: Running flush and purging binary logs to $master_log. Logs before flush and purge: " . Dumper $logs);
  $master_conn->execute('FLUSH BINARY LOGS');
  if ($master_conn->err) {
    sayError("FLUSH BINARY LOGS failed: " . $master_conn->print_error);
    return STATUS_CRITICAL_FAILURE;
  }
  $master_conn->execute("PURGE BINARY LOGS TO '$master_log'");
  if ($master_conn->err) {
    sayWarning("PURGE BINARY LOGS TO '$master_log' failed: " . $master_conn->print_error);
  }
  $logs = $master_conn->query("SHOW BINARY LOGS");
  say("PurgeBinaryLogs: Logs after flush and purge: " . Dumper $logs);
  return STATUS_OK;
}

sub type {
  return REPORTER_TYPE_PERIODIC;
}

1;
