#  Copyright (c) 2019, 2022, MariaDB Corporation
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

#include <conf/rr/basics.rr>

query_init:
  { $indnum=0; $executors->[0]->setMetadataReloadInterval(20 + $generator->threadId()); '' } ;

query:
  ==FACTOR:0.1== alttind_query ;

alttind_query:
  ==FACTOR:10==  ALTER __online(20) __ignore(20) TABLE _basetable _basics_wait_nowait alttind_list_with_optional_order_by |
                 CREATE __or_replace(95) __unique(20) INDEX alttind_ind_new_name alttind_ind_type_optional ON _basetable ( alttind_column_name_list ) _basics_wait_nowait alttind_option_list alttind_algorithm_optional alttind_lock_optional |
  ==FACTOR:2==   DROP INDEX __if_exists(95)  /* _basetable */ _index ON { $last_table } _basics_wait_nowait
;

alttind_list_with_optional_order_by:
  alttind_list alttind_order_by
;

alttind_list:
  ==FACTOR:3== alttind_item |
  alttind_item, alttind_list
;

# Can't put it on the list, as ORDER BY should always go last
alttind_order_by:
  | | | | | | | | | | , ORDER BY alttind_column_name_list ;

# Spatial indexes, fulltext indexes and foreign keys are in separate modules

alttind_item:
  ==FACTOR:2==   alttind_add_index |
                 alttind_add_pk |
  ==FACTOR:2==   alttind_add_unique |
  ==FACTOR:8==   alttind_drop_index |
                 alttind_drop_pk |
  ==FACTOR:6==   alttind_drop_constraint |
  ==FACTOR:8==   alttind_rename_index |
  ==FACTOR:0.1== alttind_enable_disable_keys |
                 alttind_algorithm |
                 alttind_lock
;

alttind_add_index:
  ADD alttind_index_word __if_not_exists(95) alttind_ind_new_name_optional alttind_ind_type_optional ( alttind_column_list ) alttind_option_list
;

alttind_drop_index:
  DROP alttind_index_word __if_exists(95) _index
;

alttind_rename_index:
  /* compatibility 10.5.2 */ RENAME alttind_index_word __if_exists(95) _index TO alttind_ind_new_name
;

alttind_drop_constraint:
  DROP CONSTRAINT __if_exists(95) _index
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
  ADD alttind_constraint_word_optional UNIQUE alttind_index_word_optional alttind_ind_new_name_optional alttind_ind_type_optional ( alttind_column_list ) alttind_option_list
;

alttind_ind_type_optional:
  ==FACTOR:10== |
  USING alttind_ind_type
;

alttind_ind_type:
    ==FACTOR:10== BTREE |
# Disabled due to MDEV-371 issues
#  HASH | HASH | HASH | HASH |
  RTREE
;

alttind_option_list:
  | | | | alttind_ind_option | alttind_ind_option | alttind_ind_option alttind_option_list
;

alttind_ind_option:
  KEY_BLOCK_SIZE = _smallint_unsigned |
  COMMENT _english |
  USING alttind_ind_type
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
    ==FACTOR:5== _field __asc_x_desc(33,33)
  | _field_char(_tinyint_unsigned) __asc_x_desc(10,20)
  | ==FACTOR:0.1== _field_blob(_tinyint_unsigned) __asc_x_desc(10,20)
;

alttind_column_list:
  ==FACTOR:3== alttind_column_item
  | alttind_column_item, alttind_column_list
;

alttind_column_name_list:
  _field |
  _field, alttind_column_name_list
;

alttind_ind_new_name_optional:
  | alttind_ind_new_name
;

alttind_ind_new_name:
  { 'alttind'.(++$indnum) }
;

alttind_lock_optional:
  ==FACTOR:4== |
  alttind_lock
;

alttind_algorithm_optional:
  ==FACTOR:4== |
  alttind_algorithm
;

alttind_algorithm:
  ==FACTOR:2== ALGORITHM=DEFAULT |
               ALGORITHM=INPLACE |
  ==FACTOR:5== ALGORITHM=COPY |
               ALGORITHM=NOCOPY |
               ALGORITHM=INSTANT
;

alttind_lock:
  ==FACTOR:2== LOCK=DEFAULT |
               LOCK=NONE |
               LOCK=SHARED |
               LOCK=EXCLUSIVE
;
