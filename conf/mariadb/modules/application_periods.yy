#  Copyright (c) 2019, 2022, MariaDB
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

#include <conf/basics.yy>

#
# Pre-create simple tables, to make sure they all exist
#
query_init:
    CREATE DATABASE IF NOT EXISTS { $last_database = 'app_periods' }
  ;; USE app_periods
  ;; { $tnum= 1; '' } create_simple_with_period_init
  ;; { $tnum++; '' } create_simple_with_period_init
  ;; { $tnum++; '' } create_simple_with_period_init
  ;; { $tnum++; '' } create_simple_with_period_init
  ;; { $tnum++; '' } create_simple_with_period_init
  ;; { $tnum++; '' } create_simple_with_period_init
  ;; { $tnum++; '' } create_simple_with_period_init
  ;; { $tnum++; '' } create_simple_with_period_init
  ;; { $tnum++; '' } create_simple_with_period_init
  ;; { $tnum++; '' } create_simple_with_period_init
  ;; { $tnum++; '' } create_simple_with_period_init
  ;; { $tnum++; '' } create_simple_with_period_init
  ;; { $tnum++; '' } create_simple_with_period_init
  ;; { $tnum++; '' } create_simple_with_period_init
  ;; { $tnum++; '' } create_simple_with_period_init
  ;; SET system_versioning_alter_history= KEEP { $last_database= ''; $executors->[0]->forceMetadataReload(); $executors->[0]->setMetadataReloadInterval(10 + $generator->threadId()); '' }
;

query:
     USE { $col_number= 0; $inds= 1; $period_added= 0; ''; $last_database= 'app_periods' } 
  ;; app_periods_query { $last_database = '' }
;

app_periods_query:
    ==FACTOR:20==  dml
  |                ddl
  |                admin_table
  | ==FACTOR:0.1== invalid /* EXECUTOR_FLAG_SILENT */ 
;

##############
### CREATE TABLE statements and other DDL
##############

# _init variant does CREATE TABLE IF NOT EXISTS, to avoid re-creating the table multiple times
#
create_simple_with_period_init:
  CREATE TABLE IF NOT EXISTS { $last_table= 'app_periods.t'.$tnum } (create_definition_for_simple_with_period) ;

# _runtime variant does CREATE OR REPLACE, to avoid non-ops
#
create_simple_with_period_runtime:
  CREATE OR REPLACE TABLE own_table (create_definition_for_simple_with_period);

# More flexible table structures for re-creation at runtime
#
create_table:
    create_table_clause own_table LIKE any_table
  | create_table_clause own_table AS SELECT * FROM any_table
  | create_table_clause own_table (create_definition) optional_main_engine _basics_table_options partitioning_definition
;

optional_main_engine:
  ==FACTOR:8== |
  ==FACTOR:4== InnoDB |
  ==FACTOR:2== MyISAM |
  ==FACTOR:2== Aria
;

create_table_clause:
    CREATE __or_replace(95) __temporary(5) TABLE
  | CREATE __temporary(5) TABLE __if_not_exists(95)
;

create_definition_for_simple_with_period:
  # Only period columns and period
    full_period_definition
  # Period columns, period, auto-incremented primary key, optional WITHOUT OVERLAPS  
  | `id` INT AUTO_INCREMENT, `f` VARCHAR(16), full_period_definition, PRIMARY KEY(`id` __asc_x_desc(33,33) without_overlaps_opt)
  # Period columns, period, unique blob, optional primary/unique key on INT column with optional WITHOUT OVERLAPS  
  | `id` INT, `f` _basics_blob_column_type /*!100403 UNIQUE */, full_period_definition unique_key_for_simple_table_opt
  # Period columns, period, PK on VARCHAR, unique key on INT column with optional WITHOUT OVERLAPS  
  | `id` VARCHAR(32), `f` INT,  full_period_definition, PRIMARY KEY(`id` __asc_x_desc(33,33)), UNIQUE(`f` __asc_x_desc(33,33) without_overlaps_opt)
;

#
# Table names
#

any_table:
  { $last_database= '' } _table { $last_database = 'app_periods'; '' }
;

own_table:
  { $last_table= 'app_periods.t'.$prng->uint16(1,15) };

#
# PERIOD definitions
#

