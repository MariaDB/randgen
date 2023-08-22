# Copyright (C) 2017, 2022, MariaDB Corporation Ab
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

package GenTest::Scenario;

require Exporter;
@ISA = qw(GenTest Exporter);
@EXPORT = qw(SC_GALERA_DEFAULT_LISTEN_PORT);

use strict;
use GenUtil;
use GenTest;
use Constants;
use Data::Dumper;

use constant SC_TEST_PROPERTIES        => 1;
use constant SC_TYPE                   => 3;
use constant SC_DETECTED_BUGS          => 4;
use constant SC_GLOBAL_RESULT          => 5;
use constant SC_SCENARIO_OPTIONS       => 6;
use constant SC_RAND                   => 7;
use constant SC_COMPATIBILITY          => 8;
use constant SC_NUMBER_OF_SERVERS      => 9;

use constant SC_GALERA_DEFAULT_LISTEN_PORT =>  4800;

1;

sub new {
  my $class = shift;

  my $scenario = $class->SUPER::new({
      properties => SC_TEST_PROPERTIES,
      scenario_options => SC_SCENARIO_OPTIONS
  }, @_);

  $scenario->[SC_DETECTED_BUGS] = {};
  $scenario->[SC_GLOBAL_RESULT] = STATUS_OK;
  $scenario->[SC_RAND]= GenTest::Random->new(seed => $scenario->getProperty('seed'));

  if ($scenario->[SC_SCENARIO_OPTIONS] and defined $scenario->[SC_SCENARIO_OPTIONS]->{type}) {
    $scenario->setTestType($scenario->[SC_SCENARIO_OPTIONS]->{type});
  }
  $scenario->[SC_COMPATIBILITY]= $scenario->getProperty('compatibility') | '000000';
  $scenario->backupProperties();
  $scenario->printTitle();
  return $scenario;
}

# Checks min/max number of servers for the scenario, removes gaps
# in server configuration and fixes the counts when possible
sub numberOfServers {
  my ($self, $min, $max)= @_;
  if (defined $min or defined $max) {
    my @servers= sort keys %{$self->getProperty('server_specific')};
    my $server_specific= {};
    foreach my $i (0..$#servers) {
      $server_specific->{$i+1}= $self->getProperty('server_specific')->{$servers[$i]};
    }
    $self->setProperty('server_specific',$server_specific);
    if (defined $max and scalar(@servers)>$max) {
      sayWarning(scalar(@servers)." servers configured, but only up to $max can be used, ignoring the rest");
    } elsif (defined $min and scalar(@servers)<$min) {
      sayWarning(scalar(@servers)." servers configured, but at least $min needed, cloning the first server");
      foreach my $i ($min - scalar(@servers)..$min) {
        $self->copyServerSpecific(1,$i);
      }
    }
    $self->[SC_NUMBER_OF_SERVERS]= ((defined $max and scalar(keys %{$self->getProperty('server_specific')}) > $max) ? $max : scalar(keys %{$self->getProperty('server_specific')}));
  }
  return $self->[SC_NUMBER_OF_SERVERS];
}

sub run {
  die "Default scenario run() called.";
}

sub prng {
  return $_[0]->[SC_RAND];
}

sub backupProperties {
  $_[0]->[SC_TEST_PROPERTIES]->backupProperties();
}

sub getTestType {
  return $_[0]->[SC_TYPE];
}

sub setTestType {
  $_[0]->[SC_TYPE]= $_[1];
}

sub getProperties {
  return $_[0]->[SC_TEST_PROPERTIES];
}

sub getProperty {
  return $_[0]->[SC_TEST_PROPERTIES]->property($_[1]);
}

sub setProperty {
  $_[0]->[SC_TEST_PROPERTIES]->property($_[1], $_[2]);
}

sub unsetProperty {
  $_[0]->[SC_TEST_PROPERTIES]->unsetProperty($_[1]);
}

