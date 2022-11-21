use strict;

our ($all_encryption_options, $upgrade_scenarios, $innodb_pagesize_combinations, $innodb_compression_combinations);
require "$ENV{RQG_HOME}/conf/mariadb/include/parameter_presets";
require "$ENV{RQG_HOME}/conf/mariadb/include/upgrade.scenarios";

$combinations = [
  [
  '
  --threads=4
  --seed=time
  --gendata=conf/mariadb/innodb.zz
  --gendata=conf/mariadb/innodb_upgrade.zz
  --gendata-advanced
  --reporters=Backtrace,ErrorLog,Deadlock
  --mysqld=--server-id=111
  --mysqld=--log_output=FILE
  --mysqld=--loose-max-statement-time=20
  --mysqld=--lock-wait-timeout=10
  --mysqld=--innodb-lock-wait-timeout=5
  '],
  [ @$innodb_compression_combinations ],
  [ @$innodb_pagesize_combinations ],
  [ '', $all_encryption_options ],
  # Scenarios
    $upgrade_scenarios,
];
