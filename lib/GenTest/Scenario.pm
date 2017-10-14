# Copyright (C) 2017 MariaDB Corporation Ab
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
@EXPORT = qw();

use strict;
use GenTest;
use GenTest::Constants;
use Data::Dumper;

use constant SCENARIO_PROPERTIES      => 1;
use constant SCENARIO_CURRENT_BASEDIR => 2;
use constant SCENARIO_TYPE            => 3;
use constant SCENARIO_DETECTED_BUGS   => 4;
use constant SCENARIO_GLOBAL_RESULT   => 5;

1;

sub new {
  my $class = shift;

  my $scenario = $class->SUPER::new({
      properties => SCENARIO_PROPERTIES,
      type => SCENARIO_TYPE
  }, @_);

  $scenario->[SCENARIO_DETECTED_BUGS] = {};
  $scenario->[SCENARIO_GLOBAL_RESULT] = STATUS_OK;

  if (!defined $scenario->getProperty('database')) {
    $scenario->setProperty('database','test');
  }
  if (!defined $scenario->getProperty('user')) {
    $scenario->setProperty('user','root');
  }

  return $scenario;
}

sub run {
  die "Default scenario run() called.";
}

sub getTestType {
  return $_[0]->[SCENARIO_TYPE];
}

sub setTestType {
  $_[0]->[SCENARIO_TYPE]= $_[1];
}

sub getTestDuration {
  return $_[0]->getProperty('duration');
}

sub setTestDuration {
  return $_[0]->setProperty('duration',$_[1]);
}

sub getProperties {
  return $_[0]->[SCENARIO_PROPERTIES];
}

sub getProperty {
  return $_[0]->[SCENARIO_PROPERTIES]->{$_[1]};
}

sub setProperty {
  $_[0]->[SCENARIO_PROPERTIES]->{$_[1]}= $_[2];
}

# Scenario can run (consequently or simultaneously) an arbitrary
# number of servers. Each server might potentially have different set
# of options. $server_num indicates which options should be used

sub prepareServer {
  my ($self, $server_num, $opts)= @_;

  my @server_options= ();
  # "Zero" options are applied to all servers
  if ($self->getProperty('mysqld')) {
    push @server_options, @{$self->getProperty('mysqld')};
  }
  if ($self->getProperty('mysqld'.$server_num)) {
    push @server_options, @{$self->getProperty('mysqld'.$server_num)};
  }

  if (!exists $opts->{start_dirty}) {
    $opts->{start_dirty}= 0;
  }
  if (!exists $opts->{general_log}) {
    $opts->{general_log}= 1;
  }
  if (!exists $opts->{valgrind}) {
    $opts->{valgrind}= $self->getProperty('valgrind');
  }
  if (!defined $opts->{port}) {
    $opts->{port}= $self->getProperty('port') + $server_num - 1;
  }
  if (!defined $opts->{user}) {
    $opts->{user}= $self->getProperty('user');
  }
  if (!defined $opts->{basedir}) {
    $opts->{basedir}= $self->getProperty('basedir'.$server_num) || $self->getProperty('basedir');
  }
  if (!defined $opts->{vardir}) {
    $opts->{vardir}= $self->getProperty('vardir'.$server_num) || $self->getProperty('vardir');
  }

  return DBServer::MySQL::MySQLd->new(
                      basedir => $opts->{basedir},
                      vardir => $opts->{vardir},
                      port => $opts->{port},
                      start_dirty => $opts->{start_dirty},
                      valgrind => $opts->{valgrind},
                      server_options => \@server_options,
                      general_log => $opts->{general_log},
                      user => $opts->{user}
              );
  
}

# Scenario can run (consequently or simultaneously) an arbitrary
# number of test flows. Each flow might potentially have different set
# of options. $gentest_num indicates which options should be used

sub prepareGentest {
  my ($self, $gentest_num, $opts)= @_;
  my $config= GenTest::Properties->new();
  
  foreach my $o (keys %$opts) {
    $config->property($o, $opts->{$o});
  }
  
  if (!defined $config->property('database')) {
    $config->property('database', $self->getProperty('database') || 'test');
  }
  if (!defined $config->property('duration')) {
    $config->property('duration', $self->getProperty('duration') || 300);
  }
  # gendata and gendata-advanced will only be used if they specified
  # explicitly for this run
#  if (!defined $config->property('gendata')) {
    #$config->property('gendata', $self->getProperty('gendata'.$gentest_num));
#  }
#  if (!defined $config->property('gendata-advanced')) {
#    $config->property('gendata-advanced', $self->getProperty('gendata-advanced'.$gentest_num));
#  }
  if (!defined $config->property('generator')) {
    $config->property('generator', $self->getProperty('generator') || 'FromGrammar');
  }
  if (!defined $config->property('grammar')) {
    $config->property('grammar', $self->getProperty('grammar'.$gentest_num) || $self->getProperty('grammar'));
  }
  if (!defined $config->property('queries')) {
    $config->property('queries', $self->getProperty('queries') || '100M');
  }
  if (!defined $config->property('reporters')) {
    $config->property('reporters', $self->getProperty('reporters') || ['Backtrace', 'Deadlock']);
  }
  if (!defined $config->property('threads')) {
    $config->property('threads', $self->getProperty('threads'.$gentest_num) || $self->getProperty('threads'));
  }
  if (!defined $config->property('user')) {
    $config->property('user', $self->getProperty('user') || 'root');
  }

  return GenTest::App::GenTest->new(config => $config);
}

