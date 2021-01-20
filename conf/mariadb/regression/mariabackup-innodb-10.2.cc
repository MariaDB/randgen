our ($encryption, $mariabackup_scenarios, $innodb_pagesizes, $innodb_compression);
require "$ENV{RQG_HOME}/conf/mariadb/include/encryption_on_off";
require "$ENV{RQG_HOME}/conf/mariadb/include/mariabackup.scenarios";
require "$ENV{RQG_HOME}/conf/mariadb/include/innodb_pagesize";
require "$ENV{RQG_HOME}/conf/mariadb/include/innodb_compression";

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
  # Compression
    $innodb_compression,
  # Pagesize
    $innodb_pagesizes,
  # Encryption
    $encryption,
  # Scenarios (DML-only, DDL+DML)
    $mariabackup_scenarios,
];
