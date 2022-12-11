# Copyright (c) 2008, 2011 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2014 SkySQL Ab
# Copyright (c) 2015, 2022 MariaDB Corporation Ab
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


#features: multi-update/delete


query_init:
  { $total_dur = 0; "" };

query:
  { @nonaggregates = () ; %tables = () ; $tables = 0 ; $fields = 0 ; $ifields = 0; $cfields = 0; $subquery_idx=0 ; $child_subquery_idx=0; '' } multi_query ;

multi_query:
  { _set_db('NON-SYSTEM') }   multi_main_dml |
  { _set_db('simple_db') } multi_update_delete
;

multi_main_dml:
    ==FACTOR:10== multi_main_update |
    multi_loose_scan_update |
    multi_store_data ;; multi_main_delete ;; multi_restore_data
;

################################################################################
# The loose* rules listed below are to hit the 'Using index for group-by'
# optimization.  This optimization has some strict requirements, thus
# we needed a separate query pattern to ensure we hit it.
################################################################################
multi_loose_scan_update:
  UPDATE __ignore(50) new_table_item
  SET table_one_two._field_int = _tinyint
  WHERE generic_where_list ;

loose_select_clause:
  loose_select_list |
  MIN( _field_indexed) AS { "field".++$fields } , loose_select_list |
  MAX( _field_indexed) AS { "field".++$fields } , loose_select_list |
  MIN( _field_indexed[invariant] ) AS { "field".++$fields }, MAX( _field_indexed[invariant] ) AS { "field".++$fields }, loose_select_list ;

loose_select_list:
  loose_select_item |
  loose_select_item , loose_select_list ;

loose_select_item:
  _field AS { my $f = "field".++$fields ; push @nonaggregates , $f ; $f } |
  _field_int AS { my $f = "ifield".++$ifields ; push @nonaggregates , $f ; $f } |
  _field_char AS { my $f = "cfield".++$cfields ; push @nonaggregates , $f ; $f } ;

################################################################################

multi_store_data:
    CREATE OR REPLACE TEMPORARY TABLE { 'multi_tmp1_'.abs($$) } AS SELECT * FROM _table { $tables{alias1} = [$last_database, $last_table] }
    ;; CREATE OR REPLACE TEMPORARY TABLE { 'multi_tmp2_'.abs($$) } AS SELECT * FROM _table { $tables{alias2} = [$last_database, $last_table] }
;

multi_restore_data:
    TRUNCATE { $tables{alias1}->[0].'.'$tables{alias1}->[1] }
  ;; INSERT INTO { $tables{alias1}->[0].'.'$tables{alias1}->[1] } SELECT * FROM { 'multi_tmp1_'.abs($$) }
  ;; TRUNCATE { $tables{alias2}->[0].'.'$tables{alias2}->[1] }
  ;; INSERT INTO { $tables{alias2}->[0].'.'$tables{alias2}->[1] } SELECT * FROM { 'multi_tmp2_'.abs($$) }
;

multi_main_update:
  UPDATE __ignore(50) join_list
  SET table_one_two._field_int = _tinyint
  where_clause;

multi_main_delete:
  DELETE __ignore(50) table_one_two FROM join_list where_clause |
  DELETE __ignore(50) alias1, alias2 FROM join_list where_clause
;

explain_extended:
  | | | | | | | | | explain_extended2 ;

# Disabled due to MDEV-16694
explain_extended2:
#  | | | | EXPLAIN | EXPLAIN EXTENDED
;

distinct: DISTINCT | | | | | | | | | ;

select_option:  | | | | | | | | | | | SQL_SMALL_RESULT ;

straight_join:  | | | | | | | | | | | | | | | | | | | | | STRAIGHT_JOIN ;

select_list:
  new_select_item |
  new_select_item , select_list |
  new_select_item , select_list ;

simple_select_list:
  nonaggregate_select_item |
  nonaggregate_select_item , simple_select_list |
  nonaggregate_select_item , simple_select_list ;

aggregate_select_list:
  aggregate_select_item | aggregate_select_item |
  aggregate_select_item, aggregate_select_list ;

