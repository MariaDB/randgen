use strict;

our ($all_encryption_options, $innodb_pagesize_combinations, $innodb_compression_combinations);
require "$ENV{RQG_HOME}/conf/mariadb/include/parameter_presets";

$combinations = [
  [
  '
  --threads=2
  --duration=120
  --no-mask
  --seed=time
  --grammar=conf/mariadb/oltp-transactional.yy
  --gendata=conf/mariadb/innodb_upgrade.zz
  --gendata=conf/mariadb/innodb_upgrade_compression.zz
  --gendata-advanced
  --reporters=Backtrace,ErrorLog,Deadlock
  --mysqld=--server-id=111
  --mysqld=--log_output=FILE
  --mysqld=--loose-max-statement-time=20
  --mysqld=--lock-wait-timeout=10
  --mysqld=--innodb-lock-wait-timeout=5
  --scenario=NormalUpgrades
  '],
  [ @$innodb_compression_combinations ],
  [ @$innodb_pagesize_combinations ],
  [ '', $all_encryption_options ],
];
