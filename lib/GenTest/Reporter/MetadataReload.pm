# Copyright (c) 2019, 2021, MariaDB Corporation AB. All rights reserved.
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

# Periodically reloads metadata.
# Recommended if the test performs DDL and uses standard grammar entries
# such as _table, _field, etc., rather than custom ones specified
# in the grammar itself

package GenTest::Reporter::MetadataReload;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;

use DBI;
use GenTest;
use GenTest::Constants;
use GenTest::Result;
use GenTest::Reporter;
use GenTest::Reporter::Backtrace;
use GenTest::Executor::MySQL;

use DBI;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use POSIX;

use constant METADATA_RELOAD_INTERVAL => 300;
use constant METADATA_QUERY_TIMEOUT => 25;
use constant ER_LOCK_WAIT_TIMEOUT => 1205;
use constant ER_STATEMENT_TIMEOUT => 1969;

my $last_reload= 0;
my $reloaded_before= 0;
my $test_end= 0;

my $dbh;
my $metadata_file;
my $last_md5;
my $system_schemata= "'mysql','information_schema','performance_schema','sys'";
# Databases used for technical purposes
# (we don't want these tables be tampered with)
my $exempt_schemata= "'transforms'";

sub init {
  my $reporter= shift;
  sayDebug("MetadataReload initialization");
  # This is for scenarios, where servers get restart, reporters re-initialized, etc.
  if ($dbh) {
    $dbh->disconnect();
    $dbh= undef;
  }
  $test_end= time() + $reporter->testDuration();
  $reporter->loadNonSystemSchemata();
  return $reporter->loadSystemSchemata();
}

sub monitor {
  if ($reloaded_before and time() < $last_reload + METADATA_RELOAD_INTERVAL or time() > $test_end) {
    return STATUS_OK;
  }
  $_[0]->restoreBrokenViews();
  return $_[0]->loadNonSystemSchemata();
}

sub restoreBrokenViews {
  my $reporter= shift;
  my $dbh= $reporter->dbh();
  unless ($dbh) {
    return;
  }
  # We don't need ROW_FORMAT here, but it makes the query open tables rather than frm only
  my $broken_views= $dbh->selectall_arrayref("SELECT table_schema, table_name, row_format FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_COMMENT LIKE '%references invalid table%'");
  if ($broken_views) {
    my $datadir= $reporter->serverVariable('datadir');
    foreach my $v (@$broken_views) {
      my ($schema, $view)= @$v;
      my $recreate_query;
      my $algorithm= 'UNDEFINED';
      if (open(VIEW, "$datadir/$schema/$view.frm")) {
        while (<VIEW>) {
          if (/^algorithm=(\d+)/) {
            $algorithm= ($1 == 1 ? 'MERGE' : ($1 == 2 ? 'TEMPTABLE' : 'UNDEFINED'));
          } elsif (/^source=(.*)/) {
            $recreate_query= $1;
            chomp $recreate_query;
            last;
          }
        }
        close(VIEW);
      } else {
        sayWarning("MetadataReload: Couldn't open $datadir/$schema/$view.frm for reading: $!, dropping the view");
      }
      if ($recreate_query) {
        $dbh->do('CREATE OR REPLACE ALGORITHM='.$algorithm.' VIEW `'.$schema.'`.`'.$view.'` AS '.$recreate_query);
        if ($dbh->err) {
          sayWarning("MetadataReload: Could not restore broken view $schema.$view: ".$dbh->errstr);
          $dbh->do('DROP VIEW IF EXISTS `'.$schema.'`.`'.$view.'`');
          if ($dbh->err) {
            sayWarning("MetadataReload: Failed to drop broken view $schema.$view");
          } else {
            say("MetadataReload: Dropped broken view $schema.$view");
          }
        } else {
          say("MetadataReload: Restored broken view $schema.$view");
        }
      }
    }
  }
}

