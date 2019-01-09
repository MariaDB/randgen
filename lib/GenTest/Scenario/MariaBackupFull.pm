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
# The module implements a full MariaBackup scenario
#
# The test starts the server, executes some flow on it, 
# performs backup in the middle, continues the test flow for a while,
# stops the server, restores the backup, starts the server again,
# performs a basic data check and executes some more flow.
#
########################################################################

package GenTest::Scenario::MariaBackupFull;

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
  my $self= $class->SUPER::new(@_);

  $self->printTitle('Full MariaBackup');
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

  my $gentest_pid= fork();
  if (not defined $gentest_pid) {
    sayError("Failed to fork for running the test flow");
    return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[$server]);
  }
  
  # The child will be running the test flow. The parent will be running
  # the backup in the middle, and while waiting, will be monitoring
  # the status of the test flow to notice if it exits prematurely.
  
  if ($gentest_pid > 0) {
    my $timeout= int($self->getTestDuration / 3);

    $self->printStep("Running initial test flow on the server");

    foreach (1..$timeout) {
      if (waitpid($gentest_pid, WNOHANG) == 0) {
        sleep 1;
      } 
      else {
        $status= $? >> 8;
        last;
      }
    }

    if ($status != STATUS_OK) {
      sayError("Test flow before the backup failed");
      return $self->finalize(STATUS_TEST_FAILURE,[$server]);
    }
    
    $self->printStep("Creating full backup");
    $cmd= "$mbackup --backup --target-dir=".$server->vardir."/backup/ --protocol=tcp --port=".$server->port." --user=".$server->user." 2>".$server->vardir."/mbackup_backup.log";
    say($cmd);
    system($cmd);
    $status= $? >> 8;

    if ($status != STATUS_OK) {
      sayError("Full backup failed");
      sayFile($server->vardir."/mbackup_backup.log");
      return $self->finalize(STATUS_BACKUP_FAILURE,[$server]);
    }

    $self->printStep("Continuing test flow after backup");

    foreach (1..$timeout) {
      if (waitpid($gentest_pid, WNOHANG) == 0) {
        sleep 1;
      } 
      else {
        $status= $? >> 8;
        last;
      }
    }

    if ($status != STATUS_OK) {
      sayError("Test flow after full failed");
      return $self->finalize(STATUS_BACKUP_FAILURE,[$server]);
    }
  }
  else {
    $gentest= $self->prepareGentest(1,
      {
        duration => int($self->getTestDuration * 2 / 3),
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

  #####
  $self->printStep("Preparing backup");
  $cmd= "$mbackup --prepare --target-dir=".$server->vardir."/backup/ --user=".$server->user." 2>".$server->vardir."/mbackup_prepare.log";
  say($cmd);
  system($cmd);
  $status= $? >> 8;

  if ($status != STATUS_OK) {
    sayError("Backup preparing failed");
    sayFile($server->vardir."/mbackup_prepare.log");
    return $self->finalize(STATUS_BACKUP_FAILURE,[$server]);
  }

  #####
  $self->printStep("Restoring backup");
  system("rm -rf ".$server->datadir);
  $cmd= "$mbackup --copy-back --target-dir=".$server->vardir."/backup/ --datadir=".$server->datadir." --user=".$server->user." 2>".$server->vardir."/mbackup_restore.log";
  say($cmd);
  system($cmd);
  $status= $? >> 8;

  if ($status != STATUS_OK) {
    sayError("Backup restore failed");
    sayFile($server->vardir."/mbackup_restore.log");
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
  $self->printStep("Running test flow on the server after restoring the backup");

  $gentest= $self->prepareGentest(1,
    {
      duration => int($self->getTestDuration / 3),
      dsn => [$server->dsn($self->getProperty('database'))],
      servers => [$server],
    },
    my $skip_gendata=1
  );
  $status= $gentest->run();
  
  if ($status != STATUS_OK) {
    sayError("Test flow on the server after restoring the backup failed");
    #####
    $self->printStep("Checking the server error log for known errors");

    if ($self->checkErrorLog($server) == STATUS_CUSTOM_OUTCOME) {
      $status= STATUS_CUSTOM_OUTCOME;
    }

    $self->setStatus($status);
    return $self->finalize($status,[$server])
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

1;
