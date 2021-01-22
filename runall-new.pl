#!/usr/bin/perl

# Copyright (c) 2010, 2012, Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2019, 2020, MariaDB Corporation Ab.
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

my ($help,
    $props, $deprecated,
    $wait_debugger, $skip_shutdown, $store_binaries,
    $skip_gendata, # Legacy to be kept for now, too many configs assume gendata by default
    $scenario, %scenario_options);

$props->{user}= 'rqg';
$props->{database}= 'test';
$props->{threads}= 10;
$props->{queries}= 100000000;
$props->{duration}= 600;

my @ARGV_saved = @ARGV;

my $opt_result = GetOptions(
    'annotate_rules|annotate-rules' => \$props->{annotate_rules},
    'basedir=s' => \$props->{basedir},
    'basedir1=s' => \$props->{server_specific}->{1}->{basedir},
    'basedir2=s' => \$props->{server_specific}->{2}->{basedir},
    'basedir3=s' => \$props->{server_specific}->{3}->{basedir},
    'compatibility=s' => \$props->{compatibility},
    'debug' => \$props->{debug},
    # Compatibility option, not used
    'debug-server' => \$deprecated->{debug_server},
    'debug-server1' => \$deprecated->{debug_server},
    'debug-server2' => \$deprecated->{debug_server},
    'debug-server3' => \$deprecated->{debug_server},
    'default-database|default_database=s' => \$props->{database},
    'duration=i' => \$props->{duration},
    'engine=s' => \$props->{engine},
    'engine1=s' => \$props->{server_specific}->{1}->{engine},
    'engine2=s' => \$props->{server_specific}->{2}->{engine},
    'engine3=s' => \$props->{server_specific}->{3}->{engine},
    'filter=s@'    => \@{$props->{filters}},
    'freeze_time' => \$props->{freeze_time},
    'galera=s' => \$props->{galera},
    'genconfig:s' => \$props->{genconfig},
    'gendata:s@' => \@{$props->{gendata}},
    'gendata_advanced|gendata-advanced' => \$props->{gendata_advanced},
    'grammar=s' => \$props->{grammar},
    'help' => \$help,
    'logconf=s' => \$props->{logconf},
    'logfile=s' => \$props->{logfile},
    'mask=i' => \$props->{mask},
    'mask-level|mask_level=i' => \$props->{mask_level},
    # Compatibility option, not used
    'mem' => \$deprecated->{mem},
    'metadata!' => \$props->{metadata},
    'mtr-build-thread=i' => \$props->{build_thread},
    'mysqld=s@' => \@{$props->{mysqld_options}},
    'mysqld1=s@' => \@{$props->{server_specific}->{1}->{mysqld_options}},
    'mysqld2=s@' => \@{$props->{server_specific}->{2}->{mysqld_options}},
    'mysqld3=s@' => \@{$props->{server_specific}->{3}->{mysqld_options}},
    # Compatibility option, not used (no-mask is default unless mask was defined)
    'no_mask|no-mask' => \$deprecated->{no_mask},
    'notnull' => \$props->{notnull},
    'partitions'   => \$props->{partitions},
    'partitions1'  => \$props->{server_specific}->{1}->{partitions},
    'partitions2'  => \$props->{server_specific}->{2}->{partitions},
    'partitions3'  => \$props->{server_specific}->{3}->{partitions},
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
    'rr!' => \$props->{rr},
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
    'use_gtid|use-gtid=s' => \$props->{use_gtid},
    'valgrind!'    => \$props->{valgrind},
    'valgrind_options|valgrind-options=s@'    => \@{$props->{valgrind_options}},
    'validators=s@' => \@{$props->{validators}},
    'vardir=s' => \$props->{vardir},
    'vardir1=s' => \$props->{server_specific}->{1}->{vardir},
    'vardir2=s' => \$props->{server_specific}->{2}->{vardir},
    'vardir3=s' => \$props->{server_specific}->{3}->{vardir},
    'varchar_length|varchar-length=i' => \$props->{varchar_len},
    'vcols:s'        => \$props->{vcols},
    'vcols1:s'        => \$props->{server_specific}->{1}->{vcols},
    'vcols2:s'        => \$props->{server_specific}->{2}->{vcols},
    'vcols3:s'        => \$props->{server_specific}->{3}->{vcols},
    'views:s'        => \$props->{views},
    'views1:s'        => \$props->{server_specific}->{1}->{views},
    'views2:s'        => \$props->{server_specific}->{2}->{views},
    'views3:s'        => \$props->{server_specific}->{3}->{views},
    'wait-for-debugger' => \$wait_debugger,
    'xml-output=s'    => \$props->{xml_output},
);

