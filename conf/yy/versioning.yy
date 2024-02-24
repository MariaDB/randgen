#  Copyright (c) 2017, 2022, MariaDB
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

####################################################
# System versioning
####################################################

#include <conf/yy/include/basics.inc>
#features system-versioned tables, Aria tables


# DDL-rich grammar requires frequent metadata reload
query_init:
  { $vers_tab_num=0; '' }
    CREATE DATABASE IF NOT EXISTS versioning_db
  ;; SET ROLE admin
  # PS is a workaround for MDEV-30190
  ;; EXECUTE IMMEDIATE CONCAT('GRANT ALL ON versioning_db.* TO ',CURRENT_USER,' WITH GRANT OPTION')
  ;; SET ROLE NONE
  ;; { _set_db('versioning_db') }
     SET SYSTEM_VERSIONING_ALTER_HISTORY= vers_alter_history_value, ENFORCE_STORAGE_ENGINE=NULL
  ;; vers_create_init ;; vers_create_init ;; vers_create_init ;; vers_create_init ;; vers_create_init
  ;; vers_create_init ;; vers_create_init ;; vers_create_init ;; vers_create_init ;; vers_create_init
  ;; vers_create_init ;; vers_create_init ;; vers_create_init ;; vers_create_init ;; vers_create_init
  ;; vers_create_init ;; vers_create_init ;; vers_create_init ;; vers_create_init ;; vers_create_init
  ;; vers_create_table_with_visible_columns
  ;; vers_create_simple_table
  ;; CREATE OR REPLACE VIEW vers_view_1 AS SELECT * FROM `vers_table_visible_columns`
  ;; CREATE OR REPLACE VIEW vers_view_2 AS SELECT * FROM `vers_simple_table`
  ;; SET ENFORCE_STORAGE_ENGINE=DEFAULT
;

query:
  { $new_col_next_num= 0; _set_db('versioning_db') } vers_fix_timestamp ;; vers_query ;; SET timestamp= 0 ;

vers_create_init:
    { $new_col_next_num= 1; '' } CREATE TABLE IF NOT EXISTS vers_new_table_name (vers_col_list) vers_engine vers_table_flags vers_partitioning_optional
  | { $new_col_next_num= 1; '' } CREATE TABLE IF NOT EXISTS vers_new_table_name (vers_col_list_with_period , PERIOD FOR SYSTEM_TIME ( { $period_start } , { $period_end } )) vers_engine vers_table_flags vers_partitioning_optional
;

vers_create_view:
  CREATE OR REPLACE VIEW vers_view_name AS SELECT * FROM _versionedtable WHERE _field _basics_comparison_operator _basics_any_value ;

vers_create_simple_table:
  CREATE OR REPLACE TABLE `vers_simple_table` (a INT) WITH SYSTEM VERSIONING;

vers_create_table_with_visible_columns:
  CREATE OR REPLACE TABLE `vers_table_visible_columns` (`a` INT, `row_start` TIMESTAMP(6) AS ROW START, `row_end` TIMESTAMP(6) AS ROW END, PERIOD FOR SYSTEM_TIME(`row_start`,`row_end`)) WITH SYSTEM VERSIONING
;

vers_fix_timestamp:
  ==FACTOR:100== |
  SET timestamp= @@timestamp |
  SET timestamp= @@timestamp { '+'.$prng->uint16(-10000000,10000000) } |
  SET timestamp= UNIX_TIMESTAMP(_datetime)
;

vers_query:
    ==FACTOR:5==    { $new_col_next_num= 1; '' } vers_create
  | ==FACTOR:0.5==  vers_insert_history /* compatibility 10.11.0 */
  | ==FACTOR:0.5==  vers_delete_history
  | ==FACTOR:0.05== vers_change_variable
  | ==FACTOR:5==    vers_optional_switch_db vers_alter
  | ==FACTOR:2==    vers_alter_partitioning
  | ==FACTOR:15==   vers_select
  | ==FACTOR:0.5==  vers_tx_history
  | ==FACTOR:0.1==  vers_create_view
;

vers_optional_switch_db:
  ==FACTOR:100== |
  { _set_db('NON-SYSTEM') }
;

