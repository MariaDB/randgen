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

use constant PROCESSLIST_PROCESS_COMMAND => 4;
use constant PROCESSLIST_PROCESS_TIME    => 5;
use constant PROCESSLIST_PROCESS_INFO    => 7;

# Maximum lifetime of a query before it is considered suspicios
# (hard default, may be overridden later)
use constant QUERY_LIFETIME_THRESHOLD    => 600;  # Seconds

# Number of suspicious queries required before a deadlock is declared
use constant STALLED_QUERY_COUNT_THRESHOLD  => 5;

# Number of times the actual test duration is allowed to exceed the desired one
use constant ACTUAL_TEST_DURATION_MULTIPLIER  => 2;

# Set actual query time limit to a slighly lower value than test duration
my $lifetime_threshold;

sub monitor {
  my $reporter = shift;

  # Set actual query time limit to a slighly lower value than test duration
  unless (defined $lifetime_threshold) {
    $lifetime_threshold= ($reporter->testDuration() * 0.8 > QUERY_LIFETIME_THRESHOLD
                          ? QUERY_LIFETIME_THRESHOLD
                          : int($reporter->testDuration() * 0.8))
  }

  my $actual_test_duration = time() - $reporter->testStart();

  if ($actual_test_duration > ACTUAL_TEST_DURATION_MULTIPLIER * $reporter->testDuration()) {
    sayError("Deadlock reporter: Actual test duration ($actual_test_duration seconds) is more than ".(ACTUAL_TEST_DURATION_MULTIPLIER)." times the desired duration (".$reporter->testDuration()." seconds)");
    $reporter->collect_deadlock_diagnostics();
    return STATUS_SERVER_DEADLOCKED;
  }

  if (osWindows()) {
    return $reporter->monitor_threaded();
  } else {
    return $reporter->monitor_nonthreaded();
  }
}

sub monitor_nonthreaded {
  my $reporter = shift;

#  sigaction SIGALRM, new POSIX::SigAction sub {
#                sayError("Deadlock reporter: Timeout upon running SHOW FULL PROCESSLIST");
#                return STATUS_SERVER_DEADLOCKED;
#  } or die "Deadlock reporter: Error setting SIGALRM handler: $!\n";

#  alarm (REPORTER_CONNECT_TIMEOUT_THRESHOLD);

  my $conn= $reporter->connection();
  if (! $conn) {
    sayError((ref $reporter)." could not connect to the server");
    return STATUS_SERVER_UNAVAILABLE;
  }
  my $processlist = $conn->query("SHOW FULL PROCESSLIST");
#  alarm (0);

  # Stalled queries are those which have been in the process list too long (in any state)
  my $stalled_queries= 0;
  # A query which stays in killed state too long is an indication of a problem,
  # even if there is only one. But killed queries can take some time to finalize
  # and disappear from the processlist, so we'll give it some extra time
  # before declaring a deadlock
  my $dead_queries= 0;

  foreach my $process (@$processlist) {
    if (
      ($process->[PROCESSLIST_PROCESS_INFO]) &&
      ($process->[PROCESSLIST_PROCESS_TIME] > $lifetime_threshold)
    ) {
        sayError("Deadlock reporter: Stalled query: (".$process->[PROCESSLIST_PROCESS_COMMAND].") (".$process->[PROCESSLIST_PROCESS_TIME]." sec): ".$process->[PROCESSLIST_PROCESS_INFO]);
        $stalled_queries++;
        if (($process->[PROCESSLIST_PROCESS_COMMAND] eq 'Killed') && $process->[PROCESSLIST_PROCESS_TIME] > $lifetime_threshold * 1.5) {
          $dead_queries++;
        }
    }
  }

  if ($stalled_queries >= STALLED_QUERY_COUNT_THRESHOLD or $dead_queries > 0) {
    sayError("Deadlock reporter: $stalled_queries stalled queries / $dead_queries dead queries detected, declaring deadlock");
    return $reporter->collect_deadlock_diagnostics();
  }

  return STATUS_OK;
}