join_list:
################################################################################
# this limits us to 2 and 3 table joins / can use it if we hit
# too many mega-join conditions which take too long to run
################################################################################
  ( new_table_item join_type new_table_item ON (join_condition_list ) ) |
  ( new_table_item join_type ( ( new_table_item join_type new_table_item ON (join_condition_list ) ) ) ON (join_condition_list ) ) |
  ( new_table_item , new_table_item ) |
  ( new_table_item , new_table_item , new_table_item ) ;


join_list_disabled:
################################################################################
# preventing deep join nesting for run time / table access methods are more
# important here - join.yy can provide deeper join coverage
# Enabling this / swapping out with join_list above can produce some
# time-consuming queries.
################################################################################

  new_table_item |
  ( new_table_item join_type join_list ON (join_condition_list ) ) ;

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
  ( current_table_item  . _field_pk arithmetic_operator previous_table_item . _field ) AND (current_table_item  . _field_pk arithmetic_operator previous_table_item . _field ) ;

join_condition_item:
  current_table_item . _field_int_indexed = previous_table_item . _field_int on_subquery |
  current_table_item . _field_int = previous_table_item . _field_int_indexed on_subquery |
  current_table_item . _field_char_indexed = previous_table_item . _field_char on_subquery |
  current_table_item . _field_char = previous_table_item . _field_char_indexed on_subquery |
  current_table_item . _field_int_indexed arithmetic_operator previous_table_item . _field_int on_subquery |
  current_table_item . _field_int arithmetic_operator previous_table_item . _field_int_indexed on_subquery |
  current_table_item . _field_char_indexed arithmetic_operator previous_table_item . _field_char on_subquery |
  current_table_item . _field_char arithmetic_operator previous_table_item . _field_char_indexed on_subquery ;

on_subquery:
  |||||||||||||||||||| { $subquery_idx += 1 ; $subquery_tables=0 ; $sq_ifields = 0; $sq_cfields = 0; ""} and_or general_subquery ;


left_right:
  LEFT | RIGHT ;

outer:
  | OUTER ;

where_clause:
  WHERE where_subquery |
  WHERE where_list |
   WHERE ( where_subquery ) and_or where_list |
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
  degenerate_where_item ;

real_where_item:
  where_subquery  |
  existing_table_item . _field_char arithmetic_operator _char  |
  existing_table_item . _field_char arithmetic_operator existing_table_item . _field_char |
  existing_table_item . _field arithmetic_operator value  |
  existing_table_item . _field arithmetic_operator existing_table_item . _field |
  { ($last_database, $last_table) = @{$tables{alias1}}; 'alias1' } . _field IS not NULL |
  { ($last_database, $last_table) = @{$tables{alias1}}; 'alias1' } . _field_pk IS not NULL |
  { ($last_database, $last_table) = @{$tables{alias1}}; 'alias1' } . _field_pk arithmetic_operator existing_table_item . _field  |
  { ($last_database, $last_table) = @{$tables{alias1}}; 'alias1' } . _field_int arithmetic_operator existing_table_item . _field_int  |
  { ($last_database, $last_table) = @{$tables{alias1}}; 'alias1' } . _field_indexed arithmetic_operator value AND ( alias1 . _field_char LIKE '%a%' OR alias1._field_char LIKE '%b%') ;


################################################################################
# subquery rules
################################################################################

where_subquery:
  { $subquery_idx += 1 ; $subquery_tables=0 ; $sq_ifields = 0; $sq_cfields = 0; ""} subquery_type ;

subquery_type:
  general_subquery | special_subquery ;

general_subquery:
  existing_table_item . _field_int arithmetic_operator  int_single_value_subquery  |
  existing_table_item . _field_char arithmetic_operator char_single_value_subquery |
  existing_table_item . _field_int membership_operator  int_single_member_subquery  |
  existing_table_item . _field_int membership_operator  int_single_value_subquery  |
  _digit membership_operator  int_single_member_subquery  |
  _char membership_operator  char_single_member_subquery  |
  ( existing_table_item . _field_int , existing_table_item . _field_int ) not IN int_double_member_subquery |
  existing_table_item . _field_char membership_operator  char_single_member_subquery  |
  existing_table_item . _field_char membership_operator  char_single_value_subquery  |
  ( existing_table_item . _field_char , existing_table_item . _field_char ) not IN char_double_member_subquery |
  ( _digit, _digit ) not IN int_double_member_subquery |
  ( _char, _char ) not IN char_double_member_subquery |
  existing_table_item . _field_int membership_operator int_single_union_subquery |
  existing_table_item . _field_char membership_operator char_single_union_subquery ;

