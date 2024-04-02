# Copyright (c) 2008, 2011 Oracle and/or its affiliates. All rights reserved.
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

# **NOTE** Joins for this grammar are currently not working as intended.
# For example, if we have tables 1, 2, and 3, we end up with ON conditions that 
# only involve tables 2 and 3.
# This will be fixed, but initial attempts at altering this had a negative 
# impact on the coverage the test was providing.  To be fixed when scheduling 
# permits.  We are still seeing significant coverage with the grammar as-is.

################################################################################
# optimizer_subquery.yy:  Random Query Generator grammar for testing subquery  #
#                    optimizations.  This grammar *should* hit the             # 
#                    optimizations listed here:                                #
#                    https://inside.mysql.com/wiki/Optimizer_grammar_worksheet #
# see:  WL#5006 Random Query Generator testing of Azalea Optimizer- subqueries #
#       https://intranet.mysql.com/worklog/QA-Sprint/?tid=5006                 #
#                                                                              #
# recommendations:                                                             #
#       queries: 10k+.  We can see a lot with lower values, but over 10k is    #
#                best.  The intersect optimization happens with low frequency  #
#                so larger values help us to hit it at least some of the time  #
#       engines: MyISAM *and* Innodb.  Certain optimizations are only hit with #
#                one engine or another and we should use both to ensure we     #
#                are getting maximum coverage                                  #
#       Validators:  ResultsetComparatorSimplify                               #
#                      - used on server-server comparisons                     #
#                    Transformer - used on a single server                     #
#                      - creates equivalent versions of a single query         # 
#                    SelectStability - used on a single server                 #
#                      - ensures the same query produces stable result sets    #
################################################################################

thread1_init:
	analyze_tables | analyze_tables | ;

analyze_tables:
	{ say "Analyzing tables..."; "" }
	ANALYZE A; ANALYZE B; ANALYZE C; ANALYZE D; ANALYZE E;
	ANALYZE AA; ANALYZE BB; ANALYZE CC ANALYZE DD ;

################################################################################
# The perl code in {} helps us with bookkeeping for writing more sensible      #
# queries.  We need to keep track of these items to ensure we get interesting  #
# and stable queries that find bugs rather than wondering if our query is      #
# dodgy.                                                                       #
################################################################################
query:
	{ $gby = "";  @int_nonaggregates = () ; @nonaggregates = () ; @aggregates = () ; $t1 = 1 ; @st1 = (); $tables = 0 ; $fields = 0 ; @ssqt1 = () ; $sqt1 = 1 ; $subquery_idx=0 ; @scsqt1 = () ; $csqt1 = 1 ; $child_subquery_idx=0 ; $max_table_id = $prng->int(1,3); "" }
	hints main_select ;

################################################################################
# YB: Randomly add a hint set that encourages Batched Nested Loop plans
################################################################################

hints:
  | | | |
  /*+ disable_hashmerge */ |
  /*+ disable_seqscan disable_hashagg disable_sort */ |
  /*+ disable_seqscan disable_hashagg disable_sort disable_hashmerge */ ;

disable_hashmerge: Set(enable_hashjoin off) Set(enable_mergejoin off) Set(enable_material off) ;

disable_seqscan: Set(enable_seqscan OFF) ;

disable_sort: | | Set(enable_sort OFF) ;

disable_hashagg: | | Set(enable_hashagg OFF) ;


main_select:
#	explain_extended 
    SELECT distinct straight_join select_option select_list
	FROM join_list
	where_clause
	group_by_clause
        having_clause
	order_by_clause |
#	explain_extended 
    SELECT noagg_select_list
	FROM join_list
	where_clause
	any_item_order_by_clause ;

explain_extended:
    | | | | | | | | | explain_extended2 ;

explain_extended2: | | | | EXPLAIN | EXPLAIN EXTENDED ; 
       
distinct: DISTINCT | | | | | | | | | ;

select_option:  | | | | | | | | | | | SQL_SMALL_RESULT ;

straight_join:  | | | | | | | | | | | STRAIGHT_JOIN ;

select_list:
	new_select_item |
	new_select_item , select_list |
        new_select_item , select_list ;

noagg_select_list:
	noagg_new_select_item |
	noagg_new_select_item , noagg_select_list |
        noagg_new_select_item , noagg_select_list ;

join_list:
	{ join("", expand($rule_counters,$rule_invariants, "join_list_".$max_table_id)) } ;

################################################################################
# this limits us to 2 and 3 table joins / can use it if we hit                 #
# too many mega-join conditions which take too long to run                     #
################################################################################
join_list_1:
        new_table_item | new_table_item | join_list_2 ;

join_list_2:
	( new_table_item join_type new_table_item ON (join_condition_item ) ) |
	( new_table_item join_type new_table_item ON (join_condition_item ) ) |
	join_list_3 ;

join_list_3:
        ( new_table_item
	      join_type new_table_item ON (join_condition_item )
	      join_type new_table_item ON (join_condition_item ) ) |
        ( new_table_item join_type ( ( { push @st1, $t1; $t1 = $tables + 1; "" } new_table_item join_type new_table_item ON (join_condition_item ) { $t1 = pop @st1; "" } ) ) ON (join_condition_item ) ) ;

join_list_disabled:
################################################################################
# preventing deep join nesting for run time / table access methods are more    #
# important here - join.yy can provide deeper join coverage                    #
# Enabling this / swapping out with join_list above can produce some           #
# time-consuming queries.                                                      #
################################################################################
        ( new_table_item join_type join_list ON (join_condition_item ) ) ;

join_type:
	INNER JOIN | left_right outer JOIN | STRAIGHT_JOIN ;  

join_condition_item:
    current_table_item . int_indexed = previous_table_item . int_field_name on_subquery |
    current_table_item . int_field_name = previous_table_item . int_indexed on_subquery |
    current_table_item . `col_varchar_key` = previous_table_item . char_field_name on_subquery |
    current_table_item . char_field_name = previous_table_item . `col_varchar_key` on_subquery |
    current_table_item . int_indexed = existing_table_item . int_field_name on_subquery |
    current_table_item . int_field_name = existing_table_item . int_indexed on_subquery |
    current_table_item . `col_varchar_key` = existing_table_item . char_field_name on_subquery |
    current_table_item . char_field_name = existing_table_item . `col_varchar_key` on_subquery ;

