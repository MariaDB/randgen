query_add:
  atomic_drop |
  atomic_create |
  atomic_rename |
  alt_query |
  alttind_query |
  ia_query |
#  seq_query |
  ==FACTOR:0.05== xa_query |
  ==FACTOR:0.05== atomic_backup_stages
;

atomic_drop:
  DROP TABLE atomic_if_exists atomic_table_name_list |
  DROP TRIGGER atomic_if_exists atomic_trigger_name |
  DROP VIEW atomic_if_exists atomic_view_name_list |
  ==FACTOR:0.1== DROP DATABASE atomic_if_exists atomic_db_name
;

atomic_create:
  CREATE atomic_or_replace TRIGGER atomic_trigger_name atomic_before_after atomic_op ON atomic_table_name FOR EACH ROW UPDATE atomic_table_name SET _field = _field LIMIT 1 |
  CREATE atomic_or_replace atomic_temporary TABLE atomic_own_table_name LIKE atomic_table_name |
  CREATE atomic_temporary TABLE IF NOT EXISTS atomic_own_table_name LIKE atomic_table_name |
  CREATE atomic_or_replace atomic_temporary TABLE atomic_own_table_name AS SELECT * FROM atomic_table_name |
  CREATE atomic_temporary TABLE IF NOT EXISTS atomic_own_table_name AS SELECT * FROM atomic_table_name |
  CREATE atomic_or_replace VIEW atomic_own_view_name AS SELECT * FROM atomic_table_name |
  ==FACTOR:0.1== CREATE atomic_or_replace DATABASE atomic_db_name |
;

atomic_rename:
  RENAME TABLE atomic_rename_list |
  ALTER TABLE atomic_own_table_name RENAME TO atomic_own_table_name
;

atomic_if_exists:
  | IF EXISTS ;

atomic_or_replace:
  | OR REPLACE ;

atomic_trigger_name:
  { 'trg'.$prng->int(1,20) } ;

atomic_db_name:
  { 'db'.$prng->int(1,6) } ;

atomic_before_after:
  BEFORE | AFTER ;

atomic_op:
  INSERT | UPDATE | DELETE ;

atomic_table_name:
  _table | atomic_own_table_name | atomic_own_view_name ;

atomic_table_name_list:
  atomic_table_name |
  atomic_table_name, atomic_table_name_list ;

atomic_temporary:
  |
  ==FACTOR:0.1== TEMPORARY ;

atomic_own_table_name:
  { 'tt'.$prng->int(1,20) } ;

atomic_own_view_name:
  { 'vv'.$prng->int(1,20) } ;

atomic_view_name:
  _view |
  ==FACTOR:3== atomic_own_view_name ;

atomic_rename_list:
  atomic_table_name TO atomic_table_name | atomic_table_name TO atomic_table_name, atomic_rename_list ;

atomic_view_name_list:
  atomic_view_name | atomic_view_name, atomic_view_name_list ;

alt_query:
    alt_create
  | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter
  | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter
  | alt_rename_multi
#  | alt_alter_partitioning
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
    DROP TABLE IF EXISTS { $tmp_tbl= 'tmp_rename_'.abs($$) } ; RENAME TABLE alt_own_table_name TO $tmp_tbl, $tmp_tbl TO { $my_last_table }
;

alt_dml:
    alt_insert | alt_insert | alt_insert | alt_insert | alt_insert | alt_insert | alt_insert | alt_insert | alt_insert | alt_insert | alt_insert
  | alt_update | alt_update
  | alt_delete | alt_truncate
;

alt_alter:
  ALTER alt_online_optional alt_ignore_optional TABLE alt_table_name alt_wait_optional alt_alter_list_with_optional_order_by
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

alt_alter_list_with_optional_order_by:
  alt_alter_list alt_optional_order_by
;

alt_alter_list:
  alt_alter_item | alt_alter_item | alt_alter_item, alt_alter_list
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
  | RENAME TO alt_own_table_name
