# Copyright (C) 2017 MariaDB Corporation.
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

# Rough imitation of OLTP-read-write test (sysbench-like)


query:
	select | insert | delete | update |
	select | insert | delete | update |
	select | insert | delete | update |
	select | insert | delete | update |
	select | insert | delete | update |
	select | insert | delete | update |
	select | insert | delete | update |
	select | insert | delete | update |
	select | insert | delete | update |
	select | insert | delete | update |
	create | alter
;

create:
	CREATE OR REPLACE TABLE `tmp` ENGINE=engine AS select
;

engine:
	MyISAM | InnoDB | MEMORY
;

insert:
	INSERT INTO `tmp` ( `fld` ) select
;

alter:
	  ALTER TABLE `tmp` ADD index_type INDEX ( key_field_key_length )
	| ALTER TABLE `tmp` DROP INDEX key_field
	| ALTER TABLE `tmp` column_op `vfld` TEXT AS ( vcol_expression ) virt_persist
	| ALTER TABLE `tmp` MODIFY `fld` fld_type
;

vcol_expression:
	json_func | `fld` | SUBSTR(`fld`,1,1024)
;

fld_type:
	TEXT | BLOB | MEDIUMTEXT | VARCHAR(2048)
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
	DELETE FROM `tmp` WHERE `fld` = json_func LIMIT 1
;

update:
	UPDATE `tmp` SET `fld` = json_func
;

select:
	{ $from_clause = '' } SELECT json_func  AS `fld` { $from_clause } LIMIT _digit
;

json_text_arg:
	_json | `fld` { $from_clause = 'FROM `tmp` '; '' } | `vfld` { $from_clause = 'FROM `tmp` '; '' }
;

json_func:
	  JSON_ARRAY_APPEND( json_text_arg, json_path_val_list )
	| JSON_ARRAY_INSERT( json_text_arg, json_path_val_list )
	| JSON_COMPACT( json_text_arg )
	| JSON_CONTAINS( json_text_arg, json_contains_args )
	| JSON_CONTAINS_PATH( json_text_arg, one_or_all, json_path_list )
	| JSON_DEPTH( json_text_arg )
	| JSON_EXISTS( json_text_arg, _jsonpath )
	| JSON_EXTRACT( json_text_arg, json_path_list )
	| JSON_INSERT( json_text_arg, json_path_val_list )
	| JSON_KEYS( json_text_arg json_optional_path )
	| JSON_LENGTH( json_text_arg json_optional_path_list )
	| JSON_MERGE( json_text_arg, json_doc_list )
	| JSON_OBJECT( json_key_value_list )
	| JSON_QUERY( json_text_arg, _jsonpath )
	| JSON_QUOTE( _jsonvalue )
	| JSON_REMOVE( json_text_arg, json_path_list )
	| JSON_REPLACE( json_text_arg, json_path_val_list )
	| JSON_SEARCH( json_text_arg, one_or_all, json_search_string json_search_args )
	| JSON_SET( json_text_arg, json_path_val_list )
	| JSON_TYPE( _jsonvalue )
	| JSON_UNQUOTE( _jsonvalue )
	| JSON_VALID( json_valid_arg )
	| JSON_VALUE( json_text_arg, _jsonpath )
;

json_optional_path:
	| , _jsonpath
;

json_valid_arg:
	json_text_arg | _jsonvalue | _jsonkey | _jsonpair | _jsonarray | _jsonpath | `fld`
;

json_search_string:
	_english | _char(2) | _digit | '' | NULL | `fld`
;

json_search_args:
	| , json_escape_char | , json_escape_char, _jsonpath | , json_escape_char, _jsonpath json_search_args
;

one_or_all:
	'one' | 'all'
;

json_key_value_list:
	_jsonkey, _jsonvalue | _jsonkey, _jsonvalue, json_key_value_list
;

json_doc_list:
	json_text_arg | json_text_arg, json_doc_list
;

json_optional_path_list:
	| , json_path_list
;

json_path_list:
	_jsonpath | _jsonpath, json_path_list
;

json_contains_args:
	_jsonvalue | _jsonvalue, _jsonpath
;

json_path_val_list:
	_jsonpath, _jsonvalue | json_path_val_list, _jsonpath, _jsonvalue
;

json_escape_char:
	NULL | '\\' | "'" | '"' | '/' | '%' | _char(1)
;

