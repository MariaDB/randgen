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

our ($common_options, $ps_protocol_combinations, $views_combinations, $vcols_combinations, $gis_combinations, $threads_low_combinations, $optional_variators);
our ($basic_engine_combinations, $enforced_engine_combinations, $extra_engine_combinations);
our ($non_crash_scenarios, $crash_scenarios, $mariabackup_scenarios, $upgrade_scenarios);
our (%server_options, %options);
our ($grammars, $unsafe_grammars, $gendata);

my @empty_set_10= ('','','','','','','','','','');

require "$ENV{RQG_HOME}/conf/cc/include/parameter_presets";

# Choose options based on $version value
# ($version may be defined via config-version, otherwise 999999 will be used)
local @ARGV = ($version);
require "$ENV{RQG_HOME}/conf/cc/include/versioned_options.pl";

$combinations = [
  [ $common_options ], # seed, reporters, timeouts
  [ @$threads_low_combinations ],
  [ @$views_combinations ],
  [ @$vcols_combinations ],
  [ @$optional_variators ],
  [ @$grammars ],
  [ @$gendata ],

  ##### Engines and scenarios
  ##### Scenarios
  [
    {
      normal => [
        [ @$non_crash_scenarios ],
        [ @$basic_engine_combinations ],
        [ @$unsafe_grammars ],
        [ @{$options{safe_charsets}}, @{$options{unsafe_charsets}} ],
      ],
      recovery => [
        [ @$crash_scenarios ],
        [ '--engine=InnoDB', '--engine=Aria --mysqld=--default-storage-engine=Aria' ],
        [ @{$options{safe_charsets}} ],
      ],
      upgrade_backup => [
        [ @$mariabackup_scenarios ],
        [ @$basic_engine_combinations ],
        [ @{$options{safe_charsets}} ],
      ],
    }
  ],

  ##### Encryption
  [ @{$options{optional_full_encryption}} ],
  ##### InnoDB
  [ @{$options{optional_innodb_variables}} ],
  ##### Plugins (not linked to grammars)
  [ @{$options{optional_plugins}} ],
  ##### Binary logging
  [ @{$options{optional_binlog_variables}} ],
  ##### Startup variables (general)
  [ @{$options{optional_server_variables}} ],
  [ @{$options{safe_charsets}} ],
];