sub loadSystemSchemata {
  my $reporter= shift;
  # Workaround for MDEV-24975 -- don't use OPTIMIZER_TRACE table in queries
  my $clause= "table_schema IN ($system_schemata) AND table_name != 'OPTIMIZER_TRACE'";
  my $schemata= $reporter->reload($clause);
  if ($schemata) {
    local $Data::Dumper::Maxdepth= 0;
    local $Data::Dumper::Sortkeys= 1;
    $reporter->writeToFile('metadata_system.info',Dumper($schemata));
    return STATUS_OK;
  } else {
    sayError("MetadataReload failed to load system schemata");
    return STATUS_ENVIRONMENT_FAILURE;
  }
}

sub loadNonSystemSchemata {
  my $reporter= shift;
  my $clause= "table_schema NOT IN ($system_schemata,$exempt_schemata) and table_name != 'DUMMY'";
  my $schemata= $reporter->reload($clause);
  if ($schemata) {
    local $Data::Dumper::Maxdepth= 0;
    local $Data::Dumper::Sortkeys= 1;
    my $dump= Dumper($schemata);
    if (defined $last_md5 and md5_hex($dump) eq $last_md5) {
      sayDebug("MetadataReload: MD5 checksum hasn't changed, not re-writing the file");
    } else {
      $reporter->writeToFile('metadata.info',$dump);
    }
  } else {
    sayError("MetadataReload failed to load non-system schemata");
  }

  $last_reload= time();
  $reloaded_before++;
  sayDebug("MetadataReload: Finished reloading metadata. Number of reloads: $reloaded_before");
  return STATUS_OK;
}

sub dbh {
  my $reporter= shift;
  unless ($dbh) {
    sayDebug("MetadataReload: dbh not defined, reconnecting");
    my $dsn = $reporter->dsn();
    unless ($dbh = DBI->connect($dsn, undef, undef, {mysql_connect_timeout => METADATA_RELOAD_INTERVAL, PrintError => 0, RaiseError => 0})) {
      # Try to connect twice, due to MDEV-24998
      sayWarning("MetadataReload got error ".$DBI::err." upon connecting to $dsn. Trying again");
      $dbh = DBI->connect($dsn, undef, undef, {mysql_connect_timeout => METADATA_RELOAD_INTERVAL, PrintError => 0, RaiseError => 0});
      unless ($dbh) {
        sayError("MetadataReload failed to connect to the database");
        return undef;
      }
    }
    sayDebug("MetadataReload: dbh presumably reconnected");
    $dbh->do('/*!100108 SET @@max_statement_time= '.METADATA_QUERY_TIMEOUT.' */');
    sayDebug("After setting max_statement_time: ".$dbh->err);
    $dbh->do('SET @@lock_wait_timeout= '.METADATA_QUERY_TIMEOUT);
  }
  return $dbh;
}

