# Copyright (C) 2017, 2020 MariaDB Corporation Ab
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
# option, default 30 seconds
#
########################################################################

package GenTest::Scenario::Restart;

require Exporter;
@ISA = qw(GenTest::Scenario);

use strict;
use DBI;
use GenUtil;
use GenTest;
use GenTest::App::GenTest;
use GenTest::Properties;
use GenTest::Constants;
use GenTest::Scenario;
use Data::Dumper;
use File::Copy;
use File::Compare;
use POSIX;

use DBServer::MariaDB;

sub new {
  my $class= shift;
  my $self= $class->SUPER::new(@_);

  if (!$self->getTestType) {
    $self->setTestType('normal');
  }

  $self->printTitle($self->getTestType." restart");

  return $self;
}

sub run {
  my $self= shift;
  my ($status, $server, $gentest);

  $status= STATUS_OK;

  $server= $self->prepareServer(1);

  #####
  $self->printStep("Starting the server");

  $status= $server->startServer;

  if ($status != STATUS_OK) {
    sayError("Server failed to start");
    return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[]);
  }

  #####
  $self->printStep("Generating test data");

  $status= $self->generate_data();
  
  if ($status != STATUS_OK) {
    sayError("Data generation on the old server failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$server]);
  }

  #####
  my $test_end=time() + $self->getProperty('duration');
  my $restart_interval= $self->scenarioOptions->{restart_interval} || 30;
  my $shutdown_timeout= $self->scenarioOptions->{shutdown_timeout} || 120;

  while ( ( my $remaining_time= $test_end - time() ) > 0 )
  {
    my $timeout= ( $remaining_time > $restart_interval ? $restart_interval : $remaining_time );

    #####
    $self->printStep("Running test flow (for $timeout sec)");

    my $gentest_pid= fork();
    if (not defined $gentest_pid) {
      sayError("Failed to fork for running the test flow");
      return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[$server]);
    }
    
    # The child will be running the test flow. The parent will be running
    # the server and then stopping it, and while waiting, will be monitoring
    # the status of the test flow to notice if it exits prematurely.
    
    if ($gentest_pid > 0) {
      foreach (1..$timeout) {
        if (waitpid($gentest_pid, WNOHANG) == 0) {
          sleep 1;
        } 
        else {
          $status= $? >> 8;
          last;
        }
      }
    }
    else {
      my $res= $self->run_test_flow();
      exit $res;
    }
    
    if ($status != STATUS_OK) {
      sayError("Test flow failed");
      return $self->finalize($status,[$server]);
    }
    
    #####

    if ($self->getTestType eq 'crash') {
      $self->printStep("killing the server");
      $status= $server->kill;
    } else {
      $self->printStep("Stopping the server");
      $status= $server->stopServer($shutdown_timeout);
    }
    
    if ($status != STATUS_OK) {
      sayError("Could not stop the server");
      return $self->finalize(STATUS_TEST_FAILURE,[$server]);
    }

    # We don't care about the result of gentest after stopping the server,
    # but we need to ensure that the process exited
    kill(-9, $gentest_pid);
    waitpid($gentest_pid, 0);

    #####
    $self->printStep("Checking the server log for fatal errors after stopping");

    $status= $self->checkErrorLog($server, {CrashOnly => 1});

    if ($status != STATUS_OK) {
      sayError("Found fatal errors in the log, server shutdown has apparently failed");
      return $self->finalize(STATUS_TEST_FAILURE,[$server]);
    }

    #####
    $self->printStep("Restarting the server");

    $server->setStartDirty(1);
    $status= $server->startServer;

    if ($status != STATUS_OK) {
      sayError("Server failed to start");
      # Error log might indicate known bugs which will affect the exit code
      $status= $self->checkErrorLog($server);
      # ... but even if it's a known error, we cannot proceed without the server
      return $self->finalize($status,[$server]);
    }

    #####
    if ($self->getTestType eq 'normal') {
      $self->printStep("Checking the database state after restart");

      $status= $server->checkDatabaseIntegrity;

      if ($status != STATUS_OK) {
        sayError("Database appears to be corrupt after restart");
        return $self->finalize(STATUS_RECOVERY_FAILURE,[$server]);
      }
    }
  }
  
  #####
  $self->printStep("Stopping the server");

  $status= $server->stopServer($shutdown_timeout);

  if ($status != STATUS_OK) {
    sayError("Server shutdown failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$server]);
  }

  return $self->finalize($status,[]);
}

1;
