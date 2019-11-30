#!/usr/bin/perl

# Copyright (c) 2010, 2012, Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2019, MariaDB Corporation Ab.
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

#################### FOR THE MOMENT THIS SCRIPT IS FOR TESTING PURPOSES


unless (defined $ENV{RQG_HOME}) {
  use File::Basename qw(dirname);
  use Cwd qw(abs_path);
  $ENV{RQG_HOME}= abs_path(dirname($0));
}

use Getopt::Long qw( :config pass_through );

use lib 'lib';
use lib "$ENV{RQG_HOME}/lib";
use Carp;
use strict;
use GenTest;
use GenTest::BzrInfo;
use GenTest::Constants;
use GenTest::Properties;
use GenTest::App::GenTest;
use GenTest::App::GenConfig;
use DBServer::DBServer;
use DBServer::MySQL::MySQLd;
use DBServer::MySQL::ReplMySQLd;
use DBServer::MySQL::GaleraMySQLd;

$| = 1;
my $logger;
eval
{
    require Log::Log4perl;
    Log::Log4perl->import();
    $logger = Log::Log4perl->get_logger('randgen.gentest');
};

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

use Getopt::Long;
use GenTest::Constants;
use DBI;
use Cwd;

my $database = 'test';
my $user = 'rqg';
my @dsns;

my ($help, $debug,
    $mem,
    @valgrind_options,
    $no_mask,
    $wait_debugger,
    $skip_gendata, $skip_shutdown, $use_gtid,
    $scenario, $store_binaries, $props);

my $default_threads= 10;
my $default_queries= 100000000;
my $default_duration= 600;

my @ARGV_saved = @ARGV;

