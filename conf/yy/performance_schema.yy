# Copyright (C) 2010 Sun Microsystems, Inc. All rights reserved.
# Copyright (c) 2021, 2022 MariaDB Corporation Ab.
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

query:
  { _set_db('NON-SYSTEM') } perfschema_query ;

perfschema_query:
  ==FACTOR:0.1== perfschema_ddl |
  perfschema_dml |
  { @nonaggregates = () ; @table_names = () ; @database_names = () ; $tables = 0 ; $fields = 0 ; "" } perfschema_select |
  perfschema_update_settings |
  ==FACTOR:0.1== perfschema_truncate |
  perfschema_show_engine |
  sysschema_stored_routine ;

perfschema_update_settings:
  perfschema_update_consumers |
  perfschema_update_instruments |
  perfschema_update_timers ;

perfschema_update_consumers:
  UPDATE performance_schema . setup_consumers SET enabled = yes_or_no WHERE name IN ( perfschema_consumer_list ) |
  UPDATE performance_schema . setup_consumers SET enabled = yes_or_no WHERE name LIKE perfschema_consumer_category ;

perfschema_update_instruments:
  UPDATE performance_schema . setup_instruments SET __enabled_x_timed = yes_or_no WHERE NAME LIKE perfschema_instrument_category |
  UPDATE performance_schema . setup_instruments SET __enabled_x_timed = yes_or_no ORDER BY RAND(_int_unsigned) LIMIT _digit ;

perfschema_update_timers:
  UPDATE performance_schema . setup_timers SET timer_name = perfschema_timer_type ;

perfschema_truncate:
  TRUNCATE TABLE performance_schema . perfschema_truncateable_table ;

perfschema_truncateable_table:
  events_waits_current |
  events_waits_history | events_waits_history_long |
  events_waits_summary_by_event_name | events_waits_summary_by_instance | events_waits_summary_by_thread_by_event_name |
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
#  character_sets |
#  collations |
#  collation_character_set_applicability |
  perfschema_columns |
  perfschema_column_privileges |
#  engines |
  perfschema_events |
#  files |
#  global_status |
#  global_variables |
  perfschema_key_column_usage |
  perfschema_parameters |
  perfschema_partitions |
#  plugins |
#  processlist |
#  profiling |
#  referential_constraints |
#  routines |    # same as perfschema_parameters
  perfschema_schemata |
  perfschema_schema_privileges |
#  session_status |
#  session_variables |
#  statistics |
  perfschema_tables |
#  perfschema_tablespaces |
  perfschema_table_constraints |
  perfschema_table_privileges |
  perfschema_triggers |
  perfschema_user_privileges |
  perfschema_views ;

perfschema_columns:
  ALTER TABLE _table ADD COLUMN _letter INTEGER DEFAULT NULL |
  ALTER TABLE _table DROP COLUMN _letter ;

perfschema_column_privileges:
  GRANT /* _table[invariant] */ perfschema_privilege_list ON _table[invariant] TO 'someuser'@'somehost';

perfschema_events:
  CREATE __or_replace(90) EVENT _letter ON SCHEDULE AT NOW() DO SET @a=@a |
  CREATE EVENT __if_not_exists(90) _letter ON SCHEDULE AT NOW() DO SET @a=@a |
  DROP EVENT __if_exists(95) _letter ;

perfschema_key_column_usage:
  ALTER TABLE _table ADD KEY ( _letter __asc_x_desc(33,33)) |
  ALTER TABLE _table DROP KEY _letter ;

perfschema_parameters:
  CREATE PROCEDURE __if_not_exists(80) _letter ( perfschema_procedure_parameter_list ) BEGIN SELECT COUNT(*) INTO @a FROM _table; END |
  DROP PROCEDURE __if_exists(80) _letter |
  CREATE FUNCTION __if_not_exists(80) _letter ( perfschema_function_parameter_list ) RETURNS INTEGER RETURN 1 |
  DROP FUNCTION __if_exists(80) _letter ;

