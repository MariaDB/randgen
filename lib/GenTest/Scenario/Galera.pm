# Copyright (C) 2022, MariaDB
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
# The module implements an RQG scenario for Galera replication.
# There was a somewhat experimental version of it performed
# by runall-new.pl running with --galera=[ms]+
#
# TODO: add arbitrary topologies
#
########################################################################

package GenTest::Scenario::Galera;

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

sub new {
  my $class= shift;
  my $self= $class->SUPER::new(@_);
  $self->numberOfServers(3);
  $self->printSubtitle($self->numberOfServers()."-node topology");
  return $self;
}

sub run {
  my $self= shift;
  my ($status, $server, $gentest, $topology);
  $status= STATUS_OK;
  $topology= 'mss';

  my $srv_count= scalar(keys %{$self->getProperty('server_specific')});
  my @servers= ();

  # Checking for wsrep-provider
  my $wsrep_provider= $ENV{WSREP_PROVIDER};
  unless ($wsrep_provider) {
    $wsrep_provider=`/sbin/ldconfig -p | grep libgalera_smm.so | sed -e 's/.*=>[[:space:]]*//'`;
    chomp $wsrep_provider;
    unless (-e $wsrep_provider) {
      $wsrep_provider= undef;
    }
  }

  foreach my $s (1..$srv_count) {
    unless($self->getServerStartupOption($s,'wsrep-provider')) {
      if ($wsrep_provider) {
        $self->setServerStartupOption($s,'wsrep-provider',$wsrep_provider);
      } else {
        sayError("For server $s wsrep provider is not defined, and none found in the system or environment");
        $status= STATUS_ENVIRONMENT_FAILURE;
        last;
      }
    }
    # Workaround for MDEV-30197 (WSREP debug can't run with utf32)
    if (my $cs= $self->getServerStartupOption($s,'character-set-server')) {
      if ($cs eq 'utf32') {
        sayWarning("Cannot run Galera with utf32 due to MDEV-30197, switching to utf8mb3");
        $self->setServerStartupOption($s,'character-set-server','utf8mb3');
        $self->setServerStartupOption($s,'collation-server','utf8mb3_general_ci');
      }
    }
    my $galera_listen_port = SC_GALERA_DEFAULT_LISTEN_PORT + $s-1;
    my $galera_cluster_address = ($s-1 ? "gcomm://127.0.0.1:".SC_GALERA_DEFAULT_LISTEN_PORT : "gcomm://")
                                       . "?gmcast.listen_addr=tcp://127.0.0.1:".$galera_listen_port ;
    # Setting default options as per https://mariadb.com/kb/en/configuring-mariadb-galera-cluster/
    # of 2022-11-17
    $self->setServerStartupOption($s,'wsrep-cluster-address',$galera_cluster_address);
    $self->setServerStartupOption($s,'binlog-format','row');
    # We won't set default storage engine even though the page wants it
    $self->setServerStartupOption($s,'innodb-autoinc-lock-mode','2');
    $self->setServerStartupOption($s,'innodb-doublewrite','1');
    $self->setServerStartupOption($s,'enforce-storage-engine=');
    $self->setServerStartupOption($s,'wsrep-on');

    # is_active is for Gendata/GenTest to know on which servers to execute the flow
    # TODO: should be set for actual masters masters
    print Dumper $self->getProperty('server_specific')->{$s};
    push @servers, $self->prepareServer($s,my $is_active= ($s == 1));
  }
  if ($status != STATUS_OK) {
    sayError("Galera configuration failed");
    return $self->finalize($status,[@servers]);
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

  $self->printStep("Generating test data on the server(s)");

  $status= $self->generateData();

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
