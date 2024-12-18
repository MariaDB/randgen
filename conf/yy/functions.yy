# Copyright (c) 2021, 2022, MariaDB Corporation Ab.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# 51 Franklin Street, Suite 500, Boston, MA 02110-1335 USA

#include <conf/yy/include/basics.inc>

query_init:
  { $tmp_table = 0; _set_db('test') } CREATE FUNCTION IF NOT EXISTS MIN2(a BIGINT, b BIGINT) RETURNS BIGINT RETURN (a>b,b,a) ;

query:
    ==FACTOR:10==   { _set_db('ANY') }        func_select
  |                 { _set_db('ANY') }        { $tmp_table++; '' } func_create_and_drop
  |                 { _set_db('ANY') }        func_view
  |                 { _set_db('NON-SYSTEM') } func_alter_table
  | ==FACTOR:2==    { _set_db('NON-SYSTEM') } func_dml
  | ==FACTOR:2==    { _set_db('NON-SYSTEM') } func_dml_function
  | ==FACTOR:0.01== { _set_db('ANY') }        func_set_binlog_variables
;

func_set_binlog_variables:
     SELECT VARIABLE_VALUE INTO @func_binlog_file FROM INFORMATION_SCHEMA.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Binlog_snapshot_file'
  ;; SELECT VARIABLE_VALUE INTO @func_binlog_pos FROM INFORMATION_SCHEMA.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Binlog_snapshot_position'
;

func_alter_table:
  ALTER TABLE _basetable DROP CONSTRAINT IF EXISTS `func_check` ;; ALTER TABLE _basetable ADD CONSTRAINT IF NOT EXISTS `func_check` CHECK(func_func) |
  ALTER TABLE _basetable func_add_or_modify_col `func_col_str` VARCHAR(1024) DEFAULT (func_func) func_opt_col_check |
  ALTER TABLE _basetable func_add_or_modify_col `func_col_int` BIGINT DEFAULT (func_func) func_opt_col_check |
  ALTER TABLE _basetable func_add_or_modify_col `func_vcol_str` VARCHAR(1024) GENERATED ALWAYS AS (func_func) func_opt_col_check |
  ALTER TABLE _basetable func_add_or_modify_col `func_vcol_str` BIGINT GENERATED ALWAYS AS (func_func) func_opt_col_check |
  ALTER TABLE _basetable func_add_or_modify_col `func_vcol_str` VARCHAR(1024) AS (func_func) STORED func_opt_col_check |
  ALTER TABLE _basetable func_add_or_modify_col `func_vcol_str` BIGINT AS (func_func) STORED func_opt_col_check
;

func_add_or_modify_col:
  ADD COLUMN IF NOT EXISTS |
  ==FACTOR:20== MODIFY COLUMN IF EXISTS ;

func_opt_col_check:
  ==FACTOR:5== |
  CHECK(func_func) ;

func_create_and_drop:
     CREATE __temporary(50) TABLE { 'test.tmp'.$tmp_table } AS func_select ;; DROP TABLE IF EXISTS { 'test.tmp'.$tmp_table } ;

func_view:
  CREATE OR REPLACE VIEW { 'test.v'.$tmp_table } AS func_select ;; SELECT * FROM { 'test.v'.$tmp_table } func_where ;; DROP VIEW IF EXISTS { 'test.v'.$tmp_table } ;

func_dml:
   func_dml_one_field | func_dml_two_fields | func_dml_three_fields
;

func_dml_one_field:
     CREATE OR REPLACE __temporary(50) TABLE { 'test.tmp'.$tmp_table } SELECT _field AS f1 FROM _table LIMIT _digit
   ;; INSERT IGNORE INTO { 'test.tmp'.$tmp_table } VALUES ( func_arg )
;

