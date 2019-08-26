#!/usr/bin/perl

# Copyright (c) 2008-2009 Sun Microsystems, Inc. All rights reserved.
# Copyright (c) 2019, MariaDB Corporation
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

my ($trials, $storage_prefix);
my @exit_status;
my @expected_output;
my $mtr_thread= 500;

GetOptions(
    'trials=i' => \$trials,
    'exit_status|exit-status=s@' => \@exit_status,
    'output=s@' => \@expected_output,
    'workdir=s' => \$storage_prefix,
    'mtr_thread|mtr-thread=i' => \$mtr_thread,
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

my $exit_status_values= '';
map { $exit_status_values.= "--exit-status=".$_." " } (@exit_status);

my @mysqld_options;
my @rqg_options;
my @grammars;
my @validators;
my @transformers;
my @reporters;
my @gendata_options;
my $threads= 2;
my $duration= 400;

foreach my $o (@ARGV) {
    if ($o =~ /^--mysqld\d?=/) {
        push @mysqld_options, $o;
    } elsif ($o =~ /^(?:--grammar|--redefine)\d?=(.+)/) {
        push @grammars, $1;
    } elsif ($o =~ /^--reporters=(.*)/) {
        my @r= split(/,/,$1);
        push @reporters, @r;
    } elsif ($o =~ /^--transformers=(.*)/) {
        my @t= split(/,/,$1);
        push @transformers, @t;
    } elsif ($o =~ /^--validators=(.*)/) {
        my @v= split(/,/,$1);
        push @validators, @v;
    } elsif ($o =~ /^--gendata|^--skip[-_]gendata/) {
        push @gendata_options, $o;
    } elsif ($o =~ /^--duration=(\d+)/) {
        $duration= $1;
    } elsif ($o =~ /^--threads=(\d+)/) {
        $threads= $1;
    } elsif ($o !~ /^--(?:vardir|mtr[-_]build[-_]thread)/) {
        # Vardir and mtr-build-thread are replaced by own values
        push @rqg_options, $o;
    }
}

unless (scalar @grammars) {
    croak("No grammars defined");
}

my $initial_grammar= '';

foreach my $g (@grammars) {
    my $contents;
    open(INITIAL_GRAMMAR, $g) or croak "Unable to open initial_grammar_file '" . $g . "' : $!";
    read(INITIAL_GRAMMAR, $contents , -s $g);
    close(INITIAL_GRAMMAR);
    $initial_grammar.= $contents;
}

my $errfile = $vardir . '/mysql.err';
my $general_log = $vardir . '/mysql.log';

my $iteration;

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

        my $rqgcmd =
            "perl runall-trials.pl ".
            "$exit_status_values ".
            "--output=\"".$expected_output[0]."\" ".
            "--trials=$trials ".
            "--grammar=$current_grammar ".
            "--duration=$duration ".
            "--threads=$threads ".
            "--vardir=$vardir ".
            "--mtr-build-thread=$mtr_thread ".
            "@rqg_options ".
            "@gendata_options ".
            "@rqg_options ".
            "@mysqld_options "
        ;

        if (scalar @transformers) {
            $rqgcmd.= '--transformers='.join(',', @transformers).' ';
        }
        if (scalar @validators) {
            $rqgcmd.= '--validators='.join(',', @validators).' ';
        }
        if (scalar @reporters) {
            $rqgcmd.= '--reporters='.join(',', @reporters).' ';
        }

        $rqgcmd.= " >$current_rqg_log 2>&1";

        say($rqgcmd);
        my $rqg_status = system($rqgcmd);
        $rqg_status = $rqg_status >> 8;

        my $end_time = Time::HiRes::time();
        my $duration = $end_time - $start_time;

        unless (scalar @exit_status) {
            @exit_status= (+STATUS_ANY_ERROR);
        }

        say("rqg_status = $rqg_status; duration = $duration");

        foreach my $desired_status_code (@exit_status)
        {
            return ORACLE_ISSUE_NO_LONGER_REPEATABLE
                if ($rqg_status == STATUS_ENVIRONMENT_FAILURE && 
                    $desired_status_code != STATUS_ENVIRONMENT_FAILURE);

            if (($rqg_status == $desired_status_code) ||
                (($rqg_status != 0) && ($desired_status_code == STATUS_ANY_ERROR))) {
                # The current log (to be scanned for @expected_output) is in $current_rqg_log 

                open (my $my_logfile,'<'.$current_rqg_log)
                    or croak "unable to open $current_rqg_log : $!";

                # If open (above) did not fail than size determination must be successful.
                my @filestats = stat($current_rqg_log);
                my $filesize = $filestats[7];

                seek($my_logfile, -$filesize, 2) or croak "Could not seek $filesize bytes backwards from the 
                end of the file '$current_rqg_log' (which is $filesize bytes long). Error: $!\n";
                read($my_logfile, my $rqgtest_output, $filesize);

                # Every element of @expected_output must be found in $rqgtest_output.
                my $success = 1;
                foreach my $expected_output (@expected_output) {
                    if ($rqgtest_output =~ m{$expected_output}sio) {
                        say ("#####################");
                        say ("###### Found pattern:  $expected_output ######");
                    } else {
                        say ("###### Not found pattern:  $expected_output ######");
                        $success = 0;
                        last;
                    }
                }
                if ($success) {
                    say ("###### SUCCESS with $current_grammar ######");
                    say ("#####################");
                    system("cp $general_log $storage/mysql.log.$iteration");
                    return ORACLE_ISSUE_STILL_REPEATABLE;
                }
            } # End of check if the output matches given string patterns
        } # End of loop over desired_status_codes
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
