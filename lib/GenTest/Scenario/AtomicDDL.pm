# Copyright 2020 MariaDB Corporation Ab
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
# The module implements a crash recovery scenario for Atomic DDL
#
########################################################################

package GenTest::Scenario::AtomicDDL;

require Exporter;
@ISA = qw(GenTest::Scenario::Upgrade);

use strict;
use DBI;
use GenTest;
use GenTest::App::GenTest;
use GenTest::Properties;
use GenTest::Constants;
use GenTest::Scenario;
use GenTest::Scenario::Upgrade;
use GenTest::Random;
use Data::Dumper;
use File::Copy;
use File::Compare;
use POSIX;

use DBServer::MySQL::MySQLd;

sub new {
  my $class= shift;
  my $self= $class->SUPER::new(@_);

  $self->printTitle('Atomic DDL');
  return $self;
}

sub run {
  my $self= shift;
  my ($status, $server, $binlog, $databases, $general_log_file);
  my ($datadir, $datadir_before_recovery, $datadir_restored_binlog);

  my $prng = GenTest::Random->new( seed => $self->getProperty('seed') );

  $status= STATUS_OK;

  #####
  # Prepare servers

  $server= $self->prepare_servers();
  $datadir= $server->datadir;
  $datadir_before_recovery= $datadir.'_before_recovery';
  $datadir_restored_binlog= $datadir.'_restored_binlog';

  $server->backupDatadir($datadir_restored_binlog);

  #####
  $self->printStep("Starting the server");

  $status= $server->startServer;

  if ($status != STATUS_OK) {
    sayError("The server failed to start");
    return $self->finalize(STATUS_TEST_FAILURE,[]);
  }

  $binlog= $server->serverVariable('log_bin_basename');
  $general_log_file= $server->serverVariable('general_log_file');
  unless ($general_log_file =~ /(?:\/|\\)/) {
    $general_log_file= $server->datadir.'/'.$general_log_file;
  }

  #####
  $self->printStep("Generating data");

  $status= $self->generate_data();

  if ($status != STATUS_OK) {
    sayError("Data generation failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$server]);
  }

  #####
  my $queries= $prng->uint16(20,200);
  $self->printStep("Running $queries queries as initial test flow");
  $self->setProperty('queries',$queries);
  $status= $self->run_test_flow();

  if ($status != STATUS_OK) {
    sayError("Initial test flow failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$server]);
  }

  #####

  my $timeout= $prng->int(5,$self->getProperty('duration')/3);

  $self->printStep("Running atomic DDL test flow (random duration: $timeout sec)");

  if ($self->scenarioOptions()->{grammar2}) {
    $self->setProperty('grammar',$self->scenarioOptions()->{grammar2});
    $self->unsetProperty('redefine');
  } else {
    sayError("Atomic DDL grammar is not specified (--scenario-grammar2)");
    return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[$server]);
  }
  $self->setProperty('queries',10000000);

  my $gentest_pid= fork();
  if (not defined $gentest_pid) {
    sayError("Failed to fork for atomic DDL");
    return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[$server]);
  }

  # The child will be running DDL. The parent will be running
  # the server and then killing it, and while waiting, will be monitoring
  # the status of the test flow to notice if it exits prematurely.

  if ($gentest_pid > 0) {
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
    my $res= $self->run_test_flow();
    exit $res;
  }

  if ($status != STATUS_OK) {
    sayError("Atomic DDL failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$server]);
  }

  #####
  $self->printStep("Killing the server");

  $status= $server->kill;

  if ($status != STATUS_OK) {
    sayError("Could not kill the server");
    return $self->finalize(STATUS_TEST_FAILURE,[$server]);
  }

  # We don't care about the result of gentest after killing the server,
  # but we need to ensure that the process exited
  waitpid($gentest_pid, 0);

  #####
  $self->printStep("Checking the server log for fatal errors after killing");

  $status= $self->checkErrorLog($server, {CrashOnly => 1});

  if ($status != STATUS_OK) {
    sayError("Found fatal errors in the log");
    return $self->finalize(STATUS_TEST_FAILURE,[$server]);
  }

  #####
  $self->printStep("Backing up data directory");

  $server->backupDatadir($datadir_before_recovery);
  move($server->errorlog, $server->errorlog.'_before_recovery');
  if (-e $general_log_file) {
    move($general_log_file, $general_log_file.'_before_recovery');
  }

  #####
  $self->printStep("Restarting the server");

  $status= $server->startServer;

  if ($status != STATUS_OK) {
    sayError("Server failed to restart");
    # Error log might indicate known bugs which will affect the exit code
    $status= $self->checkErrorLog($server);
    # ... but even if it's a known error, we cannot proceed without the server
    return $self->finalize($status,[$server]);
  }

  #####
  $self->printStep("Checking the server error log for errors after recovery");

  $status= $self->checkErrorLog($server);

  if ($status != STATUS_OK) {
    # Error log can show known errors. We want to update
    # the global status, but don't want to exit prematurely
    $self->setStatus($status);
    sayError("Found errors in the log after restart");
    if ($status > STATUS_CUSTOM_OUTCOME) {
      return $self->finalize(STATUS_RECOVERY_FAILURE,[$server]);
    }
  }

  my $dump_result= STATUS_OK;
  if ($binlog) {
    #####
    $self->printStep("Storing binary logs for further binlog consistency check");
    mkdir($server->vardir.'/binlogs_to_replay');
    if (osWindows()) {
        system('xcopy "'.$binlog.'.0*" "'.$server->vardir.'/binlogs_to_replay/ /E /I /Q');
    } else {
        system('cp -r '.$binlog.'.0* '.$server->vardir.'/binlogs_to_replay/');
    }

    #####
    $self->printStep("Dumping databases for further binlog consistency check");

    $databases= join ' ', $server->nonSystemDatabases();
    $dump_result= $server->dumpSchema($databases, $server->vardir.'/server_schema_recovered.dump');
    if ($dump_result == STATUS_OK) {
      $server->normalizeDump($server->vardir.'/server_schema_recovered.dump', 'remove_autoincs');
    }
  }


  #####
  $self->printStep("Checking the database state after restart");

  $status= $server->checkDatabaseIntegrity;

  if ($status != STATUS_OK) {
    sayError("Database appears to be corrupt after restart");
    return $self->finalize(STATUS_RECOVERY_FAILURE,[$server]);
  }

#  #####
#  $self->printStep("Running test flow on the restarted server");
#
#  $self->setProperty('duration',int($self->getProperty('duration')/4));
#  $self->setProperty('queries',$queries);
#  $status= $self->run_test_flow();
#
#  if ($status != STATUS_OK) {
#    sayError("Test flow after restart failed");
#    #####
#    $self->printStep("Checking the server error log for known errors");
#
#    if ($self->checkErrorLog($server) == STATUS_CUSTOM_OUTCOME) {
#      $status= STATUS_CUSTOM_OUTCOME;
#    }
#
#    $self->setStatus($status);
#    return $self->finalize($status,[$server])
#  }
#
  #####
  $self->printStep("Stopping the server");

  $status= $server->stopServer;

  if ($status != STATUS_OK) {
    sayError("Server shutdown failed");
    return $self->finalize(STATUS_SERVER_SHUTDOWN_FAILURE,[$server]);
  }

  if ($dump_result != STATUS_OK) {
    sayError("Schema dump after recovery failed, skipping the binlog consistency check");
    return $self->finalize(STATUS_RECOVERY_FAILURE,[]);
  } elsif ($binlog) {
    #####
    $self->printStep("Starting the server on a clean datadir for binlog consistency check");
    $server->setDatadir($datadir_restored_binlog);
    $server->addServerOptions(['--secure-timestamp=NO']);
    $server->addServerOptions(['--max-statement-time=0']);
    $server->addServerOptions(['--general-log-file='.$general_log_file.'_binlog_recovered']);
    $server->addServerOptions(['--log-error='.$server->errorlog.'_binlog_recovered']);
    $status= $server->startServer;

    if ($status != STATUS_OK) {
      sayError("The server failed to start");
      return $self->finalize(STATUS_TEST_FAILURE,[]);
    }

    my $client = DBServer::MySQL::MySQLd::_find(undef,
            [$server->serverVariable('basedir')],
            osWindows()?["client/Debug","client/RelWithDebInfo","client/Release","bin"]:["client","bin"],
            osWindows()?"mariadb.exe":"mariadb"
    );
    my $mysqlbinlog = DBServer::MySQL::MySQLd::_find(undef,
            [$server->serverVariable('basedir')],
            osWindows()?["client/Debug","client/RelWithDebInfo","client/Release","bin"]:["client","bin"],
            osWindows()?"mariadb-binlog.exe":"mariadb-binlog"
    );

    $self->printStep("Feeding original binary logs to the new server");
    my $cmd= $mysqlbinlog.' '.$server->vardir."/binlogs_to_replay/* | $client --force -uroot --binary-mode --comments --protocol=tcp --port=".$server->port;
    say("Running $cmd");
    system($cmd);
    $status= $? >> 8;
#    move($datadir,$datadir_before_recovery);

    if ($status != STATUS_OK) {
      sayError("Binlog replay failed");
      return $self->finalize(STATUS_RECOVERY_FAILURE,[]);
    }

    $self->printStep("Dumping databases after binlog replay");

    $databases= join ' ', $server->nonSystemDatabases();
    $server->dumpSchema($databases, $server->vardir.'/server_schema_from_binlog.dump');
    $server->normalizeDump($server->vardir.'/server_schema_from_binlog.dump', 'remove_autoincs');

    #####
    $self->printStep("Comparing schemata after data recovery and after binlog replay");

    $status= compare($server->vardir.'/server_schema_recovered.dump', $server->vardir.'/server_schema_from_binlog.dump');
    if ($status != STATUS_OK) {
      sayError("Database structures differ");
      system('diff -u '.$server->vardir.'/server_schema_recovered.dump'.' '.$server->vardir.'/server_schema_from_binlog.dump');
      return $self->finalize(STATUS_RECOVERY_FAILURE,[$server]);
    }
    else {
      say("Structure dumps appear to be identical");
    }
  }

  #####
  $self->printStep("Stopping the server");

  $status= $server->stopServer;
  if ($status != STATUS_OK) {
    sayError("Server shutdown failed");
    return $self->finalize(STATUS_SERVER_SHUTDOWN_FAILURE,[$server]);
  }


  return $self->finalize($status,[]);
}

1;
