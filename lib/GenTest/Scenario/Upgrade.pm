# Copyright (C) 2017 MariaDB Corporation Ab
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
# The module implements a normal upgrade scenario.
#
# This is the simplest form of upgrade. The test starts the old server,
# executes some flow on it, shuts down the server, starts the new one
# on the same datadir, runs mysql_upgrade if necessary, performs a basic
# data check and executes some more flow.
#
########################################################################

package GenTest::Scenario::Upgrade;

require Exporter;
@ISA = qw(GenTest::Scenario);

use strict;
use DBI;
use GenTest;
use GenTest::App::GenTest;
use GenTest::Properties;
use GenTest::Constants;
use GenTest::Scenario;
use Data::Dumper;
use File::Copy;
use File::Compare;

use DBServer::MySQL::MySQLd;

sub new {
  my $class= shift;
  my $self= $class->SUPER::new(@_);

  if (!defined $self->getProperty('basedir2') or ($self->getProperty('basedir') eq $self->getProperty('basedir2'))) {
    $self->printTitle('Normal restart');
  }
  else {
    $self->printTitle('Normal upgrade');
  }

  if (not defined $self->getProperty('grammar')) {
    $self->setProperty('grammar', 'conf/mariadb/oltp.yy');
  }
  if (not defined $self->getProperty('gendata')) {
    $self->setProperty('gendata', 'conf/mariadb/innodb_upgrade.zz');
  }
  if (not defined $self->getProperty('gendata1')) {
    $self->setProperty('gendata1', $self->getProperty('gendata'));
  }
  if (not defined $self->getProperty('gendata-advanced1')) {
    $self->setProperty('gendata-advanced1', $self->getProperty('gendata-advanced'));
  }
  if (not defined $self->getProperty('threads')) {
    $self->setProperty('threads', 4);
  }
  
  return $self;
}

