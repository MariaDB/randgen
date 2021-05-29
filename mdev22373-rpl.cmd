# Unset CHECK_TABLE if the test shouldn't run CHECK TABLE after restart
# (to allow to proceed to corruption errors upon DML)
# By default CHECK TABLE is executed

check_table=1

# Unset DATADIR_BACKUP so that the test doesn't store the datadir
# after each server restart. If there are many restarts, it can take a lot of space,
# which can be problematic especially if the test runs in shm

datadir_backup=1

CHECK_TABLE=$check_table DATADIR_BACKUP=$datadir_backup perl ./runall-new.pl --mysqld1=--innodb-buffer-pool-size=4G --mysqld=--sql-mode=NO_ENGINE_SUBSTITUTION --seed=1622299458 --duration=3600 --gendata=mdev22373.sql --reporters=SlaveCrashRecovery --restart-timeout=60 --threads=64 --rpl-mode=mixed --grammar=conf/mariadb/oltp.yy --mysqld2=--skip-slave-start --mysqld2=--innodb-flush-method=fsync --mysqld2=--slave-parallel-threads=32 --mysqld2=--slave-parallel-workers=32 --mtr-build-thread=373 --vardir=/dev/shm/mdev22373 $*
