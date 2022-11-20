# Copyright (C) 2022 MariaDB Corporation Ab
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
# The module implements a mysql dump recovery/upgrade scenario.
#
# This is the logical upgrade. The test starts the old server,
# executes some flow on it, dumps the schema, shuts down the server,
# starts the new one, loads the dump, runs mysql_upgrade if necessary,
# compares the data before and after upgrade and executes some more flow.
#
########################################################################

package GenTest::Scenario::DumpUpgrade;

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
    $self->printTitle('Dump recovery');
  }
  else {
    $self->printTitle('Dump upgrade/downgrade');
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
   $old_server->backupDatadir($old_server->datadir."_clean");

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

  # Dump all databases for further restoring
  if ($old_server->versionNumeric gt '101100') {
    $status= $old_server->dumpdb(undef, $old_server->vardir.'/all_db.dump',my $for_restoring=1,"--dump-history --force");
  } else {
    $status= $old_server->dumpdb(undef, $old_server->vardir.'/all_db.dump',my $for_restoring=1);
  }
  if ($status != STATUS_OK) {
    sayWarning("Database dump on the old server failed, but it was running with --force, so we will continue");
  }

  # Dump non-system databases for further comparison
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
  $self->printStep("Backing up data directory from the old server and restoring clean datadir for the new server");
  system ('mv '.$old_server->datadir.' '.$old_server->datadir.'_orig');
  system ('mv '.$old_server->datadir.'_clean '.$old_server->datadir);

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
  $self->printStep("Restoring the dump of all databases");
  my $client_command= $new_server->client.' -uroot --host=127.0.0.1 --protocol=tcp --port='.$new_server->port;

  system($client_command.' < '.$old_server->vardir.'/all_db.dump');
  $status= $?;
  if ($status != STATUS_OK) {
    sayError("All databases' schema dump failed to load");
    $status= $self->checkErrorLog($new_server);
    return ($same_server ? $self->finalize(STATUS_RECOVERY_FAILURE,[$new_server]) : $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]));
  }

  #####
  $self->printStep("Checking the server error log for errors after dump reload");

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
  
  my $x_status= compare($new_server->vardir.'/server_schema_old.dump', $new_server->vardir.'/server_schema_new.dump');
  if ($x_status != STATUS_OK) {
    sayError("Database structures differ after upgrade");
    system('diff -a -u '.$new_server->vardir.'/server_schema_old.dump'.' '.$new_server->vardir.'/server_schema_new.dump');
    return ($same_server ? $self->finalize(STATUS_RECOVERY_FAILURE,[$new_server]) : $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]));
  }
  else {
    say("Structure dumps appear to be identical");
  }
  
  $x_status= compare($new_server->vardir.'/server_data_old.dump', $new_server->vardir.'/server_data_new.dump');
  if ($x_status != STATUS_OK) {
    sayError("Data differs after upgrade");
    system('diff -a -u '.$new_server->vardir.'/server_data_old.dump'.' '.$new_server->vardir.'/server_data_new.dump');
    return ($same_server ? $self->finalize(STATUS_RECOVERY_FAILURE,[$new_server]) : $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]));
  }
  else {
    say("Data dumps appear to be identical");
  }
  
  $x_status= $self->compare_autoincrements($table_autoinc{old}, $table_autoinc{new});
  if ($x_status != STATUS_OK) {
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
