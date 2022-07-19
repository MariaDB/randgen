# Copyright (c) 2021, 2022 MariaDB Corporation Ab
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

#######################################
# IMPORTANT NOTE:
# Log records from this reporter are used for automatic bug recognition;
# do not change the wording or logging format unless absolutely
# necessary!
#######################################

package GenTest::Reporter::FeatureUsage;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use GenTest;
use GenTest::Constants;
use GenTest::Result;
use GenTest::Reporter;
use GenTest::Executor::MySQL;

use DBI;
use Data::Dumper;
use POSIX;

my $dbh;
my $server_version;

my %usage_check= (
  app_periods => \&check_for_app_periods,
  aria_tables => \&check_for_aria_tables,
  backup_stages => \&check_for_backup_stages,
  compressed_cols => \&check_for_compressed_cols,
  delayed_insert => \&check_for_delayed_insert,
  federated => \&check_for_federated,
  fk => \&check_for_fk,
  gis => \&check_for_gis,
  multi_upd_del => \&check_for_multi_upd_del,
  perfschema => \&check_for_perfschema,
  rocksdb => \&check_for_rocksdb,
  s3 => \&check_for_s3,
  sequences => \&check_for_sequences,
  spider => \&check_for_spider,
  unique_blobs => \&check_for_unique_blobs,
  vcols => \&check_for_vcols,
  versioning => \&check_for_versioning,
  xa => \&check_for_xa,
);
my %features_used = ();

sub monitor {
  my $reporter = shift;
  unless (defined $server_version) {
    if ($reporter->serverVariable('version') =~ /^(\d+)\.(\d+)\.\d+(-\d+)?/) {
      $server_version= sprintf("%02d%02d",$1, $2);
      $server_version.= 'e' if defined $3;
    }
  }
  foreach my $f (sort keys %usage_check) {
    next if $features_used{$f};
    my $func= $usage_check{$f};
    $reporter->$func;
  }
  return STATUS_OK;
}

sub report {

  my $reporter = shift;
  return STATUS_OK;
}

##########
# Checkers

sub check_for_rocksdb {
  my $reporter= shift;
  if ($features_used{spider}= $reporter->getval("SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE ENGINE='RocksDB'")) {
    say("FeatureUsage detected RocksDB tables in the database");
  }
}

sub check_for_spider {
  my $reporter= shift;
  if ($features_used{spider}= $reporter->getval("SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE ENGINE='SPIDER'")) {
    say("FeatureUsage detected SPIDER tables in the database");
  }
}

sub check_for_federated {
  my $reporter= shift;
  if ($features_used{federated}= $reporter->getval("SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE ENGINE='FEDERATED'")) {
    say("FeatureUsage detected FEDERATED tables in the database");
  }
}

sub check_for_s3 {
  return if $server_version lt '1004';
  my $reporter= shift;
  if ($features_used{s3}= $reporter->getval("SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE ENGINE='S3'")) {
    say("FeatureUsage detected S3 tables in the database");
  }
}

sub check_for_sequences {
  return if $server_version lt '1003';
  my $reporter= shift;
  if ($features_used{sequences}= $reporter->getval("SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='SEQUENCE'")) {
    say("FeatureUsage detected sequences in the database");
  }
}

sub check_for_aria_tables {
  my $reporter= shift;
  if ($features_used{aria_tables}= $reporter->getval("SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE ENGINE='Aria' and TABLE_SCHEMA NOT IN ('mysql','information_schema','sys')")) {
    say("FeatureUsage detected Aria user tables in the database");
  }
}

sub check_for_fk {
  my $reporter= shift;
  if ($features_used{fk}= $reporter->getval("SELECT COUNT(*) FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS")) {
    say("FeatureUsage detected foreign keys in the database");
  }
}

sub check_for_unique_blobs {
  return if $server_version lt '1004';
  my $reporter= shift;
  if ($features_used{unique_blobs}= $reporter->getval("SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS constr JOIN INFORMATION_SCHEMA.STATISTICS stat ON ( constr.TABLE_SCHEMA = stat.TABLE_SCHEMA AND constr.TABLE_NAME = stat.TABLE_NAME AND constr.CONSTRAINT_NAME = stat.INDEX_NAME) JOIN INFORMATION_SCHEMA.COLUMNS cols ON ( stat.TABLE_SCHEMA = cols.TABLE_SCHEMA AND stat.TABLE_NAME = cols.TABLE_NAME AND stat.COLUMN_NAME = cols.COLUMN_NAME ) where constr.CONSTRAINT_TYPE = 'UNIQUE' AND stat.INDEX_TYPE = 'HASH' AND cols.DATA_TYPE in ('varchar','varbinary','tinyblob','mediumblob','blob','longblob','tinytext','mediumtext','text','longtext')")) {
    say("FeatureUsage detected unique blobs in the database");
  }
}

