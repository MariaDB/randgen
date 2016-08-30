# Copyright (c) 2008, 2011 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2014 SkySQL Ab
# Copyright (c) 2015, 2016, MariaDB Corporation Ab
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


query_init:
	{ $query_count = 0; $total_dur = 0; %table_columns; %table_columns_by_type; "" } fetch_table_columns fetch_table_int_columns fetch_table_char_columns;
    
fetch_table_columns:
    { unless (%table_columns) { foreach $t (@{$executors->[0]->baseTables()}) { $table_columns{$t} = $executors->[0]->metaColumns($t, $last_database) }; } '' };

fetch_table_int_columns:
    { $type = 'int'; '' } fetch_table_columns_by_type;

fetch_table_char_columns:
    { $type = 'char'; '' } fetch_table_columns_by_type;

fetch_table_columns_by_type:
    { unless (%table_columns_by_type and $table_columns_by_type{$type}) { foreach $t (@{$executors->[0]->baseTables()}) { ${$table_columns_by_type{$type}}{$t} = $executors->[0]->metaColumnsDataType($type,$t,$last_database) } }; '' } ;

# We don't want many big tables in a query, it makes queries too slow and does not really add value to the tests
# Now we'll have the max number of big tables hardcoded here to 1, maybe later we'll change it
smart_table:
    { if ( $bigtables < 1 ) { $last_table = $prng->arrayElement($executors->[0]->tables($last_database)); $bigtables++ if ($executors->[0]->isBigTable($last_table)) } else { $last_table = $prng->arrayElement($executors->[0]->smallTables($last_database)) } ; $last_table };

smart_base_table:
    { if ( $bigtables < 1 ) { $last_table = $prng->arrayElement($executors->[0]->baseTables($last_database)); $bigtables++ if ($executors->[0]->isBigTable($last_table)) } else { $last_table = $prng->arrayElement($executors->[0]->smallBaseTables($last_database)) } ; $last_table };
# else { $last_table = $prng->arrayElement($executors->[0]->smallTables($last_database)) }

# else { $last_table = $prng->arrayElement($executors->[0]->smallTables($last_database)) }

query:
	{ @nonaggregates = () ; $tables = 0 ; $fields = 0 ; $ifields = 0; $cfields = 0; $bigtables = 0; $subquery_idx=0 ; $child_subquery_idx=0 ; "" } query_type ;

#################################################################################
#################################################################################
#-------------------------------------------------------------------------------#
#---- This part of the grammar was derived from optimizer.yy -------------------#
#-------------------------------------------------------------------------------#
#################################################################################
#################################################################################


query_type:
      main_select 
    | range_access ;

main_select:
	simple_select | simple_select | simple_select | simple_select |
	mixed_select |  mixed_select |  mixed_select |  mixed_select  | 
	aggregate_select | loose_scan ;

################################################################################
# The loose* rules listed below are to hit the 'Using index for group-by'
# optimization.  This optimization has some strict requirements, thus
# we needed a separate query pattern to ensure we hit it.
################################################################################
loose_scan:
	SELECT distinct loose_select_clause
	FROM new_table_item
	WHERE generic_where_list
	group_by_clause ;

loose_select_clause:
	loose_select_list |
	MIN( _field) AS { "field".++$fields } , loose_select_list |
	MAX( _field) AS { "field".++$fields } , loose_select_list |
	MIN( _field[invariant] ) AS { "field".++$fields }, MAX( _field[invariant] ) AS { "field".++$fields }, loose_select_list ;

loose_select_list:
	loose_select_item | 
	loose_select_item , loose_select_list ;

loose_select_item:
	_field AS { my $f = "field".++$fields ; push @nonaggregates , $f ; $f } |
	_field_int AS { my $f = "ifield".++$ifields ; push @nonaggregates , $f ; $f } |
	_field_char AS { my $f = "cfield".++$cfields ; push @nonaggregates , $f ; $f } ;
	
################################################################################

mixed_select:
	SELECT distinct straight_join select_option select_list
	FROM join_list
	where_clause
	group_by_clause 
	having_clause
	order_by_clause ;

simple_select:
	SELECT distinct straight_join select_option simple_select_list
	FROM join_list
	where_clause
	optional_group_by 
	having_clause
	order_by_clause ;

aggregate_select:
	SELECT distinct straight_join select_option aggregate_select_list
	FROM join_list
	where_clause
	optional_group_by 
	having_clause
	order_by_clause ;

explain_extended:	
	| | | | | | | | | explain_extended2 ;

explain_extended2: | | | | EXPLAIN | EXPLAIN EXTENDED ; 
	   
distinct: DISTINCT | | | | | | | | | ;

select_option:  | | | | | | | | | | | | | | | | SQL_SMALL_RESULT | SQL_BIG_RESULT ;

straight_join:  | | | | | | | | | | | | | | | | | | | | | STRAIGHT_JOIN ;

select_list:
	new_select_item |
	new_select_item , select_list ;

simple_select_list:
	nonaggregate_select_item |
	nonaggregate_select_item , simple_select_list ;

aggregate_select_list:
	aggregate_select_item | aggregate_select_item |
	aggregate_select_item, aggregate_select_list ;

join_list:
################################################################################
# this limits us to 2 and 3 table joins / can use it if we hit
# too many mega-join conditions which take too long to run
################################################################################
	  new_table_item |
	  new_table_item |
	( new_table_item , new_table_item ) |
	( new_table_item , new_table_item ) |
	( new_table_item join_type new_table_item ON (join_condition_list ) ) |
	( new_table_item join_type new_table_item ON (join_condition_list ) ) |
	( new_table_item join_type ( new_table_item join_type new_table_item ON (join_condition_list ) ) ON (join_condition_list ) ) |
	( new_table_item , new_table_item , new_table_item ) ;


join_type:
	INNER JOIN | left_right outer JOIN |
	INNER JOIN | left_right outer JOIN |
	INNER JOIN | left_right outer JOIN |
	INNER JOIN | left_right outer JOIN |
	INNER JOIN | left_right outer JOIN |
	STRAIGHT_JOIN ;  

join_condition_list:
	join_condition_item | 
	( join_condition_item ) and_or ( join_condition_list ) |
	( current_table_item  . _field arithmetic_operator previous_table_item . _field ) AND (current_table_item  . _field arithmetic_operator previous_table_item . _field ) ;	