my $opt_result = GetOptions(
    'annotate_rules|annotate-rules' => \$props->{annotate_rules},
    'basedir=s' => \${$props->{basedir}}[0],
    'basedir1=s' => \${$props->{basedir}}[1],
    'basedir2=s' => \${$props->{basedir}}[2],
    'basedir3=s' => \${$props->{basedir}}[3],
    'debug' => \$debug,
    'debug-server' => \${$props->{debug_server}}[0],
    'debug-server1' => \${$props->{debug_server}}[1],
    'debug-server2' => \${$props->{debug_server}}[2],
    'debug-server3' => \${$props->{debug_server}}[3],
    'default-database|default_database=s' => \$database,
    'duration=i' => \$props->{duration},
    'engine=s' => \${$props->{engine}}[0],
    'engine1=s' => \${$props->{engine}}[1],
    'engine2=s' => \${$props->{engine}}[2],
    'engine3=s' => \${$props->{engine}}[3],
    'filter=s'    => \$props->{filter},
    'freeze_time' => \$props->{freeze_time},
    'galera=s' => \$props->{galera},
    'genconfig:s' => \$props->{genconfig},
    'gendata:s@' => \$props->{gendata},
    'gendata_advanced|gendata-advanced' => \$props->{gendata_advanced},
    'grammar=s' => \$props->{grammar},
    'help' => \$help,
    'logconf=s' => \$props->{logconf},
    'logfile=s' => \$props->{logfile},
    'mask=i' => \$props->{mask},
    'mask-level|mask_level=i' => \$props->{mask_level},
    'mem' => \$mem,
    'metadata!' => \$props->{metadata},
    'mtr-build-thread=i' => \$props->{build_thread},
    'mysqld=s@' => \${$props->{mysqld_options}}[0],
    'mysqld1=s@' => \${$props->{mysqld_options}}[1],
    'mysqld2=s@' => \${$props->{mysqld_options}}[2],
    'mysqld3=s@' => \${$props->{mysqld_options}}[3],
    'no_mask|no-mask' => \$no_mask,
    'notnull' => \$props->{notnull},
    'partitions'   => \${$props->{partitions}}[0],
    'partitions1'  => \${$props->{partitions}}[1],
    'partitions2'  => \${$props->{partitions}}[2],
    'partitions3'  => \${$props->{partitions}}[3],
    'ps_protocol|ps-protocol' => \$props->{ps_protocol},
    'queries=s' => \$props->{queries},
    'querytimeout=i' => \$props->{querytimeout},
    'redefine=s@' => \@{$props->{redefine}},
    'report-tt-logdir=s' => \$props->{report_tt_logdir},
    'report-xml-tt'    => \$props->{report_xml_tt},
    'report-xml-tt-dest=s' => \$props->{report_xml_tt_dest},
    'report-xml-tt-type=s' => \$props->{report_xml_tt_type},
    'reporters=s@' => \@{$props->{reporters}},
    'restart_timeout|restart-timeout=i' => \$props->{restart_timeout},
    'rows=s' => \$props->{rows},
    'rpl_mode|rpl-mode=s' => \$props->{rpl_mode},
    'scenario:s' => \$scenario,
    'seed=s' => \$props->{seed},
    'short_column_names|short-column-names' => \$props->{short_column_names},
    'skip_recursive_rules|skip-recursive-rules' > \$props->{skip_recursive_rules},
    'skip_gendata|skip-gendata' => \$skip_gendata,
    'skip_shutdown|skip-shutdown' => \$skip_shutdown,
    'sqltrace:s' => \$props->{sqltrace},
    'start_dirty|start-dirty'    => \$props->{start_dirty},
    'store-binaries|store_binaries' => \$store_binaries,
    'strict_fields|strict-fields' => \$props->{strict_fields},
    'testname=s'        => \$props->{testname},
    'threads=i' => \$props->{threads},
    'transformers=s@' => \@{$props->{transformers}},
    'use_gtid|use-gtid=s' => \$use_gtid,
    'valgrind!'    => \$props->{valgrind},
    'valgrind_options=s@'    => \@valgrind_options,
    'validators=s@' => \@{$props->{validators}},
    'vardir=s' => \${$props->{vardir}}[0],
    'vardir1=s' => \${$props->{vardir}}[1],
    'vardir2=s' => \${$props->{vardir}}[2],
    'vardir3=s' => \${$props->{vardir}}[3],
    'varchar_length|varchar-length=i' => \$props->{varchar_len},
    'vcols:s'        => \${$props->{vcols}}[0],
    'vcols1:s'        => \${$props->{vcols}}[1],
    'vcols2:s'        => \${$props->{vcols}}[2],
    'vcols3:s'        => \${$props->{vcols}}[3],
    'views:s'        => \${$props->{views}}[0],
    'views1:s'        => \${$props->{views}}[1],
    'views2:s'        => \${$props->{views}}[2],
    'views3:s'        => \${$props->{views}}[3],
    'wait-for-debugger' => \$wait_debugger,
    'xml-output=s'    => \$props->{xml_output},
);

if (!$opt_result) {
    print STDERR "\nERROR: Error occured while reading options\n\n";
    help();
    exit 1;
}

if ( osWindows() && !$debug )
{
    require Win32::API;
    my $errfunc = Win32::API->new('kernel32', 'SetErrorMode', 'I', 'I');
    my $initial_mode = $errfunc->Call(2);
    $errfunc->Call($initial_mode | 2);
};

if (defined $props->{logfile} && defined $logger) {
    setLoggingToFile($props->{logfile});
} else {
    if (defined $props->{logconf} && defined $logger) {
        setLogConf($props->{logconf});
    }
}


if ($help) {
    help();
    exit 0;
}

if (${$props->{basedir}}[0] eq '' and ${$props->{basedir}}[1] eq '') {
    print STDERR "\nERROR: Basedir is not defined\n\n";
    help();
    exit 1;
}

# Originally it was done in Gendata, but we want the same seed for all components

if (defined $props->{seed} and $props->{seed} eq 'time') {
    $props->{seed} = time();
    say("Converted --seed=time to --seed=$props->{seed}");
}
elsif (not defined $props->{seed}) {
    $props->{seed} = time();
    say("Seed was not set, using 'time': --seed=$props->{seed}");
}

if (not defined $scenario and not defined $props->{grammar}) {
    print STDERR "\nERROR: Grammar file is not defined\n\n";
    help();
    exit 1;
}

