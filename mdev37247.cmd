if [ $# -lt 1 ] ; then
  echo "Provide a basedir as an argument"
else
  perl ./run.pl --grammar=mdev37247.yy --gendata=mdev37247.sql --basedir=$1 --vardir=/dev/shm/var-mdev37247 --threads=4 --duration=300 --mysqld=--lock-wait-timeout=40 --mysqld=--innodb-lock-wait-timeout=20 --mysqld=--log-bin
fi