on_subquery:
    |||||||||||||||||||| { $subquery_idx += 1 ; $subquery_tables=0 ; $max_subquery_table_id = $prng->int(1,3) ; ""} and_or general_subquery ;


left_right:
	LEFT | RIGHT ;

outer:
	| OUTER ;

where_clause:
         WHERE ( where_subquery ) and_or where_list ;


where_list:
	generic_where_list |
        range_predicate1_list | range_predicate2_list |
        range_predicate1_list and_or generic_where_list |
        range_predicate2_list and_or generic_where_list ; 


generic_where_list:
        where_item | where_item |
        ( where_list and_or where_item ) |
        ( where_item and_or where_list ) ;

not:
	| | | NOT;

where_item:
        where_subquery  |  
        table1 . int_field_name comparison_operator existing_table_item . int_field_name  |
	existing_table_item . char_field_name comparison_operator _char  |
        existing_table_item . char_field_name comparison_operator existing_table_item . char_field_name |
        table1 . _field IS not NULL |
        table1 . int_field_name comparison_operator existing_table_item . int_field_name  |
	existing_table_item . char_field_name comparison_operator _char  |
        existing_table_item . char_field_name comparison_operator existing_table_item . char_field_name |
        table1 . _field IS not NULL ;

################################################################################
# subquery rules
################################################################################

where_subquery:
    { $subquery_idx += 1 ; $subquery_tables=0 ; $max_subquery_table_id = $prng->int(1,3); ""} subquery_type ;

subquery_type:
    general_subquery | special_subquery ;

general_subquery:
    existing_table_item . int_field_name comparison_operator  int_single_value_subquery  |
    existing_table_item . char_field_name comparison_operator char_single_value_subquery |
    existing_table_item . int_field_name membership_operator  int_single_member_subquery  |
    existing_table_item . char_field_name membership_operator  char_single_member_subquery  |
    ( existing_table_item . int_field_name , existing_table_item . int_field_name ) membership_operator int_double_member_subquery |
    ( existing_table_item . char_field_name , existing_table_item . char_field_name ) membership_operator char_double_member_subquery |
    ( current_table_item . int_field_name , existing_table_item . int_field_name ) membership_operator int_double_member_subquery |
    ( current_table_item . char_field_name , existing_table_item . char_field_name ) membership_operator char_double_member_subquery |
    ( existing_table_item . char_field_name , existing_table_item . int_field_name ) membership_operator char_int_double_member_subquery |
    ( current_table_item . int_field_name , existing_table_item . int_field_name ) comparison_operator int_double_member_one_row_subquery |
    ( current_table_item . char_field_name , existing_table_item . char_field_name ) comparison_operator char_double_member_one_row_subquery |
    ( existing_table_item . char_field_name , existing_table_item . int_field_name ) comparison_operator char_int_double_member_one_row_subquery |
    ( _digit, _digit ) membership_operator int_double_member_subquery |
    ( _char, _char ) membership_operator char_double_member_subquery |
    existing_table_item . int_field_name membership_operator int_single_union_subquery |
    existing_table_item . char_field_name membership_operator char_single_union_subquery ;

general_subquery_union_test_disabled:
    existing_table_item . char_field_name comparison_operator all_any char_single_union_subquery_disabled |
    existing_table_item . int_field_name comparison_operator all_any int_single_union_subquery_disabled ;

special_subquery:
    not EXISTS ( int_single_member_subquery ) |
    not EXISTS ( char_single_member_subquery ) |
    not EXISTS int_correlated_subquery |
    not EXISTS char_correlated_subquery  | 
    existing_table_item . int_field_name membership_operator  int_correlated_subquery  |
    existing_table_item . char_field_name membership_operator char_correlated_subquery |
  ## the ones below need some more scoping tweaks to avoid missing table in FROM-clause error
  # int_single_value_subquery membership_operator  int_correlated_subquery |
  # char_single_value_subquery membership_operator char_correlated_subquery |
    int_single_value_subquery IS not NULL |
    char_single_value_subquery IS not NULL ;

int_single_value_subquery:
    ( SELECT distinct select_option aggregate subquery_table_alias . int_field_name ) AS { "SUBQUERY".$subquery_idx."_field1" } 
      subquery_body ) |
    ( SELECT distinct select_option aggregate subquery_table_alias . int_field_name ) AS { "SUBQUERY".$subquery_idx."_field1" } 
      subquery_body ) |
    ( SELECT select_option subquery_table_alias . int_field_name AS { "SUBQUERY".$subquery_idx."_field1" }
      subquery_body ORDER BY 1 LIMIT 1 ) |
    ( SELECT select_option subquery_table_alias . int_field_name AS { "SUBQUERY".$subquery_idx."_field1" }
      subquery_body ORDER BY 1 LIMIT 1 ) |
    ( SELECT _digit FROM DUMMY ) ;

char_single_value_subquery:
    ( SELECT distinct select_option any_type_aggregate subquery_table_alias . char_field_name ) AS { "SUBQUERY".$subquery_idx."_field1" } 
      subquery_body ) |
    ( SELECT distinct select_option any_type_aggregate subquery_table_alias . char_field_name ) AS { "SUBQUERY".$subquery_idx."_field1" } 
      subquery_body ) |
    ( SELECT distinct select_option subquery_table_alias . char_field_name AS { "SUBQUERY".$subquery_idx."_field1" }
      subquery_body ORDER BY 1 LIMIT 1 ) |
    ( SELECT distinct select_option subquery_table_alias . char_field_name AS { "SUBQUERY".$subquery_idx."_field1" }
      subquery_body ORDER BY 1 LIMIT 1 ) |
    ( SELECT _char FROM DUMMY ) ;
   
int_single_member_subquery:
    ( SELECT distinct select_option subquery_table_alias . int_field_name AS { "SUBQUERY".$subquery_idx."_field1" }
      subquery_body 
      single_subquery_group_by
      subquery_having ) |
    ( SELECT distinct select_option aggregate subquery_table_alias . int_field_name ) AS { "SUBQUERY".$subquery_idx."_field1" }
      subquery_body 
      any_field_subquery_group_by
      subquery_having ) |
    ( SELECT _digit FROM DUMMY ) ;

