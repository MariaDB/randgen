#  Copyright (c) 2018, 2022, MariaDB
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

#include <conf/yy/include/basics.inc>
#features Aria tables, foreign keys, virtual columns


query_init:
  { $tbnum=0; '' }
     CREATE DATABASE IF NOT EXISTS alt_table_db
  ;; SET ROLE admin
     # PS is a workaround for MDEV-30190
  ;; EXECUTE IMMEDIATE CONCAT('GRANT ALL ON alt_table_db.* TO ',CURRENT_USER,' WITH GRANT OPTION')
  ;; SET ROLE NONE
  ;; { _set_db('alt_table_db') }
     alt_create_or_replace ;; alt_create_or_replace ;; alt_create_or_replace
  ;; alt_create_or_replace ;; alt_create_or_replace ;; alt_create_or_replace
  ;; alt_create_or_replace ;; alt_create_or_replace ;; alt_create_or_replace
;

query:
  { $in_new_table= 0; $colnum= 0; '' } alt_query;

alt_query:
    ==FACTOR:0.5== { _set_db('alt_table_db') } alt_create
  | ==FACTOR:20==  { _set_db('NON-SYSTEM') } alt_alter
  | ==FACTOR:0.1== { _set_db('alt_table_db') } alt_rename_multi
  |                { _set_db('NON-SYSTEM') } alt_alter_partitioning
  | ==FACTOR:0.5== { _set_db('NON-SYSTEM') } alt_optimize
  |                { _set_db('NON-SYSTEM') }  alt_alter_item_skip_binlog
;

alt_create:
    alt_create_or_replace
  | alt_create_like
;

alt_rename_multi:
    DROP TABLE IF EXISTS { $tmp_tbl= 'tmp_rename_'.abs($$) } ;; RENAME TABLE _basetable[invariant] TO { $tmp_tbl }, { $tmp_tbl } TO _basetable[invariant]
;

alt_alter:
  alt_optional_set_statement ALTER alt_online_optional alt_ignore_optional TABLE alt_if_exists _basetable _basics_wait_nowait alt_alter_list_with_optional_order_by |
  alt_optional_set_statement ALTER ONLINE __ignore(20) TABLE __if_exists(95) _basetable _basics_wait_nowait alt_alter_list, ALGORITHM=COPY
;

alt_if_exists:
  |
  ==FACTOR:95== IF EXISTS /* compatibility 10.5.2 */
;

alt_ignore_optional:
  | | IGNORE
;

alt_online_optional:
  | | | ONLINE
;

alt_alter_list_with_optional_order_by:
  alt_alter_list alt_optional_order_by
;

alt_alter_list:
  ==FACTOR:3== alt_alter_item |
  alt_alter_item, alt_alter_list
;

alt_alter_item:
    ==FACTOR:5==   alt_table_option
  | ==FACTOR:2==   alt_add_column
  | ==FACTOR:3==   alt_modify_column
  |                alt_change_column
  |                alt_alter_column
  | ==FACTOR:4==   alt_add_index
  | ==FACTOR:0.2== alt_add_foreign_key
  | ==FACTOR:0.2== alt_drop_foreign_key
  | ==FACTOR:0.5== alt_add_check_constraint
  | ==FACTOR:0.5== alt_drop_check_constraint
  | ==FACTOR:0.5== alt_drop_column
  |                alt_drop_index
  | ==FACTOR:0.1== alt_versioning
  | ==FACTOR:2==   alt_convert_charset
  | ==FACTOR:0.001== RENAME TO alt_new_or_existing_table_name
  | ==FACTOR:4==   alt_alter_item_can_skip_binlog
;

alt_convert_charset:
  CONVERT TO CHARACTER SET _charset_name alt_optional_collation ;

alt_optional_collation:
  | COLLATE _collation_name ;

# We will only do non-binlog ALTER if it doesn't change the structure,
# to avoid diverging
alt_alter_item_can_skip_binlog:
    ==FACTOR:4==   FORCE alt_lock alt_algorithm
  |                DISABLE KEYS alt_lock alt_algorithm
  |                ENABLE KEYS alt_lock alt_algorithm
;

alt_alter_item_skip_binlog:
  SET STATEMENT SQL_LOG_BIN=0 FOR ALTER TABLE alt_if_exists _basetable _basics_wait_nowait alt_alter_item_can_skip_binlog
;

# Can't put it on the list, as ORDER BY should always go last
alt_optional_order_by:
  | | | | | | | | | | , ORDER BY alt_column_list ;

alt_versioning:
  ==FACTOR:3== ADD SYSTEM VERSIONING |
               DROP SYSTEM VERSIONING
;

