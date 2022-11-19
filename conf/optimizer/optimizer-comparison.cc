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
    --duration=400
    --queries=100M
    --reporters=Backtrace,ErrorLog,Deadlock
    --redefine=conf/mariadb/analyze-tables-at-start.yy
    --mysqld=--log-output=FILE
    --mysqld=--max-statement-time=30
  '], 

  [
    { 
      specific_data => [
        [
          '--grammar=conf/optimizer/outer_join.yy --gendata=conf/optimizer/outer_join.zz --views=TEMPTABLE,MERGE',
          '--grammar=conf/optimizer/optimizer_access_exp.yy --gendata=conf/optimizer/range_access.zz --views=TEMPTABLE,MERGE',
        ],
      ],
      any_data => [
        [
          '--grammar=conf/optimizer/optimizer.yy',
          '--grammar=conf/optimizer/range_access2.yy',
          '--grammar=conf/optimizer/range_access.yy',
        ],
        [ 
          '--gendata=conf/optimizer/range_access.zz',
          '--gendata=conf/optimizer/range_access2.zz',
          '--gendata=conf/optimizer/optimizer.zz',
          '--gendata-advanced',
          '--gendata',
          '--gendata=data/sql/world.sql'
        ],
        [ '--views --engine=InnoDB,MyISAM,Aria' ],
      ],
    }
  ], 
];
