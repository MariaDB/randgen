# Copyright (C) 2008-2009 Sun Microsystems, Inc. All rights reserved.
# Copyright (c) 2022, 2023 MariaDB
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

package GenTest::Reporter::ReplicationConnectionKiller;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use GenUtil;
use GenTest;
use GenTest::Reporter;
use Constants;

my $tcpkill_pid;

use constant KILL_DURATION => 5;

sub monitor {
  local $SIG{INT} = sub {
    kill(15, $tcpkill_pid) if defined $tcpkill_pid;
    exit(STATUS_OK);
  };

  my $reporter = shift;

  my $conn = $reporter->connection();

  return kill_binlog_dump_connections($conn) if osWindows();

  my $slave_host = $reporter->serverInfo('slave_host');
  my $master_port = $reporter->server->serverVariable('port');

  # If interface is not specified, tcpkill will auto-pick the first available

  my $interface = $slave_host eq '127.0.0.1' ? 'lo' : '';

  my $slave_local = $conn->get_row("
    SELECT HOST
    FROM INFORMATION_SCHEMA.PROCESSLIST
    WHERE COMMAND = 'Binlog Dump'
  ");

  my ($slave_local_host, $slave_local_port) = split (':', $slave_local);

  $tcpkill_pid = fork();

  if ($tcpkill_pid) {  # parent
    sleep(KILL_DURATION);
    say("Killing tcpkill with pid $tcpkill_pid");
    kill (15, $tcpkill_pid);
    $tcpkill_pid = undef;
    return(STATUS_OK);
  } else {
    my $command = "/usr/sbin/tcpkill -i $interface src host $slave_local_host and src port $slave_local_port and dst port $master_port";
    say("Executing $command");
    exec($command);
    exit(STATUS_OK);
  }
}

# There is no tcpkill on Windows. Instead, the replication connections
# are killed on the primary side with KILL CONNECTION, repeatedly
# during KILL_DURATION seconds, so that the replica's reconnection
# attempts also fail for a while
sub kill_binlog_dump_connections {
  my $conn= shift;
  unless ($conn) {
    sayWarning("ReplicationConnectionKiller could not connect to the server");
    return STATUS_OK;
  }
  my $end_time= time() + KILL_DURATION;
  while (time() < $end_time) {
    my $ids= $conn->get_column("SELECT ID FROM INFORMATION_SCHEMA.PROCESSLIST WHERE COMMAND = 'Binlog Dump'");
    foreach my $id (@{$ids || []}) {
      say("ReplicationConnectionKiller: Killing replication connection $id");
      $conn->execute("KILL CONNECTION $id");
    }
    sleep(1);
  }
  return STATUS_OK;
}

sub type {
  return REPORTER_TYPE_PERIODIC;
}

1;