full_period_definition:
  `s` period_type, `e` {$periodtype}, PERIOD FOR { $last_period_name= '`p`' }(`s`,`e`) ;

#
# KEY definitions
#

without_overlaps_opt:
  | /*!100503 , {$last_period_name} WITHOUT OVERLAPS */ ;

unique_key_for_simple_table_opt:
  | , unique_key_for_simple_table ;

unique_key_for_simple_table:
    PRIMARY KEY (`id` __asc_x_desc(33,33) without_overlaps_opt)
  | UNIQUE new_index_name_optional (`id` __asc_x_desc(33,33))
  | UNIQUE new_index_name_optional (`id` __asc_x_desc(33,33) without_overlaps_opt)
;

##############
### DML
##############

dml:
    ==FACTOR:10== insert_replace INTO _table insert_values _basics_order_by_limit_50pct /*!100500 _basics_returning_5pct */
  |               INSERT __ignore(30) INTO _table insert_values ON DUPLICATE KEY UPDATE _field = _basics_value_for_numeric_column /*!100500 _basics_returning_5pct */
  |               INSERT __ignore(30) INTO _table insert_values ON DUPLICATE KEY UPDATE app_period_valid_period_boundaries_update /*!100500 _basics_returning_5pct */
  | ==FACTOR:10== UPDATE __ignore(80) _table optional_for_portion SET update_values app_period_optional_where_clause optional_order_by_limit
  | ==FACTOR:5==  UPDATE __ignore(80) _table SET app_period_valid_period_boundaries_update app_period_optional_where_clause optional_order_by_limit
  |               UPDATE __ignore(80) _table alias1 { $t1= $last_table; '' } NATURAL JOIN any_table alias2 { $t2= $last_table; '' } SET { $last_table= $t1; '' } alias1._field = { $last_table= $t2; '' } alias2._field app_period_optional_where_clause optional_order_by_limit
  |               UPDATE __ignore(80) any_table alias1  { $t1= $last_table; '' } NATURAL JOIN _table alias2 SET alias2._field = { $last_table= $t1; '' } alias1._field app_period_optional_where_clause
  | ==FACTOR:2==  DELETE __ignore(80) FROM _table optional_for_portion app_period_optional_where_clause optional_order_by_limit _basics_returning_5pct
  | ==FACTOR:0.2== DELETE __ignore(80) alias1.* FROM _table alias1, any_table alias2
  | ==FACTOR:0.2== DELETE __ignore(80) alias2.* FROM any_table alias1, _table alias2
  # Error silenced due to expected "No such file or directory" errors if the previous SELECT didn't work
  | ==FACTOR:0.1== SELECT * INTO OUTFILE { $fname= '_data_'.time(); "'$fname'" } FROM _table app_period_optional_where_clause ; LOAD DATA INFILE { "'$fname'" } optional_ignore_replace INTO TABLE { $last_table } /* EXECUTOR_FLAG_SILENT */
  |                SELECT * FROM _table app_period_optional_where_clause optional_order_by_limit
  |                SELECT * FROM any_table WHERE _field IN ( SELECT _field FROM _table app_period_optional_where_clause optional_order_by_limit )
  | ==FACTOR:0.2== DELETE HISTORY FROM any_table
  | ==FACTOR:0.2== TRUNCATE TABLE _table
;