# Given that we use pass_through, it would be some very unexpected error
if (!$opt_result) {
    print STDERR "\nERROR: Error occured while reading options: $!\n\n";
    help();
    exit 1;
}

my @unknown_options= ();
if (! $scenario and scalar(@ARGV)) {
  # Without scenario mode, be strict about GetOpts -- return error
  # if there were unknown options on the command line
  @unknown_options= @ARGV;
}
elsif ($scenario) {
    # In the scenario mode, let unknown --scenario-xx options pass through,
    # but fail upon any other ones
    foreach my $o (@ARGV) {
        if ($o =~ /^--scenario-([^=]+)(?:=(.*))?$/) {
            $scenario_options{$1}= $2;
        } else {
            push @unknown_options, $o;
        }
    }
}

if (scalar(@unknown_options)) {
  print STDERR "\nERROR: Unknown options: @unknown_options\n\n";
  exit 1;
}

if ( osWindows() && !$props->{debug} )
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

if (not defined $scenario and not defined $props->{grammar}) {
    print STDERR "\nERROR: Grammar file is not defined\n\n";
    help();
    exit 1;
}

say("Starting \n# $0 \\ \n# ".join(" \\ \n# ", @ARGV_saved));

# Originally it was done in Gendata, but we want the same seed for all components
if (defined $props->{seed} and $props->{seed} eq 'time') {
    $props->{seed} = time();
    say("Converted seed=time into $props->{seed}");
}
elsif (not defined $props->{seed}) {
    $props->{seed} = time();
    say("Seed is not defined, using $props->{seed}");
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

# Different servers can be defined by providing server-specific options.
# Now it's time to clean it all up and define how many servers
# we need to run, and with which options

if ($props->{rpl_mode}) {
    $props->{number_of_servers}= 2;
} elsif ($props->{galera}) {
    $props->{number_of_servers}= length($props->{galera});
} else {
    # If at least one of server-specific versions for the server 3 or 2
    # is defined, it means we need this server and all before it
    $props->{number_of_servers}= 1;
    NUMBEROFSERVERS:
    foreach my $n (3,2) {
        foreach (values %{$props->{server_specific}->{$n}}) {
            if (defined $_ and (ref $_ ne 'ARRAY' or scalar(@$_) > 0)) {
                $props->{number_of_servers}= $n;
                last NUMBEROFSERVERS;
            }
        }
    }
}

foreach my $s (1..$props->{number_of_servers}) {
    $props->{server_specific}->{$s}->{port}= 10000 + 10 * $props->{build_thread} + ($s - 1) * 2;
}

say("MTR_BUILD_THREAD : $props->{build_thread} Number of servers: $props->{number_of_servers}");

# Currently recognized server-specific options:
# basedir engine mysqld_options partitions vardir vcols views

# Vardir differs from others and will be handled separately first
# The logic is this:
# - if it's specified for each server, don't do anything
# - if only general 'vardir' is specified and number_of_servers == 1,
#   use it as is
# - if only general 'vardir' is specified and number_of_servers > 1,
#   use {vardir}N for each server
# - otherwise throw an error

my $vardir_ok= 1;
foreach my $i (1..$props->{number_of_servers}) {
    $props->{server_specific}->{$i}= {} unless defined $props->{server_specific}->{$i};
    unless ($props->{server_specific}->{$i}->{vardir}) {
        $vardir_ok= 0;
        last;
    }
}
unless ($vardir_ok) {
    if ($props->{vardir}) {
        if ($props->{number_of_servers} == 1 or defined $props->{rpl_mode}) {
            $props->{server_specific}->{1}->{vardir}= $props->{vardir};
        } else {
            foreach my $i (1..$props->{number_of_servers}) {
                $props->{server_specific}->{$i}->{vardir}= $props->{vardir}.$i;
            }
        }
    } else {
        print STDERR "\nERROR: Vardir isn't defined".($props->{number_of_servers} == 1 ? "!" : " for some of the servers!")."\n\n";
        help();
        exit 1;
    }
}

# mysqld_options are also slightly different, as the server-specific set
# doesn't completely override the common one, but is applied on top of it

foreach my $i (1..$props->{number_of_servers}) {
  @{$props->{server_specific}->{$i}->{mysqld_options}}= (
    defined $props->{server_specific}->{$i}->{mysqld_options}
    ? (@{$props->{mysqld_options}},@{$props->{server_specific}->{$i}->{mysqld_options}})
    : @{$props->{mysqld_options}}
  );
};

# Clean up other options to make sure everything is specified for every server,

foreach my $o (qw(basedir engine partitions vcols views)) {
    foreach my $i (1..$props->{number_of_servers}) {
      $props->{server_specific}->{$i}->{$o} ||= $props->{$o};
    };
    $props->{$o}= $props->{server_specific}->{1}->{$o} unless defined $props->{$o};
}

# Finally make sure common values for basedir and vardir are set
# (for compatibility)

$props->{basedir} ||= $props->{server_specific}->{1}->{basedir};
$props->{vardir} ||= $props->{server_specific}->{1}->{vardir};

# If we don't have basedir at this point, something went wrong
unless ($props->{basedir}) {
    print STDERR "\nERROR: Basedir is not defined\n\n";
    help();
    exit 1;
}

my $client_basedir;

foreach my $path ("$props->{basedir}/client/RelWithDebInfo", "$props->{basedir}/client/Debug", "$props->{basedir}/client", "$props->{basedir}/bin") {
    if (-e $path) {
        $client_basedir = $path;
        last;
    }
}

if ($props->{genconfig}) {
    unless (-e $props->{genconfig}) {
        croak("ERROR: Specified config template $props->{genconfig} does not exist");
    }
    $props->{cnf_array_ref} = GenTest::App::GenConfig->new(spec_file => $props->{genconfig},
                                               seed => $props->{seed},
                                               debug => $props->{debug}
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

@{$props->{gendata}}= ('') unless (defined $props->{gendata} and scalar @{$props->{gendata}} or $skip_gendata);

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

#
# Start servers. Use rpl_alter if replication is needed.
#

my $rplsrv;
my $version;
my $min_version_numeric= '999999';

if ($props->{rpl_mode} ne '') {

    $rplsrv = DBServer::MySQL::ReplMySQLd->new(master_basedir => $props->{server_specific}->{1}->{basedir},
                                               slave_basedir => $props->{server_specific}->{2}->{basedir},
                                               master_vardir => $props->{server_specific}->{1}->{vardir},
                                               master_port => $props->{server_specific}->{1}->{port},
                                               slave_vardir => $props->{server_specific}->{1}->{vardir}.'_slave',
                                               slave_port => $props->{server_specific}->{2}->{port},
                                               mode => $props->{rpl_mode},
                                               server_options => [ $props->{server_specific}->{1}->{mysqld_options}, $props->{server_specific}->{2}->{mysqld_options} ],
                                               valgrind => $props->{valgrind},
                                               valgrind_options => \@{$props->{valgrind_options}},
                                               general_log => 1,
                                               rr => $props->{rr},
                                               start_dirty => $props->{start_dirty},
                                               use_gtid => $props->{use_gtid},
                                               config => $props->{cnf_array_ref},
                                               user => $props->{user}
    );
    
    my $status = $rplsrv->startServer();
    $version= $rplsrv->version;
    $min_version_numeric= $rplsrv->versionNumeric;
    
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
    
    $props->{server_specific}->{1}->{dsn}= $rplsrv->master->dsn($props->{database},$props->{user});
    $props->{server_specific}->{2}->{dsn}= undef; # No dsn for slave!
    $props->{server_specific}->{1}->{server}= $rplsrv->master;
    $props->{server_specific}->{2}->{server}= $rplsrv->slave;

} elsif ($props->{galera} ne '') {

    if (osWindows()) {
        croak("Galera is not supported on Windows (yet)");
    }

    unless ($props->{galera} =~ /^[ms]+$/i) {
        croak ("--galera option should contain a combination of M and S, indicating masters and slaves");
    }

    $rplsrv = DBServer::MySQL::GaleraMySQLd->new(
        basedir => $props->{basedir},
        parent_vardir => $props->{vardir},
        first_port => $props->{server_specific}->{1}->{port},
        server_options => $props->{server_specific}->{1}->{mysqld_options},
        valgrind => $props->{valgrind},
        valgrind_options => \@{$props->{valgrind_options}},
        general_log => 1,
        rr => $props->{rr},
        start_dirty => $props->{start_dirty},
        node_count => length($props->{galera})
    );
    
    my $status = $rplsrv->startServer();
    
    if ($status > DBSTATUS_OK) {
        stopServers($status);

        sayError("Could not start Galera cluster");
        exit_test(STATUS_ENVIRONMENT_FAILURE);
    }
    $version= $rplsrv->version;
    $min_version_numeric= $rplsrv->versionNumeric;

    my $galera_topology = $props->{galera};
    my $i = 0;
    while ($galera_topology =~ s/^(\w)//) {
        if (lc($1) eq 'm') {
            $props->{server_specific}->{$i+1}->{dsn} = $rplsrv->nodes->[$i]->dsn($props->{database},$props->{user});
        }
        $props->{server_specific}->{$i+1}->{dsn} = $rplsrv->nodes->[$i];
        $i++;
    }

} elsif (not defined $scenario) {

    foreach my $server_id (1..$props->{number_of_servers}) {
        next unless $props->{server_specific}->{$server_id}->{basedir};
        
        $props->{server_specific}->{$server_id}->{server} = DBServer::MySQL::MySQLd->new(
                                                           basedir => $props->{server_specific}->{$server_id}->{basedir},
                                                           vardir => $props->{server_specific}->{$server_id}->{vardir},
                                                           port => $props->{server_specific}->{$server_id}->{port},
                                                           start_dirty => $props->{start_dirty},
                                                           valgrind => $props->{valgrind},
                                                           valgrind_options => \@{$props->{valgrind_options}},
                                                           rr => $props->{rr},
                                                           server_options => $props->{server_specific}->{$server_id}->{mysqld_options},
                                                           general_log => 1,
                                                           config => $props->{cnf_array_ref},
                                                           user => $props->{user});
        
        my $status = $props->{server_specific}->{$server_id}->{server}->startServer;
        
        if ($status > DBSTATUS_OK) {
            stopServers($status);
            if (osWindows()) {
                say(system("dir ".unix2winPath($props->{server_specific}->{$server_id}->{server}->datadir)));
            } else {
                say(system("ls -l ".$props->{server_specific}->{$server_id}->{server}->datadir));
            }
            sayError("Could not start all servers");
            exit_test(STATUS_CRITICAL_FAILURE);
        }
        my $ver= $props->{server_specific}->{$server_id}->{server}->versionNumeric;
        if ($ver lt $min_version_numeric) {
            $min_version_numeric= $ver;
            $version= $props->{server_specific}->{$server_id}->{server}->version;
        }
        
        $props->{server_specific}->{$server_id}->{dsn} = $props->{server_specific}->{$server_id}->{server}->dsn($props->{database},$props->{user});
    }
}

$props->{compatibility}= $version unless defined ($props->{compatibility});

if ($props->{compatibility}=~ /([0-9]+)\.([0-9]+)\.([0-9]+)-([0-9]+)/) {
    $props->{compatibility}= sprintf("%02d%02d%02de",int($1),int($2),int($3));
}
elsif ($props->{compatibility}=~ /([0-9]+)\.([0-9]+)\.([0-9]+)/) {
    $props->{compatibility}= sprintf("%02d%02d%02d",int($1),int($2),int($3));
}

if ($props->{compatibility} gt $min_version_numeric) {
    sayWarning("Minimal server version $min_version_numeric is lower than the required compatibility level $props->{compatibility}. Unexpected syntax errors may occur");
}

say("Server version $version; version compatibility: $props->{compatibility}");

#
# Wait for user interaction before continuing, allowing the user to attach 
# a debugger to the server process(es).
# Will print a message and ask the user to press a key to continue.
# User is responsible for actually attaching the debugger if so desired.
#
if ($wait_debugger) {
    say("Pausing test to allow attaching debuggers etc. to the server process.");
    my @pids;   # there may be more than one server process
    foreach my $server_id (1..$props->{number_of_servers}) {
        $pids[$server_id] = $props->{server_specific}->{$server_id}->{server}->serverpid;
    }
    say('Number of servers started: '.scalar(@pids));
    say('Server PID: '.join(', ', @pids));
    say("Press ENTER to continue the test run...");
    my $keypress = <STDIN>;
}

my $config = GenTest::Properties->init($props);

#######
# Scenario variant
#######
if (defined $scenario) {
  my $cp= my $class= "GenTest::Scenario::$scenario";
  $cp =~ s/::/\//g;
  require "$cp.pm";
  my $sc= $class->new(properties => $config, scenario_options => \%scenario_options);
  my $status= $sc->run();
  say("[$$] $0 will exit with exit status ".status2text($status). " ($status)\n");
  safe_exit($status);
}

#######
# Non-scenario (GenTest) variant
#######
my $gentest = GenTest::App::GenTest->new(config => $config);
my $gentest_result = $gentest->run();
say("GenTest exited with exit status ".status2text($gentest_result)." ($gentest_result)");

# If Gentest produced any failure then exit with its failure code,
# otherwise if the test is replication/with two servers compare the 
# server dumps for any differences else if there are no failures exit with success.

if ( $gentest_result == STATUS_OK
    && ( ($props->{rpl_mode} && $props->{rpl_mode} !~ /nosync/)
         || defined $props->{server_specific}->{2}->{basedir}
         || defined $props->{server_specific}->{3}->{basedir}
         || $props->{galera}
       )
   )
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
  
    foreach my $i (1..$props->{number_of_servers}) {
        $dump_files[$i] = tmpdir()."server_".abs($$)."_".$i.".dump";
        my $dump_result = $props->{server_specific}->{$i}->{server}->dumpdb($props->{database},$dump_files[$i]);
        exit_test($dump_result >> 8) if $dump_result > 0;
    }
  
    say("Comparing SQL dumps...");
    
    foreach my $i (1..$props->{number_of_servers}) {
        next if $i == 1;
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
      foreach my $i (1..$props->{number_of_servers}) {
        my $file= $props->{server_specific}->{$i}->{server}->binary;
        my $to= $props->{server_specific}->{$i}->{vardir};
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
    my $res= DBSTATUS_OK;
    my @errlogs;
    if ($skip_shutdown) {
        say("Server shutdown is skipped upon request");
        return;
    }
    say("Stopping server(s)...");
    if ($props->{rpl_mode} ne '') {
        $res= $rplsrv->stopServer($status);
        @errlogs= $rplsrv->error_logs;
    } else {
        foreach my $i (1..$props->{number_of_servers}) {
            my $srv= $props->{server_specific}->{$i}->{server};
            if ($srv) {
                my $r= $srv->stopServer;
                $res= $r if $r > $res;
                push @errlogs, $srv->error_logs if $r != DBSTATUS_OK;
            }
        }
    }
    if ($res != DBSTATUS_OK) {
        foreach my $log (@errlogs) {
            if (open(ERRLOG, $log)) {
                my @errlog= ();
                my $maxsize= 200;
                while (<ERRLOG>) {
                    shift @errlog if scalar(@errlog) >= $maxsize;
                    push @errlog, $_;
                }
                say("The last 200 lines from $log :");
                print(@errlog);
                close(ERRLOG);
            } else {
                sayError("Couldn't open $log for reading");
            }
        }
    }
    return $res;
}

sub help {
    
    print <<EOF
Copyright (c) 2010,2011 Oracle and/or its affiliates. All rights reserved. Use is subject to license terms.

$0 - Run a complete random query generation test, including server start with replication and master/slave verification
    
    Options related to one standalone MySQL server:

    --basedir   : Specifies the base directory of the stand-alone MySQL installation;
    --mysqld    : Options passed to the MySQL server
    --vardir    : Optional. (default \$basedir/mysql-test/var);
    --debug-server: Use mysqld-debug server (deprecated)

    Options related to two MySQL servers

    --basedir1  : Specifies the base directory of the first MySQL installation;
    --basedir2  : Specifies the base directory of the second MySQL installation;
    --mysqld    : Options passed to both MySQL servers
    --mysqld1   : Options passed to the first MySQL server
    --mysqld2   : Options passed to the second MySQL server
    --debug-server1: Use mysqld-debug server for MySQL server1 (deprecated)
    --debug-server2: Use mysqld-debug server for MySQL server2 (deprecated)
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
    --engine    : Table engine(s) to use when creating tables with gendata (default no ENGINE in CREATE TABLE).
                : Multiple engines should be provided as a comma-separated list.
                  Separate values for separate servers can be provided through --engine1 | --engine2 | --engine3
    --threads   : Number of threads to spawn (default $props->{default_threads});
    --queries   : Number of queries to execute per thread (default $props->{default_queries});
    --duration  : Duration of the test in seconds (default $props->{duration} seconds);
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
    --rr        : Run the server under rr record, if available
    --sqltrace  : Print all generated SQL statements. 
                  Optional: Specify --sqltrace=MarkErrors to mark invalid statements.
    --varchar-length: length of strings. passed to gentest.pl
    --xml-outputs: Passed to gentest.pl
    --vcols     : Types of virtual columns (only used if data is generated by GendataSimple or GendataAdvanced)
    --views     : Generate views. Optionally specify view type (algorithm) as option value. Passed to gentest.pl.
                  Different values can be provided to servers through --views1 | --views2 | --views3
    --valgrind  : Passed to gentest.pl
    --filter    : Suppress queries which match given patterns. Multiple filters can be provided
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
    --compatibility  : Server version which syntax should be compatible with, in the form of x.y.z (e.g. 10.3.22) or NNNNNN (100322).
                       It is not guaranteed that all resulting queries will comply with the requirement, only those which come
                       from the generation mechanisms aware of the option.
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
    my $res= stopServers($status);
    if ($status == STATUS_OK and $res != DBSTATUS_OK) {
        say("Setting status to DBSTATUS_FAILURE due to a problem upon server shutdown");
        $status= DBSTATUS_FAILURE;
    }
    say("[$$] $0 will exit with exit status ".status2text($status). " ($status)");
    safe_exit($status);
}