sub check_for_vcols {
  my $reporter= shift;
  if ($features_used{vcols}= $reporter->getval("SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE IS_GENERATED='ALWAYS'")) {
    say("FeatureUsage detected virtual columns in the database");
  }
}

sub check_for_compressed_cols {
  return if $server_version lt '1003';
  my $reporter= shift;
  if ($features_used{compressed_cols}= $reporter->getval("SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_TYPE LIKE '%COMPRESSED%'")) {
    say("FeatureUsage detected compressed columns in the database");
  }
}

sub check_for_xa {
  if ($features_used{xa}= $_[0]->check_status_var('Com_xa_start')) {
    say("FeatureUsage detected XA transactions");
  }
}

sub check_for_versioning {
  return if $server_version lt '1003';
  if ($features_used{versioning}= $_[0]->check_status_var('Feature_system_versioning')) {
    say("FeatureUsage detected system-versioned tables in the database");
  }
}

sub check_for_app_periods {
  return if $server_version lt '1004';
  if ($features_used{app_periods}= $_[0]->check_status_var('Feature_application_time_periods')) {
    say("FeatureUsage detected application periods in the database");
  }
}

sub check_for_gis {
  if ($features_used{gis}= $_[0]->check_status_var('Feature_gis')) {
    say("FeatureUsage detected GIS columns in the database");
  }
}

sub check_for_perfschema {
  if ($features_used{perfschema}= $_[0]->check_system_var('performance_schema')) {
    say("FeatureUsage detected performance schema enabled");
  }
}

sub check_for_multi_upd_del {
  if ($features_used{multi_upd_del}= ( $_[0]->check_status_var('Com_delete_multi') or $_[0]->check_status_var('Com_update_multi')) ) {
    say("FeatureUsage detected multi update/delete");
  }
}

sub check_for_delayed_insert {
  if ($features_used{delayed_insert}= $_[0]->check_status_var('Delayed_writes')) {
    say("FeatureUsage detected delayed inserts");
  }
}

sub check_for_backup_stages {
  return if $server_version lt '1004' and $server_version ne '1002e' and $server_version ne '1003e';
  if ($features_used{backup_stages}= $_[0]->check_status_var('Com_backup')) {
    say("FeatureUsage detected backup stages");
  }
}

####
# Helpers

sub check_status_var {
  my ($reporter, $var)= @_;
  return $reporter->getval("SELECT VARIABLE_VALUE FROM INFORMATION_SCHEMA.GLOBAL_STATUS WHERE VARIABLE_NAME='".$var."'");
}

sub check_system_var {
  my ($reporter, $var)= @_;
  return $reporter->getval("SELECT IF(VARIABLE_VALUE = 'OFF',0,1) FROM INFORMATION_SCHEMA.GLOBAL_VARIABLES WHERE VARIABLE_NAME='".$var."'");
}

sub getval {
  my ($reporter, $query)= @_;
  my $res;
  if ($dbh= $reporter->refresh_dbh()) {
    eval {
        $res= $dbh->selectrow_arrayref($query)->[0];
        # Can't return res from here, because if it's 0, the "or" block will be executed
        1;
    } or do {
      sayWarning("FeatureUsage got an error: ".$dbh->err." (".$dbh->errstr.") for query $query");
    }
  }
  return $res;
}

sub refresh_dbh {
  my $reporter= shift;
  unless ($dbh) {
    $dbh = DBI->connect($reporter->dsn(), undef, undef, { RaiseError => 1, PrintError => 0 });
    unless ($dbh) {
      sayError("FeatureUsage reporter could not connect to the server. Status will be set to STATUS_INTERNAL_ERROR");
      return undef;
    }
  }
  return $dbh;
}

# End of checkers/helpers
#################

sub type {
  return REPORTER_TYPE_ALWAYS | REPORTER_TYPE_PERIODIC;
}

1;