sub collect_deadlock_diagnostics {
  my $reporter= shift;
#  sigaction SIGALRM, new POSIX::SigAction sub {
#              sayError("Deadlock reporter: Timeout upon performing deadlock diagnostics");
#              return STATUS_SERVER_DEADLOCKED;
#  } or die "Deadlock reporter: Error setting SIGALRM handler: $!\n";
#
#  alarm(REPORTER_CONNECT_TIMEOUT_THRESHOLD);
#
  unless ($reporter->connection) {
#    alarm(0);
    return STATUS_SERVER_UNAVAILABLE;
  }
  $reporter->connection->execute("INSTALL SONAME 'metadata_lock_info'");
  foreach my $status_query (
    "SHOW FULL PROCESSLIST",
    "SELECT * FROM INFORMATION_SCHEMA.METADATA_LOCK_INFO",
    "SHOW ENGINE INNODB STATUS"
    # "SHOW OPEN TABLES" - disabled due to bug #46433
  ) {
      say("Deadlock reporter: Executing $status_query:");
      my $status_result = $reporter->connection->query($status_query);
      print Dumper $status_result;
  }
#  alarm(0);
  return STATUS_SERVER_DEADLOCKED;
}

sub monitor_threaded {
  my $reporter = shift;

  require threads;

#
# We create two threads:
# * alarm_thread keeps a timeout so that we do not hang forever
# * connect_thread attempts to connect to the database and thus can hang forever because
# there are no network-level timeouts in DBD::mysql
#

  my $alarm_thread = threads->create( \&alarm_thread );
  my $connect_thread = threads->create ( \&connect_thread, $reporter );

  my $status;

  # We repeatedly check if either thread has terminated, and if so, reap its exit status

  while (1) {
    foreach my $thread ($alarm_thread, $connect_thread) {
      $status = $thread->join() if defined $thread && $thread->is_joinable();
    }
    last if defined $status;
    sleep(1);
  }

  # And then we kill the remaining thread.

  foreach my $thread ($alarm_thread, $connect_thread) {
    next if !$thread->is_running();
    # Windows hangs when joining killed threads
    if (osWindows()) {
      $thread->kill('SIGKILL');
    } else {
      $thread->kill('SIGKILL')->join();
    }
   }

  return ($status);
}

sub alarm_thread {
  local $SIG{KILL} = sub { threads->exit() };

  # We sleep in small increments so that signals can get delivered in the meantime

  foreach my $i (1..REPORTER_CONNECT_TIMEOUT_THRESHOLD) {
    sleep(1);
  };

  sayError("Deadlock reporter: Entire-server deadlock detected.");
  return(STATUS_SERVER_DEADLOCKED);
}

sub connect_thread {
  local $SIG{KILL} = sub { threads->exit() };
  my $reporter = shift;
  my $conn = $reporter->connection();
  my $processlist = $conn->query("SHOW FULL PROCESSLIST");
  return $conn->last_error->[0] if not defined $processlist;

  my $stalled_queries = 0;
  my $dead_queries = 0;

  foreach my $process (@$processlist) {
    if (
      ($process->[PROCESSLIST_PROCESS_INFO] ne '') &&
      ($process->[PROCESSLIST_PROCESS_TIME] > QUERY_LIFETIME_THRESHOLD)
    ) {
      $stalled_queries++;
    }
  }

  if ($stalled_queries >= STALLED_QUERY_COUNT_THRESHOLD) {
    sayError("Deadlock reporter: $stalled_queries stalled queries detected, declaring deadlock at DSN ".$reporter->server->dsn);
    print Dumper $processlist;
    return STATUS_SERVER_DEADLOCKED;
  } else {
    return STATUS_OK;
  }
}

sub report {
  my $reporter = shift;
  my $server_pid = $reporter->serverInfo('pid');
  my $datadir = $reporter->server->serverVariable('datadir');

  if (
    ($^O eq 'MSWin32') ||
    ($^O eq 'MSWin64')
        ) {
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
  return STATUS_SERVER_DEADLOCKED;
}

sub type {
  return REPORTER_TYPE_PERIODIC | REPORTER_TYPE_DEADLOCK;
}

1;