general_subquery_union_test_disabled:
  existing_table_item . _field_char arithmetic_operator all_any char_single_union_subquery_disabled |
  existing_table_item . _field_int arithmetic_operator all_any int_single_union_subquery_disabled ;

special_subquery:
  not EXISTS ( int_single_member_subquery ) |
  not EXISTS ( char_single_member_subquery ) |
  not EXISTS int_correlated_subquery |
  not EXISTS char_correlated_subquery  |
  existing_table_item . _field_int membership_operator  int_correlated_subquery  |
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
  (  SELECT _digit  UNION all_distinct  SELECT _digit  )  ;

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

char_single_member_subquery:
  ( SELECT distinct select_option subquery_table_one_two . _field_char AS { $sq_cfields = 1; "SQ".$subquery_idx."_cfield1" }
   subquery_body
   single_subquery_group_by
   subquery_having) ;

char_single_union_subquery:
  (  SELECT _char  UNION all_distinct  SELECT _char  )  ;

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
  existing_subquery_table_item . _field_char arithmetic_operator existing_table_item . _field_char ;
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
   ( subquery_new_table_item , subquery_new_table_item ) |
   ( subquery_new_table_item join_type subquery_new_table_item ON (subquery_join_condition_item ) ) |
   ( subquery_new_table_item join_type subquery_new_table_item ON (subquery_join_condition_item ) ) |
   ( subquery_new_table_item join_type ( subquery_new_table_item join_type subquery_new_table_item ON (subquery_join_condition_item )  ) ON (subquery_join_condition_item ) ) ;

subquery_join_condition_item:
  subquery_current_table_item . _field_int = subquery_previous_table_item . _field_int_indexed subquery_on_subquery |
  subquery_current_table_item . _field_int_indexed = subquery_previous_table_item . _field_int subquery_on_subquery |
  subquery_current_table_item . _field_char_indexed = subquery_previous_table_item . _field_char subquery_on_subquery |
  subquery_current_table_item . _field_char = subquery_previous_table_item . _field_char_indexed subquery_on_subquery ;

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
  existing_subquery_table_item . _field_char arithmetic_operator char_single_value_child_subquery |
  existing_subquery_table_item . _field_int membership_operator  int_single_member_child_subquery  |
  ( existing_subquery_table_item . _field_int , existing_subquery_table_item . _field_int ) not IN int_double_member_child_subquery |
  existing_subquery_table_item . _field_char membership_operator  char_single_member_child_subquery  |
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
   ( child_subquery_new_table_item join_type child_subquery_new_table_item ON (child_subquery_join_condition_item ) ) |
   ( child_subquery_new_table_item join_type child_subquery_new_table_item ON (child_subquery_join_condition_item ) ) |
   ( child_subquery_new_table_item join_type ( ( child_subquery_new_table_item join_type child_subquery_new_table_item ON (child_subquery_join_condition_item ) ) ) ON (child_subquery_join_condition_item ) ) ;

