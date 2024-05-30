# Copyright (C) 2017, 2022 MariaDB Corporation Ab
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
# The test starts the old server, runs some test flow, kills the server,
# starts the new one on the same datadir, runs mysql_upgrade if necessary,
# performs basic data checks and executes some more flow
#
########################################################################

package GenTest::Scenario::CrashRecovery;

require Exporter;
@ISA = qw(GenTest::Scenario::Upgrade);

use strict;
use GenUtil;
use GenTest;
use GenTest::TestRunner;
use GenTest::Properties;
use Constants;
use GenTest::Scenario;
use GenTest::Scenario::Upgrade;
use Data::Dumper;
use File::Copy;
use File::Compare;
use POSIX;

use DBServer::MariaDB;

sub new {
  my $class= shift;
  my $self= $class->SUPER::new(@_);
  return $self;
}

sub run {
  my $self= shift;
  my ($status, $old_server, $new_server, $server, $databases, %table_autoinc);

  $status= STATUS_OK;

  #####
  # Prepare old server
  $old_server=  $self->prepareServer(1, my $is_active=1);
  unless ($old_server) {
    sayError("Could not initialize the old server");
    $status= STATUS_ENVIRONMENT_FAILURE;
    goto FINALIZE;
  }

  $server= $old_server;

  #####
  $self->printStep("Starting the old server");

  $status= $old_server->startServer;

  if ($status != STATUS_OK) {
    sayError("Old server failed to start");
    $status= STATUS_SERVER_STARTUP_FAILURE if $status < STATUS_SERVER_STARTUP_FAILURE;
    goto FINALIZE;
  }

  #####
  $self->printStep("Generating data on the old server");

  $status= $self->generateData();

  if ($status != STATUS_OK) {
    sayError("Data generation on the old server failed");
    $status= STATUS_CRITICAL_FAILURE if $status < STATUS_CRITICAL_FAILURE;
    goto FINALIZE;
  }

  #####
  $self->printStep("Running test flow on the old server");

  $self->createTestRunner();

  my $gentest_pid= fork();
  if (not defined $gentest_pid) {
    sayError("Failed to fork for running the test flow");
    $status= STATUS_ENVIRONMENT_FAILURE if $status < STATUS_ENVIRONMENT_FAILURE;
    goto FINALIZE;
  }

  # The child will be running the test flow. The parent will be running
  # the server and then killing it, and while waiting, will be monitoring
  # the status of the test flow to notice if it exits prematurely.

  if ($gentest_pid > 0) {
    my $timeout= int($self->getProperty('duration')/2);
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
    my $res= $self->runTestFlow();
    exit $res;
  }

  if ($status != STATUS_OK) {
    sayError("Test flow on the old server failed");
    goto FINALIZE;
  }

  #####
  $self->printStep("Killing the old server");

  $status= $old_server->startPlannedDowntime('KILL',-1);

  if ($status != STATUS_OK) {
    sayError("Could not kill the old server");
    goto FINALIZE;
  }

  # We don't care about the result of gentest after killing the server,
  # but we need to ensure that the process exited
  waitpid($gentest_pid, 0);

  #####
  $self->printStep("Checking the old server log for fatal errors after killing");

  $status= $self->checkErrorLog($old_server, {CrashOnly => 1});

  if ($status != STATUS_OK) {
    sayError("Found fatal errors in the log, old server shutdown has apparently failed");
    goto FINALIZE;
  }

  $old_server->endPlannedDowntime();
  #####
  $self->printStep("Backing up data directory from the old server");

  $old_server->backupDatadir($old_server->datadir."_orig");
  move($old_server->errorlog, $old_server->errorlog.'_orig');

  #####
  $self->printStep("Starting the new server");

  # Point server_specific to the new server
  $new_server= $self->prepare_new_server($old_server);
  $server= $new_server;
  $self->switch_to_new_server();

  $status= $new_server->startServer(my $repair_log_tables=1);

  if ($status != STATUS_OK) {
    sayError("New server failed to start");
    # Error log might indicate known bugs which will affect the exit code
    my $log_status= $self->checkErrorLog($new_server);
    # ... but even if it's a known error, we cannot proceed without the server
    $status= ($log_status == STATUS_CUSTOM_OUTCOME ? STATUS_CUSTOM_OUTCOME : $self->upgrade_or_recovery_failure);
    goto FINALIZE;
  }

  #####
  $self->printStep("Checking the server error log for errors after recovery");

  $status= $self->checkErrorLog($new_server);

  if ($status != STATUS_OK) {
    # Error log can show known errors. We want to update
    # the global status, but don't want to exit prematurely
    $self->setStatus($status);
    sayError("Found errors in the log after recovery");
    if ($status > STATUS_CUSTOM_OUTCOME) {
      $status= $self->upgrade_or_recovery_failure;
      goto FINALIZE;
    }
  }

  #####
  if ( ($old_server->majorVersion ne $new_server->majorVersion)
        # Follow-up for MDEV-14637 which changed the structure of InnoDB stat tables in 10.2.17 / 10.3.9
        or ($old_server->versionNumeric lt '100217' and $new_server->versionNumeric ge '100217' )
        or ($old_server->versionNumeric lt '100309' and $new_server->versionNumeric ge '100309' )
        # Follow-up/workaround for MDEV-25866, CHECK errors on encrypted Aria tables
        or ($new_server->serverVariable('aria_encrypt_tables') and $old_server->versionNumeric lt '100510' and $new_server->versionNumeric ge '100510' )
     )
  {
    $self->printStep("Running mysql_upgrade");
    $status= $new_server->upgradeDb;
    if ($status != STATUS_OK) {
      sayError("mysql_upgrade failed");
      $status= $self->upgrade_or_recovery_failure;
      goto FINALIZE;
    }
  }
  else {
    $self->printStep("mysql_upgrade is skipped, as servers have the same major version");
  }

  #####
  $self->printStep("Checking the database state after recovery");

  $status= $new_server->checkDatabaseIntegrity;

  if ($status != STATUS_OK) {
    sayError("Database appears to be corrupt after recovery");
    $status= $self->upgrade_or_recovery_failure;
    goto FINALIZE;
  }

FINALIZE:
  return $self->finalize($status,[$server]);
}

1;
