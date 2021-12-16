thread1_init_add:
  SET GLOBAL SQL_MODE= CONCAT(@@sql_mode,hist_extra_sql_mode_values); 

query_add:
  { $fields = 0 ; "" } ANALYZE FORMAT=JSON SELECT hist_select_list FROM _table WHERE hist_where_list hist_opt_where_list hist_group_by_clause hist_order_by_clause;
  
hist_select_list:
  hist_select_item | hist_select_item , hist_select_list ;

hist_select_item:
  _field AS { my $f = "field".++$fields ; $f } ; 

hist_where_list:
    hist_where_clause | hist_where_clause |
    hist_where_list hist_and_or hist_where_clause ;

hist_where_clause:
   hist_where_list hist_or_and hist_where_item |
   ( hist_where_list hist_or_and hist_where_item ) |
   hist_where_item | hist_where_item | hist_where_item | hist_where_item ;

hist_where_item:
   hist_int_value_or_field hist_comparison_operator hist_int_value_or_field |
   hist_int_value_or_field hist_not IN (hist_number_list) |
   hist_int_value_or_field hist_not BETWEEN hist_int_value_or_field AND hist_int_value_or_field |
   hist_char_value_or_field hist_comparison_operator hist_char_value_or_field |
   hist_char_value_or_field hist_not IN (hist_char_list) |
   hist_char_value_or_field hist_not LIKE ( hist_char_pattern ) |
   hist_char_value_or_field hist_not BETWEEN hist_char_value_or_field AND hist_char_value_or_field |
   _field IS hist_not hist_is_value |
   hist_any_value_or_field hist_comparison_operator hist_any_value_or_field |
   hist_any_value_or_field hist_not IN (hist_number_list) |
   hist_any_value_or_field hist_not BETWEEN hist_any_value_or_field AND hist_any_value_or_field
;


hist_opt_where_list:
  | | | | hist_and_or hist_where_list ;

hist_group_by_clause:
  | | | | | GROUP BY { @groupby = (); for (1..$fields) { push @groupby, 'field'.$_ }; join ',', @groupby } ;

hist_order_by_clause:
  | | |
  ORDER BY hist_total_order_by hist_desc hist_limit |
  ORDER BY hist_order_by_list  ;

hist_total_order_by:
  { join(', ', map { "field".$_ } (1..$fields) ) };

hist_order_by_list:
  hist_order_by_item  |
  hist_order_by_item  , hist_order_by_list ;

hist_order_by_item:
  hist_existing_select_item hist_desc ;

hist_existing_select_item:
  { "field".$prng->uint16(1,$fields) };

hist_limit:
  | | LIMIT hist_limit_size | LIMIT hist_limit_size OFFSET hist_int_value;

hist_extra_sql_mode_values:
  {   @modes= ('REAL_AS_FLOAT','ANSI_QUOTES','ORACLE','ANSI','NO_BACKSLASH_ESCAPES','NO_ZERO_IN_DATE','NO_ZERO_DATE','ALLOW_INVALID_DATES','PAD_CHAR_TO_FULL_LENGTH')
      ; $length=$prng->int(0,scalar(@modes))
      ; "'" . (join ',', @{$prng->shuffleArray(\@modes)}[0..$length-1]) . "'"
  }
;

hist_or_and:
  OR | OR | XOR | AND ;

hist_comparison_operator:
  = | > | < | != | <> | <= | >= | <=> ;

hist_is_value:
  ==FACTOR:5== NULL
  | TRUE | FALSE | UNKNOWN ;

hist_not:
    | | NOT ;

hist_int_value_or_field:
  hist_int_value | _field_int ;

hist_int_value:
   _digit | _digit | _tinyint_unsigned | 20 | 25 | 30 | 35 | 50 | 65 | 75 | 100 ;

hist_char_value_or_field:
  hist_char_value | _field_char ;

hist_char_value:
  _char | _char(8) | _char(16) | _quid | _english ; 

hist_char_list: 
   hist_char_value_or_field | hist_char_list, hist_char_value_or_field ;

hist_char_pattern:
 hist_char_value | hist_char_value | CONCAT( _char, '%') | 'a%'| _quid | '_' | '_%' ;

hist_desc:
 ASC | | | | DESC ; 

hist_and_or:
   AND | AND | AND | AND | OR | XOR ;

hist_limit_size:
    1 | 2 | 10 | 100 | 1000;

hist_number_list:
   hist_int_value_or_field | hist_number_list, hist_int_value_or_field ;

hist_any_value:
  hist_char_value | hist_int_value | _basics_any_value ;

hist_any_value_or_field:
  hist_any_value | _field ;

hist_any_list:
 hist_any_value_or_field | hist_any_list, hist_any_value_or_field ;