alt_optional_set_statement:
  | SET STATEMENT SYSTEM_VERSIONING_ALTER_HISTORY=KEEP FOR
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
  | alt_comment
  | alt_comment
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
  | TRANSACTIONAL alt_eq_optional alt_zero_or_one
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
    latin1_bin
  | latin1_general_cs
  | latin1_general_ci
  | utf8_bin
  | /*!100202 utf8_nopad_bin */ /*!!100202 utf8_bin */
  | utf8_general_ci
  | utf8mb4_bin
  | /*!100202 utf8mb4_nopad_bin */ /*!!100202 utf8mb4_bin */
  | /*!100202 utf8mb4_general_nopad_ci */ /*!!100202 utf8mb4_general_ci */
  | utf8mb4_general_ci
;

alt_eq_optional:
  | =
;

alt_engine:
  InnoDB | InnoDB | InnoDB | InnoDB | MyISAM | MyISAM | Aria | Aria | Memory
;

alt_default_optional:
  | | DEFAULT
;

alt_storage_optional:
# Disabled due to MDEV-14860
#  | | STORAGE
;

alt_alter_partitioning:
    ALTER TABLE _basetable PARTITION BY HASH(alt_col_name)
  | ALTER TABLE _basetable PARTITION BY KEY(alt_col_name)
  | ALTER TABLE _basetable REMOVE PARTITIONING
;

alt_new_or_existing_table_name:
  ==FACTOR:10== alt_new_table_name |
  _basetable
;

alt_new_table_name:
    { 'alt_t'.(++$tbnum) }
;

alt_col_name:
 { $in_new_table ? 'altcol'.$prng->uint16(1,$colnum) : '_field' } ;
;

alt_new_col_name:
  { 'altcol'.(++$colnum) } ;

alt_new_or_existing_col_name:
  ==FACTOR:10== alt_new_col_name |
  alt_col_name
;

alt_col_definition:
    alt_bit_type alt_null alt_default_optional_int_or_auto_increment alt_invisible_optional alt_check_optional
  | alt_int_type alt_unsigned alt_zerofill alt_null alt_default_optional_int_or_auto_increment alt_invisible_optional alt_check_optional
  | alt_int_type alt_unsigned alt_zerofill alt_null alt_default_optional_int_or_auto_increment alt_invisible_optional alt_check_optional
  | alt_int_type alt_unsigned alt_zerofill alt_null alt_default_optional_int_or_auto_increment alt_invisible_optional alt_check_optional
  | alt_num_type alt_unsigned alt_zerofill alt_null alt_optional_default alt_invisible_optional alt_check_optional
  | alt_temporal_type alt_null alt_optional_default alt_invisible_optional alt_check_optional
  | alt_timestamp_type alt_null alt_optional_default_or_current_timestamp alt_invisible_optional alt_check_optional
  | alt_text_type alt_null alt_optional_default_char alt_invisible_optional alt_check_optional
  | alt_text_type alt_null alt_optional_default_char alt_invisible_optional alt_check_optional
  | alt_text_type alt_null alt_optional_default_char alt_invisible_optional alt_check_optional
  | alt_enum_type alt_null alt_optional_default alt_invisible_optional alt_check_optional
# TODO: vcols: adjust probability when virtual columns start working
  | ==FACTOR:0.01== alt_virt_col_definition alt_virt_type alt_invisible_optional alt_check_optional
  | alt_geo_type alt_null alt_geo_optional_default alt_invisible_optional alt_check_optional
;


alt_check_optional:
  | | | | /*!100201 CHECK (alt_check_constraint_expression) */
;

alt_invisible_optional:
  | | | | /*!100303 INVISIBLE */
;

alt_virt_col_definition:
    alt_int_type AS ( alt_col_name + _digit )
  | alt_num_type AS ( alt_col_name + _digit )
  | alt_temporal_type AS ( alt_col_name )
  | alt_timestamp_type AS ( alt_col_name )
  | alt_text_type AS ( SUBSTR(alt_col_name, _digit, _digit ) )
  | alt_enum_type AS ( alt_col_name )
  | alt_geo_type AS ( alt_col_name )
;

alt_virt_type:
  /*!100201 STORED */ /*!!100201 PERSISTENT */ | VIRTUAL
;

alt_optional_default_or_current_timestamp:
  | DEFAULT alt_default_or_current_timestamp_val
;

alt_default_or_current_timestamp_val:
    '1970-01-01'
  | CURRENT_TIMESTAMP
  | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
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
  { $in_new_table= 1; '' } CREATE OR REPLACE alt_temporary TABLE alt_new_table_name (alt_col_name_and_definition_list alt_optional_keys) alt_table_flags { $in_new_table=0; '' }
;

alt_optional_keys:
  | , alt_key_list ;

alt_key_list:
  ==FACTOR:3== alt_key |
  alt_key, alt_key_list ;

alt_key:
    __key_x_unique(90,10) ({'altcol'.$prng->uint16(1,$colnum)})
  | __key_x_unique(90,10) ({'altcol'.$prng->uint16(1,$colnum)},{'altcol'.$prng->uint16(1,$colnum)})