vers_engine:
  ==FACTOR:5== |
  ==FACTOR:3==   ENGINE=InnoDB |
                 ENGINE=MyISAM |
                 ENGINE=Aria |
  ==FACTOR:0.1== ENGINE=MEMORY
;

vers_with_without_system_versioning:
  | | | | | | WITH SYSTEM VERSIONING | WITHOUT SYSTEM VERSIONING
;

vers_change_variable:
    SET __session_x_global(30,10) `SYSTEM_VERSIONING_ALTER_HISTORY`= vers_alter_history_value
  | SET __session_x_global(30,10) `system_versioning_asof` = vers_as_of_value
  | SET SYSTEM_VERSIONING_INSERT_HISTORY= __on_x_off(80) /* compatibility 10.11.0 */
;

vers_as_of_value:
  ==FACTOR:5== DEFAULT |
  NOW(6) |
  NOW() |
  CURRENT_TIMESTAMP |
  DATE(NOW()) |
  _timestamp |
  _datetime |
  _date
;

vers_alter_history_value:
  ==FACTOR:20== KEEP |
  ERROR |
  DEFAULT
;

vers_alter:
    ==FACTOR:0.1== vers_set_statement_alter_history ALTER TABLE vers_existing_table vers_partitioning
  |                vers_set_statement_alter_history ALTER TABLE vers_existing_table vers_alter_list vers_lock vers_algorithm
;

vers_set_statement_alter_history:
  ==FACTOR:20== |
  SET STATEMENT SYSTEM_VERSIONING_ALTER_HISTORY= vers_alter_history_value FOR
;

vers_set_statement_insert_history:
  ==FACTOR:20== |
  SET STATEMENT SYSTEM_VERSIONING_INSERT_HISTORY= __on_x_off FOR
;

vers_alter_list:
  vers_alter_item | vers_alter_item, vers_alter_list
;

vers_alter_item:
    ==FACTOR:0.5==  DROP SYSTEM VERSIONING
  |                 ADD SYSTEM VERSIONING
  |                 ADD PERIOD FOR SYSTEM_TIME(vers_col_start, vers_col_end)
  | ==FACTOR:0.5==  vers_add_drop_sys_column
;

vers_add_drop_sys_column:
    ADD COLUMN __if_not_exists(80) vers_explicit_row_start
  | ADD COLUMN __if_not_exists(80) vers_explicit_row_end
  | DROP COLUMN __if_exists(80) vers_col_start
  | DROP COLUMN __if_exists(80) vers_col_end
  | CHANGE COLUMN __if_exists(80) vers_col_start vers_explicit_row_start
  | CHANGE COLUMN __if_exists(80) vers_col_end vers_explicit_row_end
;

vers_select:
    SELECT * from vers_existing_table FOR system_time vers_system_time_select
  | SELECT * from vers_existing_table WHERE vers_col vers_comparison_operator @trx_user_var
  | SELECT * from vers_existing_table WHERE vers_col IN (SELECT vers_col FROM vers_existing_table)
  | SELECT vers_col FROM vers_existing_table ORDER BY RAND(_int_unsigned) LIMIT 1 INTO @trx_user_var
;

vers_comparison_operator:
  > | < | = | <= | >= | !=
;

vers_delete_history:
  DELETE HISTORY FROM vers_existing_table BEFORE SYSTEM_TIME vers_system_time
;

vers_tx_history:
  SELECT * FROM mysql.transaction_registry
;

vers_system_time_select:
    ALL | ALL | ALL
  | AS OF vers_timestamp_trx vers_system_time
  | BETWEEN vers_timestamp_trx vers_system_time AND vers_timestamp_trx vers_system_time
  | FROM vers_timestamp_trx vers_system_time TO vers_timestamp_trx vers_system_time
;

vers_timestamp_trx:
  | | | | TIMESTAMP | TIMESTAMP | TRANSACTION
;

vers_system_time:
    _timestamp
  | CURRENT_TIMESTAMP
  | NOW() | NOW(6)
  | _tinyint_unsigned
  | @trx_user_var | @trx_user_var | @trx_user_var | @trx_user_var
  | DATE_ADD(_timestamp, INTERVAL _positive_digit vers_interval)
  | DATE_SUB(_timestamp, INTERVAL _positive_digit vers_interval)
  | DATE_SUB(NOW(), INTERVAL _positive_digit vers_interval)
