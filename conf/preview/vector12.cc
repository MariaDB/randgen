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

# New
  [ '--grammar=conf/yy/vector.yy:3 --gendata=data/sql/vector_gist_960_1K.sql --gendata=data/sql/vector_deep_image_96_10K.sql' ],
  [ '--mysqld=--mhnsw_max_cache_size=128M', '--mysqld=--mhnsw_max_cache_size=8G', '--mysqld=--mhnsw_max_cache_size=4G', '--mysqld=--mhnsw_max_cache_size=1G', '--mysqld=--mhnsw_max_cache_size=1M' ],
  [ '--mysqld=--mhnsw_default_m=3', '--mysqld=--mhnsw_default_m=4', '--mysqld=--mhnsw_default_m=20', '--mysqld=--mhnsw_default_m=100', '', '' ],
  [ '--mysqld=--mhnsw_ef_search=1', '--mysqld=--mhnsw_ef_search=2', '--mysqld=--mhnsw_ef_search=5', '--mysqld=--mhnsw_ef_search=10', '--mysqld=--mhnsw_ef_search=20', '--mysqld=--mhnsw_ef_search=100', '--mysqld=--mhnsw_ef_search=200', '--mysqld=--mhnsw_ef_search=4096', '--mysqld=--mhnsw_ef_search=65535', '' ],
  [ '--mysqld=--mhnsw_default_distance=euclidean', '--mysqld=--mhnsw_default_distance=cosine' ],

  ##### Engines and scenarios
  [
    {
      aria => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Standard' ],
        [ '--engine=Aria --mysqld=--default-storage-engine=Aria' ],
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_variators},
        $options{optional_binlog_safe_variables},
        $options{optional_server_variables},
        $options{optional_aria_variables},
      ],
      bigbang => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Standard', '--scenario=Restart' ],
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
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      bigbang_with_custom_config => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Standard', '--scenario=Restart' ],
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
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      binlog => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ '--reporter=BinlogDump' ],
        [ '--mysqld=--log-bin' ],
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
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Standard' ],
        [ '--engine=InnoDB,Aria' ],
        [ '--variator=ExecuteAsOracleSP', '' ],
        [ '--variator=ExecuteAsPackageSP', '' ],
        $options{custom_options_1_master},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
      ],
      custom_rpl => [
        [ '--scenario=Replication' ],
        [ ''. '--scenario-nosync'  ],
        [ '--engine=InnoDB' ],
        [ '--variator=ExecuteAsOracleSP', '' ],
        [ '--variator=ExecuteAsPackageSP', '' ],
        [ '--grammar=conf/yy/dml.yy' ],
        [ '--filter=conf/ff/replication.ff' ],
        $options{custom_options_1_master},
        $options{custom_options_1_slave},
        $options{dml_grammars}, $options{ddl_grammars},
      ],
      encryption => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Standard', '--scenario=CrashRecovery' ],
        [ '--engine=InnoDB,Aria' ],
        {
          file_key_management => '--mysqld=--file-key-management --mysqld=--file-key-management-filename='.$ENV{RQG_HOME}.'/util/file_key_management_keys.txt --mysqld=--plugin-load-add=file_key_management',
          hashicorp => '--hashicorp --mysqld=--plugin-load-add=hashicorp_key_management --mysqld=--hashicorp-key-management'
        },
        [ '
            --mysqld=--log-bin
            --mysqld=--innodb-encrypt-tables
            --mysqld=--innodb-encrypt-log
            --mysqld=--innodb-encryption-threads=4
            --mysqld=--aria-encrypt-tables=1
            --mysqld=--encrypt-tmp-disk-tables=1
            --mysqld=--encrypt-tmp-files=1
            --mysqld=--encrypt-binlog
        '],
        $options{optional_gendata_views},
        $options{optional_charsets_safe},
        $options{optional_binlog_unsafe_variables},
        $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars}, $options{debug_grammars},
        $options{optional_variators},
        $options{optional_binlog_safe_variables},
        $options{optional_server_variables},
      ],
      galera => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Galera' ],
        [ '--filter=conf/ff/replication.ff' ],
        [ '--engine=InnoDB' ],
        $options{optional_charsets_safe},
        $options{optional_encryption},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      innodb => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ '--engine=InnoDB' ],
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_variators},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_server_variables},
      ],
      innodb_compression => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Standard' ],
        [ '--engine=InnoDB' ],
        [ '--grammar=conf/yy/innodb_compression_algorithms.yy'],
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_variators},
        $options{optional_binlog_safe_variables},
        $options{mandatory_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_server_variables},
      ],
      innodb_pagesize => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Standard' ],
        [ '--engine=InnoDB' ],
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_variators},
        $options{optional_binlog_safe_variables},
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
        [ ' --grammar=conf/yy/functions.yy:2' ],
        $options{scenario_crash_combinations},
        [ '--engine=InnoDB' ],
        [ '--filter=conf/ff/restrict_dynamic_vars.ff' ],
        $options{optional_charsets_safe},
        $options{optional_encryption},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      innodb_trx_isolation => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Standard', '--scenario=Restart', '--scenario=CrashRecovery' ],
        [ '--engine=InnoDB' ],
        [ '--grammar=conf/yy/transaction.yy' ],
        {
          uncommitted => '--mysqld=--transaction-isolation=READ-UNCOMMITTED',
          committed => '--mysqld=--transaction-isolation=READ-COMMITTED',
          serializable => '--mysqld=--transaction-isolation=SERIALIZABLE'
        },
        $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_charsets_safe},
        $options{optional_variators},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_server_variables},
      ],
      locking => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ '--grammar=conf/yy/backup-locks.yy --grammar=conf/yy/locks.yy' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_binlog_safe_variables},
        $options{optional_server_variables},
      ],
      minimal => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Standard' ],
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
      ],
      mixed_flow => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Standard', '--scenario=Restart' ],
        $options{optional_gendata_views},
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{optional_binlog_unsafe_variables},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars}, $options{debug_grammars},
        $options{optional_variators},
        $options{optional_binlog_safe_variables},
        $options{optional_server_variables},
      ],
      optimizer => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Standard' ],
        ['
          --variator=AnalyzeOrExplain
          --variator=DisableOptimizations
          --variator=EnableOptimizations
          --variator=ExecuteAsCTE
          --variator=ExecuteAsDerived
          --variator=ExecuteAsExcept
          --variator=ExecuteAsExecuteImmediate
          --variator=ExecuteAsIntersect
          --variator=ExecuteAsPreparedThrice
          --variator=ExecuteAsSPTwice
          --variator=ExecuteAsUnion
          --variator=ExecuteAsWhereSubquery
        '],
        $options{optional_gendata_views},
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{optional_server_variables},
      ],
      perfschema => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Standard', '--scenario=Restart' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
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
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Standard', '--scenario=Restart' ],
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
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Standard', '--scenario=Restart' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        [ '--variator=ExecuteAsExecuteImmediate --variator=ExecuteAsFunctionTwice --variator=ExecuteAsPreparedThrice --variator=ExecuteAsPSWithParams --variator=ExecuteAsSPTwice --variator=ExecuteAsTrigger' ],
        $options{optional_binlog_safe_variables},
        $options{optional_server_variables},
      ],
      readonly => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Standard' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars},
        [ '', '--variator=AnalyzeOrExplain' ],
        [ '', '--variator=ConvertLiteralsToVariables' ],
        [ '', '--variator=Count' ],
        [ '', '--variator=DisableOptimizations' ],
        [ '', '--variator=Distinct' ],
        [ '', '--variator=EnableOptimizations' ],
        [ '', '--variator=ExecuteAsCTE' ],
        [ '', '--variator=ExecuteAsDerived' ],
        [ '', '--variator=ExecuteAsExcept' ],
        [ '', '--variator=ExecuteAsIntersect' ],
        [ '', '--variator=ExecuteAsSelectItem' ],
        [ '', '--variator=ExecuteAsUnion' ],
        [ '', '--variator=ExecuteAsWhereSubquery' ],
        [ '', '--variator=FullOrderBy' ],
        [ '', '--variator=Having' ],
        [ '', '--variator=InlineSubqueries' ],
        [ '', '--variator=LimitDecrease' ],
        [ '', '--variator=LimitIncrease' ],
        [ '', '--variator=LimitRowsExamined' ],
        [ '', '--variator=NullIf' ],
        [ '', '--variator=OrderBy' ],
        [ '', '--variator=RemoveIndexHints' ],
        [ '', '--variator=SelectOption' ],
        $options{optional_server_variables},
      ],
      replication => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        $options{scenario_replication_combinations},
        [ ''. '--scenario-nosync'  ],
        [ '--grammar=conf/yy/replication.yy --filter=conf/ff/replication.ff' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{optional_encryption},
        $options{optional_replication_safe_variables},
        $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      replication_mbr => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        $options{scenario_replication_combinations},
        [ '--mysqld=--log-bin --mysqld=--binlog-format=mixed' ],
        [ '--grammar=conf/yy/replication.yy --filter=conf/ff/replication.ff' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{optional_replication_safe_variables},
        $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_server_variables},
      ],
      replication_rbr => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        $options{scenario_replication_combinations},
        [ '--mysqld=--log-bin --mysqld=--binlog-format=row' ],
        [ '--grammar=conf/yy/replication.yy --filter=conf/ff/replication.ff' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{optional_replication_safe_variables},
        $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_server_variables},
      ],
      simple => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Standard' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        [ '--variator=ExecuteAsPreparedTwice' ],
        $options{optional_binlog_safe_variables},
        $options{optional_server_variables},
      ],
      upgrade_backup => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        $options{scenario_mariabackup_combinations}, $options{scenario_upgrade_combinations},
        [ '--filter=conf/ff/restrict_dynamic_vars.ff' ],
        [ '--grammar=conf/yy/dml.yy' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{optional_encryption},
        $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      views => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Standard' ],
        $options{engine_basic_combinations},
        [ '--gendata=advanced', '--gendata=simple --grammar=conf/yy/views.yy' ],
        [ '--views', '--views=MERGE', '--views=TEMPTABLE' ],
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        [ '--variator=ConvertSubqueriesToViews --variator=ExecuteAsView' ],
        $options{optional_binlog_safe_variables},
        $options{optional_server_variables},
      ],
      virtual_columns => [
        [ ' --grammar=conf/yy/functions.yy:2' ],
        [ '--scenario=Standard','--scenario=Replication --scenario-nosync' ],
        [ '--gendata=advanced' ],
        [ '--grammar=conf/yy/virtual_columns.yy' ],
        [ '--vcols', '--vcols=VIRTUAL', '--vcols=STORED' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_server_variables},
      ],
    }
  ],
];