char_single_member_subquery:
    ( SELECT distinct select_option subquery_table_alias . char_field_name AS { "SUBQUERY".$subquery_idx."_field1" }
     subquery_body
     single_subquery_group_by
     subquery_having) |
    ( SELECT distinct select_option any_type_aggregate subquery_table_alias . char_field_name ) AS { "SUBQUERY".$subquery_idx."_field1" }
     subquery_body
     any_field_subquery_group_by
     subquery_having) ;

int_single_union_subquery:
    (  SELECT _digit FROM DUMMY  UNION all_distinct  SELECT _digit FROM DUMMY )  ;

char_single_union_subquery:
    (  SELECT _char FROM DUMMY UNION all_distinct  SELECT _char FROM DUMMY )  ;

int_single_union_subquery_disabled:
    int_single_member_subquery   UNION all_distinct  int_single_member_subquery ;

char_single_union_subquery_disabled:
    char_single_member_subquery   UNION all_distinct char_single_member_subquery  ;

int_double_member_subquery:
    ( SELECT distinct select_option subquery_table_alias . int_field_name AS { "SUBQUERY".$subquery_idx."_field1" } , 
      subquery_table_alias . int_field_name AS { SUBQUERY.$subquery_idx."_field2" }
      subquery_body 
      double_subquery_group_by
      subquery_having ) |
    ( SELECT distinct select_option subquery_table_alias . int_field_name AS { "SUBQUERY".$subquery_idx."_field1" } , 
      aggregate subquery_table_alias . int_field_name ) AS { SUBQUERY.$subquery_idx."_field2" }
      subquery_body 
      required_single_subquery_group_by
      subquery_having ) |
    (  SELECT _digit , _digit FROM DUMMY  UNION all_distinct  SELECT _digit, _digit FROM DUMMY ) ;

char_double_member_subquery:
   ( SELECT distinct select_option subquery_table_alias . char_field_name AS { "SUBQUERY".$subquery_idx."_field1" } ,
     subquery_table_alias . char_field_name AS { SUBQUERY.$subquery_idx."_field2" }
     subquery_body
     double_subquery_group_by
     subquery_having ) |
   ( SELECT distinct select_option subquery_table_alias . char_field_name AS { "SUBQUERY".$subquery_idx."_field1" } ,
     any_type_aggregate subquery_table_alias . char_field_name ) AS { SUBQUERY.$subquery_idx."_field2" }
     subquery_body
     required_single_subquery_group_by
     subquery_having ) |
   (  SELECT _char , _char FROM DUMMY UNION all_distinct  SELECT _char , _char FROM DUMMY ) ;

char_int_double_member_subquery:
    ( SELECT distinct select_option subquery_table_alias . char_field_name AS { "SUBQUERY".$subquery_idx."_field1" } , 
      subquery_table_alias . int_field_name AS { SUBQUERY.$subquery_idx."_field2" }
      subquery_body 
      double_subquery_group_by
      subquery_having ) |
    ( SELECT distinct select_option subquery_table_alias . char_field_name AS { "SUBQUERY".$subquery_idx."_field1" } , 
      aggregate subquery_table_alias . int_field_name ) AS { SUBQUERY.$subquery_idx."_field2" }
      subquery_body 
      required_single_subquery_group_by
      subquery_having ) |
    (  SELECT _char , _digit FROM DUMMY  UNION all_distinct  SELECT _char, _digit FROM DUMMY ) ;

int_correlated_subquery:
    ( SELECT distinct select_option subquery_table_alias . int_field_name AS { "SUBQUERY".$subquery_idx."_field1" }
      FROM subquery_join_list 
      correlated_subquery_where_clause ) |
    int_scalar_correlated_subquery ;

char_correlated_subquery:
    ( SELECT distinct select_option subquery_table_alias . char_field_name AS { "SUBQUERY".$subquery_idx."_field1" }
      FROM subquery_join_list 
      correlated_subquery_where_clause ) |
    char_scalar_correlated_subquery ;

int_scalar_correlated_subquery:
    ( SELECT distinct select_option aggregate subquery_table_alias . int_field_name ) AS { "SUBQUERY".$subquery_idx."_field1" }
      FROM subquery_join_list 
      correlated_subquery_where_clause ) |
    ( SELECT distinct select_option subquery_table_alias . int_field_name AS { "SUBQUERY".$subquery_idx."_field1" }
      FROM subquery_join_list 
      correlated_subquery_where_clause ORDER BY 1 LIMIT 1 ) ;

char_scalar_correlated_subquery:
    ( SELECT distinct select_option any_type_aggregate subquery_table_alias . char_field_name ) AS { "SUBQUERY".$subquery_idx."_field1" }
      FROM subquery_join_list 
      correlated_subquery_where_clause ) |
    ( SELECT distinct select_option subquery_table_alias . char_field_name AS { "SUBQUERY".$subquery_idx."_field1" }
      FROM subquery_join_list 
      correlated_subquery_where_clause ORDER BY 1 LIMIT 1 ) ;

int_double_member_one_row_subquery:
    ( SELECT distinct subquery_table_alias . int_field_name AS { "SUBQUERY".$subquery_idx."_field1" } , 
      subquery_table_alias . int_field_name AS { SUBQUERY.$subquery_idx."_field2" }
      subquery_body 
      double_subquery_group_by
      subquery_having
      ORDER BY 1, 2 LIMIT 1 ) |
    ( SELECT distinct subquery_table_alias . int_field_name AS { "SUBQUERY".$subquery_idx."_field1" } , 
      aggregate subquery_table_alias . int_field_name ) AS { SUBQUERY.$subquery_idx."_field2" }
      subquery_body 
      required_single_subquery_group_by
      subquery_having
      ORDER BY 1, 2 LIMIT 1 ) ;

char_double_member_one_row_subquery:
   ( SELECT distinct select_option subquery_table_alias . char_field_name AS { "SUBQUERY".$subquery_idx."_field1" } ,
     subquery_table_alias . char_field_name AS { SUBQUERY.$subquery_idx."_field2" }
     subquery_body
     double_subquery_group_by
     subquery_having
     ORDER BY 1, 2 LIMIT 1 ) |
   ( SELECT distinct select_option subquery_table_alias . char_field_name AS { "SUBQUERY".$subquery_idx."_field1" } ,
     any_type_aggregate subquery_table_alias . char_field_name ) AS { SUBQUERY.$subquery_idx."_field2" }
     subquery_body
     required_single_subquery_group_by
     subquery_having
     ORDER BY 1, 2 LIMIT 1 ) ;

