# Copyright (C) 2009-2010 Sun Microsystems, Inc. All rights reserved.
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

################################################################################
# range_access.yy
# Purpose:  For testing the range optimization for MySQL
# gendata:  Use with conf/zz/range_access.zz as a gendata file
# uses:
#   valgrind - use MarkErrorLog Validator + --valgrind
#   comparison between MySQL versions / configurations
#   3way compares to javadb and postgres
################################################################################

query:
# Since the schema is uniform, we can pre-pick any table to get correct field names,
# no need to pick it in every select and join
  { $idx_table = '' ; @idx_fields = () ;  _set_db('range_access_db') }
  { ($last_database,$last_table)= @{$prng->arrayElement($executors->[0]->metaBaseTables($work_database))}; '' }
  query_type ;

query_type:
  single_idx_query_set | dual_int_idx_query_set | dual_char_idx_query_set | tri_int_idx_query_set ;

single_idx_query_set:
  single_idx_query ;; single_idx_query ;; single_idx_query ;; single_idx_query ;; single_idx_query ;

dual_int_idx_query_set:
  new_dual_int_index ;; multi_int_idx_query_set ;

dual_char_idx_query_set:
  new_dual_char_index ;; multi_char_idx_query_set ;

tri_int_idx_query_set:
  new_tri_int_index ;; multi_int_idx_query_set ;

tri_char_idx_query_set:
  new_tri_char_index ;; multi_char_idx_query_set ;

wild_query:
  single_idx_query | multi_int_idx_query | multi_char_idx_query ;

multi_int_idx_query_set:
  multi_int_idx_query ;; multi_int_idx_query ;; multi_int_idx_query ;; multi_int_idx_query ;; multi_int_idx_query ;; wild_query ;; drop_index ;

multi_char_idx_query_set:
  multi_char_idx_query ;; multi_char_idx_query ;; multi_char_idx_query ;; multi_char_idx_query ;; multi_char_idx_query ;; wild_query ;; drop_index ;

################################################################################
# index-specific rules
################################################################################

drop_index:
 DROP INDEX IF EXISTS `test_idx` ON { $idx_table } ;

index_pre:
  ALTER TABLE index_table ADD INDEX IF NOT EXISTS `test_idx` USING index_type ;

new_dual_int_index:
  index_pre (dual_int_idx_field_list) ;

new_dual_char_index:
 index_pre (dual_char_idx_field_list) ;

new_tri_int_index:
  index_pre (tri_int_idx_field_list) ;

new_tri_char_index:
  index_pre (tri_char_idx_field_list) ;

dual_int_idx_field_list:
  _field_int __asc_x_desc(33,33), { push @idx_fields, $last_field; '' } _field_int __asc_x_desc(33,33) { push @idx_fields, $last_field; '' } ;

dual_char_idx_field_list:
  _field_char __asc_x_desc(33,33), { push @idx_fields, $last_field; '' } _field_char __asc_x_desc(33,33) { push @idx_fields, $last_field; '' } ;

tri_int_idx_field_list:
  _field_int __asc_x_desc(33,33), { push @idx_fields, $last_field; '' } _field_int __asc_x_desc(33,33), { push @idx_fields, $last_field; '' } _field_int __asc_x_desc(33,33) { push @idx_fields, $last_field; '' } ;

tri_char_idx_field_list:
  _field_char __asc_x_desc(33,33), { push @idx_fields, $last_field; '' } _field_char __asc_x_desc(33,33), { push @idx_fields, $last_field; '' } _field_char __asc_x_desc(33,33) { push @idx_fields, $last_field; '' } ;

################################################################################
# single index rules
################################################################################

single_idx_where_list:
    single_int_idx_where_clause | single_char_idx_where_clause |
    single_idx_where_list and_or single_int_idx_where_clause |
    single_idx_where_list and_or single_char_idx_where_clause ;


single_int_idx_where_clause:
   single_int_idx_where_list ;


single_int_idx_where_list:
   single_int_idx_where_list or_and single_int_idx_where_item |
   single_int_idx_where_item | single_int_idx_where_item ;

int_idx_field:
    { $last_idx_field = "alias".$prng->int(1,$tables).'.' } _field_int { $last_idx_field .= $last_field; '' } ;

single_int_idx_where_item:
   int_idx_field greater_than _digit[invariant] AND { $last_idx_field } less_than ( _digit[invariant] + increment ) |
   int_idx_field greater_than _digit[invariant] AND { $last_idx_field } less_than ( _digit[invariant] + increment ) |
   int_idx_field greater_than _digit AND { $last_idx_field } less_than ( _digit[invariant] + int_value ) |
   int_idx_field greater_than _digit[invariant] AND { $last_idx_field } less_than ( _digit + int_value ) |
   int_idx_field greater_than _digit AND { $last_idx_field } less_than ( _digit + increment ) |
   int_idx_field comparison_operator int_value |
   int_idx_field not_equal int_value |
   int_idx_field not IN (number_list) |
   int_idx_field not BETWEEN _digit[invariant] AND (_digit[invariant] + int_value ) |
   int_idx_field IS not NULL ;


