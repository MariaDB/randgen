#!/usr/bin/perl

# Copyright (c) 2010, 2012, Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2019, 2022, MariaDB Corporation Ab.
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

unless (defined $ENV{RQG_HOME}) {
  use File::Basename qw(dirname);
  use Cwd qw(abs_path);
  $ENV{RQG_HOME}= abs_path(dirname($0));
}
use lib 'lib';
# This can cause "uninitialized" errors, but we need it in case
# the script is called from outside the RQG basedir
use lib "$ENV{RQG_HOME}/lib";

use Carp;
use Data::Dumper;
use File::Path qw(mkpath remove_tree);
use Getopt::Long qw( :config pass_through );
use POSIX;
use strict;
use GenUtil;
use GenTest::Constants;
use GenTest::Properties;
use GenTest::GenConfig;

use constant RQG_DEFAULT_SCENARIO  => 'Standard';
use constant RQG_DEFAULT_BASE_PORT => 19000;

$Carp::Verbose= 1;
$| = 1;

if (osWindows()) {
  $SIG{CHLD} = { print "Caught signal\n" };
}

if (defined $ENV{RQG_HOME}) {
  if (osWindows()) {
    $ENV{RQG_HOME} = $ENV{RQG_HOME}.'\\';
  } else {
    $ENV{RQG_HOME} = $ENV{RQG_HOME}.'/';
  }
}

use Getopt::Long;
use GenTest::Constants;
use DBI;
use Cwd;

my ($help,
    $props, %scenario_options, %server_options,
    $scenario, $genconfig, $minio, $build_thread,
    @exit_status, $trials, $output, $force,
   );

unless ($ENV{RQG_IMMORTALS}) {
  $ENV{RQG_IMMORTALS}.= "$$";
  $SIG{INT}= \&group_cleaner;
}

# Defaults
$props->{user}= 'rqg';
$props->{threads}= 4;
$props->{queries}= 100000000;
$props->{duration}= 300;
$props->{seed}= 'time';
$props->{metadata_reload}= 1;
$props->{base_port}= RQG_DEFAULT_BASE_PORT;

$trials= 1;
$scenario= RQG_DEFAULT_SCENARIO;

my @ARGV_saved = @ARGV;

%server_options= (
  basedir     => undef,
  engine      => undef,
  manual_gdb  => undef,
  mysqld      => undef,
  partitions  => undef,
  ps          => undef,
  rr          => undef,
  valgrind    => undef,
  vcols       => undef,
  views       => undef,
);

my $opt_result = GetOptions(
  #
  # Server-related options
  'basedir=s' => \$server_options{basedir},
  'engine=s' => \$server_options{engine},
  'manual-gdb|manual_gdb' => \$server_options{manual_gdb},
  'mysqld=s@' => \@{$server_options{mysqld}},
  'partitions!'   => \$server_options{partitions},
  'ps_protocol|ps-protocol' => \$server_options{ps},
  'rr!' => \$server_options{rr},
  'valgrind:s'    => \$server_options{valgrind},
  'vcols:s'        => \$server_options{vcols},
  'views:s'        => \$server_options{views},
  #
  # General options
  'annotate_rules|annotate-rules' => \$props->{annotate_rules},
  'base-port|base_port=i' => \$props->{base_port},
  'compatibility=s' => \$props->{compatibility},
  'debug' => \$props->{debug},
  'duration=i' => \$props->{duration},
  'filters=s@'    => \@{$props->{filters}},
  'freeze_time|freeze-time' => \$props->{freeze_time},
  'genconfig=s' => \$genconfig,
  'gendata=s@' => \@{$props->{gendata}},
  'grammars=s@' => \@{$props->{grammars}},
  'help' => \$help,
  'metadata_reload|metadata-reload!' => \$props->{metadata_reload},
  'minio|with-minio|with_minio' => \$minio,
  'parser=s' => \$props->{parser},
  'parser-mode|parser_mode=s' => \$props->{parser_mode},
  'queries=s' => \$props->{queries},
  'redefines=s@' => \@{$props->{redefines}},
  'reporters=s@' => \@{$props->{reporters}},
  'restart_timeout|restart-timeout=i' => \$props->{restart_timeout},
  'rows=s' => \$props->{rows},
  'scenario:s' => \$scenario,
  'seed=s' => \$props->{seed},
  'short_column_names|short-column-names!' => \$props->{short_column_names},
  'sqltrace:s' => \$props->{sqltrace},
  'threads=i' => \$props->{threads},
  'transformers=s@' => \@{$props->{transformers}},
  'validators=s@' => \@{$props->{validators}},
  'variators=s@' => \@{$props->{variators}},
  'vardir=s' => \$props->{vardir},
  #
  # Options related to re-running and reproducing
  'exit_status|exit-status=s@' => \@exit_status,
  'force' => \$force,
  'output=s' => \$output,
  'trials=i' => \$trials,
);

