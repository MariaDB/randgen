#!/usr/bin/perl

# Copyright (c) 2008-2009 Sun Microsystems, Inc. All rights reserved.
# Copyright (c) 2020, MariaDB Corporation
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

use strict;
use lib 'lib';
use lib "$ENV{RQG_HOME}/lib";
use Carp;
use Getopt::Long;
Getopt::Long::Configure("pass_through");

use GenTest;
use GenTest::Constants;
use GenTest::Grammar;
use GenTest::Properties;
use GenTest::Simplifier::Grammar;
use Time::HiRes;

# Overview
# ========
# This script can be used to simplify grammar files to the smallest form
# which will still reproduce a desired outcome.
#

my $storage_prefix;
my $mtr_thread= 500;
my $expected_output;
my $seed= 1;

GetOptions(
    'workdir=s' => \$storage_prefix,
    'mtr_thread|mtr-thread=i' => \$mtr_thread,
    'output=s' => \$expected_output,
    'seed=i' => \$seed,
);

unless (defined $storage_prefix) {
    croak("ERROR: Workdir (--workdir) is not defined");
}

my $run_id = time();
say("The ID of this run is $run_id.");

my $vardir= $storage_prefix.'/vardir';
my $storage = $storage_prefix.'/grammars';
system("rm -rf $vardir $storage");
system("mkdir -p $vardir");
if ($?) {
    croak("ERROR: Could not create vardir $vardir");
}
mkdir ($storage);
say "Vardir: $vardir";
say "Grammar storage: $storage";
say "MTR build thread: $mtr_thread";

my @transformation_validators= ();
my @transformers= ();
my @simplifiable_options= ();
my @grammars= ();
my $grammar;

my $iteration= 0;

my $rqgcmd_base =
    "perl runall-trials.pl ".
    "--vardir=$vardir ".
    "--mtr-build-thread=$mtr_thread ".
    "--seed=$seed "
;

$rqgcmd_base.= " --output=\"$expected_output\"" if $expected_output;

foreach my $opt (@ARGV)
{
    # Some options will be kept as is
    if ($opt =~ /^--grammar=(.*)/) {
        $grammar= $1;
    } elsif ($opt =~ /^--redefine=(.*)/) {
        push @grammars, $1;
    } elsif ($opt =~ /^(--mysqld\d?)=--(.*)/) {
        my ($left, $right)= ($1, $2);
        if ($right !~ /^loose-/) {
            $right= 'loose-'.$right;
        }
        push @simplifiable_options, "$left=--$right";
    } elsif ($opt =~ /^--(basedir\d?|duration|queries|threads|exit[-_]status|trials)=/) {
        $rqgcmd_base.= " $opt";
    } elsif ($opt =~ /^--(vardir\d?|seed|mtr[-_]build[-_]thread)=/) {
        # vardir, mtr-build-thread and seed are overridden anyway, skipping them completely
    } elsif ($opt =~ /--transformers=(.*)/) {
        my @vals= split /,/, $1;
        @transformers= (@transformers, @vals);
    } elsif ($opt =~ /--validators=(.*)/) {
        my @vals= split /,/, $1;
        foreach my $v (@vals) {
            if ($v =~ /Transformer/) {
                push @transformation_validators, $v;
            } else {
                push @simplifiable_options, "--validators=$v";
            }
        }
    } elsif ($opt =~ /--reporters=(.*)/) {
        my @vals= split /,/, $1;
        foreach my $v (@vals) {
            if ($v eq 'Deadlock') {
                $rqgcmd_base.= " --reporters=$v";
            } else {
                push @simplifiable_options, "--reporters=$v";
            }
        }
    } else {
        push @simplifiable_options, $opt;
    }
}

unless ($grammar) {
    say("No grammar defined");
    exit 1;
}

say("###########################");
say("### Running initial trials");
say("");

my $cmd= "$rqgcmd_base --grammar=$grammar";
map { $cmd.= " --transformers=$_" } @transformers if scalar(@transformers);
map { $cmd.= " --validators=$_" } @transformation_validators if scalar(@transformation_validators);
map { $cmd.= " --redefine=$_" } @grammars if scalar(@grammars);
$cmd.= " @simplifiable_options";
$cmd.= " > ${storage}/${iteration}.log";
say($cmd);
# runall-trials returns 1 if the failure was reproduced, and 0 otherwise
my $res= system($cmd);
if ($res) {
    say("###### SUCCESS with cmd $iteration: initial run reproduced the issue");
    $iteration++;
} else {
    say("Initial run failed to reproduce the issue, giving up");
    exit 1;
}

say("########################################");
say("### Running command line simplification");
say("");

# At this point @grammars contains redefines, if any,
# and $grammar contains the main grammar