single_char_idx_where_clause:
  single_char_idx_where_list ;

single_char_idx_where_list:
  single_char_idx_where_list and_or single_char_idx_where_item |
  single_char_idx_where_item | single_char_idx_where_item ;

char_idx_field:
    { $last_idx_field = "alias".$prng->int(1,$tables).'.' } _field_char { $last_idx_field .= $last_field; '' } ;


single_char_idx_where_item:
  char_idx_field greater_than _char AND { $last_idx_field } less_than 'z' |
  char_idx_field greater_than _char AND { $last_idx_field } less_than 'z' |
  char_idx_field greater_than _char AND { $last_idx_field } less_than 'z' |
  char_idx_field greater_than char_value AND { $last_idx_field } less_than char_value |
  char_idx_field greater_than char_value AND { $last_idx_field } less_than 'zzzz' |
  char_idx_field IS not NULL |
  char_idx_field not IN (char_list) |
  char_idx_field not LIKE ( char_pattern ) |
  char_idx_field not BETWEEN _char AND 'z' ;

################################################################################
# multi-part index rules
################################################################################

multi_int_idx_where_list:
    multi_int_idx_where_clause |
    multi_int_idx_where_list and_or multi_int_idx_where_clause | multi_int_idx_where_list and_or multi_int_idx_where_clause ;


multi_int_idx_where_clause:
   {  $int_idx_field = ("alias".$prng->int(1,$tables))." . ".$prng->arrayElement(\@idx_fields) ; "" } single_int_idx_where_list ;

# char rules
multi_char_idx_where_list:
    multi_char_idx_where_clause |
    multi_char_idx_where_list and_or multi_char_idx_where_clause | multi_char_idx_where_list and_or multi_char_idx_where_clause ;

multi_char_idx_where_clause:
   {  $char_idx_field = ("alias".$prng->int(1,$tables))." . ".$prng->arrayElement(\@idx_fields) ; "" } single_char_idx_where_list ;



################################################################################
# general-purpose query rules
################################################################################

single_idx_query:
  { $tables=0 ; $fields = 0 ; "" }  SELECT straight_join select_list FROM join WHERE single_idx_where_list opt_where_list group_by_clause order_by_clause ;

multi_int_idx_query:
  { $tables=0 ; $fields = 0 ; "" }  SELECT straight_join select_list FROM idx_join WHERE multi_int_idx_where_list opt_where_list group_by_clause order_by_clause ;

multi_char_idx_query:
  { $tables=0 ; $fields = 0 ; "" }  SELECT straight_join select_list FROM idx_join WHERE multi_char_idx_where_list opt_where_list group_by_clause order_by_clause ;

select_list:
  select_item | select_item , select_list ;

select_item:
  table_one_two . _field AS { my $f = "field".++$fields ; $f } ;

straight_join:
  | | | | | | | | STRAIGHT_JOIN ;

join:
   { $stack->push() }
   table_or_join
   { $stack->set("left",$stack->get("result")); }
   left_right outer JOIN table_or_join
   ON
   join_condition ;

idx_join:
   { $stack->push() }
   idx_table_for_join
   { $stack->set("left",$stack->get("result")); }
   left_right outer JOIN table_or_join
   ON
   join_condition ;

join_condition:
   int_condition | char_condition ;

