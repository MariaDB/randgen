our ($encryption, $grammars);
require 'conf/mariadb/include/encryption_on_off';
require 'conf/mariadb/include/combo.grammars';

#  --redefine=s3.yy
#  --mysqld=--s3=ON
#  --mysqld="--s3-bucket=..."
#  --mysqld="--s3-access-key=..."
#  --mysqld="--s3-secret-key=..."
#  --mysqld="--s3-region=..."

$combinations = [
  [
  '
  --threads=4
  --duration=600
  --no-mask
  --seed=time
  --reporters=Backtrace,ErrorLog,Deadlock
  --views
  --filter=conf/mariadb/10.4-combo-filter.ff
  --redefine=conf/mariadb/bulk_insert.yy
  --redefine=conf/mariadb/alter_table.yy
  --redefine=conf/mariadb/sp.yy
  --redefine=conf/mariadb/modules/locks.yy
  --redefine=conf/mariadb/modules/admin.yy
  --redefine=conf/mariadb/modules/sql_mode.yy
  --redefine=conf/mariadb/versioning.yy
  --redefine=conf/mariadb/modules/locks-10.4-extra.yy
  --redefine=conf/mariadb/modules/application_periods.yy
  --redefine=conf/mariadb/modules/optimizer_trace.yy
  --mysqld=--server-id=111
  --mysqld=--log_output=FILE
  --mysqld=--max-statement-time=20
  --mysqld=--lock-wait-timeout=10
  --mysqld=--innodb-lock-wait-timeout=5
  --mysqld=--thread_stack=1310720
  --engine=Aria
  '],
  # Combo
    $grammars,
  # Encryption
    $encryption,
  [
    '',
    '--vcols --mysqld=--log-bin --mysqld=--log_bin_trust_function_creators=1',
    '--ps-protocol --filter=conf/mariadb/need-reconnect.ff'
  ]
];
