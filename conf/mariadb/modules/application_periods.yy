#  Copyright (c) 2019, MariaDB
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


# Re-defining grammar for application periods

query_add:
  app_periods_query
;

app_periods_query:
    query | query | query
  | app_periods_ia_query | app_periods_ia_query | app_periods_ia_query
  | app_periods_alter | app_periods_alter | app_periods_alter | app_periods_alter | app_periods_alter | app_periods_alter | app_periods_alter | app_periods_alter
  | app_periods_alter | app_periods_alter | app_periods_alter | app_periods_alter | app_periods_alter | app_periods_alter | app_periods_alter | app_periods_alter
  | app_periods_select | app_periods_select | app_periods_select | app_periods_select | app_periods_select | app_periods_select | app_periods_select 
  | app_periods_select | app_periods_select | app_periods_select | app_periods_select | app_periods_select | app_periods_select | app_periods_select 
  | app_periods_select | app_periods_select | app_periods_select | app_periods_select | app_periods_select | app_periods_select | app_periods_select 
  | app_periods_show_table
  | app_periods_drop_table
;

app_periods_show_table:
    SHOW CREATE TABLE app_periods_existing_table
  | DESC app_periods_existing_table
  | SHOW INDEX IN app_periods_existing_table
  | SHOW TABLE STATUS LIKE { "'".$last_table."'" }
  | SHOW COLUMNS IN app_periods_existing_table
  | SHOW FULL COLUMNS IN app_periods_existing_table
  | SHOW FIELDS IN app_periods_existing_table
  | SHOW FULL FIELDS IN app_periods_existing_table
  | SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = { "'".$last_table."'" }
;

app_periods_engine:
  | | ENGINE=InnoDB | ENGINE=MyISAM | ENGINE=Aria | ENGINE=MEMORY
;

app_periods_drop_table:
  DROP TABLE app_periods_ia_if_exists app_periods_ia_table_name
;

app_periods_alter:
    ALTER TABLE app_periods_existing_table app_periods_alter_table_list
  | ALTER TABLE app_periods_existing_table app_periods_partitioning
;

app_periods_alter_table_list:
    app_periods_alter_table | app_periods_alter_table | app_periods_alter_table 
  | app_periods_alter_table, app_periods_alter_table_list
  | app_periods_alter_table, app_periods_ia_alter_list
  | app_periods_ia_alter_list, app_periods_alter_table_list
;

app_periods_alter_table:
    ADD PERIOD app_periods_ia_if_not_exists FOR app_periods_period_name(app_periods_col_start, app_periods_col_start)
  | app_periods_add_drop_period_column
  | DROP PERIOD app_periods_ia_if_exists FOR app_periods_period_name
  | DROP PERIOD app_periods_ia_if_exists FOR app_periods_period_name
  | DROP PERIOD app_periods_ia_if_exists FOR app_periods_period_name
;

app_periods_period_name:
  _letter | period | apptime
;

app_periods_add_drop_period_column:
    ADD COLUMN app_periods_ia_if_not_exists app_periods_col_start app_periods_col_type
  | ADD COLUMN app_periods_ia_if_not_exists app_periods_col_end app_periods_col_type
  | DROP COLUMN app_periods_col_start
  | DROP COLUMN app_periods_col_end
  | CHANGE COLUMN app_periods_ia_if_exists app_periods_col_start app_periods_col_start app_periods_col_type
  | CHANGE COLUMN app_periods_ia_if_exists app_periods_col_end app_periods_col_end app_periods_col_type
;

app_periods_select:
    SELECT * from app_periods_existing_table WHERE row_start app_periods_comparison_operator @trx_user_var
  | SELECT * from app_periods_existing_table WHERE row_end app_periods_comparison_operator @trx_user_var
  | SELECT * from app_periods_existing_table WHERE row_start IN (SELECT row_start FROM app_periods_existing_table)
  | SELECT * from app_periods_existing_table WHERE row_end IN (SELECT row_start FROM app_periods_existing_table)
  | SELECT * from app_periods_existing_table WHERE row_start IN (SELECT row_end FROM app_periods_existing_table)
  | SELECT * from app_periods_existing_table WHERE row_end IN (SELECT row_end FROM app_periods_existing_table)
  | SELECT row_start FROM app_periods_existing_table ORDER BY RAND() LIMIT 1 INTO @trx_user_var
  | SELECT row_end FROM app_periods_existing_table ORDER BY RAND() LIMIT 1 INTO @trx_user_var
