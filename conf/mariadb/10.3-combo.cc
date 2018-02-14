our $grammars;
require 'conf/mariadb/combo.grammars';

$combinations = [ $grammars,
  [
  '
    --no-mask
    --queries=100M
    --duration=350
    --threads=6
    --seed=time
    --views
    --vcols
    --reporters=Backtrace,ErrorLog,Deadlock
    --validators=TransformerNoComparator
    --transformers=ExecuteAsCTE,ExecuteAsDeleteReturning,ExecuteAsExcept,ExecuteAsExecuteImmediate,ExecuteAsInsertSelect,ExecuteAsIntersect,ExecuteAsUnion,ExecuteAsUpdateDelete,ExecuteAsView,ExecuteAsPreparedTwice,ExecuteAsSPTwice
    --redefine=conf/mariadb/general-workarounds.yy
    --redefine=conf/mariadb/alter_table.yy
    --redefine=conf/mariadb/bulk_insert.yy
    --redefine=conf/mariadb/xa.yy
    --redefine=conf/mariadb/versioning.yy
    --redefine=conf/mariadb/sequences.yy
    --mysqld=--log_output=FILE
    --mysqld=--log-bin
    --mysqld=--log_bin_trust_function_creators=1
    --mysqld=--loose-max-statement-time=30
    --mysqld=--loose-debug_assert_on_not_freed_memory=0
  '], 
  [
    '--engine=InnoDB --mysqld=--innodb-buffer-pool-size=256M',
    '--mysqld=--default-storage-engine=MyISAM --engine=MyISAM',
    '--mysqld=--plugin-load-add=ha_rocksdb --mysqld=--binlog-format=ROW --mysqld=--default-storage-engine=RocksDB --engine=RocksDB',
  ]
];