join_condition_item:
	current_table_item . _field_int = previous_table_item . _field_int on_subquery |
	current_table_item . _field_int = previous_table_item . _field_int on_subquery |
	current_table_item . _field_char = previous_table_item . _field_char on_subquery |
	current_table_item . _field_char = previous_table_item . _field_char on_subquery |
	current_table_item . _field_int arithmetic_operator previous_table_item . _field_int on_subquery |
	current_table_item . _field_int arithmetic_operator previous_table_item . _field_int on_subquery |
	current_table_item . _field_char arithmetic_operator previous_table_item . _field_char on_subquery |
	current_table_item . _field_char arithmetic_operator previous_table_item . _field_char on_subquery ;

on_subquery:
	|||||||||||||||||||| { $subquery_idx += 1 ; $subquery_tables=0 ; $sq_ifields = 0; $sq_cfields = 0; ""} and_or general_subquery ;


left_right:
	LEFT | LEFT | LEFT | RIGHT ;

outer:
	| | | OUTER ;

where_clause:
	WHERE where_list |
	WHERE where_list |
	WHERE where_list |
	WHERE where_subquery |
 	WHERE ( where_subquery ) and_or where_list ;


where_list:
	generic_where_list |
	range_predicate1_list | range_predicate2_list |
	range_predicate1_list and_or generic_where_list |
	range_predicate2_list and_or generic_where_list ; 


generic_where_list:
	where_item |
	( where_item and_or where_item ) |
	( where_list and_or where_item ) ;

not:
	| | | NOT;

degenerate_where_item:
   _tinyint[invariant] = _tinyint[invariant] |
   _tinyint[invariant] > _tinyint[invariant] |
	_char[invariant] = _char[invariant] |
	_char[invariant] NOT LIKE _char[invariant] ;

where_item:
	real_where_item |
	real_where_item |
	real_where_item |
	real_where_item |
	real_where_item |
	real_where_item |
	real_where_item |
	degenerate_where_item ;

real_where_item:
	where_subquery  |  
	existing_table_item . _field_char arithmetic_operator _char  |
	existing_table_item . _field_char arithmetic_operator existing_table_item . _field_char |
	existing_table_item . _field arithmetic_operator value  |
	existing_table_item . _field arithmetic_operator existing_table_item . _field |
	alias1 . _field IS not NULL |
	alias1 . _field IS not NULL |
	alias1 . _field arithmetic_operator existing_table_item . _field  |
	alias1 . _field_int arithmetic_operator existing_table_item . _field_int  |
	alias1 . _field arithmetic_operator value AND ( alias1 . _field_char LIKE '%a%' OR alias1._field_char LIKE '%b%') ;


################################################################################
# subquery rules
################################################################################

where_subquery:
	{ $subquery_idx += 1 ; $subquery_tables=0 ; $sq_ifields = 0; $sq_cfields = 0; ""} subquery_type ;

subquery_type:
	general_subquery | special_subquery ;

general_subquery:
	existing_table_item . _field_int arithmetic_operator  int_single_value_subquery  |
	existing_table_item . _field_int arithmetic_operator  int_single_value_subquery  |
	existing_table_item . _field_char arithmetic_operator char_single_value_subquery |
	existing_table_item . _field_char arithmetic_operator char_single_value_subquery |
	existing_table_item . _field_int membership_operator  int_single_member_subquery  |
	existing_table_item . _field_int membership_operator  int_single_member_subquery  |
	existing_table_item . _field_int membership_operator  int_single_value_subquery  |
	existing_table_item . _field_int membership_operator  int_single_value_subquery  |
	existing_table_item . _field_char membership_operator  char_single_member_subquery  |
	existing_table_item . _field_char membership_operator  char_single_member_subquery  |
	existing_table_item . _field_char membership_operator  char_single_value_subquery  |
	existing_table_item . _field_char membership_operator  char_single_value_subquery  |
	_digit membership_operator  int_single_member_subquery  |
	_char membership_operator  char_single_member_subquery  |
	( existing_table_item . _field_int , existing_table_item . _field_int ) not IN int_double_member_subquery |
	( existing_table_item . _field_char , existing_table_item . _field_char ) not IN char_double_member_subquery |
	( _digit, _digit ) not IN int_double_member_subquery |
	( _char, _char ) not IN char_double_member_subquery |
	existing_table_item . _field_int membership_operator int_single_union_subquery |
	existing_table_item . _field_char membership_operator char_single_union_subquery ;

special_subquery:
	not EXISTS ( int_single_member_subquery ) |
	not EXISTS ( char_single_member_subquery ) |
	not EXISTS int_correlated_subquery |
	not EXISTS int_correlated_subquery |
	not EXISTS char_correlated_subquery  | 
	not EXISTS char_correlated_subquery  | 
	existing_table_item . _field_int membership_operator  int_correlated_subquery  |
	existing_table_item . _field_int membership_operator  int_correlated_subquery  |
	existing_table_item . _field_char membership_operator char_correlated_subquery  |
	existing_table_item . _field_char membership_operator char_correlated_subquery  |
	int_single_value_subquery IS not NULL |
	char_single_value_subquery IS not NULL ;

int_single_value_subquery:
	( SELECT distinct select_option aggregate subquery_table_one_two . _field_int ) AS { $sq_ifields = 1; "SQ".$subquery_idx."_ifield1" } 
	  subquery_body ) |
	( SELECT distinct select_option aggregate subquery_table_one_two . _field_int ) AS { $sq_ifields = 1; "SQ".$subquery_idx."_ifield1" } 
	  subquery_body ) |
	( SELECT _digit FROM DUAL ) ;

char_single_value_subquery:
	{ $group_concat = '' } ( SELECT distinct select_option aggregate subquery_table_one_two . _field_char ) AS { $sq_cfields = 1; "SQ".$subquery_idx."_cfield1" }  
	  subquery_body ) |
	{ $group_concat = '' } ( SELECT distinct select_option aggregate subquery_table_one_two . _field_char ) AS { $sq_cfields = 1; "SQ".$subquery_idx."_cfield1" } 
	  subquery_body ) |
	( SELECT _char FROM DUAL ) ;
   
int_single_member_subquery:
	( SELECT distinct select_option subquery_table_one_two . _field_int AS { $sq_ifields = 1; "SQ".$subquery_idx."_ifield1" }
	  subquery_body 
	  single_subquery_group_by
	  subquery_having ) |
	( SELECT _digit FROM DUAL ) ;

int_single_union_subquery:
	( SELECT _digit UNION all_distinct SELECT _digit order_by_union_sq ) ;

int_single_union_subquery_disabled:
	int_single_member_subquery   UNION all_distinct  int_single_member_subquery ;

