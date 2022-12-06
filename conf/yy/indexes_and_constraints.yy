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

#include <conf/yy/include/basics.inc>
#features GIS columns
### GIS is included via the use of _basics_column_type


query_init:
  CREATE DATABASE IF NOT EXISTS test
  ;; ind_constr_long_blobs_init
  ;; ind_constr_long_blobs_init
  ;; ind_constr_long_blobs_init
  ;; ind_constr_long_blobs_init
  ;; ind_constr_long_blobs_init
;

query:
  { _set_db('user') } ind_constr_query ;

ind_constr_own_table:
  { 'ind_constr_t'.$prng->uint16(1,5) } ;

ind_constr_query:
    ==FACTOR:3==    ind_constr_alter | ind_constr_alter
  | ==FACTOR:4==    ind_constr_create_index_stmt | ind_constr_create_index_stmt | ind_constr_create_index_stmt
  |                 ind_constr_drop_index_stmt
  | ==FACTOR:0.01== ind_constr_long_blobs_runtime
;

ind_constr_alter:
  ALTER __online(10) __ignore(30) TABLE /*!100502 __if_exists(80) */ _table _basics_wait_nowait ind_constr_list_with_optional_order_by ;

ind_constr_create_index_stmt:
  CREATE __or_replace(80) ind_constr_unique INDEX ind_constr_ind_name ind_constr_ind_type_optional ON _table ( ind_constr_column_list ) _basics_wait_nowait ind_constr_option_list ind_constr_algorithm_opt ind_constr_lock_opt ;

# ALGORITHM and LOCK are not supported, despite being documented. MDEV-12572
ind_constr_drop_index_stmt:
  DROP INDEX __if_exists(80) ind_constr_ind_name ON _table _basics_wait_nowait ;

# Long blobs
ind_constr_long_blobs:
    CREATE OR REPLACE TABLE test.ind_constr_own_table (c _basics_char_column_type, f _basics_column_type, b _basics_blob_column_type, UNIQUE(b/*!!100403 (16)*/)) __ignore(90) AS SELECT;

ind_constr_long_blobs_runtime:
    ind_constr_long_blobs /* _table */ _field AS c, _field AS f, _field AS b FROM { $last_table } ;

ind_constr_long_blobs_init:
    ind_constr_long_blobs _basics_value_for_char_column AS c, _basics_any_value AS f, _basics_any_value AS b;

ind_constr_unique:
    | | | | UNIQUE ;

ind_constr_list_with_optional_order_by:
  ind_constr_list ind_constr_order_by
;

ind_constr_list:
  ind_constr_item_alg_lock | ind_constr_item_alg_lock | ind_constr_item_alg_lock, ind_constr_list
;

# Can't put it on the list, as ORDER BY should always go last
ind_constr_order_by:
  ==FACTOR:9== |
  , ORDER BY ind_constr_column_name_list ;

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
  DROP ind_constr_index_word __if_exists(80) _index
;

ind_constr_rename_index:
  /* compatibility 10.5.2 */ RENAME ind_constr_index_word __if_exists(80) _index TO ind_constr_ind_name
;

ind_constr_drop_constraint:
  DROP CONSTRAINT __if_exists(80) _index
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
    ==FACTOR:3== _field __asc_x_desc(33,33)
  |              _field_char(_tinyint_unsigned) __asc_x_desc(33,33)
;

ind_constr_column_list:
    ind_constr_column_item | ind_constr_column_item | ind_constr_column_item
  | ind_constr_column_item, ind_constr_column_list
;

ind_constr_column_name_list:
  ==FACTOR:3== _field |
               _field, ind_constr_column_name_list
;

ind_constr_ind_name_optional:
  | ind_constr_ind_name | ind_constr_ind_name | ind_constr_ind_name
;

ind_constr_ind_name:
  ==FACTOR:5== { 'indcnstr'.$prng->uint16(1,20) } |
  _letter
;

ind_constr_algorithm_opt_comma:
  | | , ALGORITHM = __default_x_inplace_x_copy_x_nocopy_x_instant ;

ind_constr_algorithm_opt:
  | | | ALGORITHM = __default_x_inplace_x_copy_x_nocopy_x_instant ;

ind_constr_lock_opt_comma:
  | | , LOCK = __default_x_none_x_shared_x_exclusive ;

ind_constr_lock_opt:
  | | | LOCK = __default_x_none_x_shared_x_exclusive ;
