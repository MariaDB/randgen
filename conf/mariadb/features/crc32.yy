# Copyright (c) 2022, MariaDB Corporation Ab.
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

query_init_add:
   { $tmp_table = 0; '' } ;

query_add:
    ==FACTOR:9== crc32_select_or_explain_select
  | { $tmp_table++; '' } crc32_create_and_drop
;

crc32_create_and_drop:
   CREATE _basics_temporary_50pct TABLE { 'tmp'.$tmp_table } AS crc32_select ; DROP TABLE IF EXISTS { 'tmp'.$tmp_table } ;

crc32_select_or_explain_select:
   _basics_explain_analyze crc32_select;

crc32_select_list:
   crc32_select_item AS { $num++; 'field'.$num } | crc32_select_item AS { $num++; 'field'.$num } , crc32_select_list ;

crc32_select_item:
   crc32_func | crc32_aggregate_func
;

crc32_select:
  { $num = 0; '' } /* _table */ SELECT _basics_distinct_50pct crc32_select_list FROM { $last_table } crc32_where crc32_group_by_having_order_by_limit ;

crc32_aggregate_func:
   COUNT( crc32_func )
   | AVG( crc32_func )
   | SUM( crc32_func )
   | MAX( crc32_func )
   | MIN( crc32_func )
   | GROUP_CONCAT( crc32_func, crc32_func )
   | BIT_AND( crc32_arg )
   | BIT_COUNT( crc32_arg )
   | BIT_LENGTH( crc32_arg )
   | BIT_OR( crc32_arg )
   | BIT_XOR( crc32_arg )
   | STD( crc32_arg )
   | STDDEV( crc32_arg )
   | STDDEV_POP( crc32_arg )
   | STDDEV_SAMP( crc32_arg )
   | VAR_POP( crc32_arg )
   | VAR_SAMP( crc32_arg )
   | VARIANCE( crc32_arg )
;

crc32_where:
   | WHERE crc32_func ;

crc32_group_by_having_order_by_limit:
   crc32_group_by_with_rollup crc32_having _basics_limit_50pct |
   crc32_group_by crc32_having crc32_order_by _basics_limit_50pct
;

crc32_group_by_with_rollup:
   | GROUP BY crc32_func WITH ROLLUP | GROUP BY crc32_func, crc32_func WITH ROLLUP ;

crc32_group_by:
   | GROUP BY crc32_func | GROUP BY crc32_func, crc32_func ;

crc32_having:
   | HAVING { 'field' . $prng->int(1,$num) } _basics_comparison_operator _basics_any_value ;

crc32_order_by:
   | ORDER BY crc32_func | ORDER BY crc32_func, crc32_func ;

crc32_func:
  crc32_math_func |
   crc32_arithm_oper |
   crc32_comparison_oper |
   crc32_logical_or_bitwise_oper |
   crc32_assign_oper |
   crc32_cast_oper |
   crc32_control_flow_func |
   crc32_str_func |
   crc32_date_func |
   crc32_encrypt_func |
   crc32_information_func |
   crc32_xml_func |
   crc32_misc_func
;

crc32_misc_func:
   DEFAULT( _field ) |
   GET_LOCK( crc32_arg_char , crc32_zero_or_almost ) |
# TODO: provide reasonable IP
   INET_ATON( crc32_arg ) |
   INET_NTOA( crc32_arg ) |
   IS_FREE_LOCK( crc32_arg_char ) |
   IS_USED_LOCK( crc32_arg_char ) |
   MASTER_POS_WAIT( 'log', _int_unsigned, crc32_zero_or_almost ) |
   NAME_CONST( crc32_const_char_value, crc32_value ) |
   RAND(_int_unsigned) | RAND( crc32_arg ) |
   RELEASE_LOCK( crc32_arg_char ) |
   SLEEP( crc32_zero_or_almost ) |
   SYS_GUID() /* compatibility 10.6.1 */ |
   UUID_SHORT() |
   UUID() |
# Changed due to MDEV-12172
   /*!!100303 VALUES( _field ) */ /*!100303 VALUE( _field ) */
;

crc32_zero_or_almost:
   0 | 0.01 ;

# TODO: provide reasonable arguments to XML

crc32_xml_func:
   ExtractValue( crc32_value, crc32_xpath ) |
   UpdateXML( crc32_value, crc32_xpath, crc32_value )
;