;

alt_col_name_and_definition_list:
  alt_new_col_name alt_col_definition |
  alt_new_col_name alt_col_definition, alt_col_name_and_definition_list
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
    DEFAULT | DEFAULT | DEFAULT
  | DYNAMIC | DYNAMIC | DYNAMIC | DYNAMIC
  | FIXED | FIXED
  | COMPRESSED | COMPRESSED | COMPRESSED | COMPRESSED
  | REDUNDANT | REDUNDANT | REDUNDANT
  | COMPACT | COMPACT | COMPACT
  | PAGE
;

alt_row_format_optional:
  | alt_change_row_format | alt_change_row_format
;

alt_create_like:
  CREATE alt_temporary TABLE alt_new_or_existing_table_name LIKE _basetable
;

alt_add_column:
    ADD alt_column_optional __if_not_exists(95) alt_new_col_name alt_col_definition alt_col_location alt_algorithm alt_lock
  | ADD alt_column_optional __if_not_exists(95) ( alt_col_name_and_definition_list ) alt_algorithm alt_lock
;

alt_column_optional:
  | | COLUMN
;

alt_col_location:
  | | | | | FIRST | AFTER alt_col_name
;

alt_modify_column:
  MODIFY COLUMN __if_exists(95) alt_col_name alt_col_definition alt_col_location alt_algorithm alt_lock
;

alt_change_column:
  CHANGE COLUMN __if_exists(95) alt_col_name alt_new_or_existing_col_name alt_col_definition alt_algorithm alt_lock
;

alt_alter_column:
    ALTER COLUMN __if_exists(95) alt_col_name SET DEFAULT alt_default_val
  | ALTER COLUMN alt_col_name DROP DEFAULT
;

alt_drop_column:
  DROP COLUMN __if_exists(95) alt_col_name alt_algorithm alt_lock
;

alt_add_index:
  ADD alt_any_key alt_algorithm alt_lock
;


alt_drop_index:
  DROP INDEX /* EXECUTOR_FLAG_NON_EXISTING_ALLOWED */ _index | DROP PRIMARY KEY
;

alt_column_list:
  ==FACTOR:3== alt_col_name |
  alt_col_name, alt_column_list
;

alt_temporary:
  | | | | TEMPORARY
;

alt_optimize:
  OPTIMIZE TABLE _basetable
;

alt_algorithm:
  ==FACTOR:10== |
  ==FACTOR:2== , ALGORITHM=DEFAULT |
               , ALGORITHM=INPLACE |
  ==FACTOR:5== , ALGORITHM=COPY |
               , ALGORITHM=NOCOPY |
               , ALGORITHM=INSTANT
;

alt_lock:
  ==FACTOR:10== |
  ==FACTOR:2== , LOCK=DEFAULT |
               , LOCK=NONE |
               , LOCK=SHARED |
               , LOCK=EXCLUSIVE
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
  | /*!100201 DEFAULT ST_GEOMFROMTEXT('Point(1 1)') */ ;

alt_optional_auto_increment:
  | | | | | | AUTO_INCREMENT
;

alt_index:
    alt_index_or_key
  | alt_constraint_optional PRIMARY KEY
  | alt_constraint_optional UNIQUE alt_optional_index_or_key
;

alt_add_foreign_key:
  ADD alt_constraint_optional FOREIGN KEY alt_index_name_optional (alt_column_list) REFERENCES _basetable (alt_column_list) alt_optional_on_delete alt_optional_on_update
;

alt_add_check_constraint:
  ADD CONSTRAINT alt_index_name_optional CHECK (alt_check_constraint_expression)
;

alt_drop_check_constraint:
  /*!100200 DROP CONSTRAINT __if_exists(95) _letter */ /*!!100200 COMMENT 'Skipped DROP CONSTRAINT' */
;

# TODO: extend
alt_check_constraint_expression:
  alt_col_name alt_operator alt_col_name |
  alt_col_name alt_operator _digit
;

alt_operator:
  = | != | LIKE | NOT LIKE | < | <= | > | >=
;

alt_drop_foreign_key:
  DROP FOREIGN KEY __if_exists(95) _letter
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

alt_key_column_list:
  ==FACTOR:3== alt_col_name __asc_x_desc(10,20) |
  alt_col_name __asc_x_desc(10,20), alt_key_column_list
;

alt_any_key:
  ==FACTOR:4== alt_index(alt_col_name __asc_x_desc(10,20)) |
  ==FACTOR:2== alt_index(alt_key_column_list) |
  ==FACTOR:0.1== FULLTEXT KEY(alt_col_name) |
  ==FACTOR:0.0001== SPATIAL INDEX(alt_col_name)
;

alt_comment:
  COMMENT alt_eq_optional _english
;

