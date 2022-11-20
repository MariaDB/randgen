# Copyright (c) 2022, MariaDB Corporation.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1335  USA */

############################################
# A DML grammar created from all_selects.yy
############################################

#include <conf/basics.yy>


# Set here the list of databases if necessary, e.g.
# $updates_deletes_databases= [ 'test' ]; 

query_init:
   { $tables= 0; $updates_deletes_databases= $executors->[0]->databases(1); $executors->[0]->setMetadataReloadInterval(15); '' };

query:
  { @aliases= (); $non_agg_fields= 0; $agg_fields= 0; $skip_aliases= 0; '' } updates_deletes_query { $last_database= undef; $last_table= undef; '' };

updates_deletes_query:
  CREATE OR REPLACE TABLE { 'updates_deletes_tbl'.($prng->int(0,9) ? $prng->int(1,$tables) : ++$tables) } AS SELECT tbl1.*
  FROM updates_deletes_from_list
  updates_deletes_optional_where_clause
  updates_deletes_optional_group_by_clause
  updates_deletes_optional_having_clause
  updates_deletes_optional_order_by_clause
  updates_deletes_optional_limit_clause
  |
  DELETE __ignore(50) /* updates_deletes_select_list */ { if (scalar(@aliases) <= 1) { $delete_list= ($prng->uint16(0,3) ? '' : 'tbl1') } else { $delete_list= (join ', ', @aliases) }; $delete_list }
  FROM { if ($delete_list == '') { $skip_aliases= 1; $last_table } else { 'updates_deletes_from_list' } }
  updates_deletes_optional_where_clause
  |
  ==FACTOR:8==  UPDATE __ignore(50) updates_deletes_from_list
  SET updates_deletes_update_set_list
  updates_deletes_optional_where_clause
  updates_deletes_optional_order_by_clause
  updates_deletes_optional_limit_clause
;

updates_deletes_update_set_list:
  ==FACTOR:2== updates_deletes_update_set_item |
  updates_deletes_update_set_list, updates_deletes_update_set_item
;

updates_deletes_update_set_item:
  { $alias= $prng->int(1,scalar(@aliases)); $last_table= $aliases[$alias-1]; 'tbl'.$alias } . _field = updates_deletes_update_set_field_or_value ;

updates_deletes_update_set_field_or_value:
  { $alias= $prng->int(1,scalar(@aliases)); $last_table= $aliases[$alias-1]; 'tbl'.$alias } . _field |
  _basics_any_value
;

updates_deletes_select_list:
  updates_deletes_select_item | updates_deletes_select_item, updates_deletes_select_list;

updates_deletes_select_item:
  updates_deletes_new_or_existing_alias.* |
  ==FACTOR:5== updates_deletes_new_or_existing_alias._field AS { 'fld'.(++$non_agg_fields) } |
# TODO
# (subquery)
# literal
  ==FACTOR:0.1== _basics_any_value AS { 'fld'.(++$non_agg_fields) } |
  updates_deletes_aggregate_item
;

# TODO:
updates_deletes_aggregate_item:
  COUNT(*) AS { 'agg'.(++$agg_fields) }
;

updates_deletes_new_or_existing_alias:
# The probability of using a new table depends on how many tables are already picked
  { $alias= $prng->int(1,scalar(@aliases)+1); if ($alias > scalar(@aliases)) { $last_database= $prng->arrayElement($updates_deletes_databases); push @aliases, $last_database.'.'.$prng->arrayElement($executors->[0]->tables($last_database)) }; $last_table= $aliases[$alias-1]; ($skip_aliases ? '' : 'tbl'.$alias) } ;

updates_deletes_from_list:
  # We will use a random number of tables, but at least the tables which
  # have already been picked should be there

  # Comma-separated list (simple JOIN)
  updates_deletes_prepare_list_of_tables { join ', ', @{$prng->shuffleArray(\@list_of_tables)} } |

  # JOIN list (with optional ON clauses)
  updates_deletes_prepare_list_of_tables { $joined_tables_num=0; $last_join_type= '' } updates_deletes_join_list
;

updates_deletes_prepare_list_of_tables:
  { @list_of_tables= (); my $num_of_tables= (scalar(@aliases) + $prng->int(0,2)); $num_of_tables=1 unless $num_of_tables; foreach (1..$num_of_tables-scalar(@aliases)) { $last_database= $prng->arrayElement($updates_deletes_databases); push @aliases, $last_database.'.'.$prng->arrayElement($executors->[0]->tables($last_database)) }; foreach my $i (1..scalar(@aliases)) { push @list_of_tables, $aliases[$i-1].' AS tbl'.($i) }; '' }
;

# USING will produce a lot of "unknown column (1054 ER_BAD_FIELD_ERROR) errors
# on random (non-uniform) data structures.
# It will only work when joined tables happen to have the same column
updates_deletes_using_condition:
  { $last_table= $aliases[$joined_tables_num-1]; '' } USING (updates_deletes_using_list)
;

updates_deletes_using_list:
  ==FACTOR:5== _field |
  updates_deletes_using_list, _field
;

