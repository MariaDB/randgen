# Copyright (C) 2022, 2024 MariaDB
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
# if necessary, checks the tables, compares the new schema/data info with the old one.
# Then it starts the new server again on a clean datadir,
# loads the dump from the old server runs mysql_upgrade if necessary,
# compares the new schema/data info with the old one.
# Then it starts the new server again on a clean datadir,
# restores mariabackup backup, stores the schema/data info,
# compares the new schema/data info with the old one.
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
use Constants::MariaDBErrorCodes;
use GenTest::Scenario;
use GenTest::Scenario::Upgrade;
use Data::Dumper;
use File::Copy;
use File::Compare;

use DBServer::MariaDB;

my ($server, $old_server, $new_server, $databases, $vardir, $old_grants);
my (%old_data, %new_data);

# Before 10.11, mysqldump could not store historical rows
# of system-versioned tables. It sets some limitation on data comparison.
# The flag will be set according to server versions
my $history_dump_supported= 0;

sub new {
  my $class= shift;
  my $self= $class->SUPER::new(@_);
  return $self;
}

sub run {
  my $self= shift;

  my $status= STATUS_OK;
  my @upgrade_errors= ();
  # We may skip certain upgrades due to non-fatal errors during preparation phase
  # Dump upgrade may be skipped e.g. if dump on the old server failed
  my $skip_dump_upgrade= 0;
  # Backup upgrade may be skipped e.g. if mariabackup binary was not found
  my $skip_backup_upgrade= 0;

  #####
  # Prepare old server
  $old_server= $self->prepareServer(1, my $is_active=1);
  unless ($old_server) {
    sayError("Could not initialize the old server");
    $self->setStatus(STATUS_ENVIRONMENT_FAILURE);
    goto FINALIZE;
  }
  my $server= $old_server;
  $server->backupDatadir($server->datadir."_clean");
  $vardir=$server->vardir;

  #####
  $self->printStep("Starting the old server");

  $status= $server->startServer;

  if ($status != STATUS_OK) {
    sayError("Old server failed to start");
    goto UPGRADE_END;
  }

  #####
  $self->printStep("Generating data on the old server");

  $status= $self->generateData(1);

  if ($status != STATUS_OK) {
    sayError("Data generation on the old server failed");
    goto UPGRADE_END;
  }

  #####
  $self->printStep("Running test flow on the old server");

  $self->setProperty('duration',int($self->getProperty('duration')/2));
  $self->createTestRunner();
  $status= $self->runTestFlow();

  if ($status != STATUS_OK) {
    sayError("Test flow on the old server failed");
    goto UPGRADE_END;
  }

  #####
  $self->printStep("Restarting the old server and dumping databases");

  # We'll ignore non-critical status for the old server
  $status= $server->stopServer;
  if ($status >= STATUS_CRITICAL_FAILURE) {
    sayError("Shutdown of the old server failed");
    goto UPGRADE_END;
  }

  $status= $server->startServer;

  if ($status != STATUS_OK) {
    sayError("Old server failed to restart");
    goto UPGRADE_END;
  }

  # Dump all databases for further restoring.
  if ($server->versionNumeric gt '101100') {
    $status= $server->dumpdb(undef, $vardir.'/all_db.dump',my $for_restoring=1,"--dump-history");
    $history_dump_supported= 1;
  } else {
    $status= $server->dumpdb(undef, $vardir.'/all_db.dump',my $for_restoring=1);
  }
  if ($status != STATUS_OK) {
    sayError("Database dump on the old server failed, dump upgrade will be skipped");
    push @upgrade_errors, "DUMP upgrade skipped because database dump on the old server failed";
    $self->setStatus(STATUS_UPGRADE_FAILURE);
    $skip_dump_upgrade= 1;
  }

  ($status, %old_data)= $self->get_data($server);
  unless ($status == STATUS_OK) {
    sayError("Error occurred upon collecting data from the old server");
    $self->setSTatus($status);
    goto UPGRADE_END;
  }

  #####
  $self->printStep("Creating full backup with MariaBackup");

  my ($mbackup, $mbackup_command, $cmd);
  my $buffer_pool_size= $server->serverVariable('innodb_buffer_pool_size') * 2;

  if ($mbackup= $server->mariabackup()) {

    if ($server->versionNumeric lt '100500') {
      # Workaround for MDEV-29943 (MariaBackup may lose a DML operation)
      # Adding a sleep period to avoid the race condition
      sleep(5);
    }
    $mbackup_command= ($self->getProperty('rr') ? "rr record -h --output-trace-dir=$vardir/rr_profile_backup $mbackup" : $mbackup);
    $status= system("LD_LIBRARY_PATH=\$MSAN_LIBS:\$LD_LIBRARY_PATH $mbackup_command --backup --skip-ssl --target-dir=$vardir/mbackup --protocol=tcp --port=".$server->port." --user=".$server->user." >$vardir/mbackup_backup.log 2>&1");

    if ($status == STATUS_OK) {
        say("MariaBackup ran finished successfully");
    } else {
        sayFile("$vardir/mbackup_backup.log");
        sayError("MariaBackup failed: $status");
        $status= STATUS_BACKUP_FAILURE;
        goto UPGRADE_END;
    }

    $self->printStep("Preparing backup");

    say("Storing the backup before prepare attempt...");
    if (osWindows()) {
      system("xcopy $vardir/mbackup $vardir/mbackup_before_prepare /E /I /Q");
    } else {
      system("cp -r $vardir/mbackup $vardir/mbackup_before_prepare");
    }

    $cmd= ($self->getProperty('rr') ? "rr record -h --output-trace-dir=$vardir/rr_profile_prepare $mbackup" : $mbackup)
      . " --use-memory=".($buffer_pool_size * 2)." --prepare --target-dir=$vardir/mbackup --user=".$server->user." 2>$vardir/mbackup_prepare.log 2>&1";
    say($cmd);
    system("LD_LIBRARY_PATH=\$MSAN_LIBS:\$LD_LIBRARY_PATH $cmd");
    $status= $? >> 8;

    if ($status == STATUS_OK) {
        say("Prepare of backup finished successfully");
    } else {
      sayFile("$vardir/mbackup_prepare.log");
      sayError("Backup preparing failed: $status");
      $status= STATUS_BACKUP_FAILURE;
      goto UPGRADE_END;
    }
  } else {
    sayError("Could not find MariaBackup binary for the old server, mariabackup upgrade will be skipped");
    $skip_backup_upgrade= 1;
    $self->setStatus(STATUS_POSSIBLE_FAILURE);
  }

  #####
  $self->printStep("Getting ACL info from the old server");

  ($status, $old_grants)= $self->collectAclData($server);

  if ($status != STATUS_OK) {
    sayError("ACL info collection from the old server failed");
    goto UPGRADE_END;
  }

  #####
  $self->printStep("Stopping the old server");

  $status= $server->stopServer;

  if ($status != STATUS_OK) {
    sayError("Shutdown of the old server failed");
    goto UPGRADE_END;
  }

  #####
  $self->printStep("Checking the old server log for fatal errors after shutdown");

  $status= $self->checkErrorLog($server, {CrashOnly => 1});

  if ($status != STATUS_OK) {
    sayError("Found fatal errors in the log, old server shutdown has apparently failed");
    goto UPGRADE_END;
  }
  # Back up data directory and error log from the old server
  system ('cp -r '.$server->datadir.' '.$server->datadir.'_orig');
  system ('mv '.$server->errorlog.' '.$server->errorlog.'_orig');

  ######################################################################

  # Point server_specific to the new server
  $new_server=  $self->prepare_new_server($old_server);
  unless ($new_server) {
    sayError("Could not initialize the new server");
    $self->setStatus(STATUS_ENVIRONMENT_FAILURE);
    goto FINALIZE;
  }
  $self->switch_to_new_server();
  $server= $new_server;

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
  }

