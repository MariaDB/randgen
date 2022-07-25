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

# 90 combinations

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
# Some of legacy will duplicate the newer ones, but better safe than sorry
  [
    { 
      current_specific_data => [
        [
          '--grammar=conf/optimizer/outer_join.yy --gendata=conf/optimizer/outer_join.zz --views=TEMPTABLE,MERGE',
          '--grammar=conf/optimizer/optimizer_access_exp.yy --gendata=conf/optimizer/range_access.zz --views=TEMPTABLE,MERGE',
        ],
        [ '', '--notnull' ],
      ],
      current_any_data => [
        [
          '--grammar=conf/optimizer/optimizer.yy',
          '--grammar=conf/optimizer/range_access1.yy',
          '--grammar=conf/optimizer/range_access2.yy',
          '--grammar=conf/optimizer/range_access.yy',
        ],
        [ 
          '--gendata=conf/optimizer/range_access.zz',
          '--gendata=conf/optimizer/range_access2.zz',
          '--gendata=conf/optimizer/optimizer.zz',
          '--gendata-advanced',
          '--gendata',
          '--gendata=conf/general/world.sql'
        ],
        [ '--views --engine=InnoDB,MyISAM,Aria' ],
      ],
      legacy_specific_data => [
        [
          '--grammar=conf/optimizer/legacy/optimizer_access_exp.yy --gendata=conf/optimizer/legacy/range_access.zz',
          '--grammar=conf/optimizer/legacy/outer_join.yy --gendata=conf/optimizer/legacy/outer_join.zz',
          '--grammar=conf/optimizer/legacy/range_access2.yy --gendata=conf/optimizer/legacy/range_access2.zz',
          '--grammar=conf/optimizer/legacy/range_access.yy --gendata=conf/optimizer/legacy/range_access.zz',
        ],
        [ '--views' ],
        [ '', '--notnull' ],
      ],
      legacy_simple_data => [
        [
          '--grammar=conf/optimizer/legacy/optimizer_no_subquery.yy',
          '--grammar=conf/optimizer/legacy/optimizer_subquery_no_outer_join.yy',
          '--grammar=conf/optimizer/legacy/optimizer_subquery_semijoin.yy',
          '--grammar=conf/optimizer/legacy/optimizer_subquery.yy',
        ],
        [ '--engine=InnoDB', '--engine=MyISAM', '--engine=Aria' ],
        [ '--views=MERGE', '--views=TEMPTABLE' ],
        [ '', '--notnull' ],
      ],
      legacy_world_data => [
        [
          '--grammar=conf/optimizer/legacy/optimizer_no_subquery.yy --mysqld=--init-file=$RQG_HOME/conf/mariadb/world.sql',
          '--grammar=conf/optimizer/legacy/optimizer_subquery.yy --mysqld=--init-file=$RQG_HOME/conf/mariadb/world.sql',
        ],
        [ '--mysqld=--default-storage-engine=InnoDB', '--mysqld=--default-storage-engine=MyISAM', '--mysqld=--default-storage-engine=Aria' ],
      ]
    }
  ], 
];
