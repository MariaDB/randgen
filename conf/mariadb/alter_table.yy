#  Copyright (c) 2018, MariaDB
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
    alt_create_or_replace ; alt_create_or_replace ; alt_create_or_replace ; alt_create_or_replace ; alt_create_or_replace ; alt_create_or_replace ; alt_create_or_replace ; alt_create_or_replace
  ; alt_create_or_replace_sequence ; alt_create_or_replace_sequence
;
 
query_add:
  alt_query
;

alt_query:
    alt_create
  | alt_dml | alt_dml | alt_dml
  | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter
  | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter
# Disable with ASAN due to MDEV-13828
  | alt_rename_multi
  | alt_alter_partitioning
  | alt_flush
  | alt_optimize
  | alt_lock_unlock_table
  | alt_transaction
;

alt_create:
    alt_create_or_replace
  | alt_create_like
;

alt_rename_multi:
  DROP TABLE IF EXISTS { 'tmp_rename_'.abs($$) } ; RENAME TABLE alt_table_name TO { 'tmp_rename_'.abs($$) }, { 'tmp_rename_'.abs($$) } TO { $my_last_table }
;

alt_dml:
    alt_insert | alt_insert | alt_insert | alt_insert | alt_insert | alt_insert | alt_insert | alt_insert | alt_insert | alt_insert | alt_insert
  | alt_update | alt_update
  | alt_delete | alt_truncate
;  

alt_alter:
  ALTER alt_online_optional alt_ignore_optional TABLE alt_table_name alt_wait_optional alt_alter_list
;

alt_wait_optional:
  | | | /*!100301 WAIT _digit */ | /*!100301 NOWAIT */
;

alt_ignore_optional:
  | | IGNORE
;

alt_online_optional:
  | | | ONLINE
;

alt_alter_list:
  alt_alter_item | alt_alter_item, alt_alter_list
;

alt_alter_item:
    alt_table_option
  | alt_add_column
  | alt_modify_column
  | alt_change_column
  | alt_alter_column
  | alt_add_index | alt_add_index | alt_add_index
  | alt_add_foreign_key | alt_add_foreign_key
  | alt_drop_foreign_key
  | alt_add_check_constraint | alt_add_check_constraint
  | alt_drop_check_constraint
  | alt_drop_column | alt_drop_column
  | alt_drop_index | alt_drop_index
  | FORCE alt_lock alt_algorithm
#  | ORDER BY alt_column_list
  | RENAME TO alt_table_name
;

alt_table_option:
    alt_storage_optional ENGINE alt_eq_optional alt_engine
  | alt_storage_optional ENGINE alt_eq_optional alt_engine
  | AUTO_INCREMENT alt_eq_optional _int_unsigned
  | AUTO_INCREMENT alt_eq_optional _int_unsigned
  | AVG_ROW_LENGTH alt_eq_optional _tinyint_unsigned
  | alt_default_optional CHARACTER SET alt_eq_optional alt_character_set
  | alt_default_optional CHARACTER SET alt_eq_optional alt_character_set
  | CHECKSUM alt_eq_optional alt_zero_or_one
  | CHECKSUM alt_eq_optional alt_zero_or_one
  | alt_default_optional COLLATE alt_eq_optional alt_collation
  | COMMENT alt_eq_optional _english
  | COMMENT alt_eq_optional _english
#  | CONNECTION [=] 'connect_string'
#  | DATA DIRECTORY [=] 'absolute path to directory'
  | DELAY_KEY_WRITE alt_eq_optional alt_zero_or_one
# alt_eq_optional disabled due to MDEV-14859
#  | ENCRYPTED alt_eq_optional alt_yes_or_no_no_no
  | /*!100104 ENCRYPTED = alt_yes_or_no_no_no */
# alt_eq_optional disabled due to MDEV-14861
#  | ENCRYPTION_KEY_ID alt_eq_optional _digit
  | /*!100104 ENCRYPTION_KEY_ID = _digit */
# alt_eq_optional disabled due to MDEV-14859
#  | IETF_QUOTES alt_eq_optional alt_yes_or_no_no_no
  | /*!100108 IETF_QUOTES = alt_yes_or_no_no_no */