char_int_double_member_one_row_subquery:
    ( SELECT distinct subquery_table_alias . char_field_name AS { "SUBQUERY".$subquery_idx."_field1" } , 
      subquery_table_alias . int_field_name AS { SUBQUERY.$subquery_idx."_field2" }
      subquery_body 
      double_subquery_group_by
      subquery_having
      ORDER BY 1, 2 LIMIT 1 ) |
    ( SELECT distinct subquery_table_alias . char_field_name AS { "SUBQUERY".$subquery_idx."_field1" } , 
      aggregate subquery_table_alias . int_field_name ) AS { SUBQUERY.$subquery_idx."_field2" }
      subquery_body 
      required_single_subquery_group_by
      subquery_having
      ORDER BY 1, 2 LIMIT 1 ) ;

subquery_body:
      FROM subquery_join_list
      subquery_where_clause ;

subquery_where_clause:
    | | WHERE subquery_where_list ;

correlated_subquery_where_clause:
    WHERE correlated_subquery_where_list ;

correlated_subquery_where_list:
    correlated_subquery_where_item |
    correlated_subquery_where_item and_or correlated_subquery_where_item |
    correlated_subquery_where_item and_or subquery_where_item ;

correlated_subquery_where_item:
    subquery_existing_table_item . int_field_name comparison_operator existing_table_item . int_field_name |
    subquery_existing_table_item . char_field_name comparison_operator existing_table_item . char_field_name ;

subquery_where_list:
    subquery_where_item | subquery_where_item | subquery_where_item |
    ( subquery_where_item and_or subquery_where_item ) ;

subquery_where_item:
   subquery_existing_table_item . int_field_name comparison_operator _digit |
   subquery_existing_table_item . char_field_name comparison_operator _char |
   subquery_existing_table_item . int_field_name comparison_operator subquery_existing_table_item . int_field_name |
   subquery_existing_table_item . char_field_name comparison_operator subquery_existing_table_item . char_field_name |
   child_subquery ;

subquery_join_list:
    { join("", expand($rule_counters,$rule_invariants, "subquery_join_list_".$max_subquery_table_id)) } ;

subquery_join_list_1:
   subquery_new_table_item | subquery_new_table_item | subquery_join_list_2 ;

subquery_join_list_2:
   ( subquery_new_table_item join_type subquery_new_table_item ON (subquery_join_condition_item ) ) |
   ( subquery_new_table_item join_type subquery_new_table_item ON (subquery_join_condition_item ) ) |
    subquery_join_list_3 ;

subquery_join_list_3:
   ( subquery_new_table_item
         join_type subquery_new_table_item ON (subquery_join_condition_item )
         join_type subquery_new_table_item ON (subquery_join_condition_item ) ) |
   ( subquery_new_table_item join_type ( { push @ssqt1, $sqt1; $sqt1 = $subquery_tables + 1; "" } subquery_new_table_item join_type subquery_new_table_item ON (subquery_join_condition_item )  { $sqt1 = pop @ssqt1; "" } ) ON (subquery_join_condition_item ) ) ;

subquery_join_condition_item:
    subquery_current_table_item . int_field_name = subquery_previous_table_item . int_indexed subquery_on_subquery |
    subquery_current_table_item . int_indexed = subquery_previous_table_item . int_field_name subquery_on_subquery |
    subquery_current_table_item . `col_varchar_key` = subquery_previous_table_item . char_field_name subquery_on_subquery |
    subquery_current_table_item . char_field_name = subquery_previous_table_item . `col_varchar_key` subquery_on_subquery |
    subquery_current_table_item . int_field_name = subquery_existing_table_item . int_indexed subquery_on_subquery |
    subquery_current_table_item . int_indexed = subquery_existing_table_item . int_field_name subquery_on_subquery |
    subquery_current_table_item . `col_varchar_key` = subquery_existing_table_item . char_field_name subquery_on_subquery |
    subquery_current_table_item . char_field_name = subquery_existing_table_item . `col_varchar_key` subquery_on_subquery ;

subquery_on_subquery:
    |||||||||||||||||||| { $child_subquery_idx += 1 ; $child_subquery_tables=0 ; $max_child_subquery_table_id = $prng->int(1,3); ""} and_or general_child_subquery ;

required_single_subquery_group_by:
    GROUP BY { SUBQUERY.$subquery_idx."_field1" } ;

single_subquery_group_by:
    | | | | | | | | | required_single_subquery_group_by ;

double_subquery_group_by:
    | | | | | | | | | GROUP BY { SUBQUERY.$subquery_idx."_field1" } ,  { SUBQUERY.$subquery_idx."_field2" } ;

any_field_subquery_group_by:
    | | | GROUP BY existing_table_item . field_name ;

subquery_having: ;

subquery_having_disabled:
    | | | | | | | | | | HAVING subquery_having_list ;

subquery_having_list:
        subquery_having_item |
        subquery_having_item |
	(subquery_having_list and_or subquery_having_item)  ;

subquery_having_item:
	subquery_existing_table_item . int_field_name comparison_operator _digit |
        subquery_existing_table_item . char_field_name comparison_operator _char ;

################################################################################
# Child subquery rules
################################################################################

child_subquery:
    { $child_subquery_idx += 1 ; $child_subquery_tables=0 ; $max_child_subquery_table_id = $prng->int(1,3); ""} child_subquery_type ;

child_subquery_type:
    general_child_subquery | special_child_subquery ;

general_child_subquery:
    subquery_existing_table_item . int_field_name comparison_operator  int_single_value_child_subquery  |
    subquery_existing_table_item . char_field_name comparison_operator char_single_value_child_subquery |
    subquery_existing_table_item . int_field_name membership_operator  int_single_member_child_subquery  |
    subquery_existing_table_item . char_field_name membership_operator  char_single_member_child_subquery  |
    ( subquery_existing_table_item . int_field_name , subquery_existing_table_item . int_field_name ) membership_operator int_double_member_child_subquery |
    ( subquery_existing_table_item . char_field_name , subquery_existing_table_item . char_field_name ) membership_operator char_double_member_child_subquery |
    ( subquery_current_table_item . int_field_name , subquery_existing_table_item . int_field_name ) membership_operator int_double_member_child_subquery |
    ( subquery_current_table_item . char_field_name , subquery_existing_table_item . char_field_name ) membership_operator char_double_member_child_subquery |
    ( _digit, _digit ) membership_operator int_double_member_child_subquery |
    ( _char, _char ) membership_operator char_double_member_child_subquery |
    subquery_existing_table_item . int_field_name membership_operator int_single_union_child_subquery |
    subquery_existing_table_item . char_field_name membership_operator char_single_union_child_subquery ;

