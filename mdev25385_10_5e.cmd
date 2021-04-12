if [ $# -lt 1 ] ; then
  echo "Provide basedir"
else
  testdir=`pwd`
  perl ./runall-trials.pl --trials=5 --gendata-advanced --grammar=mdev25385.yy --threads=8 --duration=150 --seed=1618014694 --partitions --engine=InnoDB,MyISAM,Aria --mysqld=--max-statement-time=20 --mysqld=--lock-wait-timeout=10 --mysqld=--innodb-lock-wait-timeout=5 --mysqld=--innodb-encrypt-tables --mysqld=--innodb-encrypt-log --mysqld=--innodb-encryption-threads=4 --mysqld=--aria-encrypt-tables=1 --mysqld=--encrypt-tmp-disk-tables=1 --mysqld=--encrypt-binlog --mysqld=--file-key-management --mysqld=--file-key-management-filename=$testdir/data/file_key_management_keys.txt --mysqld=--plugin-load-add=file_key_management --vardir=/dev/shm/var_mdev25385_10_5e --basedir=$1
fi