#  | INDEX DIRECTORY [=] 'absolute path to directory'
#  | INSERT_METHOD [=] { NO | FIRST | LAST }
  | KEY_BLOCK_SIZE alt_eq_optional alt_key_block_size
  | MAX_ROWS alt_eq_optional _int_unsigned
  | MIN_ROWS alt_eq_optional _tinyint_unsigned
  | PACK_KEYS alt_eq_optional alt_zero_or_one_or_default
  | PAGE_CHECKSUM alt_eq_optional alt_zero_or_one
  | PASSWORD alt_eq_optional _english
  | alt_change_row_format
  | alt_change_row_format
  | STATS_AUTO_RECALC alt_eq_optional alt_zero_or_one_or_default
  | STATS_PERSISTENT alt_eq_optional alt_zero_or_one_or_default
  | STATS_SAMPLE_PAGES alt_eq_optional alt_stats_sample_pages
#  | TABLESPACE tablespace_name
# Disabled due to MDEV-13982 (0 also fails)
#  | TRANSACTIONAL alt_eq_optional alt_zero_or_one
#  | UNION [=] (tbl_name[,tbl_name]...)
;

alt_stats_sample_pages:
  DEFAULT | _smallint_unsigned
;

alt_zero_or_one_or_default:
  0 | 1 | DEFAULT
;

alt_key_block_size:
  0 | 1024 | 2048 | 4096 | 8192 | 16384 | 32768 | 65536
;

alt_yes_or_no_no_no:
  YES | NO | NO | NO
;

alt_zero_or_one:
  0 | 1
;

alt_character_set:
  utf8 | latin1 | utf8mb4
;

alt_collation:
    latin1_bin | latin1_general_cs | latin1_general_ci
  | utf8_bin | utf8_nopad_bin | utf8_general_ci
  | utf8mb4_bin | utf8mb4_nopad_bin | utf8mb4_general_nopad_ci | utf8mb4_general_ci
;

alt_eq_optional:
  | =
;

alt_engine:
  InnoDB | InnoDB | InnoDB | MyISAM | MyISAM | Aria | Memory
;

alt_default_optional:
  | | DEFAULT
;

alt_storage_optional:
# Disabled due to MDEV-14860
#  | | STORAGE
;
  

alt_transaction:
    BEGIN
  | SAVEPOINT sp
  | ROLLBACK TO SAVEPOINT sp
  | COMMIT
  | ROLLBACK
;

alt_lock_unlock_table:
# Disabled due to MDEV-13553 and MDEV-12466
#    FLUSH TABLE alt_table_name FOR EXPORT
    LOCK TABLE alt_table_name READ
  | LOCK TABLE alt_table_name WRITE
  | SELECT * FROM alt_table_name FOR UPDATE
  | UNLOCK TABLES
  | UNLOCK TABLES
  | UNLOCK TABLES
  | UNLOCK TABLES
;

alt_alter_partitioning:
    ALTER TABLE alt_table_name PARTITION BY HASH(alt_col_name)
  | ALTER TABLE alt_table_name PARTITION BY KEY(alt_col_name)
  | ALTER TABLE alt_table_name REMOVE PARTITIONING
;

alt_delete:
  DELETE FROM alt_table_name LIMIT _digit
;

alt_truncate:
  TRUNCATE TABLE alt_table_name
;

alt_table_name:
    { $my_last_table = 't'.$prng->int(1,10) }
  | { $my_last_table = 't'.$prng->int(1,10) }
  | _table { $my_last_table = $last_table; '' }
;

alt_col_name:
    alt_int_col_name
  | alt_num_col_name
  | alt_temporal_col_name
  | alt_timestamp_col_name
  | alt_text_col_name
  | alt_enum_col_name
  | alt_virt_col_name
  | _field
;

alt_bit_col_name:
  { $last_column = 'bcol'.$prng->int(1,10) }
;


alt_int_col_name:
    { $last_column = 'icol'.$prng->int(1,10) }
  | { $last_column = 'icol'.$prng->int(1,10) }
  | { $last_column = 'icol'.$prng->int(1,10) }
  | _field_int
;

alt_num_col_name:
    { $last_column = 'ncol'.$prng->int(1,10) }
