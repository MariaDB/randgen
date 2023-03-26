# Copyright (c) 2023, MariaDB
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

#
# Transactional statements
# including the InnoDB plugin and Falcon, their locking and transactional mechanisms. It can

query:
  { _set_db('NON-SYSTEM') } trx_query ;

trx_query:
  ==FACTOR:3== { %savepoints= (); '' } START TRANSACTION |
               { %savepoints= (); '' } COMMIT |
               { %savepoints= (); '' } ROLLBACK |
               SET __session_x_global(50,25) TRANSACTION trx_property_list |
  ==FACTOR:3== SAVEPOINT { $sp= 'sp'.$prng->uint16(1,9); $savepoints{$sp}= 1; $sp } |
               ROLLBACK TO SAVEPOINT { scalar(keys %savepoints) ? $prng->arrayElement([sort keys %savepoints]) : 'sp0' } |
               RELEASE SAVEPOINT { $sp= scalar(keys %savepoints) ? $prng->arrayElement([sort keys %savepoints]) : 'sp0'; delete $savepoints{$sp}; $sp }
;

trx_property_list:
  ISOLATION LEVEL trx_isolation_level |
  trx_property |
  ISOLATION LEVEL trx_isolation_level, trx_property |
  trx_property, ISOLATION LEVEL trx_isolation_level
;

trx_property:
  READ WRITE | READ ONLY ;

trx_isolation_level:
  ==FACTOR:5== REPEATABLE READ |
  ==FACTOR:5== READ COMMITTED |
               READ UNCOMMITTED |
               SERIALIZABLE
;