child_subquery_join_condition_item:
  child_subquery_current_table_item . _field_int = child_subquery_previous_table_item . _field_int_indexed |
  child_subquery_current_table_item . _field_int_indexed = child_subquery_previous_table_item . _field_int |
  child_subquery_current_table_item . _field_char_indexed = child_subquery_previous_table_item . _field_char |
  child_subquery_current_table_item . _field_char = child_subquery_previous_table_item . _field_char_indexed ;

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
   { ($last_database, $last_table) = @{$tables{alias1}}; 'alias1' } . _field_int_indexed not BETWEEN _tinyint_unsigned[invariant] AND ( _tinyint_unsigned[invariant] + _tinyint_unsigned ) |
   { ($last_database, $last_table) = @{$tables{alias1}}; 'alias1' } . _field_char_indexed arithmetic_operator _char[invariant]  |
   { ($last_database, $last_table) = @{$tables{alias1}}; 'alias1' } . _field_int_indexed not IN (number_list) |
   { ($last_database, $last_table) = @{$tables{alias1}}; 'alias1' } . _field_char_indexed not IN (char_list) |
   { ($last_database, $last_table) = @{$tables{alias1}}; 'alias1' } . _field_pk > _tinyint_unsigned[invariant] AND alias1 . _field_pk < ( _tinyint_unsigned[invariant] + _tinyint_unsigned ) |
   { ($last_database, $last_table) = @{$tables{alias1}}; 'alias1' } . _field_int_indexed > _tinyint_unsigned[invariant] AND alias1 . _field_int_indexed < ( _tinyint_unsigned[invariant] + _tinyint_unsigned ) ;

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
  { ($last_database, $last_table) = @{$tables{alias1}}; 'alias1' } . _field_pk = _tinyint_unsigned |
  { ($last_database, $last_table) = @{$tables{alias1}}; 'alias1' } . _field_int_indexed = _tinyint_unsigned |
  { ($last_database, $last_table) = @{$tables{alias1}}; 'alias1' } . _field_char_indexed = _char |
  { ($last_database, $last_table) = @{$tables{alias1}}; 'alias1' } . _field_int_indexed = _tinyint_unsigned |
  { ($last_database, $last_table) = @{$tables{alias1}}; 'alias1' } . _field_char_indexed LIKE CONCAT( _char , '%') |
  { ($last_database, $last_table) = @{$tables{alias1}}; 'alias1' } . _field_int_indexed = existing_table_item . _field_int_indexed |
  { ($last_database, $last_table) = @{$tables{alias1}}; 'alias1' } . _field_char_indexed = existing_table_item . _field_char_indexed ;

################################################################################
# The number and char_list rules are for creating WHERE conditions that test
# 'field' IN (list_of_items)
################################################################################
number_list:
  _tinyint_unsigned | number_list, _tinyint_unsigned ;

char_list:
  _char | 'USA' | char_list , _char | char_list , 'USA' ;

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
  existing_int_select_item arithmetic_operator value |
  { $subquery_idx += 1 ; $subquery_tables=0 ; $sq_ifields = 0; $sq_cfields = 0; ""} having_subquery;

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
  ORDER BY partial_order_by;

partial_order_by:
   { join(', ', (shuffle ( (map { "field".$_ } 1..$fields), (map { "ifield".$_ } 1..$ifields), (map { "cfield".$_ } 1..$cfields) ))[0..int(rand($fields+$ifields+$cfields))] ) };

total_order_by:
  { join(', ', shuffle ( (map { "field".$_ } 1..$fields), (map { "ifield".$_ } 1..$ifields), (map { "cfield".$_ } 1..$cfields) ) ) };

desc:
  ASC | | DESC ;


limit:
  | | LIMIT limit_size | LIMIT limit_size OFFSET _digit;

new_select_item:
  nonaggregate_select_item |
  nonaggregate_select_item |
  aggregate_select_item |
  combo_select_item |
  nonaggregate_select_item |
  nonaggregate_select_item |
  aggregate_select_item ;

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
  table_one_two . _field_indexed AS { my $f = "field".++$fields ; push @nonaggregates , $f ; $f } |
  table_one_two . _field_int_indexed AS { my $f = "ifield".++$ifields ; push @nonaggregates , $f ; $f } |
  table_one_two . _field_char_indexed AS { my $f = "cfield".++$cfields ; push @nonaggregates , $f ; $f } |
  table_one_two . _field_indexed AS { my $f = "field".++$fields ; push @nonaggregates , $f ; $f } |
  table_one_two . _field_int_indexed AS { my $f = "ifield".++$ifields ; push @nonaggregates , $f ; $f } |
  table_one_two . _field_char_indexed AS { my $f = "cfield".++$cfields ; push @nonaggregates , $f ; $f } |
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
   { $alias="alias".++$tables; $tables{$alias}=$prng->arrayElement($executors->[0]->metaTables($work_database)) if not defined $tables{$alias}; $tables{$alias}->[0].'.'$tables{$alias}->[1] } AS { $alias } ;
#  ( from_subquery ) AS { "alias".++$tables } ;

from_subquery:
     { $subquery_idx += 1 ; $subquery_tables=0 ; $sq_ifields = 0; $sq_cfields = 0; ""}  SELECT distinct select_option subquery_table_one_two . * subquery_body  ;

subquery_new_table_item:
   { $alias="SQ".$subquery_idx."_alias".++$subquery_tables; $tables{$alias}=$prng->arrayElement($executors->[0]->metaTables($work_database)) if not defined $tables{$alias}; $tables{$alias}->[0].'.'$tables{$alias}->[1] } AS { $alias } ;

