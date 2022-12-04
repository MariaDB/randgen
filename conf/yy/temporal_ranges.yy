# Copyright (c) 2010, 2012, Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2022, MariaDB
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

########################################################################
# This is a simple grammar derived from range_access2, based on the same
# principles but using temporal ranges only.
#
# It should be used with a temporal-rich dataset, e.g. temporal.zz
########################################################################

query_init:
  { _set_db('temporal_db') } alter_add ;; alter_add ;; alter_add ;; alter_add ;; alter_add ;

query:
  { _set_db('temporal_db') } temporal_ranges_query ;

temporal_ranges_query:
  alter_drop_add |
  ==FACTOR:70== select
;

select:
  SELECT distinct * FROM _table index_hint WHERE where order_by /* limit */ |
  SELECT distinct * FROM _table index_hint WHERE where order_by /* limit */ |
  SELECT distinct * FROM _table index_hint WHERE where order_by /* limit */ |
  SELECT distinct * FROM _table index_hint WHERE where order_by /* limit */ |
  SELECT aggregate _field_key ) FROM _table index_hint WHERE where |
  SELECT _field_key , aggregate _field_key ) FROM _table index_hint WHERE where GROUP BY _field_key ;

alter_add:
  ALTER TABLE _table ADD KEY key1 ( index_list ) ;

alter_drop_add:
  ALTER TABLE _table DROP KEY key1 ; ALTER TABLE _table[invariant] ADD KEY key1 ( index_list ) ;

distinct:
  | | DISTINCT ;

order_by:
  | | ORDER BY _field_indexed , `pk` ;

limit:
  | | | | |
  | LIMIT _digit;
  | LIMIT _tinyint_unsigned;

where:
  where_list and_or where_list ;

where_list:
  where_two and_or ( where_list ) |
  where_two and_or where_two |
  where_two and_or where_two and_or where_two |
  where_two ;

where_two:
  ( temporal_item and_or temporal_item );

temporal_item:
  not ( _field_indexed comparison_operator temporal_value ) |
  _field_indexed not BETWEEN temporal_value AND temporal_value |
  _field_indexed not IN ( temporal_list ) |
  _field_indexed IS not NULL ;

aggregate:
  MIN( | MAX( | COUNT( ;

and_or:
  AND | AND | AND | AND | OR ;

or_and:
  OR | OR | OR | OR | AND ;

temporal_list:
  temporal_value , temporal_value , temporal_value |
  temporal_value , temporal_list ;

temporal_value:
  _datetime | _datetime | _timestamp | '0000-00-00 00:00:00' ;

comparison_operator:
  = | = | = | = | = | = |
  != | > | >= | < | <= | <> ;

not:
  | | | | | | NOT ;

index_list:
  index_item , index_item |
  index_item , index_list;

index_item:
  _field __asc_x_desc(33,33);

index_length:
  1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 ;

index_hint:
  |
  FORCE KEY ( PRIMARY , _field_indexed , _field_indexed , _field_indexed , _field_indexed );
