# Copyright (c) 2003, 2012, Oracle and/or its affiliates. All rights reserved.
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
#
##########################################################################
# This include file contains rules common for (at least)
# partition_by_hash.yy and partition_by_range.yy.
# The grammars don't rely on the predefined tables, but use
# tables defined in init instead.
##########################################################################

#features Aria tables

init_db:
  init_5 ;; init_5 ;;

init_5:
  init_table ;; init_table ;; init_table ;; init_table ;; init_table ;

init_table:
  create ;; insert_part ;; cache_index ;; load_index ;

insert_part:
  INSERT INTO { $new_table or '_basetable' } ( `col_int_nokey`, `col_int_key` ) VALUES insert_part_vals ;

insert_part_vals:
  insert_part_vals_5 , insert_part_vals_5 , insert_part_vals_5 , 
  insert_part_vals_5 , insert_part_vals_5 , insert_part_vals_5 ;

insert_part_vals_5:
  ( value , value ) , ( value , value ) , ( value , value ) , ( value , value ) , ( value , value );

##########################################################################
# Randomly executed SQL

query:
  { $new_table= ''; _set_db('partition_db') } exec_sql ;

exec_sql:
  select_explain |
  select | select | select | select | select | select                   |
  select | select | select | select | select | select                   |
  select | select | select | select | select | select                   |
  insert | update | delete | insert | update                            |
  insert | update | delete | insert | update                            |
  alter | alter | alter | alter | alter | alter                         |
  alter | alter | alter | alter | alter | alter                         |
  cache_index | load_index                                              |
  create_sel | create_sel | create_sel | create_sel | create_sel        |
  drop_create                                                           |
  set_key_buffer_size | set_key_cache_block_size                        ;

cache_index:
  CACHE INDEX { $new_table or '_basetable' } IN cache_name                                                |
  CACHE INDEX { $new_table or '_basetable' }  PARTITION ( ALL ) IN cache_name                 |
  CACHE INDEX { $new_table or '_basetable' }  PARTITION ( partition_name_list ) IN cache_name ;

load_index:
  LOAD INDEX INTO CACHE { $new_table or '_basetable' } ignore_leaves                                               |
  LOAD INDEX INTO CACHE { $new_table or '_basetable' } PARTITION ( ALL ) ignore_leaves                 |
  LOAD INDEX INTO CACHE { $new_table or '_basetable' } PARTITION ( partition_name_list ) ignore_leaves ;

ignore_leaves:
  | IGNORE LEAVES ;

set_key_buffer_size:
  SET GLOBAL cache_name.key_buffer_size = _tinyint_unsigned |
  SET GLOBAL cache_name.key_buffer_size = _smallint_unsigned |
  SET GLOBAL cache_name.key_buffer_size = _mediumint_unsigned ;

set_key_cache_block_size:
  SET GLOBAL cache_name.key_cache_block_size = key_cache_block_size_enum;

key_cache_block_size_enum:
  512 | 1024 | 2048 | 4096 | 8192 | 16384 ;

cache_name:
  c1 | c2 | c3 | c4;

select_explain:
  EXPLAIN PARTITIONS SELECT part_field FROM _table where ;

create_select:
  SELECT `col_int_nokey` MOD 10 AS `col_int_nokey` , `col_int_key` MOD 10 AS `col_int_key` FROM _table where ;

select:
  SELECT `col_int_nokey` MOD 10 AS `col_int_nokey` , `col_int_key` MOD 10 AS `col_int_key` FROM dml_table_name where ;

# WHERE clauses suitable for partition pruning
where:
  |                                      |
  WHERE part_field comparison_operator value |
  WHERE part_field BETWEEN value AND value   ;

comparison_operator:
        > | < | = | <> | != | >= | <= ;

insert:
        insert_replace INTO dml_table_name ( `col_int_nokey`, `col_int_key` ) VALUES ( value , value ) , ( value , value )                     |
        insert_replace INTO dml_table_name ( `col_int_nokey`, `col_int_key` ) select ORDER BY `col_int_key` , `col_int_nokey` LIMIT limit_rows ;

insert_replace:
        INSERT | REPLACE ;

update:
        UPDATE dml_table_name SET part_field = value WHERE part_field = value ;

delete:
        DELETE FROM dml_table_name WHERE part_field = value ORDER BY `col_int_key` , `col_int_nokey` LIMIT limit_rows ;

value:
  _digit ;

part_field:
        `col_int_nokey` | `col_int_nokey` ;

create_sel:
        create_part_invar ;

create_part_invar:
  CREATE TABLE if_not_exists _table[invariant] (
    `col_int_nokey` INTEGER,
    `col_int_key` INTEGER NOT NULL,
    KEY (`col_int_key`)
  ) engine_clause partition create_select ;

drop_create:
  DROP TABLE if_exists _table[invariant] ;; create_part_invar ;

alter:
  ==FACTOR:20== ALTER TABLE _table alter_operation |
                alter_exchange |
                alter_convert_to /* compatibility 10.7.1,es-10.6 */ |
                alter_convert_from /* compatibility 10.7.1,es-10.6 */
;

alter_exchange:
     CREATE OR REPLACE TABLE tp_exchange LIKE _table[invariant]
  ;; ALTER TABLE tp_exchange REMOVE PARTITIONING
  ;; ALTER TABLE _table[invariant] EXCHANGE PARTITION partition_name WITH TABLE tp_exchange
;

alter_convert_to:
     DROP TABLE IF EXISTS tp_exchange
  ;; ALTER TABLE _table CONVERT PARTITION partition_name TO TABLE tp_exchange
;

alter_convert_from:
  ALTER TABLE _table CONVERT TABLE tp_exchange TO PARTITION partition_name VALUES LESS THAN MAXVALUE
;

alter_operation:
  partition                                                           |
  enable_disable KEYS                                                 |
  ADD PARTITION (PARTITION partition_name VALUES LESS THAN MAXVALUE)  |
  ADD PARTITION (PARTITION p125 VALUES LESS THAN MAXVALUE)            |
  DROP PARTITION partition_name                                       |
  COALESCE PARTITION one_two                                          |
  ANALYZE PARTITION partition_name_list                               |
  CHECK PARTITION partition_name_list                                 |
  REBUILD PARTITION partition_name_list                               |
  REPAIR PARTITION partition_name_list                                |
  REMOVE PARTITIONING                                                 |
  OPTIMIZE PARTITION partition_name_list                              |
  ENGINE = engine                                                     |
  ORDER BY part_field                                                 |
  TRUNCATE PARTITION partition_name_list    # can not be used in comparison tests against 5.0
;

subpartition:
  |
  SUBPARTITION BY linear HASH ( part_field ) SUBPARTITIONS partition_count ;

linear:
  | LINEAR;

one_two:
  1 | 2;

enable_disable:
  ENABLE | DISABLE ;

engine_clause:
  ==FACTOR:5== |
  ENGINE = engine ;

engine:
  MYISAM | ARIA | INNODB | MEMORY;

partition_count:
  1 | 2 | 3 | 3 | 3 | 4 | 4 | 4 | 4 ;

limit_rows:
  1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 ;

if_exists:
  IF EXISTS ;

if_not_exists:
  IF NOT EXISTS ;
