# Copyright (c) 2008,2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2021 MariaDB Corporation Ab
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

package GenTest::Reporter::Backtrace;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use GenTest;
use GenTest::Constants;
use GenTest::Reporter;
use GenTest::Incident;
use GenTest::CallbackPlugin;

sub report {
    if (defined $ENV{RQG_CALLBACK}) {
        return callbackReport(@_);
    } else {
        return nativeReport(@_);
    }
}

sub nativeReport {
	my $reporter = shift;

	my $datadir = $reporter->serverVariable('datadir');
	my $binary = $reporter->serverInfo('binary');
	my $bindir = $reporter->serverInfo('bindir');
	my $pid = $reporter->serverInfo('pid');
	say("datadir: $datadir");
	say("binary: $binary");
	say("bindir: $bindir");
	say("pid: $pid");

	my $core;
  $core = </cores/core.$pid> if $^O eq 'darwin';
  $core = <$datadir/vgcore*> if defined $reporter->properties->valgrind;

	my @commands;

  if (osWindows()) {
    $bindir =~ s{/}{\\}sgio;
    my $cdb_cmd = "!sym prompts off; !analyze -v; .ecxr; !for_each_frame dv /t;~*k;q";
    push @commands, 'cdb -i "'.$bindir.'" -y "'.$bindir.';srv*C:\\cdb_symbols*http://msdl.microsoft.com/download/symbols" -z "'.$datadir.'\mysqld.dmp" -lines -c "'.$cdb_cmd.'"';
  } else {
      # Coredump may be not created yet, waiting for a while
      foreach (1..30) {
        if (defined $core and -f $core) {
          $core = File::Spec->rel2abs($core);
          say("core is $core");
          last;
        }
        sleep(1);
        $core = <$datadir/core*>;
      }
      if (-f $core and osSolaris()) {
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

          # First, identify all threads
          my @threads = `echo threads | dbx $binary $core 2>&1` =~ m/t@\d+/g;

          ## Then we make a command for each thread (It would be
          ## more efficient and get nicer output to have all
          ## commands in one dbx-batch, TODO!)

          my $traces = join("; ",map{"where ".$_} @threads);

          push @commands, "echo \"$traces\" | dbx $binary $core";
        } else {
          ## We'll attempt pstack and c++filt which should allways
          ## work and show all threads. c++filt from SunStudio
          ## should even be able to demangle GNU CC-compiled
          ## executables.
          push @commands, "pstack $core | c++filt";
        }
      } elsif (-f $core) {
          ## Assume all other systems are gdb-"friendly" ;-)
          push @commands, "gdb --batch --se=$binary --core=$core --command=backtrace.gdb";
          push @commands, "gdb --batch --se=$binary --core=$core --command=backtrace-all.gdb";
      } elsif (kill(0,$pid)) {
          say("The process $pid is still alive. Taking stack traces from the running server");
          push @commands, "gdb --batch --se=$binary -p $pid --command=backtrace.gdb";
          push @commands, "gdb --batch --se=$binary -p $pid --command=backtrace-all.gdb";
      } else {
        sayWarning("Neither core file $core nor process $pid were found!");
      }
  }

	my @debugs;

	foreach my $command (@commands) {
		my $output = `$command`;
		say("$output");
		push @debugs, [$command, $output];
	}


    my $incident = GenTest::Incident->new(
        result   => 'fail',
        corefile => $core,
        debugs   => \@debugs
    );

	return STATUS_OK, $incident;
}

sub callbackReport {
    my $output = GenTest::CallbackPlugin::run("backtrace");
    say("$output");
    ## Need some incident interface here in the output from
    ## the callback
    return STATUS_OK, undef;
}

sub type {
	return REPORTER_TYPE_CRASH | REPORTER_TYPE_DEADLOCK;
}

1;
