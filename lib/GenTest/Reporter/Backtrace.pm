# Copyright (c) 2008,2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2021, 2025, MariaDB Corporation Ab
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

# Upon test failure, get stack traces from the running server
# (e.g. in case of a deadlock), and from coredumps stored in the test vardir

package GenTest::Reporter::Backtrace;

require Exporter;
@ISA = qw(GenTest::Reporter);

use File::Find;

use strict;
use GenUtil;
use GenTest;
use Constants;
use Cwd 'abs_path';
use GenTest::Reporter;
use Data::Dumper;

sub report {
  my $reporter = shift;

  my $datadir = $reporter->server->serverVariable('datadir');
  my $binary = $reporter->serverInfo('binary');
  my $bindir = $reporter->serverInfo('bindir');
  my $pid = $reporter->serverInfo('pid');
  my $vardir = $reporter->properties->vardir;

  say("BackTrace: datadir: $datadir");
  say("BackTrace: vardir:  $vardir");

  # In case the server is still somehow running
  if ($pid) {
    sub runcmd {
      my $command= shift;
      say("Backtrace: Executing $command");
      say("----------------------------  START OF STACK TRACE FROM THE RUNNING SERVER  ----------------------------\n");
      system($command);
      say("-----------------------------  END OF STACK TRACE FROM THE RUNNING SERVER -----------------------------\n");
    }
    if (osWindows()) {
      runcmd("cdb -p $pid -c \".dump /m $datadir\\mysqld.dmp;q\"");
    } elsif (kill(0,$pid)) {
      say("Backtrace: The process $pid is still alive. Taking stack traces from the running server");
      say("BackTrace: pid: $pid");
      say("BackTrace: binary: $binary");

      runcmd("gdb --batch --se=$binary -p $pid --command=util/backtrace-all.gdb");
      say("Backtrace: Sending SIGHUP to the server with pid $pid in order to force debug output.");
      kill(1, $pid);
      sleep(2);
      say("Backtrace: Killing the server with pid $pid with SIGSEGV in order to capture core.");
      $reporter->server->kill('SEGV');
    }
  }

  #  $core = </cores/core.$pid> if $^O eq 'darwin';
  #  $core = <$datadir/vgcore*> if defined $reporter->properties->valgrind;

  if (osWindows()) {
    $bindir =~ s{/}{\\}sgio;
    my $cdb_cmd = "!sym prompts off; !analyze -v; .ecxr; !for_each_frame dv /t;~*k;q";
    system('cdb -i "'.$bindir.'" -y "'.$bindir.';srv*C:\\cdb_symbols*http://msdl.microsoft.com/download/symbols" -z "'.$datadir.'\mysqld.dmp" -lines -c "'.$cdb_cmd.'"');
  } else {
    my @corefiles;
    my $core;
    say("Waiting for a few seconds in case a new core file starts getting written...");
    sleep(5);
    # We are searching for coredumps not just in the datadir or in server's vardir,
    # but in the entire test vardir, because we want to process all coredumps --
    # from all nodes, utilities, etc.
    find(
      sub {
          if ($_ =~ /^core.*/) {
              push @corefiles, abs_path($File::Find::name);
          }
      },
      $vardir
    );
    if (scalar(@corefiles)) {
      my $mtime= 0;
      COREWAIT:
      while (1) {
        # Presumably gets the latest
        ($core) = sort { -M $a <=> -M $b } @corefiles;
        # Last modification time
        $mtime = (stat($core))[9];
        unless ($mtime and (time()-$mtime < 10)) {
          say("Assuming that all coredumps have been written in full");
          last COREWAIT;
        }
        say("Coredump $core was last modified less than 10 seconds ago, waiting to see if it's still being written..'");
        sleep(10);
      }
    }
    if ($core and -f $core and osSolaris()) {
      ## We don't want to run gdb on solaris since it may core-dump
      ## if the executable was generated with SunStudio.

      ## 1) First try to do it with dbx. dbx should work for both
      ## Sunstudio and GNU CC. This is a bit complicated since we
      ## need to first ask dbx which threads we have, and then dump
      ## the stack for each thread.

      ## The code below is "inspired by MTR
      `echo | dbx - $core 2>&1` =~ m/Corefile specified executable: "([^"]+)"/;
      if ($1) {
        ## We do apparently have a working dbx

        say("BackTrace: coredump: $core");
        say("BackTrace: binary: $binary");

        # First, identify all threads
        my @threads = `echo threads | dbx $binary $core 2>&1` =~ m/t@\d+/g;

        ## Then we make a command for each thread (It would be
        ## more efficient and get nicer output to have all
        ## commands in one dbx-batch, TODO!)

        my $traces = join("; ",map{"where ".$_} @threads);

        system("echo \"$traces\" | dbx $binary $core");
      } else {
        ## We'll attempt pstack and c++filt which should allways
        ## work and show all threads. c++filt from SunStudio
        ## should even be able to demangle GNU CC-compiled
        ## executables.
        system("pstack $core | c++filt");
      }
    } elsif (scalar(@corefiles)) {
      say("Getting stack traces from ".scalar(@corefiles)." coredump(s), starting from the latest");
      foreach my $core (sort { -M $a <=> -M $b } @corefiles) {
        my $binary= `file $core`;
        chomp $binary;
        $binary =~ s/^.*from '([^' ]*).*$/$1/;
        say("----------------------------  START OF STACK TRACE FROM THE COREDUMP  ----------------------------\n");
        say("BackTrace: coredump $core");
        say("BackTrace: binary   $binary");
        system("gdb --batch --se=$binary --core=$core --command=util/backtrace.gdb | grep -vE 'New LWP [0-9]*'");
        say("----------------------------  START OF STACK TRACE FROM THE COREDUMP  ----------------------------\n");
      }
    } else {
      sayWarning("BackTrace: No coredumps found");
    }
  }
  return STATUS_OK;
}

sub type {
  return REPORTER_TYPE_CRASH | REPORTER_TYPE_DEADLOCK;
}

1;