;

# Can't put it on the list, as ORDER BY should always go last
alt_optional_order_by:
  | | | | | | | | | | , ORDER BY alt_column_list ;

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
  InnoDB | InnoDB | InnoDB | InnoDB | MyISAM | MyISAM | Aria | Aria | Memory | RocksDB | Unknown
;

alt_default_optional:
  | | DEFAULT
;

alt_storage_optional:
# Disabled due to MDEV-14860
#  | | STORAGE
;


alt_transaction:
    START TRANSACTION
  | SAVEPOINT sp
  | ROLLBACK TO SAVEPOINT sp
  | COMMIT
  | ROLLBACK
;

alt_lock_unlock_table:
    FLUSH TABLE alt_table_name FOR EXPORT
  | LOCK TABLE alt_table_name READ
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
    _table { $my_last_table = $last_table; '' }
  | alt_own_table_name
  | atomic_own_table_name
;

alt_own_table_name:
    { $my_last_table = 'alt_t'.$prng->int(1,10) }
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
    alt_bit_col_name alt_bit_type alt_null alt_default_optional_int_or_auto_increment alt_invisible_optional alt_check_optional alt_col_versioning_optional
  | alt_int_col_name alt_int_type alt_unsigned alt_zerofill alt_null alt_default_optional_int_or_auto_increment alt_invisible_optional alt_check_optional alt_col_versioning_optional
  | alt_int_col_name alt_int_type alt_unsigned alt_zerofill alt_null alt_default_optional_int_or_auto_increment alt_invisible_optional alt_check_optional alt_col_versioning_optional
  | alt_int_col_name alt_int_type alt_unsigned alt_zerofill alt_null alt_default_optional_int_or_auto_increment alt_invisible_optional alt_check_optional alt_col_versioning_optional
  | alt_num_col_name alt_num_type alt_unsigned alt_zerofill alt_null alt_optional_default alt_invisible_optional alt_check_optional alt_col_versioning_optional
  | alt_temporal_col_name alt_temporal_type alt_null alt_optional_default alt_invisible_optional alt_check_optional alt_col_versioning_optional
  | alt_timestamp_col_name alt_timestamp_type alt_null alt_optional_default_or_current_timestamp alt_invisible_optional alt_check_optional alt_col_versioning_optional
  | alt_text_col_name alt_text_type alt_null alt_optional_default_char alt_invisible_optional alt_check_optional alt_col_versioning_optional
  | alt_text_col_name alt_text_type alt_null alt_optional_default_char alt_invisible_optional alt_check_optional alt_col_versioning_optional
  | alt_text_col_name alt_text_type alt_null alt_optional_default_char alt_invisible_optional alt_check_optional alt_col_versioning_optional
  | alt_enum_col_name alt_enum_type alt_null alt_optional_default alt_invisible_optional alt_check_optional alt_col_versioning_optional
  | alt_virt_col_name alt_virt_col_definition alt_virt_type alt_invisible_optional alt_check_optional alt_col_versioning_optional
  | alt_geo_col_name alt_geo_type alt_null alt_geo_optional_default alt_invisible_optional alt_check_optional alt_col_versioning_optional
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
  CREATE OR REPLACE alt_temporary TABLE alt_own_table_name (alt_col_name_and_definition_list) alt_table_flags
;

alt_create_or_replace_sequence:
  /* compatibility 10.3.3 */ CREATE OR REPLACE SEQUENCE alt_own_table_name
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
  CREATE alt_temporary TABLE alt_own_table_name LIKE _table
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

alt_alter_column:
    ALTER COLUMN /*!100305 alt_if_exists */ alt_col_name SET DEFAULT alt_default_val
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

alt_temporary:
  | | | | TEMPORARY
;

alt_flush:
  FLUSH TABLES
;

alt_optimize:
  OPTIMIZE TABLE alt_table_name
;

