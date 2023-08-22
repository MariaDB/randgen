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
# The module implements a combination of different types of upgrades
# and corresponding checks
# - live upgrade
# - mysqldump upgrade
# - mariabackup upgrade
#
# The test starts the old server, dumps the schema and data,
# creates a full backup, and shuts down the server.
# Then it starts the new one on the old datadir, runs mysql_upgrade
# if necessary, checks the tables, dumps the schema and data;
# Then it starts the new server again on a clean datadir,
# loads the dump from the old server runs mysql_upgrade if necessary,
# dumps the schema and data;
# Then it starts the new server again on a clean datadir,
# restores mariabackup backup, dumps the schema and data;
# Then it compares all new dumps to the old one.
#
########################################################################

package GenTest::Scenario::NormalUpgrades;

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

use DBServer::MariaDB;

my ($status, $old_server, $new_server, $databases, $vardir, $old_grants);

sub new {
  my $class= shift;
  my $self= $class->SUPER::new(@_);
  return $self;
}

sub run {
  my $self= shift;

  $status= STATUS_OK;

  #####
  # Prepare old server
  $old_server=  $self->prepareServer(1, my $is_active=1);
  $old_server->backupDatadir($old_server->datadir."_clean");
  $vardir=$old_server->vardir;

  #####
  $self->printStep("Starting the old server");

  $status= $old_server->startServer;

  if ($status != STATUS_OK) {
    sayError("Old server failed to start");
    return $self->finalize($status,[]);
  }

  #####
  $self->printStep("Generating data on the old server");

  $status= $self->generateData(1);

  if ($status != STATUS_OK) {
    sayError("Data generation on the old server failed");
    return $self->finalize($status,[$old_server]);
  }

  #####
  $self->printStep("Running test flow on the old server");

  $self->setProperty('duration',int($self->getProperty('duration')/2));
  $status= $self->runTestFlow();

  if ($status != STATUS_OK) {
    sayError("Test flow on the old server failed");
    return $self->finalize($status,[$old_server]);
  }

  #####
  $self->printStep("Restarting the old server and dumping databases");

  $status= $old_server->stopServer;

  if ($status != STATUS_OK) {
    sayError("Shutdown of the old server failed");
    return $self->finalize($status,[$old_server]);
  }

  $status= $old_server->startServer;

  if ($status != STATUS_OK) {
    sayError("Old server failed to restart");
    return $self->finalize($status,[]);
  }

  # Dump all databases for further restoring
  if ($old_server->versionNumeric gt '101100') {
    $status= $old_server->dumpdb(undef, $vardir.'/all_db.dump',my $for_restoring=1,"--dump-history --force");
  } else {
    $status= $old_server->dumpdb(undef, $vardir.'/all_db.dump',my $for_restoring=1);
  }
  if ($status != STATUS_OK) {
    sayWarning("Database dump on the old server failed, but it was running with --force, so we will continue");
  }

  # Dump non-system databases for further comparison
  my @databases= $old_server->nonSystemDatabases();
  $status= $old_server->dumpSchema(\@databases, $vardir.'/server_schema_old.dump');
  if ($status != STATUS_OK) {
    sayError("Schema dump on the old server failed, no point to continue");
    return $self->finalize(STATUS_DATABASE_CORRUPTION,[$old_server]);
  }
  $old_server->normalizeDump($vardir.'/server_schema_old.dump', 'remove_autoincs');
  # Skip heap tables' data on the old server, as it won't be preserved
  $status= $old_server->dumpdb(\@databases, $vardir.'/server_data_old.dump');
  if ($status != STATUS_OK) {
    sayError("Data dump on the old server failed, no point to continue");
    return $self->finalize(STATUS_DATABASE_CORRUPTION,[$old_server]);
  }
  $old_server->normalizeDump($vardir.'/server_data_old.dump');

  #####
  $self->printStep("Creating full backup with MariaBackup");

  my $mbackup;
  my $buffer_pool_size= $old_server->serverVariable('innodb_buffer_pool_size') * 2;

  unless ($mbackup= $old_server->mariabackup()) {
    sayError("Could not find MariaBackup binary for the old server");
    return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[$old_server]);
  }

  if ($old_server->versionNumeric lt '100500') {
    # Workaround for MDEV-29943 (MariaBackup may lose a DML operation)
    # Adding a sleep period to avoid the race condition
    sleep(5);
  }
  my $mbackup_command= ($self->getProperty('rr') ? "rr record -h --output-trace-dir=$vardir/rr_profile_backup $mbackup" : $mbackup);
  $status= system("$mbackup_command --backup --target-dir=$vardir/mbackup --protocol=tcp --port=".$old_server->port." --user=".$old_server->user." >$vardir/mbackup_backup.log 2>&1");

  if ($status == STATUS_OK) {
      say("MariaBackup ran finished successfully");
  } else {
      sayError("MariaBackup failed: $status");
      sayFile("$vardir/mbackup_backup.log");
      return $self->finalize(STATUS_BACKUP_FAILURE,[$old_server]);
  }

  $self->printStep("Preparing backup");

  say("Storing the backup before prepare attempt...");
  if (osWindows()) {
    system("xcopy $vardir/mbackup $vardir/mbackup_before_prepare /E /I /Q");
  } else {
    system("cp -r $vardir/mbackup $vardir/mbackup_before_prepare");
  }

  my $cmd= ($self->getProperty('rr') ? "rr record -h --output-trace-dir=$vardir/rr_profile_prepare $mbackup" : $mbackup)
    . " --use-memory=".($buffer_pool_size * 2)." --prepare --target-dir=$vardir/mbackup --user=".$old_server->user." 2>$vardir/mbackup_prepare.log 2>&1";
  say($cmd);
  system($cmd);
  $status= $? >> 8;

  if ($status == STATUS_OK) {
      say("Prepare of backup finished successfully");
  } else {
    sayError("Backup preparing failed");
    sayFile("$vardir/mbackup_prepare.log");
    return $self->finalize(STATUS_BACKUP_FAILURE,[$old_server]);
  }

  #####
  $self->printStep("Getting ACL info from the old server");

  ($status, $old_grants)= $self->collectAclData($old_server);

  if ($status != STATUS_OK) {
    sayError("ACL info collection from the old server failed");
    return $self->finalize(STATUS_BACKUP_FAILURE,[$old_server]);
  }

  #####
  $self->printStep("Stopping the old server");

  $status= $old_server->stopServer;

  if ($status != STATUS_OK) {
    sayError("Shutdown of the old server failed");
    return $self->finalize(STATUS_SERVER_SHUTDOWN_FAILURE,[$old_server]);
  }

  #####
  $self->printStep("Checking the old server log for fatal errors after shutdown");

  $status= $self->checkErrorLog($old_server, {CrashOnly => 1});

  if ($status != STATUS_OK) {
    sayError("Found fatal errors in the log, old server shutdown has apparently failed");
    return $self->finalize(STATUS_ERRORS_IN_LOG,[$old_server]);
  }
  # Back up data directory and error log from the old server
  system ('cp -r '.$old_server->datadir.' '.$old_server->datadir.'_orig');
  system ('mv '.$old_server->errorlog.' '.$old_server->errorlog.'_orig');

  ######################################################################

  # Point server_specific to the new server
  $new_server=  $self->prepare_new_server($old_server);
  $self->switch_to_new_server();

  my @upgrade_errors;

  #######################
  # Live upgrade
  #######################

  #####
  $self->printStep("LIVE UPGRADE: Starting the new server on the old datadir");

  $status= $self->start_for_upgrade('live');

  if ($status != STATUS_OK) {
    sayError("New server failed to start for live upgrade");
    push @upgrade_errors, "LIVE upgrade failed: new server failed to start for upgrade";
    goto LIVE_UPGRADE_END;
  }

  $status= $self->post_upgrade('live');

  if ($status != STATUS_OK) {
    sayError("Live upgrade failed");
    push @upgrade_errors, "LIVE upgrade failed";
    goto LIVE_UPGRADE_END;
  }

