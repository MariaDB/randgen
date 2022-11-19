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
# The module implements a normal RQG scenario
# earlier performed by runall-new.pl by default, without extra demands:
# start a single server, run the test, shut down the server
#
########################################################################

package GenTest::Scenario::Standard;

require Exporter;
@ISA = qw(GenTest::Scenario);

use strict;
use DBI;
use GenUtil;
use GenTest;
use GenTest::App::GenTest;
use GenTest::Properties;
use GenTest::Constants;
use GenTest::Scenario;
use Data::Dumper;
use File::Copy;
use File::Compare;
use POSIX;

use DBServer::MariaDB;

sub new {
  my $class= shift;
  my $self= $class->SUPER::new(@_);
  return $self;
}

sub run {
  my $self= shift;
  my ($status, $server, $gentest);

  $status= STATUS_OK;
  $server= $self->prepareServer(1);

  #####
  $self->printStep("Starting the server");

  $status= $server->startServer;

  if ($status != STATUS_OK) {
    sayError("Server failed to start");
    return $self->finalize(STATUS_ENVIRONMENT_FAILURE,[]);
  }

  #####
  # This property is for Gendata/GenTest to know on how many servers to execute the flow
  $self->setProperty('number_of_servers',1);

  $self->printStep("Generating test data");

  $status= $self->generate_data();
  
  if ($status != STATUS_OK) {
    sayError("Data generation failed");
    return $self->finalize($status,[$server]);
  }

  #####
  $self->printStep("Running test flow");
  $status= $self->run_test_flow();
    
  if ($status != STATUS_OK) {
    sayError("Test flow failed");
    return $self->finalize($status,[$server]);
  }
    
  #####
  $self->printStep("Stopping the server");

  $status= $server->stopServer();

  if ($status != STATUS_OK) {
    sayError("Server shutdown failed");
    return $self->finalize(STATUS_SERVER_SHUTDOWN_FAILURE,[$server]);
  }

  return $self->finalize($status,[]);
}

1;
