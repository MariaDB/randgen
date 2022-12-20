  #!/usr/bin/perl

# Copyright (c) 2008, 2011 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2021, 2022 MariaDB Corporation Ab.
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

use strict;
use lib 'lib';
use lib "$ENV{RQG_HOME}/lib";
use Carp;
use Cwd;
use GenUtil;
use GenTest::Random;
use GenTest::Constants;
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

$ENV{RQG_IMMORTALS}="$$";
$SIG{TERM} = sub { exit(0) };
$SIG{CHLD} = "IGNORE" if osWindows();
#$SIG{INT}= sub { \&group_cleaner };

# Options
my @basedirs=();
my $clean;
my $config_file;
my $discard_logs= 0;
my $dry_run= 0;
my $exhaustive= 0;
my $force= 1;
my $help= 0;
my $threads= 1;
my $trials= 1;
my $seed= 'time';
my $shuffle= 1;
my $workdir;
# Config files may be parameterized depending on version number
my $version= '999999';

my $opt_result = GetOptions(
  'basedir=s@' => \@basedirs,
  'clean' => \$clean,
  'config=s' => \$config_file,
  'config-version|config_version=s' => \$version,
  'discard_logs|discard-logs' => \$discard_logs,
  'dry-run|dry_run' => \$dry_run,
  'force!' => \$force,
  'help' => \$help,
  'shuffle!' => \$shuffle,
  'parallel=i' => \$threads,
  'run-all-combinations' => \$exhaustive,
  'seed=s' => \$seed,
  'trials=i' => \$trials,
  'workdir=s' => \$workdir,
);

if (@ARGV) {
  say("Unrecognized options will be passed to the runner: @ARGV");
}

help() if $help;

# Variables
my $combinations;
my %results;
my @commands;
my $max_result = 0;
my $thread_id = 0;
my $comb_seed= ($seed = 'time' ? time() : $seed);

$version= versionN6($version);

help("ERROR: Config file must be provided") unless defined $config_file;
help("ERROR: Workdir must be provided") unless defined $workdir;
open(CONF, $config_file) or help("ERROR: Unable to open config file '$config_file': $!");
read(CONF, my $config_text, -s $config_file);
eval ($config_text);
help("ERROR: Unable to load $config_file: $@") if $@;

say("Using config=$config_file, workdir=$workdir, seed=$comb_seed");

my $stdToLog = !osWindows() && $threads == 1;

my $prng = GenTest::Random->new(seed => $comb_seed);

