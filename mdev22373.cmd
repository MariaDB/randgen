# Unset CHECK_TABLE if the test shouldn't run CHECK TABLE after restart
# (to allow to proceed to corruption errors upon DML)
# By default CHECK TABLE is executed

check_table=1

# Unset DATADIR_BACKUP so that the test doesn't store the datadir
# after each server restart. If there are many restarts, it can take a lot of space,
# which can be problematic especially if the test runs in shm

datadir_backup=1

CHECK_TABLE=$check_table DATADIR_BACKUP=$datadir_backup perl ./runall-new.pl --seed=1622299458 --duration=3600 --gendata=mdev22373.sql --reporters=Restart --restart-timeout=60 --threads=64 --grammar=conf/mariadb/oltp.yy --mysqld=--sql-mode=NO_ENGINE_SUBSTITUTION --mysqld=--innodb-flush-method=fsync --vardir=/dev/shm/mdev22373 --mtr-build-thread=373 $*
