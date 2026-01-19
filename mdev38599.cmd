# Concurrent DML and REPAIR leads to replication failure

if [ -z "$1" ] || ! [ -d "$1" ] ; then
 echo "Usage: mdev38599.cmd <basedir> [RQG options of your choice]"
else
  basedir=$1
  shift
  perl ./run.pl --base-port=17000 --basedir=$basedir --duration=200 --grammar=mdev38599.yy --mysqld=--innodb-lock-wait-timeout=2 --mysqld=--lock-wait-timeout=4 --mysqld=--log-bin --mysqld=--max-statement-time=6 --reporters=Backtrace,Deadlock --scenario=Replication --threads=4 --vardir=/dev/shm/var-mdev38599 --seed=1768603409 --nometadata-reload $*
fi
