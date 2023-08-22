# Copyright (c) 2021, 2023 MariaDB
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
use GenUtil;
use GenTest;
use Constants;
use GenTest::Result;
use GenTest::Reporter;
use GenTest::Executor::MRDB;

use Data::Dumper;
use POSIX;

my $conn;
my $server_version;

my %usage_check= (
  'application periods' => \&check_for_application_periods,
  'Aria tables' => \&check_for_aria_tables,
  'backup stages' => \&check_for_backup_stages,
  'binlog compression' => \&check_for_binlog_compression,
  'binlog alter two phase' => \&check_for_binlog_alter_two_phase,
  'Blackhole tables' => \&check_for_blackhole_tables,
  'compressed columns' => \&check_for_compressed_columns,
  'delayed inserts' => \&check_for_delayed_inserts,
  'Federated engine' => \&check_for_federated_plugin,
  'Federated tables' => \&check_for_federated_tables,
  'foreign keys' => \&check_for_foreign_keys,
  'GIS columns' => \&check_for_gis,
  'INET columns' => \&check_for_inet_columns,
  'multi-update/delete' => \&check_for_multi_upd_del,
  'Mroonga engine' => \&check_for_mroonga_plugin,
  'Mroonga tables' => \&check_for_mroonga_tables,
  'OQGraph engine' => \&check_for_oqgraph_plugin,
  'OQGraph tables' => \&check_for_oqgraph_tables,
  'performance schema' => \&check_for_performance_schema,
  'RocksDB engine' => \&check_for_rocksdb_plugin,
  'RocksDB tables' => \&check_for_rocksdb_tables,
  'S3 engine' => \&check_for_s3_plugin,
  'S3 tables' => \&check_for_s3_tables,
  'sequences' => \&check_for_sequences,
  'Spider engine' => \&check_for_spider_plugin,
  'Spider tables' => \&check_for_spider_tables,
  'unique blobs' => \&check_for_unique_blobs,
  'virtual columns' => \&check_for_virtual_columns,
  'system-versioned tables' => \&check_for_versioning,
  'XA transactions' => \&check_for_xa,
);

my %features_used = ();
# To reduce the amount of I_S queries, on every cycle we'll re-fill
# the hashes once
my %engine_tables= ();
my %plugins= ();
my %global_status= ();
my $first_reporter;

my $reporter = shift;
my $registered_features = undef;

# In case of two or more main servers, we will be called more than once.
# Ignore all but the first call.

sub monitor {
  my $reporter = shift;

  $first_reporter = $reporter if not defined $first_reporter;
  return STATUS_OK if $reporter ne $first_reporter;

  unless (defined $server_version) {
    if ($reporter->server->serverVariable('version') =~ /^(\d+)\.(\d+)\.\d+(-\d+)?/) {
      $server_version= sprintf("%02d%02d",$1, $2);
      $server_version.= 'e' if defined $3;
    }
  }
  
  $conn= $reporter->connection() unless ($conn);

  unless ($conn->alive()) {
    sayError((ref $reporter)." reporter returning critical failure");
    return STATUS_SERVER_UNAVAILABLE;
  }
  # We will only check the table once, as feature registration happens
  # before reporters are initialized
  unless (defined $registered_features) {
    eval {
        $registered_features= $conn->get_column("SELECT feature FROM mysql.rqg_feature_registry",1);
        1;
    } or do {
      sayWarning("FeatureUsage got an error: ".$conn->last_error->[0]." (".$conn->last_error->[1].") for mysql.rqg_feature_registry query");
    };
    if ($registered_features) {
      foreach my $f (@$registered_features) {
        # To get rid of duplicates in grammar lists, when each thread registeres a feature separately
        $features_used{$f}= "registered by grammar(s)";
        say("FeatureUsage detected $f ($features_used{$f})");
      }
    }
    $registered_features= 1;
  }
  %global_status= ();
  foreach my $f (sort keys %usage_check) {
    next if $features_used{$f};
    my $func= $usage_check{$f};
    my $res= $reporter->$func;
    if (defined $res) {
      $features_used{$f}= $res;
      say("FeatureUsage detected $f ($features_used{$f})");
    }
  }
  return STATUS_OK;
}


sub report {
  my $reporter = shift;

  $first_reporter = $reporter if not defined $first_reporter;
  return STATUS_OK if $reporter ne $first_reporter;

  foreach my $f (keys %features_used) {
    say("FeatureUsage detected $f ($features_used{$f})");
  }
  return STATUS_OK;
}

##########
# Checkers

