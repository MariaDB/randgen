  #!/usr/bin/perl

# Copyright (c) 2008, 2011 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2021, 2023 MariaDB
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

########################################################################
# At the top level, $combinations is an array reference.
# Each element of an array[ref] can be either a scalar, or hashref, or arrayref
#
# Elements combine as follows:
# Scalars don't combine with anything on the same level.
# From array[ref] one element is chosen and it's combines with other combinable elements
# at the same level;
# From hash[ref] one element is chosen. It combines with other combinable elements
# at the same level, but it doesn't combine with other hashref elements.
#
# Examples demonstrating the difference between hashref and arrayref:
#
# $combinations = [
#   '--opt1a',
#   '--opt1b',
#   [
#     '--opt2a',
#     '--opt2b'
#   ],
#   {
#      opt3 => [
#                 '--opt3a',
#                 '--opt3b'
#              ],
#      opt4 => [
#                 '--opt4a',
#                 '--opt4b'
#              ]
#   }
# ]
# Results in the following exhaustive set of combinations:
# --opt1a
# --opt1b
# --opt2a --opt3a
# --opt2a --opt3b
# --opt2a --opt4a
# --opt2a --opt4b
# --opt2b --opt3a
# --opt2b --opt3b
# --opt2b --opt4a
# --opt2b --opt4b
#
# $combinations = [
#   '--opt1a',
#   '--opt1b',
#   [
#     '--opt2a',
#     '--opt2b'
#   ],
#   [
#     [
#       '--opt3a',
#       '--opt3b'
#     ],
#     [
#       '--opt4a',
#       '--opt4b'
#     ]
#   ]
# ]
# Same as
# $combinations = [
#   '--opt1a',
#   '--opt1b',
#   [
#     '--opt2a',
#     '--opt2b'
#   ],
#   [
#     '--opt3a',
#     '--opt3b'
#   ],
#   [
#     '--opt4a',
#     '--opt4b'
#   ]
# ]

# Results in the following exhaustive set of combinations:
# --opt1a
# --opt1b
# --opt2a --opt3a --opt4a
# --opt2a --opt3b --opt4a
# --opt2a --opt3a --opt4b
# --opt2a --opt3b --opt4b
# --opt2b --opt3a --opt4a
# --opt2b --opt3b --opt4a
# --opt2b --opt3a --opt4b
# --opt2b --opt3b --opt4b

use strict;
use lib 'lib';
use lib "$ENV{RQG_HOME}/lib";
use Carp;
use Cwd;
use GenUtil;
use GenTest::Random;
use Constants;
use Getopt::Long;
use Getopt::Long qw( :config pass_through );
use Data::Dumper;
use File::Basename;
use File::Copy;
use File::Path qw(make_path);

use constant COMB_RQG_DEFAULT_BASE_PORT => 14000;

$| = 1;

if (defined $ENV{RQG_HOME}) {
  if (osWindows()) {
    $ENV{RQG_HOME} = $ENV{RQG_HOME}.'\\';
  } else {
    $ENV{RQG_HOME} = $ENV{RQG_HOME}.'/';
  }
} else {
  $ENV{RQG_HOME} = dirname(Cwd::abs_path($0));
}

if ( osWindows() ) {
  require Win32::API;
  my $errfunc = Win32::API->new('kernel32', 'SetErrorMode', 'I', 'I');
  my $initial_mode = $errfunc->Call(2);
  $errfunc->Call($initial_mode | 2);
};

$| = 1;

my $interrupted= 0;
my $total_status= STATUS_OK;

$SIG{TERM} = sub { exit(0) };
$SIG{CHLD} = "IGNORE" if osWindows();
$SIG{INT}= sub { \&group_cleaner; $interrupted=1; $total_status= STATUS_TEST_STOPPED if $total_status < STATUS_TEST_STOPPED };

# Options
my @basedirs=();
my $clean;
my $config_file;
my $discard_logs= 0;
my $dry_run= 0;
my $help= 0;
my $threads= 1;
my $trials= 0;
my $seed= 'time';
my $shuffle= 1;
my $workdir;
my $runall; # Backward compatibility, synonym of trials=all
# Config files may be parameterized depending on version number
my $version= '999999';