crc32_xpath:
   { @chars = ('a','b','c','d','e','/'); $length= int(rand(127)); $x= '/'; $xpath= '/'; foreach ( 1..$length ) { $x= ( ( $x eq '/' or $_ eq $length ) ? $chars[int(rand(scalar(@chars)-1))] : $chars[int(rand(scalar(@chars)))]); $xpath.= $x ; }; "'".$xpath."'" } ;

crc32_information_func:
   CHARSET( crc32_arg ) |
   BENCHMARK( _digit, crc32_select_item ) |
   COERCIBILITY( crc32_arg ) |
   COLLATION( crc32_arg ) |
   CONNECTION_ID() |
   CURRENT_USER() | CURRENT_USER |
   DATABASE() | SCHEMA() |
   FOUND_ROWS() |
   LAST_INSERT_ID() |
   ROW_COUNT() |
   SESSION_USER() | SYSTEM_USER() | USER() |
   VERSION()
;

crc32_control_flow_func:
   CASE crc32_arg WHEN crc32_arg THEN crc32_arg END | CASE crc32_arg WHEN crc32_arg THEN crc32_arg WHEN crc32_arg THEN crc32_arg END | CASE crc32_arg WHEN crc32_arg THEN crc32_arg ELSE crc32_arg END |
   IF( crc32_arg, crc32_arg, crc32_arg ) |
   IFNULL( crc32_arg, crc32_arg ) |
   NULLIF( crc32_arg, crc32_arg )
;

crc32_cast_oper:
   BINARY crc32_arg | CAST( crc32_arg AS crc32_type ) | CONVERT( crc32_arg, crc32_type ) | CONVERT( crc32_arg USING crc32_charset ) ;

crc32_charset:
   utf8 | latin1 | utf8mb4 ;

crc32_type:
   BINARY | BINARY(_digit) | CHAR | CHAR(_digit) | DATE | DATETIME | DECIMAL | DECIMAL(crc32_decimal_m) | DECIMAL(crc32_decimal_m,crc32_decimal_d) | SIGNED | TIME | UNSIGNED ;

crc32_decimal_m:
    { $decimal_m = $prng->int(0,65) }
;

crc32_decimal_d:
    { $decimal_d = $prng->int(0,$decimal_m) }
;

crc32_encrypt_func:
   AES_DECRYPT( crc32_arg, crc32_arg ) |
   AES_ENCRYPT( crc32_arg, crc32_arg ) |
   COMPRESS( crc32_arg ) |
   DECODE( crc32_arg, crc32_arg ) |
   DES_DECRYPT( crc32_arg ) | DES_DECRYPT( crc32_arg, crc32_arg ) |
   DES_ENCRYPT( crc32_arg ) | DES_ENCRYPT( crc32_arg, crc32_arg ) |
   ENCODE( crc32_arg, crc32_arg ) |
# Crash in Item_func_encrypt::val_str
# ENCRYPT( crc32_arg ) | ENCRYPT( crc32_arg, crc32_arg ) |
   MD5( crc32_arg ) |
   OLD_PASSWORD( crc32_arg ) |
   PASSWORD( crc32_arg ) |
   SHA1( crc32_arg ) |
   SHA( crc32_arg ) |
   SHA2( crc32_arg, crc32_arg ) |
   UNCOMPRESS( crc32_arg ) |
   UNCOMPRESSED_LENGTH( crc32_arg )
;