func_dml_two_fields:
     CREATE OR REPLACE __temporary(50) TABLE { 'test.tmp'.$tmp_table } SELECT _field AS f1, _field AS f2 FROM _table LIMIT _digit
   ;; INSERT IGNORE INTO { 'test.tmp'.$tmp_table } VALUES (func_arg, func_arg)
;

func_dml_three_fields:
     CREATE OR REPLACE __temporary(50) TABLE { 'test.tmp'.$tmp_table } SELECT _field AS f1, _field AS f2, _field AS f3 FROM _table LIMIT _digit
   ;; INSERT IGNORE INTO { 'test.tmp'.$tmp_table } VALUES (func_arg, func_arg, func_arbitrary_args(f1,f2))
;

func_dml_function:
     CREATE OR REPLACE __temporary(50) TABLE { 'test.tmp'.$tmp_table } SELECT _field AS f1, _field AS f2, _field AS f3 FROM _table LIMIT _digit
   ;; CREATE OR REPLACE FUNCTION { 'test.dml_function_'.abs($$) } () RETURNS INT
      BEGIN
        INSERT IGNORE INTO { 'test.tmp'.$tmp_table } VALUES (func_arg, func_arg, func_arbitrary_args(f1,f2))
      ; UPDATE IGNORE { 'test.tmp'.$tmp_table }  SET f1 = func_func, f2 = func_func, f3 = func_func
      ; RETURN _digit
      ; END
   ;; SELECT { 'test.dml_function_'.abs($$) } ();
;

func_select:
   optional_explain_analyze func_select;

optional_explain_analyze:
   ==FACTOR:10== |
   _basics_explain_analyze
;

func_select_list:
   ==FACTOR:5== func_select_item AS { $num++; 'field'.$num }
   | func_select_item AS { $num++; 'field'.$num } , func_select_list ;

func_select_item:
   ==FACTOR:3== func_func
   | func_aggregate_func
;

func_select:
  { $num = 0; '' } /* _table[invariant] */ SELECT __distinct(50) func_select_list FROM _table[invariant] func_where opt_group_by_having_order_by_limit ;

func_aggregate_func:
   COUNT( func_func )
   | AVG( func_func )
   | SUM( func_func )
   | MAX( func_func )
   | MIN( func_func )
   | GROUP_CONCAT( func_func, func_func )
   | BIT_AND( func_arg )
   | BIT_COUNT( func_arg )
   | BIT_LENGTH( func_arg )
   | BIT_OR( func_arg )
   | BIT_XOR( func_arg )
   | STD( func_arg )
   | STDDEV( func_arg )
   | STDDEV_POP( func_arg )
   | STDDEV_SAMP( func_arg )
   | VAR_POP( func_arg )
   | VAR_SAMP( func_arg )
   | VARIANCE( func_arg )
;

func_where:
   | WHERE ( func_func ) field_condition ;

opt_group_by_having_order_by_limit:
   ==FACTOR:5== |
                func_group_by_with_rollup func_having _basics_limit_50pct |
   ==FACTOR:2== func_group_by func_having func_order_by _basics_limit_50pct
;

func_group_by_with_rollup:
   | GROUP BY func_func WITH ROLLUP | GROUP BY func_func, func_func WITH ROLLUP ;

func_group_by:
   | GROUP BY func_func | GROUP BY func_func, func_func ;

func_having:
   | HAVING { 'field' . $prng->int(1,$num) } field_condition ;

field_condition:
   _basics_comparison_operator _basics_any_value |
   _basics_comparison_operator ( func_func ) |
   IS __not(50) NULL
;

func_order_by:
   | ORDER BY func_func | ORDER BY func_func, func_func ;

func_func:
   func_math_func |
   func_arithm_oper |
   func_comparison_oper |
   func_logical_or_bitwise_oper |
   func_assign_oper |
   func_cast_oper |
   func_control_flow_func |
   ==FACTOR:3== func_str_func |
   ==FACTOR:2== func_date_func |
   func_encrypt_func |
   func_information_func |
   # MDEV-35090 and generally problematic and nobody is fixing it
   ==FACTOR:0.01== func_xml_func |
   func_misc_func
