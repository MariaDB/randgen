# Copyright (c) 2025 MariaDB
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


###################################################################
# The reporter makes the primary server crash every 30 seconds,
# restarts it and checks that it started all right.
###################################################################

package GenTest::Reporter::PrimaryCrashRecovery;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use GenUtil;
use GenTest;
use Constants;
use GenTest::Reporter;
use GenTest::Comparator;
use Data::Dumper;
use IPC::Open2;
use File::Copy;
use POSIX;

use DBServer::MariaDB;

my $first_reporter;
my $last_crash_time;
my $restart_count = 0;

sub monitor {
  my $reporter = shift;
  $first_reporter = $reporter if not defined $first_reporter;
  return STATUS_OK if $reporter ne $first_reporter;
  my $status = STATUS_OK;

  my $server= $reporter->properties->server_specific->{1}->{server};
  $last_crash_time = $reporter->testStart() if not defined $last_crash_time;

  if (time() > $last_crash_time + 30) {
    $last_crash_time = time();

    $status= $server->startPlannedDowntime('KILL',60);

    if ($status != STATUS_OK) {
      sayError("PrimaryCrashRecovery: Attempt to stop the server ended with an error, aborting the test");
      $server->setFinalDowntime();
      return $status;
    }

    $server->setStartDirty(1);
    $status= $server->startServer;
    $server->endPlannedDowntime();

    if ($status != STATUS_OK) {
      sayError("PrimaryCrashRecovery: Server failed to start");
      return $status;
    }
  }
  return STATUS_OK;
}

sub report {
  return STATUS_OK;
}

sub type {
  return REPORTER_TYPE_PERIODIC;
}

1;
