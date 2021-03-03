our ($encryption_combinations, $recovery_scenarios, $innodb_pagesize_combinations, $innodb_compression_combinations);
require "$ENV{RQG_HOME}/conf/mariadb/include/parameter_presets";
require "$ENV{RQG_HOME}/conf/mariadb/include/recovery.scenarios";

$combinations = [
  [
  '
  --threads=4
  --no-mask
  --seed=time
  --grammar=conf/mariadb/oltp-transactional.yy
  --gendata=conf/mariadb/innodb_upgrade.zz
  --gendata=conf/mariadb/innodb_upgrade_compression.zz
  --gendata-advanced
  --reporters=Backtrace,ErrorLog,Deadlock
  --mysqld=--server-id=111
  --mysqld=--log_output=FILE
  --mysqld=--max-statement-time=20
  --mysqld=--lock-wait-timeout=10
  --mysqld=--innodb-lock-wait-timeout=5
  --scenario-grammar2=conf/mariadb/oltp_and_ddl.yy
  '],
  # Compression
    $innodb_compression_combinations,
  # Pagesize
    $innodb_pagesize_combinations,
  # Encryption
    $encryption_combinations,
  # Scenarios
    $recovery_scenarios,
];
