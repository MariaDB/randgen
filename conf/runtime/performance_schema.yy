# Copyright (C) 2010 Sun Microsystems, Inc. All rights reserved.
# Copyright (c) 2021, MariaDB Corporation Ab.
# Use is subject to license terms.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
# USA

query_add:
  perfschema_query { $last_database= undef; $last_table= undef; '' };

perfschema_query:
  ==FACTOR:0.1== perfschema_ddl |
	perfschema_dml |
	{ @nonaggregates = () ; @table_names = () ; @database_names = () ; $tables = 0 ; $fields = 0 ; "" } perfschema_select |
	perfschema_update_settings |
	==FACTOR:0.1== perfschema_truncate |
	perfschema_show_engine ;

perfschema_yes_no:
	'YES' | 'NO' ;

perfschema_enabled_timed:
	ENABLED | TIMED ;

perfschema_update_settings:
	perfschema_update_consumers |
	perfschema_update_instruments |
	perfschema_update_timers ;

perfschema_update_consumers:
	UPDATE performance_schema . setup_consumers SET enabled = perfschema_yes_no WHERE name IN ( perfschema_consumer_list ) |
	UPDATE performance_schema . setup_consumers SET enabled = perfschema_yes_no WHERE name LIKE perfschema_consumer_category ;

perfschema_update_instruments:
	UPDATE performance_schema . setup_instruments SET perfschema_enabled_timed = perfschema_yes_no WHERE NAME LIKE perfschema_instrument_category |
	UPDATE performance_schema . setup_instruments SET perfschema_enabled_timed = perfschema_yes_no ORDER BY RAND() LIMIT _digit ;

perfschema_update_timers:
	UPDATE performance_schema . setup_timers SET timer_name = perfschema_timer_type ;

perfschema_truncate:
	TRUNCATE TABLE performance_schema . perfschema_truncateable_table ;

perfschema_truncateable_table:
	perfschema_events_waits_current |
	perfschema_events_waits_history | perfschema_events_waits_history_long |
	perfschema_events_waits_summary_by_event_name | perfschema_events_waits_summary_by_instance | perfschema_events_waits_summary_by_thread_by_event_name |
	file_summary_by_event_name | file_summary_by_instance ;

perfschema_consumer_list:
	perfschema_consumer |
	perfschema_consumer_list , perfschema_consumer ;

perfschema_consumer:
	'events_waits_current' |
	'events_waits_history' |
	'events_waits_history_long' |
	'events_waits_summary_by_thread_by_event_name' |
	'events_waits_summary_by_event_name' |
	'events_waits_summary_by_instance' |
	'file_summary_by_event_name' |
	'file_summary_by_instance';

perfschema_consumer_category:
	'events%' | 'file%';

perfschema_instrument_category:
	'wait%' |
	'wait/synch%' | 'wait/io%' |
	'wait/synch/mutex/%' | 'wait/synch/rwlock%' | 'wait/synch/cond%' |
	'%mysys%' | '%sql%' | '%myisam%' ;

perfschema_timer_type:
	'CYCLE' | 'NANOSECOND' | 'MICROSECOND' | 'MILLISECOND' | 'TICK' ;

perfschema_show_engine:
	SHOW ENGINE PERFORMANCE_SCHEMA STATUS ;

perfschema_ddl:
#	character_sets |
#	collations |
#	collation_character_set_applicability |
	perfschema_columns |
	perfschema_column_privileges |
#	engines |
	perfschema_events |
#	files |
#	global_status |
#	global_variables |
	perfschema_key_column_usage |
	perfschema_parameters |
	perfschema_partitions |
#	plugins |
#	processlist |
#	profiling |
#	referential_constraints |
#	routines |		# same as perfschema_parameters
	perfschema_schemata |
	perfschema_schema_privileges |
#	session_status |
#	session_variables |
#	statistics |
	perfschema_tables |
#	perfschema_tablespaces |
	perfschema_table_constraints |
	perfschema_table_privileges |
	perfschema_triggers |
	perfschema_user_privileges |
	perfschema_views ;

perfschema_columns:
	ALTER TABLE _table ADD COLUMN _letter INTEGER DEFAULT NULL |
	ALTER TABLE _table DROP COLUMN _letter ;