alt_algorithm:
  | | , ALGORITHM=INPLACE | , ALGORITHM=COPY | , ALGORITHM=DEFAULT | /*!100307 , ALGORITHM=NOCOPY */ | /*!100307 , ALGORITHM=INSTANT */
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
  | /*!100201 DEFAULT ST_GEOMFROMTEXT('Point(1 1)') */ ;

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
  /*!100200 DROP CONSTRAINT alt_if_exists _letter */ /*!!100200 COMMENT 'Skipped DROP CONSTRAINT' */
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
  COMMENT alt_eq_optional _english
;

alt_compressed:
  | | | | | | COMPRESSED ;

_alt_value:
  NULL | _digit | '' | _char(1)
;

alttind_query:
  ALTER alttind_online alttind_ignore TABLE _table /*!100301 alttind_wait */ alttind_list_with_optional_order_by
;

alttind_online:
  | | | ONLINE
;

alttind_ignore:
  | | IGNORE
;

alttind_wait:
  | | | WAIT _digit | NOWAIT
;

alttind_list_with_optional_order_by:
  alttind_list alttind_order_by
;

alttind_list:
  alttind_item_alg_lock | alttind_item_alg_lock | alttind_item_alg_lock, alttind_list
;

# Can't put it on the list, as ORDER BY should always go last
alttind_order_by:
  | | | | | | | | | | , ORDER BY alttind_column_name_list ;

alttind_item_alg_lock:
  alttind_item alttind_algorithm alttind_lock
;

# Spatial indexes, fulltext indexes and foreign keys are in separate modules

alttind_item:
    alttind_add_index | alttind_add_index | alttind_add_index | alttind_add_index
  | alttind_add_index | alttind_add_index | alttind_add_index | alttind_add_index
  | alttind_add_pk | alttind_add_pk
  | alttind_add_unique | alttind_add_unique | alttind_add_unique
  | alttind_drop_index | alttind_drop_index | alttind_drop_index | alttind_drop_index
  | alttind_drop_pk
  | alttind_drop_constraint | alttind_drop_constraint
  | alttind_rename_index | alttind_rename_index | alttind_rename_index
  | alttind_rename_index | alttind_rename_index | alttind_rename_index
  | alttind_enable_disable_keys
;

alttind_add_index:
  ADD alttind_index_word alttind_if_not_exists alttind_ind_name_optional alttind_ind_type_optional ( alttind_column_list ) alttind_option_list
;

alttind_drop_index:
  DROP alttind_index_word alttind_if_exists alttind_ind_name_or_col_name
;

alttind_rename_index:
  /* compatibility 10.5.2 */ RENAME alttind_index_word alttind_if_exists alttind_ind_name_or_col_name TO alttind_ind_name_or_col_name
;

alttind_drop_constraint:
  DROP CONSTRAINT alttind_if_exists alttind_ind_name_or_col_name
;

alttind_add_pk:
  ADD alttind_constraint_word_optional PRIMARY KEY alttind_ind_type_optional ( alttind_column_list ) alttind_option_list
;

alttind_drop_pk:
  DROP PRIMARY KEY
;

alttind_enable_disable_keys:
  ENABLE KEYS | DISABLE KEYS
;

alttind_add_unique:
  ADD alttind_constraint_word_optional UNIQUE alttind_index_word_optional alttind_ind_name_optional alttind_ind_type_optional ( alttind_column_list ) alttind_option_list
;

alttind_ind_name_or_col_name:
  alttind_ind_name | alttind_ind_name | alttind_ind_name | _field
;

alttind_ind_type_optional:
  | | USING alttind_ind_type
;

alttind_ind_type:
    BTREE | BTREE | BTREE | BTREE | BTREE | BTREE | BTREE | BTREE
  | HASH | HASH | HASH | HASH
  | RTREE
;

alttind_option_list:
  | | | | alttind_ind_option | alttind_ind_option | alttind_ind_option alttind_option_list