crc32_str_func:
   ASCII( crc32_arg ) |
   BIN( crc32_arg ) |
   BIT_LENGTH( crc32_arg ) |
   CHAR_LENGTH( crc32_arg ) | CHARACTER_LENGTH( crc32_arg ) |
   CHAR( crc32_arg ) | CHAR( crc32_arg USING crc32_charset ) |
   CONCAT_WS( crc32_arg_list ) |
   CONCAT( crc32_arg ) | CONCAT( crc32_arg_list ) |
   ELT( crc32_arg_list ) |
   EXPORT_SET( crc32_arg, crc32_arg, crc32_arg ) | EXPORT_SET( crc32_arg, crc32_arg, crc32_arg, crc32_arg ) | EXPORT_SET( crc32_arg, crc32_arg, crc32_arg, crc32_arg, crc32_arg ) |
   FIELD( crc32_arg_list ) |
   FIND_IN_SET( crc32_arg, crc32_arg ) |
   FORMAT( crc32_arg, crc32_arg ) | FORMAT( crc32_arg, crc32_arg, crc32_locale ) |
   HEX( crc32_arg ) |
   INSERT( crc32_arg, crc32_arg, crc32_arg, crc32_arg ) |
   INSTR( crc32_arg, crc32_arg ) |
   LCASE( crc32_arg ) |
   LEFT( crc32_arg, crc32_arg ) |
   LENGTH( crc32_arg ) |
   crc32_arg _basics_not_33pct LIKE crc32_arg |
   LOAD_FILE( crc32_arg ) |
   LOCATE( crc32_arg, crc32_arg ) | LOCATE( crc32_arg, crc32_arg, crc32_arg ) |
   LOWER( crc32_arg ) |
   LPAD( crc32_arg, crc32_arg, crc32_arg ) |
   LTRIM( crc32_arg ) |
   MAKE_SET( crc32_arg_list ) |
   MATCH( crc32_field_list ) AGAINST ( crc32_const_char_value crc32_search_modifier ) |
   MID( crc32_arg, crc32_arg, crc32_arg ) |
   NATURAL_SORT_KEY( crc32_arg ) /* compatibility 10.7.1 */ |
   OCT( crc32_arg ) |
   OCTET_LENGTH( crc32_arg ) |
   ORD( crc32_arg ) |
   POSITION( crc32_arg IN crc32_arg ) |
   QUOTE( crc32_arg ) |
# TODO: provide reasonable patterns to REGEXP
   crc32_arg _basics_not_33pct REGEXP crc32_arg | crc32_arg _basics_not_33pct RLIKE crc32_arg |
   REPEAT( crc32_arg, crc32_arg ) |
   REPLACE( crc32_arg, crc32_arg, crc32_arg ) |
   REVERSE( crc32_arg ) |
   RIGHT( crc32_arg, crc32_arg ) |
   RPAD( crc32_arg, crc32_arg, crc32_arg ) |
   RTRIM( crc32_arg ) |
   SOUNDEX( crc32_arg ) |
   crc32_arg SOUNDS LIKE crc32_arg |
   SPACE( crc32_arg ) |
   SUBSTR( crc32_arg, crc32_arg ) | SUBSTR( crc32_arg FROM crc32_arg ) | SUBSTR( crc32_arg, crc32_arg, crc32_arg ) | SUBSTR( crc32_arg FROM crc32_arg FOR crc32_arg ) |
   SUBSTRING_INDEX( crc32_arg, crc32_arg, crc32_arg ) |
   TRIM( crc32_arg ) | TRIM( crc32_trim_mode FROM crc32_arg ) | TRIM( crc32_trim_mode crc32_arg FROM crc32_arg ) | TRIM( crc32_arg FROM crc32_arg ) |
   TO_CHAR( crc32_arg crc32_optional_to_char_fmt ) /* compatibility 10.6.1 */ |
   UCASE( crc32_arg ) |
   UNHEX( crc32_arg ) |
   UPPER( crc32_arg )
;

crc32_optional_to_char_fmt:
  | , crc32_to_char_fmt ;

crc32_to_char_fmt:
  { @fmt_elements=qw(YYYY YYY YY RRRR RR MM MON MONTH MI DD DY HH HH12 HH24 SS)
    ; $n= $prng->uint16(0,20)
    ; @special= (':','.','-','/',',',';',' ')
    ; $str= ''
    ; foreach (1..$n) { $str.= $prng->arrayElement(\@fmt_elements).$prng->arrayElement(\@special) }
    ; "'".$str."'"
  };

crc32_trim_mode:
   BOTH | LEADING | TRAILING ;

crc32_search_modifier:
   |
   IN NATURAL LANGUAGE MODE |
   IN NATURAL LANGUAGE MODE WITH QUERY EXPANSION |
   IN BOOLEAN MODE |
   WITH QUERY EXPANSION
;

