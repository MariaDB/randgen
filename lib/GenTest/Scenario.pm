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
use Constants::MariaDBErrorCodes;
use Data::Dumper;

use constant SC_TEST_PROPERTIES        => 1;
use constant SC_TYPE                   => 3;
use constant SC_DETECTED_BUGS          => 4;
use constant SC_GLOBAL_RESULT          => 5;
use constant SC_SCENARIO_OPTIONS       => 6;
use constant SC_RAND                   => 7;
use constant SC_COMPATIBILITY          => 8;
use constant SC_NUMBER_OF_SERVERS      => 9;
use constant SC_REPORTER_MANAGER       => 10;
use constant SC_TEST_RUNNER            => 11;
use constant SC_COMPATIBILITY_ES       => 12;

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
  $scenario->[SC_COMPATIBILITY_ES]= $scenario->getProperty('compatibility_es') | 0;
  $scenario->backupProperties();
  $scenario->printTitle();
  return $scenario;
}

sub compatibility {
  return $_[0]->[SC_COMPATIBILITY];
}

sub compatibility_es {
  return $_[0]->[SC_COMPATIBILITY_ES];
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

#
# Data collection for consistency checks (in upgrade tests, replication etc.)
#
sub get_data {
  my ($self, $server)= @_;
  my @databases= $server->nonSystemDatabases();
  my $databases= join ',', map { "'".$_."'" } @databases;
  my ($tables, $columns, $indexes, $checksums_unsafe, $checksums_safe);
  $server->connection->execute("SET max_statement_time= 0");
  goto GET_DATA_END if $server->connection->err();

  # We skip auto_increment value due to MDEV-13094 etc.
  $tables= $server->connection->query(
    "SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE, ENGINE, ROW_FORMAT, TABLE_COLLATION, TABLE_COMMENT ".
    "FROM INFORMATION_SCHEMA.TABLES ".
    "WHERE TABLE_SCHEMA IN ($databases)".
    "ORDER BY TABLE_SCHEMA, TABLE_NAME"
  );
  goto GET_DATA_END if $server->connection->err();

  # Workaround for MDEV-28253 -- EXTRA can be wrong on old versions
  my $extra= 'EXTRA';
#  unless (isCompatible('10.3.35,10.4.24,10.5.6,10.6.8,10.7.4',$server->version())) {
#    $extra= 'IF(EXTRA="on update current_timestamp(),","on update current_timestamp(), INVISIBLE",EXTRA)';
#  }
  # Default for virtual columns can be wrong (MDEV-32077)
  # Views don't preserve virtual column attributes, so we select view columns separately (MDEV-32078)
  $columns= $server->connection->query(
    "SELECT c.TABLE_SCHEMA, c.TABLE_NAME, c.COLUMN_NAME, c.ORDINAL_POSITION, IF(c.IS_GENERATED='ALWAYS',NULL,COLUMN_DEFAULT), c.IS_NULLABLE, c.DATA_TYPE, ".
    "CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE, DATETIME_PRECISION, CHARACTER_SET_NAME, COLLATION_NAME, COLUMN_KEY, $extra, PRIVILEGES, COLUMN_COMMENT, IS_GENERATED ".
    "FROM INFORMATION_SCHEMA.COLUMNS c JOIN INFORMATION_SCHEMA.TABLES t ON (t.TABLE_SCHEMA = c.TABLE_SCHEMA AND t.TABLE_NAME = c.TABLE_NAME ) ".
    "WHERE t.TABLE_SCHEMA IN ($databases) AND t.TABLE_TYPE NOT IN ('VIEW','SYSTEM VIEW') ".
    "UNION ".
    "SELECT c.TABLE_SCHEMA, c.TABLE_NAME, c.COLUMN_NAME, c.ORDINAL_POSITION, NULL, c.IS_NULLABLE, c.DATA_TYPE, ".
    "CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE, DATETIME_PRECISION, CHARACTER_SET_NAME, COLLATION_NAME, COLUMN_KEY, NULL, PRIVILEGES, COLUMN_COMMENT, NULL ".
    "FROM INFORMATION_SCHEMA.COLUMNS c JOIN INFORMATION_SCHEMA.TABLES t ON (t.TABLE_SCHEMA = c.TABLE_SCHEMA AND t.TABLE_NAME = c.TABLE_NAME ) ".
    "WHERE t.TABLE_SCHEMA IN ($databases) AND t.TABLE_TYPE IN ('VIEW','SYSTEM VIEW') ".
    "ORDER BY TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME"
  );
  goto GET_DATA_END if $server->connection->err();

  # Before these versions (fix MDEV-16857) row_end is shown in statistics
  if (isCompatible('10.3.31,10.4.21,10.5.12,10.6.4',$self->compatibility,$self->compatibility_es)) {
    $indexes= $server->connection->query(
      "SELECT TABLE_SCHEMA, TABLE_NAME, INDEX_NAME, COLUMN_NAME, NON_UNIQUE, SEQ_IN_INDEX, INDEX_TYPE, COMMENT ".
      "FROM INFORMATION_SCHEMA.STATISTICS ".
      "WHERE TABLE_SCHEMA IN ($databases)".
      "ORDER BY TABLE_SCHEMA, TABLE_NAME, INDEX_NAME, COLUMN_NAME"
    )
  } else {
    $indexes= $server->connection->query(
      "SELECT TABLE_SCHEMA, TABLE_NAME, INDEX_NAME, COLUMN_NAME, NON_UNIQUE, SEQ_IN_INDEX, INDEX_TYPE, COMMENT ".
      "FROM INFORMATION_SCHEMA.STATISTICS ".
      "WHERE TABLE_SCHEMA IN ($databases) AND (COLUMN_NAME != 'row_end' OR (TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME) IN (SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS))".
      "ORDER BY TABLE_SCHEMA, TABLE_NAME, INDEX_NAME, COLUMN_NAME"
    )
  }
  goto GET_DATA_END if $server->connection->err();

  # Double and float make checksum non-deterministic (apparently), regardless the type of the upgrade,
  # so they are always excluded.
  # For dump upgrade before 10.11, historical rows of system versioned tables
  # could not be dumped, so the history was lost and table checksums would differ.
  # Thus we won't compare checksums for versioned tables when older versions are involved.
  # Virtual columns make the checksum non-deterministic (MDEV-32079).
  # Aria tables often have different checksums because they initially
  # preserve wrong create options (row_format, page_checksum), but lose them after dump
  my $table_names_checksum_unsafe= $server->connection->get_value(
      "SELECT GROUP_CONCAT(CONCAT('`',TABLE_SCHEMA,'`.`',TABLE_NAME,'`') ORDER BY 1 SEPARATOR ', ') ".
      "FROM INFORMATION_SCHEMA.TABLES ".
      "WHERE TABLE_SCHEMA IN ($databases) AND TABLE_TYPE = 'SYSTEM VERSIONED' ".
      "AND (TABLE_SCHEMA, TABLE_NAME) NOT IN (SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE DATA_TYPE IN ('double','float') OR IS_GENERATED != 'NEVER' OR ENGINE = 'Aria')"
  );
  goto GET_DATA_END if $server->connection->err();

  my $table_names_checksum_safe= $server->connection->get_value(
      "SELECT GROUP_CONCAT(CONCAT('`',TABLE_SCHEMA,'`.`',TABLE_NAME,'`') ORDER BY 1 SEPARATOR ', ') ".
      "FROM INFORMATION_SCHEMA.TABLES ".
      "WHERE TABLE_SCHEMA IN ($databases) AND TABLE_TYPE != 'SYSTEM VERSIONED' ".
      "AND (TABLE_SCHEMA, TABLE_NAME) NOT IN (SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE DATA_TYPE IN ('double','float') OR IS_GENERATED != 'NEVER' OR ENGINE = 'Aria')"
  );
  goto GET_DATA_END if $server->connection->err();

  if ($table_names_checksum_unsafe) {
    $checksums_unsafe= $server->connection->query("CHECKSUM TABLE $table_names_checksum_unsafe EXTENDED");
  }
  goto GET_DATA_END if $server->connection->err();

  if ($table_names_checksum_safe) {
    $checksums_safe= $server->connection->query("CHECKSUM TABLE $table_names_checksum_safe EXTENDED");
  }
GET_DATA_END:
  return (errorType($server->connection->err()), (tables => $tables, columns => $columns, indexes => $indexes, checksums_safe => $checksums_safe, checksums_unsafe => $checksums_unsafe));
}

#
# Comarison of data collected in get_data (in upgrade tests, replication etc.)
# $type for upgrade tests is a type of upgrade (dump, live, etc.)
# for other tests, just some arbitrary string to put into file names
#

sub compare_data {
  my ($self, $old_data, $new_data, $vardir, $type)= @_;
  my $data_status= STATUS_OK;
  foreach my $d (sort keys %$old_data) {
    next if (($d eq 'checksums_unsafe') and ($type eq 'dump-upgrade'));
    my $old= Dumper $old_data->{$d};
    my $new= Dumper $new_data->{$d};
    # For now we'll just blindly replace all utf8mb3 by utf8
    $old =~ s/utf8mb3/utf8/g;
    $new =~ s/utf8mb3/utf8/g;
    if ($old ne $new) {
      $data_status= STATUS_TEST_FAILURE;
      unless (-e $vardir.'/old_'.$d.'.dump') {
        if (open(DT, '>'.$vardir.'/old_'.$d.'.dump')) {
          print DT $old;
          close(DT);
        } else {
          sayError('Could not write old '.$d." into file: $!");
        }
      }
      if (open(DT, '>'.$vardir.'/'.$type.'_'.$d.'.dump')) {
        print DT $new;
        close(DT);
      } else {
        sayError('Could not write '.$type.' '.$d." into file: $!");
      }
      sayError("Old and new $d differ after $type");
      if (-e $vardir.'/old_'.$d.'.dump' and -e $vardir.'/'.$type.'_'.$d.'.dump') {
        system("diff -a -U20 ".$vardir.'/old_'.$d.'.dump'." ".$vardir.'/'.$type.'_'.$d.'.dump');
      }
    }
  }
  return $data_status;
}

sub createTestRunner {
  my $self= shift;
  $self->backupProperties();
  $self->setProperty('compatibility', $self->[SC_COMPATIBILITY]) unless defined $self->getProperty('compatibility');
  $self->[SC_TEST_RUNNER]= GenTest::TestRunner->new(config => $self->getProperties());
  $self->[SC_REPORTER_MANAGER]= $self->[SC_TEST_RUNNER]->initReporters();
}

sub runTestFlow {
  my $self= shift;
  my $status= $self->[SC_TEST_RUNNER]->run();
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
  my ($crashes, $errors)= $server->checkErrorLogForErrors();
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

sub getStatus {
  return $_[0]->[SC_GLOBAL_RESULT];
}

sub finalize {
  my ($self, $status, $servers)= @_;
  if ($self->[SC_TEST_RUNNER]) {
    $status= $self->[SC_TEST_RUNNER]->reportResults($status);
  }
  if ($servers) {
    foreach my $s (@$servers) {
      next unless $s;
      if ($s->running) {
        say("Stopping the server at port ".$s->port);
        my $shutdown_status= $s->stopServer();
        if ($shutdown_status != STATUS_OK) {
          $s->kill;
          $status= $shutdown_status if $shutdown_status > $status;
        }
      }
      $s->errorLogReport() if $status != STATUS_OK;
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