;

alt_virt_col_name:
    { $last_column = 'vcol'.$prng->int(1,10) }
;

alt_temporal_col_name:
    { $last_column = 'tcol'.$prng->int(1,10) }
;

alt_timestamp_col_name:
    { $last_column = 'tscol'.$prng->int(1,10) }
;

alt_geo_col_name:
    { $last_column = 'geocol'.$prng->int(1,10) }
;

alt_text_col_name:
    { $last_column = 'scol'.$prng->int(1,10) }
  | { $last_column = 'scol'.$prng->int(1,10) }
  | { $last_column = 'scol'.$prng->int(1,10) }
  | _field_char
;

alt_enum_col_name:
    { $last_column = 'ecol'.$prng->int(1,10) }
;

alt_ind_name:
  { $last_index = 'ind'.$prng->int(1,10) }
;

alt_col_name_and_definition:
    alt_bit_col_name alt_bit_type alt_null alt_default_optional_int_or_auto_increment alt_invisible_optional alt_check_optional
  | alt_int_col_name alt_int_type alt_unsigned alt_zerofill alt_null alt_default_optional_int_or_auto_increment alt_invisible_optional alt_check_optional
  | alt_int_col_name alt_int_type alt_unsigned alt_zerofill alt_null alt_default_optional_int_or_auto_increment alt_invisible_optional alt_check_optional
  | alt_int_col_name alt_int_type alt_unsigned alt_zerofill alt_null alt_default_optional_int_or_auto_increment alt_invisible_optional alt_check_optional
  | alt_num_col_name alt_num_type alt_unsigned alt_zerofill alt_null alt_optional_default alt_invisible_optional alt_check_optional
  | alt_temporal_col_name alt_temporal_type alt_null alt_optional_default alt_invisible_optional alt_check_optional
  | alt_timestamp_col_name alt_timestamp_type alt_null alt_optional_default_or_current_timestamp alt_invisible_optional alt_check_optional
  | alt_text_col_name alt_text_type alt_null alt_optional_default_char alt_invisible_optional alt_check_optional
  | alt_text_col_name alt_text_type alt_null alt_optional_default_char alt_invisible_optional alt_check_optional
  | alt_text_col_name alt_text_type alt_null alt_optional_default_char alt_invisible_optional alt_check_optional
  | alt_enum_col_name alt_enum_type alt_null alt_optional_default alt_invisible_optional alt_check_optional
  | alt_virt_col_name alt_virt_col_definition alt_virt_type alt_invisible_optional alt_check_optional
  | alt_geo_col_name alt_geo_type alt_null alt_geo_optional_default alt_invisible_optional alt_check_optional
;


alt_check_optional:
  | | | | /*!100201 CHECK (alt_check_constraint_expression) */
;

alt_invisible_optional:
  | | | | /*!100303 INVISIBLE */
;

alt_col_versioning_optional:
 | | | | | /*!100304 alt_with_without SYSTEM VERSIONING */
;

alt_with_without:
  WITH | WITHOUT
;

alt_virt_col_definition:
    alt_int_type AS ( alt_int_col_name + _digit )
  | alt_num_type AS ( alt_num_col_name + _digit )
  | alt_temporal_type AS ( alt_temporal_col_name )
  | alt_timestamp_type AS ( alt_timestamp_col_name )
  | alt_text_type AS ( SUBSTR(alt_text_col_name, _digit, _digit ) )
  | alt_enum_type AS ( alt_enum_col_name )
  | alt_geo_type AS ( alt_geo_col_name )
;

alt_virt_type:
  STORED | VIRTUAL
;

alt_optional_default_or_current_timestamp:
  | DEFAULT alt_default_or_current_timestamp_val
;

alt_default_or_current_timestamp_val:
    '1970-01-01'
  | CURRENT_TIMESTAMP
  | CURRENT_TIESTAMP ON UPDATE CURRENT_TIMESTAMP
  | 0
;


alt_unsigned:
  | | UNSIGNED
;

alt_zerofill:
  | | | | ZEROFILL
;

alt_default_optional_int_or_auto_increment:
  alt_optional_default_int | alt_optional_default_int | alt_optional_default_int | alt_optional_auto_increment