;

app_periods_comparison_operator:
  > | < | = | <= | >= | !=
;

app_periods_delete_portion:
  DELETE FROM app_periods_existing_table FOR PORTION OF app_periods_period_name FROM app_periods_value TO app_periods_value ORDER BY _field LIMIT _digit
;

app_periods_portion:
  FOR PORTION OF app_periods_period_name FROM app_periods_timestamp_word app_periods_time_value TO app_periods_timestamp_word app_periods_time_value
;

app_periods_timestamp_word:
  | | | | TIMESTAMP
;

app_periods_time_value:
    _timestamp 
  | CURRENT_TIMESTAMP 
  | CURDATE
  | NOW() | NOW(6)
  | @trx_user_var | @trx_user_var | @trx_user_var | @trx_user_var
  | DATE_ADD(_timestamp, INTERVAL _positive_digit app_periods_interval)
  | DATE_SUB(_timestamp, INTERVAL _positive_digit app_periods_interval)
  | DATE_SUB(NOW(), INTERVAL _positive_digit app_periods_interval)
;

app_periods_col:
  app_periods_col_start | app_periods_col_end
;

app_periods_col_start:
  `app_periods_start` | `row_start` | `s` | _field
;

app_periods_col_end:
  `app_periods_end` | `row_end` | `e` | _field
;

app_periods_or_replace_if_not_exists:
  | OR REPLACE | IF NOT EXISTS
;

app_periods_partitioning:
    app_periods_partitioning_definition
  | app_periods_partitioning_definition
  | REMOVE PARTITIONING
  | DROP PARTITION app_periods_ia_if_exists { 'p'.$prng->int(1,5) }
;

app_periods_partitioning_optional:
  | | app_periods_partitioning_definition
;

app_periods_partitioning_definition:
  | | | | PARTITION BY app_periods_hash_key(app_periods_ia_col_name) PARTITIONS _positive_digit
;

app_periods_hash_key:
  KEY | HASH
;

app_periods_interval:
  SECOND | MINUTE | HOUR | DAY | WEEK | MONTH | YEAR
;

####################################################

app_periods_ia_query:
    app_periods_ia_create
  | app_periods_ia_insert | app_periods_ia_insert | app_periods_ia_insert | app_periods_ia_insert | app_periods_ia_insert | app_periods_ia_insert | app_periods_ia_insert | app_periods_ia_insert | app_periods_ia_insert | app_periods_ia_insert | app_periods_ia_insert
  | app_periods_ia_update | app_periods_ia_update
  | app_periods_ia_delete | app_periods_ia_truncate
  | app_periods_ia_insert | app_periods_ia_insert | app_periods_ia_insert | app_periods_ia_insert | app_periods_ia_insert | app_periods_ia_insert | app_periods_ia_insert | app_periods_ia_insert | app_periods_ia_insert | app_periods_ia_insert | app_periods_ia_insert
  | app_periods_ia_delete | app_periods_ia_truncate
  | app_periods_ia_alter | app_periods_ia_alter | app_periods_ia_alter | app_periods_ia_alter | app_periods_ia_alter | app_periods_ia_alter | app_periods_ia_alter | app_periods_ia_alter | app_periods_ia_alter
  | app_periods_ia_alter | app_periods_ia_alter | app_periods_ia_alter | app_periods_ia_alter | app_periods_ia_alter | app_periods_ia_alter | app_periods_ia_alter | app_periods_ia_alter | app_periods_ia_alter
  | app_periods_ia_alter_partitioning
  | app_periods_ia_flush
  | app_periods_ia_optimize
  | app_periods_ia_lock_unlock_table
  | app_periods_ia_transaction
  | app_periods_ia_select
;

app_periods_ia_select:
  SELECT * FROM app_periods_existing_table
;

app_periods_ia_systime:
  ALL | NOW(6) | NOW() | CURRENT_TIMESTAMP | DATE(NOW())
;

app_periods_ia_alter:
  ALTER TABLE app_periods_existing_table app_periods_ia_alter_list
;

app_periods_ia_alter_list:
  app_periods_ia_alter_item | app_periods_ia_alter_item, app_periods_ia_alter_list
;

