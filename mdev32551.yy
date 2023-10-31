# perl ./run.pl --grammar=mdev32551.yy --mysqld=--rpl_semi_sync_master_enabled=ON --mysqld=--rpl_semi_sync_slave_enabled=ON  --reporters=ErrorLog --scenario-nosync --threads=1 --duration=80 --scenario=Replication --base-port=14000 --basedir=/data/src/10.6.12-8/ --vardir=/dev/shm/var1 --seed=1698467889 --trials=20 --output="magic number error"  --nometadata-reload

query:
  SELECT 1 ;

thread1:
  /*executor2 SET GLOBAL rpl_semi_sync_slave_enabled= OFF */ ;; /*executor2 STOP SLAVE IO_THREAD */ ;; /*executor2 START SLAVE IO_THREAD */ ;; /*executor2 SET GLOBAL rpl_semi_sync_slave_enabled= ON */
;