child_subquery_new_table_item:
   { $alias="C_SQ".$child_subquery_idx."_alias".++$child_subquery_tables; $tables{$alias}=$prng->arrayElement($executors->[0]->metaTables($work_database)) if not defined $tables{$alias}; $tables{$alias}->[0].'.'$tables{$alias}->[1] } AS { $alias } ;

current_table_item:
  { $alias = "alias".$tables; ($last_database,$last_table)= @{$tables{$alias}}; $alias };

subquery_current_table_item:
  { $alias = "SQ".$subquery_idx."_alias".$subquery_tables; ($last_database,$last_table)= @{$tables{$alias}}; $alias } ;

child_subquery_current_table_item:
  { $alias = "C_SQ".$child_subquery_idx."_alias".$child_subquery_tables; ($last_database,$last_table)= @{$tables{$alias}}; $alias } ;

previous_table_item:
  { $alias="alias".($tables - 1) ; ($last_database,$last_table)= @{$tables{$alias}}; $alias };

subquery_previous_table_item:
  { $alias= "SQ".$subquery_idx."_alias".($subquery_tables-1); ($last_database,$last_table)= @{$tables{$alias}}; $alias } ;

child_subquery_previous_table_item:
  { $alias= "C_SQ".$child_subquery_idx."_alias".($child_subquery_tables-1); ($last_database,$last_table)= @{$tables{$alias}}; $alias } ;

existing_table_item:
  { $alias= "alias".$prng->int(1,$tables); $tables{$alias} = $prng->arrayElement($executors->[0]->metaTables($work_database)) if not defined $tables{$alias}; ($last_database,$last_table)= @{$tables{$alias}}; $alias };

existing_subquery_table_item:
  { $alias= "SQ".$subquery_idx."_alias".$prng->int(1,$subquery_tables); $tables{$alias} = $prng->arrayElement($executors->[0]->metaTables($work_database)) if not defined $tables{$alias}; ($last_database,$last_table)= @{$tables{$alias}}; $alias } ;

existing_child_subquery_table_item:
  { $alias="C_SQ".$child_subquery_idx."_alias".$prng->int(1,$child_subquery_tables); $tables{$alias} = $prng->arrayElement($executors->[0]->metaTables($work_database)) if not defined $tables{$alias}; ($last_database,$last_table)= @{$tables{$alias}}; $alias } ;

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


########################################################################
########################################################################
# Formerly contents of a different multi-update grammar
########################################################################

multi_update_delete:
  START TRANSACTION ;; multi_update_or_delete ;; ROLLBACK ;

multi_update_or_delete:
  main_update | main_update ;

main_update:
  explain_extended UPDATE priority_update ignore
  outer_table_join_with_set_where_subquery_expression ;

main_delete:
  delete1 | delete1 | delete2 | delete2 ;

delete1:
  explain_extended DELETE priority_update quick ignore
  delete_tab
  FROM non_comma_join
  WHERE subquery_expression_with_alias;

delete2:
  explain_extended DELETE priority_update quick ignore
  FROM delete_tab
  USING non_comma_join
        

delete_tab:
  OUTR1.* | OUTR1.*, OUTR2.* ;

priority_update:
  | LOW_PRIORITY ;

ignore:
  | | | | | | IGNORE ;

quick:
  | | | | | | | | | | QUICK ;

outer_table_join_with_set_where_subquery_expression:
  non_comma_join set_update_with_alias WHERE subquery_expression_with_alias |
  non_comma_join set_update_with_alias WHERE subquery_expression_with_alias |
  non_comma_join set_update_with_alias WHERE subquery_expression_with_alias |
  non_comma_join set_update_with_alias WHERE subquery_expression_with_alias |
  non_comma_join set_update_with_alias WHERE subquery_expression_with_alias |
  non_comma_join set_update_with_alias WHERE subquery_expression_with_alias |
  comma_join set_update_without_alias WHERE subquery_expression_without_alias |
  comma_join set_update_without_alias WHERE subquery_expression_without_alias |
  comma_join set_update_without_alias WHERE subquery_expression_without_alias |
  comma_join set_update_without_alias WHERE subquery_expression_without_alias;

