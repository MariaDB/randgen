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
  [ @{$options{test_common_option_combinations}} ], # seed, reporters, timeouts
  [ @{$options{test_concurrency_combinations}} ],
  [ @{$options{optional_gendata_views}} ],
  [ @{$options{optional_variators}} ],
  [ @{$options{gendata}} ],
# Disabled for now, too frequent DBD problems
#  [ @{$options{optional_ps_protocol}} ],

# Server options
  [ @{$options{optional_aria_variables}} ],
  [ @{$options{optional_binlog_safe_variables}} ],
  [ @{$options{optional_perfschema}} ],
  [ @{$options{optional_server_variables}} ],

  [ '--mysqld=--aria_pagecache_segments=1',
    '--mysqld=--aria_pagecache_segments=2',
    '--mysqld=--aria_pagecache_segments=4',
    '--mysqld=--aria_pagecache_segments=10',
    '--mysqld=--aria_pagecache_segments=16',
    '--mysqld=--aria_pagecache_segments=50',
    '--mysqld=--aria_pagecache_segments=64',
    '--mysqld=--aria_pagecache_segments=127',
    '--mysqld=--aria_pagecache_segments=128' ],
  [ '--engine=Aria --mysqld=--default-storage-engine=Aria' ],
  [
    '--mysqld=--aria_block_size=8192',
    '--mysqld=--aria_block_size=2048',
    '--mysqld=--aria_block_size=4096',
    '--mysqld=--aria_block_size=1024',
    '--mysqld=--aria_block_size=16384'
  ],
  [
    '--mysqld=--aria_checkpoint_interval=1',
    '--mysqld=--aria_checkpoint_interval=10',
    '--mysqld=--aria_checkpoint_interval=30',
    '--mysqld=--aria_checkpoint_interval=100',
  ],
  [
    '--mysqld=--aria_checkpoint_log_activity=1048576',
    '--mysqld=--aria_checkpoint_log_activity=0',
    '--mysqld=--aria_checkpoint_log_activity=65536',
    '--mysqld=--aria_checkpoint_log_activity=2097152',
  ],
  [
    '--mysqld=--aria_force_start_after_recovery_failures=0',
    '--mysqld=--aria_force_start_after_recovery_failures=1',
    '--mysqld=--aria_force_start_after_recovery_failures=10',
  ],
  [
    '--mysqld=--aria_group_commit=none',
    '--mysqld=--aria_group_commit=hard',
    '--mysqld=--aria_group_commit=soft',
  ],
  [
    '--mysqld=--aria_group_commit_interval=0',
    '--mysqld=--aria_group_commit_interval=1000',
    '--mysqld=--aria_group_commit_interval=1000000'
  ],
  [
    '--mysqld=--aria_log_file_size=1073741824',
    '--mysqld=--aria_log_file_size=1048576',
    '--mysqld=--aria_log_file_size=268435456',
    '--mysqld=--aria_log_file_size=262144',
  ],
  [
    '--mysqld=--aria_log_purge_type=immediate',
    '--mysqld=--aria_log_purge_type=external',
    '--mysqld=--aria_log_purge_type=at_flush',
  ],
    '--mysqld=--aria_max_sort_file_size=9223372036853727232',
    '--mysqld=--aria_max_sort_file_size=879609',
    '--mysqld=--aria_max_sort_file_size=900719925',
  [
    '--mysqld=--aria_page_checksum=on',
    '--mysqld=--aria_page_checksum=off',
  ],
  [
    '--mysqld=--aria_pagecache_age_threshold=300',
    '--mysqld=--aria_pagecache_age_threshold=100',
    '--mysqld=--aria_pagecache_age_threshold=9999900',
    '--mysqld=--aria_pagecache_age_threshold=10000',
  ],
  [
    '--mysqld=--aria_pagecache_buffer_size=128M',
    '--mysqld=--aria_pagecache_buffer_size=128K',
    '--mysqld=--aria_pagecache_buffer_size=1G',
    '--mysqld=--aria_pagecache_buffer_size=4M',
  ],
  [
    '--mysqld=--aria_pagecache_division_limit=100',
    '--mysqld=--aria_pagecache_division_limit=1',
    '--mysqld=--aria_pagecache_division_limit=50',
  ],
  [ '--mysqld=--aria_recover=NORMAL',
    '--mysqld=--aria_recover=BACKUP',
    '--mysqld=--aria_recover=FORCE',
    '--mysqld=--aria_recover=QUICK',
    '--mysqld=--aria_recover=OFF',
  ],
  [
    '--mysqld=--aria_repair_threads=1',
    '--mysqld=--aria_repair_threads=2',
    '--mysqld=--aria_repair_threads=4',
  ],
  [
    '--mysqld=--aria_sort_buffer_size=134217728',
    '--mysqld=--aria_sort_buffer_size=268434432',
    '--mysqld=--aria_sort_buffer_size=1048572',
  ],
  [
    '--mysqld=--aria_stats_method=nulls_unequal',
    '--mysqld=--aria_stats_method=nulls_equal',
    '--mysqld=--aria_stats_method=nulls_ignored',
  ],
  [
    '--mysqld=--aria_sync_log_dir=NEWFILE',
    '--mysqld=--aria_sync_log_dir=NEVER',
    '--mysqld=--aria_sync_log_dir=ALWAYS',
  ],

  ##### Engines and scenarios
  [
    {
      simple => [
        [ '--scenario=Standard' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}} ],
      ],
      normal => [
        [ @{$options{scenario_non_crash_combinations}} ],
        [ @{$options{engine_basic_combinations}}, @{$options{engine_extra_supported_combinations}}, @{$options{engine_full_mix_combinations}} ],
        [ @{$options{optional_charsets_safe}}, @{$options{optional_charsets_unsafe}} ],
        [ @{$options{optional_encryption_msan_safe}} ],
        [ @{$options{optional_binlog_unsafe_variables}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}}, @{$options{debug_grammars}} ],
      ],
      binlog => [
        [ '--mysqld=--log-bin' ],
        [ '--reporter=BinlogDump' ],
        [ @{$options{scenario_non_crash_combinations}} ],
        [ @{$options{optional_charsets_safe}}, @{$options{optional_charsets_unsafe}} ],
        [ @{$options{optional_encryption_msan_safe}} ],
        # We don't care about binlog safety here, because we are not checking consistency
        [ @{$options{optional_binlog_unsafe_variables}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}}, @{$options{debug_grammars}} ],
      ],
      index => [
        [ @{$options{scenario_non_crash_combinations}} ],
        [ '--reporters=SecondaryIndexConsistency' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption_msan_safe}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}}, @{$options{debug_grammars}} ],
      ],
      recovery => [
        [ @{$options{scenario_crash_combinations}} ],
        [ '--filter=conf/ff/restrict_dynamic_vars.ff' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption_msan_safe}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{debug_grammars}} ],
      ],
    }
  ],
];
