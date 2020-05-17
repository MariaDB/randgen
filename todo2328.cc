#our $grammars;
#require 'conf/mariadb/include/combo.grammars';

$combinations = [ 
  [
  '
    --queries=100M
    --duration=600
    --threads=4
    --seed=time
    --views
    --vcols
    --partitions
    --skip-gendata
    --gendata-advanced
    --redefine=conf/mariadb/modules/indexes_and_constraints.yy
    --redefine=conf/mariadb/modules/parser_changes.yy
    --redefine=conf/mariadb/generic-dml.yy
    --mysqld=--loose-max-statement-time=30
    --mysqld=--loose-debug_assert_on_not_freed_memory=0
    --mysqld=--lock-wait-timeout=10
    --mysqld=--innodb-lock-wait-timeout=5
  '],
  [
    '--grammar=conf/mariadb/modules/application_periods.yy --reporters=Backtrace,ErrorLog,Deadlock --basedir=/data/src/10.5-overlaps --engine=InnoDB',
    '--grammar=conf/mariadb/modules/application_periods.yy --reporters=Backtrace,ErrorLog,Deadlock --basedir=/data/src/10.5-overlaps --engine=MyISAM --mysqld=--default-storage-engine=MyISAM',
    '--grammar=conf/mariadb/modules/application_periods.yy --reporters=Backtrace,ErrorLog,Deadlock --basedir=/data/src/10.5-overlaps --engine=Aria --mysqld=--default-storage-engine=Aria',
    '--grammar=conf/mariadb/modules/application_periods.yy --reporters=Backtrace,ErrorLog,Deadlock --basedir=/data/src/10.5-overlaps --engine=Memory',
  ],
  [
    '',
    '--ps-protocol'
  ],
  [
    '--basedir=/data/bld/10.5-debug',
    '--basedir=/data/bld/10.5-rel-asan'
  ],
  [ '',
    '
    --redefine=conf/mariadb/bulk_insert.yy
    --redefine=conf/mariadb/versioning.yy
    --redefine=conf/mariadb/modules/alter_table_columns.yy
    --redefine=conf/mariadb/modules/foreign_keys.yy
    --redefine=conf/mariadb/modules/locks.yy
    ',
    '
    --redefine=conf/mariadb/alter_table.yy
    --redefine=conf/mariadb/bulk_insert.yy
    --redefine=conf/mariadb/instant_add.yy
    --redefine=conf/mariadb/sp.yy
    --redefine=conf/mariadb/modules/admin.yy
    --redefine=conf/mariadb/functions.yy
    --redefine=conf/mariadb/modules/optimizer_trace.yy
    --redefine=conf/mariadb/versioning.yy
    --redefine=conf/mariadb/modules/dynamic_variables.yy
    --redefine=conf/mariadb/modules/alter_table_columns.yy
    --redefine=conf/mariadb/modules/foreign_keys.yy
    --redefine=conf/mariadb/modules/locks.yy
    --redefine=conf/mariadb/modules/locks-10.4-extra.yy
    '
  ],
  [ '',
    '
    --validators=TransformerNoComparator
    --transformers=ExecuteAsDeleteReturning,ExecuteAsUpdateDelete,ExecuteAsView,ExecuteAsPreparedTwice,EnableOptimizations,ExecuteAsTrigger,ExecuteAsUnion,ExecuteAsExcept,ExecuteAsIntersect,ExecuteAsCTE,ExecuteAsDerived,DisableIndexes,Distinct,ExecuteAsExecuteImmediate,ExecuteAsFunctionTwice,ExecuteAsOracleSP,ExecuteAsPackageSP,ExecuteAsPreparedTwice,ExecuteAsSelectItem,ExecuteAsSPTwice,ExecuteAsWhereSubquery,Having,LimitRowsExamined,NullIf,OrderBy,SelectOption,StraightJoin
    '
  ]
];
