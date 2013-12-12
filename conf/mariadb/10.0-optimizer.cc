$combinations = [
	['
		--no-mask
		--seed=time
		--threads=5
		--duration=400
		--queries=100M
		--reporters=QueryTimeout,Backtrace,ErrorLog,Deadlock
		--validator=Transformer
		--transformers=DisableOptimizations,ExecuteAsDerived,DisableJoinCache,ExecuteAsPreparedTwice,ExecuteAsDeleteReturning
		--redefine=conf/mariadb/10.0-features-redefine.yy
		--mysqld=--log-output=FILE
		--mysqld=--slow_query_log
		--mysqld=--long_query_time=0.000001
		--querytimeout=30
	'], 
	[
		'--grammar=conf/optimizer/optimizer_subquery.yy --views=TEMPTABLE',
		'--grammar=conf/optimizer/optimizer_subquery.yy --notnull --views=TEMPTABLE',
		'--grammar=conf/optimizer/optimizer_subquery.yy --views=MERGE',
		'--grammar=conf/optimizer/optimizer_subquery.yy --notnull --views=MERGE',
		'--grammar=conf/optimizer/optimizer_subquery.yy --skip-gendata --mysqld=--init-file=$RQG_HOME/conf/mariadb/world.sql',
		'--grammar=conf/optimizer/optimizer_subquery_semijoin.yy --views=TEMPTABLE',
		'--grammar=conf/optimizer/optimizer_subquery_semijoin.yy --notnull --views=TEMPTABLE',
		'--grammar=conf/optimizer/optimizer_subquery_semijoin.yy --views=MERGE',
		'--grammar=conf/optimizer/optimizer_subquery_semijoin.yy --notnull --views=MERGE',
		'--grammar=conf/optimizer/optimizer_subquery_semijoin.yy --skip-gendata --mysqld=--init-file=$RQG_HOME/conf/mariadb/world.sql',
		'--grammar=conf/optimizer/range_access2.yy --gendata=conf/optimizer/range_access2.zz',
		'--grammar=conf/optimizer/range_access.yy --gendata=conf/optimizer/range_access.zz',
		'--grammar=conf/optimizer/optimizer_subquery_no_outer_join.yy --views=TEMPTABLE',
		'--grammar=conf/optimizer/optimizer_subquery_no_outer_join.yy --notnull --views=TEMPTABLE',
		'--grammar=conf/optimizer/optimizer_subquery_no_outer_join.yy --views=MERGE',
		'--grammar=conf/optimizer/optimizer_subquery_no_outer_join.yy --notnull --views=MERGE',
		'--grammar=conf/optimizer/optimizer_subquery_no_outer_join.yy --skip-gendata --mysqld=--init-file=$RQG_HOME/conf/mariadb/world.sql',
		'--grammar=conf/optimizer/outer_join.yy --gendata=conf/optimizer/outer_join.zz',
		'--grammar=conf/optimizer/optimizer_no_subquery.yy --views=TEMPTABLE',
		'--grammar=conf/optimizer/optimizer_no_subquery.yy --notnull --views=TEMPTABLE',
		'--grammar=conf/optimizer/optimizer_no_subquery.yy --views=MERGE',
		'--grammar=conf/optimizer/optimizer_no_subquery.yy --notnull --views=MERGE',
		'--grammar=conf/optimizer/optimizer_no_subquery.yy --skip-gendata --mysqld=--init-file=$RQG_HOME/conf/mariadb/world.sql',
		'--grammar=conf/optimizer/optimizer_access_exp.yy --views=TEMPTABLE',
		'--grammar=conf/optimizer/optimizer_access_exp.yy --notnull --views=TEMPTABLE',
		'--grammar=conf/optimizer/optimizer_access_exp.yy --views=MERGE',
		'--grammar=conf/optimizer/optimizer_access_exp.yy --notnull --views=MERGE',
		'--grammar=conf/optimizer/optimizer_access_exp.yy --skip-gendata --mysqld=--init-file=$RQG_HOME/conf/mariadb/world.sql',
	], 
	[
		'--engine=Aria',
		'--engine=MyISAM',
		'--engine=InnoDB',
		'--engine=TokuDB --mysqld=--plugin-load=ha_tokudb.so --mysqld=--loose-tokudb',
		''
	],
	['
		--mysqld=--optimizer_switch=extended_keys=on,exists_to_in=on 
		--mysqld=--use_stat_tables=PREFERABLY
		--mysqld=--optimizer_selectivity_sampling_limit=100 
		--mysqld=--optimizer_use_condition_selectivity=5 
		--mysqld=--histogram_size=100 
		--mysqld=--histogram_type=DOUBLE_PREC_HB
		--mysqld=--log_slow_verbosity=query_plan,explain
	']
];
