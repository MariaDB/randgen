# Copyright (C) 2019 MariaDB Corporation Ab
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
# performs full backup and two incremental backups while doing it,
# stops the server, restores the last backup, starts the server again,
# performs a basic data check and executes some more flow.
#
########################################################################

package GenTest::Scenario::MariaBackupIncremental;

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

our $vardir;
our $end_time;

sub new {
  my $class= shift;
  my $self= $class->SUPER::new(@_);

  $self->printTitle('Incremental MariaBackup');
  return $self;
}

sub run {
  my $self= shift;
  my ($status, $server, $mbackup, $gentest, $cmd);

  $status= STATUS_OK;

  $server= $self->prepareServer(1,
    {
      vardir => ${$self->getProperty('vardir')}[0],
      port => ${$self->getProperty('port')}[0],
      valgrind => 0,
    }
  );
  
  $mbackup= $server->_find([$server->basedir],
                            osWindows()?["client/Debug","client/RelWithDebInfo","client/Release","bin"]:["client","bin"],
                            osWindows()?"mariabackup.exe":"mariabackup"
                          );

  unless ($mbackup) {
    sayError("Could not find MariaBackup");
    return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[$server]);
  }

  $vardir= $server->vardir;
  my $mbackup_target= $vardir.'/backup';

  say("-- Server info: --");
  say($server->version());
  $server->printServerOptions();

  #####
  $self->printStep("Starting the server");

  $status= $server->startServer;

  if ($status != STATUS_OK) {
    sayError("Server failed to start");
    return $self->finalize(STATUS_TEST_FAILURE,[]);
  }
  
  #####

  my $interval_between_backups= 30;

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
    $end_time= time() + $self->getTestDuration;

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
                last;
            }
          }
        }

        if ($backup_num == 0)
        {
            $self->printStep("Creating initial full backup");
            $status= run_mbackup_in_background("$mbackup --backup --target-dir=${mbackup_target}_0 --protocol=tcp --port=".$server->port." --user=".$server->user." > $vardir/mbackup_backup_0.log");
        } else {
            $self->printStep("Creating incremental backup #$backup_num");
            $status= run_mbackup_in_background("$mbackup --backup --target-dir=${mbackup_target}_${backup_num} --incremental-basedir=${mbackup_target}_".($backup_num-1)." --protocol=tcp --port=".$server->port." --user=".$server->user." >$vardir/mbackup_backup_${backup_num}.log");
        }
        if ($status == STATUS_OK) {
            say("Backup #$backup_num finished successfully");
        } else {
            sayError("Backup #backup_num failed: $status");
            sayFile("$vardir/mbackup_backup_${backup_num}.log");
            return $self->finalize(STATUS_TEST_FAILURE,[$server]);
        }

        $backup_num++;
    }
  }
  else {
    $self->printStep("Running test flow on the server");

    $gentest= $self->prepareGentest(1,
      {
        duration => $self->getTestDuration,
        dsn => [$server->dsn($self->getProperty('database'))],
        servers => [$server],
      }
    );
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

  say("Storing the backups before prepare attempt...");

  foreach my $b (0..$backup_num-1) {
      if (osWindows()) {
        system('xcopy "'.$mbackup_target.'_'.${b}.' '.$mbackup_target.'_before_prepare_'.${b}.'" /E /I /Q');
      } else {
        system("cp -r ${mbackup_target}_${b} ${mbackup_target}_before_prepare_${b}");
      }
  }

  #####
  $self->printStep("Preparing full backup");

  $cmd= "$mbackup --prepare --apply-log-only --innodb-file-io-threads=1 --target-dir=${mbackup_target}_0 --user=".$server->user." 2>$vardir/mbackup_prepare_0.log";
  say($cmd);
  system($cmd);
  $status= $? >> 8;

  if ($status != STATUS_OK) {
    sayError("Backup preparing failed");
    sayFile("$vardir/mbackup_prepare_0.log");
    return $self->finalize(STATUS_BACKUP_FAILURE,[$server]);
  }

  #####
  foreach my $b (1..$backup_num-1) {
      $self->printStep("Preparing incremental backup #${b}");

      $cmd= "$mbackup --prepare --apply-log-only --innodb-file-io-threads=1 --target-dir=${mbackup_target}_0 --incremental-dir=${mbackup_target}_${b} --user=".$server->user." 2>$vardir/mbackup_prepare_${b}.log";
      say($cmd);
      system($cmd);
      $status= $? >> 8;

      if ($status != STATUS_OK) {
        sayError("Backup preparing failed");
        sayFile("$vardir/mbackup_prepare_${b}.log");
        return $self->finalize(STATUS_BACKUP_FAILURE,[$server]);
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

  return $self->finalize($status,[]);
}

# The subroutine will return STATUS_OK (0) if the process finished successfully,
# non-zero positive exit code if it failed,
# and -1 if it hung
sub run_mbackup_in_background {
    my $cmd= shift;
    open(MBACKUP,">$vardir/mbackup_script") || die "Could not open $vardir/mbackup_script for writing: $!\n";
    print(MBACKUP "rm -f $vardir/mbackup_exit_code $vardir/mbackup_pid\n");
    print(MBACKUP "$cmd 2>&1 && echo \$? > $vardir/mbackup_exit_code &\n");
    print(MBACKUP "echo \$! > $vardir/mbackup_pid\n");
    close(MBACKUP);
    sayFile("$vardir/mbackup_script");
    system(". $vardir/mbackup_script");
    my $mbackup_pid=`cat $vardir/mbackup_pid`;
    chomp $mbackup_pid;
    my $wait_time= $end_time - time();
    $wait_time= 60 if $wait_time < 60;
    say("Waiting $wait_time sec for mariabackup with pid $mbackup_pid to finish");
    foreach (1 .. $wait_time)
    {
        if (kill(0, $mbackup_pid)) {
            sleep 1;
        }
        else {
            my $status=`cat $vardir/mbackup_exit_code`;
            chomp $status;
            return $status;
        }
    }
    sayError("Backup did not finish in due time");
    kill(6, $mbackup_pid);
    return -1;
}

1;
