# Copyright (c) 2010, 2012, Oracle and/or its affiliates. All rights reserved.
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

########################################################################
# This is a simple grammar for testing the range optimizer, index_merge and sort_union
# It is based on the following principles:
#
# * No embedded perl and attempts to create balanced expressions
#
# * Limited nesting (no runaway recursive nesting), with fixed depth of 2 levels
#
# * Using indexed columns exclusively in order to provide a lot of optimizable expressions
#
# * No joins, in order to enable larger tables without runaway queries, suitable for benchmarking and
#  avoiding situations where the optimizer would choose a full table scan due to a very small table
#
# * A smaller set of indexes in order to provide more range overlap and intersection opportunities
#
# * Both wide and narrow ranges in BETWEEN
#
# * Preference for equality expressions in order to provide ranges that actually consist of a single value
#
# * Reduced usage of NOT in order to avoid expressions that match most of the table
#
# * Use of FORCE KEY in order to prevent full table scans as much as possible
########################################################################

query_init:
  { _set_db('user') } alter_add ; alter_add ; alter_add ; alter_add ; alter_add ;

query:
  { _set_db('user') } range_access2_query ;

range_access2_query:
  alter_drop_add |
  ==FACTOR:70== select
;

select:
  SELECT distinct * FROM _table index_hint WHERE where order_by_limit |
  SELECT distinct * FROM _table index_hint WHERE where order_by_limit |
  SELECT distinct * FROM _table index_hint WHERE where order_by_limit |
  SELECT distinct * FROM _table index_hint WHERE where order_by_limit |
  SELECT /* _table[invariant] */ aggregate _field_int_key ) FROM _table[invariant] index_hint WHERE where |
  SELECT _field_int_key , aggregate _field_int_key ) FROM _table index_hint WHERE where GROUP BY 1 ;

alter_add:
  ALTER TABLE _table ADD KEY key1 ( index_list ) ;

alter_drop_add:
  ALTER TABLE _table DROP KEY key1 ; ALTER TABLE _table[invariant] ADD KEY key1 ( index_list ) ;

distinct:
  | | DISTINCT ;

order_by_limit:
  ==FACTOR:2== |
  ORDER BY any_key , _field_pk |
  ORDER BY _field_list limit ;

limit:
  ==FACTOR:5== |
  LIMIT _digit |
  LIMIT _tinyint_unsigned
;

where:
  where_list and_or where_list ;

where_list:
  where_two and_or ( where_list ) |
  where_two and_or where_two |
  where_two and_or where_two and_or where_two |
  where_two ;

where_two:
  ( integer_item or_and integer_item ) |
  ( string_item or_and string_item );

integer_item:
  not ( _field_int_key comparison_operator integer_value ) |
  _field_int_key not BETWEEN integer_value AND integer_value + integer_value |
  _field_int_key not IN ( integer_list ) |
  _field_int_key IS not NULL ;

string_item:
  not ( _field_char_key comparison_operator string_value ) |
  _field_char_key not BETWEEN string_value AND string_value |
  _field_char_key not LIKE CONCAT (string_value , '%' ) |
  _field_char_key not IN ( string_list ) |
  _field_char_key IS not NULL ;

aggregate:
  MIN( | MAX( | COUNT( ;

and_or:
  AND | AND | AND | AND | OR ;
or_and:
  OR | OR | OR | OR | AND ;

integer_value:
  _digit | _digit |
  _tinyint | _tinyint_unsigned |
  255 | 1 ;

string_value:
  _varchar(1) | _varchar(2) | _english | _states | _varchar(10) ;

integer_list:
  integer_value , integer_value |
  integer_value , integer_list ;

string_list:
  string_value , string_value |
  string_value , string_list ;

comparison_operator:
  = | = | = | = | = | = |
  != | > | >= | < | <= | <> ;

not:
  | | | | | | NOT ;

# If there are no such keys, the generator will use any field
any_key:
  _field_int_key | _field_char_key ;

index_list:
  index_item  __asc_x_desc(33,33) , index_item  __asc_x_desc(33,33) |
  index_item  __asc_x_desc(33,33) , index_list;

index_item:
  _field | _field |
  _field_int_key | _field_char_key ( index_length ) ;

index_length:
  1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 ;

index_hint:
  ;
