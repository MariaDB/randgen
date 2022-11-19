# Copyright (C) 2021, 2022 MariaDB Corporation Ab
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
use GenUtil;
use GenTest;
use GenTest::App::GenTest;
use GenTest::Properties;
use GenTest::Constants;
use GenTest::Scenario;
use GenTest::Scenario::Upgrade;
use Data::Dumper;
use File::Copy;
use File::Compare;

use DBServer::MariaDB;

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

  my $dbh= $server->dbh;

  #####
  $self->printStep("Preparing to discard/import");
  $dbh->do("SET max_statement_time=0");

  say("Getting rid of stale XA transactions");
  $server->rollbackXA();

  my $non_system_databases= join ',', map { "'$_'" } ($server->nonSystemDatabases());

  # Drop all non-InnoDB tables, it will make things simpler
  my $not_interesting_tables = $dbh->selectcol_arrayref("select concat('`',table_schema,'`.`',table_name,'`') from information_schema.tables where table_schema in ($non_system_databases) and table_type = 'VIEW'");
  say("Dropping views @$not_interesting_tables");
  foreach my $v (@$not_interesting_tables) {
    $dbh->do("DROP VIEW $v");
  }
  $not_interesting_tables = $dbh->selectcol_arrayref("select concat('`',table_schema,'`.`',table_name,'`') from information_schema.tables where table_schema in ($non_system_databases) and engine != 'InnoDB'");
  say("Dropping non-innodb tables @$not_interesting_tables");
  foreach my $t (@$not_interesting_tables) {
    $dbh->do("DROP TABLE $t");
  }
  # Drop also partitioned tables, mainly because we don't know how to import their tablespaces
  $not_interesting_tables = $dbh->selectcol_arrayref("select distinct concat('`',table_schema,'`.`',table_name,'`') from information_schema.partitions where partition_name is not null and table_schema in ($non_system_databases)");
  say("Dropping partitioned tables @$not_interesting_tables");
  foreach my $t (@$not_interesting_tables) {
    $dbh->do("DROP TABLE $t");
  }

  #####
  $self->printStep("Creating copies of tables and importing tablespaces");

  $dbh->do("SET GLOBAL innodb_file_per_table= 1");
  # Workaround for MDEV-29960, and anyway mysqldump does it too
  $dbh->do("SET NAMES utf8");

  my $tables = $dbh->selectcol_arrayref("select ts.name from information_schema.innodb_sys_tablespaces ts ".
    "join information_schema.tables t on BINARY ts.name = BINARY concat(t.table_schema,'/',t.table_name) ".
    "where ts.name != 'innodb_system' and ts.name not like 'mysql/%' and ts.name not like '%#%' and t.table_type != 'SEQUENCE' and ts.name not like '%/FTS_0000%'");

  my %databases= ();
  foreach my $tpath (@$tables) {
    $tpath =~ /^(.*)\/(.*)/;
    my ($tschema, $tname)= ($1, $2);
    $databases{$tschema}= 1;

    # Workaround for MDEV-29966 -- invalid default prevents ALTER or CREATE .. LIKE
    ALTERFORCE:
    $dbh->do("ALTER TABLE ${tschema}.${tname} FORCE");
    say("Result of ALTER TABLE $tname FORCE: ".($dbh->err ? $dbh->err.' '.$dbh->errstr : 'OK'));
    if ($dbh->err == 1067 and $dbh->errstr =~ /Invalid default value for '(.*)'/) {
      $dbh->do("ALTER TABLE ${tschema}.${tname} ALTER `$1` DROP DEFAULT");
      if ($dbh->err) {
        sayError("Failed to drop invalid default from ${tschema}.${tname}.${1}: ".$dbh->err." ".$dbh->errstr);
        $status= STATUS_DATABASE_CORRUPTION;
        next;
      } else {
        goto ALTERFORCE;
      }
    } elsif ($dbh->err) {
      sayError("Failed to run ALTER .. FORCE on ${tschema}.${tname}: ".$dbh->err." ".$dbh->errstr);
      $status= STATUS_DATABASE_CORRUPTION;
      next;
    }

    my $tschema_import = $tschema.'_import';
    $dbh->do("CREATE DATABASE IF NOT EXISTS `$tschema_import`");
    if ($dbh->err) {
      sayError("Could not create database ${tschema_import}: ".$dbh->err.": ".$dbh->errstr);
      $status= STATUS_DATABASE_CORRUPTION;
      next;
    }
    $dbh->do("CREATE TABLE `${tschema_import}`.`$tname` LIKE `$tschema`.`$tname`");
    if ($dbh->err) {
      sayError("Could not create table ${tschema_import}.$tname: ".$dbh->err.": ".$dbh->errstr);
      $status= STATUS_DATABASE_CORRUPTION;
      next;
    }
    $dbh->do("ALTER TABLE `${tschema_import}`.`$tname` DISCARD TABLESPACE");
    if ($dbh->err) {
      sayError("Could not discard tablespace of table ${tschema_import}.$tname: ".$dbh->err.": ".$dbh->errstr);
      $status= STATUS_DATABASE_CORRUPTION;
      next;
    }

    $dbh->do("FLUSH TABLE `$tschema`.`$tname` FOR EXPORT");
    if ($dbh->err) {
      sayError("Could not flush table $tschema.$tname for export: ".$dbh->err.": ".$dbh->errstr);
      $status= STATUS_DATABASE_CORRUPTION;
      next;
    }
    copy($server->datadir.'/'.$tpath.'.ibd', $server->datadir.'/'.${tschema_import}.'/');
    copy($server->datadir.'/'.$tpath.'.cfg', $server->datadir.'/'.${tschema_import}.'/');
    $dbh->do("UNLOCK TABLES");
    if ($dbh->err) {
      sayError("Could not unlock tables: ".$dbh->err.": ".$dbh->errstr);
      return $self->finalize($status,[$server]);
    }
    $dbh->do("ALTER TABLE `${tschema_import}`.`$tname` IMPORT TABLESPACE");
    if ($dbh->err) {
      sayError("Could not import tablespace of table ${tschema_import}.$tname: ".$dbh->err.": ".$dbh->errstr);
      $status= STATUS_DATABASE_CORRUPTION;
      next;
    }
  }

  if ($status != STATUS_OK) {
    sayError("Tablespace import failed");
    return $self->finalize(STATUS_UPGRADE_FAILURE,[$server]);
  }

  foreach my $db (keys %databases) {

    #####
    $self->printStep("Dumping data from $db and ${db}_import");

    $server->dumpdb([ $db ], $server->vardir."/server_data_${db}.dump",0,'--no-create-db --skip-triggers');
    $server->normalizeDump($server->vardir."/server_data_${db}.dump");

    $server->dumpdb([ $db.'_import' ], $server->vardir."/server_data_${db}_import.dump",0,'--no-create-db --skip-triggers');
    $server->normalizeDump($server->vardir."/server_data_${db}_import.dump");

    # This is for information purposes
    $server->dumpSchema([ $db ], $server->vardir."/server_schema_${db}.dump");
    $server->dumpSchema([ $db.'_import' ], $server->vardir."/server_scheam_${db}_import.dump");

    #####
    $self->printStep("Comparing data from $db vs ${db}_import");

    $status= compare($server->vardir."/server_data_${db}.dump", $server->vardir."/server_data_${db}_import.dump");
    if ($status != STATUS_OK) {
      sayError("Data in ${db} and {$db}_import differs");
      system('diff -a -u '.$server->vardir."/server_data_${db}.dump".' '.$server->vardir."/server_data_${db}_import.dump");
      $status= STATUS_DATABASE_CORRUPTION;
    }
    else {
      say("Data in $db and ${db}_import dumps appear to be identical");
    }
  }

  if ($status != STATUS_OK) {
    sayError("Data comparison failed");
    return $self->finalize(STATUS_UPGRADE_FAILURE,[$server]);
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