LIVE_UPGRADE_END:
  # Back up data directory from the live upgrade
  system ('mv '.$new_server->datadir.' '.$new_server->datadir.'_live_upgrade');
  system ('mv '.$new_server->errorlog.' '.$new_server->errorlog.'_live_upgrade');
  $self->setStatus($status);

  #######################
  # Dump upgrade
  #######################

  #####
  $self->printStep("DUMP UPGRADE: Starting the new server on clean datadir for mysqldump upgrade");

  # Restore clean datadir for mysqldump upgrade
  system ('mv '.$old_server->datadir.'_clean '.$new_server->datadir);

  # enforce-storage-engine needs to be unset, otherwise the dump won't load
  my $enforced_stored= $self->getServerStartupOption(1,'enforce-storage-engine');
  $new_server->addServerOptions(['--enforce-storage-engine=']) if ($enforced_stored);
  $status= $self->start_for_upgrade('dump');

  if ($status != STATUS_OK) {
    sayError("New server failed to restart for mysqldump upgrade");
    push @upgrade_errors, "DUMP upgrade failed: new server failed to start for upgrade";
    goto DUMP_UPGRADE_END;
  }

  #####
  $self->printStep("Restoring the dump of all databases");
  my $client_command= $new_server->client.' -uroot --host=127.0.0.1 --protocol=tcp --port='.$new_server->port;

  $status= system($client_command.' < '.$vardir.'/all_db.dump');
  if ($status != STATUS_OK) {
    sayError("All databases' schema dump failed to load");
    return $self->finalize($self->upgrade_or_recovery_failure(),[$new_server]);
    $status= $self->checkErrorLog($new_server);
    push @upgrade_errors, "DUMP upgrade failed: all databases' schema dump failed to load";
    goto DUMP_UPGRADE_END;
  }

  $status= $self->post_upgrade('dump');

  if ($status != STATUS_OK) {
    sayError("Dump upgrade failed");
    push @upgrade_errors, "DUMP upgrade failed";
    goto DUMP_UPGRADE_END;
  }

