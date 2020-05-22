#  Copyright (c) 2019, 2020, MariaDB
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; version 2 of the License.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA */


########################################################################
# Application periods (10.4+)
# MDEV-16973, MDEV-16974, MDEV-16975, MDEV-17082
# WITHOUT OVERLAPS (10.5.3)
# MDEV-16978
#
# Can be used as a standalone or redefining grammar.
#
# ATTENTION:
# It assumes the use of basics.yy as a redefining grammar for primitives.
#
# Specifics:
# Some statements produce syntax errors on purpose, to cover changes in
# sql_yacc*.yy
#
########################################################################

#
# Pre-create simple tables, to make sure they all exist
#
query_init_add:
  # First 10 tables will remain static, only used for read operations
    { $tnum= 1; '' } app_periods_create_simple_with_period_init
  ; { $tnum++; '' } app_periods_create_simple_with_period_init
  ; { $tnum++; '' } app_periods_create_simple_with_period_init
  ; { $tnum++; '' } app_periods_create_simple_with_period_init
  ; { $tnum++; '' } app_periods_create_simple_with_period_init
  ; { $tnum++; '' } app_periods_create_simple_with_period_init
  ; { $tnum++; '' } app_periods_create_simple_with_period_init
  ; { $tnum++; '' } app_periods_create_simple_with_period_init
  ; { $tnum++; '' } app_periods_create_simple_with_period_init
  ; { $tnum++; '' } app_periods_create_simple_with_period_init
  # Other 5 tables will be dynamic, can be ALTER-ed, re-created etc.
  # But initially we create them in the same simple way
  ; { $tnum++; '' } app_periods_create_simple_with_period_init
  ; { $tnum++; '' } app_periods_create_simple_with_period_init
  ; { $tnum++; '' } app_periods_create_simple_with_period_init
  ; { $tnum++; '' } app_periods_create_simple_with_period_init
  ; { $tnum++; '' } app_periods_create_simple_with_period_init
  ; SET system_versioning_alter_history= KEEP
;

query_add:
    ==FACTOR:20==  app_periods_dml
  |                app_periods_ddl
  |                app_periods_admin_table
  | ==FACTOR:0.1== app_periods_invalid /* EXECUTOR_FLAG_SILENT */ 
;

##############
### CREATE TABLE statements and other DDL
##############

# _init variant does CREATE TABLE IF NOT EXISTS, to avoid re-creating the table multiple times
#
app_periods_create_simple_with_period_init:
  CREATE TABLE IF NOT EXISTS { $last_table= 'app_periods_t'.$tnum } (app_periods_create_definition_for_simple_with_period) ;

# _runtime variant does CREATE OR REPLACE, to avoid non-ops
#
app_periods_create_simple_with_period_runtime:
  CREATE OR REPLACE TABLE app_periods_own_table (app_periods_create_definition_for_simple_with_period);

# More flexible table structures for re-creation at runtime
#
app_periods_create_table:
      app_periods_create_table_clause app_periods_dynamic_table LIKE app_periods_any_table
    | app_periods_create_table_clause app_periods_dynamic_table AS SELECT * FROM app_periods_any_table
    | app_periods_create_table_clause app_periods_dynamic_table { @cols= (); $inds= 1; $period_added= 0; '' } (app_periods_create_definition) _basics_main_engine_clause_50pct _basics_table_options app_periods_partitioning_definition
;

app_periods_create_table_clause:
      CREATE _basics_or_replace_95pct _basics_temporary_5pct TABLE
    | CREATE _basics_temporary_5pct TABLE _basics_if_not_exists_95pct
;

