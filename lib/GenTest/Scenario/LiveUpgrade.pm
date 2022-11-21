# Copyright (C) 2020, 2022 MariaDB Corporation Ab
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
# The module implements a normal restart/live upgrade scenario.
#
# This is the simplest form of upgrade. The test starts the old server,
# executes some flow on it, shuts down the server, starts the new one
# on the same datadir, runs mysql_upgrade if necessary, performs a basic
# data check and executes some more flow.
#
########################################################################

package GenTest::Scenario::LiveUpgrade;

require Exporter;
@ISA = qw(GenTest::Scenario::Upgrade);

use strict;
use DBI;
use GenUtil;
use GenTest;
use GenTest::TestRunner;
use GenTest::Properties;
use GenTest::Constants;
use GenTest::Scenario;
use GenTest::Scenario::Upgrade;
use Data::Dumper;
use File::Copy;
use File::Compare;

use DBServer::MariaDB;

# True if the "old" and the "new" servers are the same ("restart" mode).
# It will determine how we categorize errors before the restart:
# if the server changes, then we are only really interested in the new one,
# so all errors before that will be "TEST_FAILURE". If the server is
# the same, then everything matters.
my $same_server= 0;

sub new {
  my $class= shift;
  my $self= $class->SUPER::new(@_);

  if ($self->old_server_options()->{basedir} eq $self->new_server_options()->{basedir}) {
    $same_server= 1;
    $self->printTitle('Normal restart');
  }
  else {
    $self->printTitle('Live upgrade/downgrade');
  }
  return $self;
}

