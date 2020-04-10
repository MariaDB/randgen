if [ $# -lt 2 ] ; then
  echo
  echo "ERROR: You need to provide at least --basedir=<basedir> --vardir=<vardir>"
  echo "       possibly also --mysqld=--wsrep-provider=<path> and --mysqld=--wsrep-node-address=<value>, depending on your environment"
  echo
else
    perl runall-new.pl --threads=3 --duration=350 --seed=1 --skip-gendata --grammar=mdev22216.yy --mysqld=--wsrep_on=ON --mysqld=--wsrep_cluster_address=gcomm:// --mysqld=--wsrep_sst_method=rsync --mysqld=--innodb_doublewrite=1 --mysqld=--log-bin --mysqld=--loose-binlog-format=row $@
fi