;

vers_col:
  vers_col_start | vers_col_end
;

vers_col_start:
  { $period_start = '`vers_start`' } |
  ==FACTOR:100== { $period_start = '`row_start`' }
;

vers_col_end:
  { $period_end = '`vers_end`' } |
  ==FACTOR:100== { $period_end = '`row_end`' }
;

vers_partitioning:
    vers_partitioning_definition
  | vers_partitioning_definition
  | REMOVE PARTITIONING
  | DROP PARTITION __if_exists(80) { 'ver_p'.$prng->int(1,5) }
  | ADD PARTITION __if_not_exists(80) (PARTITION { 'ver_p'.++$parts } HISTORY)
;

vers_partitioning_optional:
  ==FACTOR:10== |
  vers_partitioning_definition
;

vers_partitioning_definition:
  { $parts=0 ; '' }
  PARTITION BY system_time vers_partitioning_interval_or_limit vers_subpartitioning_optional (
    vers_partition_list ,
    PARTITION ver_pn CURRENT
  )
  # MDEV-19903
  | /* compatibility 10.5.0 */ PARTITION BY SYSTEM_TIME vers_partitioning_interval_or_limit vers_partition_number_optional
;

vers_partition_number_optional:
  | ==FACTOR:2== PARTITIONS { $prng->int(1,20) }
  | /*!100901 AUTO */
;

vers_partitioning_interval_or_limit:
    ==FACTOR:3== INTERVAL _positive_digit vers_interval vers_starts_optional
  | LIMIT _smallint_positive
  | LIMIT _positive_digit
  | LIMIT { $prng->int(990,10000) }
;

vers_starts_optional:
  |
#  STARTS _datetime |
  STARTS { ($sec,$min,$hour,$mday,$mon,$year,undef,undef,undef)= localtime(); "'".sprintf('%04d-%02d-%02d %02d:%02d:%02d',$year+1900,$mon+1,$mday,$hour,$min)."'" }
;

vers_subpartitioning_optional:
  | | | | SUBPARTITION BY __key_x_hash(vers_col_name) SUBPARTITIONS _positive_digit
;

vers_partition_list:
    PARTITION { 'ver_p'.++$parts } HISTORY
  | PARTITION { 'ver_p'.++$parts } HISTORY,
    vers_partition_list
;

vers_interval:
  ==FACTOR:2== SECOND |
  ==FACTOR:4== MINUTE |
  HOUR | DAY | WEEK | MONTH | YEAR
;

####################################################

vers_alter_partitioning:
    ALTER TABLE vers_existing_table PARTITION BY HASH(_field)
  | ALTER TABLE vers_existing_table PARTITION BY KEY(_field)
  | ALTER TABLE vers_existing_table REMOVE PARTITIONING
;

vers_new_table_name:
    { $my_last_table = 't_vers_'.abs($$).'_'.(++$vers_tab_num) }
;

vers_existing_table:
  ==FACTOR:30== _versionedtable
  | _table
  | vers_view_name
  | { $my_last_table = '`vers_simple_table`' }
  | { $my_last_table = '`vers_table_visible_columns`' }
;

vers_view_name:
  { $my_last_table = '`vers_view_'.$prng->uint16(1,2).'`' } ;

vers_existing_or_new_table_name:
  ==FACTOR:10== vers_existing_table |
  vers_new_table_name
;

vers_col_name:
  { $new_col_next_num > 0 ? 'vers_col_new_name' : '_field' } ;

vers_col_new_name:
  { 'col'.($new_col_next_num++) } ;

vers_virt_col_new_name:
  { 'vcol'.($new_col_next_num++) } ;

# TODO: vcols - adjust pribabilities when virtual columns start working
vers_col_name_and_definition:
   ==FACTOR:99== vers_col_name vers_col_definition
  | vers_virt_col_new_name vers_virt_col_definition
;