sub reload {
  my ($reporter, $clause)= @_;
  $clause= '' unless defined $clause;
  my $dbh= $reporter->dbh();
  unless ($dbh) {
    return undef;
  }
  my $table_query=
      "SELECT table_schema, table_name, table_type ".
      "FROM information_schema.tables".
      ($clause ? " WHERE $clause" : "");
  my $column_query=
      "SELECT table_schema, table_name, column_name, column_key, ".
             "data_type, character_maximum_length ".
      "FROM information_schema.columns".
      ($clause ? " WHERE $clause" : "");

  sayDebug("MetadataReload: Starting reading metadata with condition \"$clause\"");

  my ($table_metadata, $column_metadata);
  $table_metadata= $dbh->selectall_arrayref($table_query);
  if (not $dbh->err and $table_metadata) {
    $column_metadata= $dbh->selectall_arrayref($column_query);
    sayDebug("MetadataReload: Finished reading metadata");
  }
  if ($dbh->err or not $table_metadata or not $column_metadata) {
    sayError("MetadataReload: Failed to retrieve metadata with condition \"$clause\": " . $dbh->err . " " . $dbh->errstr);
    return undef;
  }

  my $meta= {};
  my %tabletype= ();

  foreach my $row (@$table_metadata) {
    my ($schema, $table, $type) = @$row;
    if (
      $type eq 'BASE TABLE' or
      $type eq 'SYSTEM VERSIONED' or
      $type eq 'SEQUENCE'
    ) { $type= 'table' }
    elsif (
      $type eq 'VIEW' or
      $type eq 'SYSTEM VIEW'
    ) { $type= 'view' }
    else { $type= 'misc' };
    if (lc($schema) eq 'information_schema') {
      $meta->{information_schema}={} if not exists $meta->{information_schema};
      $meta->{information_schema}->{$type}={} if not exists $meta->{information_schema}->{$type};
      $meta->{information_schema}->{$type}->{$table}={} if not exists $meta->{information_schema}->{$type}->{$table};
      $tabletype{'information_schema.'.$table}= $type;
      $meta->{INFORMATION_SCHEMA}={} if not exists $meta->{INFORMATION_SCHEMA};
      $meta->{INFORMATION_SCHEMA}->{$type}={} if not exists $meta->{INFORMATION_SCHEMA}->{$type};
      $meta->{INFORMATION_SCHEMA}->{$type}->{$table}={} if not exists $meta->{INFORMATION_SCHEMA}->{$type}->{$table};
      $tabletype{'INFORMATION_SCHEMA.'.$table}= $type;
    } else {
      $meta->{$schema}={} if not exists $meta->{$schema};
      $meta->{$schema}->{$type}={} if not exists $meta->{$schema}->{$type};
      $meta->{$schema}->{$type}->{$table}={} if not exists $meta->{$schema}->{$type}->{$table};
      $tabletype{$schema.'.'.$table}= $type;
    }
  }

  foreach my $row (@$column_metadata) {
    my ($schema, $table, $col, $key, $realtype, $maxlength) = @$row;
    my $metatype= lc($realtype);
    if (
      $metatype eq 'bit' or
      $metatype eq 'tinyint' or
      $metatype eq 'smallint' or
      $metatype eq 'mediumint' or
      $metatype eq 'bigint'
    ) { $metatype= 'int' }
    elsif (
      $metatype eq 'double'
    ) { $metatype= 'float' }
    elsif (
      $metatype eq 'datetime'
    ) { $metatype= 'timestamp' }
    elsif (
      $metatype eq 'varchar' or
      $metatype eq 'binary' or
      $metatype eq 'varbinary'
    ) { $metatype= 'char' }
    elsif (
      $metatype eq 'tinyblob' or
      $metatype eq 'mediumblob' or
      $metatype eq 'longblob' or
      $metatype eq 'tinytext' or
      $metatype eq 'mediumtext' or
      $metatype eq 'longtext'
    ) { $metatype= 'blob' };

    if ($key eq 'PRI') { $key= 'primary' }
    elsif ($key eq 'MUL' or $key eq 'UNI') { $key= 'indexed' }
    else { $key= 'ordinary' };
    my $type= $tabletype{$schema.'.'.$table};
    if (lc($schema) eq 'information_schema') {
      $meta->{information_schema}->{$type}->{$table}->{$col}= [$key,$metatype,$realtype,$maxlength];
      $meta->{INFORMATION_SCHEMA}->{$type}->{$table}->{$col}= [$key,$metatype,$realtype,$maxlength];
    } else {
      $meta->{$schema}->{$type}->{$table}->{$col}= [$key,$metatype,$realtype,$maxlength];
    }
  }
  return $meta;
}

sub writeToFile {
  my ($reporter, $file,$dump)= @_;
  if (open(METADATA, '>'.$reporter->serverVariable('datadir').'/'.$file)) {
    print METADATA $dump;
    close(METADATA);
    $last_md5= md5_hex($dump);
  } else {
    sayError("MetadataReload: Couldn't open $file for writing: $!");
    return STATUS_ENVIRONMENT_FAILURE;
  }
}

sub type {
  return REPORTER_TYPE_PERIODIC;
}

1;
