# Copyright (C) 2018, 2026, MariaDB Corporation.
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
  ==FACTOR:9== dml_dml |
               dml_trx |
  ==FACTOR:0.05== START TRANSACTION ;; dml_long_transaction ;; __commit_x_rollback(70,30)
;

dml_long_transaction:
               dml_10000 |
  ==FACTOR:3== dml_1000  |
  ==FACTOR:9== dml_100
;


dml_10:
     dml_dml
  ;; dml_dml
  ;; dml_dml
  ;; dml_dml
  ;; dml_dml
  ;; dml_dml
  ;; dml_dml
  ;; dml_dml
  ;; dml_dml
  ;; dml_dml
;

dml_100:
     dml_10
  ;; dml_10
  ;; dml_10
  ;; dml_10
  ;; dml_10
  ;; dml_10
  ;; dml_10
  ;; dml_10
  ;; dml_10
  ;; dml_10
;

dml_1000:
     dml_100
  ;; dml_100
  ;; dml_100
  ;; dml_100
  ;; dml_100
  ;; dml_100
  ;; dml_100
  ;; dml_100
  ;; dml_100
  ;; dml_100
;

dml_10000:
     dml_1000
  ;; dml_1000
  ;; dml_1000
  ;; dml_1000
  ;; dml_1000
  ;; dml_1000
  ;; dml_1000
  ;; dml_1000
  ;; dml_1000
  ;; dml_1000
;

dml_trx:
  START TRANSACTION |
  COMMIT
;

dml_dml:
               dml_select |
      dml_select_from_cte |
  ==FACTOR:9== dml_update |
  ==FACTOR:2== dml_delete |
  ==FACTOR:5== dml_insert
;

dml_insert:
  dml_insert_op INTO _table ( _field ) VALUES ( dml_data_value ) |
  dml_insert_op INTO _table ( _field, _field_next ) VALUES ( dml_data_value, dml_data_value ) |
  dml_insert_op INTO _table () VALUES _basics_empty_values_list
;

dml_insert_op:
  INSERT __ignore_x_delayed(85,3) | REPLACE
;

dml_data_value:
  NULL | DEFAULT | _tinyint_unsigned | _english | _char(1) | ''
;

dml_field_condition:
  _field IS __not(50) NULL |
  _field _basics_comparison_operator _tinyint_unsigned |
  _field _basics_comparison_operator _english | _char(1)
;

dml_update:
  UPDATE __ignore(80) _table SET _field = dml_data_value ORDER BY _field LIMIT _digit |
  dml_with_1cte UPDATE __ignore(80) _table SET _field = dml_data_value WHERE EXISTS (SELECT * FROM cte ) ORDER BY _field LIMIT _digit /* compatibility 12.3.1 */ |
  dml_with_2cte UPDATE __ignore(80) _table, cte1, cte2 SET _field = cte2._field WHERE EXISTS (SELECT * FROM cte1 ) ORDER BY _field LIMIT _digit /* compatibility 12.3.1 */
;

dml_delete:
  DELETE FROM _table ORDER BY _field LIMIT _digit |
  dml_with_1cte DELETE FROM _table WHERE dml_field_condition AND EXISTS ( SELECT * FROM cte ) /* compatibility 12.3.1 */ |
  dml_with_2cte DELETE FROM _table[invariant] USING _table[invariant], cte1, cte2 WHERE _field = cte2._field AND EXISTS ( SELECT * FROM cte1 NATURAL JOIN cte2 ) /* compatibility 12.3.1 */
;

dml_select:
  SELECT /* _table[invariant] */ _field FROM _table[invariant] ORDER BY _field LIMIT _tinyint_unsigned __for_update(20) |
  SELECT * FROM _table ORDER BY _field LIMIT _tinyint_unsigned __for_update(20)
;

dml_select_from_cte:
  dml_with_1cte SELECT * FROM cte WHERE dml_field_condition |
  dml_with_2cte SELECT * FROM cte1 WHERE EXISTS (SELECT * FROM cte2 WHERE dml_field_condition)
;

dml_with_1cte:
  WITH cte AS ( dml_select );

dml_with_2cte:
  WITH cte1 AS ( dml_select ), cte2 AS ( dml_select );
