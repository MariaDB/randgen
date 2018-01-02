$combinations = [
	[
	'
		--no-mask
		--seed=time
		--threads=6
		--duration=400
		--queries=100M
		--reporters=Backtrace,ErrorLog,Deadlock
    --validators=TransformerNoComparator
    --transformers=ExecuteAsExecuteImmediate,ExecuteAsPreparedTwice,ExecuteAsSPTwice
		--redefine=conf/mariadb/general-workarounds.yy
		--mysqld=--log_output=FILE
    --mysqld=--max-statement-time=30
    --redefine=conf/mariadb/alter_table.yy
    --mysqld=--plugin-load-add=file_key_management
    --mysqld=--loose-file-key-management-filename='.getcwd().'/data/file_key_management_keys.txt
    --mysqld=--loose-debug_assert_on_not_freed_memory=0
    --rpl_mode=mixed-nosync
    --mysqld=--slave-skip-errors=1049,1305,1539,1505,1317,1568
    --mysqld=--log_bin_trust_function_creators=1
    --vcols
    --views
    --redefine=conf/mariadb/bulk_insert.yy
	'], 
	[
		'--grammar=conf/runtime/metadata_stability.yy --gendata=conf/runtime/metadata_stability.zz',
		'--grammar=conf/runtime/performance_schema.yy --mysqld=--performance-schema',
		'--grammar=conf/runtime/information_schema.yy',
		'--grammar=conf/runtime/information_schema.yy --skip-gendata --gendata-advanced',
		'--grammar=conf/engines/many_indexes.yy --gendata=conf/engines/many_indexes.zz',
		'--grammar=conf/engines/engine_stress.yy --gendata=conf/engines/engine_stress.zz',
		'--grammar=conf/partitioning/partitions.yy',
		'--grammar=conf/partitioning/partition_pruning.yy --gendata=conf/partitioning/partition_pruning.zz',
		'--grammar=conf/replication/replication.yy --gendata=conf/replication/replication-5.1.zz',
		'--grammar=conf/replication/replication-ddl_sql.yy --gendata=conf/replication/replication-ddl_data.zz',
		'--grammar=conf/replication/replication-dml_sql.yy --gendata=conf/replication/replication-dml_data.zz',
		'--grammar=conf/runtime/connect_kill_sql.yy --gendata=conf/runtime/connect_kill_data.zz',
		'--grammar=conf/runtime/WL5004_sql.yy --gendata=conf/runtime/WL5004_data.zz',
    '--grammar=conf/optimizer/updateable_views.yy --mysqld=--init-file='.getcwd().'/conf/optimizer/updateable_views.init',
    '--grammar=conf/mariadb/oltp-transactional.yy --gendata=conf/mariadb/innodb_upgrade.zz',
    '--grammar=conf/mariadb/oltp-transactional.yy --skip-gendata --gendata-advanced',
    '--grammar=conf/mariadb/oltp-transactional.yy',
    '--grammar=conf/mariadb/oltp.yy --gendata=conf/mariadb/innodb_upgrade.zz',
    '--grammar=conf/mariadb/functions.yy --skip-gendata --gendata-advanced',
    '--grammar=conf/runtime/alter_online.yy --gendata=conf/runtime/alter_online.zz',
	],
	[
		'--mysqld=--old-alter-table',
		'--mysqld=--sql-mode=STRICT_TRANS_TABLES'
	],
  [
    '--engine=InnoDB --mysqld=--innodb_undo_tablespaces=3',
    '--engine=InnoDB --mysqld=--innodb-stats-on-metadata=on',
    '',
    '--engine=MyISAM',
    '--engine=Aria',
  ]
];

