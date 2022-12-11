# Copyright (C) 2008 Sun Microsystems, Inc. All rights reserved.
# Use is subject to license terms.
# Copyright (c) 2022, MariaDB
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
# This grammar is suitable for general stress testing of storage engines
# including the InnoDB plugin and Falcon, their locking and transactional mechanisms. It can
# also be used along with the Combinations facility in order to provide stress testing under
# various configurations
#
# The goal is to spend as much time as possible inside the storage engine and as little time
# as possible in the optimizer. Therefore, most of the queries have trivial optimizer plans
# and run very quickly.
#
# At the same time, please note that this grammar does not aim to cover all possible
# table access methods. The grammars from conf/optimizer/optimizer* are more suitable for that.
#

query:
  { _set_db('NON-SYSTEM') } trx_stress_query ;

trx_stress_query:
  transaction |
  ==FACTOR:4== select |
  ==FACTOR:5== insert_replace |
  ==FACTOR:2== delete |
  ==FACTOR:5== update
;

transaction:
  START TRANSACTION |
  COMMIT ; SET TRANSACTION ISOLATION LEVEL isolation_level |
  ROLLBACK ; SET TRANSACTION ISOLATION LEVEL isolation_level |
  SAVEPOINT A | ROLLBACK TO SAVEPOINT A |
  SET AUTOCOMMIT=OFF | SET AUTOCOMMIT=ON ;

isolation_level:
  READ UNCOMMITTED | READ COMMITTED | REPEATABLE READ | SERIALIZABLE ;

select:
  SELECT /* _table { ($outer_db,$outer_table)= ($last_database,$last_table); '' } */ select_list { ($last_database,$last_table)= ($outer_db,$outer_table); '' } FROM join_list where LIMIT large_digit;

select_list:
  X . _field_key | X . _field_key |
  X . _field_pk |
  X . _field |
  * |
  ==FACTOR:0.1== ( subselect ORDER BY 1 LIMIT 1 )
;

subselect:
  SELECT /* _table[invariant] */ _field_key FROM _table[invariant] WHERE _field_pk = value ;

# Use index for all joins
join_list:
  { "$last_database.$last_table" } AS X |
  { "$last_database.$last_table" } AS X LEFT JOIN _table AS Y ON ( Y._field_key = { ($last_database,$last_table)= ($outer_db,$outer_table); 'X.' } _field_key );


# Insert more than we delete
insert_replace:
  i_r INTO _table ( _field_pk ) VALUES (NULL) |
  i_r INTO _table ( _field_no_pk , _field_no_pk ) VALUES ( value , value ) , ( value , value ) |
  i_r INTO _table ( _field_no_pk ) SELECT /* _table[invariant] */ _field_key FROM _table[invariant] AS X where ORDER BY _field_list LIMIT large_digit;

i_r:
  INSERT __ignore(80) |
  REPLACE;

update:
  UPDATE __ignore(80) _table { ($outer_db,$outer_table)= ($last_database,$last_table); '' } AS X SET _field_no_pk = value where { ($last_database,$last_table)= ($outer_db,$outer_table); '' } ORDER BY _field_list LIMIT large_digit ;

# We use a smaller limit on DELETE so that we delete less than we insert

delete:
  DELETE __ignore(20) FROM _table { ($outer_db,$outer_table)= ($last_database,$last_table); '' } where_delete ORDER BY { ($last_database,$last_table)= ($outer_db,$outer_table); '' } _field_list LIMIT small_digit ;

order_by:
  | ORDER BY X . _field_key ;

# Use an index at all times
where:
  |
  WHERE X . _field_key < value |   # Use only < to reduce deadlocks
  WHERE X . _field_key IN ( value , value , value , value , value ) |
  WHERE X . _field_key BETWEEN small_digit AND large_digit |
  WHERE X . _field_key BETWEEN _tinyint_unsigned AND _int_unsigned |
  WHERE X . _field_key IN ( subselect ) |
  WHERE X . _field_key = ( subselect ORDER BY 1 LIMIT 1 ) ;

where_delete:
  |
  WHERE _field_key = value |
  WHERE _field_key IN ( value , value , value , value , value ) |
  WHERE _field_key IN ( subselect ) |
  WHERE _field_key BETWEEN small_digit AND large_digit ;

large_digit:
  5 | 6 | 7 | 8 ;

small_digit:
  1 | 2 | 3 | 4 ;

value:
  _digit | _tinyint_unsigned | _varchar(1) | _int_unsigned ;

zero_one:
  0 | 0 | 1;
