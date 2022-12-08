# Copyright (c) 2010, 2012, Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2022, MariaDB
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

########################################################################
# The goal of this grammar is to stress test the operation of the HEAP storage engine by:
#
# * Creating numerous tables, populating them rapidly and then dropping them
#
# * Using various DDL statements that cause HEAP tables to be created or manipulated
#
# * Have concurrent operation by using mostly TEMPORARY or connection-specific tables
########################################################################

query_init:
  SET ROLE admin
  ;; CREATE DATABASE IF NOT EXISTS test
  ;; GRANT ALL ON test.* TO CURRENT_USER
  ;; SET ROLE NONE
  ;; { _set_db('test') }
     { $table_name = 'local_'.$generator->threadId().'_1' ; '' } create_definition_init
  ;; { $table_name = 'local_'.$generator->threadId().'_2' ; '' } create_definition_init
  ;; { $table_name = 'local_'.$generator->threadId().'_3' ; '' } create_definition_init 
  ;; { $table_name = 'local_'.$generator->threadId().'_4' ; '' } create_definition_init 
  ;; { $table_name = 'local_'.$generator->threadId().'_5' ; '' } create_definition_init 
  ;; { $table_name = 'global_1' ; '' } create_definition_init
  ;; { $table_name = 'global_2' ; '' } create_definition_init
  ;; { $table_name = 'global_3' ; '' } create_definition_init 
  ;; { $table_name = 'global_4' ; '' } create_definition_init 
  ;; { $table_name = 'global_5' ; '' } create_definition_init 
;

create_definition_init:
  create_definition IGNORE SELECT short_value  AS f1 , short_value AS f2 , short_value AS f3 , short_value AS f4 , short_value AS f5 FROM DUAL ;

query:
  { _set_db('test') } engine_heap_ddl_query ;

engine_heap_ddl_query:
  ==FACTOR:3== set_table_name create |
  create_drop |
  select | insert | update | delete |
  alter |
  truncate ;

create_drop:
  set_table_name DROP TABLE IF EXISTS { $table_name } ;; create ;

create:
  create_definition |
  create_definition select_all
;

alter:
  ALTER TABLE table_name ENGINE = HEAP |
  ALTER TABLE table_name enable_disable KEYS ;

enable_disable:
  ENABLE | DISABLE ;

truncate:
  TRUNCATE TABLE table_name ;

select_all:
  SELECT * FROM table_name ;

create_command:
  CREATE __temporary(10) TABLE IF NOT EXISTS |
  CREATE OR REPLACE __temporary(10) TABLE ;

create_definition:
  create_command { $table_name } (
    f1 column_def_index ,
    f2 column_def_index ,
    f3 column_def ,
    f4 column_def ,
    f5 column_def ,
    index_definition_list
  ) ENGINE=HEAP /*executor1 ROW_FORMAT = __dynamic_x_fixed(90) KEY_BLOCK_SIZE = __512_x_1024_x_2048_x_3072 */ ;

insert:
  insert_multi | insert_multi | insert_select ;

insert_multi:
  __insert_ignore_x_replace(80) INTO table_name VALUES row_list ;

insert_select:
  __insert_ignore_x_replace(80) INTO table_name select_all;

row_list:
  row , row , row , row |
  row_list , row ;

row:
  ( value , value , value , value , value ) ;

index_definition_list:
  index_definition |
  index_definition , index_definition ;

index_definition:
  index_type ( index_column_list ) USING btree_hash ;

btree_hash:
# Disabled due to MDEV-371 issues
#    HASH |
  BTREE ;

index_type:
  ==FACTOR:10== KEY |
  PRIMARY KEY ;

index_column_list:
  f1 | f2 | f1 , f2 | f2 , f1 |
  f1 ( __1_x_2_x_32 ) | f2 ( __1_x_2_x_32 ) |
  f1 ( __1_x_2_x_32 ) , f2 ( __1_x_2_x_32 ) |
  f2 ( __1_x_2_x_32 ) , f1 ( __1_x_2_x_32 ) ;

column_def:
  VARCHAR ( __32_x_128_x_512_x_1024 ) character_set __not_null(20) default |
  VARCHAR ( __32_x_128_x_512_x_1024 ) collation __not_null(20) default |
  VARBINARY ( __32_x_128_x_512_x_1024 ) ;

character_set:
  | CHARACTER SET utf8 ;

collation:
  | COLLATE utf8_bin ;

column_def_index:
  VARCHAR ( __32_x_128 ) character_set __not_null(20) default |
  VARCHAR ( __32_x_128 ) collation __not_null(20) default ;

default:
  | DEFAULT _varchar(32) ;

table_name:
  connection_specific_table |
  connection_specific_table |
  connection_specific_table |
  connection_specific_table |
  connection_specific_table |
  global_table ;

connection_specific_table:
  { 'local_'.$generator->threadId().'_'.$prng->int(1,5) } ;

global_table:
  global_1 | global_2 | global_3 | global_4 | global_5 ;

set_table_name:
  { $table_name = $prng->int(1,5) <= 4 ? 'local_'.$generator->threadId().'_'.$prng->int(1,5) : 'global_'.$prng->int(1,5) ; '' } ;

value_list:
  value , value |
  value , value_list ;

value:
  short_value | long_value ;

short_value:
  _digit | _varchar(1) | NULL | _english ;

long_value:
  REPEAT( _varchar(128) , _digit ) | NULL | _data ;

select:
  SELECT field_name FROM table_name WHERE where order_by ;

order_by:
  ORDER BY field_name __desc_x_asc ;

update:
  UPDATE table_name SET field_name = value WHERE where ;

delete:
  DELETE FROM table_name WHERE where ;

field_name:
  f1 | f2 | f3 | f4 | f5 ;

where:
  (field_name cmp_op value ) __and_x_or where |
  field_name cmp_op value |
  field_name __not(50) IN ( value_list ) |
  field_name BETWEEN value AND value ;

cmp_op:
  < | > | = | <= | >= | <> | <=> | != ;