perfschema_column_privileges:
	GRANT perfschema_privilege_list ON _table TO 'someuser'@'somehost';

perfschema_events:
	CREATE EVENT _basics_if_not_exists_80pct _letter ON SCHEDULE AT NOW() DO SET @a=@a |
	DROP EVENT _basics_if_exists_80pct _letter ;

perfschema_key_column_usage:
	ALTER TABLE _table ADD KEY ( _letter ) |
	ALTER TABLE _table DROP KEY _letter ;

perfschema_parameters:
	CREATE PROCEDURE _basics_if_not_exists_80pct _letter ( perfschema_procedure_parameter_list ) BEGIN SELECT COUNT(*) INTO @a FROM _table; END ; |
	DROP PROCEDURE _basics_if_exists_80pct _letter |
	CREATE FUNCTION _basics_if_not_exists_80pct _letter ( perfschema_function_parameter_list ) RETURNS INTEGER RETURN 1 |
	DROP FUNCTION _basics_if_exists_80pct _letter ;

perfschema_partitions:
	ALTER TABLE _table PARTITION BY KEY() PARTITIONS _digit |
	ALTER TABLE _table REMOVE PARTITIONING ;

perfschema_schemata:
	CREATE DATABASE _basics_if_not_exists_80pct _letter |
	DROP DATABASE _basics_if_exists_80pct _letter ;

perfschema_schema_privileges:
	GRANT ALL PRIVILEGES ON _letter . * TO 'someuser'@'somehost' |
	REVOKE ALL PRIVILEGES ON _letter . * FROM 'someuser'@'somehost' ; 

perfschema_tables:
	CREATE TABLE _basics_if_not_exists_80pct _letter LIKE _table |
	DROP TABLE _basics_if_exists_80pct _letter ;

perfschema_table_constraints:
	ALTER TABLE _table DROP PRIMARY KEY |
	ALTER TABLE _table ADD PRIMARY KEY (`pk`) ;

perfschema_table_privileges:
	GRANT ALL PRIVILEGES ON test . _letter TO 'someuser'@'somehost' |
	REVOKE ALL PRIVILEGES ON test . _letter FROM 'someuser'@'somehost' ;

perfschema_triggers:
	CREATE TRIGGER _basics_if_not_exists_80pct _letter BEFORE INSERT ON _table FOR EACH ROW BEGIN INSERT INTO _table SELECT * FROM _table LIMIT 0 ; END ; |
	DROP TRIGGER _basics_if_exists_80pct _letter;

perfschema_user_privileges:
	GRANT perfschema_admin_privilege_list ON * . * to 'someuser'@'somehost' |
	REVOKE perfschema_admin_privilege_list ON * . * FROM 'someuser'@'somehost' ;

perfschema_admin_privilege_list:
	perfschema_admin_privilege |
	perfschema_admin_privilege , perfschema_admin_privilege_list ;

perfschema_admin_privilege:
	CREATE USER |
	PROCESS |
	RELOAD |
	REPLICATION CLIENT |
	REPLICATION SLAVE |
	SHOW DATABASES |
	SHUTDOWN |
	SUPER |
#	ALL PRIVILEGES |
	USAGE ;

perfschema_views:
	CREATE OR REPLACE VIEW _letter AS SELECT * FROM _table |
	DROP VIEW IF EXISTS _letter ;

perfschema_function_parameter_list:
	_letter INTEGER , _letter INTEGER ;

perfschema_procedure_parameter_list:
	perfschema_parameter |
	perfschema_parameter , perfschema_procedure_parameter_list ;

perfschema_parameter:
	perfschema_in_out _letter INT ;

perfschema_in_out:
	IN | OUT ;
	

perfschema_privilege_list:
	perfschema_privilege_item |
	perfschema_privilege_item , perfschema_privilege_list ;

perfschema_privilege_item:
	perfschema_privilege ( perfschema_field_list );

perfschema_privilege:
	INSERT | SELECT | UPDATE ;

perfschema_field_list:
	_field |
	_field , perfschema_field_list ;

perfschema_select:
	SELECT *
	FROM perfschema_join_list
	perfschema_where
	perfschema_group_by
	perfschema_having
	perfschema_order_by_limit
;

perfschema_select_list:
	perfschema_new_select_item |
	perfschema_new_select_item , perfschema_select_list ;

