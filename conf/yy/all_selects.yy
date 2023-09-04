# Copyright (c) 2021, 2022, MariaDB Corporation.
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

#include <conf/yy/include/basics.inc>

query:
  { @aliases= (); $non_agg_fields= 0; $agg_fields= 0; _set_db('ANY') } all_selects_query ;

all_selects_query:
  ==FACTOR:4== all_selects_generated_query |
  all_selects_extra_query
;

all_selects_extra_query:
  # From table elimination task
  { %extra_tables=(); '' } SELECT t1.* FROM _table { $extra_tables{t1}= [$last_database,$last_table]; 't1' } LEFT JOIN (SELECT /* _table */ { $extra_tables{t11} = [$last_database,$last_table]; '' } t11._field AS fld1, COUNT(*) AS cnt FROM { join '.', @{$extra_tables{t11}} } t11 LEFT JOIN _table { $extra_tables{t12}= [$last_database,$last_table]; 't12' } ON t12._field = { ($last_database,$last_table)= @{$extra_tables{t11}}; '' } t11._field GROUP BY fld1 ) sq ON sq.fld1= { ($last_database,$last_table)= @{$extra_tables{t1}}; '' } t1._field
;

all_selects_generated_query:
  SELECT all_selects_select_list
  FROM all_selects_from_list
  all_selects_optional_where_clause
  all_selects_optional_group_by_clause
  all_selects_optional_having_clause
  all_selects_optional_order_by_clause
  all_selects_optional_limit_clause
  __for_update(10)
;

all_selects_select_list:
  all_selects_select_item | all_selects_select_item, all_selects_select_list;

all_selects_select_item:
  all_selects_new_or_existing_alias.* |
  ==FACTOR:5== all_selects_new_or_existing_alias._field AS { 'fld'.(++$non_agg_fields) } |
# TODO
# (subquery)
# literal
  ==FACTOR:0.1== _basics_any_value AS { 'fld'.(++$non_agg_fields) } |
  all_selects_aggregate_item
;

# TODO:
all_selects_aggregate_item:
  COUNT(*) AS { 'agg'.(++$agg_fields) }
;

all_selects_new_or_existing_alias:
# The probability of using a new table depends on how many tables are already picked
  { $alias= $prng->int(1,scalar(@aliases)+1); if ($alias > scalar(@aliases)) { push @aliases, $prng->arrayElement($executors->[0]->metaTables($work_database)) }; ($last_database,$last_table)= @{$aliases[$alias-1]}; 'tbl'.$alias } ;

all_selects_from_list:
  # We will use a random number of tables, but at least the tables which
  # have already been picked should be there

  # Comma-separated list (simple JOIN)
  all_selects_prepare_list_of_tables { join ',', @{$prng->shuffleArray(\@list_of_tables)} } |

  # JOIN list (with optional ON clauses)
  all_selects_prepare_list_of_tables { $joined_tables_num=0; $last_join_type= '' } all_selects_join_list
;

all_selects_prepare_list_of_tables:
  { @list_of_tables= (); my $num_of_tables= (scalar(@aliases) + $prng->int(0,2)); $num_of_tables=1 unless $num_of_tables; foreach (1..$num_of_tables-scalar(@aliases)) { push @aliases, $prng->arrayElement($executors->[0]->metaTables($work_database)) }; foreach my $i (1..scalar(@aliases)) { push @list_of_tables, (join '.', @{$aliases[$i-1]}).' AS tbl'.($i) }; '' }
;

# USING will produce a lot of "unknown column (1054 ER_BAD_FIELD_ERROR) errors
# on random (non-uniform) data structures.
# It will only work when joined tables happen to have the same column
all_selects_using_condition:
  { ($last_database,$last_table)= @{$aliases[$joined_tables_num-1]}; '' } USING (all_selects_using_list)
;

all_selects_using_list:
  ==FACTOR:5== _field |
  all_selects_using_list, _field
;

# NATURAL JOIN may produce "Column is ambiguous (1052 ER_NON_UNIQ_ERROR) errors
all_selects_join_list:
  { if ($joined_tables_num) { $last_join_type=$prng->arrayElement(['INNER JOIN','STRAIGHT_JOIN','LEFT JOIN','RIGHT JOIN','NATURAL JOIN']) } else { '' } } { $joined_tables_num++; $table_to_join=shift @list_of_tables } all_selects_possible_join_condition { if (scalar @list_of_tables) { 'all_selects_join_list' } else { '' } };