app_periods_create_definition_for_simple_with_period:
  # Only period columns and period
      app_periods_full_period_definition
  # Period columns, period, auto-incremented primary key, optional WITHOUT OVERLAPS  
    | `id` INT AUTO_INCREMENT, `f` VARCHAR(16), app_periods_full_period_definition, PRIMARY KEY(`id` app_periods_without_overlaps_opt)
  # Period columns, period, unique blob, optional primary/unique key on INT column with optional WITHOUT OVERLAPS  
    | `id` INT, `f` _basics_blob_column_type /*!100403 UNIQUE */, app_periods_full_period_definition app_periods_unique_key_for_simple_table_opt
  # Period columns, period, PK on VARCHAR, unique key on INT column with optional WITHOUT OVERLAPS  
    | `id` VARCHAR(32), `f` INT,  app_periods_full_period_definition, PRIMARY KEY(`id`), UNIQUE(`f` app_periods_without_overlaps_opt)
;

#
# Table names
#

app_periods_any_table:
      ==FACTOR:5== app_periods_static_table
    | ==FACTOR:4== app_periods_dynamic_table
    |              _table
;

app_periods_own_table:
    app_periods_static_table | app_periods_dynamic_table ;

app_periods_static_table:
    { $last_table= 'app_periods_t'.$prng->int(1,10) };

app_periods_dynamic_table:
    { $last_table= 'app_periods_t'.$prng->int(11,15) };

#
# PERIOD definitions
#

app_periods_full_period_definition:
    `s` app_periods_period_type, `e` {$periodtype}, PERIOD FOR { $last_period_name= '`p`' }(`s`,`e`) ;

#
# KEY definitions
#

app_periods_without_overlaps_opt:
    | /*!100503 , {$last_period_name} WITHOUT OVERLAPS */ ;

app_periods_unique_key_for_simple_table_opt:
    | , app_periods_unique_key_for_simple_table ;

app_periods_unique_key_for_simple_table:
      PRIMARY KEY (`id` app_periods_without_overlaps_opt)
    | UNIQUE app_periods_new_index_name_optional (`id`)
    | UNIQUE app_periods_new_index_name_optional (`id` app_periods_without_overlaps_opt)
;

##############
### DML
##############

app_periods_dml:
      ==FACTOR:10== app_periods_insert_replace INTO app_periods_own_table app_periods_insert_values _basics_order_by_limit_50pct /*!100500 _basics_returning_5pct */
    |               INSERT _basics_ignore_33pct INTO app_periods_own_table app_periods_insert_values ON DUPLICATE KEY UPDATE _field = _basics_value_for_numeric_column /*!100500 _basics_returning_5pct */
    |               INSERT _basics_ignore_33pct INTO app_periods_own_table app_periods_insert_values ON DUPLICATE KEY UPDATE app_period_valid_period_boundaries_update /*!100500 _basics_returning_5pct */
    | ==FACTOR:10== UPDATE _basics_ignore_80pct app_periods_own_table app_periods_optional_for_portion SET app_periods_update_values app_period_optional_where_clause app_periods_optional_order_by_limit
    | ==FACTOR:5==  UPDATE _basics_ignore_80pct app_periods_own_table SET app_period_valid_period_boundaries_update app_period_optional_where_clause app_periods_optional_order_by_limit
    |               UPDATE _basics_ignore_80pct app_periods_own_table alias1 { $t1= $last_table; '' } NATURAL JOIN app_periods_any_table alias2 { $t2= $last_table; '' } SET { $last_table= $t1; '' } alias1._field = { $last_table= $t2; '' } alias2._field app_period_optional_where_clause app_periods_optional_order_by_limit
    |               UPDATE _basics_ignore_80pct app_periods_any_table alias1  { $t1= $last_table; '' } NATURAL JOIN app_periods_own_table alias2 SET alias2._field = { $last_table= $t1; '' } alias1._field app_period_optional_where_clause
    | ==FACTOR:2==  DELETE _basics_ignore_80pct FROM app_periods_own_table app_periods_optional_for_portion app_period_optional_where_clause app_periods_optional_order_by_limit _basics_returning_5pct
    | ==FACTOR:0.2== DELETE _basics_ignore_80pct alias1.* FROM app_periods_own_table alias1, app_periods_any_table alias2
    | ==FACTOR:0.2== DELETE _basics_ignore_80pct alias2.* FROM app_periods_any_table alias1, app_periods_own_table alias2
    # Error silenced due to expected "No such file or directory" errors if the previous SELECT didn't work
    | ==FACTOR:0.1== SELECT * INTO OUTFILE { $fname= '_data_'.time(); "'$fname'" } FROM app_periods_own_table app_period_optional_where_clause ; LOAD DATA INFILE { "'$fname'" } app_periods_optional_ignore_replace INTO TABLE { $last_table } /* EXECUTOR_FLAG_SILENT */
    |                SELECT * FROM app_periods_own_table app_period_optional_where_clause app_periods_optional_order_by_limit
    |                SELECT * FROM app_periods_any_table WHERE _field IN ( SELECT _field FROM app_periods_own_table app_period_optional_where_clause app_periods_optional_order_by_limit )
    | ==FACTOR:0.2== DELETE HISTORY FROM app_periods_any_table
    | ==FACTOR:0.2== TRUNCATE TABLE app_periods_own_table