sub addDetectedBug {
  my ($self, $bugnum)= @_;
  $self->[SCENARIO_DETECTED_BUGS]->{$bugnum}= (defined $self->[SCENARIO_DETECTED_BUGS]->{$bugnum} ? $self->[SCENARIO_DETECTED_BUGS]->{$bugnum} + 1 : 1);
}

sub detectedBugs {
  my $self= shift;
  return $self->[SCENARIO_DETECTED_BUGS];
}

# Check and parse the error log up to this point,
# and parse for known errors.
# Additional options can be provided. Currently the function recognizes
# - Marker - the check is performed either from the given marker or from the start
# - CrashOnly - if true, non-fatal errors are ignored
sub checkErrorLog {
  my ($self, $server, $opts)= @_;

  my $marker= ($opts ? $opts->{Marker} : undef);
  my $status= STATUS_OK;
  my ($crashes, $errors)= $server->checkErrorLogForErrors($marker);
  my @errors= (($opts && $opts->{CrashOnly}) ? @$crashes : (@$errors, @$crashes));
  foreach (@errors) {
    if (m{\[ERROR\] InnoDB: Corruption: Page is marked as compressed but uncompress failed with error}so) 
    {
        $self->addDetectedBug(13112);
        $status= STATUS_CUSTOM_OUTCOME if $status < STATUS_CUSTOM_OUTCOME;
    }
    elsif (m{void fil_decompress_page.*: Assertion `0' failed}so)
    {
        $self->addDetectedBug(13103);
        # We will only set the status to CUSTOM_OUTCOME if it was previously set to POSSIBLE_FAILURE
        $status= STATUS_CUSTOM_OUTCOME if $status == STATUS_POSSIBLE_FAILURE;
        last;
    }
    elsif (m{InnoDB: Corruption: Page is marked as compressed space:}so)
    {
        # Most likely it is an indication of MDEV-13103, but to make sure, we still need to find the assertion failure.
        # If we find it later, we will set result to STATUS_CUSTOM_OUTCOME.
        # If we don't find it later, we will raise it to STATUS_UPGRADE_FAILURE
        $status= STATUS_POSSIBLE_FAILURE if $status < STATUS_POSSIBLE_FAILURE;
    }
    elsif (m{recv_parse_or_apply_log_rec_body.*Assertion.*offs == .*failed}so)
    {
        $self->addDetectedBug(13101);
        $status= STATUS_CUSTOM_OUTCOME if $status < STATUS_CUSTOM_OUTCOME;
        last;
    }
    elsif (m{Failing assertion: \!memcmp\(FIL_PAGE_TYPE \+ page, FIL_PAGE_TYPE \+ page_zip\-\>data, PAGE_HEADER - FIL_PAGE_TYPE\)}so)
    {
        $self->addDetectedBug(13512);
        $status= STATUS_CUSTOM_OUTCOME if $status < STATUS_CUSTOM_OUTCOME;
        last;
    }
    elsif (m{InnoDB: Assertion failure in thread \d+ in file page0zip\.cc line \d+})
    {
        # Possibly it's MDEV-13247, it can show up if the old version is between 10.1.2 and 10.1.25.
        # We need to check for "Failing assertion: !page_zip_dir_find(page_zip, page_offset(rec))" later
        $status= STATUS_POSSIBLE_FAILURE if $status < STATUS_POSSIBLE_FAILURE;
    }
    elsif (m{Failing assertion: \!page_zip_dir_find\(page_zip, page_offset\(rec\)\)}so)
    {
        # Possibly it's MDEV-13247, it can show up if the old version is between 10.1.2 and 10.1.25.
        # If we've also seen Assertion failure .. in file page0zip.cc, we'll consider it related
        $self->addDetectedBug(13247);
        $status= STATUS_CUSTOM_OUTCOME if $status == STATUS_POSSIBLE_FAILURE;
        last;
    }
    elsif (m{Assertion \`\!is_user_rec \|\| \!leaf \|\| index-\>is_dummy \|\| dict_index_is_ibuf\(index\) \|\| n == n_fields \|\| \(n \>= index->n_core_fields \&\& n \<= index-\>n_fields\)\' failed}so)
    {
        $self->addDetectedBug(14022);
        $status= STATUS_CUSTOM_OUTCOME if $status < STATUS_CUSTOM_OUTCOME;
        last;
    }
    else {
        $status= STATUS_UPGRADE_FAILURE if $status < STATUS_UPGRADE_FAILURE;
    }
  }
  $status= STATUS_UPGRADE_FAILURE if $status == STATUS_POSSIBLE_FAILURE;
  return $status;
}

sub setStatus {
  my ($self, $res)= @_;
  if ($res > $self->[SCENARIO_GLOBAL_RESULT]) {
    $self->[SCENARIO_GLOBAL_RESULT]= $res;
  }
  return $self->[SCENARIO_GLOBAL_RESULT];
}

sub getStatus {
  my $self= shift;
  return $self->[SCENARIO_GLOBAL_RESULT];
}

sub finalize {
  my ($self, $status, $servers)= @_;
  if ($servers) {
    foreach my $s (@$servers) {
      $s->kill;
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
  $title= '=== '.$title.' scenario ===';
  my $filler='';
  foreach (1..length($title)) {
    $filler.='=';
  }
  say("\n$filler");
  say($title);
  say("$filler\n");
  say("");
}

sub printStep {
  my ($self, $step)= @_;
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