vers_col_definition:
                   BIT vers_null vers_optional_default_int_or_auto_increment
  | ==FACTOR:10==  vers_int_type __unsigned(20) __zerofill(5) vers_null vers_optional_default_int_or_auto_increment
  |                vers_num_type __unsigned(20) __zerofill(5) vers_null vers_optional_default
  |                vers_temporal_type vers_null vers_optional_default
  |                vers_timestamp_type vers_null vers_optional_default_or_current_timestamp
  | ==FACTOR:5==   vers_text_type vers_null vers_optional_default_char
  |                vers_enum_type vers_null vers_optional_default
  | ==FACTOR:0.1== vers_geo_type vers_null vers_optional_geo_default
;

vers_virt_col_definition:
    vers_int_type AS ( vers_col_name + _digit )
  | vers_num_type AS ( vers_col_name + _digit )
  | vers_temporal_type AS ( vers_col_name )
  | vers_timestamp_type AS ( vers_col_name )
  | vers_text_type AS ( SUBSTR(vers_col_name, _digit, _digit ) )
  | vers_enum_type AS ( vers_col_name )
  | vers_geo_type AS ( vers_col_name )
;

vers_optional_default_or_current_timestamp:
  | DEFAULT vers_default_or_current_timestamp_val
;

vers_default_or_current_timestamp_val:
    '1970-01-01'
  | CURRENT_TIMESTAMP
  | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  | 0
;


vers_optional_default_int_or_auto_increment:
  | vers_optional_default_int
  | vers_optional_default_int
  | vers_optional_default_int
  | vers_optional_auto_increment
;

vers_create:
    CREATE vers_replace_or_if_not_exists vers_existing_or_new_table_name (vers_col_list) vers_engine vers_table_flags vers_partitioning_optional
  | CREATE vers_replace_or_if_not_exists vers_existing_or_new_table_name (vers_col_list_with_period , PERIOD FOR SYSTEM_TIME ( { $period_start }, { $period_end } )) vers_engine vers_table_flags vers_partitioning_optional
  | CREATE vers_replace_or_if_not_exists vers_existing_or_new_table_name LIKE vers_existing_table
;

# MDEV-14670 (permanent) - cannot use virtual columns with/without system versioning
vers_col_list:
    vers_col_name vers_col_definition vers_with_without_system_versioning
  | vers_col_name vers_col_definition vers_with_without_system_versioning, vers_col_list
  | vers_col_name_and_definition
  | vers_col_name_and_definition, vers_col_list
;

vers_col_type:
    BIGINT UNSIGNED | BIGINT UNSIGNED | BIGINT UNSIGNED
  | TIMESTAMP(6) | TIMESTAMP(6) | TIMESTAMP(6)
  | vers_data_type
;

vers_col_list_with_period:
  { $numcols= $prng->uint16(1,8); @cols= ('vers_explicit_row_start','vers_explicit_row_end'); foreach (1..$numcols) { push @cols, 'vers_col_name_and_definition' }; @cols = @{$prng->shuffleArray(\@cols)}; '' }
    vers_col_list_with_period_recursion
;

vers_col_list_with_period_recursion:
  { $col= pop @cols; $col } { scalar(@cols) ? ',' : '' } { scalar(@cols) ? 'vers_col_list_with_period_recursion' : '' }
;

vers_explicit_row_start:
  vers_col_start vers_col_type GENERATED ALWAYS AS ROW START ;

vers_explicit_row_end:
  vers_col_end vers_col_type GENERATED ALWAYS AS ROW END ;

vers_replace_or_if_not_exists:
  __temporary(2) TABLE | OR REPLACE __temporary(2) TABLE | __temporary(2) TABLE IF NOT EXISTS
;

vers_table_flags:
  vers_row_format vers_encryption vers_compression __with_system_versioning(95) ;

vers_encryption:
;

vers_compression:
;

vers_change_row_format:
  ROW_FORMAT=COMPACT | ROW_FORMAT=COMPRESSED | ROW_FORMAT=DYNAMIC | ROW_FORMAT=REDUNDANT
;

vers_row_format:
  | vers_change_row_format | vers_change_row_format
;

