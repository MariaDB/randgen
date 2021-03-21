if [ $# -ne 1 ] ; then
  echo "Usage ./mdev25214.cmd <basedir>"
else
  perl ./runall-new.pl  --duration=350  --mysqld=--max-statement-time=30 --mysqld=--lock-wait-timeout=10 --mysqld=--innodb-lock-wait-timeout=5 --short-column-names  --grammar=conf/mariadb/oltp_and_ddl.yy --gendata=conf/engines/innodb/full_text_search.zz --threads=1 --queries=100000     --mysqld=--innodb-encrypt-tables --mysqld=--innodb-encrypt-log --mysqld=--innodb-encryption-threads=4 --mysqld=--file-key-management --mysqld=--file-key-management-filename=`pwd`/data/file_key_management_keys.txt --mysqld=--plugin-load-add=file_key_management      --mysqld=--innodb-open-files=200 --engine=InnoDB  --mtr-build-thread=52 --seed=1616240246 --vardir1=/dev/shm/var_mdev25214 --basedir1=$1
fi
