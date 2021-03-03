our ($all_encryption_options, $grammars);
require "$ENV{RQG_HOME}/conf/mariadb/include/parameter_presets";
require "$ENV{RQG_HOME}/conf/mariadb/include/combo.grammars";

$combinations = [
  [
  '
  --threads=6
  --duration=350
  --seed=time
  --reporters=Backtrace,ErrorLog,Deadlock
  --partitions
  --vcols
  --views
  --engine=InnoDB,MyISAM,Aria
  --filter=conf/mariadb/10.4-combo-filter.ff
  --redefine=conf/mariadb/bulk_insert.yy
  --redefine=conf/mariadb/alter_table.yy
  --redefine=conf/mariadb/sp.yy
  --redefine=conf/mariadb/modules/admin.yy
  --redefine=conf/mariadb/modules/alter_table_columns.yy
  --redefine=conf/mariadb/modules/alter_table_indexes.yy
  --redefine=conf/mariadb/modules/foreign_keys.yy
  --redefine=conf/mariadb/modules/locks.yy
  --redefine=conf/mariadb/modules/parser_changes.yy
  --mysqld=--server-id=111
  --mysqld=--log_output=FILE
  --mysqld=--max-statement-time=20
  --mysqld=--lock-wait-timeout=10
  --mysqld=--innodb-lock-wait-timeout=5
  '],
  # Combo
    $grammars,
  [
    '--redefine=conf/mariadb/modules/dynamic_variables.yy',
    '--ps-protocol --filter=conf/mariadb/need-reconnect.ff',
    '--redefine=conf/mariadb/modules/dynamic_variables.yy --validators=TransformerNoComparator --transformers=ExecuteAsCTE,ExecuteAsExecuteImmediate,ExecuteAsDeleteReturning,ExecuteAsInsertSelect,ExecuteAsUnion,ExecuteAsUpdateDelete,ExecuteAsView,ExecuteAsPreparedTwice,EnableOptimizations',
    $all_encryption_options
  ],
  [
    '',
    '--mysqld=--log-bin --mysqld=--log_bin_trust_function_creators=1',
  ],
];