int_double_member_subquery:
	( SELECT distinct select_option subquery_table_one_two . _field_int AS { "SQ".$subquery_idx."_ifield1" } , 
	  subquery_table_one_two . _field_int AS { $sq_ifields = 2; "SQ".$subquery_idx."_ifield2" }
	  subquery_body 
	  double_subquery_group_by
	  subquery_having ) |
	( SELECT distinct select_option subquery_table_one_two . _field_int AS { "SQ".$subquery_idx."_ifield1" } , 
	  subquery_table_one_two . _field_int AS { $sq_ifields = 2; "SQ".$subquery_idx."_ifield2" }
	  subquery_body 
	  double_subquery_group_by
	  subquery_having ) |
	( SELECT distinct select_option subquery_table_one_two . _field_int AS { $f = "SQ".$subquery_idx."_ifield1"; $f } , 
	  subquery_table_one_two . _field_int AS { $f = "SQ".$subquery_idx."_ifield2"; $sq_ifields = 2; $f }
	  subquery_body 
	  double_subquery_group_by
	  subquery_having ) |
	( SELECT distinct select_option subquery_table_one_two . _field_int AS { "SQ".$subquery_idx."_ifield1" } , 
	  aggregate subquery_table_one_two . _field_int ) AS { $sq_ifields = 2; "SQ".$subquery_idx."_ifield2" }
	  subquery_body 
	  single_subquery_group_by
	  subquery_having ) |
	(  SELECT _digit , _digit  UNION all_distinct  SELECT _digit, _digit  ) ;

order_by_union_sq:
	| order_by_anon ;

char_single_member_subquery:
	( SELECT distinct select_option subquery_table_one_two . _field_char AS { $sq_cfields = 1; "SQ".$subquery_idx."_cfield1" }
	 subquery_body
	 single_subquery_group_by
	 subquery_having) ;

char_single_union_subquery:
	( SELECT _char UNION all_distinct SELECT _char order_by_union_sq ) ;

char_single_union_subquery_disabled:
	char_single_member_subquery   UNION all_distinct char_single_member_subquery  ;

char_double_member_subquery:
   ( SELECT distinct select_option subquery_table_one_two . _field_char AS { "SQ".$subquery_idx."_cfield1" } ,
	 subquery_table_one_two . _field_char AS { $sq_cfields = 2; "SQ".$subquery_idx."_cfield2" }
	 subquery_body
	 double_subquery_group_by
	 subquery_having ) |
   ( SELECT distinct select_option subquery_table_one_two . _field_char AS { "SQ".$subquery_idx."_cfield1" } ,
	 subquery_table_one_two . _field_char AS { $sq_cfields = 2; "SQ".$subquery_idx."_cfield2" }
	 subquery_body
	 double_subquery_group_by
	 subquery_having ) |
   ( SELECT distinct select_option subquery_table_one_two . _field_char AS { "SQ".$subquery_idx."_cfield1" } ,
	 subquery_table_one_two . _field_char AS { $sq_cfields = 2; "SQ".$subquery_idx."_cfield2" }
	 subquery_body
	 double_subquery_group_by
	 subquery_having ) |
   ( SELECT distinct select_option subquery_table_one_two . _field_char AS { "SQ".$subquery_idx."_cfield1" } ,
	 subquery_table_one_two . _field_char AS { $sq_cfields = 2; "SQ".$subquery_idx."_cfield2" }
	 subquery_body
	 double_subquery_group_by
	 subquery_having ) |
   ( SELECT distinct select_option subquery_table_one_two . _field_char AS { "SQ".$subquery_idx."_cfield1" } ,
	 aggregate subquery_table_one_two . _field_char ) AS { $sq_cfields = 2; "SQ".$subquery_idx."_cfield2" }
	 subquery_body
	 single_subquery_group_by
	 subquery_having ) |
   (  SELECT _char , _char  UNION all_distinct  SELECT _char , _char  ) ;

int_correlated_subquery:
	( SELECT distinct select_option subquery_table_one_two . _field_int AS { $sq_ifields = 1; "SQ".$subquery_idx."_ifield1" }
	  FROM subquery_join_list 
	  correlated_subquery_where_clause ) ;

char_correlated_subquery:
	( SELECT distinct select_option subquery_table_one_two . _field_char AS { $sq_cfields = 1; "SQ".$subquery_idx."_cfield1" }
	  FROM subquery_join_list 
	  correlated_subquery_where_clause ) ;

int_scalar_correlated_subquery:
	 ( SELECT distinct select_option aggregate subquery_table_one_two . _field_int ) AS { $sq_ifields = 1; "SQ".$subquery_idx."_ifield1" }
	  FROM subquery_join_list 
	  correlated_subquery_where_clause ) |
	 ( SELECT distinct select_option aggregate table_one_two . _field_int ) AS { $sq_ifields = 1; "SQ".$subquery_idx."_ifield1" }
	  FROM subquery_join_list 
	  subquery_where_clause ) ; 

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
	existing_subquery_table_item . _field_int arithmetic_operator existing_table_item . _field_int |
	existing_subquery_table_item . _field_char arithmetic_operator existing_table_item . _field_char |
	existing_table_item . _field_int IN ( child_subquery ) |
	existing_table_item . _field_int IN ( simple_child_subquery ) |
	existing_subquery_table_item . _field_int IN ( correlated_with_top_child_subquery ) ;

correlated_with_top_child_subquery:
	{ $child_subquery_idx += 1 ; $c_sq_ifields = 0; $c_sq_cfields = 0; $child_subquery_tables=0 ; ""} int_correlated_with_top_child_subquery ;

simple_child_subquery:
	{ $child_subquery_idx += 1 ; $c_sq_ifields = 0; $c_sq_cfields = 0; $child_subquery_tables=0 ; ""} int_single_member_child_subquery ;

subquery_where_list:
	subquery_where_item | subquery_where_item | subquery_where_item |
	( subquery_where_item and_or subquery_where_item ) ;

subquery_where_item:
   existing_subquery_table_item . _field_int arithmetic_operator _digit |
   existing_subquery_table_item . _field_char arithmetic_operator _char |
   existing_subquery_table_item . _field_int arithmetic_operator existing_subquery_table_item . _field_int |
   existing_subquery_table_item . _field_char arithmetic_operator existing_subquery_table_item . _field_char |
   child_subquery ;

subquery_join_list:
   subquery_new_table_item  |  subquery_new_table_item  |
   subquery_new_table_item  |  subquery_new_table_item  |
   subquery_new_table_item  |  subquery_new_table_item  |
   ( subquery_new_table_item , subquery_new_table_item ) |
   ( subquery_new_table_item join_type subquery_new_table_item ON (subquery_join_condition_item ) ) |
   ( subquery_new_table_item join_type subquery_new_table_item ON (subquery_join_condition_item ) ) |
   ( subquery_new_table_item join_type ( subquery_new_table_item join_type subquery_new_table_item ON (subquery_join_condition_item )  ) ON (subquery_join_condition_item ) ) ;

