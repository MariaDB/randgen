# Copyright (c) 2024 MariaDB
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

# New options
  [ '--mysqld=--max-binlog-total-size=1G', '--mysqld=--max-binlog-total-size=4M', '--mysqld=--max-binlog-total-size=1M', '' ],
  [ '--mysqld=--slave-connections-needed-for-purge=0', '--mysqld=--slave-connections-needed-for-purge=2', '' ],
  [ '--grammar=conf/preview/timestamp-and-binlog-limit.yy:0.01' ],

  ##### Engines and scenarios
  [
    {
      binlog => [
        [ '--mysqld=--log-bin' ],
        [ '--reporter=BinlogDump' ],
        [ @{$options{scenario_non_crash_combinations}} ],
        [ @{$options{engine_basic_combinations}}, @{$options{engine_extra_combinations}}, @{$options{engine_full_mix_combinations}} ],
        [ @{$options{optional_charsets_safe}}, @{$options{optional_charsets_unsafe}} ],
        [ @{$options{optional_encryption}} ],
        # We don't care about binlog safety here, because we are not checking consistency
        [ @{$options{optional_binlog_unsafe_variables}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}}, @{$options{debug_grammars}} ],
      ],
      replication => [
        [ @{$options{scenario_replication_combinations}} ],
        [ '--filter=conf/ff/replication.ff' ],
        [ '--reporter=BinlogDump' ],
        [ @{$options{engine_basic_combinations}} ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{optional_replication_safe_variables}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
      ],
      cluster => [
        [ @{$options{scenario_cluster_combinations}} ],
        [ '--filter=conf/ff/replication.ff' ],
        [ '--engine=InnoDB' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
      ]
    }
  ],
];
