# perl ./run.pl  --grammar=mdev32551.yy   --gendata=simple    --mysqld=--binlog_format=ROW        --mysqld=--log_bin --mysqld=--log_bin_compress=ON --mysqld=--log-bin-compress-min-len=256  --mysqld=--log_bin_trust_function_creators=ON      --mysqld=--rpl_semi_sync_master_enabled=ON --mysqld=--rpl_semi_sync_slave_enabled=ON                           --queries=1000000 --reporters=ErrorLog --scenario-nosync --threads=1 --duration=180 --mysqld=--max-statement-time=20 --mysqld=--lock-wait-timeout=10 --mysqld=--innodb-lock-wait-timeout=5  --scenario=Replication --engine=InnoDB  --base-port=14000 --basedir=/data/bld/10.6-asan  --vardir=/dev/shm/var3 --seed=1698467889 --trials=20 --output="magic number error" --mysqld=--slave_exec_mode=IDEMPOTENT

query:
#  STOP SLAVE ;; RESET SLAVE ;; START SLAVE |
#  RESET MASTER |
#  SET GLOBAL sql_slave_skip_counter = 10 ;; START SLAVE |
  SET GLOBAL rpl_semi_sync_slave_enabled= __on_x_off(80) 
#  SET GLOBAL rpl_semi_sync_master_enabled= __on_x_off(80)
;

thread1:
  /*executor2 STOP SLAVE */ ;; /*executor2 START SLAVE */ |
  /*executor2 SET GLOBAL rpl_semi_sync_slave_enabled= __on_x_off(80) */
;

