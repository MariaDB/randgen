# Copyright (C) 2021, 2022 MariaDB Corporation.
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

$combinations = [
  ['
    --seed=time
    --threads=4
    --duration=600
    --queries=100M
    --reporters=Backtrace,ErrorLog,Deadlock
    --grammar=conf/yy/collect_eits.yy
    --mysqld=--log-output=FILE
    --mysqld=--max-statement-time=30
    --transformers=DisableOptimizations,EnableOptimizations,ExecuteAsDerived,ExecuteAsPreparedTwice,ExecuteAsView,ExecuteAsUnion,ExecuteAsExcept,ExecuteAsIntersect,DisableJoinCache
  '],
# Some of legacy will duplicate the newer ones, but better safe than sorry
  [
    {
      specific_data => [
        [
          '--grammar=conf/yy/outer_join.yy --gendata=conf/zz/outer_join.zz',
          '--grammar=conf/yy/optimizer_access_exp.yy --gendata=conf/zz/range_access.zz',
          '--grammar=conf/yy/dbt3-joins.yy --gendata=data/dbt3/dbt3-s0.001.dump',
          '--grammar=conf/yy/dbt3-ranges.yy --gendata=data/dbt3/dbt3-s0.001.dump',
          '--grammar=conf/yy/dbt3-joins.yy --gendata=data/dbt3/dbt3-s0.0001.dump',
          '--grammar=conf/yy/dbt3-ranges.yy --gendata=data/dbt3/dbt3-s0.0001.dump',
          '--grammar=conf/yy/oltp-readonly.yy --gendata=conf/zz/oltp.zz',
          '--grammar=conf/yy/range_access.yy --gendata=conf/zz/range_access.zz',
          '--grammar=conf/yy/range_access2.yy --gendata=conf/zz/range_access2.zz',
        ],
      ],
      any_data => [
        [
          '--grammar=conf/yy/optimizer.yy',
          '--grammar=conf/yy/range_access2.yy',
          '--grammar=conf/yy/range_access.yy',
        ],
        [
          '--gendata=conf/zz/range_access.zz',
          '--gendata=conf/zz/range_access2.zz',
          '--gendata=conf/zz/optimizer.zz',
          '--gendata=simple',
          '--gendata=data/dbt3/dbt3-s0.001.dump',
          '--gendata=data/sql/world.sql'
        ],
        [ '--engine=InnoDB,MyISAM,Aria' ],
      ],
    }
  ],
];
