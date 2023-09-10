# Copyright (C) 2017, 2023 MariaDB
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


########################################################################
#
# The module implements a repeated normal- or crash-restart scenario.
#
# The test starts the the server, executes some flow on it,
# stops/kills the server, restarts it, checks the status of the tables,
# continues the flow and repeats it until the end
# of the test duration.
# Time between restarts is controlled by --scenario-restart-interval
# option, default 30 seconds.
# Whether it's a shutdown or kill is controlled by --scenario-restart-type,
# for now the values are [kill | clean], default "clean"
#
########################################################################

package GenTest::Scenario::Restart;

require Exporter;
@ISA = qw(GenTest::Scenario);

use strict;
use GenUtil;
use GenTest;
use GenTest::TestRunner;
use GenTest::Properties;
use Constants;
use GenTest::Scenario;
use Data::Dumper;
use File::Copy;
use File::Compare;
use POSIX;

use DBServer::MariaDB;

sub new {
  my $class= shift;
  my $self= $class->SUPER::new(@_);
  $self->numberOfServers(1,1);
  return $self;
}

sub run {
  my $self= shift;
  my ($total_status, $status, $server, $gentest);

  $total_status= STATUS_OK;
  $status= STATUS_OK;

  $server= $self->prepareServer(1, my $is_active=1);

  #####
  $self->printStep("Starting the server");

  $status= $server->startServer;

  if ($status != STATUS_OK) {
    sayError("Server failed to start");
    $total_status= STATUS_SERVER_STARTUP_FAILURE if STATUS_SERVER_STARTUP_FAILURE > $total_status;
    return $self->finalize($total_status,[$server]);
  }

  #####
  $self->printStep("Generating test data");

  $status= $self->generateData();

  if ($status != STATUS_OK) {
    sayError("Data generation on the old server failed");
    $total_status= $status if $status > $total_status;
    return $self->finalize($total_status,[$server]);
  }

  #####
  my $test_end=time() + $self->getProperty('duration');
  my $restart_interval= $self->scenarioOptions->{restart_interval} || int($self->getProperty('duration') / 5);
  my $shutdown_timeout= $self->scenarioOptions->{shutdown_timeout} || 120;
  my $restart_type= $self->scenarioOptions->{restart_type} || 'clean';

  my $gentest_pid= undef;

  $self->createTestRunner();

  $gentest_pid= fork();
  if (not defined $gentest_pid) {
    sayError("Failed to fork for running the test flow");
    return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[$server]);
  }

  # The child will be running the test flow. The parent will be running
  # the server and then stopping it, and while waiting, will be monitoring
  # the status of the test flow to notice if it exits prematurely.

  if ($gentest_pid > 0) {
   TESTRUN:
    while ( $test_end - time() > $restart_interval )
    {
      foreach (1..$restart_interval) {
        if (waitpid($gentest_pid, WNOHANG) == 0) {
          sleep 1;
        }
        else {
          $status= $? >> 8;
          say("Test flow exited with status $status");
          last TESTRUN;
        }
      }

      #####
      $self->printStep("Stopping/killing the server");
      $status= $server->startPlannedDowntime($restart_type,$shutdown_timeout*2);

      if ($status != STATUS_OK) {
        sayError("Restart scenario: Attempt to stop the server ended with an error, aborting the test");
        $total_status= $status if $status > $total_status;
        $server->setFinalDowntime();
        last TESTRUN;
      }

      #####
      $self->printStep("Restarting the server");

      $server->setStartDirty(1);
      $status= $server->startServer;
      $server->endPlannedDowntime();

      if ($status != STATUS_OK) {
        sayError("Server failed to start");
        $total_status= STATUS_SERVER_STARTUP_FAILURE if STATUS_SERVER_STARTUP_FAILURE > $total_status;
        # Error log might indicate known bugs which will affect the exit code
        $status= $self->checkErrorLog($server);
        $total_status= $status if $status > $total_status;
        # ... but even if it's a known error, we cannot proceed without the server
        last TESTRUN;
      }

      #####
      if ($self->getTestType eq 'normal') {
        $self->printStep("Checking the database state after restart");

        $status= $server->checkDatabaseIntegrity;

        if ($status != STATUS_OK) {
          $total_status= STATUS_RECOVERY_FAILURE if STATUS_RECOVERY_FAILURE > $total_status;
          sayError("Database appears to be corrupt after restart");
          last TESTRUN;
        }
      }
    }
  }
  else {
    #####
    # Child running the queries
    $self->printStep("Running test flow");
    my $res= $self->runTestFlow();
    exit $res;
  }

  say("Waiting for test flow to finish");
  waitpid($gentest_pid, 0);
  # -1 means that we caught it before already
  $status= ($? >> 8) if ($? >= 0);
  
  if ($status != STATUS_OK) {
    sayError("Test flow failed");
    $total_status= $status if $status > $total_status;
  }

  #####
  $self->printStep("Stopping the server");

  $status= $server->stopServer($shutdown_timeout);

  if ($status != STATUS_OK) {
    sayError("Server shutdown failed");
    $total_status= $status if $status > $total_status;
  }

  #####
  $self->printStep("Checking the server log for errors");
  $status= $self->checkErrorLog($server);

  $total_status= $status if $status > $total_status;

  return $self->finalize($total_status,[$server]);
}

1;