;

alttind_ind_option:
  KEY_BLOCK_SIZE = _smallint_unsigned | COMMENT _english
;

alttind_column_name:
  _field | _letter
;

alttind_index_word:
  INDEX | KEY
;

alttind_index_word_optional:
  | alttind_index_word
;

alttind_constraint_word_optional:
  | | | CONSTRAINT | CONSTRAINT _letter
;

alttind_column_item:
    alttind_column_name alttind_asc_desc_optional
  | alttind_column_name alttind_asc_desc_optional
  | alttind_column_name(_tinyint_unsigned) alttind_asc_desc_optional
;

alttind_asc_desc_optional:
  | | | | | ASC | DESC
;

alttind_column_list:
    alttind_column_item | alttind_column_item | alttind_column_item
  | alttind_column_item, alttind_column_list
;

alttind_column_name_list:
    alttind_column_name | alttind_column_name | alttind_column_name
  | alttind_column_name, alttind_column_name_list
;

alttind_if_not_exists:
  | IF NOT EXISTS | IF NOT EXISTS | IF NOT EXISTS | IF NOT EXISTS
;

alttind_if_exists:
  | IF EXISTS | IF EXISTS | IF EXISTS | IF EXISTS
;

alttind_ind_name_optional:
  | alttind_ind_name | alttind_ind_name | alttind_ind_name
;

alttind_ind_name:
  { 'ind'.$prng->int(1,9) } | _letter
;

alttind_algorithm:
  | | | | , ALGORITHM=DEFAULT | , ALGORITHM=INPLACE | , ALGORITHM=COPY | /*!100307 , ALGORITHM=NOCOPY */ | /*!100307 , ALGORITHM=INSTANT */
;

alttind_lock:
  | | | | , LOCK=DEFAULT | , LOCK=NONE | , LOCK=SHARED | , LOCK=EXCLUSIVE
;

atomic_backup_stages:
  BACKUP STAGE START
  ; SELECT SLEEP({int(1/$prng->uint16(1,100))})
  ; BACKUP STAGE FLUSH
  ; SELECT SLEEP({int(1/$prng->uint16(1,100))})
  ; BACKUP STAGE BLOCK_DDL
  ; SELECT SLEEP({int(1/$prng->uint16(1,100))})
  ; BACKUP STAGE BLOCK_COMMIT
  ; SELECT SLEEP({int(1/$prng->uint16(1,100))})
  ; BACKUP STAGE END
;

ia_query:
    ia_create_or_replace
  | ia_create_like
  | ia_truncate
  | ia_alter | ia_alter | ia_alter | ia_alter | ia_alter | ia_alter | ia_alter | ia_alter | ia_alter
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
  | ia_change_row_format
  | FORCE ia_lock ia_algorithm
  | ENGINE=InnoDB
;

ia_transaction:
    START TRANSACTION
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
# TODO: re-enable when virtual columns start working
#  | ia_virt_col_name
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
# TODO: vcols: re-enable when virtual columns start working
#  | ia_virt_col_name ia_virt_col_definition ia_virt_type
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
  | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
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

# MDEV-14694 - only fixed in 10.3.5 - ALTER COLUMN does not accept IF EXISTS
ia_alter_column:
    ALTER COLUMN /*!100305 ia_if_exists */ ia_col_name SET DEFAULT ia_default_val
  | ALTER COLUMN /*!100305 ia_if_exists */ ia_col_name DROP DEFAULT
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

xa_query:
  ==FACTOR:10== xa_valid_sequence
#  | xa_random
;

xa_valid_sequence:
  xa_begin ; xa_opt_recover xa_query_sequence ; xa_opt_recover XA END { $last_xid } ; xa_opt_recover XA PREPARE { $last_xid } ; xa_opt_recover XA COMMIT { $last_xid } |
  xa_begin ; xa_opt_recover xa_query_sequence ; xa_opt_recover XA END { $last_xid } ; xa_opt_recover XA COMMIT { $last_xid } ONE PHASE |
  xa_begin ; xa_opt_recover xa_query_sequence ; xa_opt_recover XA END { $last_xid } ; xa_opt_recover XA PREPARE { $last_xid } ; xa_opt_recover XA ROLLBACK { $last_xid }