perfschema_partitions:
  ALTER TABLE _table PARTITION BY KEY() PARTITIONS _digit |
  ALTER TABLE _table REMOVE PARTITIONING ;

perfschema_schemata:
  CREATE DATABASE __if_not_exists(80) _letter |
  DROP DATABASE __if_exists(80) _letter ;

perfschema_schema_privileges:
  GRANT ALL PRIVILEGES ON _letter . * TO 'someuser'@'somehost' |
  REVOKE ALL PRIVILEGES ON _letter . * FROM 'someuser'@'somehost' ;

perfschema_tables:
  CREATE TABLE __if_not_exists(80) _letter LIKE _table |
  DROP TABLE __if_exists(80) _letter ;

perfschema_table_constraints:
  ALTER TABLE _table DROP PRIMARY KEY |
  ALTER TABLE _table ADD PRIMARY KEY (`pk` __asc_x_desc(33,33)) ;

perfschema_table_privileges:
  GRANT ALL PRIVILEGES ON test . _letter TO 'someuser'@'somehost' |
  REVOKE ALL PRIVILEGES ON test . _letter FROM 'someuser'@'somehost' ;

perfschema_triggers:
  CREATE TRIGGER __if_not_exists(80) _letter BEFORE INSERT ON _table FOR EACH ROW BEGIN INSERT INTO _table SELECT * FROM _table LIMIT 0 ; END |
  DROP TRIGGER __if_exists(80) _letter;

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
#  ALL PRIVILEGES |
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
  __in_x_out _letter INT ;

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

perfschema_join_list:
  perfschema_new_table_item |
  perfschema_new_table_item |
  perfschema_new_table_item |
  perfschema_new_table_item |
  (perfschema_new_table_item perfschema_join_type perfschema_new_table_item ON ( perfschema_current_table_item . _field = perfschema_previous_table_item . _field ) ) ;

perfschema_join_type:
  INNER JOIN | __left_x_right(50) __outer(50) JOIN | STRAIGHT_JOIN ;

perfschema_where:
  |
  WHERE perfschema_where_list ;

perfschema_where_list:
  __not(30) perfschema_where_item |
  __not(30) (perfschema_where_list AND perfschema_where_item) |
  __not(30) (perfschema_where_list OR perfschema_where_item) ;

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
  __not(30) perfschema_having_item |
  __not(30) (perfschema_having_list AND perfschema_having_item) |
  __not(30) (perfschema_having_list OR perfschema_having_item) |
  perfschema_having_item IS __not(30) NULL ;

perfschema_having_item:
  perfschema_existing_table_item . _field perfschema_sign perfschema_value ;

perfschema_order_by_limit:
  LIMIT _tinyint_unsigned  |
#  ORDER BY perfschema_order_by_list |
  ORDER BY perfschema_order_by_list LIMIT _tinyint_unsigned ;

perfschema_order_by_list:
  perfschema_order_by_item |
  perfschema_order_by_item , perfschema_order_by_list ;

perfschema_order_by_item:
  perfschema_existing_table_item . _field ;

# Only 20% table2, since sometimes table2 is not present at all

perfschema_new_table_item:
  _table AS { $database_names[++$tables] = $last_database ; $table_names[$tables] = $last_table ; "table".$tables };

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

yes_or_no:
  'YES' | 'NO' ;