# Given that we use pass_through, it would be some very unexpected error
if (!$opt_result) {
  help("Error occured while reading options: $!");
}

if ($help) {
  help();
}

if ( osWindows() && !$props->{debug} )
{
  require Win32::API;
  my $errfunc = Win32::API->new('kernel32', 'SetErrorMode', 'I', 'I');
  my $initial_mode = $errfunc->Call(2);
  $errfunc->Call($initial_mode | 2);
};

# We collect common and per-server options the following way:
# - collect allowed per-server options (serverN-xxx, where xxx is among
#   keys of %server_specific) in a hash for each found N;
# - for each server in the resulting hash, fill missing options
#   (except for mysqld ones) with common values if defined;
# - for each server in the resulting hash, construct the array of mysqld options
#   by using the common one first (if exist), and adding server-specific
#   (if exist) at the end of the array

my $server_specific= { 1 => () };
my @unknown_options;
foreach my $o (@ARGV) {
  if ($o =~ /^--scenario-([^=]+)(?:=(.*))?$/) {
    $scenario_options{$1}= $2;
  } elsif ($o =~ /^--(?:server|srv)(\d+)-([^=]+)(?:=(.*))?$/) {
    if (exists $server_options{$2}) {
      my %opts= $server_specific->{$1} ? %{$server_specific->{$1}} : ();
      if ($2 eq 'mysqld') {
        $opts{$2}= exists $opts{$2} ? [ @{$opts{$2}}, $3 ] : [ $3 ];
      } else {
        $opts{$2}= $3;
      }
      %{$server_specific->{$1}}= %opts;
    } else {
      push @unknown_options, $o;
    }
  } else {
    push @unknown_options, $o;
  }
}

foreach my $s (keys %$server_specific) {
  for my $o (keys %server_options) {
    if ($o eq 'mysqld') {
      @{$server_specific->{$s}{mysqld}}= $server_specific->{$s}{mysqld} ? ( @{$server_options{mysqld}}, @{$server_specific->{$s}{mysqld}} ) : ( @{$server_options{mysqld}} );
    } elsif (defined $server_options{$o} and not exists ${$server_specific->{$s}}{$o}) {
      ${$server_specific->{$s}}{$o}= $server_options{$o};
    }
  }
}

if (scalar(@unknown_options)) {
  help("Unknown options: @unknown_options");
}

#-------------------
# Mandatory options

unless ($server_specific->{1}{basedir}) {
  help("At least one basedir must be defined");
}
unless ($props->{vardir}) {
  help("Vardir must be defined");
}

#-------------------

$props->{server_specific}= $server_specific;

if (-d $props->{vardir}) {
  remove_tree($props->{vardir});
}
mkpath($props->{vardir});
open (STDOUT, "| tee -ai ".$props->{vardir}."/trial.log");
open STDERR, ">&STDOUT";

$props->{queries} =~ s/K/000/so;
$props->{queries} =~ s/M/000000/so;

if ($props->{compatibility}=~ /([0-9]+)\.([0-9]+)\.([0-9]+)-([0-9]+)/) {
  $props->{compatibility}= sprintf("%02d%02d%02de",int($1),int($2),int($3));
} elsif ($props->{compatibility}=~ /([0-9]+)\.([0-9]+)(?:\.([0-9]+))?/) {
  $props->{compatibility}= sprintf("%02d%02d%02d",int($1),int($2),int($3||0));
}

if (defined $props->{parser}) {
  $props->{generator}= 'FromParser';
}

my $git_rev= `cd $ENV{RQG_HOME} && git log -1 --pretty=%h`;
if ($git_rev) {
  # Apparently git command succeeded
  chomp $git_rev;
  system("cd $ENV{RQG_HOME} && git diff > ".$props->{vardir}."/rqg.$git_rev.diff");
  say("RQG git revision $git_rev".((-s $props->{vardir}."/rqg.diff") ? ' with local changes' : ''));
  say("###############################################################");
} else {
  sayWarning("Could not get RQG git revision");
}

say("Starting \n# $0 \\ \n# ".join(" \\ \n# ", @ARGV_saved));

if (defined $props->{sqltrace}) {
  # --sqltrace may have a string value (optional).
  # Allowed values for --sqltrace:
  my %sqltrace_legal_values = (
    'MarkErrors'    => 1  # Indicates invalid SQL statements for easier post-processing
  );

  if (length($props->{sqltrace}) > 0) {
    # A value is given, check if it is legal.
    if (not exists $sqltrace_legal_values{$props->{sqltrace}}) {
      help("Invalid value for --sqltrace option: '$props->{sqltrace}'.\n".
           "Valid values are: [".join(', ', keys(%sqltrace_legal_values))."]. ".
           "No value means that default/plain sqltrace will be used."
          );
    }
  } else {
    # If no value is given, GetOpt will assign the value '' (empty string).
    # We interpret this as plain tracing (no marking of errors, prefixing etc.).
    # Better to use 1 instead of empty string for comparisons later.
    $props->{sqltrace} = 1;
  }
}

