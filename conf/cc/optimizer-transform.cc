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
    --scenario=Standard
    --seed=time
    --threads=4
    --duration=600
    --queries=100M
    --nometadata-reload
    --reporters=Backtrace,Deadlock
    --engine=InnoDB,MyISAM,Aria,HEAP
    --mysqld=--log-output=FILE
    --mysqld=--max-statement-time=30
    --mysqld=--loose-optimizer-trace=enabled=on
    --transformer=AnalyzeOrExplain
    --transformer=ConvertSubqueriesToViews
    --transformer=Count
    --transformer=DisableChosenPlan
    --transformer=DisableOptimizations
    --transformer=Distinct
    --transformer=EnableOptimizations
    --transformer=ExecuteAsCTE
    --transformer=ExecuteAsDeleteReturning
    --transformer=ExecuteAsDerived
    --transformer=ExecuteAsExcept
    --transformer=ExecuteAsInsertSelect
    --transformer=ExecuteAsIntersect
    --transformer=ExecuteAsPreparedTwice
    --transformer=ExecuteAsPSWithParams
    --transformer=ExecuteAsSelectItem
    --transformer=ExecuteAsUnion
    --transformer=ExecuteAsUpdateDelete
    --transformer=ExecuteAsView
    --transformer=ExecuteAsWhereSubquery
    --transformer=FullOrderBy
    --transformer=Having
    --transformer=IgnoredKeys
    --transformer=InlineSubqueries
    --transformer=LimitDecrease
    --transformer=LimitIncrease
    --transformer=LimitRowsExamined
    --transformer=OffsetFetch
    --transformer=OrderBy
    --transformer=Rownum
    --transformer=SelectOption
    --validators=Transformer,OptimizerTraceParser
    --grammar=conf/yy/collect_eits.yy:0.00001
  '],
  [
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
  ],
];
