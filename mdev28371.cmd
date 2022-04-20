if [ -z "$1" ] ; then
  echo "Usage: $0 <basedir>"
else
  perl ./runall-new.pl --short-column-names --gendata=mdev28371.zz --grammar=mdev28371.yy --duration=350 --seed=1650335485 --mysqld=--max-statement-time=30 --mysqld=--lock-wait-timeout=10 --mysqld=--innodb-lock-wait-timeout=5 --threads=1 --queries=25000 --engine=InnoDB --mysqld=--innodb-page-size=4K --vardir=/dev/shm/var-mdev28371 --basedir=$1
fi
