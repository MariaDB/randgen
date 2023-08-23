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
# The module implements an RQG scenario for traditional replication.
# The basic variant of it, M=>S replication, was earlier performed
# by runall-new.pl running with --rpl-mode=X.
#
# TODO: Make the topology arbitrary, to be determined by the
# --[scenario-]replication-topology option or alike
# TODO: Add synchronization at the end of the test, optionally
#       (unless --nosync is provided)
# TODO: add optional MASTER_USE_GTID
#
########################################################################

package GenTest::Scenario::Replication;

require Exporter;
@ISA = qw(GenTest::Scenario);

use strict;
use GenUtil;
use GenTest;
use GenTest::TestRunner;
use GenTest::Properties;
use Constants;
use GenTest::Scenario;
use Data::Dumper;
use File::Copy;
use File::Compare;
use POSIX;

use DBServer::MariaDB;
use Connection::Perl;

sub new {
  my $class= shift;
  my $self= $class->SUPER::new(@_);
  $self->numberOfServers(2);
  return $self;
}

sub run {
  my $self= shift;
  my ($status, $server, $gentest, $topology);
  $status= STATUS_OK;
  $topology= '1->2';

  my @reporters= $self->getProperty('reporters') ? @{$self->getProperty('reporters')} : ();
  my $do_sync= (exists $self->scenarioOptions->{'nosync'} ? 0 : 1 );
  my $rpl_timeout= $self->scenarioOptions->{'rpl-timeout'} || $self->scenarioOptions->{'rpl_timeout'} || $self->getProperty('duration');
  push @reporters, 'ReplicationConsistency' if $do_sync;
  push @reporters, 'ReplicationSlaveStatus';

  my $srv_count= scalar(keys %{$self->getProperty('server_specific')});
  if ($srv_count < 2) {
    sayError("There should be at least two servers for the replication test");
    return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[]);
  } elsif ($srv_count > 2) {
    sayWarning("$srv_count servers are configured, but only 2 will be used by the scenario");
  }
  my @servers= ();

# TODO: make log-bin random on slaves
# TODO: make log-slave-updates be set only on slaves, and randomly
  foreach my $s (1..$srv_count) {
    my $server_id= $self->getServerStartupOption($s,'server-id');
    if ($server_id) {
      sayWarning("Overridding server id $server_id by $s for server $s");
    }
    $self->setServerStartupOption($s,'server-id',$s);
    unless ($self->getServerStartupOption($s,'log-bin')) {
      $self->setServerStartupOption($s,'log-bin',undef);
    }
    unless ($self->getServerStartupOption($s,'log-slave-updates')) {
      $self->setServerStartupOption($s,'log-slave-updates',undef);
    }
    # is_active is for GenData/GenTest to know on which servers to run the flow
    # TODO: should be set to all masters, according to the topology
    push @servers, $self->prepareServer($s,my $is_active=($s==1));
  }

  #####
  $self->printStep("Starting $srv_count servers");
  foreach my $s (0..$#servers) {
    $status= $servers[$s]->startServer;
    if ($status != STATUS_OK) {
      sayError("Server ".($s+1)." failed to start");
      return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[@servers]);
    }
  }

  #####
  $self->printStep("Configuring $topology replication topology");

  my $reporters= $self->getProperty('reporters');
  $reporters= [] unless $reporters;
  $self->setProperty('reporters',[ @$reporters, 'ReplicationSlaveStatus' ]);

  my @connections= split /,/, $topology;
  foreach my $c (@connections) {
    if ($c =~ /^(\d+)->(\d+)$/) {
      my ($master, $slave)= ($1-1, $2-1);
      say("Enabling $c replication");
      my $master_conn= Connection::Perl->new( server => $servers[$master], role => 'super', name => 'RPL' );
      $master_conn->execute("SET tx_read_only= OFF");
      $master_conn->execute("CREATE USER IF NOT EXISTS replication IDENTIFIED BY 'yvp.utu9azv4xgt6VRT'");
      unless ($master_conn->err) {
        $master_conn->execute("GRANT REPLICATION SLAVE ON *.* TO replication");
      }
      if ($master_conn->err) {
        sayError("Could not configure replication user on server $master: ".$master_conn->print_error);
        $status= STATUS_REPLICATION_FAILURE;
        last;
      }
      my $master_port= $servers[$master]->port;
      my $slave_conn= Connection::Perl->new( server => $servers[$slave], role => 'super', name => 'RPL' );
      $slave_conn->execute("CHANGE MASTER TO MASTER_HOST='127.0.0.1', MASTER_PORT=$master_port, MASTER_USER='replication', MASTER_PASSWORD='yvp.utu9azv4xgt6VRT'");
      $slave_conn->execute("START SLAVE");
      if ($slave_conn->err) {
        sayError("Could not start replication $master -> $slave: ".$slave_conn->print_error);
        $status= STATUS_REPLICATION_FAILURE;
        last;
      }
    } else {
      sayError("Wrong connection $c in topology");
      $status= STATUS_ENVIRONMENT_FAILURE;
      last;
    }
  }

  if ($status != STATUS_OK) {
    sayError("Replication configuration failed");
    return $self->finalize($status,[@servers]);
  }

  #####
  $self->printStep("Generating test data on the master");

  $status= $self->generateData(1);

  if ($status != STATUS_OK) {
    sayError("Data generation failed");
    return $self->finalize($status,[@servers]);
  }

  #####
  $self->printStep("Running test flow");
  $status= $self->runTestFlow();

  if ($status != STATUS_OK) {
    sayError("Test flow failed");
    return $self->finalize($status,[@servers]);
  }

  #####
  if ($do_sync) {
    $self->printStep("Synchronizing with master");
    my ($file, $pos) = $servers[0]->getMasterPos();
    unless ($file && $pos && $servers[1]->syncWithMaster($file, $pos, $self->getProperty('duration')) == STATUS_OK) {
      return $self->finalize(STATUS_REPLICATION_FAILURE,[@servers]);
    }
  } else {
    $self->printStep("Checking that the replica is alive");
    my $status= $servers[1]->getSlaveStatus();
    if (defined $status) {
      say("Current replica status: Last_SQL_Errno: ".$status->{Last_SQL_Errno}.", Last_IO_Errno: ".$status->{Last_IO_Errno});
    } else {
      sayError("Slave didn't return any status");
      return $self->finalize(STATUS_SERVER_UNAVAILABLE,[@servers]);
    }
  }

  #####
  $self->printStep("Stopping the servers");

  foreach (0..$#servers) {
    $status= $servers[$_]->stopServer();
    if ($status != STATUS_OK) {
      sayError("Server ".($_+1)." shutdown failed");
      return $self->finalize(STATUS_SERVER_SHUTDOWN_FAILURE,[@servers]);
    }
  }

  return $self->finalize($status,[]);
}

1;
