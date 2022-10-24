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

  my $dbh= $server->dbh;

  #####
  $self->printStep("Preparing to discard/import");
  # Drop all non-InnoDB tables, it will make things simpler
  my $non_innodb_tables = $dbh->selectcol_arrayref("select concat('`',table_schema,'`.`',table_name,'`') from information_schema.tables where table_schema not in ('mysql','information_schema','performance_schema','sys') and table_type = 'VIEW'");
  say("Dropping views @$non_innodb_tables");
  foreach my $v (@$non_innodb_tables) {
    $dbh->do("DROP VIEW $v");
  }
  $non_innodb_tables = $dbh->selectcol_arrayref("select concat('`',table_schema,'`.`',table_name,'`') from information_schema.tables where table_schema not in ('mysql','information_schema','performance_schema','sys') and engine != 'InnoDB'");
  say("Dropping tables @$non_innodb_tables");
  foreach my $t (@$non_innodb_tables) {
    $dbh->do("DROP TABLE $t");
  }
  say("Getting rid of stale XA transactions");
  $server->rollbackXA();

  #####
  $self->printStep("Dumping the remaining data before discard/import");

  $databases= join ' ', $server->nonSystemDatabases();
  $server->dumpdb($databases, $server->vardir.'/server_data_old.dump');
  $server->normalizeDump($server->vardir.'/server_data_old.dump');
  $self->printStep("Storing tablespaces for InnoDB tables and dropping the tables");
  # This is for information purposes
  $server->dumpSchema($databases, $server->vardir.'/server_schema_old.dump');


  $dbh->do("SET GLOBAL innodb_file_per_table= 1");
  $dbh->do("SET foreign_key_checks= 0");

  my $tablespace_backup_dir= $server->vardir.'/tablespaces';
  mkdir($tablespace_backup_dir);
  my %table_definitions;

  my $tables = $dbh->selectcol_arrayref("select ts.name from information_schema.innodb_sys_tablespaces ts join information_schema.tables t on BINARY ts.name = BINARY concat(t.table_schema,'/',t.table_name) where ts.name != 'innodb_system' and ts.name not like 'mysql/%' and ts.name not like '%#%' and t.table_type != 'SEQUENCE'");
  foreach my $tpath (@$tables) {
    $tpath =~ /^(.*)\/(.*)/;
    my ($tschema, $tname)= ($1, $2);
    next if $tname =~ /^FTS_0000/;
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
      sleep(3600);
      return $self->finalize(STATUS_DATABASE_CORRUPTION,[$server]);
    }
  }

  #####
  $self->printStep("Re-creating the tables and replacing tablespaces with the stored ones");
  $dbh->do('SET FOREIGN_KEY_CHECKS= 0, ENFORCE_STORAGE_ENGINE= NULL, sql_mode= CONCAT(REPLACE(REPLACE(@@sql_mode,"STRICT_TRANS_TABLES",""),"STRICT_ALL_TABLES",""),",IGNORE_BAD_TABLE_OPTIONS")');
  foreach my $tpath (@$tables) {
    $tpath =~ /^(.*)\/(.*)/;
    my ($tschema, $tname)= ($1, $2);
    $dbh->do("USE $tschema");
    my $def= $table_definitions{$tpath};
    $dbh->do($def);
    if ($dbh->err) {
      sayError("Could not re-create table $tschema.$tname: ".$dbh->err.": ".$dbh->errstr);
      $status= STATUS_DATABASE_CORRUPTION;
      next;
    }
    # Workaround for MDEV-29001: adjust null-able columns which lost their DEFAULT NULL clause
    while ($def =~ s/^(.*)?\n//) {
      my $l= $1;
      if ($l =~ /^\s+(\`.*?\`)/ && $l !~ /(?:NOT NULL|DEFAULT)/) {
        my $colname= $1;
        $dbh->do("ALTER TABLE $tname ALTER COLUMN $colname DROP DEFAULT");
        if ($dbh->err) {
          sayError("Could not drop default from $tname.$colname : ".$dbh->err.": ".$dbh->errstr);
          $status= STATUS_DATABASE_CORRUPTION;
          next;
        }
      }
    }
    $dbh->do("ALTER TABLE $tname DISCARD TABLESPACE");
    if ($dbh->err) {
      sayError("Could not discard tablespace for $tname: ".$dbh->err.": ".$dbh->errstr);
      $status= STATUS_DATABASE_CORRUPTION;
      next;
    }
    copy("$tablespace_backup_dir/".$tpath.'.ibd', $server->datadir.'/'.$tpath.'.ibd');
    copy("$tablespace_backup_dir/".$tpath.'.cfg', $server->datadir.'/'.$tpath.'.cfg');
    $dbh->do("ALTER TABLE $tname IMPORT TABLESPACE");
    if ($dbh->err) {
      sayError("Could not import tablespace for $tname: ".$dbh->err.": ".$dbh->errstr);
      $status= STATUS_DATABASE_CORRUPTION;
    }
  }
  if ($status != STATUS_OK) {
    return $self->finalize($status,[$server]);
  }
  $dbh->do('SET sql_mode= DEFAULT');

  #####
  $self->printStep("Dumping the data after discard/import");

  $databases= join ' ', $server->nonSystemDatabases();
  $server->dumpdb($databases, $server->vardir.'/server_data_new.dump');
  $server->normalizeDump($server->vardir.'/server_data_new.dump');
  # This is for information purposes
  $server->dumpSchema($databases, $server->vardir.'/server_schema_new.dump');


  #####
  $self->printStep("Comparing data before and after discard/import");

  $status= compare($server->vardir.'/server_data_old.dump', $server->vardir.'/server_data_new.dump');
  if ($status != STATUS_OK) {
    sayError("Data differs after upgrade");
    system('diff -a -u '.$server->vardir.'/server_data_old.dump'.' '.$server->vardir.'/server_data_new.dump');
    return $self->finalize(STATUS_UPGRADE_FAILURE,[$server]);
  }
  else {
    say("Data dumps appear to be identical");
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
