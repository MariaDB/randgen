# Copyright (C) 2017 MariaDB Corporation Ab
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
# When 2/3 of test duration has passed, the module will execute
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
@ISA = qw(GenTest::Scenario);

use strict;
use DBI;
use GenTest;
use GenTest::App::GenTest;
use GenTest::Properties;
use GenTest::Constants;
use GenTest::Scenario;
use Data::Dumper;
use File::Copy;
use File::Compare;
use POSIX;

use DBServer::MySQL::MySQLd;

sub new {
  my $class= shift;
  my $scenario= $class->SUPER::new(@_);

  if (!defined $scenario->getProperty('basedir2') or ($scenario->getProperty('basedir') eq $scenario->getProperty('basedir2'))) {
    $scenario->printTitle('Undo log recovery');
  }
  else {
    $scenario->printTitle('Undo log upgrade');
  }

  if (not defined $scenario->getProperty('grammar')) {
    $scenario->setProperty('grammar', 'conf/mariadb/oltp.yy');
  }
  if (not defined $scenario->getProperty('gendata')) {
    $scenario->setProperty('gendata', 'conf/mariadb/innodb_upgrade.zz');
  }
  if (not defined $scenario->getProperty('gendata1')) {
    $scenario->setProperty('gendata1', $scenario->getProperty('gendata'));
  }
  if (not defined $scenario->getProperty('gendata-advanced1')) {
    $scenario->setProperty('gendata-advanced1', $scenario->getProperty('gendata-advanced'));
  }
  if (not defined $scenario->getProperty('threads')) {
    $scenario->setProperty('threads', 4);
  }

  # Set innodb-change-buffering=none if it's there is no value
  # for the option in the settings
  my @mysqld_options= ();
  if ($scenario->getProperty('mysqld1')) {
    @mysqld_options= @{$scenario->getProperty('mysqld1')};
  }
  if ("@mysqld_options" !~ /innodb[-_]change[-_]buffering=/) {
    if ($scenario->getProperty('mysqld')) {
      @mysqld_options= @{$scenario->getProperty('mysqld')};
    }
    if ("@mysqld_options" !~ /innodb[-_]change[-_]buffering=/) {
      push @mysqld_options, '--loose-innodb-change-buffering=none';
      $scenario->setProperty('mysqld', [ @mysqld_options ]);
    }
  }

  return $scenario;
}

