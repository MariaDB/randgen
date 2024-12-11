# Copyright (c) 2008,2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2021, 2023, MariaDB
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

package GenTest::Reporter::Deadlock;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use GenUtil;
use GenTest;
use Constants;
use Constants::MariaDBErrorCodes;
use GenTest::Result;
use GenTest::Reporter;
use GenTest::Reporter::Backtrace;
use GenTest::Executor::MRDB;
use Connection::Perl;

use Data::Dumper;
use POSIX;

# Number of times the actual test duration is allowed to exceed the planned time
use constant ACTUAL_TEST_DURATION_MULTIPLIER  => 2;

my %killed_queries= ();
my $conn;

sub monitor {
  my $reporter = shift;

  my $actual_test_duration = time() - $reporter->testStart();

  sigaction SIGALRM, new POSIX::SigAction sub {
    sayError("Deadlock reporter: Timeout upon getting a PROCESSLIST");
    return STATUS_SERVER_DEADLOCKED;
  } or die "Deadlock reporter: Error setting SIGALRM handler: $!\n";

  alarm($reporter->testDuration());
  $conn= $reporter->connection() unless $conn;
  unless ($conn) {
    sayWarning("Deadlock monitor could not connect to the server");
    return STATUS_SERVER_UNAVAILABLE;
  }

  my $processlist= $reporter->connection()->get_columns_by_name("SELECT * FROM INFORMATION_SCHEMA.PROCESSLIST");
  alarm(0);

  if ($processlist) {
    sayDebug("Deadlock reporter: Found ".scalar(@$processlist)." running connections (system and user together)");
  } elsif ($reporter->connection->err) {
    sayWarning("Deadlock reporter: Got an error upon getting a processlist: ".$reporter->connection->print_error);
  }

  my %new_killed_queries= ();
  foreach my $p (@$processlist) {
    if ($p->{INFO} && $p->{QUERY_ID} && (($p->{STATE} && ($p->{STATE} eq 'Killed')) || ($p->{COMMAND} && ($p->{COMMAND} eq 'Killed'))) ) {
      if (defined $killed_queries{$p->{ID}.':'.$p->{QUERY_ID}}) {
        sayWarning("Deadlock reporter: Stalled query: ".$p->{ID}.": ".$p->{QUERY_ID}." ".$p->{STATE}." ".$p->{COMMAND}." ".$p->{TIME}." ".$p->{INFO}." ".$p->{MAX_MEMORY_USED});
      }
      $new_killed_queries{$p->{ID}.':'.$p->{QUERY_ID}}= $p->{INFO}
    }
  }
  %killed_queries= %new_killed_queries;

  return STATUS_OK if $actual_test_duration < $reporter->testDuration();

  if ($actual_test_duration > ACTUAL_TEST_DURATION_MULTIPLIER * $reporter->testDuration()) {
    sayError("Deadlock reporter: Actual test duration ($actual_test_duration seconds) is more than ".(ACTUAL_TEST_DURATION_MULTIPLIER)." times the desired duration (".$reporter->testDuration()." seconds)");
    foreach my $p (@$processlist) {
      if (exists $killed_queries{$p->{ID}.':'.$p->{QUERY_ID}}) {
        sayError("Deadlock reporter: Stalled query: ".$p->{ID}.": ".$p->{QUERY_ID}." ".$p->{STATE}." ".$p->{TIME}." ".$p->{INFO}." ".$p->{MAX_MEMORY_USED});
      }
    }
    foreach my $status_query (
      "SELECT * FROM INFORMATION_SCHEMA.PROCESSLIST",
      "SELECT * FROM INFORMATION_SCHEMA.METADATA_LOCK_INFO",
      "SHOW ENGINE INNODB STATUS"
    ) {
        say("Deadlock reporter: Executing $status_query:");
        my $status_result = $reporter->connection->query($status_query);
        print Dumper $status_result;
    }
    return STATUS_SERVER_DEADLOCKED;
  }
  return STATUS_OK;
}

sub report {
  my $reporter = shift;
  my $datadir = $reporter->server->serverVariable('datadir');
  my $server_pid = $reporter->serverInfo('pid');
  if ($server_pid) {
    if (($^O eq 'MSWin32') || ($^O eq 'MSWin64')) {
      my $cdb_command = "cdb -p $server_pid -c \".dump /m $datadir\\mysqld.dmp;q\"";
      say("Deadlock reporter: Executing $cdb_command");
      system($cdb_command);
    } else {
      say("Deadlock reporter: Killing mysqld with pid $server_pid with SIGHUP in order to force debug output.");
      kill(1, $server_pid);
      sleep(2);
      say("Deadlock reporter: Killing mysqld with pid $server_pid with SIGSEGV in order to capture core.");
      $reporter->server->kill('SEGV');
    }
  } else {
    say("Deadlock reporter: Server PID not found, not sending signals");
  }
  return STATUS_SERVER_DEADLOCKED;
}

sub type {
  return REPORTER_TYPE_PERIODIC | REPORTER_TYPE_DEADLOCK;
}

1;