sub restoreProperties {
  $_[0]->[SC_TEST_PROPERTIES]->restoreProperties();
}

sub scenarioOptions {
  return $_[0]->[SC_SCENARIO_OPTIONS];
}

sub setServerSpecific {
  my ($self, $srvnum, $option, $value)= @_;
  $self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum}->{$option}= $value;
}

sub copyServerSpecific {
  my ($self, $srvnum1, $srvnum2)= @_;
  my %new_opts= ();
  foreach my $o ( keys %{$self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum1}} ) {
    if (ref $self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum1}->{$o} eq '') {
      $new_opts{$o}= $self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum1}->{$o};
    } elsif (ref $self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum1}->{$o} eq 'ARRAY') {
      $new_opts{$o}= [ @{$self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum1}->{$o}} ];
    } elsif (ref $self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum1}->{$o} eq 'HASH') {
      $new_opts{$o}= { %{$self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum1}->{$o}} };
    }
  }
  $self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum2}= { %new_opts };
}

sub getServerSpecific {
  my ($self, $srvnum, $option)= @_;
  if ($option) {
    return $self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum}->{$option};
  } else {
    return $self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum}
  }
}

sub getServerStartupOption {
  my ($self, $srvnum, $option)= @_;
  my $option_search= $option;
  $option_search=~ s/[-_]/[-_]/g;
  my $server_options= $self->getServerSpecific($srvnum, 'mysqld');
  my $val= undef;
  if ($server_options) {
    foreach my $o (@$server_options) {
      # an option can be provided more than once, so we have to go through the whole list
      # TODO: add logic for options which can be provided multiple times,
      #       e.g. --plugin-load-add etc.
      if ($o =~ /^--(?:loose-)?$option_search=(.*)$/) {
        $val= $1;
      } elsif ($o =~ /^--(?:loose-)?$option_search$/) {
        $val= 1;
      } elsif ($o =~ /^--(?:skip-)?$option_search$/) {
        $val= 0;
      }
    }
  }
  return $val;
}

sub setServerStartupOption {
  my ($self, $srvnum, $option, $value)= @_;
  $option=~ s/\_/-/g;
  my $server_options= $self->getServerSpecific($srvnum, 'mysqld');
  $server_options= [] unless $server_options;
  if (defined $value) {
    push @$server_options, "--$option=$value";
  } else {
    push @$server_options, "--$option";
  }
  $self->setServerSpecific($srvnum, 'mysqld', [ @$server_options ]);
}

sub generateData {
  my $self= shift;
  # Server number may be undefined, doGenData will handle it
  my $server_num= shift;
  my $status= GenData::doGenData($self->[SC_TEST_PROPERTIES], $server_num);
  if ($status >= STATUS_CRITICAL_FAILURE) {
    sayError("Data generation failed with ".status2text($status));
    return $status;
  } elsif ($status != STATUS_OK) {
    sayWarning("Data generation failed with ".status2text($status));
  }
  return STATUS_OK;
}

sub runTestFlow {
  my $self= shift;
  $self->backupProperties();
  $self->setProperty('compatibility', $self->[SC_COMPATIBILITY]) unless defined $self->setProperty('compatibility');
  my $gentest= GenTest::TestRunner->new(config => $self->getProperties());
  my $status= $gentest->run();
  $self->restoreProperties();
  return $status;
}

# Scenario can run (consequently or simultaneously) an arbitrary
# number of servers. Each server might potentially have different set
# of options. $srvnum indicates which options should be used.
# $is_active indicates whether the server should be receiving test flow