all_selects_possible_join_condition:
  { if ($last_join_type eq 'INNER JOIN') { 'all_selects_optional_on_or_using' } elsif ($last_join_type eq 'STRAIGHT_JOIN') { 'all_selects_optional_on' } elsif ($last_join_type eq 'NATURAL JOIN') { '' } elsif ($last_join_type) { 'all_selects_join_on_clause' } };

all_selects_optional_on_or_using:
  |
  ==FACTOR:5== all_selects_join_on_clause |
  all_selects_using_condition
;

all_selects_optional_on:
  | all_selects_join_on_clause;

all_selects_join_on_clause:
  ON (all_selects_join_on_list) ;

all_selects_join_on_list:
  ==FACTOR:5== all_selects_join_condition __and_x_or all_selects_join_condition |
  all_selects_join_condition __and_x_or all_selects_join_on_list |
  (all_selects_join_on_list) __and_x_or all_selects_join_condition
;

# TODO
all_selects_join_condition:
  all_selects_join_on_argument _basics_comparison_operator all_selects_join_on_argument;

######
# JOIN ON condition should only use tables/aliases which have already been joined

all_selects_join_on_argument:
  ==FACTOR:10== { $alias= $prng->int(1,$joined_tables_num); ($last_database,$last_table)= @{$aliases[$alias-1]}; 'tbl'.$alias.'.' } _field |
  _basics_any_value
;

######
# Unlike JOIN ON condition, WHERE can use any tables/aliases from the FROM list

all_selects_optional_where_clause:
  |
  ==FACTOR:10== WHERE all_selects_where_list
;

all_selects_where_list:
  ==FACTOR:5== all_selects_where_condition __and_x_or all_selects_where_condition |
  all_selects_where_condition __and_x_or all_selects_where_list |
  (all_selects_where_list) __and_x_or all_selects_where_condition
;

# TODO
all_selects_where_condition:
  ==FACTOR:5== all_selects_where_argument _basics_comparison_operator all_selects_where_argument |
  all_selects_where_argument IS __not(30) NULL
;

all_selects_where_argument:
  ==FACTOR:5== { $alias= $prng->int(1,scalar(@aliases)); ($last_database,$last_table)= @{$aliases[$alias-1]}; 'tbl'.$alias.'.' } _field |
  _basics_any_value
;

all_selects_optional_group_by_clause:
  { if ($non_agg_fields and $agg_fields) { 'all_selects_group_by' } else { '' } }
;

# We will use normal decent GROUP BY <all non-aggregate fields>
all_selects_group_by:
  GROUP BY { @group_by_list= (); foreach $f (1..$non_agg_fields) { push @group_by_list, 'fld'.$f }; join ', ', @{$prng->shuffleArray(\@group_by_list)} }
;

all_selects_optional_having_clause:
  ==FACTOR:5== |
  { if ($agg_fields or $non_agg_fields) { @having_list= (); foreach my $f (1..$non_agg_fields) { push @having_list, 'fld'.$f }; foreach my $f (1..$agg_fields) { push @having_list, 'agg'.$f }; @having_list=  @{$prng->shuffleArray(\@having_list)}; 'all_selects_having_clause' } else { '' } }
;

all_selects_having_clause:
  HAVING all_selects_having_list ;

all_selects_having_list:
  ==FACTOR:5== all_selects_having_condition __and_x_or all_selects_having_condition |
  all_selects_having_condition __and_x_or all_selects_having_list |
  (all_selects_having_list) __and_x_or all_selects_having_condition
;

# TODO
all_selects_having_condition:
  ==FACTOR:5== all_selects_having_argument _basics_comparison_operator all_selects_having_argument |
  all_selects_having_argument IS __not(30) NULL
;

all_selects_having_argument:
  ==FACTOR:2== { $prng->arrayElement(\@having_list) } |
  _basics_any_value
;

all_selects_optional_order_by_clause:
  ==FACTOR:2== |
  ORDER BY { if ($agg_fields or $non_agg_fields) { @order_by_fields= (); foreach my $f (1..$non_agg_fields) { push @order_by_fields, 'fld'.$f }; foreach my $f (1..$agg_fields) { push @order_by_fields, 'agg'.$f }; @order_by_fields=  @{$prng->shuffleArray(\@order_by_fields)}[0..$prng->int(0,scalar(@order_by_fields)-1)]; 'all_selects_order_by_list' } else { '1' } }
;

all_selects_order_by_list:
  { @order_by_list= (); foreach my $f (@order_by_fields) { push @order_by_list, $f . $prng->arrayElement(['',' ASC',' DESC']) }; join ', ', @order_by_list };

all_selects_optional_limit_clause:
  |
  LIMIT _digit |
  LIMIT _digit, _digit |
  LIMIT _digit OFFSET _digit
;
