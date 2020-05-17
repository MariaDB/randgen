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

query_add:
    ==FACTOR:9== dml |
    trx
;

trx:
  START TRANSACTION |
  COMMIT
;

dml:
    select | 
    ==FACTOR:3== update |
    delete |
    ==FACTOR:2== insert
;

insert:
    insert_op INTO _table ( _field ) VALUES ( data_value ) |
    insert_op INTO _table ( _field, _next_field ) VALUES ( data_value, data_value ) |
    insert_op INTO _table () VALUES _basics_empty_values_list
;

insert_op:
  INSERT _basics_delayed_5pct _basics_ignore_80pct | REPLACE
;

data_value:
  NULL | DEFAULT | _tinyint_unsigned | _english | _char(1) | ''
;

update:
    UPDATE _basics_ignore_80pct _table SET _field = data_value ORDER BY _field LIMIT _digit
;

delete:
    DELETE FROM _table ORDER BY _field LIMIT _digit
;

select:
    SELECT _field FROM _table ORDER BY _field LIMIT _tinyint_unsigned |
    SELECT * FROM _table ORDER BY _field LIMIT _tinyint_unsigned
;
