our $mariabackup_scenarios;
require 'conf/mariadb/include/mariabackup.scenarios';

$combinations = [
  [
  '
  --duration=350
  --threads=4
  --seed=time
  --reporters=Backtrace,ErrorLog,Deadlock
  --skip-gendata
  --gendata-advanced
  --views
  --grammar=conf/mariadb/generic-dml.yy
  --redefine=conf/mariadb/bulk_insert.yy
  --filter=conf/mariadb/10.4-combo-filter.ff
  --mysqld=--log_output=FILE
  --mysqld=--max-statement-time=20
  --mysqld=--lock-wait-timeout=10
  --mysqld=--loose-innodb-lock-wait-timeout=5
  --mysqld=--loose-debug_assert_on_not_freed_memory=0
  '],
  # Engines
  [
    '--engine=MyISAM',
    '
    --engine=RocksDB
    --mysqld=--plugin-load-add=ha_rocksdb
    --mysqld=--binlog-format=row
    ',
  ],
  # Scenarios (DML-only, DDL+DML)
    $mariabackup_scenarios,
];