special_child_subquery:
    not EXISTS ( int_single_member_child_subquery ) |
    not EXISTS ( char_single_member_child_subquery ) |
    not EXISTS int_correlated_child_subquery |
    not EXISTS char_correlated_child_subquery |
    subquery_existing_table_item . int_field_name membership_operator  int_correlated_child_subquery  |
    subquery_existing_table_item . char_field_name membership_operator char_correlated_child_subquery ;


int_single_value_child_subquery:
    ( SELECT distinct select_option aggregate child_subquery_table_alias . int_field_name ) AS { "CHILD_SUBQUERY".$child_subquery_idx."_field1" } 
      child_subquery_body ) ;

char_single_value_child_subquery:
    ( SELECT distinct select_option any_type_aggregate child_subquery_table_alias . char_field_name ) AS { "CHILD_SUBQUERY".$child_subquery_idx."_field1" } 
      child_subquery_body ) ;
   
int_single_member_child_subquery:
    ( SELECT distinct select_option child_subquery_table_alias . int_field_name AS { "CHILD_SUBQUERY".$child_subquery_idx."_field1" }
      child_subquery_body 
      single_child_subquery_group_by
      child_subquery_having ) ;

int_single_union_child_subquery:
    (  SELECT _digit FROM DUMMY UNION all_distinct  SELECT _digit FROM DUMMY )  ;

int_double_member_child_subquery:
    ( SELECT distinct select_option child_subquery_table_alias . int_field_name AS { "CHILD_SUBQUERY".$child_subquery_idx."_field1" } ,
      child_subquery_table_alias . int_field_name AS { child_subquery.$child_subquery_idx."_field2" }
      child_subquery_body 
      double_child_subquery_group_by
      child_subquery_having ) |
    ( SELECT distinct select_option child_subquery_table_alias . int_field_name AS { "CHILD_SUBQUERY".$child_subquery_idx."_field1" } ,
      aggregate child_subquery_table_alias . int_field_name ) AS { child_subquery.$child_subquery_idx."_field2" }
      child_subquery_body 
      required_single_child_subquery_group_by
      child_subquery_having );

char_single_member_child_subquery:
    ( SELECT distinct select_option child_subquery_table_alias . char_field_name AS { "CHILD_SUBQUERY".$child_subquery_idx."_field1" }
     child_subquery_body
     single_child_subquery_group_by
     child_subquery_having) ;

char_single_union_child_subquery:
    (  SELECT _char FROM DUMMY  UNION all_distinct  SELECT _char FROM DUMMY )  ;

char_double_member_child_subquery:
   ( SELECT distinct select_option child_subquery_table_alias . char_field_name AS { "CHILD_SUBQUERY".$child_subquery_idx."_field1" } ,
     child_subquery_table_alias . char_field_name AS { "CHILD_SUBQUERY".$child_subquery_idx."_field2" }
     child_subquery_body
     double_child_subquery_group_by
     child_subquery_having ) |
   ( SELECT distinct select_option child_subquery_table_alias . char_field_name AS { "CHILD_SUBQUERY".$child_subquery_idx."_field1" } ,
     any_type_aggregate child_subquery_table_alias . char_field_name ) AS { "CHILD_SUBQUERY".$child_subquery_idx."_field2" }
     child_subquery_body
     required_single_child_subquery_group_by
     child_subquery_having );

int_correlated_child_subquery:
    ( SELECT distinct select_option child_subquery_table_alias . int_field_name AS { "CHILD_SUBQUERY".$subquery_idx."_field1" }
      FROM child_subquery_join_list 
      correlated_child_subquery_where_clause ) |
    int_scalar_correlated_child_subquery ;

int_scalar_correlated_child_subquery:
    ( SELECT distinct select_option aggregate child_subquery_table_alias . int_field_name ) AS { "CHILD_SUBQUERY".$subquery_idx."_field1" }
      FROM child_subquery_join_list 
      correlated_child_subquery_where_clause ) |
    ( SELECT distinct select_option child_subquery_table_alias . int_field_name AS { "CHILD_SUBQUERY".$subquery_idx."_field1" }
      FROM child_subquery_join_list 
      correlated_child_subquery_where_clause ORDER BY 1 LIMIT 1 ) ;

char_correlated_child_subquery:
    ( SELECT distinct select_option child_subquery_table_alias . char_field_name AS { "CHILD_SUBQUERY".$subquery_idx."_field1" }
      FROM child_subquery_join_list 
      correlated_child_subquery_where_clause ) |
    char_scalar_correlated_child_subquery ;

char_scalar_correlated_child_subquery:
    ( SELECT distinct select_option child_subquery_table_alias . char_field_name AS { "CHILD_SUBQUERY".$subquery_idx."_field1" }
      FROM child_subquery_join_list 
      correlated_child_subquery_where_clause ) |
    ( SELECT distinct select_option any_type_aggregate child_subquery_table_alias . char_field_name ) AS { "CHILD_SUBQUERY".$subquery_idx."_field1" }
      FROM child_subquery_join_list 
      correlated_child_subquery_where_clause ORDER BY 1 LIMIT 1 ) ;

child_subquery_body:
      FROM child_subquery_join_list
      child_subquery_where_clause ;

child_subquery_where_clause:
    | WHERE child_subquery_where_list ;

correlated_child_subquery_where_clause:
    WHERE correlated_child_subquery_where_list ;

correlated_child_subquery_where_list:
    correlated_child_subquery_where_item | correlated_child_subquery_where_item | correlated_child_subquery_where_item |
    correlated_child_subquery_where_item and_or correlated_child_subquery_where_item |
    correlated_child_subquery_where_item and_or child_subquery_where_item ;

correlated_child_subquery_where_item:
    child_subquery_existing_table_item . int_field_name comparison_operator subquery_existing_table_item . int_field_name |
    child_subquery_existing_table_item . int_field_name comparison_operator subquery_existing_table_item . int_field_name |
    child_subquery_existing_table_item . char_field_name comparison_operator subquery_existing_table_item . char_field_name |
    child_subquery_existing_table_item . char_field_name comparison_operator subquery_existing_table_item . char_field_name |
    child_subquery_existing_table_item . int_field_name comparison_operator outer_table_item . int_field_name |
    child_subquery_existing_table_item . char_field_name comparison_operator outer_table_item . char_field_name ;

