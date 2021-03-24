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

use constant METADATA_RELOAD_INTERVAL => 20;
use constant METADATA_QUERY_TIMEOUT => 5;
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

# Internal "query cache". If metadata loading ends with a lock wait timeout,
# we will use the result from the cache instead.
my %query_cache;


sub init {
  my $reporter= shift;
  sayDebug("MetadataReload initialization");
  $test_end= time() + $reporter->testDuration();
  $reporter->loadNonSystemSchemata();
  return $reporter->loadSystemSchemata();
}

sub monitor {
  if ($reloaded_before and time() < $last_reload + METADATA_RELOAD_INTERVAL or time() > $test_end) {
    return STATUS_OK;
  }
  return $_[0]->loadNonSystemSchemata();
}

sub loadSystemSchemata {
  my $reporter= shift;
  # Workaround for MDEV-24975 -- don't use OPTIMIZER_TRACE table in queries
  my $clause= "table_schema IN ($system_schemata) AND table_name != 'OPTIMIZER_TRACE'";
  my $schemata= $reporter->reload($clause);
  if ($schemata) {
#    $schemata->{INFORMATION_SCHEMA}= $schemata->{information_schema};
    local $Data::Dumper::Maxdepth= 0;
    $reporter->writeToFile('metadata_system.info',Dumper($schemata));
    return STATUS_OK;
  } else {
    sayError("MetadataReload failed to load system schemata");
    return STATUS_ENVIRONMENT_FAILURE;
  }
}

sub loadNonSystemSchemata {
  my $reporter= shift;

  my $meta= {};
  my $dbh= $reporter->dbh();
  unless ($dbh) {
    return ($reloaded_before ? STATUS_OK : STATUS_ENVIRONMENT_FAILURE);
  }
  my $query=
    "SELECT table_schema, table_name FROM information_schema.tables ".
    "WHERE table_schema NOT IN ($system_schemata,$exempt_schemata) and table_name != 'DUMMY'";

  my $tables= $dbh->selectall_arrayref($query);
  unless ($tables) {
    return ($reloaded_before ? STATUS_OK : STATUS_ENVIRONMENT_FAILURE);
  }
  foreach my $row (@$tables) {
    return STATUS_OK if time() > $test_end;
    my ($schema, $table) = @$row;
    my $meta_schema_table= $reporter->reload("table_schema = '$schema' AND table_name = '$table'");
    # The table may not exist anymore, we won't make a big deal out of it
    if ($meta_schema_table and $meta_schema_table->{$schema}) {
      my $type= (keys %{$meta_schema_table->{$schema}})[0];
      $meta->{$schema}={} if not exists $meta->{$schema};
      $meta->{$schema}->{$type}={} if not exists $meta->{$schema}->{$type};
      $meta->{$schema}->{$type}->{$table}= { %{$meta_schema_table->{$schema}->{$type}->{$table}} };
    }
  }
  if ($meta) {
    local $Data::Dumper::Maxdepth= 0;
    local $Data::Dumper::Sortkeys= 1;
    my $dump= Dumper($meta);
    if (defined $last_md5 and md5_hex($dump) eq $last_md5) {
      sayDebug("MetadataReload: MD5 checksum hasn't changed, not re-writing the file");
    } else {
      $reporter->writeToFile('metadata.info',$dump);
    }
  }
  $last_reload= time();
  $reloaded_before++;
  sayDebug("MetadataReload: Finished reloading metadata. Number of reloads: $reloaded_before");
  return STATUS_OK;
}

