our ($encryption);
require "$ENV{RQG_HOME}/conf/mariadb/include/encryption_on_off";

$combinations = [
  [
  '
  --threads=6
  --duration=250
  --no-mask
  --engine=Aria
  --seed=time
  --redefine=conf/mariadb/bulk_insert.yy
  --scenario-redefine2=conf/mariadb/alter_table.yy
  --scenario=CrashUpgrade
  --reporters=Backtrace,ErrorLog,Deadlock
  --mysqld=--server-id=111
  --mysqld=--log_output=FILE
  --mysqld=--max-statement-time=20
  --mysqld=--lock-wait-timeout=10
  --mysqld=--innodb-lock-wait-timeout=5
  '],
  [
    '--grammar=conf/mariadb/oltp-transactional.yy --gendata=conf/mariadb/oltp-aria.zz',
    '--grammar=conf/mariadb/oltp.yy --gendata=conf/mariadb/oltp-aria.zz',
    '--grammar=conf/mariadb/generic-dml.yy --gendata=conf/mariadb/oltp-aria.zz',
    '--grammar=conf/engines/engine_stress.yy --gendata=conf/engines/engine_stress.zz',
  ],
  [
    '--gendata-advanced --mysqld=--default-storage-engine=Aria',
    '--mysqld=--log_bin_trust_function_creators=1 --mysqld=--log-bin',
    '--mysqld=--aria_group_commit=hard --mysqld=--aria_group_commit_interval=1000000',
  ],
  # Encryption
    $encryption,
];
