# Unset CHECK_TABLE if the test shouldn't run CHECK TABLE after restart
# (to allow to proceed to corruption errors upon DML)
# By default CHECK TABLE is executed

check_table=1

# Unset DATADIR_BACKUP so that the test doesn't store the datadir
# after each server restart. If there are many restarts, it can take a lot of space,
# which can be problematic especially if the test runs in shm

datadir_backup=0

CHECK_TABLE=$check_table DATADIR_BACKUP=$datadir_backup perl ./runall-new.pl --seed=1622299458 --duration=3600 --vardir=/dev/shm/mdev22373 --mtr-build-thread=373 --rows=3000 --gendata=mdev22373.sql --reporter=Restart --restart-timeout=60 --threads=32 --grammar=mdev22373.yy --mysqld=--sql-mode=NO_ENGINE_SUBSTITUTION --mysqld=--innodb-flush-method=fsync --mysqld=--innodb-page-size=4K --mysqld=--innodb-buffer-pool-size=32M $*

