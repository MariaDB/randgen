# Copyright (C) 2019, 2022 MariaDB Corporation Ab
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
#
# The module implements the core functions for MariaBackup scenarios
#
########################################################################

package GenTest::Scenario::MariaBackup;

require Exporter;
@ISA = qw(GenTest::Scenario);

use strict;
use GenUtil;
use GenTest;
use GenTest::TestRunner;
use GenTest::Properties;
use Constants;
use GenTest::Scenario;
use Data::Dumper;
use File::Copy;
use File::Compare;
use POSIX;

use DBServer::MariaDB;

use constant MARIABACKUP_BACKUP_INTERVAL => 51;

sub new {
  my $class= shift;
  my $self= $class->SUPER::new(@_);
  $self->[MARIABACKUP_BACKUP_INTERVAL]= $self->scenarioOptions->{backup_interval} || int($self->getProperty('duration')/2);
  return $self;
}

sub prepare_server {
  my $self= shift;

  my $server= $self->prepareServer(1,my $is_active=1);
  if ($server) {
    say("-- Server info: --");
    say($server->version());
    $server->printServerOptions();
  }
  return $server;
}

sub mbackup_backup_interval {
  return $_[0]->[MARIABACKUP_BACKUP_INTERVAL];
}

# The subroutine will return STATUS_OK (0) if the process finished successfully,
# non-zero positive exit code if it failed,
# and -1 if it hung.
# stdout and stderr of the command are written into $log
sub run_mbackup_in_background {
    my ($self, $cmd, $end_time, $log)= @_;
    return $self->_run_mbackup_in_background_windows($cmd, $end_time, $log) if osWindows();
    $cmd.= " >$log";
    my $vardir= $self->getProperty('vardir');
    open(MBACKUP,">$vardir/mbackup_script") || die "Could not open $vardir/mbackup_script for writing: $!\n";
    print(MBACKUP "rm -f $vardir/mbackup_exit_code $vardir/mbackup_pid\n");
    print(MBACKUP "LD_LIBRARY_PATH=\$MSAN_LIBS:\$LD_LIBRARY_PATH $cmd 2>&1 || echo \$? > $vardir/mbackup_exit_code &\n");
    print(MBACKUP "echo \$! > $vardir/mbackup_pid\n");
    close(MBACKUP);
    sayFile("$vardir/mbackup_script");
    system(". $vardir/mbackup_script");
    my $mbackup_pid=`cat $vardir/mbackup_pid`;
    chomp $mbackup_pid;
    my $wait_time= $end_time - time();
    $wait_time= 60 if $wait_time < 60;
    say("Waiting $wait_time sec for mariabackup with pid $mbackup_pid to finish");
    foreach (1 .. $wait_time)
    {
        if (kill(0, $mbackup_pid)) {
            sleep 1;
        }
        else {
            my $status= (-e "$vardir/mbackup_exit_code" ? `cat $vardir/mbackup_exit_code` : 0);
            chomp $status;
            return $status;
        }
    }
    sayError("Backup did not finish in due time");
    kill(6, $mbackup_pid);
    return -1;
}

# There is no sh on Windows, and fork is emulated with threads there.
# Instead, a helper Perl process is started asynchronously. It redirects
# its output into the log, starts mariabackup directly (not via cmd.exe,
# so that the pid is of mariabackup itself), stores the pid in mbackup_pid
# (which is also used by group_cleaner), and exits with mariabackup's
# exit code. The command must not contain redirections or other shell
# constructs.
sub _run_mbackup_in_background_windows {
    my ($self, $cmd, $end_time, $log)= @_;
    my $vardir= $self->getProperty('vardir');
    my $pidfile= "$vardir/mbackup_pid";
    my $script= "$vardir/mbackup_script.pl";
    unlink($pidfile);
    local $Data::Dumper::Terse= 1;
    local $Data::Dumper::Useqq= 1;
    local $Data::Dumper::Indent= 0;
    open(my $fh, '>', $script) || die "Could not open $script for writing: $!\n";
    print $fh 'my ($cmd, $log, $pidfile)= ('.join(', ', map { Dumper($_) } ($cmd, $log, $pidfile)).");\n";
    print $fh <<'END_OF_SCRIPT';
open(STDOUT, '>', $log) or die "Could not open $log for writing: $!\n";
open(STDERR, '>&', \*STDOUT) or die "Could not redirect STDERR: $!\n";
$|= 1;
my $pid= system(1, $cmd);
unless ($pid and $pid > 0) {
  print "Could not start $cmd: $!\n";
  exit 255;
}
if (open(my $pf, '>', $pidfile)) {
  print $pf "$pid\n";
  close($pf);
}
waitpid($pid, 0);
exit($? >> 8);
END_OF_SCRIPT
    close($fh);
    sayFile($script);
    my $helper_pid= system(1, $^X, $script);
    unless ($helper_pid and $helper_pid > 0) {
      sayError("Could not start the helper process for mariabackup: $!");
      return 255;
    }
    my $wait_time= $end_time - time();
    $wait_time= 60 if $wait_time < 60;
    say("Waiting $wait_time sec for mariabackup (started by helper process $helper_pid) to finish");
    foreach (1 .. $wait_time)
    {
        if (waitpid($helper_pid, WNOHANG) == 0) {
            sleep 1;
        }
        else {
            return ($? >> 8);
        }
    }
    sayError("Backup did not finish in due time");
    my $mbackup_pid= read_file($pidfile);
    if (defined $mbackup_pid and $mbackup_pid =~ /(\d+)/) {
      $mbackup_pid= $1;
      say("Killing mariabackup with pid $mbackup_pid (there is no SIGABRT on Windows, no coredump will be produced)");
      kill('KILL', $mbackup_pid);
    }
    foreach (1..30) {
      last if waitpid($helper_pid, WNOHANG) != 0;
      sleep 1;
    }
    if (waitpid($helper_pid, WNOHANG) == 0) {
      kill('KILL', $helper_pid);
      waitpid($helper_pid, 0);
    }
    return -1;
}

sub binlog_info {
  my $self= shift;
  my $prng = $self->prng;
  return $prng->arrayElement(['OFF','ON','LOCKLESS','AUTO']);
}

1;