subquery_join_condition_item:
	subquery_current_table_item . _field_int = subquery_previous_table_item . _field_int subquery_on_subquery |
	subquery_current_table_item . _field_int = subquery_previous_table_item . _field_int subquery_on_subquery |
	subquery_current_table_item . _field_char = subquery_previous_table_item . _field_char subquery_on_subquery |
	subquery_current_table_item . _field_char = subquery_previous_table_item . _field_char subquery_on_subquery ;

subquery_on_subquery:
	|||||||||||||||||||| { $child_subquery_idx += 1 ; $c_sq_ifields = 0; $c_sq_cfields = 0; $child_subquery_tables=0 ; ""} and_or general_child_subquery ;

single_subquery_group_by:
	| | | | | | | | | GROUP BY { "SQ".$subquery_idx. ($sq_ifields ? "_ifield1" : "_cfield1") } ;

double_subquery_group_by:
	| | | | | | | | | GROUP BY { $fname = ($sq_ifields ? "_ifield" : "_cfield"); "SQ".$subquery_idx.$fname."1".", SQ".$subquery_idx.$fname."2" } ;

subquery_having:
	| | | | | | | | | | HAVING subquery_having_list ;

subquery_having_list:
	subquery_having_item |
	subquery_having_item |
	(subquery_having_list and_or subquery_having_item)  ;

subquery_having_item:
	existing_subquery_int_select_item arithmetic_operator _digit |
	existing_subquery_char_select_item arithmetic_operator _char ;

existing_subquery_select_item:
	existing_subquery_int_select_item | existing_subquery_char_select_item ;

existing_subquery_int_select_item:
	{ "SQ".$subquery_idx. ($sq_ifields ? "_ifield".$prng->int(1,$sq_ifields) : "_cfield".$prng->int(1,$sq_cfields)) };

existing_subquery_char_select_item:
	{ "SQ".$subquery_idx. ($sq_cfields ? "_cfield".$prng->int(1,$sq_cfields) : "_ifield".$prng->int(1,$sq_ifields)) };


################################################################################
# Child subquery rules
################################################################################

child_subquery:
	{ $child_subquery_idx += 1 ; $c_sq_ifields = 0; $c_sq_cfields = 0; $child_subquery_tables=0 ; ""} child_subquery_type ;

child_subquery_type:
	general_child_subquery | special_child_subquery ;

general_child_subquery:
	existing_subquery_table_item . _field_int arithmetic_operator  int_single_value_child_subquery  |
	existing_subquery_table_item . _field_int arithmetic_operator  int_single_value_child_subquery  |
	existing_subquery_table_item . _field_char arithmetic_operator char_single_value_child_subquery |
	existing_subquery_table_item . _field_char arithmetic_operator char_single_value_child_subquery |
	existing_subquery_table_item . _field_int membership_operator  int_single_member_child_subquery  |
	existing_subquery_table_item . _field_int membership_operator  int_single_member_child_subquery  |
	existing_subquery_table_item . _field_char membership_operator  char_single_member_child_subquery  |
	existing_subquery_table_item . _field_char membership_operator  char_single_member_child_subquery  |
	( existing_subquery_table_item . _field_int , existing_subquery_table_item . _field_int ) not IN int_double_member_child_subquery |
	( existing_subquery_table_item . _field_char , existing_subquery_table_item . _field_char ) not IN char_double_member_child_subquery |
	( _digit, _digit ) not IN int_double_member_child_subquery |
	( _char, _char ) not IN char_double_member_child_subquery |
	existing_subquery_table_item . _field_int membership_operator int_single_union_child_subquery |
	existing_subquery_table_item . _field_char membership_operator char_single_union_child_subquery ;

special_child_subquery:
	not EXISTS ( int_single_member_child_subquery ) |
	not EXISTS ( char_single_member_child_subquery ) |
	not EXISTS int_correlated_child_subquery |
	not EXISTS char_correlated_child_subquery |
	existing_subquery_table_item . _field_int membership_operator  int_correlated_child_subquery  |
	existing_subquery_table_item . _field_char membership_operator char_correlated_child_subquery ;


int_single_value_child_subquery:
	( SELECT distinct select_option aggregate child_subquery_table_one_two . _field_int ) AS { $c_sq_ifields=1; "C_SQ".$child_subquery_idx."_ifield1" } 
	  child_subquery_body ) ;

char_single_value_child_subquery:
	( SELECT distinct select_option aggregate child_subquery_table_one_two . _field_char ) AS { $c_sq_cfields=1; "C_SQ".$child_subquery_idx."_cfield1" } 
	  child_subquery_body ) ;
   
int_single_member_child_subquery:
	( SELECT distinct select_option child_subquery_table_one_two . _field_int AS { $c_sq_ifields=1; "C_SQ".$child_subquery_idx."_ifield1" }
	  child_subquery_body 
	  single_child_subquery_group_by
	  child_subquery_having ) ;

int_single_union_child_subquery:
	(  SELECT _digit  UNION all_distinct  SELECT _digit  )  ;

int_double_member_child_subquery:
	( SELECT distinct select_option child_subquery_table_one_two . _field_int AS { "C_SQ".$child_subquery_idx."_ifield1" } , 
	  child_subquery_table_one_two . _field_int AS { $c_sq_ifields=2; "C_SQ".$child_subquery_idx."_ifield2" }
	  child_subquery_body 
	  double_child_subquery_group_by
	  child_subquery_having ) |
	( SELECT distinct select_option child_subquery_table_one_two . _field_int AS { "C_SQ".$child_subquery_idx."_ifield1" } , 
	  aggregate child_subquery_table_one_two . _field_int ) AS { $c_sq_ifields=2; "C_SQ".$child_subquery_idx."_ifield2" }
	  child_subquery_body 
	  single_child_subquery_group_by
	  child_subquery_having );

char_single_member_child_subquery:
	( SELECT distinct select_option child_subquery_table_one_two . _field_char AS { $c_sq_cfields=1; "C_SQ".$child_subquery_idx."_cfield1" }
	 child_subquery_body
	 single_child_subquery_group_by
	 child_subquery_having) ;

char_single_union_child_subquery:
	(  SELECT _digit  UNION all_distinct  SELECT _digit  )  ;

char_double_member_child_subquery:
   ( SELECT distinct select_option child_subquery_table_one_two . _field_char AS { "C_SQ".$child_subquery_idx."_cfield1" } ,
	 child_subquery_table_one_two . _field_char AS { $c_sq_cfields=2; "C_SQ".$child_subquery_idx."_cfield2" }
	 child_subquery_body
	 double_child_subquery_group_by
	 child_subquery_having ) |
   ( SELECT distinct select_option child_subquery_table_one_two . _field_char AS { "C_SQ".$child_subquery_idx."_cfield1" } ,
	 aggregate child_subquery_table_one_two . _field_char ) AS { $c_sq_cfields=2; "C_SQ".$child_subquery_idx."_cfield2" }
	 child_subquery_body
	 single_child_subquery_group_by
	 child_subquery_having );

