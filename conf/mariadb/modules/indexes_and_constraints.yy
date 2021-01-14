#  Copyright (c) 2019, 2021, MariaDB Corporation Ab
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


query_add:
  ind_constr_query ;

ind_constr_own_table:
  { 'ind_constr_t'.$prng->int(1,5) } ;

ind_constr_table:
  ind_constr_own_table | _table ;

ind_constr_query:
    ind_constr_alter | ind_constr_alter | ind_constr_alter
  | ind_constr_create_index_stmt | ind_constr_create_index_stmt | ind_constr_create_index_stmt
  | ind_constr_drop_index_stmt
  | ind_constr_long_blobs
;

ind_constr_alter:
  ALTER _basics_online_10pct _basics_ignore_33pct TABLE /*!100502 _basics_if_exists_80pct */ ind_constr_table /*!100301 _basics_wait_nowait_40pct */ ind_constr_list_with_optional_order_by ;

ind_constr_create_index_stmt:
  CREATE _basics_or_replace_80pct ind_constr_unique INDEX ind_constr_ind_name ind_constr_ind_type_optional ON ind_constr_table ( ind_constr_column_list ) /*!100301 _basics_wait_nowait_40pct */ ind_constr_option_list ind_constr_algorithm_opt ind_constr_lock_opt ;

# ALGORITHM and LOCK are not supported, despite being documented. MDEV-12572
ind_constr_drop_index_stmt:
  DROP INDEX _basics_if_exists_80pct ind_constr_ind_name ON ind_constr_table /*!100301 _basics_wait_nowait_40pct */ ;

# Long blobs
ind_constr_long_blobs:
    /* compatibility 10.4.3 */ CREATE OR REPLACE TABLE ind_constr_own_table (f _basics_column_type, b _basics_blob_column_type, UNIQUE(b)) ind_constr_replace_ignore AS SELECT /* _table */ _field, _field FROM _table ;

ind_constr_unique:
    | | | | UNIQUE ;

ind_constr_replace_ignore:
  _basics_ignore_80pct | _basics_replace_80pct ;

ind_constr_list_with_optional_order_by:
  ind_constr_list ind_constr_order_by
;

ind_constr_list:
  ind_constr_item_alg_lock | ind_constr_item_alg_lock | ind_constr_item_alg_lock, ind_constr_list
;

# Can't put it on the list, as ORDER BY should always go last
ind_constr_order_by:
  | | | | | | | | | | , ORDER BY ind_constr_column_name_list ;

ind_constr_item_alg_lock:
  ind_constr_item ind_constr_algorithm_opt_comma ind_constr_lock_opt_comma
;

# Spatial indexes, fulltext indexes and foreign keys are in separate modules

ind_constr_item:
    ind_constr_add_index | ind_constr_add_index | ind_constr_add_index | ind_constr_add_index
  | ind_constr_add_index | ind_constr_add_index | ind_constr_add_index | ind_constr_add_index
  | ind_constr_add_pk | ind_constr_add_pk 
  | ind_constr_add_unique | ind_constr_add_unique | ind_constr_add_unique
  | ind_constr_drop_index | ind_constr_drop_index | ind_constr_drop_index | ind_constr_drop_index
  | ind_constr_drop_pk
  | ind_constr_drop_constraint | ind_constr_drop_constraint
  | ind_constr_rename_index | ind_constr_rename_index | ind_constr_rename_index
  | ind_constr_rename_index | ind_constr_rename_index | ind_constr_rename_index
  | ind_constr_enable_disable_keys
;

ind_constr_add_index:
  ADD ind_constr_index_word _basics_if_not_exists_80pct ind_constr_ind_name_optional ind_constr_ind_type_optional ( ind_constr_column_list ) ind_constr_option_list
;

ind_constr_drop_index:
  DROP ind_constr_index_word _basics_if_exists_80pct ind_constr_ind_name_or_col_name
;

ind_constr_rename_index:
  /* compatibility 10.5.2 */ RENAME ind_constr_index_word _basics_if_exists_80pct ind_constr_ind_name_or_col_name TO ind_constr_ind_name_or_col_name
;

ind_constr_drop_constraint:
  DROP CONSTRAINT _basics_if_exists_80pct ind_constr_ind_name_or_col_name
;

ind_constr_add_pk:
  ADD ind_constr_constraint_word_optional PRIMARY KEY ind_constr_ind_type_optional ( ind_constr_column_list ) ind_constr_option_list
;

ind_constr_drop_pk:
  DROP PRIMARY KEY
;

ind_constr_enable_disable_keys:
  ENABLE KEYS | DISABLE KEYS
;

ind_constr_add_unique:
  ADD ind_constr_constraint_word_optional UNIQUE ind_constr_index_word_optional ind_constr_ind_name_optional ind_constr_ind_type_optional ( ind_constr_column_list ) ind_constr_option_list
;

ind_constr_ind_name_or_col_name:
  ind_constr_ind_name | ind_constr_ind_name | ind_constr_ind_name | _field
;

ind_constr_ind_type_optional:
  | | USING ind_constr_ind_type
;

ind_constr_ind_type:
    BTREE | BTREE | BTREE | BTREE | BTREE | BTREE | BTREE | BTREE
  | HASH | HASH | HASH | HASH
  | RTREE
;

ind_constr_option_list:
  | | | | ind_constr_ind_option | ind_constr_ind_option | ind_constr_ind_option ind_constr_option_list
;

ind_constr_ind_option:
  KEY_BLOCK_SIZE = _smallint_unsigned | COMMENT _english | USING ind_constr_ind_type
;

ind_constr_column_name:
  _field | _letter
;

ind_constr_index_word:
  INDEX | KEY
;

ind_constr_index_word_optional:
  | ind_constr_index_word
;

ind_constr_constraint_word_optional:
  | | | CONSTRAINT | CONSTRAINT _letter
;

ind_constr_column_item:
    ind_constr_column_name ind_constr_asc_desc_optional
  | ind_constr_column_name ind_constr_asc_desc_optional 
  | ind_constr_column_name ind_constr_asc_desc_optional 
  | ind_constr_column_name(_tinyint_unsigned) ind_constr_asc_desc_optional
;

ind_constr_asc_desc_optional:
  | | | | | ASC | DESC
;
 
ind_constr_column_list:
    ind_constr_column_item | ind_constr_column_item | ind_constr_column_item 
  | ind_constr_column_item, ind_constr_column_list
;

ind_constr_column_name_list:
    ind_constr_column_name | ind_constr_column_name | ind_constr_column_name
  | ind_constr_column_name, ind_constr_column_name_list
;

ind_constr_ind_name_optional:
  | ind_constr_ind_name | ind_constr_ind_name | ind_constr_ind_name
;

ind_constr_ind_name:
  { 'ind'.$prng->int(1,9) } | _letter
;

ind_constr_algorithm_opt_comma:
  | | , _basics_alter_table_algorithm ;

ind_constr_algorithm_opt:
  | | | _basics_alter_table_algorithm ;

ind_constr_lock_opt_comma:
  | | , _basics_alter_table_lock ;
  
ind_constr_lock_opt:
  | | | _basics_alter_table_lock ;
