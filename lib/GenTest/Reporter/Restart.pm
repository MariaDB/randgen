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

sub monitor {
	my $reporter= shift;
  my $shutdown_timeout= shift;

  return STATUS_OK if time() < $reporter->testStart() + 10;

  $shutdown_timeout = 120 unless defined $shutdown_timeout;

	$first_reporter = $reporter if not defined $first_reporter;
	return STATUS_OK if $reporter ne $first_reporter;

	my $server= $reporter->properties->server_specific->{1}->{server};
	my $status= STATUS_OK;

	# First, check that the server is still available 
	# (or it might happen that it crashed on its own, and by restarting it we will hide the problem)
	my $dbh = DBI->connect($reporter->dsn());

	unless ($dbh) {
		sayError("Restart reporter could not connect to the server before shutdown. Status will be set to STATUS_SERVER_CRASHED");
		return STATUS_SERVER_CRASHED;
	}

#  my (undef, undef, $stat)= $dbh->selectrow_array("SHOW ENGINE INNODB STATUS");
#  my $ibuf= 0;
#  if ($stat =~ /Ibuf: size (\d+)/s) {
#    $ibuf= $1;
#    say("Ibuf size: $ibuf");
#    if ($ibuf <= 1) {
#      return STATUS_OK;
#    }
#  }

  $dbh->do("CREATE OR REPLACE FUNCTION mysql.resume_after_restart() RETURNS INT RETURN 0");
  if ($server->stopServer($shutdown_timeout) != STATUS_OK) {
    say("Restart reporter failed to stop the server");
    return STATUS_ENVIRONMENT_FAILURE;
  }

  my ($crashes, $errors)= $server->checkErrorLogForErrors();

  if ($crashes and scalar(@$crashes)) {
    return STATUS_SERVER_CRASHED;
  } elsif ($errors and scalar(@$errors)) {
    return STATUS_DATABASE_CORRUPTION;
  }

  $restart_count++;

  if ($ENV{DATADIR_BACKUP}) {
    $server->backupDatadir($server->datadir.".$restart_count");
  }

	say('Restart reporter: Restarting the server (#'.$restart_count.')...');
	my $status = $server->startServer();

	return $status if $status > STATUS_OK;

  my ($crashes, $errors)= $server->checkErrorLogForErrors();

  if (@$crashes) {
    return STATUS_SERVER_CRASHED;
  } elsif (@$errors) {
    $dbh->do("CREATE OR REPLACE FUNCTION mysql.resume_after_restart() RETURNS INT RETURN -1");
    return STATUS_DATABASE_CORRUPTION;
  }

	$dbh = DBI->connect($reporter->dsn());

	unless ($dbh) {
		sayError("Restart reporter could not connect to the restarted server. Status will be set to ENVIRONMENT_FAILURE");
		return STATUS_ENVIRONMENT_FAILURE;
	}

	$reporter->updatePid();

  if ($ENV{CHECK_TABLE}) {
    if ($server->checkDatabaseIntegrity > STATUS_OK) {
      $dbh->do("CREATE OR REPLACE FUNCTION mysql.resume_after_restart() RETURNS INT RETURN -1");
      return STATUS_DATABASE_CORRUPTION;
    } else {
      say("Schema does not look corrupt, resuming the test flow");
      $dbh->do("CREATE OR REPLACE FUNCTION mysql.resume_after_restart() RETURNS INT RETURN 1");
    }
  }

	return STATUS_OK;
}

sub type {
	return REPORTER_TYPE_PERIODIC;
}

1;