;

func_misc_func:
   BINLOG_GTID_POS(@func_binlog_file,@func_binlog_pos) |
   DEFAULT( _field ) |
   GET_LOCK( func_arg_char , func_zero_or_almost ) |
# TODO: provide reasonable IP
   INET_ATON( func_arg ) |
   INET_NTOA( func_arg ) |
   IS_FREE_LOCK( func_arg_char ) |
   IS_USED_LOCK( func_arg_char ) |
   MASTER_POS_WAIT(@func_binlog_file, @func_binlog_pos, func_zero_or_almost ) |
   NAME_CONST( func_const_char_value, func_value ) |
   RAND(_int_unsigned) | RAND( func_arg ) |
   RELEASE_LOCK( func_arg_char ) |
   SLEEP( func_zero_or_almost ) |
   SYS_GUID() /* compatibility 10.6.1 */ |
   UUID_SHORT() |
   UUID() |
# Changed due to MDEV-12172
   /*!!100303 VALUES( _field ) */ /*!100303 VALUE( _field ) */
;

func_zero_or_almost:
   0 | 0.01 ;

# TODO: provide reasonable arguments to XML

func_xml_func:
   ExtractValue( func_value, func_xpath ) |
   UpdateXML( func_value, func_xpath, func_value )
;

func_xpath:
   { @chars = ('a','b','c','d','e','/'); $length= int(rand(127)); $x= '/'; $xpath= '/'; foreach ( 1..$length ) { $x= ( ( $x eq '/' or $_ eq $length ) ? $chars[int(rand(scalar(@chars)-1))] : $chars[int(rand(scalar(@chars)))]); $xpath.= $x ; }; "'".$xpath."'" } ;

func_information_func:
   CHARSET( func_arg ) |
   BENCHMARK( _digit, func_select_item ) |
   COERCIBILITY( func_arg ) |
   COLLATION( func_arg ) |
   CONNECTION_ID() |
   CURRENT_USER() | CURRENT_USER |
   DATABASE() | SCHEMA() |
   FOUND_ROWS() |
   LAST_INSERT_ID() |
   ROW_COUNT() |
   SESSION_USER() | SYSTEM_USER() | USER() |
   VERSION()
;

func_control_flow_func:
   CASE func_arg WHEN func_arg THEN func_arg END | CASE func_arg WHEN func_arg THEN func_arg WHEN func_arg THEN func_arg END | CASE func_arg WHEN func_arg THEN func_arg ELSE func_arg END |
   IF( func_arg, func_arg, func_arg ) |
   IFNULL( func_arg, func_arg )
   # TODO: Re-enable when MDEV-19091 is fixed
   # NULLIF( func_arg, func_arg )
;

func_cast_oper:
   BINARY func_arg | CAST( func_arg AS func_type ) | CONVERT( func_arg, func_type ) | CONVERT( func_arg USING func_charset ) ;

func_charset:
   utf8 | latin1 | utf8mb4 ;

func_type:
   BINARY | BINARY(_digit) | CHAR | CHAR(_digit) | DATE | DATETIME | DECIMAL | DECIMAL(func_decimal_m) | DECIMAL(func_decimal_m,func_decimal_d) | SIGNED | TIME | UNSIGNED ;

func_decimal_m:
    { $decimal_m = $prng->int(0,65) }
;

func_decimal_d:
    { $decimal_d = $prng->int(0,$decimal_m) }
;

func_encrypt_func:
   AES_DECRYPT( func_arg, func_arg ) |
   AES_ENCRYPT( func_arg, func_arg ) |
   COMPRESS( func_arg ) |
   DECODE( func_arg, func_arg ) |
# Deprecated in 10.10.1 (MDEV-27104)
#   DES_DECRYPT( func_arg ) | DES_DECRYPT( func_arg, func_arg ) |
#   DES_ENCRYPT( func_arg ) | DES_ENCRYPT( func_arg, func_arg ) |
   ENCODE( func_arg, func_arg ) |