sub check_for_mroonga_tables {
  $_[0]->check_for_engine_tables('mroonga');
}
sub check_for_oqgraph_tables {
  $_[0]->check_for_engine_tables('oqgraph');
}

sub check_for_rocksdb_tables {
  $_[0]->check_for_engine_tables('rocksdb');
}

sub check_for_spider_tables {
  $_[0]->check_for_engine_tables('spider');
}

sub check_for_federated_tables {
  $_[0]->check_for_engine_tables('federated');
}

sub check_for_s3_tables {
  $_[0]->check_for_engine_tables('s3');
}

sub check_for_aria_tables {
  $_[0]->check_for_engine_tables('aria');
}

sub check_for_blackhole_tables {
  $_[0]->check_for_engine_tables('blackhole');
}

sub check_for_mroonga_plugin {
  $_[0]->check_for_plugin('mroonga');
}

sub check_for_oqgraph_plugin {
  $_[0]->check_for_plugin('oqgraph');
}

sub check_for_rocksdb_plugin {
  $_[0]->check_for_plugin('rocksdb');
}

sub check_for_spider_plugin {
  $_[0]->check_for_plugin('spider');
}

sub check_for_federated_plugin {
  $_[0]->check_for_plugin('federated');
}

sub check_for_s3_plugin {
  $_[0]->check_for_plugin('s3');
}

sub check_for_sequences {
  my $reporter= shift;
  if ($server_version ge '1003' and $reporter->getval("SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='SEQUENCE'")) {
    return "according to I_S.TABLES";
  }
  return undef;
}

sub check_for_foreign_keys {
  my $reporter= shift;
  if ($reporter->getval("SELECT COUNT(*) FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS")) {
    return "according to I_S.REFERENTIAL_CONSTRAINTS";
  }
  return undef;
}

sub check_for_unique_blobs {
  return if $server_version lt '1004';
  my $reporter= shift;
  if ($reporter->getval("SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS constr JOIN INFORMATION_SCHEMA.STATISTICS stat ON ( constr.TABLE_SCHEMA = stat.TABLE_SCHEMA AND constr.TABLE_NAME = stat.TABLE_NAME AND constr.CONSTRAINT_NAME = stat.INDEX_NAME) JOIN INFORMATION_SCHEMA.COLUMNS cols ON ( stat.TABLE_SCHEMA = cols.TABLE_SCHEMA AND stat.TABLE_NAME = cols.TABLE_NAME AND stat.COLUMN_NAME = cols.COLUMN_NAME ) where constr.CONSTRAINT_TYPE = 'UNIQUE' AND stat.INDEX_TYPE = 'HASH' AND cols.DATA_TYPE in ('varchar','varbinary','tinyblob','mediumblob','blob','longblob','tinytext','mediumtext','text','longtext')")) {
    return "according to I_S.STATISTICS + I_S.COLUMNS + I_S.TABLE_CONSTRAINTS";
  }
  return undef;
}

sub check_for_virtual_columns {
  my $reporter= shift;
  if ($reporter->getval("SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE IS_GENERATED='ALWAYS'")) {
    return "according to I_S.COLUMNS";
  }
  return undef;
}

sub check_for_inet_columns {
  my $reporter= shift;
  if ($reporter->getval("SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_TYPE IN ('inet4','inet6')")) {
    return "according to I_S.COLUMNS";
  }
  return undef;
}

sub check_for_compressed_columns {
  return if $server_version lt '1003';
  my $reporter= shift;
  if ($reporter->getval("SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_TYPE LIKE '%COMPRESSED%'")) {
    return "according to I_S.COLUMNS";
  }
  return undef;
}

sub check_for_xa {
  if ($_[0]->check_status_var('Com_xa_start')) {
    return "according to Com_xa_start";
  }
  return undef;
}

sub check_for_versioning {
  return if $server_version lt '1003';
  if ($_[0]->check_status_var('Feature_system_versioning')) {
    return "according to Feature_system_versioning";
  }
  return undef;
}

sub check_for_application_periods {
  return if $server_version lt '1004';
  if ( $_[0]->check_status_var('Feature_application_time_periods')) {
    return "according to Feature_application_time_periods";
  }
  return undef;
}

sub check_for_gis {
  if ($_[0]->check_status_var('Feature_gis')) {
    return "according to Feature_gis";
  }
  return undef;
}

sub check_for_binlog_compression {
  if ($_[0]->check_system_var('log_bin') && $_[0]->check_system_var('log_bin_compress')) {
    return "according to log_bin and log_bin_compress variables";
  }
  return undef;
}

