#!/usr/bin/perl

# Copyright (c) 2008, 2011 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2014, SkySQL Ab.
# Copyright (c) 2019, MariaDB Corporation Ab
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
#use List::Util 'shuffle';
use Cwd;
use File::Path 'remove_tree';
use GenTest;
use GenTest::Constants;
use Getopt::Long;
use File::Basename;

Getopt::Long::Configure("pass_through");

if (defined $ENV{RQG_HOME}) {
	if (osWindows()) {
		$ENV{RQG_HOME} = $ENV{RQG_HOME}.'\\';
	} else {
		$ENV{RQG_HOME} = $ENV{RQG_HOME}.'/';
	}
} else {
	$ENV{RQG_HOME} = dirname(Cwd::abs_path($0));
}

if ( osWindows() )
{
	require Win32::API;
	my $errfunc = Win32::API->new('kernel32', 'SetErrorMode', 'I', 'I');
	my $initial_mode = $errfunc->Call(2);
	$errfunc->Call($initial_mode | 2);
};

$| = 1;
my $ctrl_c = 0;
	
$SIG{INT} = sub { $ctrl_c = 1 };
$SIG{TERM} = sub { exit(0) };
$SIG{CHLD} = "IGNORE" if osWindows();

my ($vardir, $vardir1, $vardir2, $trials, $force, $old, $output, @exit_status);
my $output_file= "/dev/shm/runall_trials.$$.output";

my $max_result = 0;

my $opt_result = GetOptions(
	'vardir=s' => \$vardir,
	'vardir1=s' => \$vardir1,
	'vardir2=s' => \$vardir2,
	'trials=i' => \$trials,
	'force' => \$force,
	'old' => \$old,
	'exit_status|exit-status=s@' => \@exit_status,
    'output=s' => \$output,
);

$trials = 1 unless defined $trials;

push @ARGV, "--vardir=$vardir" if defined $vardir;
push @ARGV, "--vardir1=$vardir1" if defined $vardir1;
push @ARGV, "--vardir2=$vardir2" if defined $vardir2;

my $comb_str = join(' ', @ARGV);

my $trials_result= 0;

foreach my $trial_id (1..$trials) {

	say("##########################################################");
	say("Running trial ".$trial_id."/".$trials);
	my $runall = $old?"runall.pl":"runall-new.pl";

	my $command = "perl ".
		(defined $ENV{RQG_HOME} ? $ENV{RQG_HOME}."/" : "" ).
		"$runall $comb_str ";

	$command =~ s{[\t\r\n]}{ }sgio;
	$command =~ s{"}{\\"}sgio;

	unless (osWindows())
	{
		$command = 'bash -c "set -o pipefail; '.$command.' 2>&1 | tee '.$output_file.'"';
	}

	say("$command");
    system($command);

	my $result= ($? >> 8);
	my $result_name = status2text($result);
	say("Trial $trial_id ended with exit status $result_name ($result)");
	if (check_for_desired_result($result_name)) {
		$trials_result= 1;
	} else {
        next;
    }
	exit(1) if not defined $force;

    # If we are here, trials are run with --force and check for desired result returned success
    # Storing vardirs for the failure
    foreach my $v ($vardir,$vardir1,$vardir2) {
        next unless defined $v;
        # Remove trailing slashes
        $v =~ s/[\/\\]+$//;
        my $from = $v;
        my $to = $v.'_trial'.$trial_id;
        say("Copying $from to $to");
        remove_tree($to) if (-e $to);
        remove_tree($to.'_slave') if (-e $to.'_slave');
        if (osWindows()) {
            system("xcopy \"$from\" \"$to\" /E /I /Q");
            system("xcopy \"$from"."_slave\" \"$to"."_slave\" /E /I /Q") if -e $from.'_slave';
            open(OUT, ">$to/command");
            print OUT $command;
            close(OUT);
        } elsif ($command =~ m{--mem}) {
            system("cp -r /dev/shm/var $to");
            open(OUT, ">$to/command");
            print OUT $command;
            close(OUT);
        } else {
            system("cp -r $from $to");
            system("cp -r $from"."_slave $to"."_slave") if -e $from.'_slave';
            open(OUT, ">$to/command");
            print OUT $command;
            close(OUT);
        }
    }
}

say("$0 will exit with exit status ".($trials_result ? 'REPRODUCED':'FAILED TO REPRODUCE')." ($trials_result)");
unlink($output_file);
exit($trials_result);

sub check_for_desired_result {
	my $resname = shift;

    # NOTE: subroutine returns 1 if the goal was achieved, and 0 otherwise

    if ($output) {
        unless (open(OUTFILE, "$output_file")) {
            sayError("Could not open $output_file for reading: $!");
            say("Cannot check if output matches the pattern, result will be ignored");
            unlink($output_file);
            return 0;
        }
        my $output_matches= 0;
        while (<OUTFILE>) {
            if (/$output/) {
                $output_matches= 1;
                last;
            }
        }
        close(OUTFILE);
        unless ($output_matches) {
            say("Output did not match the pattern \'$output\', result will be ignored");
            return 0;
        }
    }

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
    elsif (not $output and $resname eq 'STATUS_OK') {
        say("Exit status STATUS_OK and the list of desired status codes is empty, result will be ignored");
        return 0;
    }

    # If we are here, we have achieved the goal, we just need to produce a proper log message

    my $line= "Trials succeeded at reproducing the problem: exit status $resname";
    if (scalar @exit_status) {
        $line.= ' matches one of desired exit codes';
    }
    if ($output) {
        $line.= ", output \'$output\' has been found";
    }
    say($line);
    return 1;
}