my $thread_id;
my %pids;
for my $i (1..$threads) {
  my $pid = fork();
  if ($pid == 0) {
    $ENV{RQG_IMMORTALS}.= ",$$";
    ## Child
    $thread_id = $i;
    make_path($workdir);

    if ($exhaustive) {
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
    say("[$thread_id] will exit with exit status ".status2text($max_result).
        "($max_result)");
    exit($max_result);
} else {
    ## Parent
    my $total_status = 0;
    while(1) {
      my $child = wait();
      last if $child == -1;
      my $exit_status = $? > 0 ? ($? >> 8) : 0;
      #say("Thread $pids{$child} (pid=$child) exited with $exit_status");
      $total_status = $exit_status if $exit_status > $total_status;
    }
    say("$0 will exit with exit status ".status2text($total_status).
        "($total_status)");
    exit($total_status);
}



## ----------------------------------------------------

sub pickOne
{
  my ($group)= @_;
  my $opt= [];
  $opt->[0]= '';
  $prng->shuffleArray($group);
  foreach my $element (@$group) {
    if (ref $element eq '') {
      # Regular scalar element, adding to options
      $opt->[1].= ' '.$element;
      last;
    }
    elsif (ref $element eq 'ARRAY') {
      # Group of alternatives, need to pick one option
      my $combo= pickOne($element);
      $opt->[1].= ' '.$combo->[1];
      if ($combo->[0]) {
        $opt->[0]= ($opt->[0] ? $opt->[0].'-'.$combo->[0] : $combo->[0]);
      }
    }
    elsif (ref $element eq 'HASH') {
      # Exclusives only combine with regular alternatives,
      # But not with other exclusives on the same level.
      # So, we'll keep them separate instead of combining right away,
      # and will only do it after the loop is finished
      my @keys= sort keys %$element;
      $prng->shuffleArray(\@keys);
      my $o= shift @keys;
      $opt->[0]= ($opt->[0] ? $opt->[0].'-'.$o : $o);
      my $combo= pickOne($element->{$o});
      $opt->[1].= ' '.$combo->[1];
      last;
    }
  }
  return $opt;
}

sub flattenCombinations
{
  my ($name, $group)= @_;
  my @alts= ();
  my @exclusives= ();
  foreach my $g (@$group) {
    if (ref $g eq '') {
      # Regular scalar element, adding to alternatives
      push @alts, [ $name || '', $g ];
    }
    elsif (ref $g eq 'ARRAY') {
      # Group of alternatives,
      # need a cartesian product with all previous combinations
      my $set= flattenCombinations($name, $g);
      my @new_alts= ();
      if (scalar(@alts)) {
        foreach my $a (@alts) {
          foreach my $e (@$set) {
            my $name= ($a->[0] ? ($e->[0] ? $a->[0].'-'.$e->[0] : $a->[0]) : ($e->[0] || ''));
            push @new_alts, [ $name, $a->[1].' '.$e->[1] ];
          }
        }
      } else {
        @new_alts= @$set;
      }
      @alts= @new_alts;
    }
    elsif (ref $g eq 'HASH') {
      # Exclusives only combine with regular alternatives,
      # But not with other exclusives on the same level.
      # So, we'll keep them separate instead of combining right away,
      # and will only do it after the loop is finished
      foreach my $e (sort keys %$g) {
        push @exclusives, [ $e, flattenCombinations($name, $g->{$e}) ];
      }
    }
  }
  if (scalar(@exclusives)) {
    my @new_alts= ();
    foreach my $e (@exclusives) {
      foreach my $c (@{$e->[1]}) {
        if (scalar(@alts)) {
          foreach my $a (@alts) {
            my $name= $e->[0];
            if ($a->[0]) {
              $name= $a->[0].'-'.$name;
            }
            if ($c->[0]) {
              $name= $name.'-'.$c->[0];
            }
            push @new_alts, [$name, $c->[1]];
          }
        } else {
          my $name= $e->[0];
          if ($c->[0]) {
            $name.= '-'.$c->[0];
          }
          push @new_alts, [$name, $c->[1]];
        }
      }
    }
    @alts= @new_alts;
  }
  return \@alts;
}

my $trial_counter = 0;

sub doExhaustive {
  my $flattened= flattenCombinations('',$combinations,[]);
  my @combinations= ();
  # Beautify the names
  my $num= scalar(@$flattened);
  my $len= 1;
  while (($num=int($num/10)) >= 1) {
    $len++;
  }
  my $n= 0;
  foreach my $e (@$flattened) {
    $n++;
    my $k= $e->[0];
    while ( $k=~ s/(?:\-\d+|\d+\-)//g ) {};
    $k= sprintf("%0${len}d-$k", $n);
    $k=~ s/\-$//;
    push @combinations, [$k, $e->[1]]
  }
  $trials= scalar(@combinations);

  if ($shuffle) {
    $prng->shuffleArray(\@combinations);
  }
  foreach my $e (@combinations) {
    $trial_counter++;
    doCombination($trial_counter,$e->[1],"combination ".$e->[0]);
  }
}

## ----------------------------------------------------

sub doRandom {
  foreach my $trial_id (1..$trials) {
    my $c= pickOne($combinations);
    doCombination($trial_id,$c->[1],"random trial ".$c->[0]);
  }
}

## ----------------------------------------------------
sub doCombination {
    my ($trial_id,$comb_str,$comment) = @_;

    return if (($trial_id -1) % $threads +1) != $thread_id;
    say("#============================================================");
    say("[$thread_id] Running $comment (".$trial_id."/".$trials.")");

  my $command = "
    perl ".($Carp::Verbose?"-MCarp=verbose ":"").
        (defined $ENV{RQG_HOME} ? $ENV{RQG_HOME}."/" : "./" ).
        "run.pl $comb_str ";

  $command .= " --base-port=".COMB_RQG_DEFAULT_BASE_PORT;
  foreach (@basedirs) {
    $command .= " --basedir=".$_." ";
  }
  my $tm= time();
  if ($command =~ s/--seed=time/--seed=$tm/g) {}
  elsif ($command !~ /--seed=/) {
    $command .= " --seed=".($seed eq 'time' ? $tm : $seed)." ";
  }

  $command.= " @ARGV";

  # Count the number of basedirs in the final string to add the vardirs
  my $vardir= "$workdir/current1_${thread_id}";
  $command .= " --vardir=$vardir ";

  $command =~ s{[\t\r\n]}{ }sgio;
  $commands[$trial_id] = $command;
  $command =~ s{"}{\\"}sgio;

  while ($command =~ s/\s\s/ /g) {};
  $command =~ s/^\s*//;
  say("[$thread_id] $command\n");

  unless ($dry_run)
  {
    # Command execution
    my $result= system($command);
    $result= $result >> 8;
    group_cleaner();
    # Post-execution activities
    my $tl = $workdir.'/trial'.$trial_id.'.log';
    move("$vardir/trial.log",$tl);
    if (defined $clean && $result == 0) {
      say("[$thread_id] run.pl exited with exit status ".status2text($result)."($result). Clean mode active: deleting this OK log");
      system("rm -f $tl");
    } else {
      say("[$thread_id] run.pl exited with exit status ".status2text($result)."($result), see $tl");
    }
    exit($result) if (($result == STATUS_ENVIRONMENT_FAILURE) || ($result == 255)) && (not defined $force);

    $max_result = $result if $result > $max_result;

    my $from = $workdir.'/current1_'.$thread_id;
    system("$ENV{RQG_HOME}\\util\\unlock_handles.bat -nobanner \"$from\"") if osWindows() and -e "\"$from\"";
    if ($result > 0 and not $discard_logs) {
      my $to = $workdir.'/vardir1_'.$trial_id;
      say("[$thread_id] Copying $from to $to") if $stdToLog;
      if (osWindows() and -e $from) {
        system("move \"$from\" \"$to\"");
        system("move \"$from"."_slave\" \"$to\"") if -e $from.'_slave';
        open(OUT, ">$to/command");
        print OUT $command;
        close(OUT);
      } else {
        system("cp -r $from $to") if -e $from;
        system("cp -r $from"."_slave $to") if -e $from.'_slave';
        open(OUT, ">$to/command");
        print OUT $command;
        close(OUT);
        if (defined $clean) {
          say("[$thread_id] Clean mode active & failed run (".status2text($result)."): Archiving this vardir");
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
    --force                : Optional, default ON. Continue running even when a test ended with a critical failure. Can be switched off by --noforce
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
      exit 1;
    }
    exit 0;
}
