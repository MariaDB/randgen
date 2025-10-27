# [ERROR] RocksDB: Failed to read/write in RocksDB, Status Code: 4, Status: Invalid argument: Transaction name must be unique

if [ -z "$1" ] || ! [ -d "$1" ] ; then
 echo "Usage: binlog34-81.cmd <basedir>"
else
  perl ./run.pl --basedir=$1 --compatibility=110899 --duration=200 --engine=RocksDB --gendata=simple --grammar=conf/yy/dml-ps-params.yy --grammar=conf/yy/replication.yy --grammar=conf/yy/xa.yy --mysqld=--binlog_storage_engine=innodb --mysqld=--default-storage-engine=RocksDB --mysqld=--innodb-lock-wait-timeout=10 --mysqld=--lock-wait-timeout=20 --mysqld=--log_bin --mysqld=--plugin-load-add=ha_rocksdb --queries=1000000 --reporters=Backtrace,Deadlock --scenario=Standard --threads=4 --vardir=/dev/shm/var-invalid-arg --seed=1761437910
fi
