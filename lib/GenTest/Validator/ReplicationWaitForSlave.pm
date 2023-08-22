# Copyright (C) 2008-2009 Sun Microsystems, Inc. All rights reserved.
# Copyright (c) 2022, 2023 MariaDB
# Use is subject to license terms.
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

package GenTest::Validator::ReplicationWaitForSlave;

require Exporter;
@ISA = qw(GenTest::Validator GenTest);

use Data::Dumper;

use strict;

use GenUtil;
use GenTest;
use Constants;
use GenTest::Result;
use GenTest::Validator;
use Connection::Perl;

my $slave_conn;

sub init {
  my ($validator, $executors) = @_;
  my $master_executor = $executors->[0];
  my $slave_info= $master_executor->connection->get_columns_by_name("SHOW SLAVE HOSTS",'Host','Port');
  my ($slave_host, $slave_port) = ($slave_info->[0]->{Host}, $slave_info->[0]->{Port});
  $slave_host= '127.0.0.1' if ($slave_host eq 'localhost');
  $slave_conn= Connection::Perl->new(host => $slave_host, port => $slave_port, name => 'WFS');
  return 1;
}

sub validate {
  my ($validator, $executors, $results) = @_;
  my $master_executor = $executors->[0];
  my ($file, $pos)= @{$master_executor->connection()->get_row("SHOW MASTER STATUS")};

  if (($file eq '') || ($pos eq '')) {
    sayWarning("ReplicationWaitForSlave: Could not retrieve master status");
    return STATUS_WONT_HANDLE;
  }
  my $wait_status = $slave_conn->get_value("SELECT /* ReplicationWaitForSlave::validate */ MASTER_POS_WAIT('$file', $pos)");
  if (not defined $wait_status) {
    my @slave_status = $slave_conn->get_row("SHOW SLAVE STATUS /* ReplicationWaitForSlave::validate */");
    my $slave_status = $slave_status[37];
    say("Slave SQL thread has stopped with error: ".$slave_status);
    return STATUS_REPLICATION_FAILURE;
  } else {
    return STATUS_OK;
  }
}

1;
