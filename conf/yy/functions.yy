# Copyright (c) 2021, 2026, MariaDB Corporation Ab.
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
    ==FACTOR:10==   { _set_db('ANY') }        func_select_explain_analyze
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
  CREATE OR REPLACE optional_view_alg VIEW { 'test.v'.$tmp_table } AS /* _table[invariant] */  view_contents ;; SELECT * FROM { 'test.v'.$tmp_table } func_where ;; DROP VIEW IF EXISTS { 'test.v'.$tmp_table } ;

view_contents:
   func_select | SELECT * FROM _table[invariant] | SELECT _field FROM _table[invariant] ;

optional_view_alg:
   | ALGORITHM=MERGE | ==FACTOR:50== ALGORITHM=TEMPTABLE | ALGORITHM=UNDEFINED ;

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

func_select_explain_analyze:
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
   func_xml_func |
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
# MDEV-36718: Running UNCOMPRESS on a non-compressed argument on debug server
# with high max_allowed_packed causes huge performance impact
   UNCOMPRESS( COMPRESS(func_arg) ) |
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
   TO_CHAR( func_arg, to_date_format_str ) /* compatibility 12.3.1 */ |
   UCASE( func_arg ) |
   UNHEX( func_arg ) |
   UPPER( func_arg ) |
   VEC_TOTEXT( func_arg_vector ) /* compatibility 11.7.1 */ |
   VEC_FROMTEXT( func_arg_vector ) /* compatibility 11.7.1 */ |
   VEC_DISTANCE_EUCLIDEAN( func_arg_vector, func_arg_vector ) /* compatibility 11.7.1 */ |
   VEC_DISTANCE_COSINE( func_arg_vector, func_arg_vector ) /* compatibility 11.7.1 */ |
   VEC_DISTANCE(veccol, func_arg_vector) /* compatibility 11.8.0 */
;

func_arg_vector:
   func_arg |
   { $dimensions= $prng->uint16(1,100); $min_value= $prng->uint16(-10,10); $max_value= $prng->uint16($min_value,$min_value+100); @vals= (); for (my $j=0; $j<$dimensions; $j++) { push @vals, sprintf("%.3f",$min_value + rand()*($max_value - $min_value)) }; "'[".(join ',', @vals)."]'" } |
   vector_hex_string |
   veccol
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
   TO_DATE( to_date_args ) /* compatibility 12.3.1 */ |
   func_to_date /* compatibility 12.3.1 */ |
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

to_date_args:
  to_date_arg2 |
  to_date_arg2, to_date_nls_format_str
;

to_date_arg2:
  to_date_valid_arg2 |
  to_date_date_str, to_date_format_str
;

# TODO: extend significantly. Note: not all of them are really valid,
# it's an attempt to match the string and the format
to_date_valid_arg2:
  _date, 'YYYY-MM-DD' |
  ==FACTOR:0.1== CONCAT(_date,to_date_string_separators[invariant],'BC'), CONCAT('YYYY-MM-DD',to_date_string_separators[invariant],'BC') |
  _datetime, 'YYYY-MM-DD HH24:MI:SS' |
  _datetime, 'YYYY-MM-DD HH24:MI:SS.FF6' |
  { "'".$prng->uint16(1,12).':'.$prng->uint16(0,59).':'.$prng->uint16(0,59).' '.$prng->arrayElement(['AM','A.M.','PM','P.M'])."'" }, CONCAT('HH:MI:SS ', to_date_am_pm) |
  CONCAT(_datetime,to_date_string_separators,to_date_am_pm), CONCAT('YYYY-MM-DD HH:MI:SS.FF',to_date_string_separators,to_date_am_pm) |
  CONCAT(_date,to_date_string_separators,_time), CONCAT('YYYY-MM-DD',to_date_string_separators,'HH24:MI:SS.FF6') |
  CONCAT(_date,to_date_string_separators[invariant],_time), CONCAT('YYYY-MM-DD',to_date_string_separators[invariant],'HH24:MI:SS.FF6')
;

to_date_am_pm:
  'AM' | 'A.M.' | 'PM' | 'P.M' ;

to_date_date_str:
  ==FACTOR:0.01== NULL |
  ==FACTOR:0.01== "" |
  ==FACTOR:0.05== _field |
  to_date_string_expr to_date_optional_default ;

to_date_string_expr:
  to_date_string_part |
  CONCAT(to_date_string_parts)
;

to_date_string_part:
  ==FACTOR:3== to_date_string_element |
  to_date_string_separators |
  ==FACTOR:0.005== func_arg
;

to_date_string_parts:
  to_date_string_part, to_date_string_part |
  ==FACTOR:2== to_date_string_part, to_date_string_parts
;

to_date_string_element:
  'AD' |
  'A.D.' |
  'AM' |
  'A.M.' |
  day_name | # DAY
  { "'".$prng->uint16(0,32)."'" } | # DD
  { "'".$prng->uint16(0,366)."'" } | # DDD
  day_name_abbr | # DY
  { "'".$prng->uint16(0,100000)."'" } | # FF
  { "'".$prng->uint16(0,13)."'" } | # HH, HH12, MM
  { "'".$prng->uint16(0,25)."'" } | # HH24
  { "'".$prng->uint16(0,61)."'" } | # MI, SS
  month_name_abbr | # MON
  month_name | # MONTH
  'PM' |
  'P.M.' |
  { "'".$prng->uint16(0,100)."'" } | # RR
  { "'".$prng->uint16(0,10000)."'" } | # RRRR
  { "'+".$prng->uint16(0,10000)."'" } | # SYYYY
  { "'".$prng->uint16(0,9)."'" } | # Y
  { "'".$prng->uint16(0,99)."'" } | # YY
  { "'".$prng->uint16(0,999)."'" } | # YYY
  { "'".$prng->uint16(0,9999)."'" } # YYYY
;

to_date_optional_default:
  | DEFAULT to_date_string_expr ON CONVERSION ERROR ;

# TODO: Extend with other languages
day_name:
  # English
  'Monday' | 'Tuesday' | 'Wednesday' | 'Thursday' | 'Friday' | 'Saturday' | 'Sunday' |
  # Albanian
  'E HËNË' |
  # Basque
  'ASTEARTEA' |
  # Belarusian
  'АЎТОРАК' | 'СЕРАДА' |
  # Brazilian-Portuguese
  'QUINTA-FEIRA' |
  # Bulgarian
  'ЧЕТВЪРТЪК' |
  # Cyrillic Serbian
  'НЕДЕЉА' |
  # Danish
  'LØRDAG' |
  # Greek
  'ΠΑΡΑΣΚΕΥΉ' |
  # Icelandic
  'MIÐVIKUDAGUR' |
  # Japanese
  '火曜日' |
  # Korean
  '목요일' |
  # Simplified Chinese
  '星期二' |
  # Traditional Chinese
  '星期五' |
  # Turkish
  'ÇARŞAMBA' |
  # Ukranian
  'П''ЯТНИЦЯ' |
  # Error
  'UnknownDay'
;

# TODO: Extend with other languages
day_name_abbr:
  # English
  'Mon' | 'Tue' | 'Wed' | 'Thu' | 'Fri' | 'Sat' | 'Sun' |
  # Basque
  'AL.' |
  # Canadian French
  'MER.' |
  # Estonian
  'E' |
  # Hungarian
  'K.' |
  # Icelandic
  'ÞRI' |
  # Error
  'Udy'
