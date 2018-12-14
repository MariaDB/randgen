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


query_add:
  query | query | query | query | query | fk_query
;

fk_query:
    fk_alter_table | fk_alter_table | fk_alter_table | fk_alter_table
  | fk_alter_table | fk_alter_table | fk_alter_table | fk_alter_table
  | fk_set_checks
;

fk_global_session:
  | | SESSION | SESSION | SESSION | SESSION | GLOBAL
;

fk_alter_table:
  ALTER fk_online_optional fk_ignore_optional TABLE _table fk_wait_optional fk_add_drop_list fk_algorithm fk_lock
;


fk_set_checks:
  SET fk_global_session FOREIGN_KEY_CHECKS = fk_on_off
;

fk_on_off:
  ON | OFF
;

fk_online_optional:
  | | | ONLINE
;

fk_ignore_optional:
  | | IGNORE
;

fk_wait_optional:
  | | | /*!100301 WAIT _digit */ | /*!100301 NOWAIT */
;

fk_add_drop_list:
  fk_item | fk_item | fk_item | fk_item | fk_item, fk_add_drop_list
;

fk_item:
    fk_add_foreign_key | fk_add_foreign_key | fk_add_foreign_key
  | fk_drop_foreign_key
;

fk_algorithm:
  | | , ALGORITHM=INPLACE | , ALGORITHM=COPY | , ALGORITHM=DEFAULT | /*!100307 , ALGORITHM=NOCOPY */ | /*!100307 , ALGORITHM=INSTANT */
;

fk_lock:
  |
  | , LOCK=NONE
  | , LOCK=SHARED
# Disabled due to MDEV-17595:
#  | , LOCK=EXCLUSIVE
  | , LOCK=DEFAULT
;
  
fk_add_foreign_key:
  # First variant: the table references itself, the referenced and referencing columns are random
    ADD fk_constraint_optional FOREIGN KEY fk_index_name_optional (_field) REFERENCES { $last_table } (_field) fk_optional_on_delete fk_optional_on_update
  # Second variant: the table references a different table, the referenced and referencing column lists are identical
  | ADD fk_constraint_optional FOREIGN KEY fk_index_name_optional (fk_column_list_new) REFERENCES _table (fk_column_list_last) fk_optional_on_delete fk_optional_on_update
;

fk_constraint_optional:
  | CONSTRAINT fk_index_name_optional
;

fk_index_name_optional:
  | _letter
;

fk_drop_foreign_key:
  DROP FOREIGN KEY fk_if_exists _letter
;

fk_if_exists:
  | | IF EXISTS
;

fk_column_list_new:
  { @columns=(); '' } fk_column_list
;

fk_column_list:
  fk_column | fk_column | fk_column | fk_column | fk_column, fk_column_list
;

fk_column_list_last:
  { join ',', @columns }
;

fk_column:
  _field { push @columns, $last_field; '' }
;

fk_optional_on_delete:
  | | ON DELETE fk_reference_option
;

fk_optional_on_update:
  | | ON UPDATE fk_reference_option
;

fk_reference_option:
  RESTRICT | CASCADE | SET NULL | NO ACTION | SET DEFAULT
;

