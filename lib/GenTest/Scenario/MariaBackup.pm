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
  say("-- Server info: --");
  say($server->version());
  $server->printServerOptions();

  return $server;
}

sub mbackup_backup_interval {
  return $_[0]->[MARIABACKUP_BACKUP_INTERVAL];
}

# The subroutine will return STATUS_OK (0) if the process finished successfully,
# non-zero positive exit code if it failed,
# and -1 if it hung
sub run_mbackup_in_background {
    my ($self, $cmd, $end_time)= @_;
    my $vardir= $self->getProperty('vardir');
    open(MBACKUP,">$vardir/mbackup_script") || die "Could not open $vardir/mbackup_script for writing: $!\n";
    print(MBACKUP "rm -f $vardir/mbackup_exit_code $vardir/mbackup_pid\n");
    print(MBACKUP "$cmd 2>&1 || echo \$? > $vardir/mbackup_exit_code &\n");
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

1;