sub run {
  my $self= shift;
  my ($status, $old_server, $new_server, $gentest, $databases, %table_autoinc);

  $status= STATUS_OK;

  # We can initialize both servers right away, because the second one
  # runs with start_dirty, so it won't bootstrap
  
  $old_server= $self->prepareServer(1,
    {
      vardir => $self->getProperty('vardir'),
      port => $self->getProperty('port'),
      valgrind => 0,
    }
  );
  $new_server= $self->prepareServer(2,
    {
      vardir => $self->getProperty('vardir'),
      port => $self->getProperty('port'),
      start_dirty => 1
    }
  );

  say("-- Old server info: --");
  say($old_server->version());
  $old_server->printServerOptions();
  say("-- New server info: --");
  say($new_server->version());
  $new_server->printServerOptions();
  say("----------------------");

  #####
  $self->printStep("Starting the old server");

  $status= $old_server->startServer;

  if ($status != STATUS_OK) {
    sayError("Old server failed to start");
    return $self->finalize(STATUS_TEST_FAILURE,[]);
  }
  
  #####
  $self->printStep("Generating test data on the old server");

  $gentest= $self->prepareGentest(1,
    {
      duration => int($self->getTestDuration * 2 / 3),
      dsn => [$old_server->dsn($self->getProperty('database'))],
      servers => [$old_server],
      gendata => $self->getProperty('gendata'),
      'gendata-advanced' => $self->getProperty('gendata-advanced'),
    }
  );
  $status= $gentest->doGenData();

  if ($status != STATUS_OK) {
    sayError("Could not generate the test data");
    return $self->finalize(STATUS_TEST_FAILURE,[$old_server]);
  }

  #####
  $self->printStep("Running test flow on the old server");

  $gentest= $self->prepareGentest(1,
    {
      duration => int($self->getTestDuration * 2 / 3),
      dsn => [$old_server->dsn($self->getProperty('database'))],
      servers => [$old_server],
      'start-dirty' => 1,
    }
  );
  $status= $gentest->run();
  
  if ($status != STATUS_OK) {
    sayError("Test flow on the old server failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$old_server]);
  }

  #####
  $self->printStep("Dumping databases from the old server");
  
  $databases= join ' ', $old_server->nonSystemDatabases();
  $old_server->dumpSchema($databases, $old_server->vardir.'/server_schema_old.dump');
  $old_server->normalizeDump($old_server->vardir.'/server_schema_old.dump', 'remove_autoincs');
  $old_server->dumpdb($databases, $old_server->vardir.'/server_data_old.dump');
  $table_autoinc{'old'}= $old_server->collectAutoincrements();
   
  #####
  $self->printStep("Stopping the old server");

  $status= $old_server->stopServer;

  if ($status != STATUS_OK) {
    sayError("Shutdown of the old server failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$old_server]);
  }

  #####
  $self->printStep("Checking the old server log for fatal errors after shutdown");

  $status= $self->checkErrorLog($old_server, {CrashOnly => 1});

  if ($status != STATUS_OK) {
    sayError("Found fatal errors in the log, old server shutdown has apparently failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$old_server]);
  }

  #####
  $self->printStep("Backing up data directory from the old server");

  $old_server->backupDatadir($old_server->datadir."_orig");
  move($old_server->errorlog, $old_server->errorlog.'_orig');

  #####
  $self->printStep("Starting the new server");

  $status= $new_server->startServer;

  if ($status != STATUS_OK) {
    sayError("New server failed to start");
    # Error log might indicate known bugs which will affect the exit code
    $status= $self->checkErrorLog($new_server);
    # ... but even if it's a known error, we cannot proceed without the server
    return $self->finalize($status,[$new_server]);
  }

  #####
  $self->printStep("Checking the server error log for errors after upgrade");

  $status= $self->checkErrorLog($new_server);

  if ($status != STATUS_OK) {
    # Error log can show known errors. We want to update
    # the global status, but don't want to exit prematurely
    $self->setStatus($status);
    sayError("Found errors in the log after upgrade");
    if ($status > STATUS_CUSTOM_OUTCOME) {
      return $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]);
    }
  }

  #####
  if ($old_server->majorVersion ne $new_server->majorVersion) {
    $self->printStep("Running mysql_upgrade");
    $status= $new_server->upgradeDb;
    if ($status != STATUS_OK) {
      sayError("mysql_upgrade failed");
      return $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]);
    }
  }
  else {
    $self->printStep("mysql_upgrade is skipped, as servers have the same major version");
  }

  #####
  $self->printStep("Checking the database state after upgrade");

  $status= $new_server->checkDatabaseIntegrity;

  if ($status != STATUS_OK) {
    sayError("Database appears to be corrupt after upgrade");
    return $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]);
  }
  
  #####
  $self->printStep("Dumping databases from the new server");
  
  $new_server->dumpSchema($databases, $new_server->vardir.'/server_schema_new.dump');
  $new_server->normalizeDump($new_server->vardir.'/server_schema_new.dump', 'remove_autoincs');
  $new_server->dumpdb($databases, $new_server->vardir.'/server_data_new.dump');
  $table_autoinc{'new'} = $new_server->collectAutoincrements();

  #####
  $self->printStep("Running test flow on the new server");

  $gentest= $self->prepareGentest(2,
    {
      duration => int($self->getTestDuration / 3),
      dsn => [$new_server->dsn($self->getProperty('database'))],
      servers => [$new_server],
      'start-dirty' => 1,
    }
  );
  $status= $gentest->run();

  if ($status != STATUS_OK) {
    sayError("Test flow on the new server failed");
    return $self->finalize($status,[$new_server])
  }

  #####
  $self->printStep("Stopping the new server");

  $status= $new_server->stopServer;

  if ($status != STATUS_OK) {
    sayError("Shutdown of the new server failed");
    return $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]);
  }

  #####
  $self->printStep("Comparing databases before and after upgrade");
  
  $status= compare($new_server->vardir.'/server_schema_old.dump', $new_server->vardir.'/server_schema_new.dump');
  if ($status != STATUS_OK) {
    sayError("Database structures differ after upgrade");
    return $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]);
  }
  else {
    say("Structure dumps appear to be identical");
  }
  
  $status= compare($new_server->vardir.'/server_data_old.dump', $new_server->vardir.'/server_data_new.dump');
  if ($status != STATUS_OK) {
    sayError("Data differs after upgrade");
    return $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]);
  }
  else {
    say("Data dumps appear to be identical");
  }
  
  $status= $self->_compare_autoincrements($table_autoinc{old}, $table_autoinc{new});
  if ($status != STATUS_OK) {
    # Comaring auto-increments can show known errors. We want to update 
    # the global status, but don't want to exit prematurely
    $self->setStatus($status);
    sayError("Auto-increment data differs after upgrade");
    if ($status > STATUS_CUSTOM_OUTCOME) {
      return $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]);
    }
  }
  else {
    say("Auto-increment data appears to be identical");
  }

  return $self->finalize($status,[]);
}

sub _compare_autoincrements {
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
