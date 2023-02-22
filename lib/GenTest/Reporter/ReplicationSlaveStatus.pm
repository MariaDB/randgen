# Copyright (C) 2008-2009 Sun Microsystems, Inc. All rights reserved.
# Copyright (C) 2016 MariaDB Corporation AB.
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

package GenTest::Reporter::ReplicationSlaveStatus;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use DBI;
use GenTest;
use GenTest::Constants;
use GenTest::Reporter;
#use GenTest::Comparator;
#use Data::Dumper;
#use IPC::Open2;
#use File::Copy;
#use POSIX;

use DBServer::MySQL::MySQLd;

my $first_reporter;

sub monitor {
	my $reporter = shift;
    status($reporter);
}

sub report {
	my $reporter = shift;
    status($reporter);
}

sub status {
	my $reporter = shift;

	alarm(3600);

	$first_reporter = $reporter if not defined $first_reporter;
	return STATUS_OK if $reporter ne $first_reporter;

    my $server = $reporter->properties->servers->[1];
    my $dbh = DBI->connect($server->dsn());

	if ($dbh) {
		my $slave_status = $dbh->selectrow_hashref("SHOW SLAVE STATUS /* ReplicationSlaveStatus::status */");

		if ($$slave_status{'Last_IO_Error'} ne '') {
			say("Slave IO thread has stopped with error: ".$$slave_status{'Last_IO_Error'});
			return STATUS_REPLICATION_FAILURE;
		} elsif ($$slave_status{'Last_SQL_Error'} ne '') {
			say("Slave SQL thread has stopped with error: ".$$slave_status{'Last_SQL_Error'});
			return STATUS_REPLICATION_FAILURE;
		} elsif ($$slave_status{'Last_Error'} ne '') {
			say("Slave has stopped with error: ".$$slave_status{'Last_Error'});
			return STATUS_REPLICATION_FAILURE;
		} else {
			return STATUS_OK;
		}
	} else {
		say("ERROR: Lost connection to the slave");
		return STATUS_REPLICATION_FAILURE;
	}
}

sub type {
	return REPORTER_TYPE_PERIODIC | REPORTER_TYPE_SUCCESS;
}

1;