vers_insert_history:
  vers_set_statement_insert_history vers_insert_ignore_replace INTO vers_existing_table ( _field, vers_col_start, vers_col_end ) VALUES vers_history_value_list |
  vers_set_statement_insert_history vers_insert_ignore_replace INTO vers_existing_table ( _field, vers_col_start, vers_col_end ) SELECT _field, vers_col_start, vers_col_end FROM { $my_last_table } |
  vers_set_statement_insert_history vers_insert_ignore_replace INTO vers_existing_table SELECT * FROM { $my_last_table } |
  vers_set_statement_insert_history vers_insert_ignore_replace INTO `vers_simple_table` (a, row_start, row_end) VALUES vers_history_value_list |
  vers_set_statement_insert_history vers_insert_ignore_replace INTO `vers_simple_table` VALUES vers_history_value_list |
  vers_set_statement_insert_history vers_insert_ignore_replace INTO `vers_table_visible_columns` VALUES vers_history_value_list
;

vers_insert_ignore_replace:
  INSERT __ignore(80) | REPLACE ;

vers_non_empty_value_list:
  (_vers_value) | (_vers_value),vers_non_empty_value_list
;

vers_history_value_list:
  vers_history_values | vers_history_values , vers_history_value_list ;

vers_history_values:
  # Valid range historical data
  ==FACTOR:10==  (_vers_value, { $ts=$prng->uint16(0,2147483645); $prng->datetime($ts) . ', '. $prng->datetime($ts+$prng->uint16($ts+1,2147483646)) } ) |
  # Valid range actual data
  ==FACTOR:5==   (_vers_value, { $ts=$prng->uint16(0,2147483646); $prng->datetime($ts) . ', '. "'2036-01-19 00:00:00.000000'" } ) |
  # Possibly invalid range
  ==FACTOR:0.5== (_vers_value, { $ts=$prng->uint16(0,2147483647); $prng->datetime($ts) . ', '. $prng->datetime($ts) } )
;

vers_empty_value_list:
  () | (),vers_empty_value_list
;

vers_column_list:
  vers_col_name | vers_col_name, vers_column_list
;

vers_algorithm:
  ==FACTOR:5== |
  , ALGORITHM=INPLACE |
  , ALGORITHM=NOCOPY |
  , ALGORITHM=COPY |
  , ALGORITHM=INSTANT |
  , ALGORITHM=DEFAULT
;

vers_lock:
  ==FACTOR:3== |
  , LOCK=NONE |
  , LOCK=SHARED |
  , LOCK=EXCLUSIVE
;

vers_data_type:
    BIT
  | vers_enum_type
  | vers_geo_type
  | vers_int_type
  | vers_int_type
  | vers_int_type
  | vers_int_type
  | vers_num_type
  | vers_temporal_type
  | vers_timestamp_type
  | vers_text_type
  | vers_text_type
  | vers_text_type
  | vers_text_type
;

vers_int_type:
  INT | TINYINT | SMALLINT | MEDIUMINT | BIGINT
;

vers_num_type:
  DECIMAL | FLOAT | DOUBLE
;

vers_temporal_type:
  DATE | TIME | YEAR
;

vers_timestamp_type:
  DATETIME | TIMESTAMP
;

vers_enum_type:
  ENUM('foo','bar') | SET('foo','bar')
;

vers_text_type:
  ==FACTOR:20== _basics_char_column_type |
  _basics_blob_column_type
;

vers_geo_type:
  POINT | LINESTRING | POLYGON | MULTIPOINT | MULTILINESTRING | MULTIPOLYGON | GEOMETRYCOLLECTION | GEOMETRY
;

vers_null:
  ==FACTOR:10== |
  ==FACTOR:5== NULL |
  NOT NULL
;

vers_optional_default:
  |
  DEFAULT vers_default_val
;

vers_default_val:
  { "'".$prng->uint16(0,9)."'" } | { $prng->uint16(0,100) }
;

vers_optional_default_char:
  | DEFAULT ''
;

vers_optional_default_int:
  | DEFAULT { $prng->uint16(0,100) };

vers_optional_geo_default:
  | DEFAULT ST_GEOMFROMTEXT('Point(1 1)') ;

vers_optional_auto_increment:
  | | | | | | AUTO_INCREMENT KEY;

vers_key_column_list:
  _field __asc_x_desc(33,33) | _field __asc_x_desc(33,33), vers_key_column_list
;

_vers_value:
  NULL | _digit | '' | _char(1)
;
