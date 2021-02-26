# Copyright (C) 2017, 2021 MariaDB Corporation Ab.
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

####################################
# Reference material
# https://www.json.org/json-en.html
# https://www.crockford.com/mckeeman.html
####################################

query_init_add:
    SET SQL_MODE=REPLACE(REPLACE(@@sql_mode,'STRICT_TRANS_TABLES',''),'STRICT_ALL_TABLES','')
  ; json_create
  ; SET SQL_MODE=DEFAULT
;

query_add:
  json_select | json_insert | json_delete | json_update |
  ==FACTOR:0.1== json_create |
  ==FACTOR:0.1== json_alter
;

json_create:
    SET SQL_MODE=REPLACE(REPLACE(@@sql_mode,'STRICT_TRANS_TABLES',''),'STRICT_ALL_TABLES','')
  ; CREATE OR REPLACE TABLE `tmp` ENGINE = _basics_inbuilt_engine_weighted AS json_select
  ; SET SQL_MODE=DEFAULT
;

json_insert:
    SET SQL_MODE=REPLACE(REPLACE(@@sql_mode,'STRICT_TRANS_TABLES',''),'STRICT_ALL_TABLES','')
  ; INSERT INTO `tmp` ( `fld` ) json_select
  ; SET SQL_MODE=DEFAULT
;

# TODO: vcols
json_alter:
	  ALTER TABLE `tmp` ADD json_index_type INDEX ( json_key_field json_key_length )
	| ALTER TABLE `tmp` DROP INDEX json_key_field
#	| ==FACTOR:0.05== ALTER TABLE `tmp` json_column_op `vfld` TEXT AS ( json_vcol_expression ) json_virt_persist
	| ALTER TABLE `tmp` MODIFY `fld` json_fld_type
;

json_vcol_expression:
	json_func | `fld` | SUBSTR(`fld`,1,1024)
;

json_fld_type:
	TEXT | BLOB | MEDIUMTEXT | VARCHAR(2048) | JSON
;

json_key_field:
	`fld` | `fld` | `fld` | `vfld`
;

json_key_length:
	| (_smallint_unsigned)
;

json_virt_persist:
	VIRTUAL | PERSISTENT
;

json_column_op:
	ADD IF NOT EXISTS | MODIFY
;

json_index_type:
	| | | | | | UNIQUE | FULLTEXT
;

json_delete:
  DELETE FROM { $json_table_field= 'fld'; 'tmp' } json_where LIMIT 1
;

json_update:
    SET SQL_MODE=REPLACE(REPLACE(@@sql_mode,'STRICT_TRANS_TABLES',''),'STRICT_ALL_TABLES','')
  ; UPDATE `tmp` SET { $json_table_field= 'fld' } = json_func_returning_json ORDER BY fld LIMIT _digit
  ; SET SQL_MODE=DEFAULT
;

json_select:
  /* _table _field { $json_table_field = $last_field } */ SELECT json_select_item AS fld FROM { $last_table } json_where LIMIT _digit
;

json_select_item:
    ==FACTOR:20== json_func
  | GROUP_CONCAT(json_func)
  | MIN(json_func)
  | MAX(json_func)
;

json_where:
  | | | |
  | WHERE json_text_arg _basics_comparison_operator json_text_arg
  | WHERE json_func_other _basics_comparison_operator json_func_other
;

json_text_arg:
  _json |
  json_func_returning_json |
  ==FACTOR:0.1== { $json_table_field }
;