int_correlated_child_subquery:
	( SELECT distinct select_option child_subquery_table_one_two . _field_int AS { $c_sq_ifields=1; "C_SQ".$child_subquery_idx."_ifield1" }
	  FROM child_subquery_join_list 
	  correlated_child_subquery_where_clause ) ;

int_correlated_with_top_child_subquery:
	( SELECT distinct select_option child_subquery_table_one_two . _field_int AS { $c_sq_ifields=1; "C_SQ".$child_subquery_idx."_ifield1" }
	  FROM child_subquery_join_list 
	  correlated_with_top_child_subquery_where_clause ) ;

char_correlated_child_subquery:
	( SELECT distinct select_option child_subquery_table_one_two . _field_char AS { $c_sq_cfields=1; "C_SQ".$child_subquery_idx."_cfield1" }
	  FROM child_subquery_join_list 
	  correlated_child_subquery_where_clause ) ;

child_subquery_body:
	  FROM child_subquery_join_list
	  child_subquery_where_clause ;

child_subquery_where_clause:
	| WHERE child_subquery_where_list ;

correlated_child_subquery_where_clause:
	WHERE correlated_child_subquery_where_list ;

correlated_with_top_child_subquery_where_clause:
	WHERE correlated_with_top_child_subquery_where_list ;

correlated_child_subquery_where_list:
	correlated_child_subquery_where_item | correlated_child_subquery_where_item | correlated_child_subquery_where_item |
	correlated_child_subquery_where_item and_or correlated_child_subquery_where_item |
	correlated_child_subquery_where_item and_or child_subquery_where_item ;

correlated_with_top_child_subquery_where_list:
	correlated_with_top_child_subquery_where_item | correlated_with_top_child_subquery_where_item | correlated_with_top_child_subquery_where_item |
	correlated_with_top_child_subquery_where_item and_or correlated_with_top_child_subquery_where_item |
	correlated_with_top_child_subquery_where_item and_or child_subquery_where_item ;

correlated_child_subquery_where_item:
	existing_child_subquery_table_item . _field_int arithmetic_operator existing_subquery_table_item . _field_int |
	existing_child_subquery_table_item . _field_char arithmetic_operator existing_subquery_table_item . _field_char ;

correlated_with_top_child_subquery_where_item:
	existing_child_subquery_table_item . _field_int arithmetic_operator existing_table_item . _field_int |
	existing_child_subquery_table_item . _field_char arithmetic_operator existing_table_item . _field_char ;

child_subquery_where_list:
	child_subquery_where_item | child_subquery_where_item | child_subquery_where_item |
	( child_subquery_where_item and_or child_subquery_where_item ) ;

child_subquery_where_item:
   existing_child_subquery_table_item . _field_int arithmetic_operator _digit |
   existing_child_subquery_table_item . _field_char arithmetic_operator _char |
   existing_child_subquery_table_item . _field_int arithmetic_operator existing_child_subquery_table_item . _field_int |
   existing_child_subquery_table_item . _field_char arithmetic_operator existing_child_subquery_table_item . _field_char ;

child_subquery_join_list:
	child_subquery_new_table_item  |  child_subquery_new_table_item  |
	child_subquery_new_table_item  |  child_subquery_new_table_item  |
	child_subquery_new_table_item  |  child_subquery_new_table_item  |
	child_subquery_new_table_item  |  child_subquery_new_table_item  |
   ( child_subquery_new_table_item join_type child_subquery_new_table_item ON (child_subquery_join_condition_item ) ) |
   ( child_subquery_new_table_item join_type child_subquery_new_table_item ON (child_subquery_join_condition_item ) ) |
   ( child_subquery_new_table_item join_type ( ( child_subquery_new_table_item join_type child_subquery_new_table_item ON (child_subquery_join_condition_item ) ) ) ON (child_subquery_join_condition_item ) ) ;

child_subquery_join_condition_item:
	child_subquery_current_table_item . _field_int = child_subquery_previous_table_item . _field_int |
	child_subquery_current_table_item . _field_int = child_subquery_previous_table_item . _field_int |
	child_subquery_current_table_item . _field_char = child_subquery_previous_table_item . _field_char |
	child_subquery_current_table_item . _field_char = child_subquery_previous_table_item . _field_char ;

single_child_subquery_group_by:
	| | | | | | | | | GROUP BY { "C_SQ".$child_subquery_idx. ($c_sq_ifields ? "_ifield1" : "_cfield1") } ;

double_child_subquery_group_by:
	| | | | | | | | | GROUP BY { $fname = ($c_sq_ifields ? "_ifield" : "_cfield"); "C_SQ".$child_subquery_idx.$fname."1".", C_SQ".$child_subquery_idx.$fname."2" } ;

child_subquery_having:
	| | | | | | | | | | HAVING child_subquery_having_list ;

child_subquery_having_list:
	child_subquery_having_item |
	child_subquery_having_item |
	(child_subquery_having_list and_or child_subquery_having_item)  ;

child_subquery_having_item:
	existing_child_subquery_int_select_item arithmetic_operator _digit |
	existing_child_subquery_char_select_item arithmetic_operator _char ;

existing_child_subquery_select_item:
	existing_child_subquery_int_select_item | existing_child_subquery_char_select_item ; 

existing_child_subquery_int_select_item:
	{ "C_SQ".$child_subquery_idx. ($c_sq_ifields ? "_ifield".$prng->int(1,$c_sq_ifields) : "_cfield".$prng->int(1,$c_sq_cfields)) };

existing_child_subquery_char_select_item:
	{ "C_SQ".$child_subquery_idx. ($c_sq_cfields ? "_cfield".$prng->int(1,$c_sq_cfields) : "_ifield".$prng->int(1,$c_sq_ifields)) };


################################################################################
# The range_predicate_1* rules below are in place to ensure we hit the
# index_merge/sort_union optimization.
# NOTE: combinations of the predicate_1 and predicate_2 rules tend to hit the
# index_merge/intersect optimization
################################################################################

range_predicate1_list:
	range_predicate1_item | 
	( range_predicate1_item OR range_predicate1_list ) ;