;

xa_opt_recover:
  { $prng->uint16(0,3) ? 'XA RECOVER ;' : '' };

xa_random:
    xa_begin
  | xa_end
  | xa_prepare
  | xa_commit_one_phase
  | xa_commit
  | xa_rollback
  | XA RECOVER
;

xa_query_sequence:
  ==FACTOR:2== query
  | xa_query_sequence ; query
;

xa_begin:
  XA xa_start_begin xa_xid xa_opt_join_resume { $active_xa{$last_xid}= 1 ; '' } ;

xa_end:
  XA END xa_xid_active xa_opt_suspend_opt_for_migrate { $idle_xa{$last_xid}= 1; delete $active_xa{$last_xid}; '' } ;

xa_prepare:
  XA PREPARE xa_xid_idle { $prepared_xa{$last_xid}= 1; delete $idle_xa{$last_xid}; '' } ;

xa_commit:
  XA COMMIT xa_xid_prepared { delete $idle_xa{$last_xid}; '' } ;

xa_commit_one_phase:
  XA COMMIT xa_xid_idle ONE PHASE { delete $idle_xa{$last_xid}; '' } ;

xa_rollback:
  XA ROLLBACK xa_xid_prepared { delete $prepared_xa{$last_xid}; '' } ;

# Not supported
xa_opt_suspend_opt_for_migrate:
#  | SUSPEND xa_opt_for_migrade
;

xa_opt_for_migrade:
  | FOR MIGRATE
;

xa_start_begin:
  START | BEGIN
;

# Not supported
xa_opt_join_resume:
#  | JOIN | RESUME
;

xa_xid:
  { $last_xid= "'xid".$prng->int(1,200)."'" }
;

xa_xid_active:
  { $last_xid= (scalar(keys %active_xa) ? $prng->arrayElement([keys %active_xa]) : "'inactive_xid'"); $last_xid }
;

xa_xid_idle:
  { $last_xid= (scalar(keys %idle_xa) ? $prng->arrayElement([keys %idle_xa]) : "'non_idle_xid'"); $last_xid }
;

xa_xid_prepared:
  { $last_xid= (scalar(keys %prepared_xa) ? $prng->arrayElement([keys %prepared_xa]) : "'non_prepared_xid'"); $last_xid }
;

seq_query:
    seq_create
  | seq_show
  | seq_next_val
  | seq_prev_val
  | seq_alter
  | seq_set_val
  | seq_drop
  | seq_select
  | seq_lock_unlock
  | seq_rename
  | seq_insert
;

seq_lock_unlock:
    LOCK TABLE seq_lock_list
  | UNLOCK TABLES
  | UNLOCK TABLES
  | UNLOCK TABLES
;

seq_rename:
  RENAME TABLE seq_rename_list
;

seq_rename_list:
  seq_name TO seq_name | seq_rename_list, seq_name TO seq_name
;

seq_lock_list:
  seq_name seq_lock_type | seq_lock_list, seq_name seq_lock_type
;

seq_lock_type:
  READ | WRITE
;

seq_select:
  SELECT seq_select_list FROM seq_name
;

seq_select_list:
  * | seq_select_field_list
;

seq_select_field_list:
    seq_field
  | seq_field, seq_select_field_list
  | seq_field, seq_select_field_list
;

seq_field:
    NEXT_NOT_CACHED_VALUE
  | MINIMUM_VALUE
  | MAXIMUM_VALUE
  | START_VALUE
  | INCREMENT
  | CACHE_SIZE
  | CYCLE_OPTION
  | CYCLE_COUNT
;

