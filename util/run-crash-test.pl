#!/usr/bin/perl

# Copyright (C) 2013 Monty Program Ab
# Copyright (C) 2025 MariaDB
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


#########################
# The script is meant to imitate a power-off situation,
# using kvm VMs for this
#########################

use lib 'lib';
use lib "$ENV{RQG_HOME}/lib";

use POSIX ":sys_wait_h";
use Getopt::Long qw( :config pass_through );
use Constants;
use DBServer;
use GenUtil;

use strict;

if (osWindows()) {
  say("ERROR: This test flow is Linux-specific for now");
  exit STATUS_ENVIRONMENT_FAILURE;
}

if (system('which kvm')) {
  say("ERROR: kvm not found");
  exit STATUS_ENVIRONMENT_FAILURE;
}

my @opt_gendatas;
my $opt_duration = 600;
my $opt_build_ref;
my $opt_vm_port = 2201;
my $opt_vm_user = $ENV{USER};
my $opt_base_vm = '/home/binlog/binlog-crash.qcow2';
my $opt_host_workdir;
my $opt_guest_basedir;
my $opt_guest_vardir;
my $opt_cmake_options = '';

my $vm_pid;
my $cmd_prefix = '';
my @reporters;
my @reporters_with_Crash;
my @reporters_with_BinlogConsistency;

my $opt_result = GetOptions(
  'duration=i' => \$opt_duration,
  'vm-port|vm_port=i' => \$opt_vm_port,
  'vm-user|vm_user=s' => \$opt_vm_user,
  'build-ref|build_ref=s' => \$opt_build_ref,
  'base-vm|base_vm=s' => \$opt_base_vm,
  'gendatas=s@' => \@opt_gendatas,
  'workdir=s' => \$opt_host_workdir,
  'basedir=s' => \$opt_guest_basedir,
  'vardir=s' => \$opt_guest_vardir,
  'cmake_options|cmake-options=s' => \$opt_cmake_options,
);

if (!$opt_host_workdir) {
  sayError("Workdir is not defined. It is a local workdir where the VM image and its backup will be stored");
  exit STATUS_ENVIRONMENT_FAILURE;
}

if (!$opt_guest_basedir) {
  sayError("Basedir is not defined. It should be a location of the existing or the target clone/build inside the VM");
  exit STATUS_ENVIRONMENT_FAILURE;
}

if (!$opt_guest_vardir) {
  sayError("Vardir is not defined. It should be a non-temporary location inside the VM");
  exit STATUS_ENVIRONMENT_FAILURE;
} elsif ($opt_guest_vardir =~ /^\/(?:tmp|dev\/shm)/) {
  sayError("Vardir must be in a temporary storage, otherwise we won't be able to restore on it'");
  exit STATUS_ENVIRONMENT_FAILURE;
}

my $vm_pidfile = "$ENV{HOME}/.runvmkvm_$opt_vm_port.pid";

system("mkdir -p $opt_host_workdir");

# We needed to extract duration of the test for the VM watchdog,
# the basedir for the clone/build if requested,
# the vardir for checking,
# and gendatas for removing them at recovery.
# Now we are returning them to options
my $rqg_options = "@ARGV --duration=$opt_duration --basedir=$opt_guest_basedir --vardir=$opt_guest_vardir";
foreach (@opt_gendatas) {
	$rqg_options.= " --gendata=$_";
}

# We will need to SSH to the VM before running commands
$cmd_prefix = 'ssh -o ConnectTimeout=5 -p '.$opt_vm_port.' '.$opt_vm_user.'@localhost ';

# Preparation phase, part 1: start the VM
start_vm($opt_base_vm,"$opt_host_workdir/crashtest.qcow2");

# Preparation phase, part 2
# If requested, we need to clone/pull trees and build

if ($opt_build_ref) {
  system("rm -rf $opt_guest_basedir \
		&& git init $opt_guest_basedir \
		&& cd $opt_guest_basedir \
    && git fetch https://github.com/MariaDB/server $opt_build_ref --depth=1 \
    && git checkout FETCH_HEAD \
    && cmake . \
			-DPLUGIN_CONNECT=NO \
			-DPLUGIN_COLUMNSTORE=NO \
			-DPLUGIN_MROONGA=NO \
			-DPLUGIN_SPHINX=NO \
			-DPLUGIN_OQGRAPH=NO \
			$opt_cmake_options \
    && make -j8 \
    && \$HOME/mariadb-toolbox/scripts/create_so_symlinks.sh");
}

