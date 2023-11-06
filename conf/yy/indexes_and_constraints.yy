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
     { _set_db('test') }
     long_blobs_init
  ;; long_blobs_init
  ;; long_blobs_init
  ;; long_blobs_init
  ;; long_blobs_init
;

query:
  { _set_db('NON-SYSTEM') } ind_constr_query ;

ind_constr_query:
    ==FACTOR:3==    alter | alter
  | ==FACTOR:4==    create_index_stmt | create_index_stmt | create_index_stmt
  |                 drop_index_stmt
  | ==FACTOR:0.01== long_blobs_runtime
;

alter:
  ALTER __online(10) __ignore(30) TABLE /*!100502 __if_exists(80) */ _table _basics_wait_nowait list_with_optional_order_by ;

create_index_stmt:
  CREATE __or_replace(80) unique INDEX ind_name ind_type_optional ON _table ( column_list ) _basics_wait_nowait option_list algorithm_opt lock_opt ;

# ALGORITHM and LOCK are not supported, despite being documented. MDEV-12572
drop_index_stmt:
  DROP INDEX __if_exists(80) ind_name ON _table _basics_wait_nowait ;

# Long blobs
long_blobs:
    CREATE OR REPLACE TABLE test.own_table (c _basics_char_column_type, f _basics_column_type, b _basics_blob_column_type, UNIQUE(b/*!!100403 (16)*/)) __ignore(90) AS SELECT;

long_blobs_runtime:
    long_blobs /* _table[invariant] */ _field AS c, _field AS f, _field AS b FROM _table[invariant] ;

long_blobs_init:
    long_blobs _basics_value_for_char_column AS c, _basics_any_value AS f, _basics_any_value AS b;

unique:
    | | | | UNIQUE ;

list_with_optional_order_by:
  list order_by
;

list:
  item_alg_lock | item_alg_lock | item_alg_lock, list
;

# Can't put it on the list, as ORDER BY should always go last
order_by:
  ==FACTOR:9== |
  , ORDER BY column_name_list ;

item_alg_lock:
  item algorithm_opt_comma lock_opt_comma
;

# Spatial indexes, fulltext indexes and foreign keys are in separate modules

item:
    add_index | add_index | add_index | add_index
  | add_index | add_index | add_index | add_index
  | add_pk | add_pk
  | add_unique | add_unique | add_unique
  | drop_index | drop_index | drop_index | drop_index
  | drop_pk
  | drop_constraint | drop_constraint
  | ==FACTOR:2== rename_index /* compatibility 10.5.2 */ 
  | enable_disable_keys
;

add_index:
  ADD index_word __if_not_exists(80) ind_name_optional ind_type_optional ( column_list ) option_list
;

drop_index:
  DROP index_word __if_exists(80) /* EXECUTOR_FLAG_NON_EXISTING_ALLOWED */ _index
;

rename_index:
  /* EXECUTOR_FLAG_NON_EXISTING_ALLOWED */ RENAME index_word __if_exists(80) _index TO ind_name
;

drop_constraint:
  DROP CONSTRAINT __if_exists(80) /* EXECUTOR_FLAG_NON_EXISTING_ALLOWED */  _index ;

add_pk:
  ADD constraint_word_optional PRIMARY KEY ind_type_optional ( column_list ) option_list
;

drop_pk:
  DROP PRIMARY KEY
;

enable_disable_keys:
  ENABLE KEYS | DISABLE KEYS
;

add_unique:
  ADD constraint_word_optional UNIQUE index_word_optional ind_name_optional ind_type_optional ( column_list ) option_list
;

ind_type_optional:
  | | USING ind_type
;

ind_type:
    BTREE | BTREE | BTREE | BTREE | BTREE | BTREE | BTREE | BTREE
# Disabled due to MDEV-371 issues
#  | HASH | HASH | HASH | HASH
  | RTREE
;

option_list:
  | | | | ind_option | ind_option | ind_option option_list
;

ind_option:
  KEY_BLOCK_SIZE = _smallint_unsigned | COMMENT _english | USING ind_type
;

index_word:
  INDEX | KEY
;

index_word_optional:
  | index_word
;

constraint_word_optional:
  | | | CONSTRAINT | CONSTRAINT _letter
;

column_item:
    ==FACTOR:3== _field __asc_x_desc(33,33)
  |              _field_char(_tinyint_unsigned) __asc_x_desc(33,33)
;

column_list:
    column_item | column_item | column_item
  | column_item, column_list
;

column_name_list:
  ==FACTOR:3== _field |
               _field, column_name_list
;

ind_name_optional:
  | ind_name | ind_name | ind_name
;

ind_name:
  ==FACTOR:5== { 'indcnstr'.$prng->uint16(1,20) } |
  _letter
;

algorithm_opt_comma:
  | | , ALGORITHM = __default_x_inplace_x_copy_x_nocopy_x_instant ;

algorithm_opt:
  | | | ALGORITHM = __default_x_inplace_x_copy_x_nocopy_x_instant ;

lock_opt_comma:
  | | , LOCK = __default_x_none_x_shared_x_exclusive ;

lock_opt:
  | | | LOCK = __default_x_none_x_shared_x_exclusive ;