LIVE_UPGRADE_END:
  # In case it wasn't stopped before
  $server->stopServer;
  # Back up data directory from the live upgrade
  system ('mv '.$server->datadir.' '.$server->datadir.'_live_upgrade');
  system ('mv '.$server->errorlog.' '.$server->errorlog.'_live_upgrade');
  $self->setStatus($status);

  #######################
  # Dump upgrade
  #######################

  #####
  $self->printStep("DUMP UPGRADE: Starting the new server on clean datadir for mysqldump upgrade");
  if ($skip_dump_upgrade) {
    sayError("Dump upgrade will be skipped due to the previous failures");
    goto DUMP_UPGRADE_END;
  }

  # Restore clean datadir for mysqldump upgrade
  system ('mv '.$old_server->datadir.'_clean '.$server->datadir);

  # enforce-storage-engine needs to be unset, otherwise the dump won't load
  my $enforced_stored= $self->getServerStartupOption(1,'enforce-storage-engine');
  $server->addServerOptions(['--enforce-storage-engine=']) if ($enforced_stored);
  $status= $self->start_for_upgrade('dump');

  if ($status != STATUS_OK) {
    sayError("New server failed to restart for mysqldump upgrade");
    push @upgrade_errors, "DUMP upgrade failed: new server failed to start for upgrade";
    goto DUMP_UPGRADE_END;
  }

  #####
  $self->printStep("Restoring the dump of all databases");
  my $client_command= $server->client.' -uroot --host=127.0.0.1 --protocol=tcp --port='.$server->port;

  $status= system("LD_LIBRARY_PATH=\$MSAN_LIBS:\$LD_LIBRARY_PATH ".$client_command.' < '.$vardir.'/all_db.dump');
  if ($status != STATUS_OK) {
    sayError("All databases' schema dump failed to load");
    $self->setStatus($self->upgrade_or_recovery_failure());

    $status= $self->checkErrorLog($server);
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
  # In case it wasn't stopped before
  $server->stopServer;
  # Back up data directory from the live upgrade
  system ('mv '.$server->datadir.' '.$server->datadir.'_dump_upgrade');
  system ('mv '.$server->errorlog.' '.$server->errorlog.'_dump_upgrade');
  $self->setStatus($status);

  $server->addServerOptions(['--enforce-storage-engine='.$enforced_stored]) if ($enforced_stored);

  #######################
  # MariaBackup upgrade
  #######################

  $self->printStep("BACKUP UPGRADE: Starting the new server on restored mariabackup backup");

  if ($skip_backup_upgrade) {
    sayError("MariaBackup upgrade will be skipped due to previous issues");
    goto MBACKUP_UPGRADE_END;
  }

  unless ($mbackup= $server->mariabackup()) {
    sayError("Could not find MariaBackup binary for the new server");
    $status= STATUS_ENVIRONMENT_FAILURE;
    goto MBACKUP_UPGRADE_END;
  }

  $self->printStep("Restoring mariabackup");
  system("rm -rf ".$server->datadir);
  $cmd= "$mbackup --copy-back --target-dir=$vardir/mbackup --datadir=".$server->datadir." --user=".$server->user." > $vardir/mbackup_restore.log 2>&1";
  say($cmd);
  $status= system("LD_LIBRARY_PATH=\$MSAN_LIBS:\$LD_LIBRARY_PATH $cmd");
  if ($status != STATUS_OK) {
    $status= $self->upgrade_or_recovery_failure();
    sayFile("$vardir/mbackup_restore.log");
    sayError("Backup failed to restore");
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
  # In case it wasn't stopped before
  $server->stopServer;
  # Back up data directory from the mariabackup upgrade
  system ('mv '.$server->datadir.' '.$server->datadir.'_mbackup_upgrade');
  system ('mv '.$server->errorlog.' '.$server->errorlog.'_mbackup_upgrade');

UPGRADE_END:
  $self->setStatus($status);
  $self->printStep("RESULTS");
  if (scalar(@upgrade_errors)) {
    foreach (@upgrade_errors) { sayError($_) };
  } else {
    say("All upgrades succeeded");
  }
FINALIZE:
  return $self->finalize($self->getStatus,[$server]);
}

sub start_for_upgrade {
  my ($self, $type)= @_;

  my $start_status= $new_server->startServer;

  if ($start_status != STATUS_OK) {
    sayError("New server failed to start upon $type upgrade");
    # Error log might indicate known bugs which will affect the exit code
    $start_status= $self->checkErrorLog($new_server);
    # ... but even if it's a known error, we cannot proceed without the server
    $new_server->connection->execute("SET GLOBAL max_statement_time=0, tx_read_only=0");
    return $self->finalize($self->upgrade_or_recovery_failure(),[$new_server]);
  }

  return $start_status;
}

sub post_upgrade {
  my ($self, $type, $system_versioning_history_lost)= @_;

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
      return $post_upgrade_status;
    }
  }

  #####
  if ( ($old_server->majorVersion ne $new_server->majorVersion)
        # For cross-grades between CS and ES mariadb-upgrade should always be run
        or ($old_server->enterprise() != $new_server->enterprise())
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
        return $post_upgrade_status;
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
    return $post_upgrade_status;
  }

  #####
  $self->printStep("Collecting data from the new server after $type upgrade");
  my ($status, %new_data)= $self->get_data($new_server);
  if ($status != STATUS_OK) {
    sayError("Error occurred upon collecting data from the new server after $type upgrade");
    return $status;
  }

  #####
  $self->printStep("Getting ACL info from the new server after $type upgrade");
  my $new_grants;
  ($post_upgrade_status, $new_grants)= $self->collectAclData($new_server);

  if ($post_upgrade_status != STATUS_OK) {
    sayError("ACL info collection from the new server after $type upgrade failed");
    return $post_upgrade_status;
  }

  #####
  $self->printStep("Shutting down the new server after $type upgrade");

  $post_upgrade_status= $new_server->stopServer;

  if ($post_upgrade_status != STATUS_OK) {
    sayError("Shutdown of the new server after $type upgrade failed");
    return $post_upgrade_status;
  }

  #####
  $self->printStep("Comparing databases before and after $type upgrade");
  my $data_status= $self->compare_data(\%old_data, \%new_data, $vardir, "${type}-upgrade");
  if ($data_status != STATUS_OK) {
    $data_status= $self->upgrade_or_recovery_failure();
  }
  $post_upgrade_status= $data_status if $data_status > $post_upgrade_status;
  $self->printStep("Comparing ACL data after $type upgrade");
  my $old_grants_copy= { %$old_grants };
  $self->normalizeGrants($old_server, $new_server, $old_grants_copy, $new_grants);
  $data_status= $self->compareAclData($old_grants_copy,$new_grants);

  if ($data_status != STATUS_OK) {
    sayError("ACL info collection or comparison after $type upgrade failed");
    $post_upgrade_status= $data_status if $data_status > $post_upgrade_status;
  }
  return $post_upgrade_status;
}

1;
