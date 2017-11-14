#!/usr/bin/perl

# Copyright (C) 2017 MariaDB Corporatin Ab
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

use lib 'lib';
use lib "$ENV{RQG_HOME}/lib";
use strict;
use GenTest;
use Data::Dumper;
use Getopt::Long qw( :config pass_through );
use GenTest::Constants;

$| = 1;

if (osWindows()) {
  $SIG{CHLD} = "IGNORE";
}

if (defined $ENV{RQG_HOME}) {
  if (osWindows()) {
      $ENV{RQG_HOME} = $ENV{RQG_HOME}.'\\';
  } else {
      $ENV{RQG_HOME} = $ENV{RQG_HOME}.'/';
  }
}

my ($help, $build_thread, $scenario);
my %sc_opts;

my @ARGV_saved = @ARGV;
my $opt_result = GetOptions(
  'help' => \$help,
  'mtr-build-thread|mtr_build_thread=i' => \$build_thread,
  'scenario=s' => \$scenario,
  'seed=s' => \$sc_opts{seed},
);

if ($help) {
  help();
  exit 0;
}

if (!$opt_result) {
  print STDERR "\nERROR: Error occured while reading options\n\n";
  exit 1;
}

if (!$scenario) {
  print STDERR "\nERROR: Scenario is not defined\n\n";
  exit 1;
}

# Different scenarios can expect different options. Besides,
# some options can be defined per server, and different scenarios can
# define them differently. So, here we just want to store all of them
# and pass over to the scenario. Since we don't know how many servers
# the given scenario runs, it's impossible to put it all in GetOptions,
# thus we will parse them manually

foreach my $o (@ARGV) {
  if ($o =~ /^--(?:loose[-_])?mysqld=(\S+)$/) {
    if (not defined $sc_opts{mysqld}) {
      @{$sc_opts{mysqld}}= ();
    }
    push @{$sc_opts{mysqld}}, $1;
  }
  elsif ($o =~ /^--(?:loose[-_])?(mysqld\d+)=(\S+)$/) {
    if (not defined $sc_opts{$1}) {
      @{$sc_opts{$1}}= ();
    }
    push @{$sc_opts{$1}}, $2;
  }
  elsif ($o =~ /^--([-_\w]+)=(\S+)$/) {
    my $opt=$1;
    $opt =~ s/_/-/g;
    $sc_opts{$opt}= $2;
  }
  elsif ($o =~ /^--skip-([-_\w]+)$/) {
    my $opt=$1;
    $opt =~ s/_/-/g;
    $sc_opts{$opt}= 0;
  }
  elsif ($o =~ /^--([-_\w]+)$/) {
    my $opt=$1;
    $opt =~ s/_/-/g;
    $sc_opts{$opt}= 1;
  }
}

if (not defined $sc_opts{basedir} and not defined $sc_opts{basedir1}) {
  print STDERR "\nERROR: Basedir is not defined\n\n";
  exit 1;
}
elsif (not defined $sc_opts{basedir}) {
  $sc_opts{basedir}= $sc_opts{basedir1};
}

if (not defined $sc_opts{vardir} and not defined $sc_opts{vardir1}) {
  print STDERR "\nERROR: Vardir is not defined\n\n";
  exit 1;
}
elsif (not defined $sc_opts{vardir}) {
  $sc_opts{vardir}= $sc_opts{vardir1};
}

# Calculate initial port based on MTR_BUILD_THREAD
if (not defined $sc_opts{build_thread}) {
  if (defined $ENV{MTR_BUILD_THREAD}) {
    $sc_opts{build_thread} = $ENV{MTR_BUILD_THREAD}
  } else {
    $sc_opts{build_thread} = DEFAULT_MTR_BUILD_THREAD;
  }
}
if ( $sc_opts{build_thread} eq 'auto' ) {
  say ("Please set the environment variable MTR_BUILD_THREAD to a value <> 'auto' (recommended) or unset it (will take the value ".DEFAULT_MTR_BUILD_THREAD.") ");
  exit (STATUS_ENVIRONMENT_FAILURE);
}

$sc_opts{port}= 10000 + 10 * $sc_opts{build_thread};

if (defined $sc_opts{seed} and $sc_opts{seed} eq 'time') {
  $sc_opts{seed}= time();
}
my $cmd = $0 . " " . join(" ", @ARGV_saved);
$cmd =~ s/seed=time/seed=$sc_opts{seed}/g;
say("\nFinal command line: \nperl $cmd");

my $cp= my $class= "GenTest::Scenario::$scenario";
$cp =~ s/::/\//g;
require "$cp.pm";
my $sc= $class->new(
    properties => \%sc_opts
);

my $status= $sc->run();
say("[$$] $0 will exit with exit status ".status2text($status). " ($status)\n");
safe_exit($status);
