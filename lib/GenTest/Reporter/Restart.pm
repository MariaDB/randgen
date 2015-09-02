# Copyright (C) 2015 MariaDB Corporation Ab
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


#################
# Goal: check that binary logs contents correctly reflects the server data.
# 
# The reporter switches the server into read-only mode, takes a data dump,
# shuts down the server, starts a new clean one, feeds binary log from 
# the first server to the new one, takes a data dump again, 
# and compares two dumps.
#################

package GenTest::Reporter::Restart;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use DBI;
use GenTest;
use GenTest::Constants;
use GenTest::Reporter;
use File::Copy;

use DBServer::MySQL::MySQLd;

my $first_reporter;

sub monitor {
	my $reporter = shift;

	$first_reporter = $reporter if not defined $first_reporter;
	return STATUS_OK if $reporter ne $first_reporter;

	my $server = $reporter->properties->servers->[0];
	my $status;
	my $vardir = $server->vardir();
	my $datadir = $server->datadir();
	my $port = $server->port();

	# First, check that the server is still available 
	# (or it might happen that it crashed on its own, and by restarting it we will hide the problem)
	my $dbh = DBI->connect($reporter->dsn());

	unless ($dbh) {
		say("Restart reporter: ERROR: Could not connect to the server before shutdown. Status will be set to STATUS_SERVER_CRASHED");
		return STATUS_SERVER_CRASHED;
	}

	say("Restart reporter: Shutting down the server ...");
	$status = $server->stopServer();
	sleep(5);

	my $dbh = DBI->connect($reporter->dsn(),'','',{PrintError=>0}) ;
	if ($dbh) {
		say("Restart reporter: ERROR: Can still connect to the server, shutdown failed. Status will be set to ENVIRONMENT_FAILURE");
		return STATUS_ENVIRONMENT_FAILURE;
	}

	say("Restart reporter: Restarting the server ...");
	my $status = $server->startServer();

	if ($status > STATUS_OK) {
		say("Restart reporter: ERROR: Server startup finished with an error");
		return $status;
	}

	$dbh = DBI->connect($reporter->dsn());

	unless ($dbh) {
		say("Restart reporter: ERROR: Could not connect to the restarted server. Status will be set to ENVIRONMENT_FAILURE");
		return STATUS_ENVIRONMENT_FAILURE;
	}

	return STATUS_OK;
}

sub type {
	return REPORTER_TYPE_PERIODIC;
}


1;
