# Copyright (c) 2022, 2026 MariaDB
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

use lib "$ENV{RQG_HOME}/conf/cc/include";
use ConfigCommon qw($version $combinations %parameters %options $msan_safe);
require "$ENV{RQG_HOME}/conf/cc/include/parameter_presets";

# Choose options based on $version value
# ($version may be defined via config-version, otherwise 999999 will be used)
local @ARGV = ($version);
require "$ENV{RQG_HOME}/conf/cc/include/versioned_options.pl";

my $msan_suffix = ($msan_safe ? '_msan_safe' : '');

$combinations = [

# Test options
  $options{test_common_option_combinations}, # seed, reporters
  $options{test_concurrency_combinations},   # threads and timeouts
  $options{gendata},
# Disabled for now, too frequent DBD problems
#  $options{optional_ps_protocol},

  [' --grammar=conf/yy/vector.yy:2
     --grammar=conf/yy/vector_subdist.yy:2
     --grammar=conf/preview/vector_indexes_is.yy:2
     --gendata=data/sql/vector_deep_image_96_10K.sql
     --gendata=data/sql/vector_gist_960_1K.sql
     --gendata=util/gen_vector_subdist_dataset.pl
  '],

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
        $options{"optional_encryption${msan_suffix}"},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars}, $options{debug_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{"optional_innodb_compression${msan_suffix}"},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_server_variables},
      ],
      custom => [
        [ '--scenario=Standard' ],
        [ '--engine=InnoDB,Aria' ],
        [ '--variator=ExecuteAsOracleSP', '' ],
        [ '--variator=ExecuteAsPackageSP', '' ],
        $options{custom_options_1},
        $options{custom_options_1_master},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
      ],
      custom_recovery => [
        [ '--scenario=CrashRecovery' ],
        [ '--engine=InnoDB' ],
        [ '--variator=ExecuteAsOracleSP', '' ],
        [ '--variator=ExecuteAsPackageSP', '' ],
        $options{custom_options_1},
        $options{custom_options_1_master},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
      ],
      custom_rpl => [
        [ '--scenario=Replication' ],
        [ '--engine=InnoDB' ],
        [ '--variator=ExecuteAsOracleSP', '' ],
        [ '--variator=ExecuteAsPackageSP', '' ],
        [ '--grammar=conf/yy/dml.yy' ],
        [ '--filter=conf/ff/replication.ff' ],
        $options{custom_options_1},
        $options{custom_options_1_master},
        $options{custom_options_1_slave},
        $options{dml_grammars}, $options{ddl_grammars},
      ],
      custom_unique_hash => [
        [ '--scenario=Standard' ],
        [ '--engine=InnoDB' ],
        [ '--gendata=advanced --unique-hash-keys --gendata=conf/zz/blobs.zz --grammar=conf/yy/indexes_and_constraints.yy' ],
        $options{custom_options_1},
        $options{custom_options_1_master},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
      ],
      index => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ '--reporters=SecondaryIndexConsistency' ],
        [ '--grammar=conf/yy/many_indexes.yy' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{"optional_encryption${msan_suffix}"},
        $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars}, $options{debug_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{"optional_innodb_compression${msan_suffix}"},
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
        $options{"optional_innodb_compression${msan_suffix}"},
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
        $options{"optional_innodb_compression${msan_suffix}"},
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
        $options{"optional_encryption${msan_suffix}"},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{"optional_innodb_compression${msan_suffix}"},
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
        $options{"optional_innodb_compression${msan_suffix}"},
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
        $options{"optional_innodb_compression${msan_suffix}"},
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
      partitions => [
        [ '--scenario=Standard' ],
        [ '--grammar=conf/yy/partition_by_hash.yy  --grammar=conf/yy/partition_by_list.yy  --grammar=conf/yy/partition_by_range.yy  --grammar=conf/yy/partition-dml.yy' ],
        [ '--gendata=conf/zz/partition_by_columns.zz --gendata=advanced --partitions' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_binlog_safe_variables},
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
      unique_hash => [
        [ '--scenario=Standard','--scenario=Replication --scenario-nosync --filter=conf/ff/replication.ff' ],
        [ '--gendata=advanced --unique-hash-keys --gendata=conf/zz/blobs.zz --grammar=conf/yy/indexes_and_constraints.yy' ],
        [ '--engine=InnoDB,MyISAM' ],
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{"optional_innodb_compression${msan_suffix}"},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
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
