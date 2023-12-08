# Copyright (C) 2017, 2022 MariaDB Corporation Ab.
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

#include <conf/yy/include/basics.inc>
#features Aria tables

query_init:
  { _set_db('NON-SYSTEM') } create ;

query:
                  { _set_db('ANY') } dml |
  ==FACTOR:0.01== { _set_db('ANY') } ddl ;

dml:
  select | insert | update | delete ;

ddl:
  create | alter ;

create:
    SET SQL_MODE=REPLACE(REPLACE(@@SQL_MODE,'STRICT_TRANS_TABLES',''),'STRICT_ALL_TABLES','')
  ;; CREATE OR REPLACE TABLE test.`tmp` ENGINE = inbuilt_engine AS select
  ;; SET SQL_MODE=DEFAULT
;

inbuilt_engine:
  ==FACTOR:8== InnoDB |
  ==FACTOR:5== Aria   |
  ==FACTOR:4== MyISAM |
  ==FACTOR:2== HEAP   |
  ==FACTOR:1== CSV
;

insert:
    SET SQL_MODE=REPLACE(REPLACE(@@SQL_MODE,'STRICT_TRANS_TABLES',''),'STRICT_ALL_TABLES','')
  ;; INSERT INTO test.`tmp` ( `fld` ) select
  ;; SET SQL_MODE=DEFAULT
;

# TODO: vcols - adjust probabilities when virtual columns start working
alter:
    ALTER TABLE test.`tmp` ADD index_type INDEX ( key_field key_length )
  | ALTER TABLE test.`tmp` DROP INDEX key_field
  | ==FACTOR:0.01== ALTER TABLE test.`tmp` column_op `vfld` TEXT AS ( vcol_expression ) virt_persist opt_col_check
  | ALTER TABLE test.`tmp` MODIFY `fld` fld_type opt_col_check
;

opt_col_check:
  ==FACTOR:10== |
  CHECK(func) ;

vcol_expression:
  func | `fld` | SUBSTR(`fld`,1,1024)
;

fld_type:
  TEXT | BLOB | MEDIUMTEXT | VARCHAR(2048) | JSON
;

key_field:
  `fld` | `fld` | `fld` | `vfld`
;

key_length:
  | (_smallint_unsigned)
;

virt_persist:
  VIRTUAL | PERSISTENT
;

column_op:
  ADD IF NOT EXISTS | MODIFY
;

index_type:
  | | | | | | UNIQUE | FULLTEXT
;

delete:
  DELETE FROM { $json_table_field= 'fld'; 'test.tmp' } where LIMIT 1
;

update:
    SET SQL_MODE=REPLACE(REPLACE(@@SQL_MODE,'STRICT_TRANS_TABLES',''),'STRICT_ALL_TABLES','')
  ;; UPDATE test.`tmp` SET { $json_table_field= 'fld' } = func_returning_json ORDER BY fld LIMIT _digit
  ;; SET SQL_MODE=DEFAULT
;

select:
  ==FACTOR:3== /* _table[invariant] _field { $json_table_field = $last_field } */ SELECT select_item AS fld FROM _table[invariant] where LIMIT _digit |
  SELECT { $col= $prng->uint16(1,20); $json_table_field = 'col'.$col; '' } select_item FROM { $prng->jsonTable($prng->uint16($col,25)) } /* compatibility 10.6.0 */
;

select_item:
    ==FACTOR:20== func
  | GROUP_CONCAT(func)
  | MIN(func)
  | MAX(func)
;

where:
  | | | |
  | WHERE text_arg _basics_comparison_operator text_arg
  | WHERE func_other _basics_comparison_operator func_other
;

text_arg:
  _json |
  func_returning_json |
  ==FACTOR:0.1== { $json_table_field }
;

