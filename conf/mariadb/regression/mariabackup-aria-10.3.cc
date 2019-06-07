our ($encryption, $mariabackup_scenarios);
require 'conf/mariadb/include/encryption_on_off';
require 'conf/mariadb/include/mariabackup-10.3.scenarios';

$combinations = [
  [
  '
  --duration=350
  --threads=4
  --seed=time
  --reporters=Backtrace,ErrorLog,Deadlock
  --skip-gendata
  --gendata-advanced
  --engine=Aria
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
  # Encryption
    $encryption,
  # Scenarios (DML-only, DDL+DML)
    $mariabackup_scenarios,
];