app_periods_ia_alter_item:
    app_periods_ia_add_column | app_periods_ia_add_column | app_periods_ia_add_column | app_periods_ia_add_column | app_periods_ia_add_column
  | app_periods_ia_modify_column
  | app_periods_ia_change_column
  | app_periods_ia_alter_column
  | app_periods_ia_add_index | app_periods_ia_add_index | app_periods_ia_add_index
  | app_periods_ia_drop_column | app_periods_ia_drop_column
  | app_periods_ia_drop_index | app_periods_ia_drop_index
  | app_periods_ia_change_row_format
  | FORCE app_periods_ia_lock app_periods_ia_algorithm
  | ENGINE=InnoDB
;

app_periods_ia_transaction:
    BEGIN | BEGIN | BEGIN
  | SAVEPOINT sp
  | ROLLBACK TO SAVEPOINT sp
  | COMMIT | COMMIT | COMMIT
  | ROLLBACK | ROLLBACK
  | SET AUTOCOMMIT=OFF
  | SET AUTOCOMMIT=ON
;

app_periods_ia_lock_unlock_table:
    FLUSH TABLE app_periods_existing_table FOR EXPORT
  | LOCK TABLE app_periods_existing_table READ
  | LOCK TABLE app_periods_existing_table WRITE
  | SELECT * FROM app_periods_existing_table FOR UPDATE
  | UNLOCK TABLES | UNLOCK TABLES | UNLOCK TABLES
;

app_periods_ia_alter_partitioning:
    ALTER TABLE app_periods_existing_table PARTITION BY HASH(app_periods_ia_col_name)
  | ALTER TABLE app_periods_existing_table PARTITION BY KEY(app_periods_ia_col_name)
  | ALTER TABLE app_periods_existing_table REMOVE PARTITIONING
;

app_periods_ia_delete:
  DELETE FROM app_periods_existing_table LIMIT _digit
;

app_periods_ia_truncate:
  TRUNCATE TABLE app_periods_existing_table
;

app_periods_ia_table_name:
    { $my_last_table = 't'.$prng->int(1,10) }
;

app_periods_existing_table:
  app_periods_ia_table_name | _table
;

app_periods_ia_col_name:
    app_periods_ia_int_col_name
  | app_periods_ia_num_col_name
  | app_periods_ia_temporal_col_name
  | app_periods_ia_timestamp_col_name
  | app_periods_ia_text_col_name
  | app_periods_ia_enum_col_name
  | app_periods_ia_virt_col_name
  | _field
  | app_periods_col
;

app_periods_ia_bit_col_name:
  { $last_column = 'bcol'.$prng->int(1,10) }
;


app_periods_ia_int_col_name:
    { $last_column = 'icol'.$prng->int(1,10) }
  | { $last_column = 'icol'.$prng->int(1,10) }
  | { $last_column = 'icol'.$prng->int(1,10) }
  | _field_int
;

app_periods_ia_num_col_name:
    { $last_column = 'ncol'.$prng->int(1,10) }
;

app_periods_ia_virt_col_name:
    { $last_column = 'vcol'.$prng->int(1,10) }
;

app_periods_ia_temporal_col_name:
    { $last_column = 'tcol'.$prng->int(1,10) }
;

app_periods_ia_timestamp_col_name:
    { $last_column = 'tscol'.$prng->int(1,10) }
;

app_periods_ia_geo_col_name:
    { $last_column = 'geocol'.$prng->int(1,10) }
;

app_periods_ia_text_col_name:
    { $last_column = 'scol'.$prng->int(1,10) }
  | { $last_column = 'scol'.$prng->int(1,10) }
  | { $last_column = 'scol'.$prng->int(1,10) }
  | _field_char
;

app_periods_ia_enum_col_name:
    { $last_column = 'ecol'.$prng->int(1,10) }
;

app_periods_ia_ind_name:
  { $last_index = 'ind'.$prng->int(1,10) }
;

app_periods_ia_col_name_and_definition:
    app_periods_ia_real_col_name_and_definition
  | app_periods_ia_real_col_name_and_definition
  | app_periods_ia_real_col_name_and_definition
  | app_periods_ia_real_col_name_and_definition
  | app_periods_ia_real_col_name_and_definition
  | app_periods_ia_real_col_name_and_definition
  | app_periods_ia_real_col_name_and_definition
  | app_periods_ia_real_col_name_and_definition
  | app_periods_ia_real_col_name_and_definition
  | app_periods_ia_virt_col_name_and_definition
;

app_periods_ia_virt_col_name_and_definition:
  app_periods_ia_virt_col_name app_periods_ia_virt_col_definition app_periods_ia_virt_type
