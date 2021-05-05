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
  my ($status, $server, $slave, $databases, $general_log_file);
  my ($datadir, $datadir_before_recovery);

  my $prng = GenTest::Random->new( seed => $self->getProperty('seed') );

  $status= STATUS_OK;

  #####
  # Prepare server(s)
  # If the test is running with binary log enabled, we will use replication
  # for binlog consistency check. Otherwise the check will be skipped

  my @mysqld_options= @{$self->getServerSpecific(1)->{mysqld_options}};

  $server= $self->prepareServer(1);

  if ("@mysqld_options" =~ /--log[-_]bin/) {
    $self->copyServerSpecific(1,2);
    my $port= $self->getServerSpecific(1,'port') + 1;
    $self->setServerSpecific(2,'port',$port);
    $self->setServerSpecific(2,'vardir',$self->getServerSpecific(1,'vardir').'/slave');
    my $dsn= $self->getServerSpecific(1,'dsn');
    $dsn=~ s/port=\d+/port=$port/;
    $self->setServerSpecific(2,'dsn',$dsn);

    push @mysqld_options,
      '--server-id=999',
      '--secure-timestamp=REPLICATION',
      '--max-statement-time=0'
    ;
    $self->setServerSpecific(2,'mysqld_options',\@mysqld_options);
    $slave= $self->prepareServer(2);
  }

  $datadir= $server->datadir;
  $datadir_before_recovery= $datadir.'_before_recovery';

  #####
  $self->printStep("Starting the server");

  $status= $server->startServer;

  if ($status != STATUS_OK) {
    sayError("The server failed to start");
    return $self->finalize(STATUS_TEST_FAILURE,[]);
  }

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

#  my $rpl_status= STATUS_OK;
  my $master_dump_result= STATUS_OK;
  my ($master_dbh, $slave_dbh);
  if ($slave) {
    #####
    $self->printStep("Dumping databases for further replication consistency check");

    $databases= join ' ', $server->nonSystemDatabases();
    $master_dump_result= $server->dumpSchema($databases, $server->vardir.'/server_schema_recovered.dump');
    $server->normalizeDump($server->vardir.'/server_schema_recovered.dump', 'remove_autoincs');

    #####
    $self->printStep("Starting the slave");
    $status= $slave->startServer;

    if ($status != STATUS_OK) {
      sayError("Failed to start the slave");
      return $self->finalize(STATUS_REPLICATION_FAILURE,[$server]);
    }

    $slave_dbh= $slave->dbh;
    if ($slave_dbh) {
      $slave_dbh->do("CHANGE MASTER TO MASTER_HOST='127.0.0.1', MASTER_PORT=".$server->port.", MASTER_USER='root'");
      $slave_dbh->do("START SLAVE");
    } else {
      sayError("Could not connect to the slave");
      return $self->finalize(STATUS_RECOVERY_FAILURE,[$server,$slave]);
    }
  }

  #####
  $self->printStep("Checking the database state after restart");

  $status= $server->checkDatabaseIntegrity;

  if ($status != STATUS_OK) {
    sayError("Database appears to be corrupt after restart");
    return $self->finalize(STATUS_RECOVERY_FAILURE,[$server,$slave]);
  }

  if ($slave) {
    #####
    $self->printStep("Replicating the data");
    $master_dbh= $server->dbh;
    my ($file, $pos) = $master_dbh->selectrow_array("SHOW MASTER STATUS");
    say("Master status: $file/$pos. Waiting for the slave to catch up...");
    my $wait_result = $slave_dbh->selectrow_array("SELECT MASTER_POS_WAIT('$file',$pos)");
    if (not defined $wait_result) {
      if ($slave_dbh) {
          my @slave_status = $slave_dbh->selectrow_array("SHOW SLAVE STATUS");
          sayError("Slave SQL thread has stopped with error: ".$slave_status[37]);
      } else {
          sayError("Lost connection to the slave");
      }
      return $self->finalize(STATUS_REPLICATION_FAILURE,[$server,$slave]);
    }
    $slave_dbh->do("STOP SLAVE");

    #####
    $self->printStep("Dumping databases from the slave");

    $databases= join ' ', $slave->nonSystemDatabases();
    $slave->dumpSchema($databases, $server->vardir.'/slave_schema.dump');
    $slave->normalizeDump($server->vardir.'/slave_schema.dump', 'remove_autoincs');

    #####
    $self->printStep("Comparing schemata on master and slave");

    $status= compare($server->vardir.'/server_schema_recovered.dump', $server->vardir.'/slave_schema.dump');
    if ($status != STATUS_OK) {
      sayError("Database structures differ");
      system('diff -u '.$server->vardir.'/server_schema_recovered.dump'.' '.$server->vardir.'/slave_schema.dump');
      return $self->finalize(STATUS_RECOVERY_FAILURE,[$server,$slave]);
    }
    else {
      say("Structure dumps appear to be identical");
    }
  }

  #####
  $self->printStep("Stopping the servers");

  $status= $slave->stopServer;
  if ($status != STATUS_OK) {
    sayError("Slave shutdown failed");
    return $self->finalize(STATUS_SERVER_SHUTDOWN_FAILURE,[$server,$slave]);
  }
  $status= $server->stopServer;
  if ($status != STATUS_OK) {
    sayError("Server shutdown failed");
    return $self->finalize(STATUS_SERVER_SHUTDOWN_FAILURE,[$server,$slave]);
  }

  return $self->finalize($status,[]);
}

1;
