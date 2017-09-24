#  Copyright (c) 2017, MariaDB
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

query_init_add:
  ia_create_or_replace ; ia_create_or_replace ; ia_create_or_replace ; ia_create_or_replace ; ia_create_or_replace ; ia_create_or_replace ; ia_create_or_replace ; ia_create_or_replace ; ia_create_or_replace
;
 
query_add:
  ia_query
;

ia_query:
    ia_create_or_replace
  | ia_create_like
  | ia_insert | ia_insert | ia_insert | ia_insert | ia_insert | ia_insert | ia_insert | ia_insert | ia_insert | ia_insert | ia_insert
  | ia_update | ia_update
  | ia_delete | ia_truncate
  | ia_insert | ia_insert | ia_insert | ia_insert | ia_insert | ia_insert | ia_insert | ia_insert | ia_insert | ia_insert | ia_insert
  | ia_delete | ia_truncate
  | ia_alter | ia_alter | ia_alter | ia_alter | ia_alter | ia_alter | ia_alter | ia_alter | ia_alter
  | ia_alter | ia_alter | ia_alter | ia_alter | ia_alter | ia_alter | ia_alter | ia_alter | ia_alter
  | ia_alter_partitioning
  | ia_flush
  | ia_optimize
  | ia_lock_unlock_table
  | ia_transaction
;

ia_alter:
  ALTER TABLE ia_table_name ia_alter_list
;

ia_alter_list:
  ia_alter_item | ia_alter_item, ia_alter_list
;

ia_alter_item:
    ia_add_column | ia_add_column | ia_add_column | ia_add_column | ia_add_column | ia_add_column
  | ia_modify_column
  | ia_change_column
  | ia_alter_column
  | ia_add_index | ia_add_index | ia_add_index
  | ia_drop_column | ia_drop_column
  | ia_drop_index | ia_drop_index
# Disabled due to MDEV-14396
#  | ia_change_row_format
  | FORCE ia_lock ia_algorithm
  | ENGINE=InnoDB
;

ia_transaction:
    BEGIN
  | SAVEPOINT sp
  | ROLLBACK TO SAVEPOINT sp
  | COMMIT
  | ROLLBACK
;

ia_lock_unlock_table:
    FLUSH TABLE ia_table_name FOR EXPORT
  | LOCK TABLE ia_table_name READ
  | LOCK TABLE ia_table_name WRITE
  | SELECT * FROM ia_table_name FOR UPDATE
  | UNLOCK TABLES
  | UNLOCK TABLES
  | UNLOCK TABLES
  | UNLOCK TABLES
;

ia_alter_partitioning:
    ALTER TABLE ia_table_name PARTITION BY HASH(ia_col_name)
  | ALTER TABLE ia_table_name PARTITION BY KEY(ia_col_name)
  | ALTER TABLE ia_table_name REMOVE PARTITIONING
;

ia_delete:
  DELETE FROM ia_table_name LIMIT _digit
;

ia_truncate:
  TRUNCATE TABLE ia_table_name
;

ia_table_name:
    { $my_last_table = 't'.$prng->int(1,20) }
  | { $my_last_table = 't'.$prng->int(1,20) }
  | { $my_last_table = 't'.$prng->int(1,20) }
  | _table
;

ia_col_name:
    ia_int_col_name
  | ia_num_col_name
  | ia_temporal_col_name
  | ia_timestamp_col_name
  | ia_text_col_name
  | ia_enum_col_name
  | ia_virt_col_name
  | _field
;

ia_bit_col_name:
  { $last_column = 'bcol'.$prng->int(1,10) }
;


ia_int_col_name:
    { $last_column = 'icol'.$prng->int(1,10) }
  | { $last_column = 'icol'.$prng->int(1,10) }
  | { $last_column = 'icol'.$prng->int(1,10) }
  | _field_int
;

ia_num_col_name:
    { $last_column = 'ncol'.$prng->int(1,10) }
;

ia_virt_col_name:
    { $last_column = 'vcol'.$prng->int(1,10) }
;

ia_temporal_col_name:
    { $last_column = 'tcol'.$prng->int(1,10) }
;

ia_timestamp_col_name:
    { $last_column = 'tscol'.$prng->int(1,10) }
;

ia_geo_col_name:
    { $last_column = 'geocol'.$prng->int(1,10) }
;

ia_text_col_name:
    { $last_column = 'scol'.$prng->int(1,10) }
  | { $last_column = 'scol'.$prng->int(1,10) }
  | { $last_column = 'scol'.$prng->int(1,10) }
  | _field_char