;

app_periods_ia_real_col_name_and_definition:
    app_periods_ia_bit_col_name app_periods_ia_bit_type app_periods_ia_null app_periods_ia_optional_default_int_or_auto_increment
  | app_periods_ia_int_col_name app_periods_ia_int_type app_periods_ia_unsigned app_periods_ia_zerofill app_periods_ia_null app_periods_ia_optional_default_int_or_auto_increment
  | app_periods_ia_int_col_name app_periods_ia_int_type app_periods_ia_unsigned app_periods_ia_zerofill app_periods_ia_null app_periods_ia_optional_default_int_or_auto_increment
  | app_periods_ia_int_col_name app_periods_ia_int_type app_periods_ia_unsigned app_periods_ia_zerofill app_periods_ia_null app_periods_ia_optional_default_int_or_auto_increment
  | app_periods_ia_num_col_name app_periods_ia_num_type app_periods_ia_unsigned app_periods_ia_zerofill app_periods_ia_null app_periods_ia_optional_default
  | app_periods_ia_temporal_col_name app_periods_ia_temporal_type app_periods_ia_null app_periods_ia_optional_default
  | app_periods_ia_timestamp_col_name app_periods_ia_timestamp_type app_periods_ia_null app_periods_ia_optional_default_or_current_timestamp
  | app_periods_ia_text_col_name app_periods_ia_text_type app_periods_ia_null app_periods_ia_optional_default_char
  | app_periods_ia_text_col_name app_periods_ia_text_type app_periods_ia_null app_periods_ia_optional_default_char
  | app_periods_ia_text_col_name app_periods_ia_text_type app_periods_ia_null app_periods_ia_optional_default_char
  | app_periods_ia_enum_col_name app_periods_ia_enum_type app_periods_ia_null app_periods_ia_optional_default
  | app_periods_ia_geo_col_name app_periods_ia_geo_type app_periods_ia_null app_periods_ia_optional_geo_default
;

app_periods_ia_virt_col_definition:
    app_periods_ia_int_type AS ( app_periods_ia_int_col_name + _digit )
  | app_periods_ia_num_type AS ( app_periods_ia_num_col_name + _digit )
  | app_periods_ia_temporal_type AS ( app_periods_ia_temporal_col_name )
  | app_periods_ia_timestamp_type AS ( app_periods_ia_timestamp_col_name )
  | app_periods_ia_text_type AS ( SUBSTR(app_periods_ia_text_col_name, _digit, _digit ) )
  | app_periods_ia_enum_type AS ( app_periods_ia_enum_col_name )
  | app_periods_ia_geo_type AS ( app_periods_ia_geo_col_name )
;

app_periods_ia_virt_type:
  STORED | VIRTUAL
;

app_periods_ia_optional_default_or_current_timestamp:
  | DEFAULT app_periods_ia_default_or_current_timestamp_val
;
  
app_periods_ia_default_or_current_timestamp_val:
    '1970-01-01'
  | CURRENT_TIMESTAMP
  | CURRENT_TIESTAMP ON UPDATE CURRENT_TIMESTAMP
  | 0
;


app_periods_ia_unsigned:
  | | UNSIGNED
;

app_periods_ia_zerofill:
  | | | | ZEROFILL
;

app_periods_ia_optional_default_int_or_auto_increment:
  | app_periods_ia_optional_default_int
  | app_periods_ia_optional_default_int
  | app_periods_ia_optional_default_int
  | app_periods_ia_optional_auto_increment
;

#app_periods_ia_column_definition:
#  app_periods_ia_data_type app_periods_ia_null app_periods_ia_default app_periods_ia_optional_auto_increment app_periods_ia_inline_key app_periods_ia_comment app_periods_ia_compressed
#;

app_periods_ia_create:
    CREATE app_periods_ia_replace_or_if_not_exists app_periods_ia_table_name (app_periods_col_list) app_periods_engine app_periods_ia_table_flags app_periods_partitioning_optional
  | CREATE app_periods_ia_replace_or_if_not_exists app_periods_ia_table_name (app_periods_col_list_with_period , PERIOD FOR SYSTEM_TIME ( app_periods_col_start, app_periods_col_end )) app_periods_engine app_periods_ia_table_flags app_periods_partitioning_optional
  | CREATE app_periods_ia_replace_or_if_not_exists app_periods_ia_table_name LIKE app_periods_existing_table
;

