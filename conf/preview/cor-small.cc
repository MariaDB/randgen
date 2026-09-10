# Copyright (c) 2026 MariaDB
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

use lib "$ENV{RQG_HOME}/conf/cc/include";
use ConfigCommon qw(
  $version
  $combinations
  $scenarios
  @common_options
  @new_options
  %parameters
  %options
  $msan_safe
);

require "$ENV{RQG_HOME}/conf/cc/small.cc";

@new_options = (
  [ '--mysqld=--drop-before-create-or-replace=ON', '', '', '', '' ],
  [ '--grammar=conf/preview/cor.yy:2' ],
  [ '--reporters=OrphanFiles' ],
  [ '--reporters=PrimaryCrashRecovery', '', '', '', '' ],
  [ '--mysqld=--plugin-load-add=ha_duckdb --mysqld=--default-storage-engine=DuckDB',
    '--mysqld=--plugin-load-add=ha_duckdb',
    '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '' ],
  [ '--mysqld=--binlog-format=statement --mysqld=--log-bin',
    '', '', '', '', '', '', '', '', '', '', '', '', '', '', '' ],
);

$combinations = [
  @common_options,
  @new_options,
  $scenarios
];