;

# TODO: Extend with other languages
month_name:
  # English
  'January' | 'February' | 'March' | 'April' | 'May' | 'June' | 'July' | 'August' | 'September' | 'October' | 'November' | 'December' |
  # Greek
  'ΙΟΎΝΙΟΣ' |
  # Japanese
  '2月' |
  # Korean
  '1월' |
  # Macedonian
  'ЈУЛИ' |
  # Error
  'UnknownMonth' ;

# TODO: Extend with other languages
month_name_abbr:
  # English
  'Jan' | 'Feb' | 'Mar' | 'Apr' | 'May' | 'Jun' | 'Jul' | 'Aug' | 'Sep' | 'Oct' | 'Nov' | 'Dec' |
  # Basque
  'OTS.' |
  # Bulgarian
  'АПР.' |
  # Canadian French
  'FÉVR.' |
  # Japanese
  '2月' |
  # Error
  'Umo' ;

to_date_string_separator_list:
  to_date_string_separator, to_date_string_separator |
  to_date_string_separator, to_date_string_separator_list;

# chr(35) is #, it breaks grammar parsing
# ; breaks query parsing, maybe try CHAR(59)
to_date_string_separators:
  { @valid_separators = (' ', '!', '\t', chr(35), '%', '(', ')', '*', '+', ',', '-', '.', '/', ':', '<', '=', '>', '\\\'',  '"')
    ; $invalid_separator = chr(195)
    ; $length = ($prng->uint16(0,9) ? $prng->uint16(1,2) : ($prng->uint16(0,9) ? $prng->uint16(3,10) : ($prng->uint16(0,9) ? $prng->uint16(11,20) : 200)) ) ; $separators = ''; $sep=''
    ; map { $sep=$prng->arrayElement(\@valid_separators) ; $separators .= ($prng->uint16(0,9) ? $sep : ($prng->uint16(0,9) ?  $sep.$sep : $invalid_separator)) } (1..$length)
    ; "'".$separators."'"  };


to_date_format_str:
  ==FACTOR:0.01== NULL |
  ==FACTOR:0.01== "''" |
  to_date_format_expr
;

to_date_format_expr:
  to_date_format_part |
  CONCAT(to_date_format_parts) |
  # Very long line
  ==FACTOR:0.01== CONCAT(to_date_format_parts,to_date_format_parts,to_date_format_parts,to_date_format_parts,to_date_format_parts)
;

to_date_format_part:
  ==FACTOR:3== to_date_format_element |
  to_date_string_separators |
  ==FACTOR:0.05== _field |
  ==FACTOR:0.005== func_arg
;

to_date_format_parts:
  to_date_format_part, to_date_format_part |
  ==FACTOR:2== to_date_format_part, to_date_format_parts
;

to_date_format_element:
  'AD' |
  'A.D' |
  'AM' |
  'A.M' |
  'DAY' |
  'DD' |
  'DDD' |
  'DY' |
  'FF' |
  { "'".'FF'.$prng->uint16(0,7)."'" } |
  'HH' |
  'HH12' |
  'HH24' |
  'MI' |
  'MM' |
  'MON' |
  'MONTH' |
  'PM' |
  'P.M' |
  'RR' |
  'RRRR' |
  'SS' |
  'SYYYY' |
  'Y' |
  'YY' |
  'YYY' |
  'YYYY' |
  ==FACTOR:0.01== to_date_format_element_not_supported
;

# Some not supported for TO_DATE but for TO_CHAR ?
to_date_format_element_not_supported:
  'BC' |
  'B.C.' |
  'IW' |
  'I' |
  'IY' |
  'IYY' |
  'IYYY' |
  'D' |
  'DL' |
  'DS' |
  'E' |
  'EE' |
  ==FACTOR:100= 'FM' |
  'FX' |
  'RM' |
  'SSSSS' |
  'TS' |
  'TZD' |
  'TZH' |
  'TZR' |
  'X' |
  'SY'
;

# MDEV-38585
to_date_nls_format_str:
  nls_format_element |
  ==FACTOR:0.005== func_arg |
  ==FACTOR:0.005== CONCAT(nls_format_element,' ',nls_format_element)
;

nls_format_element:
  'NLS_CALENDAR=GREGORIAN' |
  ==FACTOR:0.005== 'NLS_CALENDAR=SOMEOTHER' |
  'NLS_DATE_LANGUAGE=ENGLISH' |
  'NLS_DATE_LANGUAGE=ALBANIAN' |
  'NLS_DATE_LANGUAGE=AMERICAN' |
  'NLS_DATE_LANGUAGE=ARABIC' |
  'NLS_DATE_LANGUAGE=BASQUE' |
  'NLS_DATE_LANGUAGE=BELARUSIAN' |
  'NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''' |
  'NLS_DATE_LANGUAGE=BULGARIAN' |
  'NLS_DATE_LANGUAGE=''CANADIAN FRENCH''' |
  'NLS_DATE_LANGUAGE=CATALAN' |
  'NLS_DATE_LANGUAGE=CROATIAN' |
  'NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''' |
  'NLS_DATE_LANGUAGE=CZECH' |
  'NLS_DATE_LANGUAGE=DANISH' |
  'NLS_DATE_LANGUAGE=DUTCH' |
  'NLS_DATE_LANGUAGE=ESTONIAN' |
  'NLS_DATE_LANGUAGE=FINNISH' |
  'NLS_DATE_LANGUAGE=FRENCH' |
  'NLS_DATE_LANGUAGE=GERMAN' |
  'NLS_DATE_LANGUAGE=GREEK' |
  'NLS_DATE_LANGUAGE=HEBREW' |
  'NLS_DATE_LANGUAGE=HINDI' |
  'NLS_DATE_LANGUAGE=HUNGARIAN' |
  'NLS_DATE_LANGUAGE=ICELANDIC' |
  'NLS_DATE_LANGUAGE=INDONESIAN' |
  'NLS_DATE_LANGUAGE=ITALIAN' |
  'NLS_DATE_LANGUAGE=JAPANESE' |
  'NLS_DATE_LANGUAGE=KANNADA' |
  'NLS_DATE_LANGUAGE=KOREAN' |
  'NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''' |
  'NLS_DATE_LANGUAGE=LATVIAN' |
  'NLS_DATE_LANGUAGE=LITHUANIAN' |
  'NLS_DATE_LANGUAGE=MACEDONIAN' |
  'NLS_DATE_LANGUAGE=MALAY' |
  'NLS_DATE_LANGUAGE=''MEXICAN SPANISH''' |
  'NLS_DATE_LANGUAGE=NORWEGIAN' |
  'NLS_DATE_LANGUAGE=POLISH' |
  'NLS_DATE_LANGUAGE=PORTUGUESE' |
  'NLS_DATE_LANGUAGE=ROMANIAN' |
  'NLS_DATE_LANGUAGE=RUSSIAN' |
  'NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''' |
  'NLS_DATE_LANGUAGE=SLOVAK' |
  'NLS_DATE_LANGUAGE=SLOVENIAN' |
  'NLS_DATE_LANGUAGE=SPANISH' |
  'NLS_DATE_LANGUAGE=SWAHILI' |
  'NLS_DATE_LANGUAGE=SWEDISH' |
  'NLS_DATE_LANGUAGE=TAMIL' |
  'NLS_DATE_LANGUAGE=THAI' |
  'NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''' |
  'NLS_DATE_LANGUAGE=TURKISH' |
  'NLS_DATE_LANGUAGE=UKRAINIAN' |
  ==FACTOR:0.005== 'NLS_DATE_LANGUAGE=SOMEOTHER' |
  'NLS_DATE_LANGUAGE=en_US' |
  'NLS_DATE_LANGUAGE=ru_RU' |
  ' NLS_DATE_LANGUAGE  = ENGLISH  '
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

