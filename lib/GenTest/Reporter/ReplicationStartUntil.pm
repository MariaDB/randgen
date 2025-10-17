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

package GenTest::Reporter::ReplicationStartUntil;

require Exporter;
@ISA = qw(GenTest::Reporter);

use Data::Dumper;

use strict;
use GenUtil;
use GenTest;
use Constants;
use GenTest::Reporter;

use DBServer::MariaDB;

use constant SLAVE_STATUS_LAST_ERROR    => 19;
use constant SLAVE_STATUS_LAST_SQL_ERROR  => 35;
use constant SLAVE_STATUS_LAST_IO_ERROR    => 38;

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
    sayWarning("ReplicationStartUntil reporter could not connect to the replica");
    return STATUS_SERVER_UNAVAILABLE;
  }

  $slave_conn->execute("STOP SLAVE /* ReplicationStartUntil */");
  my $slave_status = $slave->getSlaveStatus();
  foreach my $f ('Last_SQL','Last_IO') {
    if ($slave_status->{$f.'_Errno'}) {
      sayError("${f}_Errno: ".$slave_status->{$f.'_Errno'}." (".$slave_status->{$f.'_Error'}.")");
      return STATUS_REPLICATION_FAILURE;
    }
  }
  my $gtid_pos = $master->getGtidPos();
  unless ($gtid_pos) {
    sayWarning("ReplicationStartUntil reporter could not get GTID position from primary");
    return STATUS_REPLICATION_FAILURE;
  }
  my $before_after = ('master_gtid_pos','SQL_BEFORE_GTIDS','SQL_AFTER_GTIDS')[$reporter->prng->uint16(0,2)];
  say("ReplicationStartUntil: Replica is currently at Gtid_IO_Pos ".$slave_status->{Gtid_IO_Pos}.", restarting with SLAVE UNTIL $before_after = '$gtid_pos'");
  $slave_conn->query("START SLAVE UNTIL $before_after = '$gtid_pos' /* ReplicationStartUntil */");
  return STATUS_OK;
}

sub type {
  return REPORTER_TYPE_PERIODIC;
}

1;