DUMP_UPGRADE_END:
  # Back up data directory from the live upgrade
  system ('mv '.$new_server->datadir.' '.$new_server->datadir.'_dump_upgrade');
  system ('mv '.$new_server->errorlog.' '.$new_server->errorlog.'_dump_upgrade');
  $self->setStatus($status);

  $new_server->addServerOptions(['--enforce-storage-engine='.$enforced_stored]) if ($enforced_stored);

  #######################
  # MariaBackup upgrade
  #######################

  $self->printStep("BACKUP UPGRADE: Starting the new server on restored mariabackup backup");

  unless ($mbackup= $new_server->mariabackup()) {
    sayError("Could not find MariaBackup binary for the new server");
    return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[$new_server]);
  }

  $self->printStep("Restoring mariabackup");
  system("rm -rf ".$new_server->datadir);
  $cmd= "$mbackup --copy-back --target-dir=$vardir/mbackup --datadir=".$new_server->datadir." --user=".$new_server->user." > $vardir/mbackup_restore.log 2>&1";
  say($cmd);
  $status= system($cmd);
  if ($status != STATUS_OK) {
    return $self->finalize($self->upgrade_or_recovery_failure(),[$new_server]);
    sayError("Backup failed to restore");
    sayFile("$vardir/mbackup_restore.log");
    push @upgrade_errors, "MARIABACKUP upgrade failed: backup failed to restore";
    goto MBACKUP_UPGRADE_END;
  }

  $status= $self->start_for_upgrade('mariabackup');

  if ($status != STATUS_OK) {
    sayError("New server failed to restart upon mariabackup upgrade");
    push @upgrade_errors, "MARIABACKUP upgrade failed: server failed to restart";
    goto MBACKUP_UPGRADE_END;
  }

  $status= $self->post_upgrade('mariabackup');

  if ($status != STATUS_OK) {
    sayError("MariaBackup upgrade failed");
    push @upgrade_errors, "MARIABACKUP upgrade failed";
    goto MBACKUP_UPGRADE_END;
  }

MBACKUP_UPGRADE_END:
  # Back up data directory from the mariabackup upgrade
  system ('mv '.$new_server->datadir.' '.$new_server->datadir.'mbackup_upgrade');
  system ('mv '.$new_server->errorlog.' '.$new_server->errorlog.'_mbackup_upgrade');

UPGRADE_END:
  foreach (@upgrade_errors) { sayError($_) };
  return $self->finalize($status,[$new_server]);
}

######################################
# Checks performed after each upgrade
######################################

sub start_for_upgrade {
  my ($self, $type)= @_;

  my $start_status= $new_server->startServer;

  if ($start_status != STATUS_OK) {
    sayError("New server failed to start upon $type upgrade");
    # Error log might indicate known bugs which will affect the exit code
    $start_status= $self->checkErrorLog($new_server);
    # ... but even if it's a known error, we cannot proceed without the server
    return $self->finalize($self->upgrade_or_recovery_failure(),[$new_server]);
  }

  return $start_status;
}

