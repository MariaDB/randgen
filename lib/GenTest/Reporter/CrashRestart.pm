# Copyright (c) 2013, 2017 MariaDB
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
# Goal: Check server behavior on restart after a crash.
# 
# The reporter crashes the server and immediately restarts it.
# The test (runall-new) must be run with --restart-timeout=N to wait
# till the server is up again.
#################

package GenTest::Reporter::CrashRestart;

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
	my $reporter = shift;

	$first_reporter = $reporter if not defined $first_reporter;
	return STATUS_OK if $reporter ne $first_reporter;

	# Do not crash in the first 20 seconds after the test flow started
	return STATUS_OK if (time() < $reporter->reporterStartTime() + 20);

	my $server = $reporter->properties->servers->[0];
	my $status;
	my $vardir = $server->vardir();
	my $datadir = $server->datadir();
	my $port = $server->port();

	# First, check that the server is still available 
	# (or it might happen that it crashed on its own, and by restarting it we will hide the problem)
	my $dbh = DBI->connect($reporter->dsn());

	unless ($dbh) {
		sayError("CrashRestart reporter could not connect to the server before shutdown. Status will be set to STATUS_SERVER_CRASHED");
		return STATUS_SERVER_CRASHED;
	}

	my $pid = $reporter->serverInfo('pid');
	if (!defined $pid) {
		sayError("CrashRestart reporter cannot crash the server: server PID is not defined");
		return STATUS_ENVIRONMENT_FAILURE;
	} else {
		say("CrashRestart reporter: Sending SIGKILL to server with pid $pid...");
		kill(9, $pid);
	}

	my $dbh;
	foreach (1..5) {
		$dbh = DBI->connect($reporter->dsn(),'','',{PrintError=>0}) ;
		last if not $dbh;
		sleep(1);
	}
	if ($dbh) {
		sayError("CrashRestart reporter still can connect to the server, crash did not work. Status will be set to ENVIRONMENT_FAILURE");
		return STATUS_ENVIRONMENT_FAILURE;
	}

  $restart_count++;
  system("cp -r $datadir $datadir.$restart_count");

  my $errorlog= $server->errorlog;
  my $restart_marker= "RQG RESTART MARKER $restart_count";
  if (open(ERRLOG,">>$errorlog")) {
    print ERRLOG "$restart_marker\n";
    close (ERRLOG);
  }
  else {
    sayError("Could not open $errorlog for writing a marker")
  }

	say("CrashRestart reporter: Restarting the server ...");
	my $status = $server->startServer();

	if ($status > STATUS_OK) {
		sayError("Server startup finished with an error in CrashRestart reporter");
		return $status;
	}

  open(RESTART, $errorlog);
  my $found_marker= 0;

  say("Checking server log for important errors");

  while (<RESTART>) {
    next unless $found_marker or /$restart_marker/;
    $found_marker= 1;

		$_ =~ s{[\r\n]}{}siog;

    # Ignore certain errors
    next if
         $_ =~ /innodb_table_stats/so
      or $_ =~ /ib_buffer_pool' for reading: No such file or directory/so
    ;

		say($_);
    # Crashes
    if (
           $_ =~ /Assertion\W/sio
        or $_ =~ /got signal/sio
        or $_ =~ /segmentation fault/sio
        or $_ =~ /segfault/sio
        or $_ =~ /exception/sio
    ) {
      $status= STATUS_SERVER_CRASHED;
    }
    # Other errors
    elsif (
           $_ =~ /\[ERROR\]\s+InnoDB/sio
        or $_ =~ /InnoDB:\s+Error:/sio
        or $_ =~ /registration as a STORAGE ENGINE failed./sio
    ) {
      $status= STATUS_DATABASE_CORRUPTION;
    }
  }
  close(RESTART);

  if ($status > STATUS_OK) {
    sayError("Server log after restart indicates critical errors");
    return $status;
  }

	$dbh = DBI->connect($reporter->dsn());

	unless ($dbh) {
		sayError("CrashRestart reporter could not connect to the restarted server. Status will be set to ENVIRONMENT_FAILURE");
		return STATUS_ENVIRONMENT_FAILURE;
	}

	$reporter->updatePid();

  say("Testing database integrity");

  my $databases = $dbh->selectcol_arrayref("SHOW DATABASES");
  foreach my $database (@$databases) {
      next if $database =~ m{^(mysql|information_schema|pbxt|performance_schema)$}sio;
      $dbh->do("USE $database");
      my $tabl_ref = $dbh->selectcol_arrayref("SHOW FULL TABLES", { Columns=>[1,2] });
      # 1178 is ER_CHECK_NOT_IMPLEMENTED
      my %tables = @$tabl_ref;
      foreach my $table (keys %tables) {
        # Should not do CHECK etc., and especially ALTER, on a view
        next if $tables{$table} eq 'VIEW';
        say("Verifying table: $table; database: $database");
#          $dbh->do("CHECK TABLE `$database`.`$table` EXTENDED");
        my $check = $dbh->selectcol_arrayref("CHECK TABLE `$database`.`$table` EXTENDED", { Columns=>[3,4] });
        if ($dbh->err() > 0 && $dbh->err() != 1178) {
          sayError("Table $database.$table appears to be corrupted");
          $status= STATUS_DATABASE_CORRUPTION;
        }
        else {
          my %msg = @$check;
          foreach my $m (keys %msg) {
            say("For table `$database`.`$table` : $m $msg{$m}");
            if ($m ne 'status') {
              $status= STATUS_DATABASE_CORRUPTION;
            }
          }
        }
      }
  }
  if ($status > STATUS_OK) {
    sayError("Database integrity check failed");
    return $status;
  }

  say("Schema does not look corrupt");

	return STATUS_OK;
}

sub type {
	return REPORTER_TYPE_PERIODIC;
}


1;

