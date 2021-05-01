# Copyright 2020 MariaDB Corporation Ab
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
# The module implements a crash recovery/upgrade scenario.
#
# The test starts the old server, kills the server, starts the new one
# on the same datadir, runs mysql_upgrade if necessary, performs a basic
# data check and executes some more flow.
#
########################################################################

package GenTest::Scenario::AtomicDDL;

require Exporter;
@ISA = qw(GenTest::Scenario::Upgrade);

use strict;
use DBI;
use GenTest;
use GenTest::App::GenTest;
use GenTest::Properties;
use GenTest::Constants;
use GenTest::Scenario;
use GenTest::Scenario::Upgrade;
use GenTest::Random;
use Data::Dumper;
use File::Copy;
use File::Compare;
use POSIX;

use DBServer::MySQL::MySQLd;

sub new {
  my $class= shift;
  my $self= $class->SUPER::new(@_);

  $self->printTitle('Atomic DDL');
  return $self;
}

sub run {
  my $self= shift;
  my ($status, $server, $databases, %table_autoinc);

  my $prng = GenTest::Random->new( seed => $self->getProperty('seed') );

  $status= STATUS_OK;

  #####
  # Prepare servers
  
  $server= $self->prepare_servers();

  #####
  $self->printStep("Starting the server");

  $status= $server->startServer;

  if ($status != STATUS_OK) {
    sayError("The server failed to start");
    return $self->finalize(STATUS_TEST_FAILURE,[]);
  }

  #####
  $self->printStep("Generating data");

  $status= $self->generate_data();
  
  if ($status != STATUS_OK) {
    sayError("Data generation failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$server]);
  }

  #####
  $self->printStep("Running initial test flow");

  $self->setProperty('duration',int($self->getProperty('duration')/5));
  $status= $self->run_test_flow();

  if ($status != STATUS_OK) {
    sayError("Initial test flow failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$server]);
  }

  #####

  my $timeout= $prng->int(5,$self->getProperty('duration')/3);

  $self->printStep("Running atomic DDL test flow (random duration: $timeout sec)");

  if ($self->scenarioOptions()->{grammar2}) {
    $self->setProperty('grammar',$self->scenarioOptions()->{grammar2});
    $self->unsetProperty('redefine');
  } else {
    sayError("Atomic DDL grammar is not specified (--scenario-grammar2)");
    return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[$server]);
  }

  my $gentest_pid= fork();
  if (not defined $gentest_pid) {
    sayError("Failed to fork for atomic DDL");
    return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[$server]);
  }

  # The child will be running DDL. The parent will be running
  # the server and then killing it, and while waiting, will be monitoring
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
    sayError("Atomic DDL failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$server]);
  }

  #####
  $self->printStep("Killing the server");

  $status= $server->kill;
  
  if ($status != STATUS_OK) {
    sayError("Could not kill the server");
    return $self->finalize(STATUS_TEST_FAILURE,[$server]);
  }

  # We don't care about the result of gentest after killing the server,
  # but we need to ensure that the process exited
  waitpid($gentest_pid, 0);

  #####
  $self->printStep("Checking the server log for fatal errors after killing");

  $status= $self->checkErrorLog($server, {CrashOnly => 1});

  if ($status != STATUS_OK) {
    sayError("Found fatal errors in the log");
    return $self->finalize(STATUS_TEST_FAILURE,[$server]);
  }

  #####
  $self->printStep("Backing up data directory");

  $server->backupDatadir($server->datadir."_orig");
  move($server->errorlog, $server->errorlog.'_orig');

  #####
  $self->printStep("Restarting the server");

  $status= $server->startServer;

  if ($status != STATUS_OK) {
    sayError("Server failed to restart");
    # Error log might indicate known bugs which will affect the exit code
    $status= $self->checkErrorLog($server);
    # ... but even if it's a known error, we cannot proceed without the server
    return $self->finalize($status,[$server]);
  }

  #####
  $self->printStep("Checking the server error log for errors after upgrade");

  $status= $self->checkErrorLog($server);

  if ($status != STATUS_OK) {
    # Error log can show known errors. We want to update
    # the global status, but don't want to exit prematurely
    $self->setStatus($status);
    sayError("Found errors in the log after restart");
    if ($status > STATUS_CUSTOM_OUTCOME) {
      return $self->finalize(STATUS_UPGRADE_FAILURE,[$server]);
    }
  }

  #####
  $self->printStep("Checking the database state after restart");

  $status= $server->checkDatabaseIntegrity;

  if ($status != STATUS_OK) {
    sayError("Database appears to be corrupt after restart");
    return $self->finalize(STATUS_UPGRADE_FAILURE,[$server]);
  }
  
  #####
  $self->printStep("Running test flow on the restarted server");

  $self->setProperty('duration',int($self->getProperty('duration')/4));
  $status= $self->run_test_flow();

  if ($status != STATUS_OK) {
    sayError("Test flow after restart failed");
    #####
    $self->printStep("Checking the server error log for known errors");

    if ($self->checkErrorLog($server) == STATUS_CUSTOM_OUTCOME) {
      $status= STATUS_CUSTOM_OUTCOME;
    }

    $self->setStatus($status);
    return $self->finalize($status,[$server])
  }

  #####
  $self->printStep("Stopping the server");

  $status= $server->stopServer;

  if ($status != STATUS_OK) {
    sayError("Server shutdown failed");
    return $self->finalize(STATUS_UPGRADE_FAILURE,[$server]);
  }

  return $self->finalize($status,[]);
}

1;