outer_table_item:
    { my $oti = (($t1 <= $tables)? "existing_table_item": "subquery_existing_table_item"); join("", expand($rule_counters,$rule_invariants, $oti)) };

child_subquery_where_list:
    child_subquery_where_item | child_subquery_where_item | child_subquery_where_item |
    ( child_subquery_where_item and_or child_subquery_where_item ) ;

child_subquery_where_item:
   child_subquery_existing_table_item . int_field_name comparison_operator _digit |
   child_subquery_existing_table_item . char_field_name comparison_operator _char |
   child_subquery_existing_table_item . int_field_name comparison_operator child_subquery_existing_table_item . int_field_name |
   child_subquery_existing_table_item . char_field_name comparison_operator child_subquery_existing_table_item . char_field_name ;

child_subquery_join_list:
    { join("", expand($rule_counters,$rule_invariants, "child_subquery_join_list_".$max_child_subquery_table_id)) } ;

child_subquery_join_list_1:
   child_subquery_new_table_item | child_subquery_new_table_item | child_subquery_join_list_2 ;

child_subquery_join_list_2:
   ( child_subquery_new_table_item join_type child_subquery_new_table_item ON (child_subquery_join_condition_item ) ) |
   ( child_subquery_new_table_item join_type child_subquery_new_table_item ON (child_subquery_join_condition_item ) ) |
    child_subquery_join_list_3 ;

child_subquery_join_list_3:
   ( child_subquery_new_table_item
         join_type child_subquery_new_table_item ON (child_subquery_join_condition_item )
         join_type child_subquery_new_table_item ON (child_subquery_join_condition_item ) ) |
   ( child_subquery_new_table_item join_type ( ( { push @scsqt1, $csqt1; $csqt1 = $child_subquery_tables + 1; "" } child_subquery_new_table_item join_type child_subquery_new_table_item ON (child_subquery_join_condition_item ) { $csqt1 = pop @scsqt1; "" } ) ) ON (child_subquery_join_condition_item ) ) ;

child_subquery_join_condition_item:
    child_subquery_current_table_item . int_field_name = child_subquery_previous_table_item . int_indexed |
    child_subquery_current_table_item . int_indexed = child_subquery_previous_table_item . int_field_name |
    child_subquery_current_table_item . `col_varchar_key` = child_subquery_previous_table_item . char_field_name |
    child_subquery_current_table_item . char_field_name = child_subquery_previous_table_item . `col_varchar_key` |
    child_subquery_current_table_item . int_field_name = child_subquery_existing_table_item . int_indexed |
    child_subquery_current_table_item . int_indexed = child_subquery_existing_table_item . int_field_name |
    child_subquery_current_table_item . `col_varchar_key` = child_subquery_existing_table_item . char_field_name |
    child_subquery_current_table_item . char_field_name = child_subquery_existing_table_item . `col_varchar_key` ;

required_single_child_subquery_group_by:
    GROUP BY { child_subquery.$child_subquery_idx."_field1" } ;

single_child_subquery_group_by:
    | | | | | | | | | required_single_child_subquery_group_by ;

double_child_subquery_group_by:
    | | | | | | | | | GROUP BY { child_subquery.$child_subquery_idx."_field1" } ,  { child_subquery.$child_subquery_idx."_field2" } ;

child_subquery_having: ;

child_subquery_having_disabled:
    | | | | | | | | | | HAVING child_subquery_having_list ;

child_subquery_having_list:
        child_subquery_having_item |
        child_subquery_having_item |
	(child_subquery_having_list and_or child_subquery_having_item)  ;

child_subquery_having_item:
	child_subquery_existing_table_item . int_field_name comparison_operator _digit |
        child_subquery_existing_table_item . int_field_name comparison_operator _char ;


################################################################################
# The range_predicate_1* rules below are in place to ensure we hit the         #
# index_merge/sort_union optimization.                                         #
# NOTE: combinations of the predicate_1 and predicate_2 rules tend to hit the  #
# index_merge/intersect optimization                                           #
################################################################################

range_predicate1_list:
      range_predicate1_item | 
      ( range_predicate1_item OR range_predicate1_item ) ;

range_predicate1_item:
         table1 . int_indexed not BETWEEN _tinyint_unsigned[invariant] AND ( _tinyint_unsigned[invariant] + _tinyint_unsigned ) |
         table1 . `col_varchar_key` comparison_operator _char[invariant]  |
         table1 . int_indexed not IN (number_list) |
         table1 . `col_varchar_key` not IN (char_list) |
         table1 . `pk` > _tinyint_unsigned[invariant] AND table1 . `pk` < ( _tinyint_unsigned[invariant] + _tinyint_unsigned ) |
         table1 . `col_int_key` > _tinyint_unsigned[invariant] AND table1 . `col_int_key` < ( _tinyint_unsigned[invariant] + _tinyint_unsigned ) ;

################################################################################
# The range_predicate_2* rules below are in place to ensure we hit the         #
# index_merge/union optimization.                                              #
# NOTE: combinations of the predicate_1 and predicate_2 rules tend to hit the  #
# index_merge/intersect optimization                                           #
################################################################################

range_predicate2_list:
      range_predicate2_item | 
      ( range_predicate2_item and_or range_predicate2_item ) ;

range_predicate2_item:
        table1 . `pk` = _tinyint_unsigned |
        table1 . `col_int_key` = _tinyint_unsigned |
        table1 . `col_varchar_key` = _char |
        table1 . int_indexed = _tinyint_unsigned |
        table1 . `col_varchar_key` = _char |
        table1 . int_indexed = existing_table_item . int_indexed |
        table1 . `col_varchar_key` = existing_table_item . `col_varchar_key` ;

################################################################################
# The number and char_list rules are for creating WHERE conditions that test   #
# 'field' IN (list_of_items)                                                   #
################################################################################
number_list:
        _tinyint_unsigned | number_list, _tinyint_unsigned ;

char_list: 
        _char | char_list, _char ;

