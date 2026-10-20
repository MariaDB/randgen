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

use lib "$ENV{RQG_HOME}/conf/cc/include";
use ConfigCommon qw(
  $combinations
  $scenarios
  @common_options
  @new_options
  %options
);
require "$ENV{RQG_HOME}/conf/cc/all.cc";

@new_options = (
  ['
    --grammar=conf/preview/query-cache.yy:2
    --grammar=conf/yy/plugin-query_cache_info.yy
  '],
  [
    '--mysqld=--query-cache-type=0',
    '--mysqld=--query-cache-type=1',
    '--mysqld=--query-cache-type=2',
    '--mysqld=--query-cache-size=128K',
    '--mysqld=--query-cache-size=4M',
    '--mysqld=--query-cache-size=256M',
  ],
  [
    '--mysqld=--query-cache-wlock-invalidate=off',
    '--mysqld=--query-cache-wlock-invalidate=on'
  ],
);

$combinations = [
  @common_options,
  @new_options,
  $scenarios
];