# NATURAL JOIN may produce "Column is ambiguous (1052 ER_NON_UNIQ_ERROR) errors
updates_deletes_join_list:
  { if ($joined_tables_num) { $last_join_type=$prng->arrayElement(['INNER JOIN','STRAIGHT_JOIN','LEFT JOIN','RIGHT JOIN','NATURAL JOIN']) } else { '' } } { $joined_tables_num++; $table_to_join=shift @list_of_tables } updates_deletes_possible_join_condition { if (scalar @list_of_tables) { 'updates_deletes_join_list' } else { '' } };

updates_deletes_possible_join_condition:
  { if ($last_join_type eq 'INNER JOIN') { 'updates_deletes_optional_on_or_using' } elsif ($last_join_type eq 'STRAIGHT_JOIN') { 'updates_deletes_optional_on' } elsif ($last_join_type eq 'NATURAL JOIN') { '' } elsif ($last_join_type) { 'updates_deletes_join_on_clause' } };

updates_deletes_optional_on_or_using:
  |
  ==FACTOR:5== updates_deletes_join_on_clause |
  updates_deletes_using_condition
;

updates_deletes_optional_on:
  | updates_deletes_join_on_clause;

updates_deletes_join_on_clause:
  ON (updates_deletes_join_on_list) ;

updates_deletes_join_on_list:
  ==FACTOR:5== updates_deletes_join_condition __and_x_or updates_deletes_join_condition |
  updates_deletes_join_condition __and_x_or updates_deletes_join_on_list |
  (updates_deletes_join_on_list) __and_x_or updates_deletes_join_condition
;

# TODO
updates_deletes_join_condition:
  updates_deletes_join_on_argument _basics_comparison_operator updates_deletes_join_on_argument;

######
# JOIN ON condition should only use tables/aliases which have already been joined

updates_deletes_join_on_argument:
  ==FACTOR:10== { $alias= $prng->int(1,$joined_tables_num); $last_table= $aliases[$alias-1]; 'tbl'.$alias.'.' } _field |
  _basics_any_value
;

######
# Unlike JOIN ON condition, WHERE can use any tables/aliases from the FROM list

updates_deletes_optional_where_clause:
  |
  ==FACTOR:10== WHERE updates_deletes_where_list
;

updates_deletes_where_list:
  ==FACTOR:5== updates_deletes_where_condition __and_x_or updates_deletes_where_condition |
  updates_deletes_where_condition __and_x_or updates_deletes_where_list |
  (updates_deletes_where_list) __and_x_or updates_deletes_where_condition
;

# TODO
updates_deletes_where_condition:
  ==FACTOR:5== updates_deletes_where_argument _basics_comparison_operator updates_deletes_where_argument |
  updates_deletes_where_argument IS __not(30) NULL
;

updates_deletes_where_argument:
  ==FACTOR:5== { $alias= $prng->int(1,scalar(@aliases)); $last_table= $aliases[$alias-1]; ( $skip_aliases ? '' : 'tbl'.$alias.'.' ) } _field |
  _basics_any_value
;

updates_deletes_optional_group_by_clause:
  { if ($non_agg_fields and $agg_fields) { 'updates_deletes_group_by' } else { '' } }
;

# We will use normal decent GROUP BY <all non-aggregate fields> 
updates_deletes_group_by:
  GROUP BY { @group_by_list= (); foreach $f (1..$non_agg_fields) { push @group_by_list, 'fld'.$f }; join ', ', @{$prng->shuffleArray(\@group_by_list)} }
;

updates_deletes_optional_having_clause:
  ==FACTOR:5== |
  { if ($agg_fields or $non_agg_fields) { @having_list= (); foreach my $f (1..$non_agg_fields) { push @having_list, 'fld'.$f }; foreach my $f (1..$agg_fields) { push @having_list, 'agg'.$f }; @having_list=  @{$prng->shuffleArray(\@having_list)}; 'updates_deletes_having_clause' } else { '' } }
;

updates_deletes_having_clause:
  HAVING updates_deletes_having_list ;

updates_deletes_having_list:
  ==FACTOR:5== updates_deletes_having_condition __and_x_or updates_deletes_having_condition |
  updates_deletes_having_condition __and_x_or updates_deletes_having_list |
  (updates_deletes_having_list) __and_x_or updates_deletes_having_condition
;

# TODO
updates_deletes_having_condition:
  ==FACTOR:5== updates_deletes_having_argument _basics_comparison_operator updates_deletes_having_argument |
  updates_deletes_having_argument IS __not(30) NULL
;

updates_deletes_having_argument:
  ==FACTOR:2== { $prng->arrayElement(\@having_list) } |
  _basics_any_value
;

updates_deletes_optional_order_by_clause:
  ==FACTOR:2== |
  ORDER BY { if ($agg_fields or $non_agg_fields) { @order_by_fields= (); foreach my $f (1..$non_agg_fields) { push @order_by_fields, 'fld'.$f }; foreach my $f (1..$agg_fields) { push @order_by_fields, 'agg'.$f }; @order_by_fields=  @{$prng->shuffleArray(\@order_by_fields)}[0..$prng->int(0,scalar(@order_by_fields)-1)]; 'updates_deletes_order_by_list' } else { '1' } }
;

updates_deletes_order_by_list:
  { @order_by_list= (); foreach my $f (@order_by_fields) { push @order_by_list, $f . $prng->arrayElement(['',' ASC',' DESC']) }; join ', ', @order_by_list };

updates_deletes_optional_limit_clause:
  |
  LIMIT _digit |
#  LIMIT _digit, _digit |
#  LIMIT _digit OFFSET _digit
;
