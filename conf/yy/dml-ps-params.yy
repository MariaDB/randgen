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

query_init:
  # Array index is the part of statement name (stmt_$i), the value
  # is the number of parameters
  { @ps= (); '' } { _set_db('NON-SYSTEM') } prepare_statement ;

query:
  { _set_db('NON-SYSTEM') } ps_query;

ps_query:
    prepare_statement |
    ==FACTOR:20== execute_statement |
    trx |
    ==FACTOR:0.1== deallocate_statement
;

execute_statement:
  EXECUTE { $i= $prng->uint16(0,scalar(@ps))-1; '`stmt_'.$i.'`' }  USING { $ps[$i] or 0 } ;

prepare_statement:
  PREPARE { 'stmt_'.(scalar(@ps)) } FROM " dml " { push @ps, 'data_value_'.$paramcount; '' } ;

deallocate_statement:
  DEALLOCATE PREPARE { pop @ps; 'stmt_'.(scalar(@ps)) } ;

trx:
  START TRANSACTION | COMMIT | ROLLBACK;

dml:
    select |
    ==FACTOR:3== update |
    delete |
    ==FACTOR:2== insert
;

insert:
    insert_op INTO _table ( _field ) VALUES ( { $paramcount= 1; '?' } ) |
    insert_op INTO _table ( _field, _field_next ) VALUES ( { $paramcount= 2; '?, ?' } )
;

insert_op:
  INSERT __ignore_x_delayed(85,3) | REPLACE
;

data_value_1:
  NULL | DEFAULT | _tinyint_unsigned | _english | _char(1) | '' ;

data_value_2:
  data_value_1, data_value_1;

update:
    UPDATE __ignore(80) _table SET _field = ? ORDER BY _field LIMIT { $paramcount= 2; '?' } ;

delete:
    DELETE FROM _table ORDER BY _field LIMIT { $paramcount= 1; '?' } ;

select:
    SELECT /* _table[invariant] */ _field FROM _table[invariant] ORDER BY _field LIMIT { $paramcount= 1; '?' } __for_update(20) |
    SELECT * FROM _table ORDER BY _field LIMIT { $paramcount= 1; '?' } __for_update(20)
;