range_predicate1_item:
	 alias1 . _field_int not BETWEEN _tinyint_unsigned[invariant] AND ( _tinyint_unsigned[invariant] + _tinyint_unsigned ) |
	 alias1 . _field_char arithmetic_operator _char[invariant]  |
	 alias1 . _field_int not IN (number_list) |
	 alias1 . _field_char not IN (char_list) |
	 alias1 . _field > _tinyint_unsigned[invariant] AND alias1 . _field < ( _tinyint_unsigned[invariant] + _tinyint_unsigned ) |
	 alias1 . _field_int > _tinyint_unsigned[invariant] AND alias1 . _field_int < ( _tinyint_unsigned[invariant] + _tinyint_unsigned ) ;

################################################################################
# The range_predicate_2* rules below are in place to ensure we hit the
# index_merge/union optimization.
# NOTE: combinations of the predicate_1 and predicate_2 rules tend to hit the
# index_merge/intersect optimization
################################################################################

range_predicate2_list:
	range_predicate2_item | 
	( range_predicate2_item and_or range_predicate2_list ) ;

range_predicate2_item:
	alias1 . _field = _tinyint_unsigned |
	alias1 . _field_int = _tinyint_unsigned |
	alias1 . _field_char = _char |
	alias1 . _field_int = _tinyint_unsigned |
	alias1 . _field_char LIKE CONCAT( _char , '%') |
	alias1 . _field_int = existing_table_item . _field_int |
	alias1 . _field_char = existing_table_item . _field_char ;

################################################################################
# The number and char_list rules are for creating WHERE conditions that test
# 'field' IN (list_of_items)
################################################################################
number_list:
	_tinyint_unsigned | number_list, _tinyint_unsigned ;

char_list:
	_char | _char | _char | _char | 'USA' | char_list , _char | char_list , _char | char_list , 'USA' ;

################################################################################
# We ensure that a GROUP BY statement includes all nonaggregates.
# This helps to ensure the query is more useful in detecting real errors
# that the query doesn't lend itself to variable result sets
################################################################################
group_by_clause:
	{ scalar(@nonaggregates) > 0 ? " GROUP BY ".join (', ' , @nonaggregates ) : "" }  ;

optional_group_by:
	| | group_by_clause ;

having_clause:
	| HAVING having_list;

having_list:
	having_item |
	having_item |
	(having_list and_or having_item)  ;

having_item:
	existing_int_select_item arithmetic_operator value |
	existing_int_select_item arithmetic_operator value |
	existing_int_select_item arithmetic_operator value |
	existing_int_select_item arithmetic_operator value |
	existing_int_select_item arithmetic_operator value |
	existing_int_select_item arithmetic_operator value ;
# TODO: Commented due to MDEV-7691, uncomment when fixed
#	{ $subquery_idx += 1 ; $subquery_tables=0 ; $sq_ifields = 0; $sq_cfields = 0; ""} having_subquery;

having_subquery:
	existing_int_select_item arithmetic_operator int_single_value_subquery  |
	existing_char_select_item arithmetic_operator char_single_value_subquery |
	existing_int_select_item membership_operator int_single_member_subquery  |
	existing_int_select_item membership_operator int_single_value_subquery  |
	_digit membership_operator int_single_member_subquery  |
	_char membership_operator char_single_member_subquery  |
	( existing_int_select_item , existing_int_select_item ) not IN int_double_member_subquery |
	existing_char_select_item membership_operator char_single_member_subquery  |
	existing_char_select_item membership_operator char_single_value_subquery  |
	( existing_char_select_item , existing_char_select_item ) not IN char_double_member_subquery |
	( _digit, _digit ) not IN int_double_member_subquery |
	( _char, _char ) not IN char_double_member_subquery |
	existing_int_select_item membership_operator int_single_union_subquery |
	existing_char_select_item membership_operator char_single_union_subquery ;


################################################################################
# We use the total_order_by rule when using the LIMIT operator to ensure that
# we have a consistent result set - server1 and server2 should not differ
################################################################################

order_by_clause:
	|
	ORDER BY total_order_by limit |
	ORDER BY partial_order_by |
	order_by_anon;

# TODO: Uncomment after MDEV-9513 and MDEV-9514 are fixed
order_by_anon:
#	ORDER BY 1 | ORDER BY 2 | ORDER BY 2, 1 | ORDER BY RAND();
#	ORDER BY 1 | ORDER BY RAND()
;

partial_order_by:
   { join(', ', (shuffle ( (map { "field".$_ } 1..$fields), (map { "ifield".$_ } 1..$ifields), (map { "cfield".$_ } 1..$cfields) ))[0..int(rand($fields+$ifields+$cfields))] ) };

total_order_by:
	{ join(', ', shuffle ( (map { "field".$_ } 1..$fields), (map { "ifield".$_ } 1..$ifields), (map { "cfield".$_ } 1..$cfields) ) ) };

desc:
	ASC | | DESC ; 


limit:
	| | LIMIT limit_size | LIMIT limit_size OFFSET int_value;

new_select_item:
	nonaggregate_select_item |
	nonaggregate_select_item |
	aggregate_select_item |
	combo_select_item |
	nonaggregate_select_item |
	nonaggregate_select_item |
	aggregate_select_item |
	select_subquery;

primitive_select_item:
	nonaggregate_select_item | aggregate_select_item ;
 
################################################################################
# We have the perl code here to help us write more sensible queries
# It allows us to use field1...fieldn in the WHERE, ORDER BY, and GROUP BY
# clauses so that the queries will produce more stable and interesting results
################################################################################

nonaggregate_select_item:
	_tinyint AS { my $f = "ifield".++$ifields ; push @nonaggregates , $f ; $f } |
	_char AS { my $f = "cfield".++$cfields ; push @nonaggregates , $f ; $f } |
	table_one_two . _field AS { my $f = "field".++$fields ; push @nonaggregates , $f ; $f } |
	table_one_two . _field_int AS { my $f = "ifield".++$ifields ; push @nonaggregates , $f ; $f } |
	table_one_two . _field_char AS { my $f = "cfield".++$cfields ; push @nonaggregates , $f ; $f } |
	table_one_two . _field AS { my $f = "field".++$fields ; push @nonaggregates , $f ; $f } |
	table_one_two . _field_int AS { my $f = "ifield".++$ifields ; push @nonaggregates , $f ; $f } |
	table_one_two . _field_char AS { my $f = "cfield".++$cfields ; push @nonaggregates , $f ; $f } |
	table_one_two . _field AS { my $f = "field".++$fields ; push @nonaggregates , $f ; $f } |
	table_one_two . _field_int AS { my $f = "ifield".++$ifields ; push @nonaggregates , $f ; $f } |
	table_one_two . _field_char AS { my $f = "cfield".++$cfields ; push @nonaggregates , $f ; $f } ;