# DELAYED is not supported for app-period tables
invalid:
    INSERT DELAYED __ignore(80) INTO _table insert_values
  | CREATE OR REPLACE TABLE t_invalid (a INT, s DATE, e DATE, PERIOD FOR p1(s,e), PERIOD FOR p2(s,e))
  | CREATE OR REPLACE TABLE t_invalid (a INT, s DATE, e DATE, PERIOD FOR p1(s,e), PERIOD FOR p2(s,e))
  | CREATE OR REPLACE TABLE t_invalid (a INT, s DATE, e DATE, PERIOD FOR p1(s,e), PRIMARY KEY(a __asc_x_desc(33,33), p1 WITHOUT OVERLAPS, p1 WITHOUT OVERLAPS)
;

insert_replace:
# INSERT has a priority, because REPLACE is not supported for WITHOUT OVERLAPS
    ==FACTOR:4== INSERT __ignore(80)
  |              REPLACE
;

# For LOAD DATA
optional_ignore_replace:
# IGNORE has a priority, because REPLACE is not supported for WITHOUT OVERLAPS
  |
  | ==FACTOR:4== IGNORE
  |              REPLACE
;

optional_order_by_limit:
  | ORDER BY _field _basics_limit_90pct
  | ORDER BY `s`, `e` _basics_limit_90pct
;

insert_values:
    ==FACTOR:10==  (`s`,`e`) VALUES value_list_0
  | ==FACTOR:15==  (_field,`s`,`e`) VALUES value_list_1
  | ==FACTOR:0.5== (_field_list) VALUES { $val_count= $last_field_list_length; '' } _basics_value_set
  | ==FACTOR:0.5== (_field) VALUES (_basics_type_dependent_value)
;

update_values:
    ==FACTOR:5== _field_int = _basics_value_for_numeric_column
  | ==FACTOR:2== _field_char = _basics_value_for_char_column
  | _field = _basics_any_value, update_values
;

optional_for_portion:
  | FOR PORTION OF `p` app_period_valid_portion_boundaries ;

value_list_0:
    (app_period_valid_period_boundaries)
  | (app_period_valid_period_boundaries), value_list_0
;

value_list_1:
    (_basics_any_value,app_period_valid_period_boundaries)
  | (_basics_any_value,app_period_valid_period_boundaries), value_list_1
;

app_period_valid_period_boundaries:
  { $ts= $prng->uint16(0,2147483647); $start= $prng->date($ts); $end= $prng->date($prng->uint16($ts,2147483647)); "$start,$end" };

app_period_valid_period_boundaries_update:
  { $ts= $prng->uint16(0,2147483647); $start= $prng->date($ts); $end= $prng->date($prng->uint16($ts,2147483647)); "`s` = $start, `e` = $end" };

app_period_valid_period_boundaries_between:
  { $ts= $prng->uint16(0,2147483647); $start= $prng->date($ts); $end= $prng->date($prng->uint16($ts,2147483647)); "BETWEEN $start AND $end" };

app_period_valid_portion_boundaries:
  { $ts= $prng->uint16(0,2147483647); $start= $prng->date($ts); $end= $prng->date($prng->uint16($ts,2147483647)); "FROM $start TO $end" };

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

ddl:
                  create_simple_with_period_runtime
  | ==FACTOR:2==  create_table
  | ==FACTOR:10== alter
  |               create_drop_index
;

create_drop_index:
    CREATE __or_replace(95) INDEX random_index_name ON _table (existing_column_list)
  | CREATE __or_replace(95) UNIQUE INDEX random_index_name ON _table (existing_column_list without_overlaps_opt)
  | CREATE INDEX __if_not_exists(95) random_index_name ON _table (existing_column_list)
  | CREATE UNIQUE INDEX __if_not_exists(95) random_index_name ON _table (existing_column_list without_overlaps_opt)
  | DROP INDEX __if_exists(95) random_index_name ON _table
;

admin_table:
    SHOW CREATE TABLE _table
  | DESCRIBE _table
  | SHOW INDEX IN _table
  | ANALYZE TABLE _table
  | CHECK TABLE _table EXTENDED
;

create_definition:
    column_definition
  | create_definition, table_element
  | table_element, create_definition
;

column_definition:
  new_column_name _basics_column_specification ;

table_element:
    ==FACTOR:6== column_definition
  | ==FACTOR:3== { $period_added++ ? 'column_definition' : 'full_period_definition' }
  | ==FACTOR:0.2== { $period_added++ ? 'column_definition' : 'period_definition_random' }
  |              KEY index_definition
  |              constraint_definition
;

period_definition_random:
  PERIOD FOR period_name ( _field, _field ) ;

index_definition:
  new_index_name_optional (existing_column_list) index_type_opt;

new_column_name:
  { $last_field= 'c'.(++$col_number); '`'.$last_field.'`' } ;

existing_column_list:
    ==FACTOR:5== _field __asc_x_desc(33,33)
  |              _field __asc_x_desc(33,33), existing_column_list ;

period_name:
    ==FACTOR:100== valid_period_name
  | /* EXECUTOR_FLAG_SILENT */ invalid_period_name
;

# TODO: '``' disabled due to MDEV-18873
valid_period_name:
    ==FACTOR:100== { $last_period_name= 'p' }
  |                { $last_period_name= 'app' }
  |                { $last_period_name= 'P' }
  |                { $last_period_name= 'period' }
;

# This will cause syntax errors, intentionally
invalid_period_name:
  | SYSTEM_TIME | system_time | `system_time` | `SYSTEM_TIME` ;

new_index_name_optional:
  | { $last_index_name= 'ind'.$inds++ } ;

random_index_name:
  { 'ind'.$prng->uint16(1,$inds) } ;

index_type_opt:
    ==FACTOR:3==
  |              USING index_type
;

index_type:
    ==FACTOR:3== BTREE
# Disabled due to MDEV-371 issues
#  |              HASH
;
    
constraint_definition:
    ==FACTOR:4==   unique_key
  |                primary_key
  | ==FACTOR:0.5== foreign_key
  | ==FACTOR:4==   _basics_simple_check_constraint
;

unique_key:
    UNIQUE new_index_name_optional (existing_column_list) index_type_opt
  | /* compatibility 10.5.3 */ UNIQUE new_index_name_optional (existing_column_list, { $last_period_name } WITHOUT OVERLAPS) index_type_opt
;

primary_key:
    PRIMARY KEY (existing_column_list) index_type_opt
  | /* compatibility 10.5.3 */ PRIMARY KEY (existing_column_list, { $last_period_name } WITHOUT OVERLAPS) index_type_opt
;

foreign_key:
  CONSTRAINT new_index_name_optional FOREIGN KEY (_field) REFERENCES any_table (_field) ;

alter:
    ==FACTOR:19== ALTER TABLE _table alter_table_list
  |               ALTER TABLE _table partitioning_definition
;

alter_table_list:
    ==FACTOR:4== alter_table_element
  | alter_table_element, alter_table_list
;

alter_table_element:
# Main functionality
    ==FACTOR:4==  add_drop_period
  |               add_drop_column
  |               add_drop_index
z;

add_drop_index:
    ==FACTOR:3==   ADD INDEX __if_not_exists(95) index_definition
  | ==FACTOR:3==   ADD constraint_definition
  |                DROP __if_exists(95) random_index_name
  | ==FACTOR:0.2== DROP PRIMARY KEY
;

add_drop_column:
    ==FACTOR:3== ADD __if_not_exists(95) column_definition
  |              DROP __if_exists(95) _field
;

add_drop_period:
    ==FACTOR:4== ADD PERIOD __if_not_exists(95) FOR period_name ( _field, _field )
  |              DROP PERIOD __if_exists(95) FOR period_name
;

update_list:
  _field = time_value |
  _field = time_value |
  _field = time_value |
  _field = time_value |
  update_list , _field = time_value
;

period_type:
  { $periodtype= $prng->arrayElement(['TIMESTAMP','TIMESTAMP('.$prng->uint16(0,6).')','DATETIME','DATETIME('.$prng->uint16(0,6).')','DATE']) }
;

period_boundary_literal:
  _timestamp | _date ;

time_value:
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
  { $tm = time - $prng->uint16(-100,100); '' } period_boundary_literal |
  @tm | @tm1 | @tm2 | @tm | @tm1 | @tm2 | @tm | @tm1 | @tm2 |
  # Invalid for UPDATE FOR PORTION
  SYSDATE() |
  _field
;

partitioning_definition:
    ==FACTOR:9== PARTITION BY __hash_x_key (_field) PARTITIONS _positive_digit
  |              PARTITION BY SYSTEM_TIME partitioning_by_system_time
;

partitioning_by_system_time:
    partition_condition_opt (system_partition_list)
  | /* compatibility 10.5.0 */ partition_condition_opt
  | /* compatibility 10.5.0 */ partition_condition_opt PARTITIONS _tinyint_unsigned
;

partition_condition_opt:
  | INTERVAL _smallint_unsigned _basics_interval | LIMIT _smallint_unsigned ;

system_partition_list:
  PARTITION { 'p'.($part=1) } HISTORY, system_extra_history_partitions_opt PARTITION pn CURRENT;

system_extra_history_partitions_opt:
  { $parts=''; $part_count= $prng->uint16(0,12); foreach(1..$part_count) { $parts.= 'PARTITION p'.$_.' HISTORY, ' }; $parts };


