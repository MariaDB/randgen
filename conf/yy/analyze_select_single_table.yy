# Copyright (C) 2021, 2022, MariaDB
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
# Grammar originally created for MDEV-21130 testing (JSON histograms).
# Performs single-table ANALYZE FORMAT=JSON SELECTs
########################################################################

#include <conf/yy/include/basics.inc>


thread1_init:
  SET GLOBAL SQL_MODE= CONCAT(@@sql_mode,',',extra_sql_mode_values);

query:
  { $fields = 0 ; _set_db('ANY') } ANALYZE FORMAT=JSON /* _table[invariant] */ SELECT select_list FROM _table[invariant] WHERE where_list opt_where_list group_by_clause order_by_clause;

select_list:
  select_item | select_item , select_list ;

select_item:
  _field AS { my $f = "field".++$fields ; $f } ;

where_list:
    where_clause | where_clause |
    where_list and_or where_clause ;

where_clause:
   where_list or_and where_item |
   ( where_list or_and where_item ) |
   where_item | where_item | where_item | where_item ;

where_item:
   int_value_or_field comparison_operator int_value_or_field |
   int_value_or_field __not(25) IN (number_list) |
   int_value_or_field __not(25) BETWEEN int_value_or_field AND int_value_or_field |
   char_value_or_field comparison_operator char_value_or_field |
   char_value_or_field __not(25) IN (char_list) |
   char_value_or_field __not(25) LIKE ( char_pattern ) |
   char_value_or_field __not(25) BETWEEN char_value_or_field AND char_value_or_field |
   _field IS __not(25) is_value |
   any_value_or_field comparison_operator any_value_or_field |
   any_value_or_field __not(25) IN (number_list) |
   any_value_or_field __not(25) BETWEEN any_value_or_field AND any_value_or_field
;


opt_where_list:
  | | | | and_or where_list ;

group_by_clause:
  | | | | | GROUP BY { @groupby = (); for (1..$fields) { push @groupby, 'field'.$_ }; join ',', @groupby } ;

order_by_clause:
  | | |
  ORDER BY total_order_by desc limit |
  ORDER BY order_by_list  ;

total_order_by:
  { join(', ', map { "field".$_ } (1..$fields) ) };

order_by_list:
  order_by_item  |
  order_by_item  , order_by_list ;

order_by_item:
  existing_select_item desc ;

existing_select_item:
  { "field".$prng->uint16(1,$fields) };

limit:
  | | LIMIT limit_size | LIMIT limit_size OFFSET int_value;

extra_sql_mode_values:
  {   @modes= ('REAL_AS_FLOAT','ANSI_QUOTES','ORACLE','ANSI','NO_BACKSLASH_ESCAPES','NO_ZERO_IN_DATE','NO_ZERO_DATE','ALLOW_INVALID_DATES','PAD_CHAR_TO_FULL_LENGTH')
      ; $length=$prng->int(0,scalar(@modes))
      ; "'" . (join ',', @{$prng->shuffleArray(\@modes)}[0..$length-1]) . "'"
  }
;

or_and:
  OR | OR | XOR | AND ;

comparison_operator:
  = | > | < | != | <> | <= | >= | <=> ;

is_value:
  ==FACTOR:5== NULL
  | TRUE | FALSE | UNKNOWN ;

int_value_or_field:
  int_value | _field_int ;

int_value:
   _digit | _digit | _tinyint_unsigned | 20 | 25 | 30 | 35 | 50 | 65 | 75 | 100 ;

char_value_or_field:
  char_value | _field_char ;

char_value:
  _char | _char(8) | _char(16) | _quid | _english ;

char_list:
   char_value_or_field | char_list, char_value_or_field ;

char_pattern:
 char_value | char_value | CONCAT( _char, '%') | 'a%'| _quid | '_' | '_%' ;

desc:
 ASC | | | | DESC ;

and_or:
   AND | AND | AND | AND | OR | XOR ;

limit_size:
    1 | 2 | 10 | 100 | 1000;

number_list:
   int_value_or_field | number_list, int_value_or_field ;

any_value:
  char_value | int_value | _basics_any_value ;

any_value_or_field:
  any_value | _field ;

any_list:
 any_value_or_field | any_list, any_value_or_field ;

