if ! [ -d $1 ] ; then
  echo "ERROR: The script expects basedir as an argument"
else
  perl ./runall-trials.pl --trials=100 --basedir=$1 --grammar=mdev29557.yy --threads=2 --skip-gendata --vardir=/dev/shm/var_mdev29557 --rr --duration=30
fi