if (scalar @grammars)
{
    say("Redefines to be simplified: @grammars");

    my @preserved_redefines= ();
    my $cmd= "$rqgcmd_base --grammar=$grammar";
    map { $cmd.= " --transformers=$_" } @transformers if scalar(@transformers);
    map { $cmd.= " --validators=$_" } @transformation_validators if scalar(@transformation_validators);
    $cmd.= " @simplifiable_options";
    
    for (my $i=0; $i<=$#grammars; $i++) {
        say("-----");
        say("Trying to remove redefine $grammars[$i]");
        my @new_grammars= ($i < $#grammars ? (@preserved_redefines, @grammars[$i+1..$#grammars]) : (@preserved_redefines));
        my $new_cmd= $cmd;
        map { $new_cmd.= " --redefine=$_" } @new_grammars if scalar(@new_grammars);
        $new_cmd.= " > ${storage}/${iteration}.log";
        say($new_cmd);
        # runall-trials returns 1 if the failure was reproduced, and 0 otherwise
        my $res= system($new_cmd);
        if ($res) {
            say("###### SUCCESS with cmd $iteration: redefine $grammars[$i] can be removed");
        } else {
            say("Redefine $grammars[$i] has to be preserved");
            push @preserved_redefines, $grammars[$i];
        }
        $iteration++;
    }
    @grammars= @preserved_redefines;
}

if (scalar @transformers)
{
    say("-----");
    say("Transformers to be simplified: @transformers");
    say("Transformation validators to be taken into account: @transformation_validators");

    my @preserved_transformers= ();
    my $cmd= "$rqgcmd_base --grammar=$grammar";
    map { $cmd.= " --redefine=$_" } @grammars if scalar(@grammars);
    $cmd.= " @simplifiable_options";

    for (my $i=0; $i<=$#transformers; $i++) {
        say("-----");
        say("Trying to remove transformer $transformers[$i]");
        my @new_transformers= ($i < $#transformers ? (@preserved_transformers, @transformers[$i+1..$#transformers]) : (@preserved_transformers));
        my $new_cmd= $cmd;
        map { $new_cmd.= " --transformers=$_" } @new_transformers if scalar(@new_transformers);
        map { $new_cmd.= " --validators=$_" } @transformation_validators if scalar(@new_transformers);
        $new_cmd.= " > ${storage}/${iteration}.log";
        say($new_cmd);
        # runall-trials returns 1 if the failure was reproduced, and 0 otherwise
        my $res= system($new_cmd);
        if ($res) {
            say("###### SUCCESS with cmd $iteration: transformer $transformers[$i] can be removed");
        } else {
            say("Transformer $transformers[$i] has to be preserved");
            push @preserved_transformers, $transformers[$i];
        }
        $iteration++;
    }
    if (scalar @preserved_transformers) {
        map { $rqgcmd_base.= " --transformers=$_" } @preserved_transformers;
        map { $rqgcmd_base.= " --validators=$_" } @transformation_validators;
    }
}

if (scalar @simplifiable_options)
{
    say("-----");
    say("Options to be simplified: @simplifiable_options");

    my @preserved_options= ();
    my $cmd= "$rqgcmd_base --grammar=$grammar";
    map { $cmd.= " --redefine=$_" } @grammars if scalar(@grammars);

    for (my $i=0; $i<=$#simplifiable_options; $i++) {
        say("-----");
        say("Trying to remove option $simplifiable_options[$i]");
        my $new_cmd= "$cmd @preserved_options @simplifiable_options[$i+1..$#simplifiable_options]";
        $new_cmd.= " > ${storage}/${iteration}.log";
        say($new_cmd);
        # runall-trials returns 1 if the failure was reproduced, and 0 otherwise
        my $res= system($new_cmd);
        if ($res) {
            say ("###### SUCCESS with cmd $iteration: option $simplifiable_options[$i] can be removed ######");
        } else {
            say("Option $simplifiable_options[$i] has to be preserved");
            push @preserved_options, $simplifiable_options[$i];
        }
        $iteration++;
    }
    $rqgcmd_base.= " @preserved_options";
}

say("Command line simplification finished, final set of options (excluding grammars):");
say("$rqgcmd_base");

say("####################################");
say("### Running grammar simplification");
say("");

@grammars= ($grammar, @grammars);

my $grammar = GenTest::Grammar->new(
    grammar_files => [ @grammars ],
    grammar_flags => (undef)
);

$grammar->extractFromFiles(\@grammars);
$grammar->parseFromString($grammar->string());
my $initial_grammar = $grammar->toString();

my $errfile = $vardir . '/mysql.err';
my $general_log = $vardir . '/mysql.log';

my $simplifier = GenTest::Simplifier::Grammar->new(
    grammar_flags => +GRAMMAR_FLAG_COMPACT_RULES,
    oracle => sub {
        $iteration++;
        my $oracle_grammar = shift;

        my $current_grammar = $storage . '/' . $iteration . '.yy';
        open (GRAMMAR, ">$current_grammar")
           or croak "unable to create $current_grammar : $!";
        print GRAMMAR $oracle_grammar;
        close (GRAMMAR);

        say("run_id = $run_id; iteration = $iteration");

        my $current_rqg_log = $storage . '/' . $iteration . '.log';
        my $start_time = Time::HiRes::time();

        my $rqgcmd= "$rqgcmd_base --grammar=$current_grammar >$current_rqg_log 2>&1";
        say($rqgcmd);
        my $rqg_status = system($rqgcmd);
        $rqg_status = $rqg_status >> 8;

        my $end_time = Time::HiRes::time();
        my $duration = $end_time - $start_time;

        say("rqg_status = $rqg_status; duration = $duration");

        # runall-trials.pl returns 1 if the failure was reproduced
        # and 0 otherwise
        if ($rqg_status) {
            say ("###### SUCCESS with $current_grammar ######");
            say ("#####################");
            system("cp $general_log $storage/mysql.log.$iteration");
            return ORACLE_ISSUE_STILL_REPEATABLE;
        }
        return ORACLE_ISSUE_NO_LONGER_REPEATABLE;
    }
);

my $simplified_grammar = $simplifier->simplify($initial_grammar);

if (defined $simplified_grammar) {
    print "Simplified grammar:\n\n$simplified_grammar;\n\n";
    exit 0;
} else {
    exit 1;
}