if (defined $props->{sqltrace}) {
    # --sqltrace may have a string value (optional). 
    # Allowed values for --sqltrace:
    my %sqltrace_legal_values = (
        'MarkErrors'    => 1  # Prefixes invalid SQL statements for easier post-processing
    );
    
    if (length($props->{sqltrace}) > 0) {
        # A value is given, check if it is legal.
        if (not exists $sqltrace_legal_values{$props->{sqltrace}}) {
            say("Invalid value for --sqltrace option: '$props->{sqltrace}'");
            say("Valid values are: ".join(', ', keys(%sqltrace_legal_values)));
            say("No value means that default/plain sqltrace will be used.");
            exit(STATUS_ENVIRONMENT_FAILURE);
        }
    } else {
        # If no value is given, GetOpt will assign the value '' (empty string).
        # We interpret this as plain tracing (no marking of errors, prefixing etc.).
        # Better to use 1 instead of empty string for comparisons later.
        $props->{sqltrace} = 1;
    }
}

say("Copyright (c) 2010,2011 Oracle and/or its affiliates. All rights reserved. Use is subject to license terms.");
say("Please see http://forge.mysql.com/wiki/Category:RandomQueryGenerator for more information on this test framework.");
say("Starting \n# $0 \\ \n# ".join(" \\ \n# ", @ARGV_saved));

#
# Calculate master and slave ports based on MTR_BUILD_THREAD (MTR
# Version 1 behaviour)
#

if (not defined $props->{build_thread}) {
    if (defined $ENV{MTR_BUILD_THREAD}) {
        $props->{build_thread} = $ENV{MTR_BUILD_THREAD}
    } else {
        $props->{build_thread} = DEFAULT_MTR_BUILD_THREAD;
    }
}

if ( $props->{build_thread} eq 'auto' ) {
    say ("Please set the environment variable MTR_BUILD_THREAD to a value <> 'auto' (recommended) or unset it (will take the value ".DEFAULT_MTR_BUILD_THREAD.") ");
    exit (STATUS_ENVIRONMENT_FAILURE);
}

@{$props->{port}} = (10000 + 10 * $props->{build_thread}, 10000 + 10 * $props->{build_thread}, 10000 + 10 * $props->{build_thread} + 2, 10000 + 10 * $props->{build_thread} + 4);

say("Ports : @{$props->{port}} MTR_BUILD_THREAD : $props->{build_thread} ");

# Different servers can be defined either by providing separate basedirs (basedir1, basedir2[, basedir3]),
# or by providing separate vardirs (vardir1, vardir2[, vardir3]).
# Now it's time to clean it all up and define for sure how many servers we need to run, and with options 

if (${$props->{basedir}}[1] eq '' and ${$props->{basedir}}[0] ne '') {
    # We need at least one server anyway
    ${$props->{basedir}}[1] = ${$props->{basedir}}[0];
}
if (${$props->{vardir}}[1] eq '' and ${$props->{vardir}}[0] ne '') {
    ${$props->{vardir}}[1] = ${$props->{vardir}}[0];
}

foreach (2..3) {
    # If servers 2 and 3 are defined through vardirs, use the default basedir for them
    if (${$props->{vardir}}[$_] ne '' and ${$props->{basedir}}[$_] eq '') {
        ${$props->{basedir}}[$_] = ${$props->{basedir}}[0];
    }
}

# Now we should have all basedirs.
# Check that there is no overlap in vardirs (when the user defines for two different servers the same basedir,
# but does not define separate vardirs)

foreach my $i (1..3) {
    next unless ${$props->{basedir}}[$i] or ${$props->{vardir}}[$i];
    foreach my $j ($i+1..3) {
        next unless ${$props->{basedir}}[$j] or ${$props->{vardir}}[$j];
        if (${$props->{basedir}}[$i] eq ${$props->{basedir}}[$j] and ${$props->{vardir}}[$i] eq ${$props->{vardir}}[$j]) {
            croak("Please specify either different --basedir[$i]/--basedir[$j] or different --vardir[$i]/--vardir[$j] in order to start two MySQL servers");
        }
    }
}