perfschema_join_list:
	perfschema_new_table_item |
	perfschema_new_table_item |
	perfschema_new_table_item |
	perfschema_new_table_item |
	(perfschema_new_table_item perfschema_join_type perfschema_new_table_item ON ( perfschema_current_table_item . _field = perfschema_previous_table_item . _field ) ) ;

perfschema_join_type:
	INNER JOIN | perfschema_left_right perfschema_outer JOIN | STRAIGHT_JOIN ;

perfschema_left_right:
	LEFT | RIGHT ;

perfschema_outer:
	| OUTER ;

perfschema_where:
	|
	WHERE perfschema_where_list ;

perfschema_where_list:
	_basics_not_33pct perfschema_where_item |
	_basics_not_33pct (perfschema_where_list AND perfschema_where_item) |
	_basics_not_33pct (perfschema_where_list OR perfschema_where_item) ;

perfschema_where_item:
	perfschema_existing_table_item . _field IN ( _digit , _digit , _digit ) |
	perfschema_existing_table_item . _field LIKE perfschema_instrument_category |
	perfschema_existing_table_item . _field perfschema_sign perfschema_value |
	perfschema_existing_table_item . _field perfschema_sign perfschema_existing_table_item . _field ;

perfschema_group_by:
	{ scalar(@nonaggregates) > 0 ? " GROUP BY ".join (', ' , @nonaggregates ) : "" };

perfschema_having:
	| HAVING perfschema_having_list;

perfschema_having_list:
	_basics_not_33pct perfschema_having_item |
	_basics_not_33pct (perfschema_having_list AND perfschema_having_item) |
	_basics_not_33pct (perfschema_having_list OR perfschema_having_item) |
	perfschema_having_item IS _basics_not_33pct NULL ;

perfschema_having_item:
	perfschema_existing_table_item . _field perfschema_sign perfschema_value ;

perfschema_order_by_limit:
	LIMIT _tinyint_unsigned	|
#	ORDER BY perfschema_order_by_list |
	ORDER BY perfschema_order_by_list LIMIT _tinyint_unsigned ;

perfschema_order_by_list:
	perfschema_order_by_item |
	perfschema_order_by_item , perfschema_order_by_list ;

perfschema_order_by_item:
	perfschema_existing_table_item . _field ;

perfschema_new_select_item:
	nonaggregate_select_item |
	nonaggregate_select_item |
	aggregate_select_item;

nonaggregate_select_item:
	table_one_two . _field AS { my $f = "field".++$fields ; push @nonaggregates , $f ; $f} ;

aggregate_select_item:
	aggregate table_one_two . _field ) AS { "field".++$fields };

# Only 20% table2, since sometimes table2 is not present at all

table_one_two:
	table1 { $last_table = $tables[1] } | 
	table2 { $last_table = $tables[2] } ;

aggregate:
	COUNT( | SUM( | MIN( | MAX( ;

perfschema_new_table_item:
	perfschema_database . _table AS { $database_names[++$tables] = $last_database ; $table_names[$tables] = $last_table ; "table".$tables };

perfschema_database:
	{ $last_database = $prng->arrayElement(['mysql','test','INFORMATION_SCHEMA','performance_schema']); return $last_database };

perfschema_current_table_item:
	{ $last_database = $database_names[$tables] ; $last_table = $table_names[$tables] ; "table".$tables };

perfschema_previous_table_item:
	{ $last_database = $database_names[$tables-1] ; $last_table = $table_names[$tables-1] ; "table".($tables - 1) };

perfschema_existing_table_item:
	{ my $i = $prng->int(1,$tables) ; $last_database = $database_names[$i]; $last_table = $table_names[$i] ; "table".$i };

perfschema_sign:
	= | > | < | != | <> | <= | >= ;
	
perfschema_value:
	_digit | _char(2) | _datetime ;

perfschema_dml:
        perfschema_update | perfschema_insert | perfschema_delete ;

perfschema_update:
        UPDATE _table SET _field = perfschema_value WHERE _field perfschema_sign perfschema_value ;

perfschema_delete:
        DELETE FROM _table WHERE _field perfschema_sign perfschema_value LIMIT _digit ;

perfschema_insert:
        INSERT INTO _table ( `pk` ) VALUES  (NULL);