#my $cmd = $cmd_prefix."'bash -c ".'"'.$opt_guest_basedir.'/sql/mariadbd --version > /dev/null 2>&1"'."'";
#say("Running: $cmd");
#if (system($cmd)) {
#	sayError("Server not found in $opt_guest_basedir/sql");
#	kill(9, $vm_pid);
#	exit STATUS_ENVIRONMENT_FAILURE;
#}

# Phase 1
# Test flow and server/VM crash 

say("############################");
say("Executing the first part of the test: clean server start, test flow + crash");
say("############################");

my $remote_rqg_pid = fork();
die "Could not fork for running RQG remotely: $!" unless defined $remote_rqg_pid;
if ($remote_rqg_pid) {
	# TODO:
	# For now we presume that server startup in the VM will be fast enough,
	# so we will have a good part of the test flow executed before <duration>.
	# In fact, especially with small duration values, it might be not so,
	# e.g. if duration is 1 min, we might end up killing the VM before the actual flow
	# has even started. Later we'll need a better check for that
	my $remote_rqg_exit_code = undef;
	foreach (1..$opt_duration) {
		waitpid($remote_rqg_pid, WNOHANG);
		if ($? > -1) { # process exited
      $remote_rqg_exit_code = $?;
			say("ERROR: remote RQG process exited unexpectedly with exit code $remote_rqg_exit_code");
			last;
		}
		sleep 1;
	}
	kill_vm();
	exit $remote_rqg_exit_code if (defined $remote_rqg_exit_code);
} else {
	my $cmd = $cmd_prefix.'"cd $HOME/rqg && git pull && perl ./run.pl --scenario=Standard '. $rqg_options.'" && exit';
	say("Running $cmd ...");
	my $remote_rqg_status = system($cmd) >> 8;
	say("RQG process (1st part) exited with status $remote_rqg_status");
	exit;
}

# Let the system to settle down a bit
sleep(3);

# Phase 2: recovery. We'll only let the server recover, run a few queries,
# and wait for replication to catch up. Let's see how it goes

say("############################");
say("Executing the second part of the test: server recovery and replica synchronization");
say("############################");

my $timestamp = time();
system("cp $opt_host_workdir/crashtest.qcow2 $opt_host_workdir/crashtest.qcow2.save".time());
start_vm(undef,"$opt_host_workdir/crashtest.qcow2");

my $vardir_backup = $opt_guest_vardir;
$vardir_backup =~ s/\/*$//g;
$vardir_backup .= '_backup';

say("Backing up vardir as $vardir_backup...");
my $cmd = $cmd_prefix. "mv $opt_guest_vardir $vardir_backup";
system($cmd);

my $rqg_recovery_options="@ARGV --scenario=Replication --skip-gendata --scenario-use-gtid --basedir=$opt_guest_basedir --vardir=$opt_guest_vardir --server1-dataset=$vardir_backup/s1/data --queries=10 --duration=$opt_duration";

$cmd = $cmd_prefix . '"cd $HOME/rqg && '.'perl ./run.pl ' . "$rqg_recovery_options".'"';
say("Running $cmd ...");
my $remote_rqg_status = system($cmd) >> 8;
say("Remote RQG process (2nd part) exited with status $remote_rqg_status");

say("Killing the VM (as a cleanup measure)...");
kill_vm();
exit $remote_rqg_status;

sub start_vm {
  my ($base_image, $image) = @_;
  if (-e $vm_pidfile) {
    sayWarning("Old VM pidfile found, the process with this pid will be killed!");
    kill_vm();
  }
  $base_image = ($base_image ? "--base-image=$base_image" : '');
  my $startup_timeout=600;
  my $wait_end = time() + $startup_timeout;
  my $cmd = "runvm --port=$opt_vm_port --user=$opt_vm_user --smp=4 --mem=16384 --startup-timeout=$startup_timeout --shutdown-timeout=300 --cpu=qemu64 $base_image $image bash > $opt_host_workdir/vm.log 2>&1 &";
  say("Starting the VM: $cmd...");
  system($cmd);
  say("Trying $cmd_prefix \"ls\"");
  while (time() < $wait_end) {
    if (!system("$cmd_prefix \"ls\"")) {
      say("Reading $vm_pidfile");
      system("cat $vm_pidfile");
      say("VM started");
      return;
    }
    sleep 1;
  }
  die "Failed to start the VM" unless $vm_pid;
}

sub kill_vm {
  my $vm_pid = readpipe("head -n 1 $vm_pidfile");
  chomp $vm_pid;
  if (!system("ps -ef | grep $vm_pid | grep kvm")) {
    say("Killing the VM ($vm_pid)...");
    kill(9,$vm_pid);
    sleep 3;
  }
}