sysschema_stored_routine:
  DROP DATABASE IF EXISTS { $dbcopy= 'db_copy_'.$prng->int(1,9) } ;; CALL sys.create_synonym_db(sys_database_name_param, { $dbcopy }) |
  CALL sys.diagnostics(_int_unsigned, _int_unsigned, sys_auto_config_param) |
  CALL sys.execute_prepared_stmt('SELECT * FROM mysql.user') |
  SELECT sys.extract_schema_from_file_name(_english) |
  SELECT sys.extract_table_from_file_name(_english) |
  SELECT sys.format_bytes(_float) |
  SELECT sys.format_path(_string) |
  SELECT sys.format_statement('SELECT * FROM mysql.user') |
  SELECT sys.format_time(_bigint_unsigned) |
  SELECT sys.list_add(_text,_english) |
  SELECT sys.list_drop(_text,_english) |
  CALL sys.optimizer_switch_choice(on_or_off) |
  CALL sys.optimizer_switch_off() |
  CALL sys.optimizer_switch_on() |
  # TODO: need real consumers, instruments, etc
  SELECT sys.ps_is_account_enabled('localhost',_user) |
  SELECT sys.ps_is_consumer_enabled(_string) |
  SELECT sys.ps_is_instrument_default_enabled(_string) |
  SELECT sys.ps_is_thread_instrumented(_bigint_unsigned) |
  CALL sys.ps_setup_disable_background_threads() |
  CALL sys.ps_setup_disable_consumer(_string) |
  CALL sys.ps_setup_disable_instrument(_string) |
  CALL sys.ps_setup_disable_thread(_bigint_unsigned) |
  CALL sys.ps_setup_enable_background_threads() |
  CALL sys.ps_setup_enable_consumer(_string) |
  CALL sys.ps_setup_enable_instrument(_string) |
  CALL sys.ps_setup_enable_thread(_bigint_unsigned) |
  CALL sys.ps_setup_reload_saved() |
  CALL sys.ps_setup_reset_to_default() |
  CALL sys.ps_setup_save(_int) |
  CALL sys.ps_setup_show_disabled(__true_x_false, __true_x_false) |
  CALL sys.ps_setup_show_disabled_consumers() |
  CALL sys.ps_setup_show_disabled_instruments() |
  CALL sys.ps_setup_show_enabled(__true_x_false, __true_x_false) |
  CALL sys.ps_setup_show_enabled_consumers() |
  CALL sys.ps_setup_show_enabled_instruments() |
  CALL sys.ps_statement_avg_latency_histogram() |
  SELECT sys.ps_thread_account(_bigint_unsigned) |
  SELECT sys.ps_thread_id(_bigint_unsigned) |
  SELECT sys.ps_thread_stack(_bigint_unsigned ,__true_x_false) |
  SELECT sys.ps_thread_trx_info(_bigitn_unsigned) |
  CALL sys.ps_trace_statement_digest(_english, _int, _float, __true_x_false, __true_x_false) |
  CALL sys.ps_trace_thread(_bigint_unsigned, _string, _float, _float, __true_x_false, __true_x_false, __true_x_false) |
  CALL sys.ps_truncate_all_tables(__true_x_false) |
  SELECT sys.quote_identifier(_english) |
  CALL sys.statement_performance_analyzer(sys_action_param, sys_table_param, sys_views_param) |
  # TODO: Need real variables and values?
  CALL sys.sys_get_config(_string,_string) |
  CALL sys.table_exists(sys_database_name_param,sys_table_name_param,sys_views_param) |
  SELECT sys.version_major() |
  SELECT sys.version_minor() |
  SELECT sys.version_patch()
;

on_or_off:
  'ON' | 'OFF' ;

sys_database_name_param:
  { "'".$prng->arrayElement($executors->[0]->metaAllNonEmptySchemas()) || $prng->arrayElement($executors->[0]->metaAllSchemas()."'" } ;

sys_table_name_param:
  { "'".$prng->arrayElement($executors->[0]->metaTables($work_database))."'" } ;

sys_table_exists_param:
  '' | 'BASE TABLE' | 'VIEW' | 'TEMPORARY' | 'SEQUENCE' | 'SYSTEM VIEW' | 'TEMPORARY SEQUENCE' ;

sys_auto_config_param:
  'current' | 'medium' | 'full' ;

sys_action_param:
  'snapshot' | 'overall' | 'delta' | 'create_table' | 'create_tmp' | 'save' | 'cleanup' ;

sys_table_param:
  sys_table_name_param | NULL | NOW() ;

sys_views_param:
  'with_runtimes_in_95th_percentile' | 'analysis' | 'with_errors_or_warnings' | 'with_full_table_scans' | 'with_sorting' | 'with_temp_tables' | 'custom' ;
