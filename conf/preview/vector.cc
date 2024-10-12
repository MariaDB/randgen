# Copyright (c) 2022, 2023 MariaDB
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
  [ @{$options{test_common_option_combinations}} ], # seed, reporters, timeouts
  [ @{$options{test_concurrency_combinations}} ],
  [ @{$options{optional_gendata_gis}} ],
  [ @{$options{optional_gendata_views}} ],
  [ @{$options{optional_gendata_vcols}} ],
  [ @{$options{optional_gendata_unique_hash_keys}} ],
  [ @{$options{optional_variators}} ],
  [ @{$options{gendata}} ],
# Disabled for now, too frequent DBD problems
#  [ @{$options{optional_ps_protocol}} ],

# Server options
  [ @{$options{optional_aria_variables}} ],
  [ @{$options{optional_binlog_safe_variables}} ],
  [ @{$options{optional_innodb_compression}} ],
  [ @{$options{optional_innodb_pagesize}} ],
  [ @{$options{optional_innodb_variables}} ],
  [ @{$options{optional_perfschema}} ],
  [ @{$options{optional_server_variables}} ],

# New
  [ '--grammar=conf/preview/vector.yy:3' ],
  [ '--mysqld=--mhnsw_cache_size=1M', '--mysqld=--mhnsw_cache_size=8G', '' ],
  [ '--mysqld=--mhnsw_max_edges_per_node=3', '--mysqld=--mhnsw_max_edges_per_node=4', '--mysqld=--mhnsw_max_edges_per_node=20', '--mysqld=--mhnsw_cache_size=100', '', '' ],
  [ '--mysqld=--mhnsw_min_limit=1', '--mysqld=--mhnsw_min_limit=2', '--mysqld=--mhnsw_min_limit=10', '--mysqld=--mhnsw_min_limit=100', '--mysqld=--mhnsw_min_limit=65535', '' ],
  [ '--mysqld=--mhnsw_distance_function=euclidean', '--mysqld=--mhnsw_distance_function=cosine' ],

  ##### Engines and scenarios
  [
    {
      simple => [
        [ '--scenario=Standard' ],
        [ '--gendata=/data/tmp/vector_db' ],
        [ @{$options{engine_basic_combinations}} ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}} ],
      ],
      innodb => [
        [ '--scenario=Standard' ],
        [ '--gendata=/data/tmp/vector_db' ],
        [ '--engine=InnoDB' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}} ],
      ],
      normal => [
        [ @{$options{scenario_non_crash_combinations}} ],
        [ @{$options{engine_basic_combinations}}, @{$options{engine_extra_supported_combinations}}, @{$options{engine_full_mix_combinations}} ],
        [ @{$options{optional_charsets_safe}}, @{$options{optional_charsets_unsafe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{optional_binlog_unsafe_variables}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}}, @{$options{debug_grammars}} ],
      ],
      index => [
        [ @{$options{scenario_non_crash_combinations}} ],
        [ '--gendata=/data/tmp/vector_db' ],
        [ '--reporters=SecondaryIndexConsistency' ],
        [ @{$options{engine_basic_combinations}}, @{$options{engine_extra_supported_combinations}} ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}}, @{$options{debug_grammars}} ],
      ],
      recovery => [
        [ @{$options{scenario_crash_combinations}} ],
        [ '--gendata=/data/tmp/vector_db' ],
        [ '--engine=InnoDB', '--engine=Aria --mysqld=--default-storage-engine=Aria', '--engine=InnoDB,Aria' ],
        [ '--filter=conf/ff/restrict_dynamic_vars.ff' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{debug_grammars}} ],
      ],
      innodb_recovery => [
        [ @{$options{scenario_crash_combinations}} ],
        [ '--gendata=/data/tmp/vector_db' ],
        [ '--engine=InnoDB' ],
        [ '--filter=conf/ff/restrict_dynamic_vars.ff' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
      ],
      upgrade_backup => [
        [ @{$options{scenario_mariabackup_combinations}} ],
        [ '--filter=conf/ff/restrict_dynamic_vars.ff' ],
        [ @{$options{engine_basic_combinations}} ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
      ],
      replication => [
        [ @{$options{scenario_replication_combinations}} ],
        [ '--filter=conf/ff/replication.ff' ],
        [ @{$options{engine_basic_combinations}} ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{optional_replication_safe_variables}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
      ],
    }
  ],
];