# MDEV-14669 -- cannot use virtual columns with/without system versioning

app_periods_col_list:
    app_periods_ia_real_col_name_and_definition
  | app_periods_ia_real_col_name_and_definition, app_periods_col_list
;

app_periods_col_type:
    BIGINT UNSIGNED | BIGINT UNSIGNED | BIGINT UNSIGNED
  | TIMESTAMP(6) | TIMESTAMP(6) | TIMESTAMP(6)
  | app_periods_ia_data_type
;

app_periods_col_list_with_period:
    app_periods_ia_real_col_name_and_definition, app_periods_col_list_with_period
  | app_periods_col_start app_periods_col_type GENERATED ALWAYS AS ROW START, app_periods_col_end app_periods_ia_data_type GENERATED ALWAYS AS ROW END
;  

app_periods_ia_replace_or_if_not_exists:
  app_periods_ia_temporary TABLE | OR REPLACE app_periods_ia_temporary TABLE | app_periods_ia_temporary TABLE IF NOT EXISTS
;

app_periods_ia_table_flags:
  app_periods_ia_row_format app_periods_ia_encryption app_periods_ia_compression
;

app_periods_ia_encryption:
;

app_periods_ia_compression:
;

app_periods_ia_change_row_format:
  ROW_FORMAT=COMPACT | ROW_FORMAT=COMPRESSED | ROW_FORMAT=DYNAMIC | ROW_FORMAT=REDUNDANT
;

app_periods_ia_row_format:
  | app_periods_ia_change_row_format | app_periods_ia_change_row_format
;

app_periods_ia_insert:
  app_periods_ia_insert_select | app_periods_ia_insert_values
;

app_periods_ia_update:
  UPDATE app_periods_existing_table SET app_periods_ia_col_name = DEFAULT LIMIT 1;

app_periods_ia_insert_select:
  INSERT INTO app_periods_existing_table ( app_periods_ia_col_name ) SELECT app_periods_ia_col_name FROM app_periods_existing_table
;

app_periods_ia_insert_values:
    INSERT INTO app_periods_existing_table () VALUES app_periods_ia_empty_value_list
  | INSERT INTO app_periods_existing_table (app_periods_ia_col_name) VALUES app_periods_ia_non_empty_value_list
;

app_periods_ia_non_empty_value_list:
  (_app_periods_ia_value) | (_app_periods_ia_value),app_periods_ia_non_empty_value_list
;
 
app_periods_ia_empty_value_list:
  () | (),app_periods_ia_empty_value_list
;

app_periods_ia_add_column:
  ADD COLUMN app_periods_ia_if_not_exists app_periods_ia_col_name_and_definition app_periods_ia_col_location app_periods_ia_algorithm app_periods_ia_lock
;

app_periods_ia_modify_column:
  MODIFY COLUMN app_periods_ia_if_exists app_periods_ia_col_name_and_definition app_periods_ia_col_location app_periods_ia_algorithm app_periods_ia_lock
;

app_periods_ia_change_column:
  CHANGE COLUMN app_periods_ia_if_exists app_periods_ia_col_name app_periods_ia_col_name_and_definition app_periods_ia_algorithm app_periods_ia_lock
;

app_periods_ia_col_location:
  | | | | | FIRST | AFTER ia_col_name
;

# MDEV-14694 - ALTER COLUMN does not accept IF EXISTS
# app_periods_ia_if_exists
app_periods_ia_alter_column:
    ALTER COLUMN app_periods_ia_col_name SET DEFAULT app_periods_ia_default_val
  | ALTER COLUMN app_periods_ia_col_name DROP DEFAULT
;

app_periods_ia_if_exists:
  | IF EXISTS | IF EXISTS | IF EXISTS
;

app_periods_ia_if_not_exists:
  | IF NOT EXISTS | IF NOT EXISTS | IF NOT EXISTS 
;

app_periods_ia_drop_column:
  DROP COLUMN app_periods_ia_if_exists app_periods_ia_col_name app_periods_ia_algorithm app_periods_ia_lock
;

app_periods_ia_add_index:
  ADD app_periods_ia_any_key app_periods_ia_algorithm app_periods_ia_lock
;


app_periods_ia_drop_index:
  DROP INDEX app_periods_ia_ind_name | DROP PRIMARY KEY
;

app_periods_ia_column_list:
  app_periods_ia_col_name | app_periods_ia_col_name, app_periods_ia_column_list
;

