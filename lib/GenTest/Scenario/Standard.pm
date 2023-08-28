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
# The module implements a normal RQG scenario
# earlier performed by runall-new.pl by default, without extra demands:
# start a single server, run the test, shut down the server
#
########################################################################

package GenTest::Scenario::Standard;

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
  $self->numberOfServers(1,1);
  return $self;
}

sub run {
  my $self= shift;
  my ($status, $total_status, $server, $gentest);

  $status= STATUS_OK;
  $total_status= STATUS_OK;

  $server= $self->prepareServer(1, my $is_active=1);

  #####
  $self->printStep("Starting the server");

  $status= $server->startServer;

  if ($status != STATUS_OK) {
    sayError("Server failed to start");
    $total_status= $status;
    goto FINALIZE;
  }

  #####
  $self->printStep("Generating test data");
  $self->generateData();

  if ($status != STATUS_OK) {
    sayError("Data generation failed");
    $total_status= $status if $status > $total_status;
    goto FINALIZE;
  }

  #####
  $self->printStep("Running test flow");
  $status= $self->runTestFlow();

  if ($status != STATUS_OK) {
    sayError("Test flow failed");
    $total_status= $status if $status > $total_status;
    goto FINALIZE;
  }

  #####
  $self->printStep("Stopping the server");

  $status= $server->stopServer();

  if ($status != STATUS_OK) {
    sayError("Server shutdown failed");
    $total_status= $status if $status > $total_status;
  }

FINALIZE:
  return $self->finalize($total_status,[$server]);
}

1;
