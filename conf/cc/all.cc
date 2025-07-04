# Copyright (c) 2022, 2025 MariaDB
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

use Data::Dumper;
use strict;

our (%parameters, %options);

require "$ENV{RQG_HOME}/conf/cc/include/parameter_presets";

# Choose options based on $version value
# ($version may be defined via config-version, otherwise 999999 will be used)
local @ARGV = ($version);
require "$ENV{RQG_HOME}/conf/cc/include/versioned_options.pl";

$combinations = [

# Test options
  [ @{$options{test_common_option_combinations}} ], # seed, reporters
  [ @{$options{test_concurrency_combinations}} ],   # threads and timeouts
  [ @{$options{gendata}} ],
# Disabled for now, too frequent DBD problems
#  [ @{$options{optional_ps_protocol}} ],

  ##### Engines and scenarios
  [
    {
      minimal => [
        [ '--scenario=Standard' ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
      ],
      simple => [
        [ '--scenario=Standard' ],
        [ @{$options{engine_basic_combinations}} ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
        [ @{$options{optional_variators}} ],
        [ @{$options{optional_binlog_safe_variables}} ],
        [ @{$options{optional_server_variables}} ],
      ],
      innodb => [
        [ '--scenario=Standard' ],
        [ '--engine=InnoDB' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}} ],
        [ @{$options{optional_variators}} ],
        [ @{$options{optional_binlog_safe_variables}} ],
        [ @{$options{optional_innodb_compression}} ],
        [ @{$options{optional_innodb_pagesize}} ],
        [ @{$options{optional_innodb_variables}} ],
        [ @{$options{optional_server_variables}} ],
      ],
      aria => [
        [ '--scenario=Standard' ],
        [ '--engine=Aria --mysqld=--default-storage-engine=Aria' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}} ],
        [ @{$options{optional_variators}} ],
        [ @{$options{optional_binlog_safe_variables}} ],
        [ @{$options{optional_server_variables}} ],
        [ @{$options{optional_aria_variables}} ],
      ],
      mix => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ @{$options{optional_gendata_views}} ],
        [ @{$options{optional_gendata_vcols}} ],
        [ @{$options{optional_gendata_gis}} ],
        [ @{$options{optional_gendata_unique_hash_keys}} ],
        [ @{$options{engine_basic_combinations}}, @{$options{engine_extra_supported_combinations}}, @{$options{engine_full_mix_combinations}} ],
        [ @{$options{optional_charsets_safe}}, @{$options{optional_charsets_unsafe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{optional_binlog_unsafe_variables}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}}, @{$options{debug_grammars}} ],
        [ @{$options{optional_variators}} ],
        [ @{$options{optional_aria_variables}} ],
        [ @{$options{optional_binlog_safe_variables}} ],
        [ @{$options{optional_innodb_compression}} ],
        [ @{$options{optional_innodb_pagesize}} ],
        [ @{$options{optional_innodb_variables}} ],
        [ @{$options{optional_perfschema}} ],
        [ @{$options{optional_server_variables}} ],
      ],
      gis => [
        [ '--scenario=Standard','--scenario=Replication --scenario-nosync' ],
        [ '--gendata=advanced --gis'],
        [ @{$options{engine_basic_combinations}} ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}} ],
        [ @{$options{optional_variators}} ],
        [ @{$options{optional_aria_variables}} ],
        [ @{$options{optional_binlog_safe_variables}} ],
        [ @{$options{optional_innodb_compression}} ],
        [ @{$options{optional_innodb_pagesize}} ],
        [ @{$options{optional_innodb_variables}} ],
        [ @{$options{optional_server_variables}} ],
      ],
      perfschema => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ @{$options{engine_basic_combinations}} ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}} ],
        [ @{$options{optional_variators}} ],
        [ @{$options{optional_aria_variables}} ],
        [ @{$options{optional_binlog_safe_variables}} ],
        [ @{$options{optional_innodb_compression}} ],
        [ @{$options{optional_innodb_pagesize}} ],
        [ @{$options{optional_innodb_variables}} ],
        [ @{$options{optional_server_variables}} ],
        [ '--mysqld=--performance-schema=on --mysqld=--performance-schema-instrument="%=ON" --grammar=conf/yy/performance_schema.yy' ],
        [ '--mysqld=--performance-schema-consumer-events-stages-current=ON', '--mysqld=--performance-schema-consumer-events-stages-history=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-stages-history-long=ON', '--mysqld=--performance-schema-consumer-events-stages-history-long=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-stages-history-long=ON', '--mysqld=--performance-schema-consumer-events-stages-history-long=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-statements-current=ON', '--mysqld=--performance-schema-consumer-events-statements-current=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-statements-history=ON', '--mysqld=--performance-schema-consumer-events-statements-history=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-statements-history-long=ON', '--mysqld=--performance-schema-consumer-events-statements-history-long=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-waits-current=ON', '--mysqld=--performance-schema-consumer-events-waits-current=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-waits-history=ON', '--mysqld=--performance-schema-consumer-events-waits-history=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-waits-history-long=ON', '--mysqld=--performance-schema-consumer-events-waits-history-long=OFF' ],
        [ '--mysqld=--performance-schema-consumer-global-instrumentation=ON', '--mysqld=--performance-schema-consumer-global-instrumentation=OFF' ],
        [ '--mysqld=--performance-schema-consumer-thread-instrumentation=ON', '--mysqld=--performance-schema-consumer-thread-instrumentation=OFF' ],
        [ '--mysqld=--performance-schema-consumer-statements-digest=ON', '--mysqld=--performance-schema-consumer-statements-digest=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-transactions-current=ON', '--mysqld=--performance-schema-consumer-events-transactions-current=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-transactions-history=ON', '--mysqld=--performance-schema-consumer-events-transactions-history=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-transactions-history-long=ON', '--mysqld=--performance-schema-consumer-events-transactions-history-long=OFF' ],
      ],
      unique_hash => [
        [ '--scenario=Standard','--scenario=Replication --scenario-nosync' ],
        [ '--gendata=advanced --unique-hash-keys'],
        [ @{$options{engine_basic_combinations}} ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}} ],
        [ @{$options{optional_variators}} ],
        [ @{$options{optional_aria_variables}} ],
        [ @{$options{optional_binlog_safe_variables}} ],
        [ @{$options{optional_innodb_compression}} ],
        [ @{$options{optional_innodb_pagesize}} ],
        [ @{$options{optional_innodb_variables}} ],
        [ @{$options{optional_server_variables}} ],
      ],
      virtual_columns => [
        [ '--scenario=Standard','--scenario=Replication --scenario-nosync' ],
        [ '--gendata=advanced' ],
        [ '--vcols', '--vcols=VIRTUAL', '--vcols=STORED' ],
        [ @{$options{engine_basic_combinations}} ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}} ],
        [ @{$options{optional_variators}} ],
        [ @{$options{optional_aria_variables}} ],
        [ @{$options{optional_binlog_safe_variables}} ],
        [ @{$options{optional_innodb_compression}} ],
        [ @{$options{optional_innodb_pagesize}} ],
        [ @{$options{optional_innodb_variables}} ],
        [ @{$options{optional_server_variables}} ],
      ],
      binlog => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ '--reporter=BinlogDump' ],
        [ '--mysqld=--log-bin' ],
        [ @{$options{engine_basic_combinations}}, @{$options{engine_extra_supported_combinations}}, @{$options{engine_full_mix_combinations}} ],
        [ @{$options{optional_charsets_safe}}, @{$options{optional_charsets_unsafe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}}, @{$options{debug_grammars}} ],
        [ @{$options{optional_variators}} ],
        [ @{$options{optional_aria_variables}} ],
        # We don't care about binlog safety here, because we are not checking consistency
        [ @{$options{optional_binlog_safe_variables}}, @{$options{optional_binlog_unsafe_variables}} ],
        [ @{$options{optional_innodb_compression}} ],
        [ @{$options{optional_innodb_pagesize}} ],
        [ @{$options{optional_innodb_variables}} ],
        [ @{$options{optional_server_variables}} ],
      ],
      index => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ '--reporters=SecondaryIndexConsistency' ],
        [ @{$options{engine_basic_combinations}}, @{$options{engine_extra_supported_combinations}} ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}}, @{$options{debug_grammars}} ],
        [ @{$options{optional_variators}} ],
        [ @{$options{optional_aria_variables}} ],
        [ @{$options{optional_binlog_safe_variables}} ],
        [ @{$options{optional_innodb_compression}} ],
        [ @{$options{optional_innodb_pagesize}} ],
        [ @{$options{optional_innodb_variables}} ],
        [ @{$options{optional_perfschema}} ],
        [ @{$options{optional_server_variables}} ],
      ],
      recovery => [
        [ @{$options{scenario_crash_combinations}} ],
        [ '--engine=InnoDB', '--engine=Aria --mysqld=--default-storage-engine=Aria', '--engine=InnoDB,Aria' ],
        [ '--filter=conf/ff/restrict_dynamic_vars.ff' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{debug_grammars}} ],
        [ @{$options{optional_variators}} ],
        [ @{$options{optional_aria_variables}} ],
        [ @{$options{optional_binlog_safe_variables}} ],
        [ @{$options{optional_innodb_compression}} ],
        [ @{$options{optional_innodb_pagesize}} ],
        [ @{$options{optional_innodb_variables}} ],
        [ @{$options{optional_perfschema}} ],
        [ @{$options{optional_server_variables}} ],
      ],
      innodb_recovery => [
        [ @{$options{scenario_crash_combinations}} ],
        [ '--engine=InnoDB' ],
        [ '--filter=conf/ff/restrict_dynamic_vars.ff' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
        [ @{$options{optional_variators}} ],
        [ @{$options{optional_aria_variables}} ],
        [ @{$options{optional_binlog_safe_variables}} ],
        [ @{$options{optional_innodb_compression}} ],
        [ @{$options{optional_innodb_pagesize}} ],
        [ @{$options{optional_innodb_variables}} ],
        [ @{$options{optional_perfschema}} ],
        [ @{$options{optional_server_variables}} ],
      ],
      upgrade_backup => [
        [ @{$options{scenario_mariabackup_combinations}}, @{$options{scenario_upgrade_combinations}} ],
        [ '--filter=conf/ff/restrict_dynamic_vars.ff' ],
        [ @{$options{engine_basic_combinations}} ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
        [ @{$options{optional_variators}} ],
        [ @{$options{optional_aria_variables}} ],
        [ @{$options{optional_binlog_safe_variables}} ],
        [ @{$options{optional_innodb_compression}} ],
        [ @{$options{optional_innodb_pagesize}} ],
        [ @{$options{optional_innodb_variables}} ],
        [ @{$options{optional_perfschema}} ],
        [ @{$options{optional_server_variables}} ],
      ],
      replication => [
        [ @{$options{scenario_replication_combinations}} ],
        [ '--filter=conf/ff/replication.ff' ],
        [ @{$options{engine_basic_combinations}} ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{optional_replication_safe_variables}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
        [ @{$options{optional_variators}} ],
        [ @{$options{optional_aria_variables}} ],
        [ @{$options{optional_binlog_safe_variables}} ],
        [ @{$options{optional_innodb_compression}} ],
        [ @{$options{optional_innodb_pagesize}} ],
        [ @{$options{optional_innodb_variables}} ],
        [ @{$options{optional_perfschema}} ],
        [ @{$options{optional_server_variables}} ],
      ],
      galera => [
        [ '--scenario=Galera' ],
        [ '--filter=conf/ff/replication.ff' ],
        [ '--engine=InnoDB' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
        [ @{$options{optional_variators}} ],
        [ @{$options{optional_aria_variables}} ],
        [ @{$options{optional_binlog_safe_variables}} ],
        [ @{$options{optional_innodb_compression}} ],
        [ @{$options{optional_innodb_pagesize}} ],
        [ @{$options{optional_innodb_variables}} ],
        [ @{$options{optional_perfschema}} ],
        [ @{$options{optional_server_variables}} ],
      ],
      custom => [
        [ '--scenario=Standard' ],
        [ '--engine=InnoDB' ],
        [ '--genconfig=conf/cnf/custom1-master.cnf --mysqld=--innodb-buffer-pool-size=2G' ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
      ],
      custom_rpl => [
        [ '--scenario=Replication' ],
        [ '--engine=InnoDB' ],
        [ '--filter=conf/ff/replication.ff --server1-genconfig=conf/cnf/custom1-master.cnf --server2-genconfig=conf/cnf/custom1-slave.cnf --mysqld=--innodb-buffer-pool-size=1G' ],
        [ @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
      ],
      custom_recovery => [
        [ '--scenario=CrashRecovery' ],
        [ '--engine=InnoDB' ],
        [ '--genconfig=conf/cnf/custom1-master.cnf --mysqld=--innodb-buffer-pool-size=2G' ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
      ],
    }
  ],
];
