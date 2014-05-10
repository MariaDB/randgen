thread4_init:
	PREPARE show_expl_stmt FROM "SHOW EXPLAIN FOR ?"; 

thread4:
	show_explain |
	explain_iud |
	engine_independent_statistics |
	flush_export |
	create_or_replace
;

thread7:
	thread4;

thread3:
	set_names_or_charset | 
	query | query | query | query | query | query ;

#############################
# CREATE OR REPLACE

create_or_replace:
	create_or_replace_as_select | create_or_replace_like ;

create_or_replace_as_select:
	CREATE OR REPLACE TEMPORARY TABLE `tmp` AS SELECT * FROM _table[invariant] ; CREATE OR REPLACE TABLE _table[invariant] AS SELECT * FROM `tmp` ;

create_or_replace_like:
	CREATE OR REPLACE TEMPORARY TABLE `tmp` LIKE _table[invariant] ; INSERT INTO `tmp` SELECT * FROM _table[invariant] ; CREATE OR REPLACE TABLE _table[invariant] LIKE `tmp`; INSERT INTO _table[invariant] SELECT * FROM `tmp`;


#############################
# FLUSH TABLES .. FOR EXPORT

flush_export:
	FLUSH TABLE flush_table_list FOR EXPORT ; UNLOCK TABLES ;

flush_table_list:
	_table | flush_table_list, _table ;

#############################
# SHOW EXPLAIN

show_explain:
	SELECT ID INTO @thread_id FROM INFORMATION_SCHEMA.PROCESSLIST ORDER BY RAND() LIMIT 1 ; EXECUTE stmt USING @thread_id ;

#############################
# EXPLAIN UPDATE/DELETE/INSERT

explain_iud:
	EXPLAIN explain_iud_extended query ;

explain_iud_extended:
	| EXTENDED ;

#############################
# Engine-independent statistics

engine_independent_statistics:
	eistat_analyze_stats | eistat_analyze_stats | eistat_analyze_stats | eistat_analyze_stats | 
	eistat_analyze_stats | eistat_analyze_stats | eistat_analyze_stats | eistat_analyze_stats |
	eistat_analyze_stats | eistat_analyze_stats | eistat_analyze_stats | eistat_analyze_stats |
	eistat_analyze_stats | eistat_analyze_stats | eistat_analyze_stats | eistat_analyze_stats |
	eistat_set_use_stat_tables | eistat_set_use_stat_tables | 
	eistat_select_stat ;

eistat_analyze_stats:
	ANALYZE TABLE _table eistat_persistent_for |
	ANALYZE TABLE _basetable PERSISTENT FOR COLUMNS eistat_persistent_for_columns INDEXES  eistat_persistent_for_real_indexes
	;

eistat_persistent_for:
	| 
	PERSISTENT FOR ALL |
	PERSISTENT FOR COLUMNS eistat_persistent_for_columns |
	PERSISTENT FOR COLUMNS eistat_persistent_for_columns INDEXES eistat_persistent_for_columns ;

eistat_persistent_for_columns:
	ALL | ( eistat_columns ) ;

eistat_persistent_for_real_indexes:
	ALL | ( eistat_indexes ) ;
	
eistat_columns:
	 | | _field | _field | _field, _field, _field, _field ;

eistat_indexes:
	 | | 
	PRIMARY |
	eistat_indexed | eistat_indexed | 
	eistat_indexed, eistat_indexed, eistat_indexed, eistat_indexed |
# Hoping to create an existing multi-part index name sometimes
	{ '`'.$prng->arrayElement($fields_indexed).'_'.$prng->arrayElement($fields_indexed).'`' }
;

eistat_indexed:
	_field_key | _field_key | _field_key | _field_key | _field ;

eistat_set_use_stat_tables:
	SET eistat_scope use_stat_tables = eistat_use_stat_tables ;

eistat_use_stat_tables:
	PREFERABLY | COMPLEMENTARY | NEVER ;

eistat_scope:
	| SESSION | GLOBAL ;

eistat_stat_table:
	`mysql` . `table_stats` | `mysql` . `column_stats` | `mysql` . `index_stats` ;

eistat_select_stat:
	SELECT * FROM eistat_stat_table WHERE `table_name` = '_table' ;

set_names_or_charset:
	SELECT CHARACTER_SET_NAME INTO @cset FROM INFORMATION_SCHEMA.CHARACTER_SETS ORDER BY RAND() LIMIT 1; SET @stmt_names_or_charset = CONCAT( names_or_charset, @cset ); add_collation ; PREPARE stmt_names_or_charset FROM @stmt_names_or_charset ; EXECUTE stmt_names_or_charset ; DEALLOCATE PREPARE stmt_names_or_charset |
	SET NAMES DEFAULT |
	SET CHARACTER SET DEFAULT ;

names_or_charset:
	'SET NAMES ' | 'SET CHARACTER SET ' ;

add_collation:
	valid_collation | valid_collation | valid_collation | valid_collation | valid_collation | valid_collation | 
	invalid_collation ;

valid_collation:
	SELECT CONCAT(@stmt_names_or_charset, ' COLLATE ', COLLATION_NAME) INTO @stmt_names_or_charset FROM INFORMATION_SCHEMA.COLLATIONS WHERE CHARACTER_SET_NAME = @cset ORDER BY RAND() LIMIT 1;

invalid_collation:
        SELECT CONCAT(@stmt_names_or_charset, ' COLLATE ', COLLATION_NAME) INTO @stmt_names_or_charset FROM INFORMATION_SCHEMA.COLLATIONS WHERE CHARACTER_SET_NAME != @cset ORDER BY RAND() LIMIT 1;