;

# DELAYED is not supported for app-period tables
app_periods_invalid:
      INSERT DELAYED _basics_ignore_80pct INTO app_periods_own_table app_periods_insert_values
    | CREATE OR REPLACE TABLE app_periods_t_invalid (a INT, s DATE, e DATE, PERIOD FOR p1(s,e), PERIOD FOR p2(s,e))
    | CREATE OR REPLACE TABLE app_periods_t_invalid (a INT, s DATE, e DATE, PERIOD FOR p1(s,e), PERIOD FOR p2(s,e))
    | CREATE OR REPLACE TABLE app_periods_t_invalid (a INT, s DATE, e DATE, PERIOD FOR p1(s,e), PRIMARY KEY(a, p1 WITHOUT OVERLAPS, p1 WITHOUT OVERLAPS)
;

app_periods_insert_replace:
# INSERT has a priority, because REPLACE is not supported for WITHOUT OVERLAPS
      ==FACTOR:4== INSERT _basics_ignore_80pct
    |              REPLACE
;

# For LOAD DATA
app_periods_optional_ignore_replace:
# IGNORE has a priority, because REPLACE is not supported for WITHOUT OVERLAPS
    | ==FACTOR:4== _basics_ignore_80pct
    |              REPLACE
;

app_periods_optional_order_by_limit:
    | ORDER BY _field _basics_limit_90pct
    | ORDER BY `s`, `e` _basics_limit_90pct
;

app_periods_insert_values:
      ==FACTOR:10==  (`s`,`e`) VALUES app_periods_value_list_0
    | ==FACTOR:15==  (_field,`s`,`e`) VALUES app_periods_value_list_1
    | ==FACTOR:0.5== (_field_list) VALUES { $val_count= $last_field_list_length; '' } _basics_value_set
    | ==FACTOR:0.5== (_field) VALUES (_basics_type_dependent_value)
;

app_periods_update_values:
      ==FACTOR:5== _field_int = _basics_value_for_numeric_column
    | ==FACTOR:2== _field_char = _basics_value_for_char_column
    | _field = _basics_any_value, app_periods_update_values
;

app_periods_optional_for_portion:
    | FOR PORTION OF `p` app_period_valid_portion_boundaries ;

app_periods_value_list_0:
      (app_period_valid_period_boundaries)
    | (app_period_valid_period_boundaries), app_periods_value_list_0
;

app_periods_value_list_1:
      (_basics_any_value,app_period_valid_period_boundaries)
    | (_basics_any_value,app_period_valid_period_boundaries), app_periods_value_list_1
;

app_period_valid_period_boundaries:
    { $ts= $prng->int(0,2147483647); $start= $prng->date($ts); $end= $prng->date($prng->int($ts,2147483647)); "'$start','$end'" };

app_period_valid_period_boundaries_update:
   { $ts= $prng->int(0,2147483647); $start= $prng->date($ts); $end= $prng->date($prng->int($ts,2147483647)); "`s` = '$start', `e` = '$end'" };

app_period_valid_period_boundaries_between:
    { $ts= $prng->int(0,2147483647); $start= $prng->date($ts); $end= $prng->date($prng->int($ts,2147483647)); "BETWEEN '$start' AND '$end'" };

app_period_valid_portion_boundaries:
   { $ts= $prng->int(0,2147483647); $start= $prng->date($ts); $end= $prng->date($prng->int($ts,2147483647)); "FROM '$start' TO '$end'" };

app_period_where_condition:
    `s` app_period_valid_period_boundaries_between
  | `e` app_period_valid_period_boundaries_between
  | _field app_period_valid_period_boundaries_between
  | _field _basics_comparison_operator _date
;

app_period_where_conditions:
    ==FACTOR:2==   app_period_where_condition
  | ==FACTOR:0.2== app_period_where_condition AND app_period_where_condition
  | ==FACTOR:0.5== app_period_where_condition OR app_period_where_condition
;

app_period_optional_where_clause:
  | WHERE app_period_where_conditions ;

#
# Other DDL
#

app_periods_ddl:
                  app_periods_create_simple_with_period_runtime
  | ==FACTOR:2==  app_periods_create_table
  | ==FACTOR:10== app_periods_alter
  |               app_periods_create_drop_index
;

app_periods_create_drop_index:
    CREATE _basics_or_replace_95pct INDEX app_periods_random_index_name ON app_periods_dynamic_table (app_periods_existing_column_list)
  | CREATE _basics_or_replace_95pct UNIQUE INDEX app_periods_random_index_name ON app_periods_dynamic_table (app_periods_existing_column_list app_periods_without_overlaps_opt)
  | CREATE INDEX _basics_if_not_exists_95pct app_periods_random_index_name ON app_periods_dynamic_table (app_periods_existing_column_list)
  | CREATE UNIQUE INDEX _basics_if_not_exists_95pct app_periods_random_index_name ON app_periods_dynamic_table (app_periods_existing_column_list app_periods_without_overlaps_opt)
  | DROP INDEX _basics_if_exists_95pct app_periods_random_index_name ON app_periods_dynamic_table
;

app_periods_admin_table:
    SHOW CREATE TABLE app_periods_own_table
  | DESCRIBE app_periods_own_table
  | SHOW INDEX IN app_periods_own_table
  | ANALYZE TABLE app_periods_own_table
  | CHECK TABLE app_periods_own_table EXTENDED
;

app_periods_create_definition:
    app_periods_column_definition
  | app_periods_create_definition, app_periods_table_element
  | app_periods_table_element, app_periods_create_definition
;

app_periods_column_definition:
  app_periods_new_column_name _basics_column_specification ;

app_periods_table_element:
    ==FACTOR:6== app_periods_column_definition
  | ==FACTOR:3== { $period_added++ ? 'app_periods_column_definition' : 'app_periods_full_period_definition' }
  | ==FACTOR:0.2== { $period_added++ ? 'app_periods_column_definition' : 'app_periods_period_definition_random' }
  |              KEY app_periods_index_definition
  |              app_periods_constraint_definition
;

app_periods_period_definition_random:
  PERIOD FOR app_periods_period_name ( app_periods_existing_column_name, app_periods_existing_column_name ) ;

app_periods_index_definition:
  app_periods_new_index_name_optional (app_periods_existing_column_list) app_periods_index_type_opt;

app_periods_new_column_name:
  { $last_field= 'c'.(scalar(@cols)+1); push @cols, $last_field; '`'.$last_field.'`' } ;

app_periods_existing_column_name:
  { $last_field= scalar(@cols) ? $prng->arrayElement(\@cols) : 'c'.$prng->int(1,$max_cols); '`'.$last_field.'`' } ;

app_periods_existing_column_list:
    ==FACTOR:5== app_periods_existing_column_name
  |              app_periods_existing_column_name, app_periods_existing_column_list ;

app_periods_period_name:
    ==FACTOR:100== app_periods_valid_period_name
  | /* EXECUTOR_FLAG_SILENT */ app_periods_invalid_period_name
;

# TODO: '``' disabled due to MDEV-18873
app_periods_valid_period_name:
    ==FACTOR:100== { $last_period_name= 'p' }
  |                { $last_period_name= 'app' }
  |                { $last_period_name= 'P' }
  |                { $last_period_name= 'period' }
;

# This will cause syntax errors, intentionally
app_periods_invalid_period_name:
  | SYSTEM_TIME | system_time | `system_time` | `SYSTEM_TIME` ;

app_periods_new_index_name_optional:
  | { $last_index_name= 'ind'.$inds++ } ;

app_periods_random_index_name:
  { 'ind'.$prng->int(1,$inds) } ;

app_periods_random_column_name:
  { $last_field= ( $prng->int(0,10) ? ( $prng->int(0,10) ? 'c'.$prng->int(1,$max_cols) : 's' ) : 'e' ); '`'.$last_field.'`' } ;

app_periods_index_type_opt:
    ==FACTOR:3==
  |              USING app_periods_index_type
;

app_periods_index_type:
    ==FACTOR:2== BTREE
  |              HASH
;
    
app_periods_constraint_definition:
    ==FACTOR:4==   app_periods_unique_key
  |                app_periods_primary_key
  | ==FACTOR:0.5== app_periods_foreign_key
  | ==FACTOR:4==   _basics_simple_check_constraint
;

app_periods_unique_key:
    UNIQUE app_periods_new_index_name_optional (app_periods_existing_column_list) app_periods_index_type_opt
  | /* compatibility 10.5.3 */ UNIQUE app_periods_new_index_name_optional (app_periods_existing_column_list, { $last_period_name } WITHOUT OVERLAPS) app_periods_index_type_opt
;

app_periods_primary_key:
    PRIMARY KEY (app_periods_existing_column_list) app_periods_index_type_opt
  | /* compatibility 10.5.3 */ PRIMARY KEY (app_periods_existing_column_list, { $last_period_name } WITHOUT OVERLAPS) app_periods_index_type_opt
;

app_periods_foreign_key:
  CONSTRAINT app_periods_new_index_name_optional FOREIGN KEY (_field) REFERENCES app_periods_any_table (_field) ;

app_periods_alter:
    ==FACTOR:19== ALTER TABLE app_periods_dynamic_table app_periods_alter_table_list
  |               ALTER TABLE app_periods_dynamic_table app_periods_partitioning_definition
  | ==FACTOR:0.01== _basics_reload_metadata
;

app_periods_alter_table_list:
    ==FACTOR:4== app_periods_alter_table_element
  | app_periods_alter_table_element, app_periods_alter_table_list
;

app_periods_alter_table_element:
# Main functionality
    ==FACTOR:4==  app_periods_add_drop_period
  |               app_periods_add_drop_column
  |               app_periods_add_drop_index
# Extra statements for coverage
  |               app_periods_system_versioning
  |               app_periods_change_modify_column
  |               _basics_alter_table_element
;

app_periods_add_drop_index:
    ==FACTOR:3==   ADD INDEX _basics_if_not_exists_95pct app_periods_index_definition
  | ==FACTOR:3==   ADD app_periods_constraint_definition
  |                DROP _basics_if_exists_95pct app_periods_random_index_name
  | ==FACTOR:0.2== DROP PRIMARY KEY
;

app_periods_add_drop_column:
    ==FACTOR:3== ADD _basics_if_not_exists_95pct app_periods_column_definition
  |              DROP _basics_if_exists_95pct _field
;

app_periods_change_modify_column:
  MODIFY _basics_if_exists_95pct _field  _basics_column_specification |
  CHANGE _basics_if_exists_95pct _field app_periods_random_column_name _basics_column_specification
;

app_periods_system_versioning:
  ADD COLUMN `row_start` TIMESTAMP(6) AS ROW START, ADD COLUMN `row_end` TIMESTAMP(6) AS ROW END, ADD PERIOD FOR SYSTEM_TIME(`row_start`,`row_end`), WITH SYSTEM VERSIONING |
  ADD COLUMN `row_start` BIGINT UNSIGNED AS ROW START, ADD COLUMN `row_end` BIGINT UNSIGNED AS ROW END, ADD PERIOD FOR SYSTEM_TIME(`row_start`,`row_end`), WITH SYSTEM VERSIONING |
  WITH SYSTEM VERSIONING |
  DROP IF EXISTS `row_start`, DROP IF EXISTS `row_end`, DROP PERIOD FOR SYSTEM_TIME, DROP SYSTEM VERSIONING |
  DROP SYSTEM VERSIONING
;

app_periods_add_drop_period:
    ==FACTOR:4== ADD PERIOD _basics_if_not_exists_95pct FOR app_periods_period_name ( app_periods_existing_column_name, app_periods_existing_column_name )
  |              DROP PERIOD _basics_if_exists_95pct FOR app_periods_dynamic_table
;

app_periods_update_list:
  app_periods_existing_column_name = app_periods_time_value |
  app_periods_existing_column_name = app_periods_time_value |
  app_periods_existing_column_name = app_periods_time_value |
  _field = app_periods_time_value |
  app_periods_update_list , app_periods_existing_column_name = app_periods_time_value
;

app_periods_period_type:
  { $periodtype= $prng->arrayElement(['TIMESTAMP','TIMESTAMP('.$prng->int(0,6).')','DATETIME','DATETIME('.$prng->int(0,6).')','DATE']) }
;

app_periods_period_boundary_literal:
  _timestamp | _date ;

app_periods_time_value:
  _timestamp | _date |
  CURRENT_TIMESTAMP + _tinyint |
  CURDATE | CURDATE | CURDATE | CURDATE | CURDATE | CURDATE | 
  NOW() | NOW(6) | NOW() | NOW(6) | NOW() | NOW(6) | NOW() | NOW(6) |
  DATE_ADD(_timestamp, INTERVAL _positive_digit _basics_interval) |
  DATE_ADD(_timestamp, INTERVAL _positive_digit _basics_interval) |
  DATE_ADD(_timestamp, INTERVAL _positive_digit _basics_interval) |
  DATE_SUB(_timestamp, INTERVAL _positive_digit _basics_interval) |
  DATE_SUB(_timestamp, INTERVAL _positive_digit _basics_interval) |
  DATE_SUB(_timestamp, INTERVAL _positive_digit _basics_interval) |
  DATE_SUB(_timestamp, INTERVAL _positive_digit _basics_interval) |
  DATE_SUB(NOW(), INTERVAL _positive_digit _basics_interval) |
  { $tm = time - $prng->int(-100,100); '' } app_periods_period_boundary_literal |
  @tm | @tm1 | @tm2 | @tm | @tm1 | @tm2 | @tm | @tm1 | @tm2 |
  # Invalid for UPDATE FOR PORTION
  SYSDATE() |
  app_periods_existing_column_name
;

app_periods_partitioning_definition_opt:
    ==FACTOR:9==
  |               app_periods_partitioning_definition
;

app_periods_partitioning_definition:
    ==FACTOR:9== PARTITION BY _basics_hash_or_key(app_periods_existing_column_name) PARTITIONS _positive_digit
  |              PARTITION BY SYSTEM_TIME app_periods_partitioning_by_system_time
;

app_periods_partitioning_by_system_time:
      app_periods_partition_condition_opt (app_periods_system_partition_list)
    | /* compatibility 10.5.0 */ app_periods_partition_condition_opt
    | /* compatibility 10.5.0 */ app_periods_partition_condition_opt PARTITIONS app_periods_partition_count
;

# TODO: Replace with _tinyint_unsigned or alike and remove after MDEV-22178 has been fixed
app_periods_partition_count:
    { $prng->int(2,64) } ;

app_periods_partition_condition_opt:
    | INTERVAL _smallint_unsigned _basics_interval | LIMIT _smallint_unsigned ;

app_periods_system_partition_list:
    PARTITION { 'p'.($part=1) } HISTORY, app_periods_system_extra_history_partitions_opt PARTITION pn CURRENT;

app_periods_system_extra_history_partitions_opt:
    { $parts=''; $part_count= $prng->int(0,12); foreach(1..$part_count) { $parts.= 'PARTITION p'.$_.' HISTORY, ' }; $parts };


