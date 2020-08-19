# Copyright (C) 2019, 2020 MariaDB Corporation Ab
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
# The module implements a full MariaBackup scenario
#
# The test starts the server, executes some flow on it, 
# performs some backup in the middle while the test flow is running,
# stops the server, restores the backups one by one,
# each time starting the server and running the checks
#
########################################################################

package GenTest::Scenario::MariaBackupFull;

require Exporter;
@ISA = qw(GenTest::Scenario::MariaBackup);

use strict;
use DBI;
use GenTest;
use GenTest::App::GenTest;
use GenTest::Properties;
use GenTest::Constants;
use GenTest::Scenario;
use GenTest::Scenario::MariaBackup;
use Data::Dumper;
use File::Copy;
use File::Compare;
use POSIX;

use DBServer::MySQL::MySQLd;

our $vardir;
our $end_time;

sub new {
  my $class= shift;
  my $self= $class->SUPER::new(@_);

  $self->printTitle('Full MariaBackup');
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
    return $self->finalize(STATUS_TEST_FAILURE,[]);
  }
  
  #####

  unless ($mbackup= $self->mbackup_binary) {
    sayError("Could not find MariaBackup binary");
    return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[$server]);
  }

  $vardir= $server->vardir;
  my $mbackup_target= $vardir.'/backup';

  my $interval_between_backups= $self->mbackup_backup_interval;

  my $gentest_pid= fork();
  if (not defined $gentest_pid) {
    sayError("Failed to fork for running the test flow");
    return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[$server]);
  }
  
  # The child will be running the test flow. The parent will be running
  # the backup in the middle, and while waiting, will be monitoring
  # the status of the test flow to notice if it exits prematurely.
  
  my $backup_num= 0;

  if ($gentest_pid > 0)
  {
    $end_time= time() + $self->getProperty('duration');


    while (time() < $end_time - $interval_between_backups)
    {
        foreach (1..$interval_between_backups) {
          if (waitpid($gentest_pid, WNOHANG) == 0) {
            sleep 1;
          }
          else {
            $status= $? >> 8;
            if ($status != STATUS_OK) {
              sayError("Test flow before the backup failed");
              return $self->finalize(STATUS_TEST_FAILURE,[$server]);
            } else {
                last BACKUP;
            }
          }
        }

        $backup_num++;
        $self->printStep("Creating full backup #$backup_num");
        my $mbackup_command= ($self->getProperty('rr') ? "rr record --output-trace-dir=$vardir/rr_profile_backup_${backup_num} $mbackup" : $mbackup);
        $status= $self->run_mbackup_in_background("$mbackup_command --backup --target-dir=${mbackup_target}_${backup_num} --protocol=tcp --port=".$server->port." --user=".$server->user." >$vardir/mbackup_backup_${backup_num}.log", $end_time);

        if ($status == STATUS_OK) {
            say("Backup #$backup_num finished successfully");
        } else {
            sayError("Backup #$backup_num failed: $status");
            sayFile("$vardir/mbackup_backup_${backup_num}.log");
            return $self->finalize(STATUS_TEST_FAILURE,[$server]);
        }
    }
  }
  else {
    $self->printStep("Running test flow on the server");
    $gentest= GenTest::App::GenTest->new(config => $self->getProperties());
    my $res= $gentest->run();
    exit $res;
  }

  #####
  $self->printStep("Stopping the server");

  $status= $server->stopServer;

  if ($status != STATUS_OK) {
    sayError("Server shutdown failed");
    return $self->finalize(STATUS_BACKUP_FAILURE,[$server]);
  }

  waitpid($gentest_pid, 0);

  #####
  $self->printStep("Checking the server log for fatal errors after shutdown");

  $status= $self->checkErrorLog($server, {CrashOnly => 1});

  if ($status != STATUS_OK) {
    sayError("Found fatal errors in the log, server shutdown has apparently failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$server]);
  }

  #####
  $self->printStep("Backing up data directory before restart");

  $server->backupDatadir($server->datadir."_orig");
  move($server->errorlog, $server->errorlog.'_orig');
  # We'll need it for --prepare (--use-memory)
  # Due to MDEV-19176, a bigger value is required
  $buffer_pool_size= $server->serverVariable('innodb_buffer_pool_size') * 2;

  foreach my $b (1..$backup_num) {

      #####
      $self->printStep("Preparing backup #$b");

      say("Storing the backup before prepare attempt...");
      if (osWindows()) {
        system("xcopy ${mbackup_target}_${b} ${mbackup_target}_${b}_before_prepare /E /I /Q");
      } else {
        system("cp -r ${mbackup_target}_${b} ${mbackup_target}_${b}_before_prepare");
      }

      $cmd= ($self->getProperty('rr') ? "rr record --output-trace-dir=$vardir/rr_profile_prepare_$b $mbackup" : $mbackup)
        . " --use-memory=$buffer_pool_size --prepare --target-dir=${mbackup_target}_${b} --user=".$server->user." 2>$vardir/mbackup_prepare_${b}.log";
      say($cmd);
      system($cmd);
      $status= $? >> 8;

      if ($status != STATUS_OK) {
        sayError("Backup preparing failed");
        sayFile("$vardir/mbackup_prepare_${b}.log");
        return $self->finalize(STATUS_BACKUP_FAILURE,[$server]);
      }

      #####
      $self->printStep("Restoring backup #$b");
      system("rm -rf ".$server->datadir);
      $cmd= "$mbackup --copy-back --target-dir=${mbackup_target}_${b} --datadir=".$server->datadir." --user=".$server->user." 2>$vardir/mbackup_restore_${b}.log";
      say($cmd);
      system($cmd);
      $status= $? >> 8;

      if ($status != STATUS_OK) {
        sayError("Backup restore failed");
        sayFile("$vardir/mbackup_restore_${b}.log");
        return $self->finalize(STATUS_BACKUP_FAILURE,[$server]);
      }


      #####
      $self->printStep("Restarting the server");

      $status= $server->startServer;

      if ($status != STATUS_OK) {
        sayError("Server failed to start after backup restoration");
        # Error log might indicate known bugs which will affect the exit code
        $status= $self->checkErrorLog($server);
        # ... but even if it's a known error, we cannot proceed without the server
        return $self->finalize($status,[$server]);
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
          return $self->finalize(STATUS_BACKUP_FAILURE,[$server]);
        }
      }

      #####
      $self->printStep("Checking the database state after restore and restart");

      $status= $server->checkDatabaseIntegrity;

      if ($status != STATUS_OK) {
        sayError("Database appears to be corrupt after restoring the backup");
        return $self->finalize(STATUS_BACKUP_FAILURE,[$server]);
      }

      #####
      $self->printStep("Stopping the server");

      $status= $server->stopServer;

      if ($status != STATUS_OK) {
        sayError("Server shutdown failed");
        return $self->finalize(STATUS_BACKUP_FAILURE,[$server]);
      }
  }

  return $self->finalize($status,[]);
}

1;