json_func_returning_json:
    JSON_ARRAY( json_value_list )
  | JSON_ARRAYAGG( json_any_value ) /* compatibility 10.5.0 */
  | JSON_ARRAY_APPEND( json_text_arg, json_path_val_list_no_wildcard )
  | JSON_ARRAY_INSERT( json_text_arg, json_path_val_list_no_wildcard )
  | JSON_COMPACT( json_text_arg )
  | JSON_DETAILED( json_text_arg )
  # MDEV-24585: Assertion failure when the argument produced by a function
  # | JSON_INSERT( json_text_arg, json_path_val_list_no_wildcard )
  | JSON_INSERT( _json, json_path_val_list_no_wildcard )
  | JSON_KEYS( json_text_arg json_optional_path_no_wildcard )
  | JSON_LOOSE( json_text_arg )
  | JSON_MERGE( json_text_arg, json_doc_list )
  | JSON_MERGE_PATCH( json_text_arg, json_doc_list ) /* compatibility 10.2.25 */
  | JSON_MERGE_PRESERVE( json_text_arg, json_doc_list ) /* compatibility 10.2.25 */
  | JSON_OBJECT( json_key_value_list )
  | JSON_OBJECTAGG( _jsonkey, json_valid_arg ) /* compatibility 10.5.0 */
  | JSON_QUERY( json_text_arg, _jsonpath )
  | JSON_REMOVE( json_text_arg, json_remove_path_list )
  # MDEV-24585: Assertion failure when the argument produced by a function
  # | JSON_REPLACE( json_text_arg, json_path_val_list_no_wildcard )
  | JSON_REPLACE( _json, json_path_val_list_no_wildcard )
  # MDEV-24585: Assertion failure when the argument produced by a function
  # | JSON_SET( json_text_arg, json_path_val_list_no_wildcard )
  | JSON_SET( _json, json_path_val_list_no_wildcard )
;

json_func:
  ==FACTOR:2== json_func_returning_json
  |            json_func_other
;

json_func_other:
	  JSON_CONTAINS( json_text_arg, json_contains_args )
	| JSON_CONTAINS_PATH( json_text_arg, json_one_or_all, json_path_list_no_wildcard )
	| JSON_DEPTH( json_text_arg )
	| JSON_EXISTS( json_text_arg, _jsonpath )
	| JSON_EXTRACT( json_text_arg, json_path_list )
	| JSON_LENGTH( json_text_arg json_optional_path_no_wildcard )
	| JSON_QUOTE( _json )
	| JSON_SEARCH( json_text_arg, json_one_or_all, json_search_string json_search_args )
	| JSON_TYPE( _json )
	| JSON_UNQUOTE( _json )
	| JSON_VALID( json_valid_arg )
	| JSON_VALUE( json_text_arg, _jsonpath )
;

json_optional_path_no_wildcard:
	| , _jsonpath_no_wildcard
;

json_value_list:
  _json | _json, json_value_list ;

json_valid_arg:
	json_text_arg | _json | _jsonkey | _jsonpath | { $last_json_field or 'fld' }
;

json_search_string:
	_english | _char(2) | _digit | '' | NULL | `fld`
;

json_search_args:
	| , json_escape_char | , json_escape_char, _jsonpath | , json_escape_char, _jsonpath json_search_args
;

json_one_or_all:
	'one' | 'all'
;

json_key_value_list:
	==FACTOR:3== _jsonkey, _json |
  _jsonkey, _json, json_key_value_list
;

json_doc_list:
	==FACTOR:3== json_text_arg |
  json_text_arg, json_doc_list
;

json_optional_path_list:
	| , json_path_list
;

json_optional_path_list_no_wildcard:
	| , json_path_list_no_wildcard
;

# Path '$' is not allowed in JSON_REMOVE
json_remove_path_item:
  _jsonpath_no_wildcard(1) |
  _jsonpath_no_wildcard(2) |
  _jsonpath_no_wildcard(3) |
  _jsonpath_no_wildcard(4)
;

json_remove_path_list:
  ==FACTOR:3== json_remove_path_item |
  json_remove_path_item, json_remove_path_list
;

json_path_list_no_wildcard:
  ==FACTOR:3== _jsonpath_no_wildcard |
  _jsonpath_no_wildcard, json_path_list_no_wildcard
;

json_path_list:
	==FACTOR:3== _jsonpath |
  _jsonpath, json_path_list
;

json_contains_args:
	_json | _json, _jsonpath_no_wildcard
;

json_path_val_list_no_wildcard:
  ==FACTOR:3== _jsonpath_no_wildcard, _json |
  json_path_val_list_no_wildcard, _jsonpath_no_wildcard, _json
;

json_path_val_list:
	==FACTOR:3== _jsonpath, _json |
  json_path_val_list, _jsonpath, _json
;

json_escape_char:
	NULL | '\\' | "'" | '"' | '/' | '%' | _char(1)
;

json_any_value:
  _basics_any_value | `fld` | _field | _json ;