int_condition:
   { my $left = $stack->get("left"); my %s=map{$_=>1} @$left; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . int_indexed =
   { my $right = $stack->get("result"); my %s=map{$_=>1} @$right; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . int_indexed
   { my $left = $stack->get("left");  my $right = $stack->get("result"); my @n = (); push(@n,@$right); push(@n,@$left); $stack->pop(\@n); return undef } |
   { my $left = $stack->get("left"); my %s=map{$_=>1} @$left; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . int_indexed =
   { my $right = $stack->get("result"); my %s=map{$_=>1} @$right; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . int_field_name
   { my $left = $stack->get("left");  my $right = $stack->get("result"); my @n = (); push(@n,@$right); push(@n,@$left); $stack->pop(\@n); return undef } |
   { my $left = $stack->get("left"); my %s=map{$_=>1} @$left; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . int_field_name =
   { my $right = $stack->get("result"); my %s=map{$_=>1} @$right; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/,
 $table_string); $table_array[1] } . int_indexed
   { my $left = $stack->get("left");  my $right = $stack->get("result"); my @n = (); push(@n,@$right); push(@n,@$left); $stack->pop(\@n); return undef } |
   { my $left = $stack->get("left"); my %s=map{$_=>1} @$left; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . int_field_name =
   { my $right = $stack->get("result"); my %s=map{$_=>1} @$right; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/,
 $table_string); $table_array[1] } . int_field_name
   { my $left = $stack->get("left");  my $right = $stack->get("result"); my @n = (); push(@n,@$right); push(@n,@$left); $stack->pop(\@n); return undef } ;

char_condition:
   { my $left = $stack->get("left"); my %s=map{$_=>1} @$left; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . char_field_name =
   { my $right = $stack->get("result"); my %s=map{$_=>1} @$right; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . char_field_name
   { my $left = $stack->get("left");  my $right = $stack->get("result"); my @n = (); push(@n,@$right); push(@n,@$left); $stack->pop(\@n); return undef } |
   { my $left = $stack->get("left"); my %s=map{$_=>1} @$left; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . char_indexed  =
   { my $right = $stack->get("result"); my %s=map{$_=>1} @$right; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . char_field_name
   { my $left = $stack->get("left");  my $right = $stack->get("result"); my @n = (); push(@n,@$right); push(@n,@$left); $stack->pop(\@n); return undef } |
   { my $left = $stack->get("left"); my %s=map{$_=>1} @$left; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . char_field_name =
   { my $right = $stack->get("result"); my %s=map{$_=>1} @$right; my @r=(keys %s); my $table_string = $prng->arrayElement(\@r); my @table_array = split(/AS/, $table_string); $table_array[1] } . char_indexed
   { my $left = $stack->get("left");  my $right = $stack->get("result"); my @n = (); push(@n,@$right); push(@n,@$left); $stack->pop(\@n); return undef } ;

table_or_join:
           table | table | table | table | table | table |
           table | table | join | join ;

table:
# We use the "AS alias" bit here so we can have unique aliases if we use the same table many times
       { $stack->push(); my (undef,$x) = @{$prng->arrayElement($executors->[0]->metaTables($work_database))}; $x.=" AS alias".++$tables;  my @s=($x); $stack->pop(\@s); $x } ;

idx_table_for_join:
       { $stack->push() ; my $x = $idx_table." AS alias".++$tables; my @s=($x); $stack->pop(\@s); $x } ;

join_type:
  INNER JOIN | left_right outer JOIN | STRAIGHT_JOIN ;

left_right:
  LEFT | LEFT | LEFT | RIGHT ;

outer:
  | | | | OUTER ;

index_type:
# Disabled due to MDEV-371 issues
#  HASH |
  BTREE ;

index_table:
  { my (undef,$idx_table_candidate) = @{$prng->arrayElement($executors->[0]->metaBaseTables($work_database))} ; $idx_table = $idx_table_candidate ; $idx_table } ;

opt_where_list:
  | | | | and_or where_list ;

where_list:
  where_item | where_item | where_item | ( where_list and_or where_item ) ;

where_item:
  existing_table_item . int_field_name comparison_operator int_value |
  existing_table_item . char_field_name comparison_operator _char |
  existing_table_item . int_field_name comparison_operator int_value |
  existing_table_item . int_field_name comparison_operator existing_table_item . int_field_name |
  existing_table_item . char_field_name comparison_operator _char |
  existing_table_item . char_field_name comparison_operator existing_table_item . char_field_name |
  existing_table_item . _field IS not NULL |
  existing_table_item . int_field_name IS not NULL |
  single_idx_where_list ;

group_by_clause:
  | | | | | GROUP BY { @groupby = (); for (1..$fields) { push @groupby, 'field'.$_ }; join ',', @groupby } ;

order_by_clause:
  | | |
        ORDER BY total_order_by __asc_x_desc(20,20) limit |
  ORDER BY order_by_list  ;

total_order_by:
  { join(', ', map { "field".$_ } (1..$fields) ) };

order_by_list:
  order_by_item  |
  order_by_item  , order_by_list ;

order_by_item:
  existing_select_item __asc_x_desc(20,20);

limit:
  | | LIMIT limit_size | LIMIT limit_size OFFSET int_value;

limit_size:
    1 | 2 | 10 | 100 | 1000;

################################################################################
# utility / helper rules
################################################################################

new_table_item:
  _table AS { "alias".++$tables };

existing_table_item:
  { "alias".$prng->int(1,$tables) };

existing_select_item:
  { "field".$prng->int(1,$fields) };

comparison_operator:
  = | > | < | != | <> | <= | >= ;

greater_than:
  > | >= ;

less_than:
  < | <= ;

not_equal:
  <> | != ;

int_value:
   _digit | _digit | _digit | _digit | _digit | _digit | other_int ;

other_int:
   _tinyint_unsigned | 20 | 25 | 30 | 35 | 50 | 65 | 75 | 100 ;

char_value:
  _char | _char | _char | _quid | _english ;

char_pattern:
 char_value | char_value | CONCAT( _char, '%') | 'a%'| _quid | '_' | '_%' ;

increment:
   1 |  1 | 2 | 2 | 5 | 5 | 6 | 10 ;

large_length:
   200 | 200 | 200 | 200 | 200 | 100 | 200 | 250 | 37 | 50 | 175 | small_length ;

small_length:
   1 | 2 | 5 | 7 | 8 | 9 | 10 | 10 | 10 | 10 ;

random_length:
  large_length | large_length | small_length ;

int_indexed:
   _field_int ;

int_field_name:
   _field_int ;

char_indexed:
   _field_char;

char_field_name:
   _field_char ;

number_list:
   int_value | number_list, int_value ;

char_list:
   _char | char_list, _char ;

table_one_two:
   alias1 | alias1 | alias1 | alias2 | alias2 ;

and_or:
   AND | AND | OR ;

or_and:
  OR | OR | OR | AND ;

not:
    | | NOT ;