# Disabled due to MDEV-11071
app_periods_ia_temporary:
#  | | | | TEMPORARY
;

app_periods_ia_flush:
  FLUSH TABLES
;

app_periods_ia_optimize:
  OPTIMIZE TABLE app_periods_existing_table
;

app_periods_ia_algorithm:
  | | , ALGORITHM=INPLACE | , ALGORITHM=COPY
;

app_periods_ia_lock:
  | | , LOCK=NONE | , LOCK=SHARED
;
  
app_periods_ia_data_type:
    app_periods_ia_bit_type
  | app_periods_ia_enum_type
  | app_periods_ia_geo_type
  | app_periods_ia_int_type
  | app_periods_ia_int_type
  | app_periods_ia_int_type
  | app_periods_ia_int_type
  | app_periods_ia_num_type
  | app_periods_ia_temporal_type
  | app_periods_ia_timestamp_type
  | app_periods_ia_text_type
  | app_periods_ia_text_type
  | app_periods_ia_text_type
  | app_periods_ia_text_type
;

app_periods_ia_bit_type:
  BIT
;

app_periods_ia_int_type:
  INT | TINYINT | SMALLINT | MEDIUMINT | BIGINT
;

app_periods_ia_num_type:
  DECIMAL | FLOAT | DOUBLE
;

app_periods_ia_temporal_type:
  DATE | TIME | YEAR
;

app_periods_ia_timestamp_type:
  DATETIME | TIMESTAMP
;

app_periods_ia_enum_type:
  ENUM('foo','bar') | SET('foo','bar')
;

app_periods_ia_text_type:
  BLOB | TEXT | CHAR | VARCHAR(_smallint_unsigned) | BINARY | VARBINARY(_smallint_unsigned)
;

app_periods_ia_geo_type:
  POINT | LINESTRING | POLYGON | MULTIPOINT | MULTILINESTRING | MULTIPOLYGON | GEOMETRYCOLLECTION | GEOMETRY
;

app_periods_ia_null:
  | NULL | NOT NULL ;
  
app_periods_ia_optional_default:
  | DEFAULT app_periods_ia_default_val
;

app_periods_ia_default_val:
  NULL | app_periods_ia_default_char_val | app_periods_ia_default_int_val
;

app_periods_ia_optional_default_char:
  | DEFAULT app_periods_ia_default_char_val
;

app_periods_ia_default_char_val:
  NULL | ''
;

app_periods_ia_optional_default_int:
  | DEFAULT app_periods_ia_default_int_val;

app_periods_ia_default_int_val:
  NULL | 0 | _digit
;

app_periods_ia_optional_geo_default:
  | DEFAULT ST_GEOMFROMTEXT('Point(1 1)') ;

app_periods_ia_optional_auto_increment:
  | | | | | | AUTO_INCREMENT ;
  
app_periods_ia_inline_key:
  | | | app_periods_ia_index ;
  
app_periods_ia_index:
  KEY | PRIMARY KEY | UNIQUE ;
  
app_periods_ia_key_column:
    app_periods_ia_bit_col_name
  | app_periods_ia_int_col_name
  | app_periods_ia_int_col_name
  | app_periods_ia_int_col_name
  | app_periods_ia_num_col_name
  | app_periods_ia_enum_col_name
  | app_periods_ia_temporal_col_name
  | app_periods_ia_timestamp_col_name
  | app_periods_ia_text_col_name(_tinyint_positive)
  | app_periods_ia_text_col_name(_smallint_positive)
;

app_periods_ia_key_column_list:
  app_periods_ia_key_column | app_periods_ia_key_column, app_periods_ia_key_column_list
;

app_periods_ia_any_key:
    app_periods_ia_index(app_periods_ia_key_column)
  | app_periods_ia_index(app_periods_ia_key_column)
  | app_periods_ia_index(app_periods_ia_key_column)
  | app_periods_ia_index(app_periods_ia_key_column)
  | app_periods_ia_index(app_periods_ia_key_column_list)
  | app_periods_ia_index(app_periods_ia_key_column_list)
  | FULLTEXT KEY(app_periods_ia_text_col_name)
#  | SPATIAL INDEX(app_periods_ia_geo_col_name)
;

app_periods_ia_comment:
  | | COMMENT 'comment';
  
app_periods_ia_compressed:
  | | | | | | COMPRESSED ;

_app_periods_ia_value:
  NULL | _digit | '' | _char(1)
;