sub run {
  my $self= shift;
  my ($status, $old_server, $new_server, $gentest);

  $status= STATUS_OK;

  # We can initialize both servers right away, because the second one
  # runs with start_dirty, so it won't bootstrap
  
  $old_server= $self->prepareServer(1,
    {
      vardir => $self->getProperty('vardir'),
      port => $self->getProperty('port'),
      valgrind => 0,
    }
  );
  $new_server= $self->prepareServer(2, 
    {
      vardir => $self->getProperty('vardir'),
      port => $self->getProperty('port'),
      start_dirty => 1
    }
  );

  say("-- Old server info: --");
  say($old_server->version());
  $old_server->printServerOptions();
  say("-- New server info: --");
  say($new_server->version());
  $new_server->printServerOptions();
  say("----------------------");

  #####
  $self->printStep("Starting the old server");

  $status= $old_server->startServer;

  if ($status != STATUS_OK) {
    sayError("Old server failed to start");
    return $self->finalize(STATUS_TEST_FAILURE,[]);
  }

  #####
  $self->printStep("Generating test data on the old server");

  $gentest= $self->prepareGentest(1,
    {
      duration => int($self->getTestDuration * 2 / 3),
      dsn => [$old_server->dsn($self->getProperty('database'))],
      servers => [$old_server],
      gendata => $self->getProperty('gendata'),
      'gendata-advanced' => $self->getProperty('gendata-advanced'),
    }
  );
  $status= $gentest->doGenData();

  if ($status != STATUS_OK) {
    sayError("Could not generate the test data");
    return $self->finalize(STATUS_TEST_FAILURE,[$old_server]);
  }

  #####
  $self->printStep("Running test flow on the old server");

  my $gentest_pid= fork();
  if (not defined $gentest_pid) {
    sayError("Failed to fork for running the test flow");
    return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[$old_server]);
  }
  
  # The child will be running the test flow. The parent will be running
  # the server and then killing it, and while waiting, will be monitoring
  # the status of the test flow to notice if it exits prematurely.
  
  if ($gentest_pid > 0) {
    my $timeout= $self->getTestDuration * 2 / 3;
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
    $gentest= $self->prepareGentest(1,
      {
        duration => int($self->getTestDuration * 2 / 3),
        dsn => [$old_server->dsn($self->getProperty('database'))],
        servers => [$old_server],
        'start-dirty' => 1,
      }
    );
    my $res= $gentest->run();
    exit $res;
  }
  
  if ($status != STATUS_OK) {
    sayError("Test flow on the old server failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$old_server]);
  }
  
  #####
  $self->printStep("Killing the old server");

  $status= $old_server->kill;
  
  if ($status != STATUS_OK) {
    sayError("Could not kill the old server");
    return $self->finalize(STATUS_TEST_FAILURE,[$old_server]);
  }

  # We don't care about the result of gentest after killing the server,
  # but we need to ensure that the process exited
  waitpid($gentest_pid, 0);

  #####
  $self->printStep("Checking the old server log for fatal errors after killing");

  $status= $self->checkErrorLog($old_server, {CrashOnly => 1});

  if ($status != STATUS_OK) {
    sayError("Found fatal errors in the log, old server shutdown has apparently failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$old_server]);
  }

  #####
  $self->printStep("Backing up data directory from the old server");

  $old_server->backupDatadir($old_server->datadir."_orig");
  move($old_server->errorlog, $old_server->errorlog.'_orig');

  #####
  $self->printStep("Restarting the old server with innodb-force-recovery");

  $old_server->setStartDirty(1);
  $old_server->addServerOptions(['--innodb-force-recovery=3']);

  $status= $old_server->startServer;

  if ($status != STATUS_OK) {
    sayError("Old server failed to restart with innodb-force-recovery");
    return $self->finalize(STATUS_TEST_FAILURE,[]);
  }

  #####
  $self->printStep("Stopping the old server");

  # We don't want to stop too quickly, it seems to cause problems
  # with some old servers
  sleep(10);

  $status= $old_server->stopServer;

  if ($status != STATUS_OK) {
    sayError("Shutdown of the old server failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$old_server]);
  }

  #####
  $self->printStep("Backing up data directory from the old server again");

  $old_server->backupDatadir($old_server->datadir.'_orig2');
  move($old_server->errorlog, $old_server->errorlog.'_orig2');

  #####
  $self->printStep("Starting the new server");

  $status= $new_server->startServer;

  if ($status != STATUS_OK) {
    sayError("New server failed to start");
    # Error log might indicate known bugs which will affect the exit code
    $status= $self->checkErrorLog($new_server);
    # ... but even if it's a known error, we cannot proceed without the server
    return $self->finalize($status,[$new_server]);
  }

  #####
  $self->printStep("Checking the server error log for errors after upgrade");

  $status= $self->checkErrorLog($new_server);

  if ($status != STATUS_OK) {
    # Error log can show known errors. We want to update 
    # the global status, but don't want to exit prematurely
    $self->setStatus($status);
    if ($status > STATUS_CUSTOM_OUTCOME) {
      sayError("Found errors in the log, upgrade has apparently failed");
      return $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]);
    }
  }

  #####
  $self->printStep("Checking the database state after upgrade");

  $status= $new_server->checkDatabaseIntegrity;

  if ($status != STATUS_OK) {
    sayError("Database appears to be corrupt after upgrade");
    return $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]);
  }
  
  #####
  if ($old_server->majorVersion ne $new_server->majorVersion) {
    $self->printStep("Running mysql_upgrade");
    $status= $new_server->upgradeDb;
    if ($status != STATUS_OK) {
      sayError("mysql_upgrade failed");
      return $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]);
    }
  } else {
    $self->printStep("mysql_upgrade is skipped, as servers have the same major version");
  }

  #####
  $self->printStep("Running test flow on the new server");

  $gentest= $self->prepareGentest(2,
    {
      duration => int($self->getTestDuration / 3),
      dsn => [$new_server->dsn($self->getProperty('database'))],
      servers => [$new_server],
    }
  );
  $status= $gentest->run();
  
  if ($status != STATUS_OK) {
    sayError("Test flow on the new server failed");
    #####
    $self->printStep("Checking the server error log for known errors");

    if ($self->checkErrorLog($new_server) == STATUS_CUSTOM_OUTCOME) {
      $status= STATUS_CUSTOM_OUTCOME;
    }

    $self->setStatus($status);
    return $self->finalize($status,[$new_server])
  }

  #####
  $self->printStep("Checking the database state again after DML");

  $status= $new_server->checkDatabaseIntegrity;

  if ($status != STATUS_OK) {
    sayError("Database appears to be corrupt after upgrade");
    return $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]);
  }
  
  #####
  $self->printStep("Stopping the new server");

  $status= $new_server->stopServer;

  if ($status != STATUS_OK) {
    sayError("Shutdown of the new server failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$new_server]);
  }

  return $self->finalize($status,[]);
}

1;
