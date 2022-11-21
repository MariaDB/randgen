#  Copyright (c) 2019, 2022, MariaDB Corporation Ab
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

#include <conf/basics.rr>


query_init:
  { $indnum=0; $executors->[0]->setMetadataReloadInterval(20 + $generator->threadId()); '' } ;

query:
  ==FACTOR:0.1== ind_constr_query ;

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
  ALTER __online(10) __ignore(30) TABLE /*!100502 __if_exists(80) */ ind_constr_table _basics_wait_nowait ind_constr_list_with_optional_order_by ;

ind_constr_create_index_stmt:
  CREATE __or_replace(80) ind_constr_unique INDEX ind_constr_ind_name ind_constr_ind_type_optional ON ind_constr_table ( ind_constr_column_list ) _basics_wait_nowait ind_constr_option_list ind_constr_algorithm_opt ind_constr_lock_opt ;

# ALGORITHM and LOCK are not supported, despite being documented. MDEV-12572
ind_constr_drop_index_stmt:
  DROP INDEX __if_exists(80) ind_constr_ind_name ON ind_constr_table _basics_wait_nowait ;

# Long blobs
ind_constr_long_blobs:
    /* compatibility 10.4.3 */ CREATE OR REPLACE TABLE ind_constr_own_table (f _basics_column_type, b _basics_blob_column_type, UNIQUE(b)) ind_constr_replace_ignore AS SELECT /* _table */ _field, _field FROM _table ;

ind_constr_unique:
    | | | | UNIQUE ;

ind_constr_replace_ignore:
  __ignore(80) | __replace(80) ;

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
  ADD ind_constr_index_word __if_not_exists(80) ind_constr_ind_name_optional ind_constr_ind_type_optional ( ind_constr_column_list ) ind_constr_option_list
;

ind_constr_drop_index:
  DROP ind_constr_index_word __if_exists(80) ind_constr_ind_name_or_col_name
;

ind_constr_rename_index:
  /* compatibility 10.5.2 */ RENAME ind_constr_index_word __if_exists(80) ind_constr_ind_name_or_col_name TO ind_constr_ind_name_or_col_name
;

ind_constr_drop_constraint:
  DROP CONSTRAINT __if_exists(80) ind_constr_ind_name_or_col_name
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
# Disabled due to MDEV-371 issues
#  | HASH | HASH | HASH | HASH
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
    ind_constr_column_name __asc_x_desc(33,33)
  | ind_constr_column_name __asc_x_desc(33,33)
  | ind_constr_column_name __asc_x_desc(33,33)
  | ind_constr_column_name(_tinyint_unsigned) __asc_x_desc(33,33)
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
  | | , ALGORITHM = __default_x_inplace_x_copy_x_nocopy_x_instant ;

ind_constr_algorithm_opt:
  | | | ALGORITHM = __default_x_inplace_x_copy_x_nocopy_x_instant ;

ind_constr_lock_opt_comma:
  | | , LOCK = __default_x_none_x_shared_x_exclusive ;
  
ind_constr_lock_opt:
  | | | LOCK = __default_x_none_x_shared_x_exclusive ;
