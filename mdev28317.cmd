if [ -z "$1" ] ; then
  echo "Usage: $0 <basedir>"
else
  perl ./runall-new.pl --mysqld=--loose-innodb-read-only-compressed=on --engine=InnoDB --scenario=MariaBackupFull --mysqld=--innodb-undo-tablespaces=64 --short-column-names --grammar=conf/mariadb/generic-dml.yy --duration=350 --seed=1649853872 --reporters=Backtrace,ErrorLog,Deadlock --mysqld=--max-statement-time=10 --mysqld=--lock-wait-timeout=5 --mysqld=--innodb-lock-wait-timeout=2 --redefine=conf/mariadb/sp.yy --redefine=conf/mariadb/modules/foreign_keys.yy --redefine=conf/mariadb/modules/disks.yy --redefine=conf/mariadb/modules/locks-10.4-extra.yy --redefine=conf/mariadb/modules/parser_changes.yy --threads=8 --queries=12500 --vardir=/dev/shm/var-mdev28317 --basedir=$1
fi