## Multiple-value parameters may be given as comma-separated strings
foreach my $p (qw(engines filters gendatas grammars redefines reporters transformers validators variators)) {
  my @vals= ();
  foreach my $v (@{$props->{$p}}) {
    push @vals, split ',', $v;
  }
  $props->{$p}= [ @vals ];
}

if ($genconfig) {
  unless (-e $genconfig) {
      help("Specified config template $genconfig does not exist");
  }
}

# Push the number of "worker" threads into the environment.
# lib/GenTest/Generator/FromGrammar.pm will generate a corresponding grammar element.
$ENV{RQG_THREADS}= $props->{threads};

# Configure MinIO if it's installed and running
# (it seems an overkill to start the server here, since it will be rarely needed)
if ($minio) {
  if (system("mc alias set local http://127.0.0.1:9000 minio minioadmin && ( mc rb --force local/rqg || true ) && mc mb local/rqg")) {
    sayWarning("Could not configure S3 backend");
    $ENV{S3_DOABLE}= '';
  } else {
    say("S3 backend has been configured");
    $ENV{S3_DOABLE}= '!100501';
  }
}

my $cp= my $class= "GenTest::Scenario::$scenario";
$cp =~ s/::/\//g;
require "$cp.pm";

my $status= STATUS_OK;
my $trial_result= 0;

my $props_vardir_orig= $props->{vardir};
my $props_seed_orig= $props->{seed};

# There will be differences in logging etc. depending on whether it's
# a normal single run (as previously by runall-new), or it is a search
# run, either with multiple trials, or with search targets, or both

my $search_mode= $trials > 1 || defined $output || scalar(@exit_status);

TRIALS:
foreach my $trial_id (1..$trials)
{
  my $cmd = $0 . " " . join(" ", @ARGV_saved);
  $props->{seed}= time() if $props_seed_orig eq 'time';
  $cmd =~ s/--seed=\S+//g;
  $cmd.= " --seed=$props->{seed}";

  if ($trials > 1) {
    say("##########################################################");
    say("Running trial ".$trial_id."/".$trials);
    $props->{vardir}= $props_vardir_orig."/trial.${trial_id}";
    mkpath($props->{vardir});
    open (STDOUT, "| tee -ai ".$props->{vardir}."/trial.log");
    open STDERR, ">&STDOUT";
  }

  my $output_file= $props_vardir_orig."/trial$trial_id.log";
  $cmd = 'bash -c "set -o pipefail; '.$cmd.' 2>&1 | tee -i '.$output_file.'"';

  if ($genconfig) {
    my $cnf_contents = GenTest::GenConfig->new(spec_file => $genconfig,
                                               seed => $props->{seed},
                                               debug => $props->{debug}
    );
    $props->{cnf}= $props->{vardir}.'/my.cnf';
    open(CONFIG,'>'.$props->{cnf}) || help("Could not open file ".$props->{cnf}." for writing: $!");
    print CONFIG @$cnf_contents;
    close(CONFIG);
  }

  say("Final command line: \n$cmd");

  my $config = GenTest::Properties->init($props);
  my $sc= $class->new(properties => $config, scenario_options => \%scenario_options);
  unless (defined $sc) {
    $status= STATUS_ENVIRONMENT_FAILURE;
    last;
  }
  my $res= STATUS_PERL_FAILURE;
  eval { $res= $sc->run(); } ; warn $@ if $@;
  $status= $res if $res > $status;
  my $resname= status2text($res);
  group_cleaner();
  if ($search_mode) {
    say("Trial $trial_id ended with exit status $resname ($res)");
    my $check_result= check_for_desired_result($resname,$output_file);
    if ($check_result) {
      $trial_result= 1;
      last TRIALS unless $force;
    }
    remove_tree($props->{vardir}) unless ($check_result || $res != STATUS_OK);
  }
}

say("$0 will exit with exit status ".status2text($status). " ($status)\n");
if ($search_mode) {
  say("Test runs apparently ".($trial_result ? "achieved the expected outcome" : "failed to achieve the expected outcome"));
}

safe_exit($status);

###############################################

