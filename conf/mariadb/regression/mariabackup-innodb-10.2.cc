use strict;

our ($innodb_encryption_options, $mariabackup_scenarios, $innodb_pagesize_combinations, $innodb_compression_combinations);
require "$ENV{RQG_HOME}/conf/mariadb/include/parameter_presets";
require "$ENV{RQG_HOME}/conf/mariadb/include/mariabackup.scenarios";

$combinations = [
  [
  '
  --duration=350
  --threads=4
  --seed=time
  --reporters=Backtrace,ErrorLog,Deadlock
  --skip-gendata
  --gendata-advanced
  --engine=InnoDB
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
  [ @$innodb_compression_combinations ],
  [ @$innodb_pagesize_combinations ],
  [ '', $innodb_encryption_options ],
  # Scenarios (DML-only, DDL+DML)
    $mariabackup_scenarios,
];
