$combinations = [
	[
	'
		--no-mask
		--seed=time
		--threads=4
		--duration=400
		--reporters=Backtrace,ErrorLog,Deadlock
    --redefine=conf/mariadb/bulk_insert.yy
    --redefine=conf/mariadb/versioning.yy
    --redefine=conf/mariadb/alter_table.yy
    --redefine=conf/mariadb/instant_add.yy
    --redefine=conf/mariadb/redefine_temporary_tables.yy
    --redefine=conf/mariadb/modules/admin.yy
    --redefine=conf/mariadb/modules/alter_table_columns.yy
    --redefine=conf/mariadb/modules/alter_table_indexes.yy
    --redefine=conf/mariadb/modules/foreign_keys.yy
    --redefine=conf/mariadb/modules/locks-10.4-extra.yy
    --redefine=conf/mariadb/modules/locks.yy
    --redefine=conf/mariadb/modules/optimizer_trace.yy
    --redefine=conf/mariadb/modules/sql_mode.yy
    --redefine=conf/mariadb/xa.yy
		--mysqld=--log_output=FILE
		--mysqld=--log_bin_trust_function_creators=1
    --mysqld=--max-statement-time=20
    --mysqld=--lock-wait-timeout=10
    --mysqld=--innodb-lock-wait-timeout=5
    --mysqld=--slave-skip-errors=1049,1305,1539,1505,1317,1568
    --mysqld=--loose-debug_assert_on_not_freed_memory=0
    --gendata-advanced
    --filter=conf/mariadb/10.4-combo-filter-asan.ff
	'],
  [
    '--rpl_mode=mixed-nosync',
    '--rpl_mode=row-nosync'
  ],
  [
    '--mysqld=--secure-timestamp=YES',
    '--mysqld=--secure-timestamp=NO',
  ],
	[
		'--grammar=conf/runtime/metadata_stability.yy --gendata=conf/runtime/metadata_stability.zz',
		'--grammar=conf/runtime/performance_schema.yy --mysqld=--performance-schema=on --mysqld=--performance-schema-instrument="%=ON" --mysqld=--performance-schema-consumer-events-stages-current=ON --mysqld=--performance-schema-consumer-events-stages-history=ON --mysqld=--performance-schema-consumer-events-stages-history-long=ON --mysqld=--performance-schema-consumer-events-statements-current=ON --mysqld=--performance-schema-consumer-events-statements-history=ON --mysqld=--performance-schema-consumer-events-statements-history-long=ON --mysqld=--performance-schema-consumer-events-transactions-current=ON --mysqld=--performance-schema-consumer-events-transactions-history=ON --mysqld=--performance-schema-consumer-events-transactions-history-long=ON --mysqld=--performance-schema-consumer-events-waits-current=ON --mysqld=--performance-schema-consumer-events-waits-history=ON --mysqld=--performance-schema-consumer-events-waits-history-long=ON --mysqld=--performance-schema-consumer-global-instrumentation=ON --mysqld=--performance-schema-consumer-thread-instrumentation=ON --mysqld=--performance-schema-consumer-statements-digest=ON',
		'--grammar=conf/runtime/information_schema.yy',
		'--grammar=conf/engines/many_indexes.yy --gendata=conf/engines/many_indexes.zz',
		'--grammar=conf/engines/engine_stress.yy --gendata=conf/engines/engine_stress.zz',
		'--grammar=conf/partitioning/partitions.yy',
		'--grammar=conf/partitioning/partition_pruning.yy --gendata=conf/partitioning/partition_pruning.zz',
		'--grammar=conf/replication/replication.yy --gendata=conf/replication/replication-5.1.zz',
		'--grammar=conf/replication/replication-ddl_sql.yy --gendata=conf/replication/replication-ddl_data.zz',
		'--grammar=conf/replication/replication-dml_sql.yy --gendata=conf/replication/replication-dml_data.zz',
		'--grammar=conf/runtime/connect_kill_sql.yy --gendata=conf/runtime/connect_kill_data.zz',
		'--grammar=conf/runtime/WL5004_sql.yy --gendata=conf/runtime/WL5004_data.zz',
    '--grammar=conf/mariadb/optimizer.yy --gendata',
    '--grammar=conf/optimizer/updateable_views.yy --mysqld=--init-file='.getcwd().'/conf/optimizer/updateable_views.init',
    '--grammar=conf/mariadb/oltp_and_ddl.yy --gendata=conf/mariadb/oltp.zz',
    '--grammar=conf/mariadb/functions.yy',
    '--grammar=conf/runtime/alter_online.yy --gendata=conf/runtime/alter_online.zz',
	],
	[
		'',
		'--engine=InnoDB,MyISAM,Aria',
	],
];

