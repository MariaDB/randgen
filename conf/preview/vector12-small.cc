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

# New
  [ '--grammar=conf/yy/vector.yy:3 --gendata=data/sql/vector_gist_960_1K.sql --gendata=data/sql/vector_deep_image_96_10K.sql --grammar=conf/yy/functions.yy:2' ],
  [ '--mysqld=--mhnsw_max_cache_size=128M', '--mysqld=--mhnsw_max_cache_size=8G', '--mysqld=--mhnsw_max_cache_size=4G', '--mysqld=--mhnsw_max_cache_size=1G', '--mysqld=--mhnsw_max_cache_size=1M' ],
  [ '--mysqld=--mhnsw_default_m=3', '--mysqld=--mhnsw_default_m=4', '--mysqld=--mhnsw_default_m=20', '--mysqld=--mhnsw_default_m=100', '', '' ],
  [ '--mysqld=--mhnsw_ef_search=1', '--mysqld=--mhnsw_ef_search=2', '--mysqld=--mhnsw_ef_search=5', '--mysqld=--mhnsw_ef_search=10', '--mysqld=--mhnsw_ef_search=20', '--mysqld=--mhnsw_ef_search=100', '--mysqld=--mhnsw_ef_search=200', '--mysqld=--mhnsw_ef_search=4096', '--mysqld=--mhnsw_ef_search=65535', '' ],
  [ '--mysqld=--mhnsw_default_distance=euclidean', '--mysqld=--mhnsw_default_distance=cosine' ],


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
      readonly => [
        [ '--scenario=Standard' ],
        [ @{$options{engine_basic_combinations}} ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{read_only_grammars}} ],
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
        [ @{$options{optional_server_variables}} ],
      ],
      ps_sp => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ @{$options{engine_basic_combinations}} ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
        [ '--variator=ExecuteAsExecuteImmediate --variator=ExecuteAsFunctionTwice --variator=ExecuteAsPreparedThrice --variator=ExecuteAsPSWithParams --variator=ExecuteAsSPTwice --variator=ExecuteAsTrigger' ],
        [ @{$options{optional_binlog_safe_variables}} ],
        [ @{$options{optional_server_variables}} ],
      ],      innodb => [
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
      custom => [
        [ '--scenario=Standard' ],
        [ '--engine=InnoDB' ],
        [ '--genconfig=conf/cnf/custom1-master.cnf --mysqld=--innodb-buffer-pool-size=2G' ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
      ],
    }
  ],
];