sub prepareServer {
  my ($self, $srvnum, $is_active)= @_;

  say("Preparing server $srvnum");

  my $server= DBServer::MariaDB->new(
                      basedir => $self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum}->{basedir},
                      config => $self->[SC_TEST_PROPERTIES]->cnf,
                      general_log => 1,
                      manual_gdb => $self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum}->{manual_gdb},
                      port => ($self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum}->{port} || $self->[SC_TEST_PROPERTIES]->base_port + $srvnum - 1),
                      rr => $self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum}->{rr},
                      perf => $self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum}->{perf},
                      ps => $self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum}->{ps},
                      server_options => [ @{$self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum}->{mysqld}} ],
                      start_dirty => $self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum}->{start_dirty} || 0,
                      user => $self->[SC_TEST_PROPERTIES]->user,
                      valgrind => $self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum}->{valgrind},
                      vardir => ($self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum}->{vardir} || $self->[SC_TEST_PROPERTIES]->vardir.'/s'.$srvnum),
              );
  $self->setServerSpecific($srvnum,'active',($is_active || 0));
  $self->setServerSpecific($srvnum,'server',$server);
  $self->[SC_COMPATIBILITY] = $server->version() if isNewerVersion($server->version(),$self->[SC_COMPATIBILITY]);
  return $server;
}

sub addDetectedBug {
  my ($self, $bugnum)= @_;
  $self->[SC_DETECTED_BUGS]->{$bugnum}= (defined $self->[SC_DETECTED_BUGS]->{$bugnum} ? $self->[SC_DETECTED_BUGS]->{$bugnum} + 1 : 1);
}

sub detectedBugs {
  my $self= shift;
  return $self->[SC_DETECTED_BUGS];
}

# Check and parse the error log up to this point,
# and parse for known errors.
# Additional options can be provided. Currently the function recognizes
# - Marker - the check is performed either from the given marker or from the start
sub checkErrorLog {
  my ($self, $server, $opts)= @_;

  my $marker= ($opts ? $opts->{Marker} : undef);
  my $status= STATUS_OK;
  my ($crashes, $errors)= $server->checkErrorLogForErrors($marker);
  if (scalar(@$crashes)) {
    $status= STATUS_SERVER_CRASHED;
  } elsif (scalar(@$errors)) {
    $status= STATUS_ERRORS_IN_LOG;
  }
  return $status;
}

sub setStatus {
  my ($self, $res)= @_;
  if ($res > $self->[SC_GLOBAL_RESULT]) {
    $self->[SC_GLOBAL_RESULT]= $res;
  }
  return $self->[SC_GLOBAL_RESULT];
}

sub finalize {
  my ($self, $status, $servers)= @_;
  if ($servers) {
    foreach my $s (@$servers) {
      if ($s->stopServer() != STATUS_OK) {
        $s->kill
      }
    }
  }
  if (scalar (keys %{$self->detectedBugs})) {
    my $bugs= $self->detectedBugs;
    my @bugs= map { 'MDEV-'. $_ . '('.$bugs->{$_}.')' } keys %$bugs;
    say("Detected possible appearance of known bugs: @bugs");
  }
  return $self->setStatus($status);
}

sub printTitle {
  my ($self, $title)= @_;
  ($title= ref $self) =~ s/.*::// unless $title;
  if ($title =~ /^(\w)(.*)/) {
    $title= uc($1).$2;
  }
  $title= '=== '.$title.' scenario ===';
  my $filler='';
  foreach (1..length($title)) {
    $filler.='=';
  }
  say("\n$filler");
  say($title);
  say("$filler");
}
sub printSubtitle {
  my ($self, $title)= @_;
  ($title= ref $self) =~ s/.*::// unless $title;
  if ($title =~ /^(\w)(.*)/) {
    $title= uc($1).$2;
  }
  $title= '- '.$title.' -';
  my $filler='';
  foreach (1..length($title)) {
    $filler.='=';
  }
  say("$filler");
  say($title);
  say("$filler\n");
  say("");
}

sub printStep {
  my ($self, $step)= @_;
  if ($step =~ /^(\w)(.*)/) {
    $step= uc($1).$2;
  }
  $step= "-- $step --";
  my $filler='';
  foreach (1..length($step)) {
    $filler.='-';
  }
  say("#$filler#");
  say("#$step#");
  say("#$filler#");
}

sub configure {
  return 1;
}

1;