;

ia_enum_col_name:
    { $last_column = 'ecol'.$prng->int(1,10) }
;

ia_ind_name:
  { $last_index = 'ind'.$prng->int(1,10) }
;

ia_col_name_and_definition:
    ia_bit_col_name ia_bit_type ia_null ia_default_optional_int_or_auto_increment
  | ia_int_col_name ia_int_type ia_unsigned ia_zerofill ia_null ia_default_optional_int_or_auto_increment
  | ia_int_col_name ia_int_type ia_unsigned ia_zerofill ia_null ia_default_optional_int_or_auto_increment
  | ia_int_col_name ia_int_type ia_unsigned ia_zerofill ia_null ia_default_optional_int_or_auto_increment
  | ia_num_col_name ia_num_type ia_unsigned ia_zerofill ia_null ia_optional_default
  | ia_temporal_col_name ia_temporal_type ia_null ia_optional_default
  | ia_timestamp_col_name ia_timestamp_type ia_null ia_optional_default_or_current_timestamp
  | ia_text_col_name ia_text_type ia_null ia_optional_default_char
  | ia_text_col_name ia_text_type ia_null ia_optional_default_char
  | ia_text_col_name ia_text_type ia_null ia_optional_default_char
  | ia_enum_col_name ia_enum_type ia_null ia_optional_default
  | ia_virt_col_name ia_virt_col_definition ia_virt_type
  | ia_geo_col_name ia_geo_type ia_null ia_geo_optional_default
;

ia_virt_col_definition:
    ia_int_type AS ( ia_int_col_name + _digit )
  | ia_num_type AS ( ia_num_col_name + _digit )
  | ia_temporal_type AS ( ia_temporal_col_name )
  | ia_timestamp_type AS ( ia_timestamp_col_name )
  | ia_text_type AS ( SUBSTR(ia_text_col_name, _digit, _digit ) )
  | ia_enum_type AS ( ia_enum_col_name )
  | ia_geo_type AS ( ia_geo_col_name )
;

ia_virt_type:
  STORED | VIRTUAL
;

ia_optional_default_or_current_timestamp:
  | DEFAULT ia_default_or_current_timestamp_val
;

ia_default_or_current_timestamp_val:
    '1970-01-01'
  | CURRENT_TIMESTAMP
  | CURRENT_TIESTAMP ON UPDATE CURRENT_TIMESTAMP
  | 0
;


ia_unsigned:
  | | UNSIGNED
;

ia_zerofill:
  | | | | ZEROFILL
;

ia_default_optional_int_or_auto_increment:
  ia_optional_default_int | ia_optional_default_int | ia_optional_default_int | ia_optional_auto_increment
;

ia_create_or_replace:
  CREATE OR REPLACE ia_temporary TABLE ia_table_name (ia_col_name_and_definition) ia_table_flags
;

ia_table_flags:
  ia_row_format ia_encryption ia_compression
;

ia_encryption:
;

ia_compression:
;

ia_change_row_format:
  ROW_FORMAT=COMPACT | ROW_FORMAT=COMPRESSED | ROW_FORMAT=DYNAMIC | ROW_FORMAT=REDUNDANT
;

ia_row_format:
  | ia_change_row_format | ia_change_row_format
;

ia_create_like:
  CREATE ia_temporary TABLE ia_table_name LIKE _table
;

ia_insert:
  ia_insert_select | ia_insert_values
;

ia_update:
  UPDATE ia_table_name SET ia_col_name = DEFAULT LIMIT 1;

ia_insert_select:
  INSERT INTO ia_table_name ( ia_col_name ) SELECT ia_col_name FROM ia_table_name
;

ia_insert_values:
    INSERT INTO ia_table_name () VALUES ia_empty_value_list
  | INSERT INTO ia_table_name (ia_col_name) VALUES ia_non_empty_value_list
;

ia_non_empty_value_list:
  (_ia_value) | (_ia_value),ia_non_empty_value_list
;
 
ia_empty_value_list:
  () | (),ia_empty_value_list
;

ia_add_column:
    ADD COLUMN ia_if_not_exists ia_col_name_and_definition ia_col_location ia_algorithm ia_lock
  | ADD COLUMN ia_if_not_exists ( ia_add_column_list ) ia_algorithm ia_lock
;

ia_col_location:
  | | | | | FIRST | AFTER ia_col_name
;

ia_add_column_list:
  ia_col_name_and_definition | ia_col_name_and_definition, ia_add_column_list
;