# TODO: Restore when MDEV-27514 is fixed
#  ENCRYPT( func_arg ) | ENCRYPT( func_arg, func_arg ) |
   MD5( func_arg ) |
   OLD_PASSWORD( func_arg ) |
   PASSWORD( func_arg ) |
   RANDOM_BYTES( func_arg ) /* compatibility 10.10.1 */ |
   SHA1( func_arg ) |
   SHA( func_arg ) |
   SHA2( func_arg, func_arg ) |
   UNCOMPRESS( func_arg ) |
   UNCOMPRESSED_LENGTH( func_arg )
;

func_str_func:
   ASCII( func_arg ) |
   BIN( func_arg ) |
   BIT_LENGTH( func_arg ) |
   CHAR_LENGTH( func_arg ) | CHARACTER_LENGTH( func_arg ) |
   CHAR( func_arg ) | CHAR( func_arg USING func_charset ) |
   CONCAT_WS( func_arg_list ) |
   CONCAT( func_arg ) | CONCAT( func_arg_list ) |
   ELT( func_arg_list ) |
   EXPORT_SET( func_arg, func_arg, func_arg ) | EXPORT_SET( func_arg, func_arg, func_arg, func_arg ) | EXPORT_SET( func_arg, func_arg, func_arg, func_arg, func_arg ) |
   FIELD( func_arg_list ) |
   FIND_IN_SET( func_arg, func_arg ) |
   FORMAT( func_arg, func_arg ) | FORMAT( func_arg, func_arg, func_locale ) |
   HEX( func_arg ) |
   INSERT( func_arg, func_arg, func_arg, func_arg ) |
   INSTR( func_arg, func_arg ) |
   LCASE( func_arg ) |
   LEFT( func_arg, func_arg ) |
   LENGTH( func_arg ) |
   func_arg __not(30) LIKE func_arg |
   LOAD_FILE( func_arg ) |
   LOCATE( func_arg, func_arg ) | LOCATE( func_arg, func_arg, func_arg ) |
   LOWER( func_arg ) |
   LPAD( func_arg, test.MIN2( func_arg, 65536 ), func_arg ) |
   LTRIM( func_arg ) |
   MAKE_SET( func_arg_list ) |
   MATCH( func_field_list ) AGAINST ( func_const_char_value func_search_modifier ) |
   MID( func_arg, func_arg, func_arg ) |
   NATURAL_SORT_KEY( func_arg ) /* compatibility 10.7.1 */ |
   OCT( func_arg ) |
   OCTET_LENGTH( func_arg ) |
   ORD( func_arg ) |
   POSITION( func_arg IN func_arg ) |
   QUOTE( func_arg ) |
# TODO: provide reasonable patterns to REGEXP
   func_arg __not(30) REGEXP func_arg | func_arg __not(30) RLIKE func_arg |
   REPEAT( func_arg, test.MIN2( func_arg, 65536 ) ) |
   REPLACE( func_arg, func_arg, func_arg ) |
   REVERSE( func_arg ) |
   RIGHT( func_arg, func_arg ) |
   RPAD( func_arg, test.MIN2( func_arg, 65536 ), func_arg ) |
   RTRIM( func_arg ) |
