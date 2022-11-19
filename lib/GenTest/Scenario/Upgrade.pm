# Copyright (C) 2017, 2020 MariaDB Corporation Ab
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
# The module implements the core functions for server upgrade scenarios
#
########################################################################

package GenTest::Scenario::Upgrade;

require Exporter;
@ISA = qw(GenTest::Scenario);

use strict;
use DBI;
use GenUtil;
use GenTest;
use GenTest::App::GenTest;
use GenTest::Properties;
use GenTest::Constants;
use GenTest::Scenario;
use Data::Dumper;
use File::Copy;
use File::Compare;

use DBServer::MariaDB;

sub new {
  my $class= shift;
  my $self= $class->SUPER::new(@_);
  my $srvspec= $self->getProperty('server_specific');
  # Use common vardir if it was provided
  $srvspec->{1}->{vardir}= $self->getProperty('vardir') || $srvspec->{1}->{vardir};

  if ($self->getProperty('number_of_servers') == 1) {
    $srvspec->{2}= $srvspec->{1};
  } else {
    $srvspec->{2}->{vardir}= $srvspec->{1}->{vardir};
    $srvspec->{2}->{port}= $srvspec->{1}->{port};
    $srvspec->{2}->{database}= $srvspec->{1}->{database};
  }
  $self->setProperty('server_specific',$srvspec);
  $self->setProperty('number_of_servers',1);

  return $self;
}

sub old_server_options {
  return $_[0]->getProperty('server_specific')->{1};
}

sub new_server_options {
  return $_[0]->getProperty('server_specific')->{2};
}

sub prepare_servers {
  my $self= shift;

  # We can initialize both servers right away, because the second one
  # runs with start_dirty, so it won't bootstrap

  my $old_server= $self->prepareServer(1);
  my $new_server= $self->prepareServer(2, my $start_dirty= 1);

  say("-- Old server info: --");
  say($old_server->version());
  $old_server->printServerOptions();
  say("-- New server info: --");
  say($new_server->version());
  $new_server->printServerOptions();
  say("----------------------");

  $self->setServerSpecific(2,'dsn',$self->getServerSpecific(1,'dsn'));

  $self->backupProperties();

  return ($old_server, $new_server);
}

sub switch_to_new_server {
  my $self= shift;
  my $srvspec= $self->getProperty('server_specific');
  $srvspec->{1}= $self->new_server_options();
  $self->setProperty('server_specific',$srvspec);
  if ($self->scenarioOptions()->{grammar2}) {
    $self->setProperty('grammar',$self->scenarioOptions()->{grammar2});
  }
  if ($self->scenarioOptions()->{redefine2}) {
    my @redefines= @{$self->getProperty('redefine')};
    push @redefines, $self->scenarioOptions()->{redefine2};
    $self->setProperty('redefine',\@redefines);
  }
}

sub compare_autoincrements {
  my ($self, $old_autoinc, $new_autoinc)= @_;
#	say("Comparing auto-increment data between old and new servers...");

  if (not $old_autoinc and not $new_autoinc) {
      say("No auto-inc data for old and new servers, skipping the check");
      return STATUS_OK;
  }
  elsif ($old_autoinc and ref $old_autoinc eq 'ARRAY' and (not $new_autoinc or ref $new_autoinc ne 'ARRAY')) {
      sayError("Auto-increment data for the new server is not available");
      return STATUS_CONTENT_MISMATCH;
  }
  elsif ($new_autoinc and ref $new_autoinc eq 'ARRAY' and (not $old_autoinc or ref $old_autoinc ne 'ARRAY')) {
      sayError("Auto-increment data for the old server is not available");
      return STATUS_CONTENT_MISMATCH;
  }
  elsif (scalar @$old_autoinc != scalar @$new_autoinc) {
      sayError("Different number of tables in auto-incement data. Old server: ".scalar(@$old_autoinc)." ; new server: ".scalar(@$new_autoinc));
      return STATUS_CONTENT_MISMATCH;
  }
  else {
    foreach my $i (0..$#$old_autoinc) {
      my $to = $old_autoinc->[$i];
      my $tn = $new_autoinc->[$i];
#      say("Comparing auto-increment data. Old server: @$to ; new server: @$tn");

      # 0: table name; 1: table auto-inc; 2: column name; 3: max(column)
      if ($to->[0] ne $tn->[0] or $to->[2] ne $tn->[2] or $to->[3] != $tn->[3] or ($tn->[1] != $to->[1] and $tn->[1] != $tn->[3]+1))
      {
        $self->addDetectedBug(13094);
        sayError("Difference found:\n  old server: table $to->[0]; autoinc $to->[1]; MAX($to->[2])=$to->[3]\n  new server: table $tn->[0]; autoinc $tn->[1]; MAX($tn->[2])=$tn->[3]");
        return STATUS_CUSTOM_OUTCOME;
      }
    }
  }
}

1;
