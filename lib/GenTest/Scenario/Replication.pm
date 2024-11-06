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
# The module implements an RQG scenario for traditional replication.
# The basic variant of it, M=>S replication, was earlier performed
# by runall-new.pl running with --rpl-mode=X.
#
# The scenario recognized the following options:
# --scenario-skip-consistency-check:
#   Do not perform data consistency check which otherwise occurs
#   if the test reached the end and replication didn't abort
# --scenario-nosync:
#   Do not wait for the replica to catch up with the master (and
#   thus do not perform the data consistency check afterwards)
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
  my ($status, $server, $gentest, $topology, $total_status);
  $total_status= STATUS_OK;
  $status= STATUS_OK;

  $topology= '1->2';

  my @reporters= $self->getProperty('reporters') ? @{$self->getProperty('reporters')} : ();
  my $do_sync= (exists $self->scenarioOptions->{'nosync'} ? 0 : 1 );
  my $rpl_timeout= $self->scenarioOptions->{'rpl-timeout'} || $self->scenarioOptions->{'rpl_timeout'} || $self->getProperty('duration');
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
    my $s= $self->prepareServer($s,my $is_active=($s==1));
    unless ($s) {
      sayError("Could not initialize the server");
      $total_status= STATUS_ENVIRONMENT_FAILURE;
      goto FINALIZE;
    }
    push @servers, $s;
  }

  #####
  $self->printStep("Starting $srv_count servers");
  foreach my $s (0..$#servers) {
    $status= $servers[$s]->startServer;
    if ($status != STATUS_OK) {
      sayError("Server ".($s+1)." failed to start");
      $total_status= $status if $status > $total_status;
      goto FINALIZE;
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
      my ($master_conn, $err)= Connection::Perl->new( server => $servers[$master], role => 'super', name => 'RPL' );
      unless ($master_conn) {
        sayError("Connection RPL to the master failed, error $err");
        $total_status= STATUS_ENVIRONMENT_FAILURE if STATUS_ENVIRONMENT_FAILURE > $total_status;
        last;
      }
      $master_conn->execute("/*!100001 SET tx_read_only= OFF */");
      $master_conn->execute("CREATE USER /*!100104 IF NOT EXISTS */ replication IDENTIFIED BY 'yvp.utu9azv4xgt6VRT'");
      unless ($master_conn->err) {
        $master_conn->execute("GRANT REPLICATION SLAVE ON *.* TO replication");
      }
      my $master_port= $servers[$master]->port;
      my ($slave_conn, $err)= Connection::Perl->new( server => $servers[$slave], role => 'super', name => 'RPL' );
      unless ($slave_conn) {
        sayError("Connection RPL to the slave failed, error $err");
        $total_status= STATUS_ENVIRONMENT_FAILURE if STATUS_ENVIRONMENT_FAILURE > $total_status;
        last;
      }
      $slave_conn->execute("/*!100001 SET GLOBAL tx_read_only= OFF */");
      $slave_conn->execute("CHANGE MASTER TO MASTER_HOST='127.0.0.1', MASTER_PORT=$master_port, MASTER_USER='replication', MASTER_PASSWORD='yvp.utu9azv4xgt6VRT', MASTER_SSL=0");
      $slave_conn->execute("START SLAVE");
      if ($slave_conn->err) {
        sayError("Could not start replication $master -> $slave: ".$slave_conn->print_error);
        $total_status= STATUS_REPLICATION_FAILURE if STATUS_REPLICATION_FAILURE > $total_status;
        last;
      }
    } else {
      sayError("Wrong connection $c in topology");
      $total_status= STATUS_ENVIRONMENT_FAILURE if STATUS_ENVIRONMENT_FAILURE > $total_status;
      last;
    }
  }

  if ($total_status != STATUS_OK) {
    sayError("Replication preparation failed");
    goto FINALIZE;
  }

  #####
  $self->printStep("Generating test data on the master");

  $status= $self->generateData(1);

  if ($status != STATUS_OK) {
    sayError("Data generation failed");
    $total_status= $status if $status > $total_status;
    goto FINALIZE;
  }

  #####
  $self->printStep("Running test flow");
  $self->createTestRunner();
  $status= $self->runTestFlow();

  if ($status != STATUS_OK) {
    sayError("Test flow failed");
    $total_status= $status if $status > $total_status;
    goto FINALIZE;
  }

  #####
  if ($do_sync) {
    $self->printStep("Synchronizing with master");
    my ($file, $pos) = $servers[0]->getMasterPos();
    unless ($file && $pos) {
      sayError("Could not detect master logname/position");
      return STATUS_ENVIRONMENT_FAILURE;
    }
    $status= $servers[1]->syncWithMaster($file, $pos, $self->getProperty('duration'));
    unless ($status  == STATUS_OK) {
      $total_status= $status if $status > $total_status;
      goto FINALIZE;
    }
    my ($master_status, %master_data)= $self->get_data($servers[0]);
    if ($master_status != STATUS_OK) {
      $total_status= $master_status if $master_status > $total_status;
      goto FINALIZE;
    }
    my ($slave_status, %slave_data)= $self->get_data($servers[1]);
    if ($slave_status != STATUS_OK) {
      sayError("Error occurred upon collecting data from the master");
      $total_status= $slave_status if $slave_status > $total_status;
      goto FINALIZE;
    }

    $self->printStep("Comparing data on primary and replica");
    my $data_status= $self->compare_data(\%master_data, \%slave_data, $servers[0]->vardir, 'replicaton');
    if ($data_status != STATUS_OK) {
      $data_status= STATUS_REPLICATION_FAILURE;
      sayError("Inconsistency between primary and replica");
      $total_status= $data_status if $data_status > $total_status;
      goto FINALIZE;
    }

  } else {
    $self->printStep("Checking that the replica is alive");
    my $slave_status= $servers[1]->getSlaveStatus();
    if (defined $slave_status) {
      say("Current replica status: Last_SQL_Errno: ".$slave_status->{Last_SQL_Errno}.", Last_IO_Errno: ".$slave_status->{Last_IO_Errno});
    } else {
      sayError("Slave didn't return any status");
      $total_status= STATUS_REPLICATION_FAILURE if STATUS_REPLICATION_FAILURE > $total_status;
      goto FINALIZE;
    }
  }

FINALIZE:
  return $self->finalize($total_status,[@servers]);
}

1;