crc32_date_func:
   ADD_MONTHS( crc32_arg, _smallint ) /* compatibility 10.6.1 */ |
   ADDDATE( crc32_arg, INTERVAL crc32_arg crc32_unit1 ) | ADDDATE( crc32_arg, crc32_arg ) |
   ADDTIME( crc32_arg, crc32_arg ) |
   CONVERT_TZ( crc32_arg, crc32_arg, crc32_arg ) |
   CURDATE() | CURRENT_DATE() | CURRENT_DATE |
   CURTIME() | CURRENT_TIME() | CURRENT_TIME |
   CURRENT_TIMESTAMP() | CURRENT_TIMESTAMP |
   DATE( crc32_arg ) |
   DATEDIFF( crc32_arg, crc32_arg ) |
   DATE_ADD( crc32_arg, INTERVAL crc32_arg crc32_unit1 ) | DATE_SUB( crc32_arg, INTERVAL crc32_arg crc32_unit1 ) |
   DATE_FORMAT( crc32_arg, crc32_arg ) |
   DAY( crc32_arg ) | DAYOFMONTH( crc32_arg ) |
   DAYNAME( crc32_arg ) |
   DAYOFWEEK( crc32_arg ) |
   DAYOFYEAR( crc32_arg ) |
   EXTRACT( crc32_unit1 FROM crc32_arg ) |
   FROM_DAYS( crc32_arg ) |
   FROM_UNIXTIME( crc32_arg ) | FROM_UNIXTIME( crc32_arg, crc32_arg ) |
   GET_FORMAT( crc32_get_format_type, crc32_get_format_format ) |
   HOUR( crc32_arg ) |
   LAST_DAY( crc32_arg ) |
   LOCALTIME() |
   LOCALTIMESTAMP() |
   MAKEDATE( crc32_arg, crc32_arg ) |
   MAKETIME( crc32_arg, crc32_arg, crc32_arg ) |
   MICROSECOND( crc32_arg ) |
   MINUTE( crc32_arg ) |
   MONTH( crc32_arg ) |
   MONTHNAME( crc32_arg ) |
   NOW() |
   PERIOD_ADD( crc32_arg, crc32_arg ) |
   PERIOD_DIFF( crc32_arg, crc32_arg ) |
   QUARTER( crc32_arg ) |
   SECOND( crc32_arg ) |
   SEC_TO_TIME( crc32_arg ) |
   STR_TO_DATE( crc32_arg, crc32_arg ) |
   SUBDATE( crc32_arg, crc32_arg ) |
   SUBTIME( crc32_arg, crc32_arg ) |
   SYSDATE() |
   # For ORACLE mode
   SYSDATE /* compatibility 10.6.1 */ |
   TIME( crc32_arg ) |
   TIMEDIFF( crc32_arg, crc32_arg ) |
   TIMESTAMP( crc32_arg ) | TIMESTAMP( crc32_arg, crc32_arg ) |
   TIMESTAMPADD( crc32_unit2, crc32_arg, crc32_arg ) |
   TIMESTAMPDIFF( crc32_unit2, crc32_arg, crc32_arg ) |
   TIME_FORMAT( crc32_arg, crc32_arg ) |
   TIME_TO_SEC( crc32_arg ) |
   TO_DAYS( crc32_arg ) |
   TO_SECONDS( crc32_arg ) |
   UNIX_TIMESTAMP( crc32_arg ) | UNIX_TIMESTAMP() |
   UTC_DATE() |
   UTC_TIME() |
   UTC_TIMESTAMP() |
   WEEK( crc32_arg ) | WEEK( crc32_arg, crc32_week_mode ) |
   WEEKDAY( crc32_arg ) |
   WEEKOFYEAR( crc32_arg ) |
   YEAR( crc32_arg ) |
   YEARWEEK( crc32_arg ) | YEARWEEK( crc32_arg, crc32_week_mode )
;

crc32_week_mode:
   0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | crc32_arg ;

crc32_get_format_type:
   DATE | TIME | DATETIME ;

crc32_get_format_format:
   'EUR' | 'USA' | 'JIS' | 'ISO' | 'INTERNAL' | crc32_arg ;

crc32_unit1:
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

crc32_unit2:
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

