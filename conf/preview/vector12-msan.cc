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
  [ '--grammar=conf/yy/vector.yy:3 --gendata=data/sql/vector_gist_960_1K.sql --gendata=data/sql/vector_deep_image_96_10K.sql --grammar=conf/yy/functions.yy:2' ],
  [ '--mysqld=--mhnsw_max_cache_size=128M', '--mysqld=--mhnsw_max_cache_size=8G', '--mysqld=--mhnsw_max_cache_size=4G', '--mysqld=--mhnsw_max_cache_size=1G', '--mysqld=--mhnsw_max_cache_size=1M' ],
  [ '--mysqld=--mhnsw_default_m=3', '--mysqld=--mhnsw_default_m=4', '--mysqld=--mhnsw_default_m=20', '--mysqld=--mhnsw_default_m=100', '', '' ],
  [ '--mysqld=--mhnsw_ef_search=1', '--mysqld=--mhnsw_ef_search=2', '--mysqld=--mhnsw_ef_search=5', '--mysqld=--mhnsw_ef_search=10', '--mysqld=--mhnsw_ef_search=20', '--mysqld=--mhnsw_ef_search=100', '--mysqld=--mhnsw_ef_search=200', '--mysqld=--mhnsw_ef_search=4096', '--mysqld=--mhnsw_ef_search=65535', '' ],
  [ '--mysqld=--mhnsw_default_distance=euclidean', '--mysqld=--mhnsw_default_distance=cosine' ],

  ##### Engines and scenarios
  [
    {
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
      binlog => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ '--reporter=BinlogDump' ],
        [ '--mysqld=--log-bin' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{optional_encryption_msan_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars}, $options{debug_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression_msan_safe},
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
      index => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ '--reporters=SecondaryIndexConsistency' ],
        [ '--grammar=conf/yy/many_indexes.yy' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{optional_encryption_msan_safe},
        $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars}, $options{debug_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression_msan_safe},
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
        $options{optional_innodb_compression_msan_safe},
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
        $options{optional_innodb_compression_msan_safe},
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
        $options{optional_encryption_msan_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression_msan_safe},
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
        $options{optional_innodb_compression_msan_safe},
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
        $options{optional_innodb_compression_msan_safe},
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
      simple => [
        [ '--scenario=Standard' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        [ '--variator=ExecuteAsPreparedTwice' ],
        $options{optional_binlog_safe_variables},
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
    }
  ],
];