func_to_date:
  TO_DATE('2026-05 JANAR,E HËNË', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-05 JAN,HËN', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-03 SHKURT,E MARTË', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-03 SHK,MAR', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-04 MARS,E MËRKURË', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-04 MAR,MËR', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-02 PRILL,E ENJTE', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-02 PRI,ENJ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-01 MAJ,E PREMTE', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-01 MAJ,PRE', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-06 QERSHOR,E SHTUNË', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-06 QER,SHT', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-05 KORRIK,E DIEL', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-05 KOR,DIE', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-31 GUSHT', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-31 GSH', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-30 SHTATOR', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-30 SHT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-31 TETOR', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-31 TET', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-30 NËNTOR', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-30 NËN', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-31 DHJETOR', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-31 DHJ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ALBANIAN''') |
  TO_DATE('2026-05 JANUARY,MONDAY', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-05 JAN,MON', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-03 FEBRUARY,TUESDAY', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-03 FEB,TUE', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-04 MARCH,WEDNESDAY', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-04 MAR,WED', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-02 APRIL,THURSDAY', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-02 APR,THU', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-01 MAY,FRIDAY', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-01 MAY,FRI', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-06 JUNE,SATURDAY', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-06 JUN,SAT', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-05 JULY,SUNDAY', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-05 JUL,SUN', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-31 AUGUST', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-31 AUG', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-30 SEPTEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-30 SEP', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-31 OCTOBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-31 OCT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-30 NOVEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-30 NOV', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-31 DECEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-31 DEC', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''AMERICAN''') |
  TO_DATE('2026-05 يناير,الاثنين', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-05 يناير,الاثنين', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-03 فبراير,الثلاثاء', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-03 فبراير,الثلاثاء', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-04 مارس,الاربعاء', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-04 مارس,الاربعاء', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-02 ابريل,الخميس', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-02 ابريل,الخميس', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-01 مايو,الجمعة', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-01 مايو,الجمعة', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-06 يونيو,السبت', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-06 يونيو,السبت', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-05 يوليو,الاحد', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-05 يوليو,الاحد', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-31 اغسطس', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-31 اغسطس', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-30 سبتمبر', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-30 سبتمبر', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-31 اكتوبر', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-31 اكتوبر', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-30 نوفمبر', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-30 نوفمبر', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-31 ديسمبر', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-31 ديسمبر', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ARABIC''') |
  TO_DATE('2026-05 URTARRILAK,ASTELEHENA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-05 URT.,AL.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-03 OTSAILAK,ASTEARTEA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-03 OTS.,AR.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-04 MARTXOAK,ASTEAZKENA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-04 MAR.,AZ.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-02 APIRILAK,OSTEGUNA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-02 API.,OG.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-01 MAIATZAK,OSTIRALA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-01 MAI.,OR.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-06 EKAINAK,LARUNBATA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-06 EKA.,LR.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-05 UZTAILAK,IGANDEA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-05 UZT.,IG.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-31 ABUZTUAK', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-31 ABU.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-30 IRAILAK', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-30 IRA.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-31 URRIAK', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-31 URR.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-30 AZAROAK', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-30 AZA.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-31 ABENDUAK', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-31 ABE.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''BASQUE''') |
  TO_DATE('2026-05 СТУДЗЕНЬ,ПАНЯДЗЕЛАК', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-05 СТУ,ПН', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-03 ЛЮТЫ,АЎТОРАК', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-03 ЛЮТ,АЎ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-04 САКАВІК,СЕРАДА', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-04 САК,СР', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-02 КРАСАВІК,ЧАЦВЕР', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-02 КРА,ЧЦ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-01 МАЙ,ПЯТНІЦА', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-01 МАЙ,ПТ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-06 ЧЭРВЕНЬ,СУБОТА', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-06 ЧЭР,СБ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-05 ЛІПЕНЬ,НЯДЗЕЛЯ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-05 ЛІП,НД', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-31 ЖНІВЕНЬ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-31 ЖНІ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-30 ВЕРАСЕНЬ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-30 ВЕР', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-31 КАСТРЫЧНІК', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-31 КАС', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-30 ЛІСТАПАД', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-30 ЛІС', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-31 СЬНЕЖАНЬ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-31 СНЕ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''BELARUSIAN''') |
  TO_DATE('2026-05 JANEIRO,SEGUNDA-FEIRA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-05 JAN,SEG', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-03 FEVEREIRO,TERÇA-FEIRA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-03 FEV,TER', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-04 MARÇO,QUARTA-FEIRA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-04 MAR,QUA', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-02 ABRIL,QUINTA-FEIRA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-02 ABR,QUI', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-01 MAIO,SEXTA-FEIRA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-01 MAI,SEX', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-06 JUNHO,SÁBADO', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-06 JUN,SÁB', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-05 JULHO,DOMINGO', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-05 JUL,DOM', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-31 AGOSTO', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-31 AGO', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-30 SETEMBRO', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-30 SET', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-31 OUTUBRO', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-31 OUT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-30 NOVEMBRO', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-30 NOV', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-31 DEZEMBRO', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-31 DEZ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''BRAZILIAN PORTUGUESE''') |
  TO_DATE('2026-05 ЯНУАРИ,ПОНЕДЕЛНИК', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-05 ЯН.,ПН', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-03 ФЕВРУАРИ,ВТОРНИК', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-03 ФЕВ.,ВТ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-04 МАРТ,СРЯДА', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-04 МАРТ.,СР', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-02 АПРИЛ,ЧЕТВЪРТЪК', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-02 АПР.,ЧТ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-01 МАЙ,ПЕТЪК', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-01 МАЙ.,ПТ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-06 ЮНИ,СЪБОТА', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-06 ЮНИ.,СБ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-05 ЮЛИ,НЕДЕЛЯ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-05 ЮЛИ.,НД', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-31 АВГУСТ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-31 АВГ.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-30 СЕПТЕМВРИ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-30 СЕП.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-31 ОКТОМВРИ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-31 ОКТ.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-30 НОЕМВРИ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-30 НОЕМ.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-31 ДЕКЕМВРИ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-31 ДЕК.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''BULGARIAN''') |
  TO_DATE('2026-05 JANVIER,LUNDI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-05 JANV.,LUN.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-03 FÉVRIER,MARDI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-03 FÉVR.,MAR.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-04 MARS,MERCREDI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-04 MARS,MER.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-02 AVRIL,JEUDI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-02 AVR.,JEU.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-01 MAI,VENDREDI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-01 MAI,VEN.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-06 JUIN,SAMEDI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-06 JUIN,SAM.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-05 JUILLET,DIMANCHE', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-05 JUIL.,DIM.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-31 AOÛT', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-31 AOÛT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-30 SEPTEMBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-30 SEPT.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-31 OCTOBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-31 OCT.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-30 NOVEMBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-30 NOV.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-31 DÉCEMBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-31 DÉC.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CANADIAN FRENCH''') |
  TO_DATE('2026-05 GENER,DILLUNS', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-05 GEN.,DL.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-03 FEBRER,DIMARTS', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-03 FEBR.,DT.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-04 MARÇ,DIMECRES', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-04 MARÇ,DC.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-02 ABRIL,DIJOUS', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-02 ABR.,DJ.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-01 MAIG,DIVENDRES', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-01 MAIG,DV.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-06 JUNY,DISSABTE', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-06 JUNY,DS.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-05 JULIOL,DIUMENGE', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-05 JUL.,DG.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-31 AGOST', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-31 AG.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-30 SETEMBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-30 SET.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-31 OCTUBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-31 OCT.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-30 NOVEMBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-30 NOV.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-31 DESEMBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-31 DES.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CATALAN''') |
  TO_DATE('2026-05 SIJEČANJ,PONEDJELJAK', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-05 SIJ,PON', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-03 VELJAČA,UTORAK', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-03 VEL,UTO', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-04 OŽUJAK,SRIJEDA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-04 OŽU,SRI', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-02 TRAVANJ,ČETVRTAK', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-02 TRA,ČET', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-01 SVIBANJ,PETAK', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-01 SVI,PET', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-06 LIPANJ,SUBOTA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-06 LIP,SUB', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-05 SRPANJ,NEDJELJA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-05 SRP,NED', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-31 KOLOVOZ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-31 KOL', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-30 RUJAN', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-30 RUJ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-31 LISTOPAD', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-31 LIS', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-30 STUDENI', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-30 STU', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-31 PROSINAC', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-31 PRO', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CROATIAN''') |
  TO_DATE('2026-05 ЈАНУАР,ПОНЕДЕЉАК', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-05 ЈАН,ПОН', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-03 ФЕБРУАР,УТОРАК', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-03 ФЕБ,УТО', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-04 МАРТ,СРЕДА', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-04 МАР,СРЕ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-02 АПРИЛ,ЧЕТВРТАК', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-02 АПР,ЧЕТ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-01 МАЈ,ПЕТАК', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-01 МАЈ,ПЕТ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-06 ЈУН,СУБОТА', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-06 ЈУН,СУБ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-05 ЈУЛ,НЕДЕЉА', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-05 ЈУЛ,НЕД', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-31 АВГУСТ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-31 АВГ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-30 СЕПТЕМБАР', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-30 СЕП', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-31 ОКТОБАР', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-31 ОКТ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-30 НОВЕМБАР', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-30 НОВ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-31 ДЕЦЕМБАР', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-31 ДЕЦ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CYRILLIC SERBIAN''') |
  TO_DATE('2026-05 LEDEN,PONDĚLÍ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-05 LED,PO', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-03 ÚNOR,ÚTERÝ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-03 ÚNO,ÚT', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-04 BŘEZEN,STŘEDA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-04 BŘE,ST', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-02 DUBEN,ČTVRTEK', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-02 DUB,ČT', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-01 KVĚTEN,PÁTEK', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-01 KVĚ,PÁ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-06 ČERVEN,SOBOTA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-06 ČER,SO', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-05 ČERVENEC,NEDĚLE', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-05 ČVC,NE', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-31 SRPEN', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-31 SRP', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-30 ZÁŘÍ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-30 ZÁŘ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-31 ŘÍJEN', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-31 ŘÍJ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-30 LISTOPAD', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-30 LIS', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-31 PROSINEC', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-31 PRO', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''CZECH''') |
  TO_DATE('2026-05 JANUAR,MANDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-05 JAN,MA', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-03 FEBRUAR,TIRSDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-03 FEB,TI', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-04 MARTS,ONSDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-04 MAR,ON', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-02 APRIL,TORSDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-02 APR,TO', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-01 MAJ,FREDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-01 MAJ,FR', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-06 JUNI,LØRDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-06 JUN,LØ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-05 JULI,SØNDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-05 JUL,SØ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-31 AUGUST', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-31 AUG', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-30 SEPTEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-30 SEP', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-31 OKTOBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-31 OKT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-30 NOVEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-30 NOV', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-31 DECEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-31 DEC', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''DANISH''') |
  TO_DATE('2026-05 JANUARI,MAANDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-05 JAN,MA', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-03 FEBRUARI,DINSDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-03 FEB,DI', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-04 MAART,WOENSDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-04 MRT,WO', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-02 APRIL,DONDERDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-02 APR,DO', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-01 MEI,VRIJDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-01 MEI,VR', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-06 JUNI,ZATERDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-06 JUN,ZA', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-05 JULI,ZONDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-05 JUL,ZO', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-31 AUGUSTUS', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-31 AUG', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-30 SEPTEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-30 SEP', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-31 OKTOBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-31 OKT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-30 NOVEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-30 NOV', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-31 DECEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-31 DEC', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''DUTCH''') |
  TO_DATE('2026-05 JANUARY,MONDAY', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-05 JAN,MON', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-03 FEBRUARY,TUESDAY', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-03 FEB,TUE', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-04 MARCH,WEDNESDAY', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-04 MAR,WED', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-02 APRIL,THURSDAY', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-02 APR,THU', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-01 MAY,FRIDAY', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-01 MAY,FRI', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-06 JUNE,SATURDAY', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-06 JUN,SAT', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-05 JULY,SUNDAY', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-05 JUL,SUN', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-31 AUGUST', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-31 AUG', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-30 SEPTEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-30 SEP', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-31 OCTOBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-31 OCT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-30 NOVEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-30 NOV', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-31 DECEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-31 DEC', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ENGLISH''') |
  TO_DATE('2026-05 JAANUAR,ESMASPÄEV', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-05 JAAN,E', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-03 VEEBRUAR,TEISIPÄEV', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-03 VEEBR,T', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-04 MÄRTS,KOLMAPÄEV', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-04 MÄRTS,K', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-02 APRILL,NELJAPÄEV', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-02 APR,N', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-01 MAI,REEDE', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-01 MAI,R', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-06 JUUNI,LAUPÄEV', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-06 JUUNI,L', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-05 JUULI,PÜHAPÄEV', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-05 JUULI,P', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-31 AUGUST', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-31 AUG', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-30 SEPTEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-30 SEPT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-31 OKTOOBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-31 OKT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-30 NOVEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-30 NOV', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-31 DETSEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-31 DETS', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ESTONIAN''') |
  TO_DATE('2026-05 TAMMIKUU,MAANANTAI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-05 TAMMI,MA', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-03 HELMIKUU,TIISTAI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-03 HELMI,TI', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-04 MAALISKUU,KESKIVIIKKO', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-04 MAALIS,KE', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-02 HUHTIKUU,TORSTAI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-02 HUHTI,TO', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-01 TOUKOKUU,PERJANTAI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-01 TOUKO,PE', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-06 KESÄKUU,LAUANTAI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-06 KESÄ,LA', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-05 HEINÄKUU,SUNNUNTAI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-05 HEINÄ,SU', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-31 ELOKUU', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-31 ELO', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-30 SYYSKUU', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-30 SYYS', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-31 LOKAKUU', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-31 LOKA', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-30 MARRASKUU', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-30 MARRAS', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-31 JOULUKUU', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-31 JOULU', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''FINNISH''') |
  TO_DATE('2026-05 JANVIER,LUNDI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-05 JANV.,LUN.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-03 FÉVRIER,MARDI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-03 FÉVR.,MAR.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-04 MARS,MERCREDI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-04 MARS,MER.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-02 AVRIL,JEUDI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-02 AVR.,JEU.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-01 MAI,VENDREDI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-01 MAI,VEN.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-06 JUIN,SAMEDI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-06 JUIN,SAM.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-05 JUILLET,DIMANCHE', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-05 JUIL.,DIM.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-31 AOÛT', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-31 AOÛT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-30 SEPTEMBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-30 SEPT.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-31 OCTOBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-31 OCT.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-30 NOVEMBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-30 NOV.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-31 DÉCEMBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-31 DÉC.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''FRENCH''') |
  TO_DATE('2026-05 JANUAR,MONTAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-05 JAN,MO', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-03 FEBRUAR,DIENSTAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-03 FEB,DI', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-04 MÄRZ,MITTWOCH', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-04 MRZ,MI', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-02 APRIL,DONNERSTAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-02 APR,DO', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-01 MAI,FREITAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-01 MAI,FR', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-06 JUNI,SAMSTAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-06 JUN,SA', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-05 JULI,SONNTAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-05 JUL,SO', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-31 AUGUST', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-31 AUG', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-30 SEPTEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-30 SEP', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-31 OKTOBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-31 OKT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-30 NOVEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-30 NOV', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-31 DEZEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-31 DEZ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''GERMAN''') |
  TO_DATE('2026-05 ΙΑΝΟΥΆΡΙΟΣ,ΔΕΥΤΈΡΑ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-05 ΙΑΝ,ΔΕΥ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-03 ΦΕΒΡΟΥΆΡΙΟΣ,ΤΡΊΤΗ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-03 ΦΕΒ,ΤΡ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-04 ΜΆΡΤΙΟΣ,ΤΕΤΆΡΤΗ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-04 ΜΑΡ,ΤΕΤ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-02 ΑΠΡΊΛΙΟΣ,ΠΈΜΠΤΗ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-02 ΑΠΡ,ΠΕΜ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-01 ΜΆΙΟΣ,ΠΑΡΑΣΚΕΥΉ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-01 ΜΑΪ,ΠΑΡ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-06 ΙΟΎΝΙΟΣ,ΣΆΒΒΑΤΟ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-06 ΙΟΥΝ,ΣΑΒ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-05 ΙΟΎΛΙΟΣ,ΚΥΡΙΑΚΉ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-05 ΙΟΥΛ,ΚΥΡ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-31 ΑΎΓΟΥΣΤΟΣ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-31 ΑΥΓ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-30 ΣΕΠΤΈΜΒΡΙΟΣ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-30 ΣΕΠ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-31 ΟΚΤΏΒΡΙΟΣ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-31 ΟΚΤ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-30 ΝΟΈΜΒΡΙΟΣ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-30 ΝΟΕ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-31 ΔΕΚΈΜΒΡΙΟΣ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-31 ΔΕΚ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''GREEK''') |
  TO_DATE('2026-05 ינואר,יום שני', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-05 ינואר,ב', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-03 פברואר,יום שלישי', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-03 פברואר,ג', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-04 מרץ,יום רביעי', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-04 מרץ,ד', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-02 אפריל,יום חמישי', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-02 אפריל,ה', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-01 מאי,יום שישי', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-01 מאי,ו', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-06 יוני,שבת', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-06 יוני,ש', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-05 יולי,יום ראשון', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-05 יולי,א', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-31 אוגוסט', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-31 אוגוסט', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-30 ספטמבר', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-30 ספטמבר', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-31 אוקטובר', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-31 אוקטובר', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-30 נובמבר', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-30 נובמבר', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-31 דצמבר', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-31 דצמבר', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''HEBREW''') |
  TO_DATE('2026-05 जनवरी,सोमवार', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-05 जनवरी,सोम', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-03 फरवरी,मंगलवार', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-03 फरवरी,मंगल', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-04 मार्च,बुधवार', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-04 मार्च,बुध', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-02 अप्रैल,गुरूवार', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-02 अप्रैल,गुरू', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-01 मई,शुक्रवार', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-01 मई,शुक्र', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-06 जून,शनिवार', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-06 जून,शनि', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-05 जुलाई,रविवार', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-05 जुलाई,रवि', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-31 अगस्त', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-31 अगस्त', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-30 सितम्बर', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-30 सितम्बर', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-31 अक्टूबर', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-31 अक्टूबर', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-30 नवम्बर', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-30 नवम्बर', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-31 दिसम्बर', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-31 दिसम्बर', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''HINDI''') |
  TO_DATE('2026-05 JANUÁR,HÉTFŐ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-05 JAN.,H.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-03 FEBRUÁR,KEDD', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-03 FEBR.,K.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-04 MÁRCIUS,SZERDA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-04 MÁRC.,SZE', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-02 ÁPRILIS,CSÜTÖRTÖK', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-02 ÁPR.,CS.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-01 MÁJUS,PÉNTEK', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-01 MÁJ.,P.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-06 JÚNIUS,SZOMBAT', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-06 JÚN.,SZO', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-05 JÚLIUS,VASÁRNAP', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-05 JÚL.,V.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-31 AUGUSZTUS', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-31 AUG.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-30 SZEPTEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-30 SZEPT.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-31 OKTÓBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-31 OKT.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-30 NOVEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-30 NOV.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-31 DECEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-31 DEC.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''HUNGARIAN''') |
  TO_DATE('2026-05 JANÚAR,MÁNUDAGUR', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-05 JAN,MÁN', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-03 FEBRÚAR,ÞRIÐJUDAGUR', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-03 FEB,ÞRI', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-04 MARS,MIÐVIKUDAGUR', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-04 MAR,MIÐ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-02 APRÍL,FIMMTUDAGUR', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-02 APR,FIM', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-01 MAÍ,FÖSTUDAGUR', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-01 MAÍ,FÖS', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-06 JÚNÍ,LAUGARDAGUR', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-06 JÚN,LAU', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-05 JÚLÍ,SUNNUDAGUR', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-05 JÚL,SUN', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-31 ÁGÚST', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-31 ÁGÚ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-30 SEPTEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-30 SEP', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-31 OKTÓBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-31 OKT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-30 NÓVEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-30 NÓV', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-31 DESEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-31 DES', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ICELANDIC''') |
  TO_DATE('2026-05 JANUARI,SENIN', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-05 JAN,SEN', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-03 FEBRUARI,SELASA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-03 FEB,SEL', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-04 MARET,RABU', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-04 MAR,RAB', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-02 APRIL,KAMIS', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-02 APR,KAM', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-01 MEI,JUMAT', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-01 MEI,JUM', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-06 JUNI,SABTU', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-06 JUN,SAB', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-05 JULI,MINGGU', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-05 JUL,MIN', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-31 AGUSTUS', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-31 AGT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-30 SEPTEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-30 SEP', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-31 OKTOBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-31 OKT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-30 NOVEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-30 NOV', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-31 DESEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-31 DES', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''INDONESIAN''') |
  TO_DATE('2026-05 GENNAIO,LUNEDÌ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-05 GEN,LUN', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-03 FEBBRAIO,MARTEDÌ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-03 FEB,MAR', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-04 MARZO,MERCOLEDÌ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-04 MAR,MER', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-02 APRILE,GIOVEDÌ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-02 APR,GIO', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-01 MAGGIO,VENERDÌ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-01 MAG,VEN', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-06 GIUGNO,SABATO', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-06 GIU,SAB', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-05 LUGLIO,DOMENICA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-05 LUG,DOM', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-31 AGOSTO', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-31 AGO', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-30 SETTEMBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-30 SET', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-31 OTTOBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-31 OTT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-30 NOVEMBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-30 NOV', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-31 DICEMBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-31 DIC', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ITALIAN''') |
  TO_DATE('2026-05 1月,月曜日', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-05 1月,月', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-03 2月,火曜日', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-03 2月,火', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-04 3月,水曜日', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-04 3月,水', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-02 4月,木曜日', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-02 4月,木', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-01 5月,金曜日', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-01 5月,金', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-06 6月,土曜日', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-06 6月,土', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-05 7月,日曜日', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-05 7月,日', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-31 8月', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-31 8月', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-30 9月', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-30 9月', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-31 10月', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-31 10月', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-30 11月', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-30 11月', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-31 12月', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-31 12月', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''JAPANESE''') |
  TO_DATE('2026-05 ಜನವರಿ,ಸೋಮವಾರ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-05 ಜನವರಿ,ಸೋಮ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-03 ಫೆಬ್ರವರಿ,ಮಂಗಳವಾರ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-03 ಫೆಬ್ರವರಿ,ಮಂಗಳ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-04 ಮಾರ್ಚ್,ಬುಧವಾರ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-04 ಮಾರ್ಚ್,ಬುಧು', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-02 ಏಪ್ರಿಲ್,ಗುರುವಾರ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-02 ಏಪ್ರಿಲ್,ಗುರು', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-01 ಮೇ,ಶುಕ್ರವಾರ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-01 ಮೇ,ಶುಕ್ರ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-06 ಜೂನ್,ಶನಿವಾರ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-06 ಜೂನ್,ಶನಿ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-05 ಜುಲೈ,ಭಾನುವಾರ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-05 ಜುಲೈ,ಭಾನು', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-31 ಅಗಸ್ಟ್', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-31 ಅಗಸ್ಟ್', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-30 ಸೆಪ್ಟಂಬರ್', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-30 ಸೆಪ್ಟಂಬರ್', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-31 ಅಕ್ಟೋಬರ್', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-31 ಅಕ್ಟೋಬರ್', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-30 ನವೆಂಬರ್', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-30 ನವೆಂಬರ್', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-31 ಡಿಸೆಂಬರ್', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-31 ಡಿಸೆಂಬರ್', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''KANNADA''') |
  TO_DATE('2026-05 1월,월요일', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-05 1월,월', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-03 2월,화요일', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-03 2월,화', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-04 3월,수요일', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-04 3월,수', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-02 4월,목요일', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-02 4월,목', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-01 5월,금요일', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-01 5월,금', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-06 6월,토요일', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-06 6월,토', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-05 7월,일요일', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-05 7월,일', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-31 8월', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-31 8월', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-30 9월', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-30 9월', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-31 10월', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-31 10월', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-30 11월', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-30 11월', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-31 12월', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-31 12월', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''KOREAN''') |
  TO_DATE('2026-05 ENERO,LUNES', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-05 ENE,LUN', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-03 FEBRERO,MARTES', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-03 FEB,MAR', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-04 MARZO,MIÉRCOLES', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-04 MAR,MIÉ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-02 ABRIL,JUEVES', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-02 ABR,JUE', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-01 MAYO,VIERNES', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-01 MAY,VIE', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-06 JUNIO,SÁBADO', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-06 JUN,SÁB', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-05 JULIO,DOMINGO', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-05 JUL,DOM', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-31 AGOSTO', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-31 AGO', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-30 SEPTIEMBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-30 SEP', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-31 OCTUBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-31 OCT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-30 NOVIEMBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-30 NOV', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-31 DICIEMBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-31 DIC', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''LATIN AMERICAN SPANISH''') |
  TO_DATE('2026-05 JANVĀRIS,PIRMDIENA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-05 JAN,PR', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-03 FEBRUĀRIS,OTRDIENA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-03 FEB,OT', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-04 MARTS,TREŠDIENA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-04 MAR,TR', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-02 APRĪLIS,CETURTDIENA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-02 APR,CE', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-01 MAIJS,PIEKTDIENA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-01 MAI,PK', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-06 JŪNIJS,SESTDIENA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-06 JŪN,SE', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-05 JŪLIJS,SVĒTDIENA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-05 JŪL,SV', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-31 AUGUSTS', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-31 AUG', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-30 SEPTEMBRIS', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-30 SEP', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-31 OKTOBRIS', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-31 OKT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-30 NOVEMBRIS', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-30 NOV', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-31 DECEMBRIS', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-31 DEC', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''LATVIAN''') |
  TO_DATE('2026-05 SAUSIO,PIRMADIENIS', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-05 SAU,PR', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-03 VASARIO,ANTRADIENIS', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-03 VAS,AN', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-04 KOVO,TREČIADIENIS', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-04 KOV,TR', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-02 BALANDŽIO,KETVIRTADIENIS', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-02 BAL,KT', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-01 GEGUŽĖS,PENKTADIENIS', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-01 GEG,PN', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-06 BIRŽELIO,ŠEŠTADIENIS', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-06 BIR,ŠT', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-05 LIEPOS,SEKMADIENIS', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-05 LIE,SK', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-31 RUGPJŪČIO', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-31 RGP', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-30 RUGSĖJO', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-30 RGS', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-31 SPALIO', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-31 SPL', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-30 LAPKRIČIO', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-30 LAP', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-31 GRUODŽIO', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-31 GRD', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''LITHUANIAN''') |
  TO_DATE('2026-05 ЈАНУАРИ,ПОНЕДЕЛНИК', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-05 ЈАН,ПОН', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-03 ФЕВРУАРИ,ВТОРНИК', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-03 ФЕВ,ВТР', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-04 МАРТ,СРЕДА', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-04 МАР,СРД', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-02 АПРИЛ,ЧЕТВРТОК', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-02 АПР,ЧЕТ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-01 МАЈ,ПЕТОК', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-01 МАЈ,ПЕТ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-06 ЈУНИ,САБОТА', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-06 ЈУН,САБ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-05 ЈУЛИ,НЕДЕЛА', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-05 ЈУЛ,НЕД', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-31 АВГУСТ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-31 АВГ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-30 СЕПТЕМВРИ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-30 СЕП', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-31 ОКТОМВРИ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-31 ОКТ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-30 НОЕМВРИ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-30 НОЕ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-31 ДЕКЕМВРИ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-31 ДЕК', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''MACEDONIAN''') |
  TO_DATE('2026-05 JANUARI,ISNIN', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-05 JAN,ISNIN', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-03 FEBRUARI,SELASA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-03 FEB,SELASA', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-04 MAC,RABU', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-04 MAC,RABU', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-02 APRIL,KHAMIS', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-02 APR,KHAMIS', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-01 MEI,JUMAAT', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-01 MEI,JUMAAT', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-06 JUN,SABTU', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-06 JUN,SABTU', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-05 JULAI,AHAD', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-05 JUL,AHAD', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-31 OGOS', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-31 OGO', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-30 SEPTEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-30 SEP', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-31 OKTOBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-31 OKT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-30 NOVEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-30 NOV', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-31 DISEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-31 DIS', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''MALAY''') |
  TO_DATE('2026-05 ENERO,LUNES', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-05 ENE,LUN', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-03 FEBRERO,MARTES', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-03 FEB,MAR', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-04 MARZO,MIÉRCOLES', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-04 MAR,MIÉ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-02 ABRIL,JUEVES', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-02 ABR,JUE', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-01 MAYO,VIERNES', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-01 MAY,VIE', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-06 JUNIO,SÁBADO', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-06 JUN,SÁB', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-05 JULIO,DOMINGO', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-05 JUL,DOM', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-31 AGOSTO', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-31 AGO', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-30 SEPTIEMBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-30 SEP', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-31 OCTUBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-31 OCT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-30 NOVIEMBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-30 NOV', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-31 DICIEMBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-31 DIC', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''MEXICAN SPANISH''') |
  TO_DATE('2026-05 JANUAR,MANDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-05 JAN,MA', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-03 FEBRUAR,TIRSDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-03 FEB,TI', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-04 MARS,ONSDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-04 MAR,ON', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-02 APRIL,TORSDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-02 APR,TO', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-01 MAI,FREDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-01 MAI,FR', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-06 JUNI,LØRDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-06 JUN,LØ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-05 JULI,SØNDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-05 JUL,SØ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-31 AUGUST', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-31 AUG', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-30 SEPTEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-30 SEP', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-31 OKTOBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-31 OKT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-30 NOVEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-30 NOV', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-31 DESEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-31 DES', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''NORWEGIAN''') |
  TO_DATE('2026-05 STYCZEŃ,PONIEDZIAŁEK', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-05 STY,PN', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-03 LUTY,WTOREK', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-03 LUT,WT', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-04 MARZEC,ŚRODA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-04 MAR,ŚR', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-02 KWIECIEŃ,CZWARTEK', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-02 KWI,CZ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-01 MAJ,PIĄTEK', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-01 MAJ,PT', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-06 CZERWIEC,SOBOTA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-06 CZE,SO', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-05 LIPIEC,NIEDZIELA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-05 LIP,N', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-31 SIERPIEŃ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-31 SIE', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-30 WRZESIEŃ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-30 WRZ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-31 PAŹDZIERNIK', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-31 PAŹ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-30 LISTOPAD', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-30 LIS', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-31 GRUDZIEŃ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-31 GRU', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''POLISH''') |
  TO_DATE('2026-05 JANEIRO,SEGUNDA-FEIRA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-05 JAN,SEG', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-03 FEVEREIRO,TERÇA-FEIRA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-03 FEV,TER', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-04 MARÇO,QUARTA-FEIRA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-04 MAR,QUA', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-02 ABRIL,QUINTA-FEIRA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-02 ABR,QUI', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-01 MAIO,SEXTA-FEIRA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-01 MAI,SEX', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-06 JUNHO,SÁBADO', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-06 JUN,SÁB', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-05 JULHO,DOMINGO', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-05 JUL,DOM', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-31 AGOSTO', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-31 AGO', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-30 SETEMBRO', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-30 SET', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-31 OUTUBRO', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-31 OUT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-30 NOVEMBRO', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-30 NOV', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-31 DEZEMBRO', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-31 DEZ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''PORTUGUESE''') |
  TO_DATE('2026-05 IANUARIE,LUNI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-05 IAN,L', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-03 FEBRUARIE,MARŢI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-03 FEB,MA', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-04 MARTIE,MIERCURI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-04 MAR,MI', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-02 APRILIE,JOI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-02 APR,J', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-01 MAI,VINERI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-01 MAI,V', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-06 IUNIE,SÂMBĂTĂ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-06 IUN,S', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-05 IULIE,DUMINICĂ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-05 IUL,D', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-31 AUGUST', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-31 AUG', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-30 SEPTEMBRIE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-30 SEP', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-31 OCTOMBRIE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-31 OCT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-30 NOIEMBRIE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-30 NOI', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-31 DECEMBRIE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-31 DEC', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''ROMANIAN''') |
  TO_DATE('2026-05 ЯНВАРЬ,ПОНЕДЕЛЬНИК', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-05 ЯНВ,ПН', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-03 ФЕВРАЛЬ,ВТОРНИК', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-03 ФЕВ,ВТ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-04 МАРТ,СРЕДА', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-04 МАР,СР', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-02 АПРЕЛЬ,ЧЕТВЕРГ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-02 АПР,ЧТ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-01 МАЙ,ПЯТНИЦА', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-01 МАЙ,ПТ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-06 ИЮНЬ,СУББОТА', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-06 ИЮН,СБ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-05 ИЮЛЬ,ВОСКРЕСЕНЬЕ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-05 ИЮЛ,ВС', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-31 АВГУСТ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-31 АВГ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-30 СЕНТЯБРЬ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-30 СЕН', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-31 ОКТЯБРЬ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-31 ОКТ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-30 НОЯБРЬ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-30 НОЯ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-31 ДЕКАБРЬ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-31 ДЕК', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''RUSSIAN''') |
  TO_DATE('2026-05 1月,星期一', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-05 1月,星期一', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-03 2月,星期二', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-03 2月,星期二', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-04 3月,星期三', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-04 3月,星期三', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-02 4月,星期四', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-02 4月,星期四', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-01 5月,星期五', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-01 5月,星期五', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-06 6月,星期六', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-06 6月,星期六', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-05 7月,星期日', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-05 7月,星期日', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-31 8月', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-31 8月', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-30 9月', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-30 9月', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-31 10月', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-31 10月', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-30 11月', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-30 11月', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-31 12月', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-31 12月', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SIMPLIFIED CHINESE''') |
  TO_DATE('2026-05 JANUÁR,PONDELOK', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-05 JAN,PO', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-03 FEBRUÁR,UTOROK', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-03 FEB,UT', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-04 MAREC,STREDA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-04 MAR,ST', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-02 APRÍL,ŠTVRTOK', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-02 APR,ŠT', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-01 MÁJ,PIATOK', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-01 MÁJ,PI', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-06 JÚN,SOBOTA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-06 JÚN,SO', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-05 JÚL,NEDEĽA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-05 JÚL,NE', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-31 AUGUST', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-31 AUG', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-30 SEPTEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-30 SEP', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-31 OKTÓBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-31 OKT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-30 NOVEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-30 NOV', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-31 DECEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-31 DEC', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SLOVAK''') |
  TO_DATE('2026-05 JANUAR,PONEDELJEK', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-05 JAN,PON', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-03 FEBRUAR,TOREK', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-03 FEB,TOR', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-04 MAREC,SREDA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-04 MAR,SRE', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-02 APRIL,ČETRTEK', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-02 APR,ČET', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-01 MAJ,PETEK', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-01 MAJ,PET', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-06 JUNIJ,SOBOTA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-06 JUN,SOB', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-05 JULIJ,NEDELJA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-05 JUL,NED', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-31 AVGUST', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-31 AVG', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-30 SEPTEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-30 SEP', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-31 OKTOBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-31 OKT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-30 NOVEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-30 NOV', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-31 DECEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-31 DEC', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SLOVENIAN''') |
  TO_DATE('2026-05 ENERO,LUNES', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-05 ENE,LUN', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-03 FEBRERO,MARTES', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-03 FEB,MAR', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-04 MARZO,MIÉRCOLES', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-04 MAR,MIÉ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-02 ABRIL,JUEVES', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-02 ABR,JUE', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-01 MAYO,VIERNES', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-01 MAY,VIE', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-06 JUNIO,SÁBADO', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-06 JUN,SÁB', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-05 JULIO,DOMINGO', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-05 JUL,DOM', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-31 AGOSTO', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-31 AGO', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-30 SEPTIEMBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-30 SEP', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-31 OCTUBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-31 OCT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-30 NOVIEMBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-30 NOV', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-31 DICIEMBRE', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-31 DIC', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SPANISH''') |
  TO_DATE('2026-05 JANUARI,JUMATATU', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-05 JAN,J3', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-03 FEBRUARI,JUMANNE', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-03 FEB,J4', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-04 MACHI,JUMATANO', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-04 MAC,J5', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-02 APRILI,ALHAMISI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-02 APR,ALH', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-01 MEI,IJUMAA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-01 MEI,IJ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-06 JUNI,JUMAMOSI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-06 JUN,J1', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-05 JULAI,JUMAPILI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-05 JUL,J2', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-31 AGOSTI', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-31 AGO', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-30 SEPTEMBA', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-30 SEP', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-31 OKTOBA', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-31 OKT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-30 NOVEMBA', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-30 NOV', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-31 DESEMBA', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-31 DES', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SWAHILI''') |
  TO_DATE('2026-05 JANUARI,MÅNDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-05 JAN,MÅ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-03 FEBRUARI,TISDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-03 FEB,TI', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-04 MARS,ONSDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-04 MAR,ON', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-02 APRIL,TORSDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-02 APR,TO', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-01 MAJ,FREDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-01 MAJ,FR', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-06 JUNI,LÖRDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-06 JUN,LÖ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-05 JULI,SÖNDAG', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-05 JUL,SÖ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-31 AUGUSTI', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-31 AUG', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-30 SEPTEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-30 SEP', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-31 OKTOBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-31 OKT', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-30 NOVEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-30 NOV', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-31 DECEMBER', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-31 DEC', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''SWEDISH''') |
  TO_DATE('2026-05 ஜனவரி,திங்கட்கிழமை', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-05 ஜன.,திங்கள்', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-03 பிப்ரவரி,செவ்வாய்', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-03 பிப்.,செவவாய்', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-04 மார்ச்,புதன்கிழமை', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-04 மார்.,புதன்', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-02 ஏப்ரல்,வியாழன்', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-02 ஏப்.,வியாழன்', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-01 மே,வெள்ளி', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-01 மே,வெள்ளி', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-06 ஜூன்,சனிக்கிழமை', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-06 ஜூன்,சனி', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-05 ஜூலை,ஞாயிறு', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-05 ஜூலை,ஞாயிறு', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-31 ஆகஸ்ட்', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-31 ஆக.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-30 செப்டம்பர்', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-30 செப்.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-31 அக்டோபர்', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-31 அக்.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-30 நவம்பர்', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-30 நவ.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-31 டிசம்பர்', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-31 டிச.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''TAMIL''') |
  TO_DATE('2026-05 มกราคม,จันทร์', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-05 ม.ค.,จ.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-03 กุมภาพันธ์,อังคาร', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-03 ก.พ.,อ.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-04 มีนาคม,พุธ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-04 มี.ค.,พ.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-02 เมษายน,พฤหัสบดี', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-02 เม.ย.,พฤ.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-01 พฤษภาคม,ศุกร์', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-01 พ.ค.,ศ.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-06 มิถุนายน,เสาร์', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-06 มิ.ย.,ส.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-05 กรกฎาคม,อาทิตย์', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-05 ก.ค.,อา.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-31 สิงหาคม', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-31 ส.ค.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-30 กันยายน', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-30 ก.ย.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-31 ตุลาคม', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-31 ต.ค.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-30 พฤศจิกายน', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-30 พ.ย.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-31 ธันวาคม', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-31 ธ.ค.', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''THAI''') |
  TO_DATE('2026-05 1月,星期一', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-05 1月,星期一', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-03 2月,星期二', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-03 2月,星期二', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-04 3月,星期三', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-04 3月,星期三', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-02 4月,星期四', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-02 4月,星期四', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-01 5月,星期五', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-01 5月,星期五', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-06 6月,星期六', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-06 6月,星期六', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-05 7月,星期日', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-05 7月,星期日', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-31 8月', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-31 8月', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-30 9月', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-30 9月', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-31 10月', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-31 10月', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-30 11月', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-30 11月', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-31 12月', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-31 12月', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''TRADITIONAL CHINESE''') |
  TO_DATE('2026-05 OCAK,PAZARTESI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-05 OCA,PZT', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-03 ŞUBAT,SALI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-03 ŞUB,SAL', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-04 MART,ÇARŞAMBA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-04 MAR,ÇAR', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-02 NISAN,PERŞEMBE', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-02 NIS,PER', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-01 MAYIS,CUMA', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-01 MAY,CUM', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-06 HAZIRAN,CUMARTESI', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-06 HAZ,CMT', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-05 TEMMUZ,PAZAR', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-05 TEM,PAZ', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-31 AĞUSTOS', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-31 AĞU', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-30 EYLÜL', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-30 EYL', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-31 EKIM', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-31 EKI', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-30 KASIM', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-30 KAS', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-31 ARALIK', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-31 ARA', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''TURKISH''') |
  TO_DATE('2026-05 СІЧЕНЬ,ПОНЕДІЛОК', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-05 СІЧ,ПН.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-03 ЛЮТИЙ,ВІВТОРОК', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-03 ЛЮТ,ВТ.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-04 БЕРЕЗЕНЬ,СЕРЕДА', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-04 БЕР,СР.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-02 КВІТЕНЬ,ЧЕТВЕР', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-02 КВІ,ЧТ.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-01 ТРАВЕНЬ,П''ЯТНИЦЯ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-01 ТРА,ПТ.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-06 ЧЕРВЕНЬ,СУБОТА', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-06 ЧЕР,СБ.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-05 ЛИПЕНЬ,НЕДІЛЯ', 'YYYY-DD MONTH, DAY','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-05 ЛИП,НД.', 'YYYY-DD MON, DY','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-31 СЕРПЕНЬ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-31 СЕР', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-30 ВЕРЕСЕНЬ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-30 ВЕР', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-31 ЖОВТЕНЬ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-31 ЖОВ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-30 ЛИСТОПАД', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-30 ЛИС', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-31 ГРУДЕНЬ', 'YYYY-DD MONTH','NLS_DATE_LANGUAGE=''UKRAINIAN''') |
  TO_DATE('2026-31 ГРУ', 'YYYY-DD MON','NLS_DATE_LANGUAGE=''UKRAINIAN''')
;