my @pass_through= ();

my $opt_result = GetOptions(
  'basedir=s@' => \@basedirs,
  'clean' => \$clean,
  'config=s' => \$config_file,
  'config-version|config_version=s' => \$version,
  'discard_logs|discard-logs' => \$discard_logs,
  'dry-run|dry_run' => \$dry_run,
  'help' => \$help,
  'shuffle!' => \$shuffle,
  'parallel=i' => \$threads,
  'run-all-combinations' => \$runall,
  'seed=s' => \$seed,
  'trials=s' => \$trials,
  'workdir=s' => \$workdir,
);

help() if $help;

if (defined $runall) {
  if ($trials) {
    sayWarning("Both --run-all-combinations and trials were defined, run-all-combinations will be ignored");
  } else {
    $trials= 'all';
  }
} elsif ($trials eq '0') {
  sayError("No trials requested");
  exit 1;
}

# Variables
my $combinations;
my %results;
my @commands;
my $max_result = 0;
my $thread_id = 0;
my $comb_seed= ($seed eq 'time' ? time() : $seed);

my $es= '';
if ($version =~ s/^es-//) {
  $es= 'es-';
}
if ($version =~ /^\d+\.\d+$/) {
  # config-version=10.6 means that *any* 10.6.x is good
  $version.= '.99';
}

$version= $es.versionN6($version);

help("ERROR: Config file must be provided") unless defined $config_file;
help("ERROR: Workdir must be provided") unless defined $workdir;
open(CONF, $config_file) or help("ERROR: Unable to open config file '$config_file': $!");
read(CONF, my $config_text, -s $config_file);
eval ($config_text);
help("ERROR: Unable to load $config_file: $@") if $@;

say("Using config=$config_file, workdir=$workdir, seed=$comb_seed, adjusted to version $version");

if (@ARGV) {
  sayDebug("Unrecognized options will be passed to the runner: @ARGV");
  @pass_through= @ARGV;
  @ARGV= ();
}



my $stdToLog = !osWindows() && $threads == 1;

my $prng = GenTest::Random->new(seed => $comb_seed);

my $thread_id;
my %pids;
for my $i (1..$threads) {
  my $pid = fork();
  if ($pid == 0) {
    $ENV{RQG_IMMORTALS}= "$$";
    ## Child
    $thread_id = $i;
    make_path($workdir);

    if ($trials eq 'all') {
      doExhaustive();
    } else {
      doRandom();
    }
    ## Children does not continue this loop
    last;
  } else {
    ##Parent
    $thread_id = 0;
    $pids{$pid}=$i;
    say("Started thread [$i] pid=$pid");
  }
}

if ($thread_id > 0) {
    sayDebug("Combinations [$thread_id]: will exit with exit status ".status2text($max_result).
        "($max_result)");
    exit($max_result);
} else {
    ## Parent
    $total_status = 0;
    while(1) {
      my $child = wait();
      last if $child == -1;
      my $exit_status = $? > 0 ? ($? >> 8) : 0;
      #say("Thread $pids{$child} (pid=$child) exited with $exit_status");
      $total_status = $exit_status if $exit_status > $total_status;
    }
    say("Combinations exit with exit status ".status2text($total_status)." ($total_status)");
    exit($total_status);
}



## ----------------------------------------------------

sub pickOne
{
  my $group= shift;
  if (ref $group eq '') {
    $group= [ $group ];
  }
  my $opt;
  $prng->shuffleArray($group);
  foreach my $element (@$group) {
    if (ref $element eq '' and not defined $opt) {
      # Regular scalar element, using exclusively
      $opt= $element;
      last;
    }
    elsif (ref $element eq 'ARRAY') {
      # Group of alternatives, need to pick one option
      my $combo= pickOne($element);
      $opt.= ' '.$combo;
    }
    elsif (ref $element eq 'HASH') {
      # Hashref represents exclusive options.
      # Exclusives only combine with regular alternatives,
      # But not with other exclusives of the same level.
      # In other words, we only pick one element from the hash.
      my @keys= sort keys %$element;
      $prng->shuffleArray(\@keys);
      my $o= shift @keys;
      my $combo= pickOne($element->{$o});
      $opt.= ' '.$combo;
    }
  }
  return $opt;
}