sub run {
  my $self= shift;
  my ($status, $old_server, $new_server, $databases, %table_autoinc);

  $status= STATUS_OK;

  #####
  # Prepare servers

  ($old_server, $new_server)= $self->prepare_servers();

  #####
  $self->printStep("Starting the old server");

  $status= $old_server->startServer;

  if ($status != STATUS_OK) {
    sayError("Old server failed to start");
    return ($same_server ? $self->finalize($status,[]) : $self->finalize(STATUS_TEST_FAILURE,[]));
  }

  #####
  $self->printStep("Generating data on the old server");

  $status= $self->generate_data();

  if ($status != STATUS_OK) {
    sayError("Data generation on the old server failed");
    return ($same_server ? $self->finalize($status,[$old_server]) : $self->finalize(STATUS_TEST_FAILURE,[$old_server]));
  }

  #####
  $self->printStep("Running test flow on the old server");

  $self->setProperty('duration',int($self->getProperty('duration')/3));
  $status= $self->run_test_flow();

  if ($status != STATUS_OK) {
    sayError("Test flow on the old server failed");
    return ($same_server ? $self->finalize($status,[$old_server]) : $self->finalize(STATUS_TEST_FAILURE,[$old_server]));
  }

  #####
  $self->printStep("Restarting the old server and dumping databases");

  $status= $old_server->stopServer;

  if ($status != STATUS_OK) {
    sayError("Shutdown of the old server failed");
    return ($same_server ? $self->finalize($status,[$old_server]) : $self->finalize(STATUS_TEST_FAILURE,[$old_server]));
  }

  $status= $old_server->startServer;

  if ($status != STATUS_OK) {
    sayError("Old server failed to restart");
    return ($same_server ? $self->finalize($status,[]) : $self->finalize(STATUS_TEST_FAILURE,[]));
  }

  my @databases= $old_server->nonSystemDatabases();
  $status= $old_server->dumpSchema(\@databases, $old_server->vardir.'/server_schema_old.dump');
  if ($status != STATUS_OK) {
    sayError("Schema dump on the old server failed, no point to continue");
    return ($same_server ? $self->finalize(STATUS_DATABASE_CORRUPTION,[$old_server]) : $self->finalize(STATUS_TEST_FAILURE,[$old_server]));
  }
  $old_server->normalizeDump($old_server->vardir.'/server_schema_old.dump', 'remove_autoincs');
  # Skip heap tables' data on the old server, as it won't be preserved
  $status= $old_server->dumpdb(\@databases, $old_server->vardir.'/server_data_old.dump');
  if ($status != STATUS_OK) {
    sayError("Data dump on the old server failed, no point to continue");
    return ($same_server ? $self->finalize(STATUS_DATABASE_CORRUPTION,[$old_server]) : $self->finalize(STATUS_TEST_FAILURE,[$old_server]));
  }
  $old_server->normalizeDump($old_server->vardir.'/server_data_old.dump');
  $table_autoinc{'old'}= $old_server->collectAutoincrements();

  #####
  $self->printStep("Stopping the old server");

  $status= $old_server->stopServer;

  if ($status != STATUS_OK) {
    sayError("Shutdown of the old server failed");
    return ($same_server ? $self->finalize($status,[$old_server]) : $self->finalize(STATUS_TEST_FAILURE,[$old_server]));
  }

  #####
  $self->printStep("Checking the old server log for fatal errors after shutdown");

  $status= $self->checkErrorLog($old_server, {CrashOnly => 1});

  if ($status != STATUS_OK) {
    sayError("Found fatal errors in the log, old server shutdown has apparently failed");
    return ($same_server ? $self->finalize($status,[$old_server]) : $self->finalize(STATUS_TEST_FAILURE,[$old_server]));
  }

  #####
  $self->printStep("Backing up data directory from the old server");

  $old_server->backupDatadir($old_server->datadir."_orig");
  move($old_server->errorlog, $old_server->errorlog.'_orig');

  #####
  $self->printStep("Starting the new server");

  # Point server_specific to the new server
  $self->switch_to_new_server();

  $status= $new_server->startServer;

  if ($status != STATUS_OK) {
    sayError("New server failed to start");
    # Error log might indicate known bugs which will affect the exit code
    $status= $self->checkErrorLog($new_server);
    # ... but even if it's a known error, we cannot proceed without the server
    return ($same_server ? $self->finalize(STATUS_RECOVERY_FAILURE,[$new_server]) : $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]));
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
      return ($same_server ? $self->finalize(STATUS_RECOVERY_FAILURE,[$new_server]) : $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]));
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
      return ($same_server ? $self->finalize(STATUS_RECOVERY_FAILURE,[$new_server]) : $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]));
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
    return ($same_server ? $self->finalize(STATUS_RECOVERY_FAILURE,[$new_server]) : $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]));
  }

  #####
  $self->printStep("Dumping databases from the new server");

  $new_server->dumpSchema(\@databases, $new_server->vardir.'/server_schema_new.dump');
  $new_server->normalizeDump($new_server->vardir.'/server_schema_new.dump', 'remove_autoincs');
  # No need to skip heap tables' data on the new server, they should be empty
  $new_server->dumpdb(\@databases, $new_server->vardir.'/server_data_new.dump');
  $new_server->normalizeDump($new_server->vardir.'/server_data_new.dump');
  $table_autoinc{'new'} = $new_server->collectAutoincrements();

  #####
  $self->printStep("Restarting the new server and running the rest of the test flow");

  $status= $new_server->stopServer;

  if ($status != STATUS_OK) {
    sayError("Shutdown of the new server failed");
    return $self->finalize(STATUS_SERVER_SHUTDOWN_FAILURE,[$new_server]);
  }

  $status= $new_server->startServer;

  if ($status != STATUS_OK) {
    sayError("New server failed to restart");
    return $self->finalize(STATUS_RECOVERY_FAILURE,[]);
  }

  $self->setProperty('duration',int($self->getProperty('duration')/3));
  $status= $self->run_test_flow();

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
  $self->printStep("Stopping the new server");

  $status= $new_server->stopServer;

  if ($status != STATUS_OK) {
    sayError("Shutdown of the new server failed");
    return $self->finalize($status,[$new_server]);
  }

  #####
  $self->printStep("Comparing databases before and after upgrade");

  $status= compare($new_server->vardir.'/server_schema_old.dump', $new_server->vardir.'/server_schema_new.dump');
  if ($status != STATUS_OK) {
    sayError("Database structures differ after upgrade");
    system('diff -a -u '.$new_server->vardir.'/server_schema_old.dump'.' '.$new_server->vardir.'/server_schema_new.dump');
    return ($same_server ? $self->finalize(STATUS_RECOVERY_FAILURE,[$new_server]) : $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]));
  }
  else {
    say("Structure dumps appear to be identical");
  }

  $status= compare($new_server->vardir.'/server_data_old.dump', $new_server->vardir.'/server_data_new.dump');
  if ($status != STATUS_OK) {
    sayError("Data differs after upgrade");
    system('diff -a -u '.$new_server->vardir.'/server_data_old.dump'.' '.$new_server->vardir.'/server_data_new.dump');
    return ($same_server ? $self->finalize(STATUS_RECOVERY_FAILURE,[$new_server]) : $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]));
  }
  else {
    say("Data dumps appear to be identical");
  }

  $status= $self->compare_autoincrements($table_autoinc{old}, $table_autoinc{new});
  if ($status != STATUS_OK) {
    # Comaring auto-increments can show known errors. We want to update
    # the global status, but don't want to exit prematurely
    $self->setStatus($status);
    sayError("Auto-increment data differs after upgrade");
    if ($status > STATUS_CUSTOM_OUTCOME) {
      return ($same_server ? $self->finalize(STATUS_RECOVERY_FAILURE,[$new_server]) : $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]));
    }
  }
  else {
    say("Auto-increment data appears to be identical");
  }

  return $self->finalize($status,[]);
}

1;