sub dbh {
  my $reporter= shift;
  unless ($dbh) {
    my $dsn = $reporter->dsn();
    unless ($dbh = DBI->connect($dsn), undef, undef, {mysql_connect_timeout => METADATA_RELOAD_INTERVAL, PrintError => 0, RaiseError => 0}) {
      # Try to connect twice, due to MDEV-24998
      sayWarning("MetadataReload got error ".$DBI::err." upon connecting to $dsn. Trying again");
      $dbh = DBI->connect($dsn, undef, undef, {mysql_connect_timeout => METADATA_RELOAD_INTERVAL, PrintError => 0, RaiseError => 0} );
      unless ($dbh) {
        sayError("MetadataReload failed to connect to the database");
        return undef;
      }
    }
    $dbh->do('/*!100108 SET @@max_statement_time= '.METADATA_QUERY_TIMEOUT.' */');
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
  my $query=
      "SELECT DISTINCT ".
             "table_schema, ".
             "table_name, ".
             "CASE WHEN table_type = 'BASE TABLE' THEN 'table' ".
                  "WHEN table_type = 'SYSTEM VERSIONED' THEN 'table' ".
                  "WHEN table_type = 'SEQUENCE' THEN 'table' ".
                  "WHEN table_type = 'VIEW' THEN 'view' ".
                  "WHEN table_type = 'SYSTEM VIEW' then 'view' ".
                  "ELSE 'misc' END AS table_type, ".
             "column_name, ".
             "CASE WHEN column_key = 'PRI' THEN 'primary' ".
                  "WHEN column_key IN ('MUL','UNI') THEN 'indexed' ".
                  "ELSE 'ordinary' END AS column_key, ".
             "CASE WHEN data_type IN ('bit','tinyint','smallint','mediumint','int','bigint') THEN 'int' ".
                  "WHEN data_type IN ('float','double') THEN 'float' ".
                  "WHEN data_type IN ('decimal') THEN 'decimal' ".
                  "WHEN data_type IN ('datetime','timestamp') THEN 'timestamp' ".
                  "WHEN data_type IN ('char','varchar','binary','varbinary') THEN 'char' ".
                  "WHEN data_type IN ('tinyblob','blob','mediumblob','longblob') THEN 'blob' ".
                  "WHEN data_type IN ('tinytext','text','mediumtext','longtext') THEN 'blob' ".
                  "ELSE data_type END AS data_type_normalized, ".
             "data_type, ".
             "character_maximum_length, ".
             "table_rows ".
       "FROM information_schema.tables INNER JOIN ".
            "information_schema.columns USING(table_schema,table_name)".
       ($clause ? " WHERE $clause" : "");

  sayDebug("MetadataReload: Starting reading metadata with condition \"$clause\"");
  my $metadata;
  if (($dbh->err == ER_LOCK_WAIT_TIMEOUT or $dbh->err == ER_STATEMENT_TIMEOUT) and exists $query_cache{$clause}) {
    sayWarning("MetadataReload: query timed out, using the previously cached result");
    $metadata= [ @{$query_cache{$clause}} ];
  } elsif ($dbh->err) {
    sayError("MetadataReload: Failed to retrieve metadata with condition \"$clause\": " . $dbh->err . " " . $dbh->errstr);
    return undef;
  } else {
    $metadata = $dbh->selectall_arrayref($query);
    sayDebug("MetadataReload: Finished reading metadata with condition \"$clause\"");
    $query_cache{$clause}= [ @$metadata ] if ($metadata);
  }

  my $meta = {};

  foreach my $row (@$metadata) {
    my ($schema, $table, $type, $col, $key, $metatype, $realtype, $maxlength) = @$row;
    $meta->{$schema}={} if not exists $meta->{$schema};
    $meta->{$schema}->{$type}={} if not exists $meta->{$schema}->{$type};
    $meta->{$schema}->{$type}->{$table}={} if not exists $meta->{$schema}->{$type}->{$table};
    $meta->{$schema}->{$type}->{$table}->{$col}= [$key,$metatype,$realtype,$maxlength];
    if ($schema eq 'information_schema') {
      $schema= uc($schema);
      $meta->{$schema}={} if not exists $meta->{$schema};
      $meta->{$schema}->{$type}={} if not exists $meta->{$schema}->{$type};
      $meta->{$schema}->{$type}->{$table}={} if not exists $meta->{$schema}->{$type}->{$table};
      $meta->{$schema}->{$type}->{$table}->{$col}= [$key,$metatype,$realtype,$maxlength];
    }
    elsif ($schema eq 'INFORMATION_SCHEMA') {
      $schema= lc($schema);
      $meta->{$schema}={} if not exists $meta->{$schema};
      $meta->{$schema}->{$type}={} if not exists $meta->{$schema}->{$type};
      $meta->{$schema}->{$type}->{$table}={} if not exists $meta->{$schema}->{$type}->{$table};
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