################################################################################
# We ensure that a GROUP BY statement includes all nonaggregates.              #
# This helps to ensure the query is more useful in detecting real errors /     #
# that the query doesn't lend itself to variable result sets                   #
################################################################################
group_by_clause:
	{ $gby = (@nonaggregates > 0 and (@aggregates > 0 or $prng->int(1,3) == 1) ? " GROUP BY ".join (', ' , @nonaggregates ) : "" ) }  ;

having_clause:
	| |
	{ ($gby or @aggregates > 0)? "HAVING ".join("", expand($rule_counters,$rule_invariants, "having_list")) : "" } ;

having_list:
        having_item |
        having_item |
	(having_list and_or having_item)  ;

having_item:
	{ ($gby and @int_nonaggregates > 0 and (!@aggregates or $prng->int(1,3) == 1)) ? $prng->arrayElement(\@int_nonaggregates) : join("", expand($rule_counters,$rule_invariants, "new_aggregate_existing_table_item")) }
	comparison_operator _digit ;

################################################################################
# We use the total_order_by rule when using the LIMIT operator to ensure that  #
# we have a consistent result set - server1 and server2 should not differ      #
################################################################################

order_by_clause:
	|
	ORDER BY order_by_list |
	ORDER BY order_by_list, total_order_by limit ;

any_item_order_by_clause:
	order_by_clause |
        ORDER BY table1 . _field_indexed desc , total_order_by  limit ;

total_order_by:
	{ join(', ', map { "field".$_." /*+JavaDB:Postgres: NULLS FIRST */" } (1..$fields) ) };

order_by_list:
	order_by_item  |
	order_by_item  , order_by_list ;

any_item_order_by_list:
	any_item_order_by_item  |
	any_item_order_by_item  , any_item_order_by_list ;

order_by_item:
	existing_select_item desc ;

any_item_order_by_item:
	order_by_item |
        table1 . _field_indexed /*+JavaDB:Postgres: NULLS FIRST*/ , existing_table_item .`pk` desc |
        table1 . _field_indexed desc |
        CONCAT( existing_table_item . char_field_name, existing_table_item . char_field_name ) /*+JavaDB:Postgres: NULLS FIRST*/ ;

desc:
        ASC /*+JavaDB:Postgres: NULLS FIRST */| /*+JavaDB:Postgres: NULLS FIRST */ | DESC /*+JavaDB:Postgres: NULLS LAST */ ; 


limit:
	| | LIMIT limit_size | LIMIT limit_size OFFSET _digit;

new_select_item:
	nonaggregate_select_item |
	nonaggregate_select_item |
	aggregate_select_item |
        combo_select_item |
        nonaggregate_select_item |
	nonaggregate_select_item |
	aggregate_select_item |
        select_subquery;

noagg_new_select_item:
	nonaggregate_select_item |
	nonaggregate_select_item |
        combo_select_item ;

################################################################################
# We have the perl code here to help us write more sensible queries            #
# It allows us to use field1...fieldn in the WHERE, ORDER BY, and GROUP BY     #
# clauses so that the queries will produce more stable and interesting results #
################################################################################

nonaggregate_select_item:
        { my $x = "table".$prng->int(1,$max_table_id)." . ".join("",expand($rule_counters,$rule_invariants, "_field_int_indexed")); push @int_nonaggregates , $x ; push @nonaggregates , $x ; $x } AS { "field".++$fields } |
        { my $x = "table".$prng->int(1,$max_table_id)." . ".join("",expand($rule_counters,$rule_invariants, "_field_indexed")); push @nonaggregates , $x ; $x } AS { "field".++$fields } |
        { my $x = "table".$prng->int(1,$max_table_id)." . ".join("",expand($rule_counters,$rule_invariants, "_field")); push @nonaggregates , $x ; $x } AS { "field".++$fields } |
        { my $x = "table".$prng->int(1,$max_table_id)." . ".join("",expand($rule_counters,$rule_invariants, "_field_int")); push @int_nonaggregates , $x ; push @nonaggregates , $x ; $x } AS { "field".++$fields } ;

aggregate_select_item:
	{ my $x = join("", expand($rule_counters,$rule_invariants, "new_aggregate")); push @aggregates, $x; $x } AS { "field".++$fields };

new_aggregate:
	aggregate table_alias . _field_int ) |
	aggregate table_alias . _field_int ) |
	aggregate table_alias . _field_int ) |
	literal_aggregate ;

new_aggregate_existing_table_item:
	aggregate existing_table_item . _field_int ) |
	aggregate existing_table_item . _field_int ) |
	aggregate existing_table_item . _field_int ) |
	literal_aggregate ;

select_subquery:
         { $subquery_idx += 1 ; $subquery_tables=0 ; $max_subquery_table_id = $prng->int(1,3) ; ""} select_subquery_body;

select_subquery_body:
         int_single_value_subquery AS { my $f = "field".++$fields ; push @nonaggregates , $f ; $f } |
         char_single_value_subquery AS { my $f = "field".++$fields ; push @nonaggregates , $f ; $f } |
         int_scalar_correlated_subquery AS  { my $f = "field".++$fields ; push @nonaggregates , $f ; $f } |
	 char_scalar_correlated_subquery AS  { my $f = "field".++$fields ; push @nonaggregates , $f ; $f } ;

select_subquery_body_disabled:
         (  SELECT _digit  UNION all_distinct  ( SELECT _digit ) ORDER BY 1 LIMIT 1 )  AS  { my $f = "field".++$fields ; push @nonaggregates , $f ; $f } |
         (  SELECT _char  UNION all_distinct ( SELECT _char ) ORDER BY 1 LIMIT 1 )  AS  { my $f = "field".++$fields ; push @nonaggregates , $f ; $f } ;

################################################################################
# The combo_select_items are for 'spice' 
################################################################################

combo_select_item:
    int_combo_select_item | char_combo_select_item ;

int_combo_select_item:
    { my $x = join("",expand($rule_counters,$rule_invariants, "int_combo_expr")); push @int_nonaggregates , $x ; push @nonaggregates , $x ; $x } AS { "field".++$fields } ;

int_combo_expr:
	( ( table_alias . _field_int ) math_operator ( table_alias . _field_int ) ) ;

char_combo_select_item:
    { my $x = join("",expand($rule_counters,$rule_invariants, "char_combo_expr")); push @nonaggregates , $x ; $x } AS { "field".++$fields } ;

char_combo_expr:
	CONCAT( table_alias . _field_char , table_alias . _field_char ) ;

