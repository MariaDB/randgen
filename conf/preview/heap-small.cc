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
  ['
    --gendata=data/sql/engine-heap.sql
    --gendata=conf/zz/blobs.zz
    --grammar=conf/preview/heap.yy
  '],
  ['', '--grammar=conf/yy/engine-heap-dml.yy', '--grammar=conf/yy/engine-heap-dml.yy:2'],
  ['', '--grammar=conf/yy/engine-heap-ddl.yy', '--grammar=conf/yy/engine-heap-ddl.yy:2'],
  [
    '',
    '--gendata=advanced --gis',
    '--gendata=advanced --unique-hash-keys',
    '--gendata=advanced --gis --unique-hash-keys'
  ],
  ['', '--engine=HEAP', '--engine=HEAP,MyISAM', '--engine=HEAP,Aria', '--engine=HEAP,InnoDB'],
  ['', '--mysqld=--default-storage-engine=HEAP'],
  ['', '--mysqld=--default-tmp-storage-engine=HEAP'],
  ['', '', '--mysqld=--optimizer_switch=derived_merge=off'],
  [
   '',
   '--mysqld=--tmp-table-size=0',
   '--mysqld=--tmp-table-size=1K',
   '--mysqld=--tmp-table-size=128M'
  ],
  [
   '',
   '--mysqld=--max-heap-table-size=16K',
   '--mysqld=--max-heap-table-size=1M',
   '--mysqld=--max-heap-table-size=128M',
   '--mysqld=--max-heap-table-size=256M',
  ],
);

$combinations = [
  @common_options,
  @new_options,
  $scenarios
];