crc32_math_func:
   ABS( crc32_arg ) | ACOS( crc32_arg ) | ASIN( crc32_arg ) | ATAN( crc32_arg ) | ATAN( crc32_arg, crc32_arg ) | ATAN2( crc32_arg, crc32_arg ) |
   CEIL( crc32_arg ) | CEILING( crc32_arg ) | CONV( crc32_arg, _tinyint_unsigned, _tinyint_unsigned ) | COS( crc32_arg ) | COT( crc32_arg ) | CRC32( crc32_arg ) |
   ==FACTOR:100== /* compatibility 10.8.0 */ CRC32( crc32_arg, crc32_arg ) |
   ==FACTOR:100== /* compatibility 10.8.0 */ CRC32C( crc32_arg ) |
   ==FACTOR:100== /* compatibility 10.8.0 */ CRC32C( crc32_arg, crc32_arg ) |
   DEGREES( crc32_arg ) |
   EXP( crc32_arg ) |
   FLOOR( crc32_arg ) |
   FORMAT( crc32_arg, _digit ) | FORMAT( crc32_arg, crc32_format_second_arg, crc32_locale ) |
   HEX( crc32_arg ) |
   LN( crc32_arg ) | LOG( crc32_arg ) | LOG( crc32_arg, crc32_arg ) | LOG2( crc32_arg ) | LOG10( crc32_arg ) |
   MOD( crc32_arg, crc32_arg ) |
   PI( ) | POW( crc32_arg, crc32_arg ) | POWER( crc32_arg, crc32_arg ) |
   RADIANS( crc32_arg ) | RAND(_int_unsigned) | RAND( crc32_arg ) | ROUND( crc32_arg ) | ROUND( crc32_arg, crc32_arg ) |
   SIGN( crc32_arg ) | SIN( crc32_arg ) | SQRT( crc32_arg ) |
   TAN( crc32_arg ) | TRUNCATE( crc32_arg, crc32_truncate_second_arg ) ;

crc32_arithm_oper:
   crc32_arg + crc32_arg |
   crc32_arg - crc32_arg |
   - crc32_arg |
   crc32_arg * crc32_arg |
   crc32_arg / crc32_arg |
   crc32_arg DIV crc32_arg |
   crc32_arg MOD crc32_arg |
   crc32_arg % crc32_arg
;

crc32_logical_or_bitwise_oper:
   NOT crc32_arg | ! crc32_arg | ~ crc32_arg |
   crc32_arg AND crc32_arg | crc32_arg && crc32_arg | crc32_arg & crc32_arg |
   crc32_arg OR crc32_arg | crc32_arg | crc32_arg |
   crc32_arg XOR crc32_arg | crc32_arg ^ crc32_arg |
   crc32_arg << crc32_arg | crc32_arg >> crc32_arg
;

crc32_assign_oper:
   @A := crc32_arg ;

crc32_comparison_oper:
   crc32_arg = crc32_arg |
   crc32_arg <=> crc32_arg |
   crc32_arg != crc32_arg |
   crc32_arg <> crc32_arg |
   crc32_arg <= crc32_arg |
   crc32_arg < crc32_arg |
   crc32_arg >= crc32_arg |
   crc32_arg > crc32_arg |
   crc32_arg IS _basics_not_33pct crc32_bool_value |
   crc32_arg _basics_not_33pct BETWEEN crc32_arg AND crc32_arg |
   COALESCE( crc32_arg_list ) |
   GREATEST( crc32_arg_list ) |
   crc32_arg _basics_not_33pct IN ( crc32_arg_list ) |
   ISNULL( crc32_arg ) |
   INTERVAL( crc32_arg_list ) |
   LEAST( crc32_arg_list ) |
   crc32_arg _basics_not_33pct LIKE crc32_arg |
   STRCMP( crc32_arg, crc32_arg )
;

crc32_arg_list:
   crc32_arg_list_2 | crc32_arg_list_3 | crc32_arg_list_5 | crc32_arg_list_10 | crc32_arg, crc32_arg_list ;

crc32_arg_list_2:
   crc32_arg, crc32_arg ;

crc32_arg_list_3:
   crc32_arg, crc32_arg, crc32_arg ;

crc32_arg_list_5:
   crc32_arg, crc32_arg, crc32_arg, crc32_arg, crc32_arg ;

crc32_arg_list_10:
   crc32_arg, crc32_arg, crc32_arg, crc32_arg, crc32_arg, crc32_arg, crc32_arg, crc32_arg, crc32_arg, crc32_arg ;


crc32_field_list:
   _field | crc32_field_list , _field ;

crc32_format_second_arg:
   crc32_truncate_second_arg ;

crc32_truncate_second_arg:
   _digit | _digit | _tinyint_unsigned | crc32_arg ;

crc32_arg:
   _field | crc32_value | ( crc32_func ) ;

crc32_arg_char:
  _field_char | _char(1) | _english | _string(16) | NULL
;

crc32_const_char_value:
  _char(1) | _english | _string(16) | ''
;

crc32_value:
   _bigint | _smallint | _int_unsigned | _char(1) | _char(256) | _datetime | _date | _time | NULL ;

crc32_bool_value:
   TRUE | FALSE | UNKNOWN | NULL ;

crc32_locale:
   'en_US' | 'de_DE' ;

