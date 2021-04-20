#    --mysqld=--sql-mode=ONLY_FULL_GROUP_BY,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
#		--redefine=conf/mariadb/analyze-tables-at-start.yy
$combinations = [
	['
		--no-mask
		--seed=time
		--threads=4
		--duration=250
		--queries=100M
		--reporters=QueryTimeout,Backtrace,ErrorLog,Deadlock
		--mysqld=--log-output=FILE
		--querytimeout=30
    --engine=InnoDB
    --views
    --variators=JsonTables
    --validators=ExitCodeComparator
    --mysqld=--sql-mode=NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
    --mysqld=--character-set-server=utf8mb4
	'], 
	[
		'--grammar=conf/mariadb/all_selects.yy --gendata',
		'--grammar=conf/mariadb/optimizer.yy --gendata',
		'--grammar=conf/optimizer/range_access2.yy --gendata=conf/optimizer/range_access2.zz',
		'--grammar=conf/optimizer/range_access.yy --gendata=conf/optimizer/range_access.zz',
		'--grammar=conf/optimizer/outer_join.yy --gendata=conf/optimizer/outer_join.zz',
		'--grammar=conf/optimizer/optimizer_access_exp.yy',
	], 
];
