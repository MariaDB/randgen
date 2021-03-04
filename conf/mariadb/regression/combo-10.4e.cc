our ($encryption_combinations, $grammars_basic);
require "$ENV{RQG_HOME}/conf/mariadb/include/parameter_presets";
require "$ENV{RQG_HOME}/conf/mariadb/include/combo.grammars";

# Disabled to the amount of bugs
#  --redefine=conf/mariadb/modules/application_periods.yy

$combinations = [
  [
  '
  --threads=6
  --duration=350
  --no-mask
  --seed=time
  --reporters=Backtrace,ErrorLog,Deadlock
  --validators=TransformerNoComparator
  --transformers=ExecuteAsCTE,ExecuteAsExecuteImmediate,ExecuteAsDeleteReturning,ExecuteAsInsertSelect,ExecuteAsUnion,ExecuteAsUpdateDelete,ExecuteAsView,ExecuteAsPreparedTwice,ExecuteAsIntersect,ExecuteAsExcept
  --views
  --filter=conf/mariadb/10.4-combo-filter.ff
  --redefine=conf/mariadb/bulk_insert.yy
  --redefine=conf/mariadb/alter_table.yy
  --redefine=conf/mariadb/sp.yy
  --redefine=conf/mariadb/modules/locks.yy
  --redefine=conf/mariadb/modules/foreign_keys.yy
  --redefine=conf/mariadb/modules/admin.yy
  --redefine=conf/mariadb/modules/sql_mode.yy
  --redefine=conf/mariadb/versioning.yy
  --redefine=conf/mariadb/sequences.yy
  --redefine=conf/mariadb/modules/locks-10.4-extra.yy
  --redefine=conf/mariadb/modules/optimizer_trace.yy
  --mysqld=--server-id=111
  --mysqld=--log_output=FILE
  --mysqld=--max-statement-time=20
  --mysqld=--lock-wait-timeout=10
  --mysqld=--innodb-lock-wait-timeout=5
  '],
  # Combo
    $grammars_basic,
  # Encryption
    $encryption_combinations,
  [
    '',
    '--ps-protocol --filter=conf/mariadb/need-reconnect.ff',
    '--vcols --mysqld=--log-bin --mysqld=--log_bin_trust_function_creators=1',
    '--mysqld=--log-bin --mysqld=--log_bin_trust_function_creators=1 --mysqld=--binlog-format=row',
  ]
];
