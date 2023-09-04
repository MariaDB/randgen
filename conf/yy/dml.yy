# Copyright (C) 2018, 2022, MariaDB Corporation.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
# USA

#################################################################
# Very generic DML which should work with most gendata patterns,
# mainly to serve as a placeholder to run with various redefines
#################################################################

#include <conf/yy/include/basics.inc>


query:
  { _set_db('NON-SYSTEM') } dml_query;

dml_query:
    ==FACTOR:9== generic_dml_query |
    ==FACTOR:3== generic_dml_transaction |
    generic_dml_trx
;

generic_dml_trx:
  START TRANSACTION |
  COMMIT
;

generic_dml_transaction:
  START TRANSACTION ;; generic_dml_set ;; COMMIT ;

generic_dml_set:
  generic_dml_dml |
  generic_dml_dml ;; generic_dml_set
;

generic_dml_query:
    generic_dml_select |
    ==FACTOR:10== generic_dml_dml ;

generic_dml_dml:
    ==FACTOR:3== generic_dml_update |
    generic_dml_delete |
    ==FACTOR:2== generic_dml_insert
;

generic_dml_insert:
    generic_dml_insert_op INTO _table ( _field ) VALUES ( generic_dml_data_value ) |
    generic_dml_insert_op INTO _table ( _field, _field_next ) VALUES ( generic_dml_data_value, generic_dml_data_value ) |
    generic_dml_insert_op INTO _table () VALUES _basics_empty_values_list
;

generic_dml_insert_op:
  INSERT __ignore_x_delayed(85,3) | REPLACE
;

generic_dml_data_value:
  NULL | DEFAULT | _tinyint_unsigned | _english | _char(1) | ''
;

generic_dml_update:
    UPDATE __ignore(80) _table SET _field = generic_dml_data_value ORDER BY _field LIMIT _digit
;

generic_dml_delete:
    DELETE FROM _table ORDER BY _field LIMIT _digit
;

generic_dml_select:
    SELECT /* _table[invariant] */ _field FROM _table[invariant] ORDER BY _field LIMIT _tinyint_unsigned __for_update(20) |
    SELECT * FROM _table ORDER BY _field LIMIT _tinyint_unsigned __for_update(20)
;