sub check_for_binlog_alter_two_phase {
  if ($server_version ge '1008' && $_[0]->check_system_var('log_bin') && $_[0]->check_system_var('binlog_alter_two_phase')) {
    return "according to log_bin and binlog_alter_two_phase variables";
  }
  return undef;
}

sub check_for_performance_schema {
  if ($_[0]->check_system_var('performance_schema')) {
    return "according to performance_schema variable";
  }
  return undef;
}

sub check_for_multi_upd_del {
  if (($_[0]->check_status_var('Com_delete_multi') or $_[0]->check_status_var('Com_update_multi')) ) {
    return "according to Com_update_multi/Com_delete_multi";
  }
  return undef;
}

sub check_for_delayed_inserts {
  if ($_[0]->check_status_var('Delayed_writes')) {
    return "according to Delayed_writes";
  }
  return undef;
}

sub check_for_backup_stages {
  return ;
  if (($server_version ge '1004' or $server_version eq '1002e' or $server_version eq '1003e') and $_[0]->check_status_var('Com_backup')) {
    return "according to Com_backup";
  }
  return undef;
}

####
# Helpers

sub check_for_engine_tables {
  my ($reporter, $engine)= @_;
  unless ($engine_tables{$engine}) {
    my $engines;
    eval {
        $engines= $conn->get_column("SELECT DISTINCT lower(ENGINE) FROM INFORMATION_SCHEMA.TABLES WHERE ENGINE IS NOT NULL AND TABLE_SCHEMA NOT IN ('mysql','information_schema','sys','performance_schema')");
        # Can't return res from here, because if it's 0, the "or" block will be executed
        1;
    } or do {
      sayWarning("FeatureUsage got an error: ".$conn->last_error->[0]." (".$conn->last_error->[1].") for ENGINES query");
    };
    if ($engines) {
      # Also add them to plugins, because if there is a table, there is (or was) the engine/plugin
      map { $engine_tables{$_}= 1; $plugins{$_}= 1; } (@$engines);
    }
  }
  return ($engine_tables{lc($engine)} ? return "according to I_S.TABLES" : undef);
}

sub check_for_plugin {
  my ($reporter, $plugin)= @_;
  unless ($plugins{$plugin}) {
    my $plg;
    eval {
        $plg= $conn->get_column("SELECT lower(plugin_name) FROM INFORMATION_SCHEMA.PLUGINS WHERE PLUGIN_STATUS = 'ACTIVE'");
        # Can't return res from here, because if it's 0, the "or" block will be executed
        1;
    } or do {
      sayWarning("FeatureUsage got an error: ".$conn->last_error->[0]." (".$conn->last_error->[1].") for PLUGINS query");
    };
    if ($plg) {
      map { $plugins{$_}= 1 } (@$plg);
    }
  }
  return ($plugins{lc($plugin)} ? return "according to I_S.PLUGINS" : undef);
}

sub check_system_var {
  my ($reporter, $var)= @_;
  if($reporter->getval("SELECT IF(VARIABLE_VALUE = 'OFF',0,1) FROM INFORMATION_SCHEMA.GLOBAL_VARIABLES WHERE VARIABLE_NAME='".$var."'")) {
    return "according to I_S.GLOBAL_VARIABLES";
  }
  return undef;
}

sub check_status_var {
  my ($reporter, $var)= @_;
  if (scalar(keys %global_status) == 0) {
    my $global_status_arr;
    eval {
        $global_status_arr= $conn->query("SELECT VARIABLE_NAME, VARIABLE_VALUE FROM INFORMATION_SCHEMA.GLOBAL_STATUS");
        # Can't return res from here, because if it's 0, the "or" block will be executed
        1;
    } or do {
      sayWarning("FeatureUsage got an error: ".$conn->last_error->[0]." (".$conn->last_error->[1].") for GLOBAL STATUS query");
    };
    foreach (@$global_status_arr) {
      $global_status{$_->[0]}= $_->[1];
    }
  }
  return ($global_status{uc($var)} ? "according to I_S.GLOBAL_STATUS" : undef);
}

sub getval {
  my ($reporter, $query)= @_;
  my $res;
  eval {
      $res= $conn->get_value($query,1,1);
      # Can't return res from here, because if it's 0, the "or" block will be executed
      1;
  } or do {
    sayWarning("FeatureUsage got an error: ".$conn->last_error->[0]." (".$conn->last_error->[1].") for query $query");
  };
  return $res;
}

# End of checkers/helpers
#################

sub type {
  return REPORTER_TYPE_ALWAYS | REPORTER_TYPE_PERIODIC;
}

1;