non_comma_join:
  o_tab AS OUTR1 join o_tab AS OUTR2 ON ( outer_join_condition ) |
  o_tab AS OUTR1 join o_tab AS OUTR2 ON ( outer_join_condition ) join o_tab AS OUTR3 ON ( outer_join_condition2 ) ;

comma_join:
  o_tab AS OUTR1, o_tab AS OUTR2 ;
#  o_tab AS OUTR1, o_tab AS OUTR2 WHERE ( outer_join_condition ) ;

join:
  JOIN | RIGHT JOIN | LEFT JOIN | INNER JOIN | RIGHT OUTER JOIN | LEFT OUTER JOIN ;

outer_join_condition:
  OUTR1 . int_field_name = OUTR2 . int_field_name |
  OUTR1 . date_field_name = OUTR2 . date_field_name |
  OUTR1 . char_field_name = OUTR2 . char_field_name ;

outer_join_condition2:
  OUTR1 . int_field_name = OUTR3 . int_field_name |
  OUTR1 . date_field_name = OUTR3 . date_field_name |
  OUTR1 . char_field_name = OUTR3 . char_field_name ;

set_update_with_alias:
  SET OUTR1.set_field_name = value2 |
  SET OUTR1.set_field_name = value2, OUTR2.set_field_name = value2 ;

set_update_without_alias:
  SET OUTR1.char_field_name = value2 |
  SET OUTR1.char_field_name = value2, OUTR2.char_field_name = value2 ;

subquery_expression_with_alias:
  OUTR1 . int_field_name arithmetic_operator ( SELECT __distinct(50) INNR1 . int_field_name AS y select_inner_body ) |
  OUTR1 . char_field_name arithmetic_operator ( SELECT __distinct(50) INNR1 . char_field_name AS y select_inner_body ) |
  OUTR1 . int_field_name membership_operator ( SELECT __distinct(50) INNR1 . int_field_name AS y select_inner_body ) |
  OUTR1 . char_field_name membership_operator ( SELECT __distinct(50) INNR1 . char_field_name AS y select_inner_body ) |
  OUTR1 . int_field_name not IN ( SELECT __distinct(50) INNR1 . int_field_name AS y select_inner_body ) |
  OUTR1 . int_field_name not IN ( SELECT __distinct(50) INNR1 . int_field_name AS y select_inner_body ) |
  OUTR1 . char_field_name not IN ( SELECT __distinct(50) INNR1 . char_field_name AS y select_inner_body ) |
  OUTR1 . char_field_name not IN ( SELECT __distinct(50) INNR1 . char_field_name AS y select_inner_body ) |
  ( OUTR1 . int_field_name , OUTR1 . int_field_name ) not IN ( SELECT __distinct(50) INNR1 . int_field_name AS x , INNR1 . int_field_name AS y select_inner_body ) |
  ( OUTR1 . int_field_name , OUTR1 . int_field_name ) not IN ( SELECT __distinct(50) INNR1 . int_field_name AS x , INNR1 . int_field_name AS y select_inner_body ) |
  ( OUTR1 . char_field_name , OUTR1 . char_field_name ) not IN ( SELECT __distinct(50) INNR1 . char_field_name AS x , INNR1 . char_field_name AS y select_inner_body ) |
  ( OUTR1 . char_field_name , OUTR1 . char_field_name ) not IN ( SELECT __distinct(50) INNR1 . char_field_name AS x , INNR1 . char_field_name AS y select_inner_body ) |
  ( _digit, _digit ) not IN ( SELECT __distinct(50) INNR1 . int_field_name AS x , INNR1 . int_field_name AS y select_inner_body ) |
  ( _char, _char ) not IN ( SELECT __distinct(50) INNR1 . char_field_name AS x , INNR1 . char_field_name AS y select_inner_body ) |
  (_digit, _digit ) not IN ( SELECT __distinct(50) INNR1 . int_field_name AS x , INNR1 . int_field_name AS y select_inner_body ) |
  ( _char, _char ) not IN ( SELECT __distinct(50) INNR1 . char_field_name AS x , INNR1 . char_field_name AS y select_inner_body ) |
  OUTR1 . int_field_name membership_operator int_single_union_subquery |
  OUTR1 . char_field_name membership_operator char_single_union_subquery ;