sub flattenCombinations
{
  my $group= shift;
  if (ref $group eq '') {
    $group= [ $group ];
  }
  my @combinations= ();
  my @alts= ();
  my @exclusives= ();
  foreach my $g (@$group) {
    if (ref $g eq '') {
      # Regular scalar element, doesn't combine with anything else,
      # so adding to combinations as is
      push @combinations, $g;
    } elsif (ref $g eq 'ARRAY') {
      # Group of alternatives
      # need a cartesian product with all previous alternatives
      my $flattened= flattenCombinations($g);
      if ($flattened and scalar(@$flattened)) {
        if (scalar(@alts)) {
          my @new_alts= ();
          foreach my $f (@$flattened) {
            foreach my $a (@alts) {
              push @new_alts, "$a $f";
            }
          }
          @alts= @new_alts;
        } else {
          @alts= ( @$flattened );
        }
      }
    } elsif (ref $g eq 'HASH') {
      # Exclusives only combine with regular alternatives,
      # But not with other exclusives on the same level
      # (and of course not with scalars)
      foreach my $e (sort keys %$g) {
        push @exclusives, @{flattenCombinations($g->{$e})};
      }
    }
  }
  # Now we need to combine alternatives with exclusives
  # and add results to combinations
  if (scalar(@exclusives)) {
    if (scalar(@alts)) {
      foreach my $e (@exclusives) {
        foreach my $a (@alts) {
          push @combinations, "$a $e";
        }
      }
    } else {
      push @combinations, @exclusives;
    }
  } else {
    push @combinations, @alts;
  }
  return \@combinations;
}

my $trial_counter = 0;

sub doExhaustive {
  my $flattened= flattenCombinations($combinations);
  my @combinations= ();
  # Beautify the names
  my $num= scalar(@$flattened);
  my $len= 1;
  while (($num=int($num/10)) >= 1) {
    $len++;
  }
  my $n= 0;
  foreach my $k (@$flattened) {
    $n++;
    push @combinations, $k
  }
  $trials= scalar(@combinations);

  if ($shuffle) {
    $prng->shuffleArray(\@combinations);
  }
  foreach my $e (@combinations) {
    $trial_counter++;
    doCombination($trial_counter,$e,"combination");
    last if $interrupted;
  }
}

## ----------------------------------------------------

sub doRandom {
  foreach my $trial_id (1..$trials) {
    my $c= pickOne($combinations);
    doCombination($trial_id,$c,"random trial");
    last if $interrupted;
  }
}