seq_drop:
  DROP seq_temporary SEQUENCE seq_if_exists_optional seq_drop_list
;

seq_drop_list:
  seq_name | seq_name | seq_name, seq_drop_list
;

seq_temporary:
  | | | TEMPORARY
;

seq_set_val:
  SELECT SETVAL(seq_name, seq_start_value)
;

seq_alter:
  ALTER SEQUENCE seq_if_exists_optional seq_name seq_alter_list
;

seq_if_exists_optional:
  | IF EXISTS | IF EXISTS | IF EXISTS
;

seq_alter_list:
  seq_alter_element | seq_alter_element seq_alter_list
;

seq_insert:
  INSERT INTO seq_name VALUES (seq_start_value, seq_start_value, seq_end_value, seq_start_value, seq_increment_value, _tinyint_unsigned, seq_zero_or_one, seq_zero_or_one)
;

seq_alter_element:
    RESTART seq_with_or_equal_optional seq_start_value
  | seq_increment
  | seq_min
  | seq_max
  | seq_start_with
;

seq_zero_or_one:
  0 | 1
;

seq_next_val:
    SELECT NEXT VALUE FOR seq_name
  | SELECT NEXTVAL( seq_name )
  | SET STATEMENT `sql_mode`=ORACLE FOR SELECT seq_name.nextval
;

seq_prev_val:
    SELECT PREVIOUS VALUE FOR seq_name
  | SELECT LASTVAL( seq_name )
  | SET STATEMENT `sql_mode`=ORACLE FOR SELECT seq_name.currval
;

seq_create:
  CREATE seq_or_replace_if_not_exists seq_name seq_start_with_optional seq_min_optional seq_max_optional seq_increment_optional seq_cache_optional seq_cycle_optional seq_engine_optional
;

seq_cache:
    CACHE _tinyint_unsigned
  | CACHE = _tinyint_unsigned
;

seq_cache_optional:
  | | | seq_cache
;

seq_cycle:
  NOCYCLE | CYCLE
;

seq_cycle_optional:
  | | | seq_cycle
;

seq_engine:
  ENGINE=InnoDB | ENGINE=MyISAM | ENGINE=Aria
;

seq_engine_optional:
  | | | seq_engine
;

seq_min:
    MINVALUE = seq_start_value
  | MINVALUE seq_start_value
  | NO MINVALUE
  | NOMINVALUE
;

seq_min_optional:
  | | seq_min
;

seq_max:
    MAXVALUE = seq_end_value
  | MAXVALUE seq_end_value
  | NO MAXVALUE
  | NOMAXVALUE
;

seq_max_optional:
  | | seq_max
;

seq_show:
    SHOW CREATE SEQUENCE seq_name
  | SHOW CREATE TABLE seq_name
  | SHOW TABLES
;

seq_or_replace_if_not_exists:
  seq_temporary SEQUENCE | OR REPLACE seq_temporary SEQUENCE | seq_temporary SEQUENCE IF NOT EXISTS
;

seq_name:
  { 'seq'.$prng->int(1,10) }
;

seq_or_table_name:
    seq_name | seq_name | seq_name | seq_name | seq_name | seq_name
  | _table
;

seq_start_with:
    START seq_start_value
  | START seq_with_or_equal_optional seq_start_value
  | START seq_with_or_equal_optional seq_start_value
;

seq_with_or_equal_optional:
  | WITH | =
;

seq_start_with_optional:
  | | | seq_start_with
;

seq_start_value:
  0 | _tinyint | _smallint_unsigned | _bigint
;

seq_end_value:
  0 | _smallint_unsigned | _int_unsigned | _bigint
;

seq_increment:
    INCREMENT BY seq_increment_value
  | INCREMENT = seq_increment_value
  | INCREMENT seq_increment_value
;

seq_increment_optional:
  | | | seq_increment
;

seq_increment_value:
  _positive_digit | _positive_digit | _positive_digit | _tinyint
;
