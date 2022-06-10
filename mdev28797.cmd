if [ -z "$1" ] ; then
  echo "Basedir is not specified"
else
  basedir=$1
  shift
  perl ./runall-trials.pl --trials=10 --seed=1654811744 --reporters=ErrorLog --mysqld=--log_output=FILE --mysqld=--max-statement-time=30 --mysqld=--lock-wait-timeout=10 --mysqld=--innodb-lock-wait-timeout=5 --mysqld=--character-set-server=utf16 --engine=InnoDB --duration=350 --redefine=conf/mariadb/modules/metadata_lock_info.yy --redefine=conf/mariadb/modules/dynamic_variables.yy --redefine=conf/mariadb/xa.yy --threads=2 --queries=33333 --gendata=conf/replication/replication-dml_data.zz --short-column-names --grammar=conf/mariadb/oltp_and_ddl.yy --skip-gendata --gendata-advanced --vardir=/dev/shm/var-mdev28797 --basedir=$basedir $*
fi