# NOTE: subroutine returns 1 if the goal was achieved, and 0 otherwise
sub check_for_desired_result
{
  my ($resname, $output_file) = @_;
  return $resname ne 'STATUS_OK' unless (defined $output || scalar(@exit_status));

  if (scalar @exit_status) {
    my $exit_status_matches= 0;
    foreach (@exit_status) {
      if ($resname eq $_) {
        $exit_status_matches= 1;
        last;
      }
    }
    unless ($exit_status_matches) {
      say("Exit status $resname is not on the list of desired status codes (@exit_status), it will be ignored");
      return 0;
    }
  }

  if ($output) {
    my @output_files= ($output_file);
    foreach my $srvnum (keys %{$props->server_specific}) {
      if (-e $props->{vardir}."/s${srvnum}/mysql.err") {
        push @output_files, $props->{vardir}."/s${srvnum}/mysql.err";
      }
    }
    my $output_matches= 0;
    FL:
    foreach my $f (@output_files) {
      unless (open(OUTFILE, "$f")) {
        sayError("Could not open $f for reading: $!");
        say("Cannot check if output matches the pattern, result will be ignored");
        return 0;
      }
      while (<OUTFILE>) {
        if (/$output/) {
          $output_matches= 1;
          close(OUTFILE);
          last FL;
        }
      }
      close(OUTFILE);
    }
    unless ($output_matches) {
      say("Output did not match the pattern \'$output\', result will be ignored");
      return 0;
    }
  }

  # If we are here, we have achieved the goal, we just need to produce a proper log message

  my $line= "The trial achieved the expected result: exit status $resname";
  if (scalar @exit_status) {
      $line.= ", matches one of desired exit codes [@exit_status]";
  }
  if ($output) {
      $line.= ", output \'$output\' has been found";
  }
  say($line);
  return 1;
}

sub help {
    print <<EOF

$0 - Run a complete random query generation test scenario

    Options related to the server(s):

    --basedir   : Specifies the base directory of a server
    --mysqld    : Options passed to the server(s)
    --vardir    : Mandatory, full path to the vardir

    General options

    --base-port : Start of the port range used for the servers
    --grammar   : Grammar file to use when generating queries (can be used multiple times)
    --redefine  : Grammar file(s) to redefine and/or add rules to the given grammar
    --engine    : Table engine(s) to use when creating tables with gendata (default no ENGINE in CREATE TABLE).
                : Multiple engines should be provided as a comma-separated list.
                  Separate values for separate servers can be provided through --engine1 | --engine2 | --engine3
    --threads   : Number of threads to spawn (default $props->{default_threads});
    --queries   : Number of queries to execute per thread (default $props->{default_queries});
    --duration  : Duration of the test in seconds (default $props->{duration} seconds);
    --validator(s) : The validators to use
    --reporter  : The reporters to use
    --transformer(s): The transformers to use (turns on --validator=transformer). Accepts comma separated list
    --variator(s): Variators to use. Accepts comma separated list
    --gendata   : Generate data option. Passed to gentest.pl / GenTest. Takes a data template (.zz file)
                  as an optional argument. Without an argument, indicates the use of GendataSimple (default)
    --gendata-advanced: Generate the data using GendataAdvanced instead of default GendataSimple
    --seed      : PRNG seed. Passed to gentest.pl
    --rows      : No of rows. Passed to gentest.pl
    --rr        : Run the server under rr record, if available
    --sqltrace  : Print all generated SQL statements.
                  Optional: Specify --sqltrace=MarkErrors to mark invalid statements.
    --vcols     : Types of virtual columns (only used if data is generated by GendataSimple or GendataAdvanced)
    --views     : Generate views. Optionally specify view type (algorithm) as option value. Passed to gentest.pl.
                  Different values can be provided to servers through --views1 | --views2 | --views3
    --valgrind  : Passed to gentest.pl
    --filter    : Suppress queries which match given patterns. Multiple filters can be provided
    --debug     : Debug mode
    --short_column_names: use short column names in gendata (c<number>)
    --freeze_time: Freeze time for each query so that CURRENT_TIMESTAMP gives the same result for all transformers/validators
    --annotate-rules: Add to the resulting query a comment with the rule name before expanding each rule.
                      Useful for debugging query generation, otherwise makes the query look ugly and barely readable.
    --wait-for-debugger: Pause and wait for keypress after server startup to allow attaching a debugger to the server process.
    --restart-timeout: If the server has gone away, do not fail immediately, but wait to see if it restarts (it might be a part of the test)
    --[no]metadata-reload : Re-load metadata periodically during the test flow. On by default, to turn off, run with --nometadata
    --compatibility  : Server version which syntax should be compatible with, in the form of x.y.z (e.g. 10.3.22) or NNNNNN (100322).
                       It is not guaranteed that all resulting queries will comply with the requirement, only those which come
                       from the generation mechanisms aware of the option.
    --help      : This help message

    If you specify --basedir1 and --basedir2 or --vardir1 and --vardir2, two servers will be started and the results from the queries
    will be compared between them.
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