# Make sure that "default" values ([0]) are also set, for compatibility,
# in case they are used somewhere
${$props->{basedir}}[0] ||= ${$props->{basedir}}[1];
${$props->{vardir}}[0] ||= ${$props->{vardir}}[1];

# Now sort out other options that can be set differently for different servers:
# - mysqld_options
# - debug_server
# - views
# - engine
# values[0] are those that are applied to all servers.
# values[N] expand or override values[0] for the server N

@{${$props->{mysqld_options}}[0]} = () if not defined ${$props->{mysqld_options}}[0];
# push @{${$props->{mysqld_options}}[0]}, "--sql-mode=no_engine_substitution" if join(' ', @ARGV_saved) !~ m{sql[-_]mode}io;

foreach my $i (1..3) {
    @{${$props->{mysqld_options}}[$i]} = ( defined ${$props->{mysqld_options}}[$i] 
            ? ( @{${$props->{mysqld_options}}[0]}, @{${$props->{mysqld_options}}[$i]} )
            : @{${$props->{mysqld_options}}[0]}
    );
    ${$props->{debug_server}}[$i] = ${$props->{debug_server}}[0] if ${$props->{debug_server}}[$i] eq '';
    ${$props->{vcols}}[$i] = ${$props->{vcols}}[0] if ${$props->{vcols}}[$i] eq '';
    ${$props->{views}}[$i] = ${$props->{views}}[0] if ${$props->{views}}[$i] eq '';
    ${$props->{engine}}[$i] ||= ${$props->{engine}}[0];
    ${$props->{partitions}}[$i] = ${$props->{partitions}}[0] if ${$props->{partitions}}[$i] eq '';
}

shift @{$props->{debug_server}};
shift @{$props->{vcols}};
shift @{$props->{views}};
shift @{$props->{engine}};
shift @{$props->{partitions}};

my $client_basedir;

foreach my $path ("${$props->{basedir}}[0]/client/RelWithDebInfo", "${$props->{basedir}}[0]/client/Debug", "${$props->{basedir}}[0]/client", "${$props->{basedir}}[0]/bin") {
    if (-e $path) {
        $client_basedir = $path;
        last;
    }
}

my $cnf_array_ref;

if ($props->{genconfig}) {
    unless (-e $props->{genconfig}) {
        croak("ERROR: Specified config template $props->{genconfig} does not exist");
    }
    $cnf_array_ref = GenTest::App::GenConfig->new(spec_file => $props->{genconfig},
                                               seed => $props->{seed},
                                               debug => $debug
    );
}

## For backward compatability
if ($#{$props->{validators}} == 0 and ${$props->{validators}}[0] =~ m/,/) {
    @{$props->{validators}} = split(/,/,${$props->{validators}}[0]);
}

## For backward compatability
my @reps= ();
foreach my $r (@{$props->{reporters}}) {
  push @reps, split /,/, $r;
}
@{$props->{reporters}}= @reps;

## For backward compatability
if ($#{$props->{transformers}} == 0 and ${$props->{transformers}}[0] =~ m/,/) {
    @{$props->{transformers}} = split(/,/,${$props->{transformers}}[0]);
}

## For uniformity
if ($#{$props->{redefine}} == 0 and ${$props->{redefine}}[0] =~ m/,/) {
    @{$props->{redefine}} = split(/,/,${$props->{redefine}}[0]);
}

# Some more adjustments

$props->{debug}= $debug;
$props->{dsns}= \@dsns;
$props->{duration}= $default_duration unless defined $props->{duration};
$props->{gendata}= '' unless exists $props->{gendata} and defined $props->{gendata} and scalar @{$props->{gendata}};
$props->{queries}= $default_queries unless defined $props->{queries};
$props->{threads}= $default_threads unless defined $props->{threads};

delete $props->{gendata} if $skip_gendata;
delete $props->{mask} if $no_mask;

# Push the number of "worker" threads into the environment.
# lib/GenTest/Generator/FromGrammar.pm will generate a corresponding grammar element.
$ENV{RQG_THREADS}= $props->{threads};