subquery_expression_without_alias:
  OUTR1.int_field_name not IN ( SELECT __distinct(50) INNR1 . int_field_name AS y select_inner_body_without_alias ) |
  OUTR1.char_field_name not IN ( SELECT __distinct(50) INNR1 . char_field_name AS y select_inner_body_without_alias) |
  OUTR1.int_field_name arithmetic_operator ( SELECT __distinct(50) INNR1 . int_field_name AS y select_inner_body ) |
  OUTR1.char_field_name arithmetic_operator ( SELECT __distinct(50) INNR1 . char_field_name AS y select_inner_body ) |
   OUTR1.int_field_name membership_operator ( SELECT __distinct(50) INNR1 . int_field_name AS y select_inner_body ) |
  OUTR1.char_field_name membership_operator ( SELECT __distinct(50) INNR1 . char_field_name AS y select_inner_body ) |
  ( OUTR1.int_field_name, OUTR1.int_field_name ) not IN ( SELECT __distinct(50) INNR1 . int_field_name AS x , INNR1 . int_field_name AS y select_inner_body ) |
  ( OUTR1.char_field_name, OUTR1.char_field_name ) not IN ( SELECT __distinct(50) INNR1 . char_field_name AS x , INNR1 . char_field_name AS y select_inner_body ) |
  ( _digit, _digit ) not IN ( SELECT __distinct(50) INNR1 . int_field_name AS x , INNR1 . int_field_name AS y select_inner_body ) |
  ( _char, _char ) not IN ( SELECT __distinct(50) INNR1 . char_field_name AS x , INNR1 . char_field_name AS y select_inner_body ) |
  OUTR1.int_field_name membership_operator int_single_union_subquery |
  OUTR1.char_field_name membership_operator char_single_union_subquery ;

select_inner_body:
  FROM inner_from
  WHERE inner_condition_top
  inner_order_by ;

select_inner_body_without_alias:
  FROM inner_from
  WHERE inner_condition_top1
  inner_order_by ;

inner_from:
  i_tab AS INNR1 |
  i_tab AS INNR2 join i_tab AS INNR1 ON ( inner_join_condition );

inner_order_by:
  | ORDER BY INNR1 . field_name ;

inner_join_condition:
  INNR2 . int_field_name arithmetic_operator INNR1 . int_field_name |
  INNR2 . char_field_name arithmetic_operator INNR1 . char_field_name |
  INNR2 . date_field_name arithmetic_operator INNR1 . date_field_name ;

inner_condition_top:
  INNR1 . expression |
  OUTR1 . expression |
  inner_condition_bottom logical_operator inner_condition_bottom |
  inner_condition_bottom logical_operator outer_condition_bottom ;

inner_condition_top1:
  INNR1 . expression |
  inner_condition_bottom logical_operator inner_condition_bottom ;

expression:
  field_name null_operator |
  int_field_name int_expression |
  date_field_name date_expression |
  char_field_name char_expression ;

int_expression:
  arithmetic_operator _digit ;

date_expression:
  arithmetic_operator date | BETWEEN date AND date ;

char_expression:
  arithmetic_operator _varchar(1) ;

inner_condition_bottom:
  INNR1 . expression |
  INNR1 . int_field_name arithmetic_operator INNR1 . int_field_name |
  INNR1 . date_field_name arithmetic_operator INNR1 . date_field_name |
  INNR1 . char_field_name arithmetic_operator INNR1 . char_field_name ;

outer_condition_bottom:
  OUTR2 . expression ;

null_operator:
  IS NULL | IS NOT NULL ;

logical_operator:
  AND | OR | OR NOT | XOR | AND NOT ;

field_name:
  int_field_name | char_field_name | date_field_name;

int_field_name:
  `pk` | `col_int_key` | `col_int_nokey` ;

date_field_name:
  `col_date_key` | `col_date_nokey` | `col_datetime_key` | `col_datetime_nokey` ;

char_field_name:
  `col_varchar_key` | `col_varchar_nokey` ;

set_field_name:
  `col_int_nokey` | `col_int_key` | `col_varchar_nokey` | `col_varchar_key` ;

o_tab:
  A | B | C | D | E ;

i_tab:
  AA | BB | CC | DD ;

value2:
  _data | _data | _varchar(256) | _varchar(1024) | _char(256) | _char(1024) | _english | _english | NULL | NULL | 0 | 1 | -1 ;
