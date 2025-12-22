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
  $options{test_common_option_combinations}, # seed, reporters
  $options{test_concurrency_combinations},   # threads and timeouts
  $options{gendata},
# Disabled for now, too frequent DBD problems
#  $options{optional_ps_protocol},

  [ '--mysqld=--log_bin --mysqld=--binlog_storage_engine=innodb',
    '--mysqld=--log_bin --mysqld=--binlog_storage_engine=innodb --mysqld=--max_binlog_size=32M',
    '--mysqld=--log_bin --mysqld=--binlog_storage_engine=innodb',
    '--mysqld=--log_bin'
  ],
  [ '--mysqld=--binlog-directory=binlogs --mysqld=--ignore-db-dirs=binlogs',
    ''
  ],
  $options{optional_binlog_safe_variables},
  [ '--filter=conf/preview/new_binlog.ff' ],

  [ '--grammar=conf/yy/xa.yy', '', '', '' ],
  [ '--grammar=conf/yy/admin.yy', '', '' ],
  [ '--grammar=conf/yy/bulk_insert.yy', '', '' ],
  [ '--grammar=conf/yy/dml.yy', '', '' ],
  [ '--grammar=conf/preview/server_domain_id.yy:0.05', '', '', '', '', '' ],
  [ '--reporter=PurgeBinaryLogs', '', '', '', '' ],
  [ '--reporter=ResetMaster', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '' ],

  [
    '--mysqld=--plugin-load-add=ha_spider --mysqld=--loose-spider-same-server-link=on --mysqld=--loose-spider_table_crd_thread_count=1 --mysqld=--loose-spider_table_sts_thread_count=1 --grammar=conf/yy/engine-spider.yy',
    '', ''
  ],
  [
     '--engine=RocksDB --grammar=conf/yy/engine-rocksdb.yy --mysqld=--default-storage-engine=RocksDB --mysqld=--plugin-load-add=ha_rocksdb',
     '--engine=RocksDB --grammar=conf/yy/engine-rocksdb.yy --mysqld=--default-storage-engine=RocksDB --mysqld=--plugin-load-add=ha_rocksdb --mysqld=--transaction-isolation=READ-COMMITTED',
     '','','',
     '--mysqld=--transaction-isolation=READ-UNCOMMITTED --grammar=conf/yy/transaction.yy',
     '--mysqld=--transaction-isolation=SERIALIZABLE --grammar=conf/yy/transaction.yy',
     '--mysqld=--transaction-isolation=READ-COMMITTED --grammar=conf/yy/transaction.yy',
     '--mysqld=--transaction-isolation=REPEATABLE-READ --grammar=conf/yy/transaction.yy',
  ],
  [
    '--scenario=Replication --reporter=ReplicationStartUntil --scenario-use-gtid --filter=conf/ff/replication.ff',
    '--scenario=Replication --reporter=ReplicationStartUntil --scenario-use-gtid --filter=conf/ff/replication.ff',
    '--scenario=Replication --reporter=ReplicationStartUntil --scenario-use-gtid --filter=conf/ff/replication.ff',
    '--scenario=Replication --reporter=ReplicationStartUntil --scenario-use-gtid --filter=conf/ff/replication.ff',
    '--scenario=Replication --reporter=ReplicationStartUntil --scenario-use-gtid --filter=conf/ff/replication.ff',
    '--scenario=Replication --scenario-nosync --scenario-use-gtid --filter=conf/ff/replication.ff',
    '--scenario=Replication --scenario-nosync --scenario-use-gtid --filter=conf/ff/replication.ff',
    '--scenario=Replication --scenario-nosync --scenario-use-gtid --filter=conf/ff/replication.ff',
    '--scenario=Replication --scenario-use-gtid --filter=conf/ff/replication.ff',
    '--scenario=Replication --scenario-use-gtid --filter=conf/ff/replication.ff',
    '--scenario=Replication --scenario-use-gtid --filter=conf/ff/replication.ff',
    '--scenario=Replication --scenario-primary-crash-recovery --scenario-use-gtid --filter=conf/ff/replication.ff --mysqld=--binlog_storage_engine=innodb',
    '--scenario=Replication --scenario-primary-crash-recovery --scenario-use-gtid --filter=conf/ff/replication.ff --mysqld=--binlog_storage_engine=innodb',
    '--scenario=Replication --scenario-primary-crash-recovery --scenario-use-gtid --filter=conf/ff/replication.ff --mysqld=--binlog_storage_engine=innodb',
    '--scenario=Standard --reporter=BinlogDump --filter=conf/ff/replication.ff',
    '--scenario=Restart --reporter=BinlogDump --filter=conf/ff/replication.ff',
    '--scenario=CrashRecovery --reporter=BinlogDump --filter=conf/ff/replication.ff',
    '--scenario=CrashRecovery --reporter=BinlogDump --filter=conf/ff/replication.ff',
#    '--scenario=AtomicDDL --reporter=BinlogDump --filter=conf/ff/replication.ff',
    '--scenario=MariaBackupFull --reporter=BinlogDump --filter=conf/ff/replication.ff',
    '--scenario=MariaBackupIncremental --reporter=BinlogDump --filter=conf/ff/replication.ff',
    '--scenario=NormalUpgrades --reporter=BinlogDump --filter=conf/ff/replication.ff',
  ],

  ##### Engines and scenarios
  [
    {
      acl => [
        [ '--grammar=conf/yy/acl.yy', '--grammar=conf/yy/create_user.yy'],
        ['
          --mysqld=--plugin-load-add=auth_0x0100.so
          --mysqld=--plugin-load-add=auth_ed25519.so
          --mysqld=--plugin-load-add=auth_pam.so
          --mysqld=--plugin-load-add=password_reuse_check.so
          --mysqld=--plugin-load-add=cracklib_password_check.so
          --mysqld=--plugin-load-add=simple_password_check.so
          --mysqld=--loose-password-reuse-check-interval=1
        '],
        $options{engine_basic_combinations},
        $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_charsets_safe},
        $options{optional_variators},
        $options{optional_server_variables},
      ],
      aria => [
        [ '--engine=Aria --mysqld=--default-storage-engine=Aria' ],
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_variators},
        $options{optional_server_variables},
        $options{optional_aria_variables},
      ],
      bigbang => [
        $options{optional_gendata_views},
        $options{optional_gendata_vcols},
        $options{optional_gendata_gis},
        $options{optional_gendata_unique_hash_keys},
        $options{engine_basic_combinations}, $options{engine_extra_supported_combinations}, $options{engine_full_mix_combinations},
        $options{optional_charsets_safe}, $options{optional_charsets_unsafe},
        $options{optional_encryption},
        $options{optional_binlog_unsafe_variables},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars}, $options{debug_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      bigbang_with_custom_config => [
        $options{custom_options_1},
        $options{custom_options_1_master},
        $options{optional_gendata_views},
        $options{optional_gendata_vcols},
        $options{optional_gendata_gis},
        $options{optional_gendata_unique_hash_keys},
        $options{engine_basic_combinations}, $options{engine_extra_supported_combinations}, $options{engine_full_mix_combinations},
        $options{optional_charsets_safe}, $options{optional_charsets_unsafe},
        $options{optional_encryption},
        $options{optional_binlog_unsafe_variables},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars}, $options{debug_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      binlog => [
        $options{engine_basic_combinations}, $options{engine_extra_supported_combinations}, $options{engine_full_mix_combinations},
        $options{optional_charsets_safe}, $options{optional_charsets_unsafe},
        $options{optional_encryption},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars}, $options{debug_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        # We don't care about binlog safety here, because we are not checking consistency
        $options{optional_binlog_safe_variables}, $options{optional_binlog_unsafe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_server_variables},
      ],
      custom => [
        [ '--engine=InnoDB,Aria' ],
        [ '--variator=ExecuteAsOracleSP', '' ],
        [ '--variator=ExecuteAsPackageSP', '' ],
        $options{custom_options_1},
        $options{custom_options_1_master},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
      ],
      custom_recovery => [
        [ '--engine=InnoDB' ],
        [ '--variator=ExecuteAsOracleSP', '' ],
        [ '--variator=ExecuteAsPackageSP', '' ],
        $options{custom_options_1},
        $options{custom_options_1_master},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
      ],
      custom_rpl => [
        [ '--engine=InnoDB' ],
        [ '--variator=ExecuteAsOracleSP', '' ],
        [ '--variator=ExecuteAsPackageSP', '' ],
        [ '--grammar=conf/yy/dml.yy' ],
        $options{custom_options_1},
        $options{custom_options_1_master},
        $options{custom_options_1_slave},
        $options{dml_grammars}, $options{ddl_grammars},
      ],
      custom_unique_hash => [
        [ '--engine=InnoDB' ],
        [ '--gendata=advanced --unique-hash-keys --gendata=conf/zz/blobs.zz --grammar=conf/yy/indexes_and_constraints.yy' ],
        $options{custom_options_1},
        $options{custom_options_1_master},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
      ],
      encryption => [
        [ '--engine=InnoDB,Aria' ],
        [ '--grammar=conf/yy/dml.yy' ],
        $options{key_management_hash},
        [ '
            --mysqld=--innodb-encrypt-tables
            --mysqld=--innodb-encrypt-log
            --mysqld=--innodb-encryption-threads=4
            --mysqld=--aria-encrypt-tables=1
            --mysqld=--encrypt-tmp-disk-tables=1
            --mysqld=--encrypt-tmp-files=1
        '],
        $options{optional_gendata_views},
        $options{optional_charsets_safe},
        $options{optional_binlog_unsafe_variables},
        $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars}, $options{debug_grammars},
        $options{optional_variators},
        $options{optional_server_variables},
      ],
      galera => [
        [ '--engine=InnoDB' ],
        $options{optional_charsets_safe},
        $options{optional_encryption},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      gis => [
        [ '--gendata=advanced --gis'],
        [ '--grammar=conf/yy/gis.yy --grammar=conf/yy/alter_table.yy'],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_server_variables},
      ],
      index => [
        [ '--reporters=SecondaryIndexConsistency' ],
        [ '--grammar=conf/yy/many_indexes.yy' ],
        $options{engine_basic_combinations}, $options{engine_extra_supported_combinations},
        $options{optional_charsets_safe},
        $options{optional_encryption},
        $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars}, $options{debug_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      innodb => [
        [ '--engine=InnoDB' ],
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_variators},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_server_variables},
      ],
      innodb_compression => [
        [ '--engine=InnoDB' ],
        [ '--grammar=conf/yy/innodb_compression_algorithms.yy'],
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_variators},
        $options{mandatory_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_server_variables},
      ],
      innodb_pagesize => [
        [ '--engine=InnoDB' ],
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_variators},
        $options{optional_innodb_compression},
        {
            pagesize4k => '--mysqld=--innodb_page_size=4K',
            pagesize8k => '--mysqld=--innodb_page_size=8K',
            pagesize32k => '--mysqld=--innodb_page_size=32K',
            pagesize64k => '--mysqld=--innodb_page_size=64K'
        },
        $options{optional_innodb_variables},
        $options{optional_server_variables},
      ],
      innodb_recovery => [
        [ '--engine=InnoDB' ],
        [ '--filter=conf/ff/restrict_dynamic_vars.ff' ],
        $options{optional_charsets_safe},
        $options{optional_encryption},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      json => [
        $options{engine_basic_combinations},
        [ '--grammar=conf/yy/json.yy --variator=JsonTables' ],
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_server_variables},
      ],
      locking => [
        [ '--grammar=conf/yy/backup-locks.yy --grammar=conf/yy/locks.yy' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_server_variables},
      ],
      minimal => [
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
      ],
      mixed_flow => [
        $options{optional_gendata_views},
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{optional_binlog_unsafe_variables},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars}, $options{debug_grammars},
        $options{optional_variators},
        $options{optional_server_variables},
      ],
      optimizer => [
        ['
          --gendata=conf/zz/range_access.zz
          --grammar=conf/yy/analyze_select_single_table.yy
          --grammar=conf/yy/collect_eits.yy
          --grammar=conf/yy/optimizer_access_exp.yy
          --grammar=conf/yy/optimizer_costs.yy
          --grammar=conf/yy/optimizer_trace.yy
          --grammar=conf/yy/optimizer_vars.yy
          --grammar=conf/yy/range_access2.yy
          --grammar=conf/yy/range_access.yy
          --grammar=conf/yy/window_functions.yy
        '],
        $options{optional_variators},
        $options{optional_gendata_views},
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{optional_server_variables},
      ],
      partitions => [
        [ '--grammar=conf/yy/partition_by_hash.yy  --grammar=conf/yy/partition_by_list.yy  --grammar=conf/yy/partition_by_range.yy  --grammar=conf/yy/partition-dml.yy' ],
        [ '--gendata=conf/zz/partition_by_columns.zz --gendata=advanced --partitions' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_server_variables},
      ],
      perfschema => [
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_server_variables},
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
      plugins => [
        ['
          --grammar=conf/yy/query_response_time.yy
          --mysqld=--plugin-load-add=query_response_time
          --mysqld=--loose-query-response-time
          --grammar=conf/yy/plugin-query_cache_info.yy
          --mysqld=--plugin-load-add=query_cache_info
          --mysqld=--loose-query-cache-info
          --mysqld=--query-cache-type=1
          --grammar=conf/yy/query_response_time.yy
          --mysqld=--plugin-load-add=query_response_time
          --mysqld=--loose-query-response-time
          --grammar=conf/yy/metadata_lock_info.yy
          --mysqld=--plugin-load-add=metadata_lock_info
          --mysqld=--loose-metadata-lock-info
          --grammar=conf/yy/locales.yy
          --mysqld=--plugin-load-add=locales
          --mysqld=--loose-locales
          --grammar=conf/yy/disks.yy
          --mysqld=--plugin-load-add=disks
          --mysqld=--loose-disks
          --grammar=conf/yy/sql_errlog.yy
          --mysqld=--plugin-load-add=sql_errlog
          --mysqld=--loose-sql-error-log
        '],
        $options{engine_basic_combinations},
        $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_charsets_safe},
        $options{optional_variators},
        $options{optional_server_variables},
      ],
      ps_sp => [
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        [ '--variator=ExecuteAsExecuteImmediate --variator=ExecuteAsFunctionTwice --variator=ExecuteAsPreparedThrice --variator=ExecuteAsPSWithParams --variator=ExecuteAsSPTwice --variator=ExecuteAsTrigger' ],
        $options{optional_server_variables},
      ],
      readonly => [
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars},
        $options{optional_variators},
        $options{optional_server_variables},
      ],
      recovery => [
        [ '--engine=InnoDB', '--engine=Aria --mysqld=--default-storage-engine=Aria', '--engine=InnoDB,Aria' ],
        [ '--filter=conf/ff/restrict_dynamic_vars.ff' ],
        [ '--grammar=conf/yy/dml.yy' ],
        $options{optional_charsets_safe},
        $options{optional_encryption},
        $options{dml_grammars}, $options{ddl_grammars}, $options{debug_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      replication => [
        [ '--grammar=conf/yy/replication.yy' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{optional_encryption},
        $options{optional_replication_safe_variables},
        $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      replication_mbr => [
        [ '--mysqld=--binlog-format=mixed' ],
        [ '--grammar=conf/yy/replication.yy' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{optional_replication_safe_variables},
        $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_server_variables},
      ],
      replication_rbr => [
        [ '--mysqld=--binlog-format=row' ],
        [ '--grammar=conf/yy/replication.yy' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{optional_replication_safe_variables},
        $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_server_variables},
      ],
      simple => [
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        [ '--variator=ExecuteAsPreparedTwice' ],
        $options{optional_server_variables},
      ],
      spider => [
        ['
          --mysqld=--plugin-load-add=ha_spider
          --mysqld=--loose-spider-same-server-link=on
          --mysqld=--loose-spider_table_crd_thread_count=1
          --mysqld=--loose-spider_table_sts_thread_count=1
          --grammar=conf/yy/engine-spider.yy
        '],
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_server_variables},
      ],
      unique_hash => [
        [ '--gendata=advanced --unique-hash-keys --gendata=conf/zz/blobs.zz --grammar=conf/yy/indexes_and_constraints.yy' ],
        [ '--engine=InnoDB,MyISAM' ],
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_server_variables},
      ],
      upgrade_backup => [
        [ '--filter=conf/ff/restrict_dynamic_vars.ff' ],
        [ '--grammar=conf/yy/dml.yy' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{optional_encryption},
        $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      views => [
        $options{engine_basic_combinations},
        [ '--gendata=advanced', '--gendata=simple --grammar=conf/yy/views.yy' ],
        [ '--views', '--views=MERGE', '--views=TEMPTABLE' ],
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        [ '--variator=ConvertSubqueriesToViews --variator=ExecuteAsView' ],
        $options{optional_server_variables},
      ],
      virtual_columns => [
        [ '--gendata=advanced' ],
        [ '--grammar=conf/yy/virtual_columns.yy' ],
        [ '--vcols', '--vcols=VIRTUAL', '--vcols=STORED' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_server_variables},
      ],
    }
  ],
];