table_alias:
	table1 | table1 | table1 |
	{ "table".$prng->int(1,$max_table_id >= 2? 2: $max_table_id) } |
	{ "table".$prng->int(1,$max_table_id >= 2? 2: $max_table_id) } |
	{ "table".$prng->int(1,$max_table_id >= 3? 3: $max_table_id) } ;

subquery_table_alias:
        { "SUBQUERY".$subquery_idx."_t1" ;  } | { "SUBQUERY".$subquery_idx."_t1" ;  } |
        { "SUBQUERY".$subquery_idx."_t1" ;  } |
	{ "SUBQUERY".$subquery_idx."_t".$prng->int(1,$max_subquery_table_id >= 2? 2: $max_subquery_table_id) } |
	{ "SUBQUERY".$subquery_idx."_t".$prng->int(1,$max_subquery_table_id >= 2? 2: $max_subquery_table_id) } |
	{ "SUBQUERY".$subquery_idx."_t".$prng->int(1,$max_subquery_table_id >= 3? 3: $max_subquery_table_id) } ;

child_subquery_table_alias:
        { "CHILD_SUBQUERY".$child_subquery_idx."_t1" ;  } | { "CHILD_SUBQUERY".$child_subquery_idx."_t1" ;  } |
        { "CHILD_SUBQUERY".$child_subquery_idx."_t1" ;  } |
	{ "CHILD_SUBQUERY".$child_subquery_idx."_t".$prng->int(1,$max_child_subquery_table_id >= 2? 2: $max_child_subquery_table_id) ;  } |
	{ "CHILD_SUBQUERY".$child_subquery_idx."_t".$prng->int(1,$max_child_subquery_table_id >= 2? 2: $max_child_subquery_table_id) ;  } |
	{ "CHILD_SUBQUERY".$child_subquery_idx."_t".$prng->int(1,$max_child_subquery_table_id >= 3? 3: $max_child_subquery_table_id) ;  } ;

any_type_aggregate:
	MIN( distinct | MAX( distinct ;

aggregate:
	COUNT( distinct | SUM( distinct | any_type_aggregate ;

literal_aggregate:
	COUNT(*) | COUNT(0) | SUM(1) ;

################################################################################
# The following rules are for writing more sensible queries - that we don't    #
# reference tables / fields that aren't present in the query and that we keep  #
# track of what we have added.  You shouldn't need to touch these ever         #
################################################################################
new_table_item:
	_table AS { "table".++$tables } | _table AS { "table".++$tables } | _table AS { "table".++$tables } |
        ( { push @st1, $t1; $t1 = $tables + 1; "" } from_subquery { $t1 = pop @st1; "" } ) AS { "table".++$tables } ;

from_subquery:
       { $subquery_idx += 1 ; $subquery_tables=0 ; $max_subquery_table_id = $prng->int(1,3) ; ""}  SELECT distinct select_option subquery_table_alias . * subquery_body  ;

subquery_new_table_item:
        _table AS { "SUBQUERY".$subquery_idx."_t".++$subquery_tables } ;

child_subquery_new_table_item:
        _table AS { "CHILD_SUBQUERY".$child_subquery_idx."_t".++$child_subquery_tables } ;      

current_table_item:
	{ "table".$tables };

subquery_current_table_item:
        { "SUBQUERY".$subquery_idx."_t".$subquery_tables } ;

child_subquery_current_table_item:
        { "CHILD_SUBQUERY".$child_subquery_idx."_t".$child_subquery_tables } ;

previous_table_item:
	{ "table".($tables - 1) } ;

subquery_previous_table_item:
        { "SUBQUERY".$subquery_idx."_t".($subquery_tables-1) } ;

child_subquery_previous_table_item:
        { "CHILD_SUBQUERY".$child_subquery_idx."_t".($child_subquery_tables-1) } ;

existing_table_item:
	{ "table".$prng->int($t1,$tables) } ;

subquery_existing_table_item:
        { "SUBQUERY".$subquery_idx."_t".$prng->int($sqt1,$subquery_tables) } ;

child_subquery_existing_table_item:
        { "CHILD_SUBQUERY".$child_subquery_idx."_t".$prng->int($csqt1,$child_subquery_tables) } ;

existing_select_item:
	{ "field".$prng->int(1,$fields) };

################################################################################
# end of utility rules                                                         #
################################################################################

comparison_operator:
	= | > | < | != | <> | <= | >= ;


membership_operator:
    comparison_operator all_any |
    not IN ;

all_any:
    ALL | ANY | SOME ;

################################################################################
# Used for creating combo_items - ie (field1 + field2) AS fieldX               #
# We ignore division to prevent division by zero errors                        #
################################################################################
math_operator:
    + | - | * ;

################################################################################
# We stack AND to provide more interesting options for the optimizer           #
# Alter these percentages at your own risk / look for coverage regressions     #
# with --debug if you play with these.  Those optimizations that require an    #
# OR-only list in the WHERE clause are specifically stacked in another rule    #
################################################################################
and_or:
   AND | AND | OR ;

all_distinct:
   | | | | |
   | | | ALL | DISTINCT ;

	 
value:
	_digit | _digit | _digit | _digit | _tinyint_unsigned|
        _char(2) | _char(2) | _char(2) | _char(2) | _char(2) ;

_table:
     A | B | C | BB | CC | B | C | BB | CC | 
     CC | CC | CC | CC | CC |
     C | C | C | C | C | D ;    

################################################################################
# Add a possibility for 'view' to occur at the end of the previous '_table' rule
# to allow a chance to use views (when running the RQG with --views)
################################################################################

view:
    view_A | view_B | view_C | view_BB | view_CC ;

_field:
    int_field_name | char_field_name ;

_digit:
    1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | _tinyint_unsigned ;

int_field_name:
    `pk` | `col_int_key` | `col_int_nokey` ;

int_indexed:
    `pk` | `col_int_key` ;


char_field_name:
    `col_varchar_key` | `col_varchar_nokey` ;

field_name:
    int_field_name | int_field_name |
    char_field_name | char_field_name |
    col_datetime_key | col_datetime_nokey ;

################################################################################
# We define LIMIT_rows in this fashion as LIMIT values can differ depending on      #
# how large the LIMIT is - LIMIT 2 = LIMIT 9 != LIMIT 19                       #
################################################################################

limit_size:
    1 | 2 | 10 | 100 | 1000;
