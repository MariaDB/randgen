# Copyright (C) 2022, 2023 MariaDB
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
use GenTest::Scenario;
use GenTest::Scenario::Upgrade;
use Data::Dumper;
use File::Copy;
use File::Compare;

use DBServer::MariaDB;

my ($server, $old_server, $new_server, $databases, $vardir, $old_grants);
my ($old_tables, $old_columns, $old_indexes, $old_checksums_non_versioned, $old_checksums_versioned);

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

  #####
  # Prepare old server
  $old_server=  $self->prepareServer(1, my $is_active=1);
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

  $status= $server->stopServer;

  if ($status != STATUS_OK) {
    sayError("Shutdown of the old server failed");
    goto UPGRADE_END;
  }

  $status= $server->startServer;

  if ($status != STATUS_OK) {
    sayError("Old server failed to restart");
    goto UPGRADE_END;
  }

  # Dump all databases for further restoring
  if ($server->versionNumeric gt '101100') {
    $status= $server->dumpdb(undef, $vardir.'/all_db.dump',my $for_restoring=1,"--dump-history --force");
    $history_dump_supported= 1;
  } else {
    $status= $server->dumpdb(undef, $vardir.'/all_db.dump',my $for_restoring=1);
  }
  if ($status != STATUS_OK) {
    sayWarning("Database dump on the old server failed, but it was running with --force, so we will continue");
    $self->setStatus($status);
  }

  ($old_tables, $old_columns, $old_indexes, $old_checksums_non_versioned, $old_checksums_versioned)= get_data($server);

  #####
  $self->printStep("Creating full backup with MariaBackup");

  my $mbackup;
  my $buffer_pool_size= $server->serverVariable('innodb_buffer_pool_size') * 2;

  unless ($mbackup= $server->mariabackup()) {
    sayError("Could not find MariaBackup binary for the old server");
    $status= STATUS_ENVIRONMENT_FAILURE;
    goto UPGRADE_END;
  }

  if ($server->versionNumeric lt '100500') {
    # Workaround for MDEV-29943 (MariaBackup may lose a DML operation)
    # Adding a sleep period to avoid the race condition
    sleep(5);
  }
  my $mbackup_command= ($self->getProperty('rr') ? "rr record -h --output-trace-dir=$vardir/rr_profile_backup $mbackup" : $mbackup);
  $status= system("$mbackup_command --backup --target-dir=$vardir/mbackup --protocol=tcp --port=".$server->port." --user=".$server->user." >$vardir/mbackup_backup.log 2>&1");

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

  my $cmd= ($self->getProperty('rr') ? "rr record -h --output-trace-dir=$vardir/rr_profile_prepare $mbackup" : $mbackup)
    . " --use-memory=".($buffer_pool_size * 2)." --prepare --target-dir=$vardir/mbackup --user=".$server->user." 2>$vardir/mbackup_prepare.log 2>&1";
  say($cmd);
  system($cmd);
  $status= $? >> 8;

  if ($status == STATUS_OK) {
      say("Prepare of backup finished successfully");
  } else {
    sayFile("$vardir/mbackup_prepare.log");
    sayError("Backup preparing failed: $status");
    $status= STATUS_BACKUP_FAILURE;
    goto UPGRADE_END;
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
  $self->switch_to_new_server();
  $server= $new_server;

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

  $status= system($client_command.' < '.$vardir.'/all_db.dump');
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

  unless ($mbackup= $server->mariabackup()) {
    sayError("Could not find MariaBackup binary for the new server");
    $status= STATUS_ENVIRONMENT_FAILURE;
    goto MBACKUP_UPGRADE_END;
  }

  $self->printStep("Restoring mariabackup");
  system("rm -rf ".$server->datadir);
  $cmd= "$mbackup --copy-back --target-dir=$vardir/mbackup --datadir=".$server->datadir." --user=".$server->user." > $vardir/mbackup_restore.log 2>&1";
  say($cmd);
  $status= system($cmd);
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
  $self->setStatus($status);

UPGRADE_END:
  $self->setStatus($status);
  $self->printStep("RESULTS");
  if (scalar(@upgrade_errors)) {
    foreach (@upgrade_errors) { sayError($_) };
  } else {
    say("All upgrades succeeded");
  }
  return $self->finalize($status,[$server]);
}

######################################
# Checks performed after each upgrade
######################################

