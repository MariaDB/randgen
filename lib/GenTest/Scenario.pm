# Copyright (C) 2017, 2020 MariaDB Corporation Ab
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

use constant SC_TEST_PROPERTIES        => 1;
use constant SC_CURRENT_BASEDIR        => 2;
use constant SC_TYPE                   => 3;
use constant SC_DETECTED_BUGS          => 4;
use constant SC_GLOBAL_RESULT          => 5;
use constant SC_SCENARIO_OPTIONS       => 6;
use constant SC_PROPERTIES_BACKUP      => 7;

1;

sub new {
  my $class = shift;

  my $scenario = $class->SUPER::new({
      properties => SC_TEST_PROPERTIES,
      scenario_options => SC_SCENARIO_OPTIONS
  }, @_);

  $scenario->[SC_DETECTED_BUGS] = {};
  $scenario->[SC_GLOBAL_RESULT] = STATUS_OK;

  if ($scenario->[SC_SCENARIO_OPTIONS] and defined $scenario->[SC_SCENARIO_OPTIONS]->{type}) {
    $scenario->setTestType($scenario->[SC_SCENARIO_OPTIONS]->{type});
  }
  $scenario->backupProperties();
  return $scenario;
}

sub run {
  die "Default scenario run() called.";
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

sub getTestDuration {
  return $_[0]->getProperty('duration');
}

sub setTestDuration {
  return $_[0]->setProperty('duration',$_[1]);
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
    $new_opts{$o}= $self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum1}->{$o};
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

sub generate_data {
  my $self= shift;
  $self->setProperty('duration',3600);
  $self->setProperty('queries',0);
  $self->setProperty('threads',1);
  $self->setProperty('reporters','None');
  my $gentest= GenTest::App::GenTest->new(config => $self->getProperties());
  my $status= $gentest->run();
  $self->restoreProperties();
  return $status;
}

sub run_test_flow {
  my $self= shift;
  $self->unsetProperty('gendata');
  $self->unsetProperty('gendata-advanced');
  my $gentest= GenTest::App::GenTest->new(config => $self->getProperties());
  my $status= $gentest->run();
  $self->restoreProperties();
  return $status;
}

# Scenario can run (consequently or simultaneously) an arbitrary
# number of servers. Each server might potentially have different set
# of options. $srvnum indicates which options should be used

sub prepareServer {
  my ($self, $srvnum, $start_dirty)= @_;

  my $server= DBServer::MySQL::MySQLd->new(
                      basedir => $self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum}->{basedir},
                      vardir => $self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum}->{vardir},
                      port => $self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum}->{port},
                      start_dirty => $start_dirty || 0,
                      valgrind => $self->[SC_TEST_PROPERTIES]->valgrind,
                      valgrind_options => ($self->[SC_TEST_PROPERTIES]->valgrind_options ? \@{$self->[SC_TEST_PROPERTIES]->valgrind_options} : []),
                      rr => $self->[SC_TEST_PROPERTIES]->rr,
                      server_options => [ @{$self->[SC_TEST_PROPERTIES]->server_specific->{$srvnum}->{mysqld_options}} ],
                      general_log => 1,
                      config => $self->[SC_TEST_PROPERTIES]->cnf_array_ref,
                      user => $self->[SC_TEST_PROPERTIES]->user
              );

  $self->setServerSpecific($srvnum,'dsn',$server->dsn($self->getProperty('database'),$self->getProperty('user')));
  $self->setServerSpecific($srvnum,'server',$server);
  return $server;
}



# Scenario can run (consequently or simultaneously) an arbitrary
# number of test flows. Each flow might potentially have different set
# of options. $gentest_num indicates which options should be used

#  my $props= $self->getProperties;
#  $props->{duration}= int($self->getTestDuration * 2 / 3);
#  $props->{server}= [$old_server];
#  my $gentestProps = GenTest::Properties->init($props);

sub prepareGentest {
  my ($self, $gentest_num, $opts)= @_;
  
  my $config= $self->getProperties;
#  foreach my $p (keys %$props) {
#    if ($p =~ /^([-\w]+)$gentest_num/) {
#      $props->{$1}= $props->{$p};
#    }
#    if ($skip_gendata and $p =~ /^gendata/) {
#      delete $props->{$p};
#    }
#  }

#  my $config= GenTest::Properties->init($self->getProperties);

#  foreach my $o (keys %$opts) {
#    $config->property($o, $opts->{$o});
#  }

#  if (not $config->property('gendata') and not $config->property('gendata-advanced') and not $config->property('grammar')) {
#    say("Neither gendata nor grammar are configured for this gentest, skipping");
#    return undef;
#  }

# my $gentestProps = GenTest::Properties->init($props);
# my $gentest = GenTest::App::GenTest->new(config => $gentestProps);
# my $gentest_result = $gentest->run();
# say("GenTest exited with exit status ".status2text($gentest_result)." ($gentest_result)");

  # Set hard defaults for missing values
#  $config->property('database', 'test') if !defined $config->property('database');
#  $config->property('duration', 300) if !defined $config->property('duration');
#  $config->property('generator', 'FromGrammar') if !defined $config->property('generator');
#  $config->property('queries', '1000M') if !defined $config->property('queries');
#  $config->property('reporters', ['Backtrace', 'Deadlock']) if !defined $config->property('reporters');
#  $config->property('user', 'root') if !defined $config->property('user');
#  $config->property('strict_fields', 1);

  # gendata and gendata-advanced will only be used if they specified
  # explicitly for this run
#  if (!defined $config->property('gendata')) {
    #$config->property('gendata', $self->getProperty('gendata'.$gentest_num));
#  }
#  if (!defined $config->property('gendata-advanced')) {
#    $config->property('gendata-advanced', $self->getProperty('gendata-advanced'.$gentest_num));
#  }

  return GenTest::App::GenTest->new(config => $config);
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
# Assertion `id == 0 || id > trx_id' failed
    elsif (m{Assertion \`id == 0 \|\| id \> trx_id\' failed}so)
    {
        $self->addDetectedBug(13820);
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
  if ($res > $self->[SC_GLOBAL_RESULT]) {
    $self->[SC_GLOBAL_RESULT]= $res;
  }
  return $self->[SC_GLOBAL_RESULT];
}

sub getStatus {
  my $self= shift;
  return $self->[SC_GLOBAL_RESULT];
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