# Disabled due to MDEV-31024 - crash
#  SFORMAT( sformat_template, func_arg ) |
   SOUNDEX( func_arg ) |
   func_arg SOUNDS LIKE func_arg |
   SPACE( test.MIN2( func_arg, 65536 ) ) |
   SUBSTR( func_arg, func_arg ) | SUBSTR( func_arg FROM func_arg ) | SUBSTR( func_arg, func_arg, func_arg ) | SUBSTR( func_arg FROM func_arg FOR func_arg ) |
   SUBSTRING_INDEX( func_arg, func_arg, func_arg ) |
   TRIM( func_arg ) | TRIM( func_trim_mode FROM func_arg ) | TRIM( func_trim_mode func_arg FROM func_arg ) | TRIM( func_arg FROM func_arg ) |
   TO_CHAR( func_arg func_optional_to_char_fmt ) /* compatibility 10.6.1 */ |
   UCASE( func_arg ) |
   UNHEX( func_arg ) |
   UPPER( func_arg ) |
   VEC_TOTEXT( func_arg_vector ) /* compatibility 11.7.1 */ |
   VEC_FROMTEXT( func_arg_vector ) /* compatibility 11.7.1 */ |
   VEC_DISTANCE_EUCLIDEAN( func_arg_vector, func_arg_vector ) /* compatibility 11.7.1 */ |
   VEC_DISTANCE_COSINE( func_arg_vector, func_arg_vector ) /* compatibility 11.7.1 */ |
   VEC_DISTANCE( func_arg_vector, func_arg_vector ) /* compatibility 11.8.0 */
;

func_arg_vector:
   func_arg |
   { $dimensions= $prng->uint16(1,100); $min_value= $prng->uint16(-10,10); $max_value= $prng->uint16($min_value,$min_value+100); @vals= (); for (my $j=0; $j<$dimensions; $j++) { push @vals, sprintf("%.3f",$min_value + rand()*($max_value - $min_value)) }; "'[".(join ',', @vals)."]'" } |
   vector_hex_string
;

vector_hex_string:
   _vector(1) | _vector(2) | _vector(3) | _vector(8) | _vector(96) ;

sformat_template:
  CONCAT(_string, sformat_replacement_field, _string);

# TODO: extend!!!
# https://fmt.dev/latest/syntax.html
sformat_replacement_field:
  '{}' ;

func_optional_to_char_fmt:
  | , func_to_char_fmt ;

func_to_char_fmt:
  { @fmt_elements=qw(YYYY YYY YY RRRR RR MM MON MONTH MI DD DY HH HH12 HH24 SS)
    ; $n= $prng->uint16(0,20)
    ; @special= (':','.','-','/',',',';',' ')
    ; $str= ''
    ; foreach (1..$n) { $str.= $prng->arrayElement(\@fmt_elements).$prng->arrayElement(\@special) }
    ; "'".$str."'"
  };

func_trim_mode:
   BOTH | LEADING | TRAILING ;

func_search_modifier:
   |
   IN NATURAL LANGUAGE MODE |
   IN NATURAL LANGUAGE MODE WITH QUERY EXPANSION |
   IN BOOLEAN MODE |
   WITH QUERY EXPANSION
;

