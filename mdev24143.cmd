if [ "$#" -lt 2 ] ; then
  echo "Usage: . ./mdev24143.cmd <basedir> <path to galera library>"
elif [ ! -d $1 ] ; then
  echo "Basedir $1 does not exist or not a directory"
elif [ ! -f $2 ] ; then
  echo "Galera library $2 does not exist"
else
  perl ./runall-new.pl --grammar=mdev24143.yy --vardir=/dev/shm/var_mdev24143 --duration=300 --threads=1 --galera=mms --mysqld=--lock-wait-timeout=3 --basedir=$1 --mysqld=--wsrep-provider=$2
fi
