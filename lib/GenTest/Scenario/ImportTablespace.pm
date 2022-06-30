# Copyright (C) 2021 MariaDB Corporation Ab
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
# The module implements discard/import tablespace scenario.
#
# The test starts the old server,executes some flow on it,
# waits till it ends, dumps the schema and data for further comparison,
# stores all definitions and tablespaces of existing InnoDB tables,
# drops the tables, re-creates them, discards/imports tablespaces,
# dumps the schema and data again and checks the consistency.
#
# TODO: Lift limitation for partitioned tables
#
########################################################################

package GenTest::Scenario::ImportTablespace;

require Exporter;
@ISA = qw(GenTest::Scenario::Upgrade);

use strict;
use DBI;
use GenTest;
use GenTest::App::GenTest;
use GenTest::Properties;
use GenTest::Constants;
use GenTest::Scenario;
use GenTest::Scenario::Upgrade;
use Data::Dumper;
use File::Copy;
use File::Compare;

use DBServer::MySQL::MySQLd;

sub new {
  my $class= shift;
  my $self= $class->SUPER::new(@_);

  $self->printTitle('Discard/Import Tablespace');
  return $self;
}

sub run {
  my $self= shift;
  my ($status, $server, $databases, %table_autoinc);

  $status= STATUS_OK;

  #####
  # Prepare servers

  $server= $self->prepare_servers();

  #####
  $self->printStep("Starting the server");

  $status= $server->startServer;

  if ($status != STATUS_OK) {
    sayError("The server failed to start");
    return $self->finalize(STATUS_TEST_FAILURE,[]);
  }

  #####
  $self->printStep("Generating data");

  $status= $self->generate_data();

  if ($status != STATUS_OK) {
    sayError("Data generation failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$server]);
  }

  #####
  $self->printStep("Running the test flow");

  $self->setProperty('duration',int($self->getProperty('duration')*4/5));
  $status= $self->run_test_flow();

  if ($status != STATUS_OK) {
    sayError("Initial test flow failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$server]);
  }

  #####
  $self->printStep("Dumping the data before discard/import");

  $databases= join ' ', $server->nonSystemDatabases();
  $server->dumpSchema($databases, $server->vardir.'/server_schema_old.dump');
  $server->normalizeDump($server->vardir.'/server_schema_old.dump', 'remove_autoincs');
  $server->dumpdb($databases, $server->vardir.'/server_data_old.dump');
  $server->normalizeDump($server->vardir.'/server_data_old.dump');
  $table_autoinc{'old'}= $server->collectAutoincrements();

  #####
  $self->printStep("Storing tablespaces for InnoDB tables and dropping the tables");

  my $dbh= $server->dbh;

  $dbh->do("SET GLOBAL innodb_file_per_table= 1");
  $dbh->do("SET foreign_key_checks= 0");

  my $tablespace_backup_dir= $server->vardir.'/tablespaces';
  mkdir($tablespace_backup_dir);
  my %table_definitions;

  my $tables = $dbh->selectcol_arrayref("select `name` from information_schema.innodb_sys_tablespaces where name != 'innodb_system' and name not like 'mysql/%' and name not like '%#%'");
  foreach my $tpath (@$tables) {
    $tpath =~ /^(.*)\/(.*)/;
    my ($tschema, $tname)= ($1, $2);
    mkdir($tablespace_backup_dir.'/'.$tschema) unless (-d $tablespace_backup_dir.'/'.$tschema);
    $dbh->do("USE $tschema");
    $dbh->do("FLUSH TABLES `$tname` FOR EXPORT");
    if ($dbh->err) {
      sayError("Could not flush table $tname for export: ".$dbh->err.": ".$dbh->errstr);
      return $self->finalize(STATUS_DATABASE_CORRUPTION,[$server]);
    }
    my $tdef = $dbh->selectcol_arrayref("SHOW CREATE TABLE `$tname`", { Columns=>[2] });
    $table_definitions{$tpath}= $tdef->[0];
    if ($dbh->err) {
      sayError("Could not run SHOW CREATE TABLE $tname: ".$dbh->err.": ".$dbh->errstr);
      return $self->finalize(STATUS_DATABASE_CORRUPTION,[$server]);
    }
    copy($server->datadir.'/'.$tpath.'.ibd', $tablespace_backup_dir.'/'.$tschema.'/');
    copy($server->datadir.'/'.$tpath.'.cfg', $tablespace_backup_dir.'/'.$tschema.'/');
    $dbh->do("UNLOCK TABLES");
    $dbh->do("DROP TABLE $tname");
    if ($dbh->err) {
      sayError("Could not drop table $tname: ".$dbh->err.": ".$dbh->errstr);
      return $self->finalize(STATUS_DATABASE_CORRUPTION,[$server]);
    }
  }

  #####
  $self->printStep("Re-creating the tables and replacing tablespaces with the stored ones");

  foreach my $tpath (@$tables) {
    $tpath =~ /^(.*)\/(.*)/;
    my ($tschema, $tname)= ($1, $2);
    $dbh->do("USE $tschema");
    $dbh->do($table_definitions{$tpath});
    $dbh->do("ALTER TABLE $tname DISCARD TABLESPACE");
    if ($dbh->err) {
      sayError("Could not discard tablespace for $tname: ".$dbh->err.": ".$dbh->errstr);
      return $self->finalize(STATUS_DATABASE_CORRUPTION,[$server]);
    }
    copy("$tablespace_backup_dir/".$tpath.'.ibd', $server->datadir.'/'.$tpath.'.ibd');
    copy("$tablespace_backup_dir/".$tpath.'.cfg', $server->datadir.'/'.$tpath.'.cfg');
    $dbh->do("ALTER TABLE $tname IMPORT TABLESPACE");
    if ($dbh->err) {
      sayError("Could not import tablespace for $tname: ".$dbh->err.": ".$dbh->errstr);
      return $self->finalize(STATUS_DATABASE_CORRUPTION,[$server]);
    }
  }

  #####
  $self->printStep("Dumping the data after discard/import");

  $databases= join ' ', $server->nonSystemDatabases();
  $server->dumpSchema($databases, $server->vardir.'/server_schema_new.dump');
  $server->normalizeDump($server->vardir.'/server_schema_new.dump', 'remove_autoincs');
  $server->dumpdb($databases, $server->vardir.'/server_data_new.dump');
  $server->normalizeDump($server->vardir.'/server_data_new.dump');
  $table_autoinc{'new'}= $server->collectAutoincrements();


  #####
  $self->printStep("Comparing databases before and after discard/import");

  $status= compare($server->vardir.'/server_schema_old.dump', $server->vardir.'/server_schema_new.dump');
  if ($status != STATUS_OK) {
    sayError("Database structures differ after upgrade");
    system('diff -a -u '.$server->vardir.'/server_schema_old.dump'.' '.$server->vardir.'/server_schema_new.dump');
    return $self->finalize(STATUS_UPGRADE_FAILURE,[$server]);
  }
  else {
    say("Structure dumps appear to be identical");
  }

  $status= compare($server->vardir.'/server_data_old.dump', $server->vardir.'/server_data_new.dump');
  if ($status != STATUS_OK) {
    sayError("Data differs after upgrade");
    system('diff -a -u '.$server->vardir.'/server_data_old.dump'.' '.$server->vardir.'/server_data_new.dump');
    return $self->finalize(STATUS_UPGRADE_FAILURE,[$server]);
  }
  else {
    say("Data dumps appear to be identical");
  }

  $status= $self->compare_autoincrements($table_autoinc{old}, $table_autoinc{new});
  if ($status != STATUS_OK) {
    # Comaring auto-increments can show known errors. We want to update
    # the global status, but don't want to exit prematurely
    $self->setStatus($status);
    sayError("Auto-increment data differs after discard/import");
    if ($status > STATUS_CUSTOM_OUTCOME) {
      return $self->finalize(STATUS_UPGRADE_FAILURE,[$server]);
    }
  }
  else {
    say("Auto-increment data appears to be identical");
  }

  #####
  $self->printStep("Stopping the server");

  $status= $server->stopServer;

  if ($status != STATUS_OK) {
    sayError("Server shutdown failed");
    return $self->finalize(STATUS_UPGRADE_FAILURE,[$server]);
  }

  return $self->finalize($status,[]);
}

1;