aggregate_select_item:
	aggregate table_one_two . _field ) AS { "field".++$fields } |
	aggregate_group_concat AS { "cfield".++$cfields };

select_subquery:
	 { $subquery_idx += 1 ; $subquery_tables=0 ; $sq_ifields = 0; $sq_cfields = 0; ""} select_subquery_body;

select_subquery_body:
	 int_single_value_subquery AS { my $f = "field".++$fields ; push @nonaggregates , $f ; $f } |
	 char_single_value_subquery AS { my $f = "field".++$fields ; push @nonaggregates , $f ; $f } |
	 int_scalar_correlated_subquery AS  { my $f = "field".++$fields ; push @nonaggregates , $f ; $f } ;

select_subquery_body_disabled:
	 (  SELECT _digit  UNION all_distinct  ( SELECT _digit ) LIMIT 1 )  AS  { my $f = "field".++$fields ; push @nonaggregates , $f ; $f } |
	 (  SELECT _char  UNION all_distinct ( SELECT _char ) LIMIT 1 )  AS  { my $f = "field".++$fields ; push @nonaggregates , $f ; $f } ;

################################################################################
# The combo_select_items are for 'spice' 
################################################################################

combo_select_item:
	( ( table_one_two . _field_int ) math_operator ( table_one_two . _field_int ) ) AS { my $f = "ifield".++$ifields ; push @nonaggregates , $f ; $f } |
	CONCAT( table_one_two . _field_char , table_one_two . _field_char ) AS { my $f = "cfield".++$cfields ; push @nonaggregates , $f ; $f } ;

table_one_two:
	existing_table_item ;

subquery_table_one_two:
	existing_subquery_table_item ;

child_subquery_table_one_two:
	existing_child_subquery_table_item ;

