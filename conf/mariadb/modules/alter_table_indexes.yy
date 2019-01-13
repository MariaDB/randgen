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


query_add:
  query | query | query | alttind_query
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
# Disabled due to MDEV-17725
#  | | | | | | | | | | , ORDER BY alttind_column_list
;

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
  | alttind_enable_disable_keys
;

alttind_add_index:
  ADD alttind_index_word alttind_if_not_exists alttind_ind_name_optional alttind_ind_type_optional ( alttind_column_list ) alttind_option_list
;

alttind_drop_index:
  DROP alttind_index_word alttind_if_exists alttind_ind_name_or_col_name
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
    alttind_column_item| alttind_column_item | alttind_column_item 
  | alttind_column_item, alttind_column_list
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
  
