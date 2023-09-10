# Copyright (C) 2019, 2023 MariaDB
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
# The module implements incremental MariaBackup scenario
#
# The test starts the server, executes some flow on it,
# performs some incremental backups while the test flow is running,
# stops the server, restores the all the backups,
# starts the server and runs the checks
#
########################################################################

package GenTest::Scenario::MariaBackupIncremental;

require Exporter;
@ISA = qw(GenTest::Scenario::MariaBackup);

use strict;
use GenUtil;
use GenTest;
use GenTest::TestRunner;
use GenTest::Properties;
use Constants;
use GenTest::Scenario;
use GenTest::Scenario::MariaBackup;
use Data::Dumper;
use File::Copy;
use File::Compare;
use POSIX;

use DBServer::MariaDB;

our $vardir;
our $end_time;

sub new {
  my $class= shift;
  my $self= $class->SUPER::new(@_);
  $self->printSubtitle('Incremental backup');
  return $self;
}

sub run {
  my $self= shift;
  my ($status, $server, $mbackup, $gentest, $cmd, $buffer_pool_size);

  $status= STATUS_OK;

  #####

  $self->printStep("Starting the server");

  $server= $self->prepare_server();
  $status= $server->startServer;

  if ($status != STATUS_OK) {
    sayError("Server failed to start");
    $status= STATUS_SERVER_STARTUP_FAILURE if $status < STATUS_SERVER_STARTUP_FAILURE;
    goto FINALIZE;
  }

  #####
  $self->printStep("Generating test data");
  $self->generateData();

  if ($status != STATUS_OK) {
    sayError("Data generation failed");
    goto FINALIZE;
  }
  #####

  unless ($mbackup= $server->mariabackup) {
    sayError("Could not find MariaBackup binary");
    $status= STATUS_ENVIRONMENT_FAILURE if $status < STATUS_ENVIRONMENT_FAILURE;
    goto FINALIZE;
  }

  $vardir= $server->vardir;
  my $mbackup_target= $vardir.'/backup';

  my $interval_between_backups= $self->mbackup_backup_interval;

  $self->createTestRunner();

  my $gentest_pid= fork();
  if (not defined $gentest_pid) {
    sayError("Failed to fork for running the test flow");
    $status= STATUS_ENVIRONMENT_FAILURE if $status < STATUS_ENVIRONMENT_FAILURE;
    goto FINALIZE;
  }

  # The child will be running the test flow. The parent will be running
  # the backup in the middle, and while waiting, will be monitoring
  # the status of the test flow to notice if it exits prematurely.

  my $backup_num= 0;

  if ($gentest_pid > 0)
  {
    $end_time= time() + $self->getProperty('duration');
    # Test flow can finish (successfully) before end_time, e.g.
    # due to the exceeded number of queries.
    my $test_flow_finished= 0;

  BACKUPLOOP:
    while (time() < $end_time - $interval_between_backups)
    {
      if (not $test_flow_finished) {
        foreach (1..$interval_between_backups) {
          if (waitpid($gentest_pid, WNOHANG) == 0) {
            sleep 1;
          }
          else {
            $status= $? >> 8;
            $test_flow_finished= 1;
            if ($status != STATUS_OK) {
              sayError("Test flow before the backup failed");
              goto FINALIZE;
            } else {
                last;
                say("Test flow finished, take the backup now");
            }
          }
        }
      } elsif ($backup_num < 2) {
        say("The test flow has finished, but we need at least 2 backups for the test");
        sleep($interval_between_backups);
      } else {
        # If the test is finished and we have 2 backups, we can stop
        last BACKUPLOOP;
      }

      my $mbackup_command= ($self->getProperty('rr') ? "rr record -h --output-trace-dir=$vardir/rr_profile_backup_${backup_num} $mbackup" : $mbackup);
      if ($backup_num == 0)
      {
          $self->printStep("Creating initial full backup");
          $status= $self->run_mbackup_in_background("$mbackup_command --backup --target-dir=${mbackup_target}_0 --protocol=tcp --port=".$server->port." --user=".$server->user." > $vardir/mbackup_backup_0.log", $end_time);
      } else {
          $self->printStep("Creating incremental backup #$backup_num");
          $status= $self->run_mbackup_in_background("$mbackup_command --backup --target-dir=${mbackup_target}_${backup_num} --incremental-basedir=${mbackup_target}_".($backup_num-1)." --protocol=tcp --port=".$server->port." --user=".$server->user." >$vardir/mbackup_backup_${backup_num}.log", $end_time);
      }
      if ($status == STATUS_OK) {
          say("Backup #$backup_num finished successfully");
      } else {
          sayError("Backup #$backup_num failed: $status");
          sayFile("$vardir/mbackup_backup_${backup_num}.log");
          $status= STATUS_BACKUP_FAILURE if $status < STATUS_BACKUP_FAILURE;
          goto FINALIZE;
      }

      $backup_num++;
    }
  }
  else {
    $self->printStep("Running test flow on the server");
    $status= $self->runTestFlow();
    exit $status;
  }

  #####
  $self->printStep("Stopping the server");

  $status= $server->startPlannedDowntime('clean',-1);

  if ($status != STATUS_OK) {
    sayError("Server shutdown failed");
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
  $server->endPlannedDowntime();
  $self->printStep("Checking the server log for fatal errors after shutdown");

  $status= $self->checkErrorLog($server, {CrashOnly => 1});

  if ($status != STATUS_OK) {
    sayError("Found fatal errors in the log, server shutdown has apparently failed");
    $status= STATUS_DATABASE_CORRUPTION if $status < STATUS_DATABASE_CORRUPTION;
    goto FINALIZE;
  }

  #####
  $self->printStep("Backing up data directory before restart");

  $server->backupDatadir($server->datadir."_orig");
  move($server->errorlog, $server->errorlog.'_orig');
  # We'll need it for --prepare (--use-memory)
  # Due to MDEV-19176, a bigger value is required
  $buffer_pool_size= $server->serverVariable('innodb_buffer_pool_size') * 2;

  say("Storing the backup before prepare attempt...");

  foreach my $b (0..$backup_num-1) {
      if (osWindows()) {
        system('xcopy "'.$mbackup_target.'_'.${b}.' '.$mbackup_target.'_before_prepare_'.${b}.'" /E /I /Q');
      } else {
        system("cp -r ${mbackup_target}_${b} ${mbackup_target}_before_prepare_${b}");
      }
  }

  #####
  $self->printStep("Preparing full backup");

  # The option is only needed and supported in 10.1
  my $apply_log_only_option= ($server->versionNumeric() ge '100200' ? '' : '--apply-log-only');

  $cmd= ($self->getProperty('rr') ? "rr record -h --output-trace-dir=$vardir/rr_profile_prepare_0 $mbackup" : $mbackup)
    . " --prepare --use-memory=$buffer_pool_size $apply_log_only_option --innodb-file-io-threads=1 --target-dir=${mbackup_target}_0 --user=".$server->user." 2>$vardir/mbackup_prepare_0.log";
  say($cmd);
  system($cmd);
  $status= $? >> 8;

  if ($status != STATUS_OK) {
    sayError("Backup preparing failed");
    sayFile("$vardir/mbackup_prepare_0.log");
    $status= STATUS_BACKUP_FAILURE if $status < STATUS_BACKUP_FAILURE;
    goto FINALIZE;
  }

  #####
  foreach my $b (1..$backup_num-1) {
      $self->printStep("Preparing incremental backup #${b}");

      $cmd= ($self->getProperty('rr') ? "rr record -h --output-trace-dir=$vardir/rr_profile_prepare_$b $mbackup" : $mbackup)
        . " --prepare --use-memory=$buffer_pool_size $apply_log_only_option --innodb-file-io-threads=1 --target-dir=${mbackup_target}_0 --incremental-dir=${mbackup_target}_${b} --user=".$server->user." 2>$vardir/mbackup_prepare_${b}.log";
      say($cmd);
      system($cmd);
      $status= $? >> 8;

      if ($status != STATUS_OK) {
        sayError("Backup preparing failed");
        sayFile("$vardir/mbackup_prepare_${b}.log");
        $status= STATUS_BACKUP_FAILURE if $status < STATUS_BACKUP_FAILURE;
        goto FINALIZE;
      }
  }

  #####
  $self->printStep("Restoring backup");
  system("rm -rf ".$server->datadir);
  $cmd= "$mbackup --copy-back --target-dir=${mbackup_target}_0 --datadir=".$server->datadir." --user=".$server->user." 2>$vardir/mbackup_restore_${b}.log";
  say($cmd);
  system($cmd);
  $status= $? >> 8;

  if ($status != STATUS_OK) {
    sayError("Backup restore failed");
    sayFile("$vardir/mbackup_restore_${b}.log");
    $status= STATUS_BACKUP_FAILURE if $status < STATUS_BACKUP_FAILURE;
    goto FINALIZE;
  }

  #####
  $self->printStep("Restarting the server");

  $status= $server->startServer;

  if ($status != STATUS_OK) {
    sayError("Server failed to start after backup restoration");
    # Error log might indicate known bugs which will affect the exit code
    $status= $self->checkErrorLog($server);
    # ... but even if it's a known error, we cannot proceed without the server
    goto FINALIZE;
  }

  #####
  $self->printStep("Checking the server error log for errors after restart");

  $status= $self->checkErrorLog($server);

  if ($status != STATUS_OK) {
    # Error log can show known errors. We want to update
    # the global status, but don't want to exit prematurely
    $self->setStatus($status);
    if ($status > STATUS_CUSTOM_OUTCOME) {
      sayError("Found errors in the log, restart has apparently failed");
      $status= STATUS_BACKUP_FAILURE if $status < STATUS_BACKUP_FAILURE;
      goto FINALIZE;
    }
  }

  #####
  $self->printStep("Checking the database state after restore and restart");

  $status= $server->checkDatabaseIntegrity;

  if ($status != STATUS_OK) {
    sayError("Database appears to be corrupt after restoring the backup");
    $status= STATUS_BACKUP_FAILURE if $status < STATUS_BACKUP_FAILURE;
    goto FINALIZE;
  }

FINALIZE:
  return $self->finalize($status,[$server]);
}

1;