ia_modify_column:
  MODIFY COLUMN ia_if_exists ia_col_name_and_definition ia_col_location ia_algorithm ia_lock
;

ia_change_column:
  CHANGE COLUMN ia_if_exists ia_col_name ia_col_name_and_definition ia_algorithm ia_lock
;

# MDEV-14694 - ALTER COLUMN does not accept IF EXISTS
# ia_if_exists
ia_alter_column:
    ALTER COLUMN ia_col_name SET DEFAULT ia_default_val
  | ALTER COLUMN ia_col_name DROP DEFAULT
;

ia_if_exists:
  | IF EXISTS | IF EXISTS
;

ia_if_not_exists:
  | IF NOT EXISTS | IF NOT EXISTS
;

ia_drop_column:
  DROP COLUMN ia_if_exists ia_col_name ia_algorithm ia_lock
;

ia_add_index:
  ADD ia_any_key ia_algorithm ia_lock
;


ia_drop_index:
  DROP INDEX ia_ind_name | DROP PRIMARY KEY
;

ia_column_list:
  ia_col_name | ia_col_name, ia_column_list
;

ia_temporary:
  | | | | TEMPORARY
;

ia_flush:
  FLUSH TABLES
;

ia_optimize:
  OPTIMIZE TABLE ia_table_name
;

ia_algorithm:
  | | , ALGORITHM=INPLACE | , ALGORITHM=COPY
;

ia_lock:
  | | , LOCK=NONE | , LOCK=SHARED
;
  
ia_data_type:
    ia_bit_type
  | ia_enum_type
  | ia_geo_type
  | ia_int_type
  | ia_int_type
  | ia_int_type
  | ia_int_type
  | ia_num_type
  | ia_temporal_type
  | ia_timestamp_type
  | ia_text_type
  | ia_text_type
  | ia_text_type
  | ia_text_type
;

ia_bit_type:
  BIT
;

ia_int_type:
  INT | TINYINT | SMALLINT | MEDIUMINT | BIGINT
;

ia_num_type:
  DECIMAL | FLOAT | DOUBLE
;

ia_temporal_type:
  DATE | TIME | YEAR
;

ia_timestamp_type:
  DATETIME | TIMESTAMP
;

ia_enum_type:
  ENUM('foo','bar') | SET('foo','bar')
;

ia_text_type:
  BLOB | TEXT | CHAR | VARCHAR(_smallint_unsigned) | BINARY | VARBINARY(_smallint_unsigned)
;

ia_geo_type:
  POINT | LINESTRING | POLYGON | MULTIPOINT | MULTILINESTRING | MULTIPOLYGON | GEOMETRYCOLLECTION | GEOMETRY
;

ia_null:
  | NULL | NOT NULL ;
  
ia_optional_default:
  | DEFAULT ia_default_val
;

ia_default_val:
  NULL | ia_default_char_val | ia_default_int_val
;

ia_optional_default_char:
  | DEFAULT ia_default_char_val
;

ia_default_char_val:
  NULL | ''
;

ia_optional_default_int:
  | DEFAULT ia_default_int_val
;

ia_default_int_val:
  NULL | 0 | _digit
;

ia_geo_optional_default:
  | DEFAULT ST_GEOMFROMTEXT('Point(1 1)') ;

ia_optional_auto_increment:
  | | | | | | AUTO_INCREMENT
;
  
ia_inline_key:
  | | | ia_index ;
  
ia_index:
  KEY | PRIMARY KEY | UNIQUE ;
  
ia_key_column:
    ia_bit_col_name
  | ia_int_col_name
  | ia_int_col_name
  | ia_int_col_name
  | ia_num_col_name
  | ia_enum_col_name
  | ia_temporal_col_name
  | ia_timestamp_col_name
  | ia_text_col_name(_tinyint_positive)
  | ia_text_col_name(_smallint_positive)
;

ia_key_column_list:
  ia_key_column | ia_key_column, ia_key_column_list
;

ia_any_key:
    ia_index(ia_key_column)
  | ia_index(ia_key_column)
  | ia_index(ia_key_column)
  | ia_index(ia_key_column)
  | ia_index(ia_key_column_list)
  | ia_index(ia_key_column_list)
  | FULLTEXT KEY(ia_text_col_name)
  | SPATIAL INDEX(ia_geo_col_name)
;

ia_comment:
  | | COMMENT 'comment';
  
ia_compressed:
  | | | | | | COMPRESSED ;

_ia_value:
  NULL | _digit | '' | _char(1)
;
