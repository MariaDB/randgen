$combinations = [
	[
	'
		--no-mask
		--seed=time
		--threads=6
		--duration=600
		--queries=100M
		--reporters=Backtrace,ErrorLog,Deadlock
    --validators=TransformerNoComparator
    --transformers=ConvertSubqueriesToViews,ConvertTablesToDerived,Count,DisableIndexes,DisableOptimizations,Distinct,EnableOptimizations,ExecuteAsCTE,ExecuteAsDeleteReturning,ExecuteAsDerived,ExecuteAsExcept,ExecuteAsExecuteImmediate,ExecuteAsInsertSelect,ExecuteAsIntersect,ExecuteAsSelectItem,ExecuteAsUnion,ExecuteAsUpdateDelete,ExecuteAsView,ExecuteAsWhereSubquery,Having,InlineSubqueries,InlineVirtualColumns,LimitRowsExamined,OrderBy,StraightJoin,ExecuteAsPreparedTwice,ExecuteAsTrigger,ExecuteAsSPTwice,ExecuteAsFunctionTwice
		--redefine=conf/mariadb/general-workarounds.yy
		--mysqld=--log_output=FILE
		--mysqld=--log_bin_trust_function_creators=1
    --mysqld=--max-statement-time=30
    --redefine=conf/mariadb/hidden_columns.yy
    --rpl_mode=mixed-nosync
    --mysqld=--slave-skip-errors=1049,1305,1539,1505,1317,1568
    --mysqld=--loose-debug_assert_on_not_freed_memory=0
    --views
    --vcols
    --skip-gendata
	'], 
	[
		'--grammar=conf/runtime/metadata_stability.yy --gendata=conf/runtime/metadata_stability.zz',
		'--grammar=conf/runtime/metadata_stability.yy --gendata-advanced',
		'--grammar=conf/runtime/performance_schema.yy --mysqld=--performance-schema --gendata-advanced',
		'--grammar=conf/runtime/information_schema.yy --gendata-advanced',
		'--grammar=conf/engines/many_indexes.yy --gendata=conf/engines/many_indexes.zz',
		'--grammar=conf/engines/many_indexes.yy --gendata-advanced',
		'--grammar=conf/engines/engine_stress.yy --gendata=conf/engines/engine_stress.zz',
		'--grammar=conf/engines/engine_stress.yy --gendata-advanced',
		'--grammar=conf/partitioning/partitions.yy --gendata-advanced',
		'--grammar=conf/partitioning/partition_pruning.yy --gendata=conf/partitioning/partition_pruning.zz',
		'--grammar=conf/partitioning/partition_pruning.yy --gendata-advanced',
		'--grammar=conf/replication/replication.yy --gendata=conf/replication/replication-5.1.zz',
		'--grammar=conf/replication/replication.yy  --gendata-advanced',
		'--grammar=conf/replication/replication-ddl_sql.yy --gendata=conf/replication/replication-ddl_data.zz',
		'--grammar=conf/replication/replication-ddl_sql.yy  --gendata-advanced',
		'--grammar=conf/replication/replication-dml_sql.yy --gendata=conf/replication/replication-dml_data.zz',
		'--grammar=conf/replication/replication-dml_sql.yy  --gendata-advanced',
		'--grammar=conf/runtime/connect_kill_sql.yy --gendata=conf/runtime/connect_kill_data.zz',
		'--grammar=conf/runtime/connect_kill_sql.yy  --gendata-advanced',
		'--grammar=conf/runtime/WL5004_sql.yy --gendata=conf/runtime/WL5004_data.zz',
		'--grammar=conf/runtime/WL5004_sql.yy  --gendata-advanced',
    '--grammar=conf/mariadb/optimizer.yy --gendata-advanced',
    '--grammar=conf/optimizer/updateable_views.yy --mysqld=--init-file='.getcwd().'/conf/optimizer/updateable_views.init',
    '--grammar=conf/mariadb/oltp-transactional.yy --gendata-advanced',
    '--grammar=conf/mariadb/oltp.yy --gendata-advanced',
    '--grammar=conf/mariadb/functions.yy --gendata-advanced',
    '--grammar=conf/runtime/alter_online.yy --gendata=conf/runtime/alter_online.zz',
    '--grammar=conf/runtime/alter_online.yy  --gendata-advanced',
    '--grammar=conf/optimizer/range_access.yy --gendata=conf/optimizer/range_access.zz',
    '--grammar=conf/optimizer/range_access.yy  --gendata-advanced',
	],
	[
		'',
		'--engine=InnoDB',
    '--engine=MyISAM --mysqld=--default-storage-engine=MyISAM',
    '--engine=Aria --mysqld=--default-storage-engine=Aria'
	],
];