my $cmd = $0 . " " . join(" ", @ARGV_saved);
if ($cmd =~ /--seed=/) {
  $cmd =~ s/seed=time/seed=$props->{seed}/g
} else {
  $cmd.= " --seed=$props->{seed}";
}
say("Final command line: \nperl $cmd");

if (defined $scenario) {
  # Scenario mode.

  # Different scenarios can expect different options. Besides,
  # some options can be defined per server, and different scenarios can
  # define them differently. So, here we just want to store all of them
  # and pass over to the scenario. Since we don't know how many servers
  # the given scenario runs, it's impossible to put it all in GetOptions,
  # thus we will parse them manually

  foreach my $o (@ARGV) {
    if ($o =~ /^--(?:loose[-_])?mysqld=(\S+)$/) {
      if (not defined $props->{mysqld}) {
        @{$props->{mysqld}}= ();
      }
      push @{$props->{mysqld}}, $1;
    }
    elsif ($o =~ /^--(?:loose[-_])?(mysqld\d+)=(\S+)$/) {
      if (not defined $props->{$1}) {
        @{$props->{$1}}= ();
      }
      push @{$props->{$1}}, $2;
    }
    elsif ($o =~ /^--([-_\w]+)=(\S+)$/) {
      my $opt=$1;
      $opt =~ s/_/-/g;
      $props->{$opt}= $2;
    }
    elsif ($o =~ /^--skip-([-_\w]+)$/) {
      my $opt=$1;
      $opt =~ s/_/-/g;
      $props->{$opt}= 0;
    }
    elsif ($o =~ /^--([-_\w]+)$/) {
      my $opt=$1;
      $opt =~ s/_/-/g;
      $props->{$opt}= 1;
    }
  }

  my $cp= my $class= "GenTest::Scenario::$scenario";
  $cp =~ s/::/\//g;
  require "$cp.pm";
  my $sc= $class->new(
      properties => $props
  );

  my $status= $sc->run();
  say("[$$] $0 will exit with exit status ".status2text($status). " ($status)\n");
  safe_exit($status);
}

# Without scenario mode, be strict about GetOpts -- return error
# if there were unknown options on the command line

if (scalar @ARGV) {
  print STDERR "\nERROR: Unknown options: @ARGV\n\n";
  exit 1;
}

#
# Start servers. Use rpl_alter if replication is needed.
#

my $rplsrv;

