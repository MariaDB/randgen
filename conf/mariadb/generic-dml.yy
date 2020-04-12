# Copyright (C) 2018 MariaDB Corporation.
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


# Very generic DML which should work with most gendata patterns,
# mainly to serve as a placeholder to run with various redefines

query:
    dml | dml | dml | dml | dml | dml | dml |
    trx
;

trx:
  START TRANSACTION |
  COMMIT
;

dml:
    select | 
    update | update | update | 
    delete |
    insert | insert
;

insert:
    insert_op INTO _table ( _field ) VALUES ( data_value ) |
    insert_op INTO _table ( _field, _field )  VALUES ( data_value, data_value ) |
    insert_op INTO _table ( _field, _field ) VALUES ( data_value, data_value ) |
    insert_op INTO _table () VALUES () |
    insert_op INTO _table () VALUES (),(),(),() |
;

insert_op:
  INSERT IGNORE | REPLACE
;

data_value:
  NULL | DEFAULT | _tinyint_unsigned | _english | _char(1) | ''
;

update:
    UPDATE IGNORE _table SET _field = data_value ORDER BY _field LIMIT 1
;

delete:
    DELETE FROM _table ORDER BY _field LIMIT 1
;

select:
    SELECT _field FROM _table ORDER BY _field LIMIT 1
;
