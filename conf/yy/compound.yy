# Copyright (c) 2023, 2025, MariaDB
# Use is subject to license terms.
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

# Basic compound statement syntax, placeholder
# TODO: to be extended

#features ROW type

query:
  ==FACTOR:2== { _set_db('NON-SYSTEM') } SET sql_mode=REPLACE(@@sql_mode,'ORACLE','') ;; BEGIN NOT ATOMIC compound_block_default ; END ;; SET sql_mode=DEFAULT |
  ==FACTOR:2== { _set_db('NON-SYSTEM') } SET sql_mode=REPLACE(@@sql_mode,'ORACLE','') ;; create_and_call_sp ;; SET sql_mode=DEFAULT |
               { _set_db('NON-SYSTEM') } SET sql_mode=ORACLE ;;                          BEGIN NOT ATOMIC compound_block_oracle ;  END ;; SET sql_mode=DEFAULT /* compatibility 11.8 */
;

sp_name:
  { 'sp'.abs($$) };

create_and_call_sp:
  CREATE OR REPLACE PROCEDURE sp_name (sp_parameters) BEGIN compound_block_default ; END ;; CALL sp_name() ;

sp_parameters:
  |
  IN p1 INT DEFAULT _int /* compatibility 11.8 */;

compound_block_default:
  declare_row_type |
  declare_row_type_default
;

compound_block_oracle:
  declare_type_is_record
;

declare_row_type:
    DECLARE r ROW TYPE OF _table[invariant]
  ; SELECT * INTO r FROM _table[invariant] LIMIT 1
  ; SELECT r._field
;

declare_row_type_default:
    DECLARE r ROW TYPE OF _table[invariant] DEFAULT (SELECT * FROM _table[invariant] LIMIT 1)
  ; SELECT r._field
;

declare_type_is_record:
  DECLARE
    TYPE type_rec IS RECORD (
      val1 record_val_type,
      val2 record_val_type,
      val3 record_val_type,
      val4 record_val_type
    )
    ; rec type_rec:= type_rec(record_val_value,record_val_value,record_val_value,record_val_value)
    ; str TEXT
  ; BEGIN
    str:= CONCAT('val1: ', rec.val1, '; ', 'val2: ', rec.val2, '; ', 'val3: ', rec.val3, '; ', 'val4: ', rec.val4)
    ; SELECT str
  ; END
;

record_val_type:
  NUMBER(_digit) | VARCHAR2(_tinyint_unsigned)
;

record_val_value:
  _int | _english ;
