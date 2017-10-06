# Copyright (C) 2015, 2017 MariaDB Corporation Ab
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
# Goal: Check server behavior on normal restart.
# 
# The reporter shuts down the server gracefully and immediately restarts it.
# The test (runall-new) must be run with --restart-timeout=N to wait
# till the server is up again.
#################

package GenTest::Reporter::Restart;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use DBI;
use GenTest;
use GenTest::Constants;
use GenTest::Reporter;

use DBServer::MySQL::MySQLd;

my $first_reporter;
my $restart_count= 0;
my $restart_marker='';

sub monitor {
	my $reporter= shift;
  my $shutdown_timeout= shift;

  $shutdown_timeout = 120 unless defined $shutdown_timeout;

	$first_reporter = $reporter if not defined $first_reporter;
	return STATUS_OK if $reporter ne $first_reporter;

	# Do not restart in the first 20 seconds after the test flow started
	return STATUS_OK if (time() < $reporter->reporterStartTime() + 20);

	my $server= $reporter->properties->servers->[0];
	my $status= STATUS_OK;

	# First, check that the server is still available 
	# (or it might happen that it crashed on its own, and by restarting it we will hide the problem)
	my $dbh = DBI->connect($reporter->dsn());

	unless ($dbh) {
		sayError("Restart reporter could not connect to the server before shutdown. Status will be set to STATUS_SERVER_CRASHED");
		return STATUS_SERVER_CRASHED;
	}

  if (!$server->stopServer($shutdown_timeout)) {
    say("Restart reporter failed to stop the server");
    return STATUS_ENVIRONMENT_FAILURE;
  }

  my ($crashes, $errors)= $server->checkErrorLogForErrors($restart_marker);

  if (@$crashes) {
    return STATUS_SERVER_CRASHED;
  } elsif (@$errors) {
    return STATUS_DATABASE_CORRUPTION;
  }

  my $old_marker= $restart_marker;
  $restart_marker= 'RQG RESTART MARKER ' . (++$restart_count);
  $server->backupDatadir($server->datadir.".$restart_count");
  $server->addErrorLogMarker($restart_marker);

	say("Restart reporter: Restarting the server ...");
	my $status = $server->startServer();

	return $status if $status > STATUS_OK;

  # We intentionally check the error log from the same (old) marker again,
  # because we might have missed something that was written on/after shutdown

  my ($crashes, $errors)= $server->checkErrorLogForErrors($old_marker);

  if (@$crashes) {
    return STATUS_SERVER_CRASHED;
  } elsif (@$errors) {
    return STATUS_DATABASE_CORRUPTION;
  }

	$dbh = DBI->connect($reporter->dsn());

	unless ($dbh) {
		sayError("Restart reporter could not connect to the restarted server. Status will be set to ENVIRONMENT_FAILURE");
		return STATUS_ENVIRONMENT_FAILURE;
	}

	$reporter->updatePid();

  if ($server->checkDatabaseIntegrity > STATUS_OK) {
    return STATUS_DATABASE_CORRUPTION;
  } else {
    say("Schema does not look corrupt");
  }

	return STATUS_OK;
}

sub type {
	return REPORTER_TYPE_PERIODIC;
}

1;
