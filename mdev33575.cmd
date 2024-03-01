if [ -n "$1" ] ; then
  perl ./run.pl --grammar=mdev33575.yy --threads=2 --duration=120 --mysqld=--max-statement-time=5 --vardir=/dev/shm/var-mdev33575 --nometadata-reload --gendata=simple --basedir=$1
else
  echo "ERROR: provide basedir as the first argument"
fi
