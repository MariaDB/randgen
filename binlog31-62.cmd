# Assertion `is_explicit_XA()'
# Crash in xid_t::key_length

if [ -z "$1" ] || ! [ -d "$1" ] || [ -z "$2" ] ; then
 echo "Usage: binlog31-62.cmd <basedir> <vardir>"
elif [[ "$2" =~ /dev/shm ]] ; then
 echo "Vardir should better be not in shm"
else
  perl ./run.pl --basedir=$1 --compatibility=110499 --duration=350 --filter=conf/ff/replication.ff --filter=conf/preview/new_binlog.ff --gendata=data/sql/world.sql --grammar=conf/yy/admin.yy --grammar=conf/yy/bulk_insert.yy --mysqld=--binlog_storage_engine=innodb --mysqld=--default-storage-engine=RocksDB --mysqld=--log_bin --mysqld=--plugin-load-add=ha_rocksdb --mysqld=--slave_parallel_threads=4 --queries=1000000 --reporters=Backtrace,Deadlock --scenario-use-gtid --scenario=Replication --mysqld=--log_bin --threads=1 --vardir=$2 --variator=ExecuteAsSPTwice --seed=1761018125 --filter=conf/preview/domain.ff
fi