sub get_data {
  my ($server)= @_;
  my @databases= $server->nonSystemDatabases();
  my $databases= join ',', map { "'".$_."'" } @databases;
  my ($tables, $columns, $indexes, $checksums_versioned, $checksums_non_versioned);
  # We skip auto_increment value due to MDEV-13094 etc.
  $tables= $server->connection->query(
    "SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE, ENGINE, ROW_FORMAT, TABLE_COLLATION, CREATE_OPTIONS, TABLE_COMMENT ".
    "FROM INFORMATION_SCHEMA.TABLES ".
    "WHERE TABLE_SCHEMA IN ($databases)".
    "ORDER BY TABLE_SCHEMA, TABLE_NAME"
  );
  # Default for virtual columns can be wrong (MDEV-32077)
  # Views don't preserve virtual column attributes, so we select view columns separately (MDEV-32078)
  $columns= $server->connection->query(
    "SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, ORDINAL_POSITION, IF(IS_GENERATED='ALWAYS',NULL,COLUMN_DEFAULT), IS_NULLABLE, DATA_TYPE, ".
    "CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE, DATETIME_PRECISION, CHARACTER_SET_NAME, COLLATION_NAME, COLUMN_KEY, EXTRA, PRIVILEGES, COLUMN_COMMENT, IS_GENERATED ".
    "FROM INFORMATION_SCHEMA.COLUMNS c ".
    "WHERE TABLE_SCHEMA IN ('test') ".
    "AND NOT (SELECT TABLE_TYPE IN ('VIEW','SYSTEM VIEW') FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = c.TABLE_SCHEMA AND TABLE_NAME = c.TABLE_NAME) ".
    "UNION ".
    "SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, ORDINAL_POSITION, NULL, IS_NULLABLE, DATA_TYPE, ".
    "CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE, DATETIME_PRECISION, CHARACTER_SET_NAME, COLLATION_NAME, COLUMN_KEY, NULL, PRIVILEGES, COLUMN_COMMENT, NULL ".
    "FROM INFORMATION_SCHEMA.COLUMNS c ".
    "WHERE TABLE_SCHEMA IN ($databases) ".
    "AND (SELECT TABLE_TYPE IN ('VIEW','SYSTEM VIEW') FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = c.TABLE_SCHEMA AND TABLE_NAME = c.TABLE_NAME) ".
    "ORDER BY TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME"
  );
  $indexes= $server->connection->query(
    "SELECT TABLE_SCHEMA, INDEX_NAME, COLUMN_NAME, NON_UNIQUE, SEQ_IN_INDEX, INDEX_TYPE, COMMENT ".
    "FROM INFORMATION_SCHEMA.STATISTICS ".
    "WHERE TABLE_SCHEMA IN ($databases)".
    "ORDER BY TABLE_SCHEMA, TABLE_NAME, INDEX_NAME, COLUMN_NAME"
  );

  # Double and float make checksum non-deterministic (apparently), regardless the type of the upgrade,
  # so they are always excluded.
  # For dump upgrade before 10.11, historical rows of system versioned tables
  # could not be dumped, so the history was lost and table checksums would differ.
  # Thus we won't compare checksums for versioned tables when older versions are involved.
  # Virtual columns make the checksum non-deterministic (MDEV-32079).
  my $table_names_versioned= $server->connection->get_value(
      "SELECT GROUP_CONCAT(CONCAT('`',TABLE_SCHEMA,'`.`',TABLE_NAME,'`') ORDER BY 1 SEPARATOR ', ') ".
      "FROM INFORMATION_SCHEMA.TABLES ".
      "WHERE TABLE_SCHEMA IN ($databases) AND TABLE_TYPE = 'SYSTEM VERSIONED' ".
      "AND (TABLE_SCHEMA, TABLE_NAME) NOT IN (SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE DATA_TYPE IN ('double','float') OR IS_GENERATED != 'NEVER')"
  );
  my $table_names_non_versioned= $server->connection->get_value(
      "SELECT GROUP_CONCAT(CONCAT('`',TABLE_SCHEMA,'`.`',TABLE_NAME,'`') ORDER BY 1 SEPARATOR ', ') ".
      "FROM INFORMATION_SCHEMA.TABLES ".
      "WHERE TABLE_SCHEMA IN ($databases) AND TABLE_TYPE != 'SYSTEM VERSIONED' ".
      "AND (TABLE_SCHEMA, TABLE_NAME) NOT IN (SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE DATA_TYPE IN ('double','float') OR IS_GENERATED != 'NEVER')"
  );

  $checksums_versioned= $server->connection->query("CHECKSUM TABLE $table_names_versioned EXTENDED");
  $checksums_non_versioned= $server->connection->query("CHECKSUM TABLE $table_names_non_versioned EXTENDED");
  return ($tables, $columns, $indexes, $checksums_non_versioned, $checksums_versioned);
}


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
  my ($tables, $columns, $indexes, $checksums_non_versioned, $checksums_versioned)= get_data($new_server);

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
  my %old_data= (
    tables => $old_tables,
    columns => $old_columns,
    indexes => $old_indexes,
    checksums_non_versioned => $old_checksums_non_versioned,
    checksums_versioned => $old_checksums_versioned,
  );
  my %new_data= (
    tables => $tables,
    columns => $columns,
    indexes => $indexes,
    checksums_non_versioned => $checksums_non_versioned,
    checksums_versioned => $checksums_versioned,
  );
  my $data_status= STATUS_OK;
  foreach my $d (sort keys %old_data) {
    next if (($d eq 'checksums_versioned') and ($type eq 'dump') and (($old_server->versionNumeric lt '101101') or ($new_server->versionNumeric lt '101101')));
    my $old= Dumper $old_data{$d};
    my $new= Dumper $new_data{$d};
    if ($old ne $new) {
      $data_status= $self->upgrade_or_recovery_failure();
      $post_upgrade_status= $data_status if $data_status > $post_upgrade_status;
      unless (-e $vardir.'/old_'.$d.'.dump') {
        if (open(DT, '>'.$vardir.'/old_'.$d.'.dump')) {
          print DT $old;
          close(DT);
        } else {
          sayError('Could not write old '.$d." into file: $!");
        }
      }
      if (open(DT, '>'.$vardir.'/'.$type.'_'.$d.'.dump')) {
        print DT $new;
        close(DT);
      } else {
        sayError('Could not write '.$type.' '.$d." into file: $!");
      }
      sayError("Old and new $d differ after $type upgrade");
      if (-e $vardir.'/old_'.$d.'.dump' and -e $vardir.'/'.$type.'_'.$d.'.dump') {
        system("diff -a -U20 ".$vardir.'/old_'.$d.'.dump'." ".$vardir.'/'.$type.'_'.$d.'.dump');
      }
    }
  }
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