func_date_func:
   ADD_MONTHS( func_arg, _smallint ) /* compatibility 10.6.1 */ |
   ADDDATE( func_arg, INTERVAL func_arg func_unit1 ) | ADDDATE( func_arg, func_arg ) |
   ADDTIME( func_arg, func_arg ) |
   CONVERT_TZ( func_arg, func_arg, func_arg ) |
   CURDATE() | CURRENT_DATE() | CURRENT_DATE |
   CURTIME() | CURRENT_TIME() | CURRENT_TIME |
   CURRENT_TIMESTAMP() | CURRENT_TIMESTAMP |
   DATE( func_arg ) |
   DATEDIFF( func_arg, func_arg ) |
   DATE_ADD( func_arg, INTERVAL func_arg func_unit1 ) | DATE_SUB( func_arg, INTERVAL func_arg func_unit1 ) |
   DATE_FORMAT( func_arg, func_arg ) |
   DAY( func_arg ) | DAYOFMONTH( func_arg ) |
   DAYNAME( func_arg ) |
   DAYOFWEEK( func_arg ) |
   DAYOFYEAR( func_arg ) |
   EXTRACT( func_unit1 FROM func_arg ) |
   FROM_DAYS( func_arg ) |
   FROM_UNIXTIME( func_arg ) | FROM_UNIXTIME( func_arg, func_arg ) |
   GET_FORMAT( func_get_format_type, func_get_format_format ) |
   HOUR( func_arg ) |
   LAST_DAY( func_arg ) |
   LOCALTIME() |
   LOCALTIMESTAMP() |
   MAKEDATE( func_arg, func_arg ) |
   MAKETIME( func_arg, func_arg, func_arg ) |
   MICROSECOND( func_arg ) |
   MINUTE( func_arg ) |
   MONTH( func_arg ) |
   MONTHNAME( func_arg ) |
   NOW() |
   PERIOD_ADD( func_arg, func_arg ) |
   PERIOD_DIFF( func_arg, func_arg ) |
   QUARTER( func_arg ) |
   SECOND( func_arg ) |
   SEC_TO_TIME( func_arg ) |
   STR_TO_DATE( func_arg, func_arg ) |
   SUBDATE( func_arg, func_arg ) |
   SUBTIME( func_arg, func_arg ) |
   SYSDATE() |
   # For ORACLE mode
   SYSDATE /* compatibility 10.6.1 */ |
   TIME( func_arg ) |
   TIMEDIFF( func_arg, func_arg ) |
   TIMESTAMP( func_arg ) | TIMESTAMP( func_arg, func_arg ) |
   TIMESTAMPADD( func_unit2, func_arg, func_arg ) |
   TIMESTAMPDIFF( func_unit2, func_arg, func_arg ) |
   TIME_FORMAT( func_arg, func_arg ) |
   TIME_TO_SEC( func_arg ) |
   TO_DAYS( func_arg ) |
   TO_SECONDS( func_arg ) |
   UNIX_TIMESTAMP( func_arg ) | UNIX_TIMESTAMP() |
   UTC_DATE() |
   UTC_TIME() |
   UTC_TIMESTAMP() |
   WEEK( func_arg ) | WEEK( func_arg, func_week_mode ) |
   WEEKDAY( func_arg ) |
   WEEKOFYEAR( func_arg ) |
   YEAR( func_arg ) |
   YEARWEEK( func_arg ) | YEARWEEK( func_arg, func_week_mode )
;

func_week_mode:
   0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | func_arg ;

func_get_format_type:
   DATE | TIME | DATETIME ;

func_get_format_format:
   'EUR' | 'USA' | 'JIS' | 'ISO' | 'INTERNAL' | func_arg ;

func_unit1:
   MICROSECOND |
   SECOND |
   MINUTE |
   HOUR |
   DAY |
   WEEK |
   MONTH |
   QUARTER |
   YEAR |
   SECOND_MICROSECOND |
   MINUTE_MICROSECOND |
   MINUTE_SECOND |
   HOUR_MICROSECOND |
   HOUR_SECOND |
   HOUR_MINUTE |
   DAY_MICROSECOND |
   DAY_SECOND |
   DAY_MINUTE |
   DAY_HOUR |
   YEAR_MONTH
;

func_unit2:
   MICROSECOND |
   SECOND |
   MINUTE |
   HOUR |
   DAY |
   WEEK |
   MONTH |
   QUARTER |
   YEAR
;

