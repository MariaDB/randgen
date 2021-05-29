# Copyright (C) 2013 Monty Program Ab
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


###################################################################
# The reporter makes the slave server crash every 30 seconds,
# restarts it and checks that it started all right. 
# If it's used alone, it can catch errors that do not allow
# slave to restart properly (e.g. if it crashed or if the replication aborted).
# If used in conjunction with ReplicationConsistency reporter,
# the correctness of the data after all the crashes will also be checked
# at the end of the test.
###################################################################

package GenTest::Reporter::SlaveCrashRecovery;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use DBI;
use GenTest;
use GenTest::Constants;
use GenTest::Reporter;
use GenTest::Comparator;
use Data::Dumper;
use IPC::Open2;
use File::Copy;
use POSIX;

use DBServer::MySQL::MySQLd;

my $first_reporter;
my $last_crash_time;
my $restart_count = 0;

sub monitor {
	my $reporter = shift;

	$first_reporter = $reporter if not defined $first_reporter;
	return STATUS_OK if $reporter ne $first_reporter;

    my $server= $reporter->properties->server_specific->{2}->{server};
	$last_crash_time = $reporter->testStart() if not defined $last_crash_time;

  my $dbh_prev = DBI->connect($server->dsn());
  my $ibuf= 0;
  if (defined $dbh_prev) {
    my (undef, undef, $stat)= $dbh_prev->selectrow_array("SHOW ENGINE INNODB STATUS");
    if ($stat =~ /Ibuf: size (\d+)/s) {
      $ibuf= $1;
      say("Ibuf size: $ibuf");
      if ($ibuf > 1) {
        my $pid = $server->serverpid();
        say("Sending SIGTERM to slave with pid $pid");
        kill(15, $pid);
        while (kill 0, $pid) {
          say("Waiting for $pid to exit...");
          sleep 1;
        }
        my $res= restart($reporter);
        $last_crash_time = time();
        return $res;
      } else {
        return STATUS_OK;
      }
    } else {
      say("Couldn't detect Ibuf size: $stat");
    }
  }
}

sub report {
	return STATUS_OK;
}

sub restart {
	my $reporter = shift;

	alarm(3600);

	$first_reporter = $reporter if not defined $first_reporter;
	return STATUS_OK if $reporter ne $first_reporter;

	my $server = $reporter->properties->server_specific->{2}->{server};

	my $dbh_prev = DBI->connect($server->dsn());
	if (defined $dbh_prev) {
		$dbh_prev->disconnect();
	}

	$server->setStartDirty(1);


	my $errlog = $server->errorlog();
	move($errlog,"$errlog.$restart_count");
  unless ($ENV{SKIP_DATADIR_BACKUP}) {
    $server->backupDatadir($server->datadir.".$restart_count");
  }

  if (check_log("$errlog.$restart_count") != STATUS_OK) {
    kill(15, $reporter->properties->server_specific->{1}->{server}->pid());
    die("Found errors in the previous run");
  }


	say("Trying to restart the server ...");
	my $restart_status = $server->startServer();

  $restart_status= check_log($errlog);
  
	$restart_count++;
	my $dbh = DBI->connect($server->dsn());

	$restart_status = STATUS_DATABASE_CORRUPTION if not defined $dbh && $restart_status == STATUS_OK;

  if ($restart_status == STATUS_OK and not $ENV{SKIP_CHECK_TABLE}) {
    $restart_status= $server->checkDatabaseIntegrity;
  }

	if ($restart_status > STATUS_OK) {
		say("Restart has failed.");
		return $restart_status;
	}

  $dbh->do("START SLAVE");

	return STATUS_OK;

}

sub check_log {
  my $errlog= shift;
  my $restart_status= STATUS_OK;
  say("Checking error log $errlog for errors");
	open(RESTART, $errlog);
	while (<RESTART>) {
		$_ =~ s{[\r\n]}{}siog;
#		say($_);
		if ($_ =~ m{registration as a STORAGE ENGINE failed.}sio) {
			say("Storage engine registration failed");
			$restart_status = STATUS_DATABASE_CORRUPTION;
		} elsif ($_ =~ m{exception}sio) {
			say("Exception was caught");
			$restart_status = STATUS_DATABASE_CORRUPTION;
		} elsif ($_ =~ m{ready for connections}sio) {
#			say("Server restart was apparently successfull.") if $restart_status == STATUS_OK ;
#			last;
		} elsif ($_ =~ m{device full error|no space left on device}sio) {
			say("No space left on device");
			$restart_status = STATUS_ENVIRONMENT_FAILURE;
			last;
		} elsif ($_ =~ m{slave SQL thread aborted|slave IO thread aborted}sio) {
			say("Replication aborted");
			$restart_status = STATUS_REPLICATION_FAILURE;
			last;
		} elsif (
			($_ =~ m{got signal}sio) ||
			($_ =~ m{segfault}sio) ||
			($_ =~ m{segmentation fault}sio)
		) {
			say("Restarting server has apparently crashed.");
			$restart_status = STATUS_DATABASE_CORRUPTION;
			last;
		} elsif ( $_ =~ m{InnoDB: Unable to find a record to delete-mark|Flagged corruption|was not found on update: TUPLE}sio )
      {
        sayError("Corruption which we are looking for occurred");
        $restart_status = STATUS_DATABASE_CORRUPTION;
        last;
    }
	}
	close(RESTART);
  return $restart_status;
}


sub type {
	return REPORTER_TYPE_PERIODIC;
}

1;