;

alt_create_or_replace:
  CREATE OR REPLACE alt_temporary TABLE alt_table_name (alt_col_name_and_definition_list) alt_table_flags
;

alt_create_or_replace_sequence:
  /*!100303 CREATE OR REPLACE SEQUENCE alt_table_name */
;

alt_col_name_and_definition_list:
  alt_col_name_and_definition | alt_col_name_and_definition | alt_col_name_and_definition, alt_col_name_and_definition_list
;

alt_table_flags:
  alt_row_format_optional alt_encryption alt_compression
;

alt_encryption:
;

alt_compression:
;

alt_change_row_format:
  ROW_FORMAT alt_eq_optional alt_row_format
;

alt_row_format:
  DEFAULT | DYNAMIC | FIXED | COMPRESSED | REDUNDANT | COMPACT | PAGE
;

alt_row_format_optional:
  | alt_change_row_format | alt_change_row_format
;

alt_create_like:
  CREATE alt_temporary TABLE alt_table_name LIKE _table
;

alt_insert:
  alt_insert_select | alt_insert_values
;

alt_update:
  UPDATE alt_table_name SET alt_col_name = DEFAULT LIMIT 1;

alt_insert_select:
  INSERT INTO alt_table_name ( alt_col_name ) SELECT alt_col_name FROM alt_table_name
;

alt_insert_values:
    INSERT INTO alt_table_name () VALUES alt_empty_value_list
  | INSERT INTO alt_table_name (alt_col_name) VALUES alt_non_empty_value_list
;

alt_non_empty_value_list:
  (_alt_value) | (_alt_value),alt_non_empty_value_list
;
 
alt_empty_value_list:
  () | (),alt_empty_value_list
;

alt_add_column:
    ADD alt_column_optional alt_if_not_exists alt_col_name_and_definition alt_col_location alt_algorithm alt_lock
  | ADD alt_column_optional alt_if_not_exists ( alt_col_name_and_definition_list ) alt_algorithm alt_lock
;

alt_column_optional:
  | | COLUMN
;

alt_col_location:
  | | | | | FIRST | AFTER alt_col_name
;

alt_modify_column:
  MODIFY COLUMN alt_if_exists alt_col_name_and_definition alt_col_location alt_algorithm alt_lock
;

alt_change_column:
  CHANGE COLUMN alt_if_exists alt_col_name alt_col_name_and_definition alt_algorithm alt_lock
;

# MDEV-14694 - ALTER COLUMN does not accept IF EXISTS
# alt_if_exists
alt_alter_column:
    ALTER COLUMN alt_col_name SET DEFAULT alt_default_val
  | ALTER COLUMN alt_col_name DROP DEFAULT
;

alt_if_exists:
  | IF EXISTS | IF EXISTS
;

alt_if_not_exists:
  | IF NOT EXISTS | IF NOT EXISTS
;

alt_drop_column:
  DROP COLUMN alt_if_exists alt_col_name alt_algorithm alt_lock
;

alt_add_index:
  ADD alt_any_key alt_algorithm alt_lock
;


alt_drop_index:
  DROP INDEX alt_ind_name | DROP PRIMARY KEY
;

alt_column_list:
  alt_col_name | alt_col_name, alt_column_list
;

# Disabled due to MDEV-11071
alt_temporary:
#  | | | | TEMPORARY
;

alt_flush:
  FLUSH TABLES
;

alt_optimize:
  OPTIMIZE TABLE alt_table_name
;

alt_algorithm:
  | | , ALGORITHM=INPLACE | , ALGORITHM=COPY | , ALGORITHM=DEFAULT
;

alt_lock:
  | | , LOCK=NONE | , LOCK=SHARED | , LOCK=EXCLUSIVE | , LOCK=DEFAULT
;
  
alt_data_type:
    alt_bit_type
  | alt_enum_type
  | alt_geo_type
  | alt_int_type
  | alt_int_type
  | alt_int_type
  | alt_int_type
  | alt_num_type
  | alt_temporal_type
  | alt_timestamp_type
  | alt_text_type
  | alt_text_type
  | alt_text_type
  | alt_text_type
;

alt_bit_type:
  BIT
;