if ($props->{rpl_mode} ne '') {

    $rplsrv = DBServer::MySQL::ReplMySQLd->new(master_basedir => ${$props->{basedir}}[1],
                                               slave_basedir => ${$props->{basedir}}[2],
                                               master_vardir => ${$props->{vardir}}[1],
                                               debug_server => ${$props->{debug_server}}[1],
                                               master_port => ${$props->{port}}[1],
                                               slave_vardir => ${$props->{vardir}}[2],
                                               slave_port => ${$props->{port}}[2],
                                               mode => $props->{rpl_mode},
                                               server_options => ${$props->{mysqld_options}}[1],
                                               valgrind => $props->{valgrind},
                                               valgrind_options => \@valgrind_options,
                                               general_log => 1,
                                               start_dirty => $props->{start_dirty},
                                               use_gtid => $use_gtid,
                                               config => $cnf_array_ref,
                                               user => $user
    );
    
    my $status = $rplsrv->startServer();
    
    if ($status > DBSTATUS_OK) {
        stopServers($status);
        if (osWindows()) {
            say(system("dir ".unix2winPath($rplsrv->master->datadir)));
            say(system("dir ".unix2winPath($rplsrv->slave->datadir)));
        } else {
            say(system("ls -l ".$rplsrv->master->datadir));
            say(system("ls -l ".$rplsrv->slave->datadir));
        }
        croak("Could not start replicating server pair");
    }
    
    $dsns[0] = $rplsrv->master->dsn($database,$user);
    $dsns[1] = undef; ## passed to gentest. No dsn for slave!
    ${$props->{server}}[0] = $rplsrv->master;
    ${$props->{server}}[1] = $rplsrv->slave;

} elsif ($props->{galera} ne '') {

    if (osWindows()) {
        croak("Galera is not supported on Windows (yet)");
    }

    unless ($props->{galera} =~ /^[ms]+$/i) {
        croak ("--galera option should contain a combination of M and S, indicating masters and slaves");
    }

    $rplsrv = DBServer::MySQL::GaleraMySQLd->new(
        basedir => ${$props->{basedir}}[0],
        parent_vardir => ${$props->{vardir}}[0],
        debug_server => ${$props->{debug_server}}[1],
        first_port => ${$props->{port}}[1],
        server_options => ${$props->{mysqld_options}}[1],
        valgrind => $props->{valgrind},
        valgrind_options => \@valgrind_options,
        general_log => 1,
        start_dirty => $props->{start_dirty},
        node_count => length($props->{galera})
    );
    
    my $status = $rplsrv->startServer();
    
    if ($status > DBSTATUS_OK) {
        stopServers($status);

        sayError("Could not start Galera cluster");
        exit_test(STATUS_ENVIRONMENT_FAILURE);
    }

    my $galera_topology = $props->{galera};
    my $i = 0;
    while ($galera_topology =~ s/^(\w)//) {
        if (lc($1) eq 'm') {
            $dsns[$i] = $rplsrv->nodes->[$i]->dsn($database,$user);
        }
        ${$props->{server}}[$i] = $rplsrv->nodes->[$i];
        $i++;
    }

} else {

    foreach my $server_id (1..3) {
        next unless ${$props->{basedir}}[$server_id];
        
        ${$props->{server}}[$server_id] = DBServer::MySQL::MySQLd->new(basedir => ${$props->{basedir}}[$server_id],
                                                           vardir => ${$props->{vardir}}[$server_id],
                                                           debug_server => ${$props->{debug_server}}[$server_id],
                                                           port => ${$props->{port}}[$server_id],
                                                           start_dirty => $props->{start_dirty},
                                                           valgrind => $props->{valgrind},
                                                           valgrind_options => \@valgrind_options,
                                                           server_options => ${$props->{mysqld_options}}[$server_id],
                                                           general_log => 1,
                                                           config => $cnf_array_ref,
                                                           user => $user);
        
        my $status = ${$props->{server}}[$server_id]->startServer;
        
        if ($status > DBSTATUS_OK) {
            stopServers($status);
            if (osWindows()) {
                say(system("dir ".unix2winPath(${$props->{server}}[$server_id]->datadir)));
            } else {
                say(system("ls -l ".${$props->{server}}[$server_id]->datadir));
            }
            sayError("Could not start all servers");
            exit_test(STATUS_CRITICAL_FAILURE);
        }
        
        if ( ($server_id == 0) || ($props->{rpl_mode} eq '') ) {
            $dsns[$server_id] = ${$props->{server}}[$server_id]->dsn($database,$user);
        }

        # For backward compatibility, check that no multiple engines were requested
        # before setting the default one
        unless (${$props->{engine}}[$server_id] =~ /,/)
        {
          if ((defined $dsns[$server_id]) && (defined ${$props->{engine}}[$server_id])) {
              my $dbh = DBI->connect($dsns[$server_id], undef, undef, { mysql_multi_statements => 1, RaiseError => 1 } );
              $dbh->do("SET GLOBAL default_storage_engine = '${$props->{engine}}[$server_id]'");
          }
        }
    }
}


#
# Wait for user interaction before continuing, allowing the user to attach 
# a debugger to the server process(es).
# Will print a message and ask the user to press a key to continue.
# User is responsible for actually attaching the debugger if so desired.
#
if ($wait_debugger) {
    say("Pausing test to allow attaching debuggers etc. to the server process.");
    my @pids;   # there may be more than one server process
    foreach my $server_id (0..$#{$props->{server}}) {
        $pids[$server_id] = ${$props->{server}}[$server_id]->serverpid;
    }
    say('Number of servers started: '.scalar(@{$props->{server}}));
    say('Server PID: '.join(', ', @pids));
    say("Press ENTER to continue the test run...");
    my $keypress = <STDIN>;
}