aggregate:
	COUNT( distinct | SUM( distinct | MIN( distinct | MAX( distinct ;

aggregate_group_concat:
	{$count_gc_fields = 0; '' } GROUP_CONCAT( aggregate_list aggregate_order_by aggregate_separator ) ;

aggregate_list:
	{ $count_gc_fields++; '' } table_one_two . _field | 
	{ $count_gc_fields++; '' } table_one_two . _field , aggregate_list | 
	{ $count_gc_fields++; '' } IF( table_one_two . _field , table_one_two . _field , table_one_two . _field ), aggregate_list;

aggregate_order_by:
	aggregate_order_by_fields ;
	aggregate_order_by_fields | aggregate_order_by_fields | aggregate_order_by_fields | aggregate_order_by_fields | aggregate_order_by_fields | 
	aggregate_order_by_fields, ( aggregate_order_by_subquery ) | ( aggregate_order_by_subquery ), aggregate_order_by_fields ;

aggregate_order_by_subquery:
	ORDER BY { $subquery_idx += 1 ; $subquery_tables=0 ; $sq_ifields = 0; $sq_cfields = 0; ""} subquery_type ;

aggregate_order_by_fields:
	ORDER BY { join ',', shuffle 1..$count_gc_fields } ;	

aggregate_separator:
	| SEPARATOR ',' | SEPARATOR '___' ;



################################################################################
# The following rules are for writing more sensible queries - that we don't
# reference tables / fields that aren't present in the query and that we keep
# track of what we have added.  You shouldn't need to touch these ever
################################################################################
new_table_item:
	smart_table AS { "alias".++$tables } | _table AS { "alias".++$tables } | _table AS { "alias".++$tables } |
	( from_subquery ) AS { "alias".++$tables } ;

from_subquery:
	   { $subquery_idx += 1 ; $subquery_tables=0 ; $sq_ifields = 0; $sq_cfields = 0; ""}  SELECT distinct select_option subquery_table_one_two . * subquery_body  ;

subquery_new_table_item:
	smart_table AS { "SQ".$subquery_idx."_alias".++$subquery_tables } ;

child_subquery_new_table_item:
	smart_table AS { "C_SQ".$child_subquery_idx."_alias".++$child_subquery_tables } ;	  

current_table_item:
	{ "alias".$tables };

subquery_current_table_item:
	{ "SQ".$subquery_idx."_alias".$subquery_tables } ;

child_subquery_current_table_item:
	{ "C_SQ".$child_subquery_idx."_alias".$child_subquery_tables } ;

previous_table_item:
	{ "alias".($tables - 1) };

subquery_previous_table_item:
	{ "SQ".$subquery_idx."_alias".($subquery_tables-1) } ;

child_subquery_previous_table_item:
	{ "C_SQ".$child_subquery_idx."_alias".($child_subquery_tables-1) } ;

existing_table_item:
	{ "alias".$prng->int(1,$tables) };

existing_subquery_table_item:
	{ "SQ".$subquery_idx."_alias".$prng->int(1,$subquery_tables) } ;

existing_child_subquery_table_item:
	{ "C_SQ".$child_subquery_idx."_alias".$prng->int(1,$child_subquery_tables) } ;

existing_select_item:
	{ $fields ? "field".$prng->int(1,$fields) : ( $ifields ? "ifield".$prng->int(1,$ifields) : "cfield".$prng->int(1,$cfields) ) };

existing_int_select_item:
	{ $ifields ? "ifield".$prng->int(1,$ifields) : ( $fields ? "field".$prng->int(1,$fields) : "cfield".$prng->int(1,$cfields) ) };

existing_char_select_item:
	{ $cfields ? "cfield".$prng->int(1,$cfields) : ( $fields ? "field".$prng->int(1,$fields) : "ifield".$prng->int(1,$ifields) ) };

################################################################################
# end of utility rules
################################################################################

arithmetic_operator:
	= | > | < | != | <> | <= | >= ;


membership_operator:
	arithmetic_operator all_any |
	not IN |
	not IN ;

all_any:
	ALL | ANY | SOME ;

################################################################################
# Used for creating combo_items - ie (field1 + field2) AS fieldX
# We ignore division to prevent division by zero errors
################################################################################
math_operator:
	+ | - | * ;

################################################################################
# We stack AND to provide more interesting options for the optimizer
# Alter these percentages at your own risk / look for coverage regressions
# with --debug if you play with these.  Those optimizations that require an
# OR-only list in the WHERE clause are specifically stacked in another rule
################################################################################
and_or:
   AND | AND | OR ;

all_distinct:
   | | | | |
   | | | ALL | DISTINCT ;

	
value:
	_digit | _digit | _digit | _digit | _tinyint_unsigned|
	_char(1) | _char(1) | _char(1) | _char(2) | _char(2) | 'USA' ;

################################################################################
# Add a possibility for 'view' to occur at the end of the previous '_table' rule
# to allow a chance to use views (when running the RQG with --views)
################################################################################

_digit:
	1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | _tinyint_unsigned ;


################################################################################
# We define LIMIT_rows in this fashion as LIMIT values can differ depending on
# how large the LIMIT is - LIMIT 2 = LIMIT 9 != LIMIT 19
################################################################################

limit_size:
	1 | 2 | 10 | 100 | 1000;


#################################################################################
#################################################################################
#-------------------------------------------------------------------------------#
#---- This part of the grammar was derived from range_access.yy ----------------#
#-------------------------------------------------------------------------------#
#################################################################################
#################################################################################

range_access:
  { $idx_table = '' ; %idx_fields = () ;  "" } range_access_query_type ;

range_access_query_type:
    single_idx_query_set 
  | dual_int_idx_query_set 
  | dual_char_idx_query_set 
  | tri_int_idx_query_set 
  | tri_char_idx_query_set 
;

single_idx_query_set:
  single_idx_query ; single_idx_query ; single_idx_query ; single_idx_query ; single_idx_query ; 

dual_int_idx_query_set:
  new_dual_int_index ; multi_int_idx_query_set ;

dual_char_idx_query_set:
  new_dual_char_index ; multi_char_idx_query_set ;

tri_int_idx_query_set:
  new_tri_int_index ; multi_int_idx_query_set ;

tri_char_idx_query_set:
  new_tri_char_index ; multi_char_idx_query_set ;

wild_query:
  single_idx_query | multi_int_idx_query | multi_char_idx_query ;

multi_int_idx_query_set:
  multi_int_idx_query ; multi_int_idx_query ; multi_int_idx_query ; multi_int_idx_query ; multi_int_idx_query ; wild_query ; drop_index ;  

multi_char_idx_query_set:
  multi_char_idx_query ; multi_char_idx_query ; multi_char_idx_query ; multi_char_idx_query ; multi_char_idx_query ; wild_query ; drop_index ;

################################################################################
# index-specific rules
################################################################################

drop_index:
 DROP INDEX `test_idx` ON { $idx_table } ;

index_pre:
  ALTER TABLE index_table { $suitable_columns = ${$table_columns_by_type{$idxcoltype}}{$idx_table}; '' } ADD INDEX `test_idx` USING index_type ;

new_dual_int_index:
  { $idxcoltype = 'int'; '' } index_pre (dual_idx_field_list);

new_dual_char_index:
  { $idxcoltype = 'char'; '' } index_pre (dual_idx_field_list);

new_tri_int_index:
  { $idxcoltype = 'int'; '' } index_pre (tri_idx_field_list);

new_tri_char_index:
  { $idxcoltype = 'char'; '' } index_pre (tri_idx_field_list);

dual_idx_field_list:
  unique_field_for_index unique_field_for_index;
    
tri_idx_field_list:
  unique_field_for_index unique_field_for_index unique_field_for_index;

unique_field_for_index:
  { if (scalar(%idx_fields)>= scalar(@$suitable_columns)) { "/* Not enough $idxcoltype columns for $idx_table, only @$suitable_columns */" } else { do { $last_field = $prng->arrayElement($suitable_columns) } until (not defined $idx_fields{$last_field}); $idx_fields{$last_field} = 1; (scalar(keys %idx_fields) > 1 ? ', ' : '') . $last_field } };


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
   {  $int_idx_field = $idx_table_alias." . ".$prng->arrayElement([keys %idx_fields]) ; "" } single_int_idx_where_list ;

# char rules
multi_char_idx_where_list:
    multi_char_idx_where_clause |
    multi_char_idx_where_list and_or multi_char_idx_where_clause | multi_char_idx_where_list and_or multi_char_idx_where_clause ;

multi_char_idx_where_clause:
   {  $char_idx_field = $idx_table_alias." . ".$prng->arrayElement([keys %idx_fields]) ; "" } single_char_idx_where_list ;
  


################################################################################
# general-purpose query rules
################################################################################

single_idx_query:
  { $tables=0 ; $fields = 0 ; "" }  SELECT straight_join range_access_select_list FROM join WHERE single_idx_where_list opt_where_list range_access_group_by_clause range_access_order_by_clause ;

multi_int_idx_query:
  { $tables=0 ; $fields = 0 ; "" }  SELECT straight_join range_access_select_list FROM idx_join WHERE multi_int_idx_where_list opt_where_list range_access_group_by_clause range_access_order_by_clause ;

multi_char_idx_query:
  { $tables=0 ; $fields = 0 ; "" }  SELECT straight_join range_access_select_list FROM idx_join WHERE multi_char_idx_where_list opt_where_list range_access_group_by_clause range_access_order_by_clause ;

range_access_select_list:
  select_item | select_item , range_access_select_list ;

select_item:
  table_one_two . _field AS { my $f = "field".++$fields ; $f } ; 

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
       { $stack->push(); '' } smart_base_table { my $x = " AS alias".++$tables;  my @s=($last_table.$x); $stack->pop(\@s); $x } ;

idx_table_for_join:
       { $stack->push() ; my $x = $idx_table." AS alias".++$tables; $idx_table_alias = "alias".$tables; my @s=($x); $stack->pop(\@s); $x } ;

index_type:
  BTREE | HASH ;

index_table:
  smart_base_table { my $idx_table_candidate = $last_table ; $idx_table = $idx_table_candidate ; '' } ;

opt_where_list:
  | | | | and_or range_access_where_list ;

range_access_where_list:
  range_access_where_item | range_access_where_item | range_access_where_item | ( range_access_where_list and_or range_access_where_item ) ;

range_access_where_item:
  existing_table_item . int_field_name comparison_operator int_value |
  existing_table_item . char_field_name comparison_operator _char |
  existing_table_item . int_field_name comparison_operator int_value |
  existing_table_item . int_field_name comparison_operator existing_table_item . int_field_name |
  existing_table_item . char_field_name comparison_operator _char |
  existing_table_item . char_field_name comparison_operator existing_table_item . char_field_name |
  existing_table_item . _field IS not NULL |
  existing_table_item . int_field_name IS not NULL |
  single_idx_where_list ;

range_access_group_by_clause:
	| | | | | GROUP BY { @groupby = (); for (1..$fields) { push @groupby, 'field'.$_ }; join ',', @groupby } ;

range_access_order_by_clause:
	| | |
    ORDER BY range_access_total_order_by desc limit |
	ORDER BY order_by_list  ;

range_access_total_order_by:
	{ join(', ', map { "field".$_ } (1..$fields) ) };

order_by_list:
	order_by_item  |
	order_by_item  , order_by_list ;

order_by_item:
	range_access_existing_select_item desc ;

################################################################################
# utility / helper rules
################################################################################

range_access_existing_select_item:
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

or_and:
  OR | OR | OR | AND ;
