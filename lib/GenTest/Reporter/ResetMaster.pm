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

package GenTest::Reporter::ResetMaster;

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
  my $master_conn = $master->connection;
  unless ($master_conn) {
    sayWarning("ResetMaster reporter could not connect to the primary");
    return STATUS_SERVER_UNAVAILABLE;
  }
  my $slave_conn = $slave->connection;
  unless ($slave_conn) {
    sayWarning("ResetMaster reporter could not connect to the replica");
    return STATUS_SERVER_UNAVAILABLE;
  }
  my $use_gtid = $slave->replicationUsesGtid();
  my ($file, $pos);
  $master_conn->execute('FLUSH TABLES WITH READ LOCK /* ResetMaster */');
  if ($master_conn->err) {
    sayError('ResetMaster: Failed to flush tables: '.$master_conn->print_error());
    return STATUS_RUNTIME_ERROR;
  }
  if ($use_gtid) {
    $pos = $master->getMasterGtidPos()
  } else {
    ($file, $pos) = $master->getMasterPos()
  }
  unless ($pos) {
    sayError('ResetMaster: Failed to get master position');
    return STATUS_REPLICATION_FAILURE;
  }
  $slave->syncWithMaster($file, $pos);
  $slave_conn->execute('STOP SLAVE /* ResetMaster */');
  if ($slave_conn->err) {
    sayError('ResetMaster: Failed to stop slave: '.$slave_conn->print_error());
    return STATUS_REPLICATION_FAILURE;
  }
  my $slave_status = $slave->getSlaveStatus();
  while ($slave_status->{Slave_IO_Running} ne 'No' or $slave_status->{Slave_SQL_Running} ne 'No') {
    say('ResetMaster: Waiting for the slave to stop');
    sleep 1;
    $slave_status = $slave->getSlaveStatus();
  }
  foreach my $f ('Last_SQL','Last_IO') {
    if ($slave_status->{$f.'_Errno'}) {
      sayError("${f}_Errno: ".$slave_status->{$f.'_Errno'}." (".$slave_status->{$f.'_Error'}.")");
      return STATUS_REPLICATION_FAILURE;
    }
  }
  $master_conn->execute('FLUSH BINARY LOGS /* ResetMaster */');
  if ($master_conn->err) {
    sayError('ResetMaster: Failed to flush binary logs: '.$master_conn->print_error());
    return STATUS_RUNTIME_ERROR;
  }
  $master_conn->execute('RESET MASTER /* ResetMaster */');
  if ($master_conn->err) {
    sayError('ResetMaster: Failed to reset master: '.$master_conn->print_error());
    return STATUS_RUNTIME_ERROR;
  }
  $slave_conn->execute('RESET SLAVE /* ResetMaster */');
  if ($slave_conn->err) {
    sayError('ResetMaster: Failed to reset slave: '.$slave_conn->print_error());
    return STATUS_RUNTIME_ERROR;
  }
  $slave_conn->execute("SET GLOBAL gtid_slave_pos='' /* ResetMaster */");
  if ($slave_conn->err) {
    sayError('ResetMaster: Failed to reset GTID position: '.$slave_conn->print_error());
    return STATUS_RUNTIME_ERROR;
  }
  $slave_conn->execute('START SLAVE /* ResetMaster */');
  if ($slave_conn->err) {
    sayError('ResetMaster: Failed to start slave: '.$slave_conn->print_error());
    return STATUS_REPLICATION_FAILURE;
  }
  $master_conn->execute('UNLOCK TABLES /* ResetMaster */');
  if ($master_conn->err) {
    sayError('ResetMaster: Failed to unlock tables: '.$master_conn->print_error());
    return STATUS_RUNTIME_ERROR;
  }
  return STATUS_OK;
}

sub type {
  return REPORTER_TYPE_PERIODIC;
}

1;