my $gentestProps = GenTest::Properties->init($props);
my $gentest = GenTest::App::GenTest->new(config => $gentestProps);
my $gentest_result = $gentest->run();
say("GenTest exited with exit status ".status2text($gentest_result)." ($gentest_result)");

# If Gentest produced any failure then exit with its failure code,
# otherwise if the test is replication/with two servers compare the 
# server dumps for any differences else if there are no failures exit with success.

if (($gentest_result == STATUS_OK) && ( ($props->{rpl_mode} && $props->{rpl_mode} !~ /nosync/) || (defined ${$props->{basedir}}[2]) || (defined ${$props->{basedir}}[3]) || $props->{galera}))
{
#
# Compare master and slave, or all masters
#
    my $diff_result = STATUS_OK;
    if ($props->{rpl_mode} ne '') {
        $diff_result = $rplsrv->waitForSlaveSync;
        if ($diff_result != STATUS_OK) {
            exit_test(STATUS_INTERNAL_ERROR);
        }
    }
  
    my @dump_files;
  
    foreach my $i (1..$#{$props->{server}}) {
        $dump_files[$i] = tmpdir()."server_".abs($$)."_".$i.".dump";
      
        my $dump_result = ${$props->{server}}[$i]->dumpdb($database,$dump_files[$i]);
        exit_test($dump_result >> 8) if $dump_result > 0;
    }
  
    say("Comparing SQL dumps...");
    
    foreach my $i (2..$#{$props->{server}}) {
        my $diff = system("diff -u $dump_files[$i-1] $dump_files[$i]");
        if ($diff == STATUS_OK) {
            say("No differences were found between servers ".($i-1)." and $i.");
        } else {
            sayError("Found differences between servers ".($i-1)." and $i.");
            $diff_result = STATUS_CONTENT_MISMATCH;
        }
    }

    foreach my $dump_file (@dump_files) {
        unlink($dump_file);
    }
    exit_test($diff_result);
} else {
    # If test was not sucessfull or not rpl/multiple servers.
    
    if ($gentest_result != STATUS_OK and $store_binaries) {
      foreach my $i ($#{$props->{server}}) {
        my $file= ${$props->{server}}[$i]->binary;
        my $to= ${$props->{vardir}}[$i];
        if (osWindows()) {
          system("xcopy \"$file\" \"".$to."\"") if -e $file and $to;
          $file =~ s/\.exe/\.pdb/;
          system("xcopy \"$file\" \"".$to."\"") if -e $file and $to;
        }
        else {
          system("cp $file ".$to) if -e $file and $to;
        }
      }
    }
    exit_test($gentest_result);
}

sub stopServers {
    my $status = shift;
    if ($skip_shutdown) {
        say("Server shutdown is skipped upon request");
        return;
    }
    say("Stopping server(s)...");
    if ($props->{rpl_mode} ne '') {
        $rplsrv->stopServer($status);
    } else {
        foreach my $srv (@{$props->{server}}) {
            if ($srv) {
                $srv->stopServer;
            }
        }
    }
}


