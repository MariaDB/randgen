if [ -z "$1" ] ; then
  echo "Usage: ./mdev34252.cmd <basedir>"
else
  basedir=$1
  shift
  perl ./run.pl --gendata=simple --duration=200 --mysqld=--max-statement-time=10 --mysqld=--lock-wait-timeout=6 --mysqld=--innodb-lock-wait-timeout=3 --threads=4 --grammar=mdev34252.yy --filter=conf/ff/restrict_dynamic_vars.ff --scenario=CrashRecovery --engine=InnoDB --mysqld=--character-set-server=cp1251 --mysqld=--collation-server=cp1251_general_nopad_ci --mysqld=--slow_query-log=ON --reporters=Deadlock,Backtrace --base-port=34250 --vardir=/dev/shm/mdev34252 --seed=1716758547 --basedir=$basedir $* --output="DDL_LOG: Got error 1050 when trying to execute action for entry" --trials=5
fi
