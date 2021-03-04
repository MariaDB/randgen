our $grammars_basic;
require "$ENV{RQG_HOME}/conf/mariadb/include/combo.grammars";

# XA removed due to the amount of bugs
#    --redefine=conf/mariadb/xa.yy

$combinations = [ $grammars_basic,
  [
  '
    --no-mask
    --queries=100M
    --duration=400
    --threads=6
    --seed=time
    --views
    --vcols
    --reporters=Backtrace,ErrorLog,Deadlock
    --validators=TransformerNoComparator
    --transformers=ExecuteAsDeleteReturning,ExecuteAsInsertSelect,ExecuteAsUnion,ExecuteAsUpdateDelete,ExecuteAsView,ExecuteAsPreparedTwice,ExecuteAsSPTwice
    --redefine=conf/mariadb/general-workarounds.yy
    --redefine=conf/mariadb/alter_table.yy
    --redefine=conf/mariadb/bulk_insert.yy
    --redefine=conf/mariadb/modules/event.yy
    --redefine=conf/mariadb/sp.yy
    --mysqld=--log_output=FILE
    --mysqld=--log_bin_trust_function_creators=1
    --mysqld=--log-bin
    --mysqld=--loose-max-statement-time=30
    --mysqld=--loose-debug_assert_on_not_freed_memory=0
    --mysqld=--lock-wait-timeout=10
    --mysqld=--innodb-lock-wait-timeout=5
  '], 
  [
    '--engine=InnoDB --mysqld=--innodb-buffer-pool-size=2G',
    '--engine=InnoDB --mysqld=--innodb-buffer-pool-size=2G --mysqld=--ignore-builtin-innodb --mysqld=--plugin-load-add=ha_innodb.so',
    '--engine=MyISAM --mysqld=--default-storage-engine=MyISAM',
  ]
];

