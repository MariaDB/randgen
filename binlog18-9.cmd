# mysqld: storage/innobase/handler/innodb_binlog.cc:3268: int gtid_search::find_gtid_pos(slave_connection_state*, rpl_binlog_state_base*, uint64_t*, uint64_t*): Assertion `(page1 - page0) % diff_state_page_interval == 0' failed.

if [ -z "$1" ] || ! [ -d "$1" ] ; then
  echo "Usage: binlog18-9.cmd <basedir>"
else
  perl ./run.pl --duration=180 --gendata=conf/zz/oltp.zz --grammar=binlog18-9.yy --server1-mysqld=--binlog-directory=binlogs --mysqld=--binlog_storage_engine=innodb --mysqld=--log_bin  --scenario=Replication --threads=1 --reporter=ReplicationStartUntil --nometadata-reload --vardir=/dev/shm/var-find-gtid-pos --seed=1759620571 --mysqld=--ignore-db-dirs=binlogs --basedir=$1
fi
