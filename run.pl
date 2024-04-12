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

# $0 doesn't work for us as it can be called from combinations.pl
use constant SCRIPT_NAME => 'run.pl';

sub run {
  @ARGV= @_;
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
  use File::Copy;
  use Getopt::Long qw( :config pass_through );
  use POSIX;
  use strict;
  use GenUtil;
  use Constants;
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
  use Constants;
  use DBI;
  use Cwd;

  my ($help,
      $props, %scenario_options, %server_options,
      $scenario, $genconfig, $build_thread,
      @exit_status, $trials, $output, $force,
      $minio, $hashicorp,
     );

  $SIG{INT}= \&group_cleaner;

  # Defaults
  $props->{user}= 'rqg';
  $props->{threads}= 4;
  $props->{queries}= 100000000;
  $props->{duration}= 300;
  $props->{seed}= 'time';
  $props->{metadata_reload}= 1;
  $props->{base_port}= RQG_DEFAULT_BASE_PORT;
  $props->{compatibility}= '999999';

  $trials= 1;
  $scenario= RQG_DEFAULT_SCENARIO;

  my @ARGV_saved = @ARGV;

  %server_options= (
    basedir     => undef,
    engines     => undef,
    gis         => undef,
    manual_gdb  => undef,
    mysqld      => undef,
    partitions  => undef,
    perf        => undef,
    ps          => undef,
    rr          => undef,
    uhashkeys   => undef,
    valgrind    => undef,
    vcols       => undef,
    views       => undef,
  );

  my $opt_result = GetOptions(
    #
    # Server-related options
    'basedir=s' => \$server_options{basedir},
    'engines=s@' => \@{$server_options{engines}},
    'gis!'     => \$server_options{gis},
    'manual-gdb|manual_gdb' => \$server_options{manual_gdb},
    'mysqld=s@' => \@{$server_options{mysqld}},
    'partitions!'   => \$server_options{partitions},
    'perf!' => \$server_options{perf},
    'ps_protocol|ps-protocol' => \$server_options{ps},
    'rr!' => \$server_options{rr},
    'unique-hash-keys|unique_hash_keys!' => \$server_options{uhashkeys},
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
    'gendatas=s@' => \@{$props->{gendatas}},
    'grammars=s@' => \@{$props->{grammars}},
    'hashicorp|with-hashicorp|with_hashicorp|vault' => \$hashicorp,
    'help' => \$help,
    'metadata_reload|metadata-reload!' => \$props->{metadata_reload},
    'minio|with-minio|with_minio' => \$minio,
    'parser=s' => \$props->{parser},
    'parser-mode|parser_mode=s' => \$props->{parser_mode},
    'queries=s' => \$props->{queries},
    'redefines=s@' => \@{$props->{redefines}},
    'reporters=s@' => \@{$props->{reporters}},
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
    return help();
  }

  $ENV{RQG_DEBUG} = 1 if ($props->{debug});

  if ( osWindows() && !$props->{debug} )
  {
    require Win32::API;
    my $errfunc = Win32::API->new('kernel32', 'SetErrorMode', 'I', 'I');
    my $initial_mode = $errfunc->Call(2);
    $errfunc->Call($initial_mode | 2);
  };

  #-------------------
  # Mandatory options

  unless ($props->{vardir}) {
    return help("Vardir must be defined");
  }

  #-------------------
  # Multiple-value parameters may be given as comma-separated strings.
  # Convert to proper arrays and remove duplicates

  foreach my $p (qw(engines filters gendatas grammars redefines reporters transformers validators variators)) {
    my %vals= ();
    if (exists $props->{$p}) {
      foreach my $v (@{$props->{$p}}) {
        map { $vals{$_}=1 } (split ',', $v);
      }
      $props->{$p}= [ keys %vals ];
    } elsif (exists $server_options{$p}) {
      foreach my $v (@{$server_options{$p}}) {
        map { $vals{$_}=1 } (split ',', $v);
      }
      $server_options{$p}= [ keys %vals ];
    }
  }

  #-------------------

  if (-d $props->{vardir}) {
    remove_tree($props->{vardir});
  }
  mkpath($props->{vardir});
  # copy STDOUT to another filehandle
  open (my $STDOUTOLD, '>&', STDOUT);
  open (my $STDERROLD, '>&', STDERR);

  open (STDOUT, "| tee -ai ".$props->{vardir}."/trial.log");
  open STDERR, ">&STDOUT";

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

  # Configure Hashicorp vault if it's installed and running
  # (again, it seems an overkill to configure it here, since it will be rarely needed)
  if ($hashicorp) {
    if (system($ENV{RQG_HOME}.'/util/setup_hashicorp.sh '.$props->{vardir}.' > '.$props->{vardir}.'/vault.log 2>&1')) {
      sayWarning("Could not configure Hashicorp vault");
      $ENV{HASHICORP_DOABLE}= '';
    } else {
      $ENV{VAULT_TOKEN}= `cat $props->{vardir}/vault.token | head -n 1`;
      chomp $ENV{VAULT_TOKEN};
      $ENV{VAULT_ADDR}= `cat $props->{vardir}/vault.token | tail -n 1`;
      chomp $ENV{VAULT_ADDR};
      say("Hashicorp vault has been configured: $ENV{VAULT_ADDR} $ENV{VAULT_TOKEN}");
    }
  }

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
    if ($hashicorp && $ENV{VAULT_TOKEN} && $ENV{VAULT_ADDR}) {
      push @{$server_specific->{$s}{mysqld}}, "--hashicorp-key-management-vault-url=$ENV{VAULT_ADDR}/v1/mariadbtest", "--hashicorp-key-management-token=$ENV{VAULT_TOKEN}";
    }
  }

  unless ($server_specific->{1}{basedir}) {
    return help("At least one basedir must be defined");
  }

  $props->{server_specific}= $server_specific;

  if (scalar(@unknown_options)) {
    return help("Unknown options: @unknown_options");
  }

  $props->{queries} =~ s/K/000/so;
  $props->{queries} =~ s/M/000000/so;

  if ($props->{compatibility} =~ s/^es-//) {
    $props->{compatibility_es}= 1;
  }
  if ($props->{compatibility}=~ /([0-9]+)\.([0-9]+)\.([0-9]+)-([0-9]+)/) {
    $props->{compatibility}= sprintf("%02d%02d%02d",int($1),int($2),int($3));
    $props->{compatibility_es}= 1;
  } elsif ($props->{compatibility}=~ /([0-9]+)\.([0-9]+)(?:\.([0-9]+))?/) {
    $props->{compatibility}= sprintf("%02d%02d%02d",int($1),int($2),int($3||99));
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

  say("Starting \\ \n# ".join(" \\ \n# ", @ARGV_saved));

  if (defined $props->{sqltrace}) {
    # --sqltrace may have a string value (optional).
    # Allowed values for --sqltrace:
    my %sqltrace_legal_values = (
      'MarkErrors'    => 1  # Indicates invalid SQL statements for easier post-processing
    );

    if (length($props->{sqltrace}) > 0) {
      # A value is given, check if it is legal.
      if (not exists $sqltrace_legal_values{$props->{sqltrace}}) {
        return help("Invalid value for --sqltrace option: '$props->{sqltrace}'.\n".
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

  if ($genconfig) {
    unless (-e $genconfig) {
      return help("Specified config template $genconfig does not exist");
    }
  }

  # Push the number of "worker" threads into the environment.
  # lib/GenTest/Generator/FromGrammar.pm will generate a corresponding grammar element.
  $ENV{RQG_THREADS}= $props->{threads};

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
    my $cmd = SCRIPT_NAME . " " . join(" ", @ARGV_saved);
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

    if ($genconfig) {
      my $cnf_contents = GenTest::GenConfig->new(spec_file => $genconfig,
                                                 seed => $props->{seed},
                                                 debug => $props->{debug}
      );
      $props->{cnf}= $props->{vardir}.'/my.cnf';
      open(CONFIG,'>'.$props->{cnf}) || return help("Could not open file ".$props->{cnf}." for writing: $!");
      print CONFIG @$cnf_contents;
      close(CONFIG);
    }

    say("Final command line: \n$cmd");
    say("Test compatibility: ".$props->{compatibility});

    my $config = GenTest::Properties->init($props);
    my $sc= $class->new(properties => $config, scenario_options => \%scenario_options);
    unless (defined $sc) {
      $status= STATUS_ENVIRONMENT_FAILURE;
      last;
    }
    my $res= STATUS_PERL_FAILURE;
    my $run_pid= fork();
    if ($run_pid) {
      # Parent, waiting for the test run to end
      waitpid($run_pid,0);
      $res= ($? >> 8);
    } elsif (defined $run_pid) {
      # Test runner
      exit $sc->run()
    } else {
      sayError("Could not fork for test run: $!");
    }
    $status= $res if $res > $status;
    my $resname= status2text($res);
    group_cleaner();
    if ($trials > 1) {
      copy($props->{vardir}."/trial.log",$props_vardir_orig."/trial$trial_id.log");
    }
    if ($search_mode) {
      say("Trial $trial_id ended with exit status $resname ($res)");
      my $check_result= check_for_desired_result($resname,$props->{vardir}."/trial.log", $output);
      if ($check_result) {
        $trial_result= 1;
        last TRIALS unless $force;
      }
      remove_tree($props->{vardir}) unless ($check_result || $res != STATUS_OK);
    }
  }

  say("Test run ends with exit status ".status2text($status). " ($status)\n");
  if ($search_mode) {
    say("Test runs apparently ".($trial_result ? "achieved the expected outcome" : "failed to achieve the expected outcome"));
  }

  # restore STDOUT and STDERR
  open (STDOUT, '>&', $STDOUTOLD);
  open (STDERR, '>&', $STDERROLD);

  return $status;
}

###############################################

# NOTE: subroutine returns 1 if the goal was achieved, and 0 otherwise
sub check_for_desired_result
{
  my ($resname, $output_file, $output) = @_;
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
    foreach my $srvnum (keys %{$props->{server_specific}}) {
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
        next if /(?:run\.pl.*)? --output=/; # skip the startup command, it always matches;
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
    print "\n".SCRIPT_NAME.": ";
    print <<EOF
Run a complete random query generation test scenario

    Options related to the server(s):

    --basedir   : Specifies the base directory of a server
    --genconfig : Template for server config generation
    --mysqld    : Options passed to the server(s), in a format
                  --mysqld=--opt[=value], can be specified multiple times

    Options related to data generation:

    --engines            : Table engine(s) to use when creating tables
                           with gendata (default no ENGINE in CREATE TABLE).
                           Comma-separated list
    --gendatas           : 'simple', 'advanced', or a path to .zz template
                           or SQL file. Can be provided multiple times
    --gis                : Create GIS columns upon data generation
                           (only affects gendata=advanced).
    --partitions         : Create partitions upon data generation
                           (only affects gendata=advanced)
    --rows               : Number of rows to use for table data generation,
                           comma-separated
    --short-column-names : Use short column names in data generation
    --vcols              : Create virtual columns upon data generation
                           (only affects gendata=advanced and gendata=simple).
                           Takes optional VIRTUAL/STORED value (comma-separated)
    --views              : Create views upon data generation.
                           Takes optional algorithm value (comma-separated)

    Options related to the test flow:

    --base-port       : Start of the port range used for the servers
    --compatibility   : Server version which syntax should be compatible with,
                        in the form of x.y.z (e.g. 10.3.22) or NNNNNN (100322).
                        It is not guaranteed that all resulting queries will
                        comply with the requirement, only those which come
                        from the generation mechanisms aware of the option
    --duration        : Approximate duration of the test run in seconds.
                        Time for data generation is not included
    --filters         : Suppress queries which match given patterns.
                        Multiple filters can be provided
    --freeze_time     : Freeze time for each query so that CURRENT_TIMESTAMP
                        gives the same result for all transformers/validators
    --grammars        : Grammar file to use when generating queries
                        (can be used multiple times)
    --hashicorp       : Prepare Hashicorp vault for the test
    --help            : Print this help message and exit
    --metadata-reload : When set to ON (default), the test will be periodically
                        updating cached information about columns, tables etc.
                      : For tests which don't do any DDL it can be turned off
                        by --nometadata-reload, to avoid extra load
    --minio           : If MinIO server is running, prepare it for the test
    --parser          : Path to the server source code containing the parser
                        to be used for test flow generation
                        (mutually exclusive with --grammar)
    --parser-mode     : 'mariadb' or 'oracle'
    --ps-protocol     : Use connector's PS protocol for the test flow
    --queries         : Number of queries to execute per thread
    --redefines       : Grammar file(s) to redefine and/or add rules
                        to the given grammars
    --reporters       : Reporters to use (can be provided multiple times)
    --scenario        : Test scenario to execute
    --seed            : Initial seed for random generation
    --threads         : Number of threads for the test flow
    --transformers    : Transformers to use (turns on --validator=Transformer).
                        Can be provided multiple times
    --validators      : Validators to use. Can be provided multiple times
    --variators       : Variators to use. Can be provided multiple times
    --vardir          : Full path to the vardir (will be emptied)

    Options related to re-running and reproducing:

    exit-status : Exit status value(s) to look for in reproducing mode
    force       : Continue to full number of trials even when the desired
                  symptoms are encountered
    output      : Output to look for in reproducing mode
    trials      : Number of trials to run in reproducing mode

    Test and server debugging:

    --annotate-rules : Add to the resulting query a comment with the rule
                       name before expanding each rule.
                       Useful for debugging query generation, otherwise
                       makes the query look ugly and barely readable.
    --debug          : RQG debug mode (a lot of extra output)
    --manual-gdb     : Pause and wait for keypress after server startup
                       to allow attaching a debugger to the server process
    --perf           : Run the server under perf record
    --rr             : Run the server under rr record
    --sqltrace       : Print all generated SQL statements.
                       Optional: Specify --sqltrace=MarkErrors to mark
                       invalid statements
    --valgrind       : Run the server under valgrind
EOF
;
    print "\n";
    if (scalar(@_)) {
      foreach (@_) {
        print STDERR "ERROR: $_\n";
      }
      print "\n";
      return STATUS_ENVIRONMENT_FAILURE;
    }
    return 0;
}

# If there are any arguments, we assume the script was launched directly,
# otherwise run(...) subroutine is called from another script
if (scalar(@ARGV)) {
  my $status= run(@ARGV);
  safe_exit($status);
}

1;
