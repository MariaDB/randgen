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
  [ '--mysqld=--metadata-locks-instances=1','--mysqld=--metadata-locks-instances=2','--mysqld=--metadata-locks-instances=8','--mysqld=--metadata-locks-instances=64','--mysqld=--metadata-locks-instances=127','--mysqld=--metadata-locks-instances=128' ],
  [ '--grammar=conf/yy/backup-locks.yy:0.5', '--grammar=conf/yy/locks.yy:0.5', '--grammar=conf/yy/admin.yy:0.5' ],

  ##### Engines and scenarios
  [
    {
      acl => [
        [ '--scenario=Standard', '--scenario=Restart' ],
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
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ '--genconfig=conf/cnf/custom1-master.cnf --mysqld=--innodb-buffer-pool-size=2G' ],
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
        [ '--scenario=Standard' ],
        [ '--engine=InnoDB,Aria' ],
        [ '--genconfig=conf/cnf/custom1-master.cnf --mysqld=--innodb-buffer-pool-size=2G' ],
        [ '--variator=ExecuteAsOracleSP', '' ],
        [ '--variator=ExecuteAsPackageSP', '' ],
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
      ],
      custom_recovery => [
        [ '--scenario=CrashRecovery' ],
        [ '--engine=InnoDB' ],
        [ '--variator=ExecuteAsOracleSP', '' ],
        [ '--variator=ExecuteAsPackageSP', '' ],
        [ '--genconfig=conf/cnf/custom1-master.cnf --mysqld=--innodb-buffer-pool-size=2G' ],
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
      ],
      custom_rpl => [
        [ '--scenario=Replication' ],
        [ '--engine=InnoDB' ],
        [ '--variator=ExecuteAsOracleSP', '' ],
        [ '--variator=ExecuteAsPackageSP', '' ],
        [ '--grammar=conf/yy/dml.yy' ],
        [ '--filter=conf/ff/replication.ff' ],
        [ '--server1-genconfig=conf/cnf/custom1-master.cnf --server2-genconfig=conf/cnf/custom1-slave.cnf --mysqld=--innodb-buffer-pool-size=1G' ],
        $options{dml_grammars}, $options{ddl_grammars},
      ],
      encryption => [
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
      gis => [
        [ '--scenario=Standard','--scenario=Replication --scenario-nosync' ],
        [ '--gendata=advanced --gis'],
        [ '--grammar=conf/yy/gis.yy --grammar=conf/yy/alter_table.yy'],
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
      index => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ '--reporters=SecondaryIndexConsistency' ],
        [ '--grammar=conf/yy/many_indexes.yy' ],
        $options{engine_basic_combinations}, $options{engine_extra_supported_combinations},
        $options{optional_charsets_safe},
        $options{optional_encryption},
        $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars}, $options{debug_grammars},
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
      innodb_xa => [
        [ '--scenario=Standard', '--scenario=Restart', '--scenario=CrashRecovery' ],
        [ '--engine=InnoDB' ],
        [ '--grammar=conf/yy/xa.yy' ],
        $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_charsets_safe},
        $options{optional_variators},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_server_variables},
      ],
      json => [
        [ '--scenario=Standard' ],
        $options{engine_basic_combinations},
        [ '--grammar=conf/yy/json.yy --variator=JsonTables' ],
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_binlog_safe_variables},
        $options{optional_server_variables},
      ],
      locking => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ '--grammar=conf/yy/backup-locks.yy --grammar=conf/yy/locks.yy' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_binlog_safe_variables},
        $options{optional_server_variables},
      ],
      minimal => [
        [ '--scenario=Standard' ],
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
      ],
      mixed_flow => [
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
        [ '--scenario=Standard' ],
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
        ['
          --variator=AnalyzeOrExplain
          --variator=DisableOptimizations
          --variator=EnableOptimizations
          --variator=ExecuteAsCTE.pm
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
      optimizer_transform => [
        [ '--scenario=Standard' ],
        ['
          --gendata=simple
          --gendata=data/sql/world.sql
          --gendata=conf/zz/outer_join.zz
          --grammar=conf/yy/collect_eits.yy
          --grammar=conf/yy/optimizer_no_subquery.yy
          --grammar=conf/yy/optimizer_subquery_semijoin.yy
          --grammar=conf/yy/optimizer.yy
          --grammar=conf/yy/outer_join.yy
          --views
        ' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        [ '--validator=Transformer --transformer=ExecuteAsPreparedTwice --transformer=EnableOptimizations --transformer=DisableOptimizations' ],
        $options{optional_server_variables},
      ],
      perfschema => [
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
        [ '--scenario=Standard', '--scenario=Restart' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        [ '--variator=ExecuteAsExecuteImmediate --variator=ExecuteAsFunctionTwice --variator=ExecuteAsPreparedThrice --variator=ExecuteAsPSWithParams --variator=ExecuteAsSPTwice --variator=ExecuteAsTrigger' ],
        $options{optional_binlog_safe_variables},
        $options{optional_server_variables},
      ],
      readonly => [
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
      recovery => [
        $options{scenario_crash_combinations},
        [ '--engine=InnoDB', '--engine=Aria --mysqld=--default-storage-engine=Aria', '--engine=InnoDB,Aria' ],
        [ '--filter=conf/ff/restrict_dynamic_vars.ff' ],
        [ '--grammar=conf/yy/dml.yy' ],
        $options{optional_charsets_safe},
        $options{optional_encryption},
        $options{dml_grammars}, $options{ddl_grammars}, $options{debug_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      replication => [
        $options{scenario_replication_combinations},
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
        [ '--scenario=Standard' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        [ '--variator=ExecuteAsPreparedTwice' ],
        $options{optional_binlog_safe_variables},
        $options{optional_server_variables},
      ],
      spider => [
        [ '--scenario=Standard' ],
        ['
          --mysqld=--plugin-load-add=ha_spider
          --mysqld=--loose-spider-same-server-link=on
          --mysqld=--loose-spider_table_crd_thread_count=1
          --mysqld=--loose-spider_table_sts_thread_count=1
          --grammar=conf/yy/engine-spider.yy
        '],
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_binlog_safe_variables},
        $options{optional_server_variables},
      ],
      unique_hash => [
        [ '--scenario=Standard','--scenario=Replication --scenario-nosync' ],
        [ '--gendata=advanced --unique-hash-keys'],
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
      upgrade_backup => [
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