sub post_upgrade {
  my ($self, $type)= @_;

  my $post_upgrade_status= STATUS_OK;

  #####
  $self->printStep("Checking the server error log for errors after $type upgrade");

  $post_upgrade_status= $self->checkErrorLog($new_server);

  if ($post_upgrade_status != STATUS_OK) {
    # Error log can show known errors. We want to update
    # the global status, but don't want to exit prematurely
    $self->setStatus($post_upgrade_status);
    sayError("Found errors in the log after upgrade");
    if ($post_upgrade_status > STATUS_CUSTOM_OUTCOME) {
      return $self->finalize($self->upgrade_or_recovery_failure(),[$new_server]);
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
    $self->printStep("Running mysql_upgrade after $type upgrade");
    $post_upgrade_status= $new_server->upgradeDb;
    if ($post_upgrade_status != STATUS_OK) {
      sayError("mysql_upgrade failed");
        return $self->finalize($self->upgrade_or_recovery_failure(),[$new_server]);
    }
  }
  else {
    $self->printStep("mysql_upgrade is skipped, as servers have the same major version");
  }

  #####
  $self->printStep("Checking the database state after $type upgrade");

  $post_upgrade_status= $new_server->checkDatabaseIntegrity;

  if ($post_upgrade_status != STATUS_OK) {
    sayError("Database appears to be corrupt after $type upgrade");
    return $self->finalize($self->upgrade_or_recovery_failure(),[$new_server]);
  }

  #####
  $self->printStep("Dumping databases from the new server after $type upgrade");

  my @databases= $new_server->nonSystemDatabases();

  $new_server->dumpSchema(\@databases, $vardir.'/server_schema_'.$type.'_upgrade.dump');
  $new_server->normalizeDump($vardir.'/server_schema_'.$type.'_upgrade.dump', 'remove_autoincs');
  $new_server->dumpdb(\@databases, $vardir.'/server_data_'.$type.'_upgrade.dump');
  $new_server->normalizeDump($vardir.'/server_data_'.$type.'_upgrade.dump');

  #####
  $self->printStep("Getting ACL info from the new server after $type upgrade");
  my $new_grants;
  ($post_upgrade_status, $new_grants)= $self->collectAclData($new_server);

  if ($post_upgrade_status != STATUS_OK) {
    sayError("ACL info collection from the new server after $type upgrade failed");
    return $self->finalize($self->upgrade_or_recovery_failure(),[$new_server]);
  }

  #####
  $self->printStep("Shutting down the new server after $type upgrade");

  $post_upgrade_status= $new_server->stopServer;

  if ($post_upgrade_status != STATUS_OK) {
    sayError("Shutdown of the new server after $type upgrade failed");
    return $self->finalize(STATUS_SERVER_SHUTDOWN_FAILURE,[$new_server]);
  }

  #####
  $self->printStep("Comparing databases before and after $type upgrade");

  $post_upgrade_status= compare($vardir.'/server_schema_old.dump', $vardir.'/server_schema_'.$type.'_upgrade.dump');
  if ($post_upgrade_status != STATUS_OK) {
    sayError("Database structures differ after $type upgrade");
    system('diff -a -u '.$vardir.'/server_schema_old.dump'.' '.$vardir.'/server_schema_'.$type.'_upgrade.dump');
    return $self->finalize($self->upgrade_or_recovery_failure(),[$new_server]);
  }
  else {
    say("Structure dumps appear to be identical after $type upgrade");
  }

  $post_upgrade_status= compare($vardir.'/server_data_old.dump', $vardir.'/server_data_'.$type.'_upgrade.dump');
  if ($post_upgrade_status != STATUS_OK) {
    sayError("Data differs after $type upgrade");
    system('diff -a -u '.$vardir.'/server_data_old.dump'.' '.$vardir.'/server_data_'.$type.'_upgrade.dump');
    return $self->finalize($self->upgrade_or_recovery_failure(),[$new_server]);
  }
  else {
    say("Data dumps appear to be identical after $type upgrade");
  }

  $self->printStep("Comparing ACL data after $type upgrade");
  my $old_grants_copy= { %$old_grants };
  $self->normalizeGrants($old_server, $new_server, $old_grants_copy, $new_grants);
  $post_upgrade_status= $self->compareAclData($old_grants_copy,$new_grants);

  if ($post_upgrade_status != STATUS_OK) {
    sayError("ACL info collection or comparison after $type upgrade failed");
    return $self->finalize($self->upgrade_or_recovery_failure(),[$new_server]);
  }

  return $post_upgrade_status;
}

1;