alt_int_type:
  INT | TINYINT | SMALLINT | MEDIUMINT | BIGINT
;

alt_num_type:
  DECIMAL | FLOAT | DOUBLE
;

alt_temporal_type:
  DATE | TIME | YEAR
;

alt_timestamp_type:
  DATETIME | TIMESTAMP
;

alt_enum_type:
  ENUM('foo','bar') | SET('foo','bar')
;

alt_text_type:
  BLOB | TEXT | CHAR | VARCHAR(_smallint_unsigned) | BINARY | VARBINARY(_smallint_unsigned)
;

alt_geo_type:
  POINT | LINESTRING | POLYGON | MULTIPOINT | MULTILINESTRING | MULTIPOLYGON | GEOMETRYCOLLECTION | GEOMETRY
;

alt_null:
  | NULL | NOT NULL ;
  
alt_optional_default:
  | DEFAULT alt_default_val
;

alt_default_val:
  NULL | alt_default_char_val | alt_default_int_val
;

alt_optional_default_char:
  | DEFAULT alt_default_char_val
;

alt_default_char_val:
  NULL | ''
;

alt_optional_default_int:
  | DEFAULT alt_default_int_val
;

alt_default_int_val:
  NULL | 0 | _digit
;

alt_geo_optional_default:
  | DEFAULT ST_GEOMFROMTEXT('Point(1 1)') ;

alt_optional_auto_increment:
  | | | | | | AUTO_INCREMENT
;
  
alt_inline_key:
  | | | alt_index ;
  
alt_index:
    alt_index_or_key
  | alt_constraint_optional PRIMARY KEY
  | alt_constraint_optional UNIQUE alt_optional_index_or_key
;

alt_add_foreign_key:
  ADD alt_constraint_optional FOREIGN KEY alt_index_name_optional (alt_column_or_list) REFERENCES alt_table_name (alt_column_or_list) alt_optional_on_delete alt_optional_on_update
;

alt_add_check_constraint:
  ADD CONSTRAINT alt_index_name_optional CHECK (alt_check_constraint_expression)
;

alt_drop_check_constraint:
  DROP CONSTRAINT alt_if_exists _letter
;

# TODO: extend
alt_check_constraint_expression:
    alt_col_name alt_operator alt_col_name
  | alt_col_name alt_operator _digit
;

alt_operator:
  = | != | LIKE | NOT LIKE | < | <= | > | >=
;

alt_drop_foreign_key:
  DROP FOREIGN KEY alt_if_exists _letter
;

alt_column_or_list:
  alt_col_name | alt_col_name | alt_col_name | alt_column_list
;

alt_optional_on_delete:
  | | ON DELETE alt_reference_option
;

alt_optional_on_update:
  | | ON UPDATE alt_reference_option
;

alt_reference_option:
  RESTRICT | CASCADE | SET NULL | NO ACTION | SET DEFAULT
;

alt_constraint_optional:
  | CONSTRAINT alt_index_name_optional
;

alt_index_name_optional:
  | _letter
;

alt_index_or_key:
  KEY | INDEX
;

alt_optional_index_or_key:
  | alt_index_or_key
;
  
alt_key_column:
    alt_bit_col_name
  | alt_int_col_name
  | alt_int_col_name
  | alt_int_col_name
  | alt_num_col_name
  | alt_enum_col_name
  | alt_temporal_col_name
  | alt_timestamp_col_name
  | alt_text_col_name(_tinyint_positive)
  | alt_text_col_name(_smallint_positive)
;

alt_key_column_list:
  alt_key_column | alt_key_column, alt_key_column_list
;

alt_any_key:
    alt_index(alt_key_column)
  | alt_index(alt_key_column)
  | alt_index(alt_key_column)
  | alt_index(alt_key_column)
  | alt_index(alt_key_column_list)
  | alt_index(alt_key_column_list)
  | FULLTEXT KEY(alt_text_col_name)
  | FULLTEXT KEY(alt_text_col_name)
#  | SPATIAL INDEX(alt_geo_col_name)
;

alt_comment:
  | | COMMENT 'comment';
  
alt_compressed:
  | | | | | | COMPRESSED ;

_alt_value:
  NULL | _digit | '' | _char(1)
;