## ----------------------------------------------------
sub doCombination {
  my ($trial_id,$comb_str,$comment) = @_;


  return if (($trial_id -1) % $threads +1) != $thread_id;
  say("#============================================================");
  say("Combinations [$thread_id]: running $comment (".$trial_id."/".$trials.")");

#  my $command = "
#    perl ".($Carp::Verbose?"-MCarp=verbose ":"").
#        (defined $ENV{RQG_HOME} ? $ENV{RQG_HOME}."/" : "./" ).
#        "run.pl $comb_str ";

  # Split arguments back into an array. We do it this way rather than
  # making an array from the start, because some arguments come from
  # combinations file as a string already, '--x --y' etc., so they
  # would need splitting anyway
  my @args= ("--compatibility=$version");
  while ($comb_str =~ s/^\s*(\".*?\"|--[^\s]+)//) {
    my $arg= $1;
    chomp $arg;
    $arg =~ s{[\t\r\n]}{ }sgio;
    push @args, $arg;
  }

  push @args, "--base-port=".COMB_RQG_DEFAULT_BASE_PORT;
  foreach (@basedirs) {
    push @args, "--basedir=".$_;
  }
  push @args, "--seed=$seed";
  push @args, @pass_through;

  my $runscript= (defined $ENV{RQG_HOME} ? $ENV{RQG_HOME}."/run.pl" : "./run.pl");
  require "$runscript";

  # Count the number of basedirs in the final string to add the vardirs
  my $vardir= "$workdir/current1_${thread_id}";
  push @args, "--vardir=$vardir";

  $commands[$trial_id] = [ @args ];

  say("Combinations [$thread_id]: arguments: @args");
  unless ($dry_run)
  {
    my $result= STATUS_PERL_FAILURE;
    my $cmd_pid= fork();
    if ($cmd_pid) {
      # Parent, waiting for command execution to finish
      waitpid($cmd_pid,0);
      $result= ($? >> 8);
    } elsif (defined $cmd_pid) {
      # Command execution
      my $r= run(@args);
      exit $r;
    } else {
      sayError("Could not for for command execution");
    }
    group_cleaner();
    # Post-execution activities
    my $tl = $workdir.'/trial'.$trial_id.'.log';
    move("$vardir/trial.log",$tl);
    if (defined $clean && $result == 0) {
      say("Combinations [$thread_id]: test run exited with exit status ".status2text($result)."($result). Clean mode active: deleting this OK log");
      system("rm -f $tl");
    } else {
      say("Combinations [$thread_id]: test run exited with exit status ".status2text($result)."($result), see $tl");
    }

    $max_result = $result if $result > $max_result;

    my $from = $workdir.'/current1_'.$thread_id;
    system("$ENV{RQG_HOME}\\util\\unlock_handles.bat -nobanner \"$from\"") if osWindows() and -e "\"$from\"";
    if ($result > 0 and not $discard_logs) {
      my $to = $workdir.'/vardir1_'.$trial_id;
      sayDebug("Combinations [$thread_id]: Copying $from to $to") if $stdToLog;
      if (osWindows() and -e $from) {
        system("move \"$from\" \"$to\"");
        system("move \"$from"."_slave\" \"$to\"") if -e $from.'_slave';
        open(OUT, ">$to/command");
        print OUT "@args";
        close(OUT);
      } else {
        system("cp -r $from $to") if -e $from;
        system("cp -r $from"."_slave $to") if -e $from.'_slave';
        open(OUT, ">$to/command");
        print OUT "@args";
        close(OUT);
        if (defined $clean) {
          say("Combinations [$thread_id]: Clean mode active & failed run (".status2text($result)."): Archiving this vardir");
          system('rm -f '.$workdir.'/vardir1_'.$trial_id.'/tmp/master.sock');
          system('tar zhcf '.$workdir.'/vardir1_'.$trial_id.'.tar.gz -C '.$workdir.' ./vardir1_'.$trial_id);
          system("rm -Rf $to");
        }
      }
    }
    $results{$result >> 8}++;
  }
}

sub help {
    print <<EOF

$0 - Run a set of RQG tests

    Options:

    --basedir=<location>   : Specifies the base directory of a server (use multiple --basedir=x --basedir=y for each server). Must be provided either as an option or in the config file
    --clean                : Optional, default OFF. If provided, logs of successful runs will be removed. Default OFF
    --config=<location>    : MANDATORY. Location of the combinations config file
    --discard-logs         : Optional, default OFF. If provided, vardirs of failed runs will not be preserved
    --shuffle              : Optional, default ON. Randomize the order of selected combinations. Can be switched off by --noshuffle
    --parallel=N           : Optional, default 1. The number of parallel processes running combinations
    --run-all-combinations : Optional, default OFF. If provided, all combinations constructed based on the config file will be run (as opposed to --trials=N)
    --seed=[N|time]        : Optional, default 'time' (epoch seconds). A number used for randomization across the RQG execution
    --trials=N             : Optional, default 1. The number of combinations to execute, out of all constructed based on the config file (as opposed to --run-all-combinations)
    --workdir=<location>   : MANDATORY. Specifies the working directory (location of vardirs for all test runs)
    --help                 : This help message
EOF
    ;
    print "\n";
    if (scalar(@_)) {
      foreach (@_) {
        print STDERR "ERROR: $_\n";
      }
      print "\n";
      exit STATUS_ENVIRONMENT_FAILURE;
    }
    exit 0;
}
