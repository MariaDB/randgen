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
  [ @{$options{optional_gendata_views}} ],
  [ @{$options{optional_variators}} ],
  [ @{$options{gendata}} ],

# Server options
  [ @{$options{optional_aria_variables}} ],
  [ @{$options{optional_binlog_safe_variables}} ],
  [ @{$options{optional_innodb_compression_msan_safe}} ],
  [ @{$options{optional_innodb_pagesize}} ],
  [ @{$options{optional_innodb_variables}} ],
  [ @{$options{optional_perfschema}} ],
  [ @{$options{optional_server_variables}} ],

# New
  [ '--grammar=conf/yy/vector.yy:3 --gendata=data/sql/vector_gist_960_1K.sql --gendata=data/sql/vector_deep_image_96_10K.sql --grammar=conf/yy/functions.yy:2' ],
  [ '--mysqld=--mhnsw_max_cache_size=128M', '--mysqld=--mhnsw_max_cache_size=8G', '--mysqld=--mhnsw_max_cache_size=4G', '--mysqld=--mhnsw_max_cache_size=1G', '--mysqld=--mhnsw_max_cache_size=1M' ],
  [ '--mysqld=--mhnsw_default_m=3', '--mysqld=--mhnsw_default_m=4', '--mysqld=--mhnsw_default_m=20', '--mysqld=--mhnsw_max_cache_size=100', '', '' ],
  [ '--mysqld=--mhnsw_ef_search=1', '--mysqld=--mhnsw_ef_search=2', '--mysqld=--mhnsw_ef_search=5', '--mysqld=--mhnsw_ef_search=10', '--mysqld=--mhnsw_ef_search=20', '--mysqld=--mhnsw_ef_search=100', '--mysqld=--mhnsw_ef_search=200', '--mysqld=--mhnsw_ef_search=4096', '--mysqld=--mhnsw_ef_search=65535', '' ],
  [ '--mysqld=--mhnsw_default_distance=euclidean', '--mysqld=--mhnsw_default_distance=cosine' ],

  ##### Engines and scenarios
  [
    {
      normal => [
        [ @{$options{scenario_non_crash_combinations}} ],
        [ @{$options{engine_basic_combinations}} ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption_msan_safe}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}}, @{$options{debug_grammars}} ],
      ],
      binlog => [
        [ '--mysqld=--log-bin' ],
        [ '--reporter=BinlogDump' ],
        [ @{$options{scenario_non_crash_combinations}} ],
        [ @{$options{engine_basic_combinations}} ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption_msan_safe}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}}, @{$options{debug_grammars}} ],
      ],
      recovery => [
        [ @{$options{scenario_crash_combinations}} ],
        [ '--engine=InnoDB' ],
        [ '--filter=conf/ff/restrict_dynamic_vars.ff' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption_msan_safe}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
      ],
    }
  ],
];
