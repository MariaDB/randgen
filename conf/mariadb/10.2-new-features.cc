#
# Configuration file for testing 10.2 features and changes
#
# MDEV-6112 multiple triggers per table
#    redefine=conf/mariadb/redefine_multiple_triggers.yy is added
# MDEV-10385 Refactor threadpool
#    thread pool turned on
# MDEV-7635 new defaults
#    binlog_format=MIXED is set for testing purposes (until it's changed by default)
# MDEV-5535 cannot reopen temporary table
#    conf/mariadb/redefine_temporary_tables.yy is added

$combinations = [
    [
    '
        --no-mask
        --seed=time
        --threads=8
        --duration=300
        --queries=100M
        --reporters=QueryTimeout,Backtrace,ErrorLog,Deadlock
        --validators=QueryProperties,TransformerNoComparator
        --transformers=ExecuteAsExecuteImmediate
        --redefine=conf/mariadb/general-workarounds.yy
        --redefine=conf/mariadb/redefine_multiple_triggers.yy
        --redefine=conf/mariadb/redefine_temporary_tables.yy
        --mysqld=--log_output=FILE
        --mysqld=--log_bin_trust_function_creators=1
        --use-gtid=current_pos
        --mysqld=--slave_parallel_threads=8
        --mysqld=--performance_schema=1
        --mysqld=--log_bin
        --mysqld=--binlog_format=MIXED
        --mysqld=--thread_handling=pool-of-threads
    '], 
    [
        '--views --grammar=conf/runtime/metadata_stability.yy --gendata=conf/runtime/metadata_stability.zz',
        '--views --grammar=conf/runtime/performance_schema.yy',
        '--views --grammar=conf/runtime/information_schema.yy',
        '--views --grammar=conf/engines/many_indexes.yy --gendata=conf/engines/many_indexes.zz',
        '--grammar=conf/engines/engine_stress.yy --gendata=conf/engines/engine_stress.zz',
        '--views --grammar=conf/partitioning/partitions.yy',
        '--views --grammar=conf/replication/replication.yy --gendata=conf/replication/replication-5.1.zz',
        '--grammar=conf/replication/replication-ddl_sql.yy --gendata=conf/replication/replication-ddl_data.zz',
        '--views --grammar=conf/replication/replication-dml_sql.yy --gendata=conf/replication/replication-dml_data.zz',
        '--views --grammar=conf/runtime/connect_kill_sql.yy --gendata=conf/runtime/connect_kill_data.zz',
        '--views --grammar=conf/runtime/WL5004_sql.yy --gendata=conf/runtime/WL5004_data.zz'
    ]
];
