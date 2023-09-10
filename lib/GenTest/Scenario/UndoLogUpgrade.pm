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
# The module implements the test described in MDEV-13269.
#
# 1. Start the old version with --innodb-change-buffering=none and run
#    quite a bit of DML
# 2. Kill & restart with --innodb-force-recovery=3 (important,
#    to preserve the undo logs)
# 3. Start the new version, run CHECK TABLE and such to make sure
#    that the data is not corrupt.
# 4. Run mysql_upgrade if necessary and run some more DML workload
#    and again CHECK TABLE afterwards.
#
# For step 1, we set innodb-change-buffering to 'none' by default,
# but rely on the test configuration if it wants to override it
# (maybe it will be later decided that other values of
# innodb-change-buffering need to be tried as well).
#
# When half of test duration has passed, the module will execute
# step 2, crash and restart the old server with innodb-force-recovery=3.
#
# If it works, the module will continue operation and execute step 3 --
# shut down the old server normally, and start the new one, without
# users' requests, and run database consistency checks.
#
# If the database is not corrupted, it will execute mysql_upgrade
# if necessary, and then run some more DML to make sure it's functional.
#
# At the end, the module again run CHECK TABLE for all tables.
#
########################################################################

package GenTest::Scenario::UndoLogUpgrade;

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
  $self->numberOfServers(1,2);

  my @mysqld_options= @{$self->old_server_options()->{mysqld}};
  if ( "@mysqld_options" !~ /innodb[-_]change[-_]buffering=/) {
    push @mysqld_options, '--loose-innodb-change-buffering=none';
    $self->setServerSpecific(1,'mysqld_options',\@mysqld_options);
  }
  @mysqld_options= @{$self->new_server_options()->{mysqld}};
  if ( "@mysqld_options" !~ /innodb[-_]change[-_]buffering=/) {
    push @mysqld_options, '--loose-innodb-change-buffering=none';
    $self->setServerSpecific(2,'mysqld_options',\@mysqld_options);
  }

  return $self;
}

sub run {
  my $self= shift;
  my ($status, $old_server, $new_server, $server, $databases, %table_autoinc);

  $status= STATUS_OK;

  #####
  # Prepare old server
  $old_server=  $self->prepareServer(1, my $is_active=1);
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
    $status= STATUS_SERVER_SHUTDOWN_FAILURE if $status < STATUS_SERVER_SHUTDOWN_FAILURE;
    goto FINALIZE;
  }

  waitpid($gentest_pid, 0);
  $status= ($? >> 8);
  if ($status != STATUS_OK && $status != STATUS_SERVER_STOPPED && $status != STATUS_TEST_STOPPED) {
    sayError("Test flow failed");
    goto FINALIZE;
  }

  #####
  $self->printStep("Checking the old server log for fatal errors after killing");

  $status= $self->checkErrorLog($old_server, {CrashOnly => 1});

  if ($status != STATUS_OK) {
    sayError("Found fatal errors in the log, old server shutdown has apparently failed");
    $status= STATUS_ERRORS_IN_LOG if $status < STATUS_ERRORS_IN_LOG;
    goto FINALIZE;
  }

  #####
  $self->printStep("Backing up data directory from the old server");

  $old_server->backupDatadir($old_server->datadir."_orig");
  move($old_server->errorlog, $old_server->errorlog.'_orig');

  #####
  $self->printStep("Restarting the old server with innodb-force-recovery");

  $self->setServerSpecific(1,'start_dirty',1);
  $old_server->addServerOptions(['--innodb-force-recovery=3']);

  $status= $old_server->startServer;

  if ($status != STATUS_OK) {
    sayError("Old server failed to restart with innodb-force-recovery");
    $status= STATUS_SERVER_STARTUP_FAILURE if $status < STATUS_SERVER_STARTUP_FAILURE;
    goto FINALIZE;
  }
  $old_server->endPlannedDowntime();

  #####
  $self->printStep("Stopping the old server after crash recovery");

  # We don't want to stop too quickly, it seems to cause problems
  # with some old servers
  sleep(10);

  $status= $old_server->stopServer;

  if ($status != STATUS_OK) {
    sayError("Shutdown of the old server failed");
    $status= STATUS_SERVER_SHUTDOWN_FAILURE;
    goto FINALIZE;
  }

  $self->restoreProperties();

  #####
  $self->printStep("Backing up data directory from the old server again");

  $old_server->backupDatadir($old_server->datadir.'_orig2');
  move($old_server->errorlog, $old_server->errorlog.'_orig2');

  #####
  $self->printStep("Starting the new server");

  # Point server_specific to the new server
  $new_server=  $self->prepare_new_server($old_server);
  $server= $new_server;
  $self->switch_to_new_server();

  $status= $new_server->startServer;

  if ($status != STATUS_OK) {
    sayError("New server failed to start");
    # Error log might indicate known bugs which will affect the exit code
    $status= $self->checkErrorLog($new_server);
    # ... but even if it's a known error, we cannot proceed without the server
    goto FINALIZE;
  }

  #####
  $self->printStep("Checking the server error log for errors after upgrade");

  $status= $self->checkErrorLog($new_server);

  if ($status != STATUS_OK) {
    # Error log can show known errors. We want to update
    # the global status, but don't want to exit prematurely
    $self->setStatus($status);
    sayError("Found errors in the log after upgrade");
    if ($status > STATUS_CUSTOM_OUTCOME) {
      $status= STATUS_UPGRADE_FAILURE if $status < STATUS_UPGRADE_FAILURE;
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
      $status= STATUS_UPGRADE_FAILURE if $status < STATUS_UPGRADE_FAILURE;
      goto FINALIZE;
    }
  }
  else {
    $self->printStep("mysql_upgrade is skipped, as servers have the same major version");
  }

  #####
  $self->printStep("Checking the database state after upgrade");

  $status= $new_server->checkDatabaseIntegrity;

  if ($status != STATUS_OK) {
    sayError("Database appears to be corrupt after upgrade");
    $status= STATUS_UPGRADE_FAILURE if $status < STATUS_UPGRADE_FAILURE;
    goto FINALIZE;
  }

  #####
  $self->printStep("Running test flow on the new server");

  $self->setProperty('duration',int($self->getProperty('duration')/3));
  $self->createTestRunner();
  $status= $self->runTestFlow();

  if ($status != STATUS_OK) {
    sayError("Test flow on the new server failed");
    #####
    $self->printStep("Checking the server error log for known errors");

    if ($self->checkErrorLog($new_server) == STATUS_CUSTOM_OUTCOME) {
      $status= STATUS_CUSTOM_OUTCOME;
    }

    $self->setStatus($status);
    goto FINALIZE;
  }

FINALIZE:
  return $self->finalize($status,[$server]);
}

1;
