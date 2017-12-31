# Copyright (C) 2017 MariaDB Corporation Ab
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
# The module implements master->slave replication scenario
#
# Unlike the old replication setup established via rpl_mode,
# this scenario also allows to execute arbitrary flow on the slave
# option, default 30 seconds
#
########################################################################

package GenTest::Scenario::MSReplication;

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

  $self->printTitle($self->getTestType." M->S replication");

  return $self;
}

sub run {
  my $self= shift;
  my ($master, $slave, $gentest_m, $gentest_s, $dbh_m, $dbh_s);
  my $status= STATUS_OK;
  my ($port_m, $port_s)= ($self->getProperty('port'), $self->getProperty('port')+1);

  $master= $self->prepareServer(1,
    {
      vardir => $self->getProperty('vardir'),
      port => $port_m,
      valgrind => 0,
    }
  );
  
  my ($log_bin_set, $server_id_set);
  my $opts= $master->getServerOptions;
  foreach my $o (@$opts) {
    if ($o =~ /^--log[-_]bin/) {
      $log_bin_set= 1;
    }
    elsif ($o =~ /^--server[-_]id/) {
      $server_id_set= 1;
    }
    last if $server_id_set and $log_bin_set;
  }
  unless ($log_bin_set) {
    $master->addServerOptions(['--log-bin']);
  }
  unless ($server_id_set) {
    $master->addServerOptions(['--server-id=1']);
  }

  $slave= $self->prepareServer(2,
    {
      vardir => $self->getProperty('vardir').'_slave',
      port => $port_s,
      valgrind => 0,
    }
  );
  $opts= $slave->getServerOptions;
  ($log_bin_set, $server_id_set)= (0, 0);
  foreach my $o (@$opts) {
    if ($o =~ /^--server[-_]id/) {
      $server_id_set= 1;
    }
    last if $server_id_set;
  }
  unless ($server_id_set) {
    $slave->addServerOptions(['--server-id=2']);
  }

  say("-- Master info: --");
  say($master->version());
  $master->printServerOptions();

  say("-- Slave info: --");
  say($slave->version());
  $slave->printServerOptions();

  #####
  $self->printStep("Starting the servers");

  $status= $master->startServer;

  if ($status != STATUS_OK) {
    sayError("Master failed to start");
    return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[]);
  }

  $status= $slave->startServer;

  if ($status != STATUS_OK) {
    sayError("Slave failed to start");
    return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[$master]);
  }

  #####
  $self->printStep("Setting up replication");
  $dbh_s= $slave->dbh();
  
  if (!$dbh_s) {
      sayError("No connection to the slave");
      return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[$master, $slave]);
  }
  $dbh_s->do("CHANGE MASTER TO MASTER_HOST='127.0.0.1', MASTER_PORT=$port_m, MASTER_USER='root'");
  $dbh_s->do("START SLAVE");

  #####
  $self->printStep("Generating test data");

  $gentest_m= $self->prepareGentest(1,
    {
      duration => $self->getTestDuration,
      dsn => [$master->dsn($self->getProperty('database'))],
      servers => [$master],
      gendata => $self->getProperty('gendata'),
      'gendata-advanced' => $self->getProperty('gendata-advanced'),
    }
  );
  $status= $gentest_m->doGenData();

  if ($status != STATUS_OK) {
    sayError("Could not generate the test data on master");
    return $self->finalize($status,[$master, $slave]);
  }

  $gentest_m= $self->prepareGentest(1,
    {
      duration => $self->getTestDuration,
      dsn => [$master->dsn($self->getProperty('database'))],
      grammar => $self->getProperty('grammar-master') || $self->getProperty('grammar1') || $self->getProperty('grammar'),
      servers => [$master, $slave],
      'start-dirty' => 1,
    }
  );
  
  my $grammar_s= $self->getProperty('grammar-slave') || $self->getProperty('grammar2') || undef;

  if ($grammar_s) {
    $gentest_s= $self->prepareGentest(2,
      {
        duration => $self->getTestDuration,
        dsn => [$slave->dsn($self->getProperty('database'))],
        grammar => $grammar_s,
        servers => [$master, $slave],
        'start-dirty' => 1,
      }
    );
  }

  ####
  $self->printStep("Wait for the slave to sync after generating the data");

  $dbh_m= $master->dbh();
  my ($file, $pos) = $dbh_m->selectrow_array("SHOW MASTER STATUS");
  say("Master status $file/$pos. Waiting for slave to catch up...");
  my $wait_result = $dbh_s->selectrow_array("SELECT MASTER_POS_WAIT('$file',$pos)");
  if (not defined $wait_result) {
    if ($dbh_s) {
      my @slave_status = $dbh_s->selectrow_array("SHOW SLAVE STATUS");
      sayError("Slave SQL thread has stopped with error: ".$slave_status[37]);
    } else {
      sayError("Lost connection to the slave");
    }
    return $self->finalize(STATUS_REPLICATION_FAILURE,[$master, $slave]);
  }

  #####
  $self->printStep("Running test flow");

  my $gentest_s_pid;
  if ($grammar_s) {
    $gentest_s_pid= fork();
    unless (defined $gentest_s_pid) {
      sayError("Failed to fork for running the test flow on slave");
      return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[$master, $slave]);
    }
  }
  
  # The child will be running the test flow on the slave. The parent will be running
  # the test flow on the master.
  
  if ($gentest_s_pid) {
    my $status= $gentest_m->run();

    if ($status != STATUS_OK) {
      sayError("Test flow on master failed");
      return $self->finalize($status,[$master, $slave]);
    }
    
    if ($grammar_s) {
      $status= STATUS_REPLICATION_FAILURE;
      my $timeout= 60;
      foreach (1..$timeout) {
        if (waitpid($gentest_s_pid, WNOHANG) == 0) {
          sleep 1;
        } 
        else {
          $status= $? >> 8;
          last;
        }
      }
      if ($status != STATUS_OK) {
        sayError("Test flow on slave failed");
        return $self->finalize($status,[$master, $slave]);
      }
    }
  }
  elsif (defined $gentest_s_pid) {
    my $res= $gentest_s->run();
    exit $res;
  }
  
  #####
  $self->printStep("Checking the database state after test flow");

  $status= $master->checkDatabaseIntegrity;

  if ($status != STATUS_OK) {
    sayError("Database appears to be corrupt on master");
    return $self->finalize(STATUS_RECOVERY_FAILURE,[$master, $slave]);
  }

  $status= $slave->checkDatabaseIntegrity;

  if ($status != STATUS_OK) {
    sayError("Database appears to be corrupt on slave");
    return $self->finalize(STATUS_RECOVERY_FAILURE,[$master, $slave]);
  }
  
  #####
  $self->printStep("Stopping the servers");

  $status= $slave->stopServer;

  if ($status != STATUS_OK) {
    sayError("Slave shutdown failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$master,$slave]);
  }

  $status= $master->stopServer;

  if ($status != STATUS_OK) {
    sayError("Master shutdown failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$master]);
  }

  #####
  $self->printStep("Checking the server logs for fatal errors after stopping");

  $status= $self->checkErrorLog($master, {CrashOnly => 0});

  if ($status != STATUS_OK) {
    sayError("Found errors in the master log");
    return $self->finalize(STATUS_TEST_FAILURE,[$master, $slave]);
  }

  $status= $self->checkErrorLog($slave, {CrashOnly => 0});

  if ($status != STATUS_OK) {
    sayError("Found errors in the master log");
    return $self->finalize(STATUS_TEST_FAILURE,[$master, $slave]);
  }

  return $self->finalize($status,[]);
}

1;