func_math_func:
   ABS( func_arg ) | ACOS( func_arg ) | ASIN( func_arg ) | ATAN( func_arg ) | ATAN( func_arg, func_arg ) | ATAN2( func_arg, func_arg ) |
   CEIL( func_arg ) | CEILING( func_arg ) | CONV( func_arg, _tinyint_unsigned, _tinyint_unsigned ) | COS( func_arg ) | COT( func_arg ) |
   CRC32( func_arg ) | /* compatibility 10.8.0 */ CRC32( func_arg, func_arg ) | /* compatibility 10.8.0 */ CRC32C( func_arg ) | /* compatibility 10.8.0 */ CRC32C( func_arg, func_arg ) |
   DEGREES( func_arg ) |
   EXP( func_arg ) |
   FLOOR( func_arg ) |
   FORMAT( func_arg, _digit ) | FORMAT( func_arg, func_format_second_arg, func_locale ) |
   HEX( func_arg ) |
   LN( func_arg ) | LOG( func_arg ) | LOG( func_arg, func_arg ) | LOG2( func_arg ) | LOG10( func_arg ) |
   MOD( func_arg, func_arg ) |
   PI( ) | POW( func_arg, func_arg ) | POWER( func_arg, func_arg ) |
   RADIANS( func_arg ) | RAND(_int_unsigned) | RAND( func_arg ) | ROUND( func_arg ) | ROUND( func_arg, func_arg ) |
   SIGN( func_arg ) | SIN( func_arg ) | SQRT( func_arg ) |
   TAN( func_arg ) | TRUNCATE( func_arg, func_truncate_second_arg ) ;

func_arithm_oper:
   func_arg + func_arg |
   func_arg - func_arg |
   - func_arg |
   func_arg * func_arg |
   func_arg / func_arg |
   func_arg DIV func_arg |
   func_arg MOD func_arg |
   func_arg % func_arg
;

func_logical_or_bitwise_oper:
   NOT ( func_arg ) | ! ( func_arg ) | ~ ( func_arg ) |
   func_arg AND func_arg | func_arg && func_arg | func_arg & func_arg |
   func_arg OR func_arg | func_arg | func_arg |
   func_arg XOR func_arg | func_arg ^ func_arg |
   func_arg << func_arg | func_arg >> func_arg
;

func_assign_oper:
   @A := func_arg ;

func_comparison_oper:
   func_arg = func_arg |
   func_arg <=> func_arg |
   func_arg != func_arg |
   func_arg <> func_arg |
   func_arg <= func_arg |
   func_arg < func_arg |
   func_arg >= func_arg |
   func_arg > func_arg |
   func_arg IS __not(30) func_bool_value |
   func_arg __not(30) BETWEEN func_arg AND func_arg |
   COALESCE( func_arg_list ) |
   GREATEST( func_arg_list ) |
   func_arg __not(30) IN ( func_arg_list ) |
   ISNULL( func_arg ) |
   INTERVAL( func_arg_list ) |
   LEAST( func_arg_list ) |
   func_arg __not(30) LIKE func_arg |
   STRCMP( func_arg, func_arg )
;

func_arbitrary_args:
   COALESCE |
   GREATEST |
   INTERVAL |
   LEAST |
   CONCAT_WS |
   CONCAT |
   ELT |
   FIELD |
   MAKE_SET
;


func_arg_list:
   func_arg_list_2 | func_arg_list_3 | func_arg_list_5 | func_arg_list_10 | func_arg, func_arg_list ;

func_arg_list_2:
   func_arg, func_arg ;

func_arg_list_3:
   func_arg, func_arg, func_arg ;

func_arg_list_5:
   func_arg, func_arg, func_arg, func_arg, func_arg ;

func_arg_list_10:
   func_arg, func_arg, func_arg, func_arg, func_arg, func_arg, func_arg, func_arg, func_arg, func_arg ;


func_field_list:
   _field | func_field_list , _field ;

func_format_second_arg:
   func_truncate_second_arg ;

func_truncate_second_arg:
   _digit | _digit | _tinyint_unsigned | func_arg ;

func_arg:
   _field | func_value | ( func_func ) ;

func_arg_char:
  CAST(_field AS CHAR) | _char(1) | _english | _string(16) | NULL
;

func_const_char_value:
  _char(1) | _english | _string(16) | ''
;

func_value:
   _bigint | _smallint | _int_unsigned | _char(1) | _char(256) | _datetime | _date | _time | NULL | _anyvalue ;

func_bool_value:
   TRUE | FALSE | UNKNOWN | NULL ;

func_locale:
   'en_US' | 'de_DE' ;