func_returning_json:
    JSON_ARRAY( value_list )
  | JSON_ARRAYAGG( any_value ) /* compatibility 10.5.0 */
  | JSON_ARRAY_APPEND( text_arg, path_val_list_no_wildcard )
  | JSON_ARRAY_INSERT( text_arg, path_val_list_no_wildcard )
  | JSON_COMPACT( text_arg )
  | JSON_DETAILED( text_arg )
  | JSON_INSERT( text_arg, path_val_list_no_wildcard )
  | JSON_INSERT( _json, path_val_list_no_wildcard )
  | JSON_KEYS( text_arg optional_path_no_wildcard )
  | JSON_LOOSE( text_arg )
  | JSON_MERGE( text_arg, doc_list )
  | JSON_MERGE_PATCH( text_arg, doc_list )
  | JSON_MERGE_PRESERVE( text_arg, doc_list )
  | JSON_NORMALIZE( text_arg ) /* compatibililty 10.7.0,es-10.4 */
  | JSON_OBJECT( key_value_list )
  | JSON_OBJECTAGG( _jsonkey, valid_arg ) /* compatibility 10.5.0 */
  | JSON_QUERY( text_arg, _jsonpath )
  | JSON_REMOVE( text_arg, remove_path_list )
  | JSON_REPLACE( text_arg, path_val_list_no_wildcard )
  | JSON_REPLACE( _json, path_val_list_no_wildcard )
  | JSON_SET( text_arg, path_val_list_no_wildcard )
  | JSON_SET( _json, path_val_list_no_wildcard )
;

func:
  ==FACTOR:2== func_returning_json
  |            func_other
;

func_other:
    JSON_CONTAINS( text_arg, contains_args )
  | JSON_CONTAINS_PATH( text_arg, one_or_all, path_list_no_wildcard )
  | JSON_DEPTH( text_arg )
  | JSON_EQUALS( text_arg, text_arg ) /* compatibility 10.7.0,es-10.4 */
  | JSON_EXISTS( text_arg, _jsonpath )
  | JSON_EXTRACT( text_arg, path_list )
  | JSON_LENGTH( text_arg json_optional_path_no_wildcard )
  | JSON_OVERLAPS( text_arg, text_arg ) /* compatibility 10.9.1,es-10.4 */
  | JSON_QUOTE( _json )
  | JSON_SCHEMA_VALID( _json, _json ) /* compatibility 11.1,es-10.4 */
  | JSON_SEARCH( text_arg, one_or_all, search_string search_args )
  | JSON_TYPE( _json )
  | JSON_UNQUOTE( _json )
  | JSON_VALID( valid_arg )
  | JSON_VALUE( text_arg, _jsonpath )
;

optional_path_no_wildcard:
  | , _jsonpath_no_wildcard
;

value_list:
  _json | _json, value_list ;

valid_arg:
  text_arg | _json | _jsonkey | _jsonpath | { $json_table_field or 'fld' }
;

search_string:
  _english | _char(2) | _digit | '' | NULL | `fld`
;

search_args:
  | , escape_char | , escape_char, _jsonpath | , escape_char, _jsonpath search_args
;

one_or_all:
  'one' | 'all'
;

key_value_list:
  ==FACTOR:3== _jsonkey, _json |
  _jsonkey, _json, key_value_list
;

doc_list:
  ==FACTOR:3== text_arg |
  text_arg, doc_list
;

# Path '$' is not allowed in JSON_REMOVE
remove_path_item:
  _jsonpath_no_wildcard(1) |
  _jsonpath_no_wildcard(2) |
  _jsonpath_no_wildcard(3) |
  _jsonpath_no_wildcard(4)
;

remove_path_list:
  ==FACTOR:3== remove_path_item |
  remove_path_item, remove_path_list
;

path_list_no_wildcard:
  ==FACTOR:3== _jsonpath_no_wildcard |
  _jsonpath_no_wildcard, path_list_no_wildcard
;

path_list:
  ==FACTOR:3== _jsonpath |
  _jsonpath, path_list
;

contains_args:
  _json | _json, _jsonpath_no_wildcard
;

path_val_list_no_wildcard:
  ==FACTOR:3== _jsonpath_no_wildcard, _json |
  path_val_list_no_wildcard, _jsonpath_no_wildcard, _json
;

path_val_list:
  ==FACTOR:3== _jsonpath, _json |
  path_val_list, _jsonpath, _json
;

escape_char:
  NULL | '\\' | "'" | '"' | '/' | '%' | _char(1)
;

any_value:
  _basics_any_value | `fld` | { $json_table_field or '_field' } | _json ;
