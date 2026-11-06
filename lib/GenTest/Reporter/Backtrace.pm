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
use File::Basename;
use POSIX qw(strftime);

sub report {
  my $reporter = shift;

  my @server_nums = keys %{$reporter->properties->server_specific};
  my $vardir = $reporter->properties->vardir;

  foreach my $id (@server_nums) {
    my $server = $reporter->properties->server_specific->{$id}->{server};
    next unless $server;
    my $datadir = $server->datadir;
    my $binary = $server->binary;
    my $bindir = dirname($binary);
    my $pid = $server->serverpid;

    say("Backtrace: server:  $id");
    say("Backtrace: datadir: $datadir");
    say("Backtrace: vardir:  $vardir");

    # In case the server is still somehow running
    if ($pid) {
      sub runcmd {
        my @commands= shift;
        say("Backtrace: Executing @commands");
        say("----------------------------  START OF STACK TRACE FROM THE RUNNING SERVER  ----------------------------\n");
        foreach (@commands) {
          system($_);
        }
        say("-----------------------------  END OF STACK TRACE FROM THE RUNNING SERVER -----------------------------\n");
      }
      if (osWindows()) {
        if (kill(0,$pid)) {
          say("Backtrace: The process $pid for the server $id is still alive. Taking stack traces from the running server");
          say("----------------------------  START OF STACK TRACE FROM THE RUNNING SERVER  ----------------------------\n");
          my $bt_file= $server->backtrace();
          my $bt= (defined $bt_file ? read_file($bt_file) : undef);
          print $bt if defined $bt;
          say("-----------------------------  END OF STACK TRACE FROM THE RUNNING SERVER -----------------------------\n");
          # There is no SIGSEGV on Windows to produce a dump, the process is just terminated
          say("Backtrace: Killing the server $id with pid $pid");
          $server->kill('KILL');
        }
      } elsif (kill(0,$pid)) {
        say("Backtrace: The process $pid for the server $id is still alive. Taking stack traces from the running server using binary $binary");
        my $bt_file= $vardir.'/threads_s'.$id.'_pid_'.$pid.'.txt';
        runcmd("gdb --batch --se=$binary -p $pid --command=util/backtrace-all.gdb > $bt_file", "grep -A1000 'Thread 1 ' $bt_file");
        say("Backtrace: Sending SIGHUP to the server $id with pid $pid in order to force debug output.");
        kill(1, $pid);
        sleep(2);
        say("Backtrace: Killing the server $id with pid $pid with SIGSEGV in order to capture core.");
        $server->kill('SEGV');
      }
    }
  }
    #  $core = </cores/core.$pid> if $^O eq 'darwin';
    #  $core = <$datadir/vgcore*> if defined $reporter->properties->valgrind;

  if (osWindows()) {
    windows_dumps($reporter, $vardir, \@server_nums);
  } else {
    my @corefiles;
    my $core;
    say("Backtrace: Waiting for a few seconds in case a new core file starts getting written...");
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
        say("Backtrace: Coredump $core was last modified less than 10 seconds ago, waiting to see if it's still being written..'");
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
        # Default value which might be not right
        my $binary = $reporter->serverInfo('binary');

        ## We do apparently have a working dbx

        say("Backtrace: coredump: $core");
        say("Backtrace: binary: $binary");

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
      say("Backtrace: Getting stack traces from ".scalar(@corefiles)." coredump(s), starting from the latest");
      foreach my $core (sort { -M $a <=> -M $b } @corefiles) {
        my $sn = '';
        if ($core =~ /\/(s\d+)\//) {
          $sn = $1.'_';
        }
        my $size = (-s $core);
        my $bt_file= $vardir.'/threads_'.$sn.basename($core).'_'.$size.'.txt';
        if (-e $bt_file) {
          say("Backtrace: thread dump $bt_file already exists, skipping the coredump $core");
          next;
        }
        my $core_binary= `file $core`;
        chomp $core_binary;
        unless ($core_binary =~ s/^.*from '([^' ]*).*$/$1/ && (-x $core_binary)) {
          $core_binary = $reporter->serverInfo('binary');
          sayWarning("Backtrace: Could not determine the binary from $core, assuming the default server binary $core_binary");
        }
        say("----------------------------  START OF STACK TRACE FROM THE COREDUMP  ----------------------------\n");
        my $cmd = "gdb --batch --se=$core_binary --core=$core --command=util/backtrace-all.gdb > $bt_file";
        say("Backtrace: running $cmd");
        system($cmd);
        system("grep -A1000 'Thread 1 ' $bt_file | grep -E '^Thread|^#'");
        say("-----------------------------  END OF STACK TRACE FROM THE COREDUMP  -----------------------------\n");
      }
    } else {
      sayWarning("Backtrace: No coredumps found");
    }
  }
  return STATUS_OK;
}

# On Windows, the server (with --core-file) writes a minidump (<name>.dmp)
# into the datadir when it crashes. As with coredumps, we search the entire
# test vardir, and get stack traces from all of them with cdb
# (Debugging Tools for Windows)
sub windows_dumps {
  my ($reporter, $vardir, $server_nums)= @_;
  my @dumps;
  find(sub { push @dumps, $File::Find::name if /\.dmp$/i }, $vardir);
  unless (scalar(@dumps)) {
    sayWarning("Backtrace: No minidumps found");
    return;
  }
  my $cdb= find_in_path('cdb');
  unless ($cdb) {
    sayWarning("Backtrace: cdb (Debugging Tools for Windows) was not found in PATH, cannot get stack traces from ".scalar(@dumps)." minidump(s)");
    return;
  }
  # Binaries (and their .pdb files) of all servers, plus the Microsoft
  # symbol server for system libraries
  my %bindirs;
  foreach my $id (@$server_nums) {
    my $server= $reporter->properties->server_specific->{$id}->{server};
    $bindirs{unix2winPath(dirname($server->binary))}= 1 if $server and $server->binary;
  }
  my $sympath= join(';', sort(keys %bindirs), 'srv*C:\\cdb_symbols*https://msdl.microsoft.com/download/symbols');
  say("Backtrace: Getting stack traces from ".scalar(@dumps)." minidump(s), starting from the latest");
  foreach my $dump (sort { -M $a <=> -M $b } @dumps) {
    my $sn= ($dump =~ /\/(s\d+)\// ? $1.'_' : '');
    my $bt_file= $vardir.'/threads_'.$sn.basename($dump).'_'.(-s $dump).'.txt';
    if (-e $bt_file) {
      say("Backtrace: thread dump $bt_file already exists, skipping the minidump $dump");
      next;
    }
    say("----------------------------  START OF STACK TRACE FROM THE MINIDUMP  ----------------------------\n");
    my $cmd= "\"$cdb\" -z \"".unix2winPath($dump)."\" -y \"$sympath\" -lines -c \"!sym prompts off; .ecxr; kc; ~*kc; q\" > \"$bt_file\" 2>&1";
    say("Backtrace: running $cmd");
    system($cmd);
    my $bt= read_file($bt_file);
    print $bt if defined $bt;
    say("-----------------------------  END OF STACK TRACE FROM THE MINIDUMP  -----------------------------\n");
  }
}

sub type {
  return REPORTER_TYPE_CRASH | REPORTER_TYPE_DEADLOCK | REPORTER_TYPE_FAILURE_POST_SHUTDOWN;
}

1;