sub help {
    
    print <<EOF
Copyright (c) 2010,2011 Oracle and/or its affiliates. All rights reserved. Use is subject to license terms.

$0 - Run a complete random query generation test, including server start with replication and master/slave verification
    
    Options related to one standalone MySQL server:

    --basedir   : Specifies the base directory of the stand-alone MySQL installation;
    --mysqld    : Options passed to the MySQL server
    --vardir    : Optional. (default \$basedir/mysql-test/var);
    --debug-server: Use mysqld-debug server

    Options related to two MySQL servers

    --basedir1  : Specifies the base directory of the first MySQL installation;
    --basedir2  : Specifies the base directory of the second MySQL installation;
    --mysqld    : Options passed to both MySQL servers
    --mysqld1   : Options passed to the first MySQL server
    --mysqld2   : Options passed to the second MySQL server
    --debug-server1: Use mysqld-debug server for MySQL server1
    --debug-server2: Use mysqld-debug server for MySQL server2
    --vardir1   : Optional. (default \$basedir1/mysql-test/var);
    --vardir2   : Optional. (default \$basedir2/mysql-test/var);

    General options

    --grammar   : Grammar file to use when generating queries (REQUIRED);
    --redefine  : Grammar file(s) to redefine and/or add rules to the given grammar
    --rpl_mode  : Replication type to use (statement|row|mixed) (default: no replication).
                  The mode can contain modifier 'nosync', e.g. row-nosync. It means that at the end the test
                  will not wait for the slave to catch up with master and perform the consistency check
    --use_gtid  : Use GTID mode for replication (current_pos|slave_pos|no). Adds the MASTER_USE_GTID clause to CHANGE MASTER,
                  (default: empty, no additional clause in CHANGE MASTER command);
    --galera    : Galera topology, presented as a string of 'm' or 's' (master or slave).
                  The test flow will be executed on each "master". "Slaves" will only be updated through Galera replication
    --engine    : Table engine to use when creating tables with gendata (default no ENGINE in CREATE TABLE);
                  Different values can be provided to servers through --engine1 | --engine2 | --engine3
    --threads   : Number of threads to spawn (default $default_threads);
    --queries   : Number of queries to execute per thread (default $default_queries);
    --duration  : Duration of the test in seconds (default $default_duration seconds);
    --validator : The validators to use
    --reporter  : The reporters to use
    --transformer: The transformers to use (turns on --validator=transformer). Accepts comma separated list
    --querytimeout: The timeout to use for the QueryTimeout reporter 
    --gendata   : Generate data option. Passed to gentest.pl / GenTest. Takes a data template (.zz file)
                  as an optional argument. Without an argument, indicates the use of GendataSimple (default)
    --gendata-advanced: Generate the data using GendataAdvanced instead of default GendataSimple
    --logfile   : Generates rqg output log at the path specified.(Requires the module Log4Perl)
    --seed      : PRNG seed. Passed to gentest.pl
    --mask      : Grammar mask. Passed to gentest.pl
    --mask-level: Grammar mask level. Passed to gentest.pl
    --notnull   : Generate all fields with NOT NULL
    --rows      : No of rows. Passed to gentest.pl
    --sqltrace  : Print all generated SQL statements. 
                  Optional: Specify --sqltrace=MarkErrors to mark invalid statements.
    --varchar-length: length of strings. passed to gentest.pl
    --xml-outputs: Passed to gentest.pl
    --vcols     : Types of virtual columns (only used if data is generated by GendataSimple or GendataAdvanced)
    --views     : Generate views. Optionally specify view type (algorithm) as option value. Passed to gentest.pl.
                  Different values can be provided to servers through --views1 | --views2 | --views3
    --valgrind  : Passed to gentest.pl
    --filter    : Passed to gentest.pl
    --mem       : Passed to mtr
    --mtr-build-thread:  Value used for MTR_BUILD_THREAD when servers are started and accessed
    --debug     : Debug mode
    --short_column_names: use short column names in gendata (c<number>)
    --strict_fields: Disable all AI applied to columns defined in \$fields in the gendata file. Allows for very specific column definitions
    --freeze_time: Freeze time for each query so that CURRENT_TIMESTAMP gives the same result for all transformers/validators
    --annotate-rules: Add to the resulting query a comment with the rule name before expanding each rule. 
                      Useful for debugging query generation, otherwise makes the query look ugly and barely readable.
    --wait-for-debugger: Pause and wait for keypress after server startup to allow attaching a debugger to the server process.
    --restart-timeout: If the server has gone away, do not fail immediately, but wait to see if it restarts (it might be a part of the test)
    --[no]metadata   : Load metadata after data generation before the test flow. On by default, to turn off, run with --nometadata
    --help      : This help message

    If you specify --basedir1 and --basedir2 or --vardir1 and --vardir2, two servers will be started and the results from the queries
    will be compared between them.
EOF
    ;
    print "$0 arguments were: ".join(' ', @ARGV_saved)."\n";
    exit_test(STATUS_UNKNOWN_ERROR);
}

sub exit_test {
    my $status = shift;
    stopServers($status);
    say("[$$] $0 will exit with exit status ".status2text($status). " ($status)");
    safe_exit($status);
}
