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
  [ @{$options{grammars}} ],
  [ @{$options{gendata}} ],

# Server options
  [ @{$options{optional_aria_variables}} ],
  [ @{$options{optional_binlog_safe_variables}} ],
  [ @{$options{optional_innodb_compression}} ],
  [ @{$options{optional_innodb_pagesize}} ],
  [ @{$options{optional_innodb_variables}} ],
  [ @{$options{optional_perfschema}} ],
  [ @{$options{optional_server_variables}} ],

  ##### Engines and scenarios
  [
    {
      normal => [
        [ @{$options{scenario_non_crash_combinations}} ],
        [ @{$options{engine_basic_combinations}} ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
      ],
      binlog => [
        [ @{$options{scenario_non_crash_combinations}} ],
        [ '--reporters=BinlogConsistency --mysqld=--log-bin' ],
        [ @{$options{engine_basic_combinations}} ],
        [ @{$options{optional_charsets_safe}} ],
        # Cannot have binlog encryption here, mysqlbinlog cannot read it
        [ @{$options{optional_non_binlog_encryption}} ],
      ],
      index => [
        [ @{$options{scenario_non_crash_combinations}} ],
        [ '--reporters=SecondaryIndexConsistency' ],
        [ @{$options{engine_basic_combinations}} ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
      ],
      recovery => [
        [ @{$options{scenario_crash_combinations}} ],
        [ '--engine=InnoDB' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
      ],
    }
  ],
];
