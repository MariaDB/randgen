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
    --scenario=Comparison
    --seed=time
    --duration=600
    --queries=100M
    --nometadata-reload
    --reporters=Backtrace,Deadlock,JsonHistogram
    --engine=InnoDB,MyISAM,Aria,HEAP
    --mysqld=--log-output=FILE
    --mysqld=--max-statement-time=30
    --variator=AnalyzeOrExplain
    --variator=ConvertSubqueriesToViews
    --variator=Count
    --variator=DisableChosenPlan
    --variator=DisableOptimizations
    --variator=Distinct
    --variator=EnableOptimizations
    --variator=ExecuteAsCTE
    --variator=ExecuteAsDeleteReturning
    --variator=ExecuteAsDerived
    --variator=ExecuteAsExcept
    --variator=ExecuteAsInsertSelect
    --variator=ExecuteAsIntersect
    --variator=ExecuteAsPreparedTwice
    --variator=ExecuteAsPSWithParams
    --variator=ExecuteAsSelectItem
    --variator=ExecuteAsUnion
    --variator=ExecuteAsUpdateDelete
    --variator=ExecuteAsView
    --variator=ExecuteAsWhereSubquery
    --variator=FullOrderBy
    --variator=Having
    --variator=IgnoredKeys
    --variator=InlineSubqueries
    --variator=LimitDecrease
    --variator=LimitIncrease
    --variator=LimitRowsExamined
    --variator=OffsetFetch
    --variator=OrderBy
    --variator=Rownum
    --variator=SelectOption
    --grammar=conf/yy/collect_eits.yy:0.00001
  '],
  [
    [
      '--validator=ResultsetComparator --threads=4',
      '--validator=ExitCodeComparator --threads=1',
      '--validator=ExecutionTimeComparator --threads=1',
    ],[
      '--grammar=conf/yy/outer_join.yy --gendata=conf/zz/outer_join.zz',
      '--grammar=conf/yy/optimizer_access_exp.yy --gendata=conf/zz/range_access.zz',
      '--grammar=conf/yy/dbt3-joins.yy --gendata=data/dbt3/dbt3-s0.001.dump',
      '--grammar=conf/yy/dbt3-ranges.yy --gendata=data/dbt3/dbt3-s0.001.dump',
      '--grammar=conf/yy/dbt3-joins.yy --gendata=data/dbt3/dbt3-s0.0001.dump',
      '--grammar=conf/yy/dbt3-ranges.yy --gendata=data/dbt3/dbt3-s0.0001.dump',
      '--grammar=conf/yy/oltp-read.yy --gendata=conf/zz/oltp.zz',
      '--grammar=conf/yy/range_access.yy --gendata=conf/zz/range_access.zz',
      '--grammar=conf/yy/range_access2.yy --gendata=conf/zz/range_access2.zz',
      '--grammar=conf/yy/optimizer_no_subquery.yy --gendata=simple',
      '--grammar=conf/yy/optimizer_subquery_semijoin.yy --gendata=simple',
      '--grammar=conf/yy/optimizer.yy --gendata=advanced --partitions',
      '--grammar=conf/yy/optimizer.yy --gendata=simple',
      '--grammar=conf/yy/optimizer.yy --gendata=data/sql/world.sql',
      '--grammar=conf/yy/optimizer.yy --gendata=data/dbt3/dbt3-s0.001.dump',
      '--grammar=conf/yy/optimizer_mtr_select.yy',
      '--grammar=conf/yy/optimizer_mtr_select.yy --mysqld=--default-storage-engine=MyISAM',
      '--grammar=conf/yy/optimizer_mtr_select.yy --mysqld=--default-storage-engine=Aria',
    ],
  ]
];
