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
# The module implements an RQG scenario which involves comparators,
# earlier performed by runall-new.pl running 2 or 3 servers.
# Now the number of servers is arbitrary, it is determined by the number
# of basedir options passed to the scenario
#
########################################################################

package GenTest::Scenario::Comparison;

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

use constant SC_COMPARISON_DEFAULT_VALIDATOR => 'ResultsetComparator';

use DBServer::MariaDB;

sub new {
  my $class= shift;
  my $self= $class->SUPER::new(@_);
  # Min 2, no max
  $self->numberOfServers(2);
  $self->printSubtitle($self->numberOfServers()." servers");
  return $self;
}

sub run {
  my $self= shift;
  my ($status, $server, $gentest);

  $status= STATUS_OK;
  my $srv_count= scalar(keys %{$self->getProperty('server_specific')});
  if ($srv_count < 2) {
    sayError("There should be at least two servers for the comparison test");
    return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[]);
  }

  if (! $self->getProperty('validators') or scalar(@{$self->getProperty('validators')}) == 0) {
    sayWarning("No validators are defined, using ".SC_COMPARISON_DEFAULT_VALIDATOR);
    $self->setProperty('validators',[ SC_COMPARISON_DEFAULT_VALIDATOR,'ExitCodeComparator' ]);
  }

  my @servers= ();
  foreach (1..$srv_count) {
    push @servers, $self->prepareServer($_, my $is_active=1);
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
  # This property is for Gendata/GenTest to know on how many servers to execute the flow
  # TODO: should be set to the number of masters

  $self->printStep("Generating test data");
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
