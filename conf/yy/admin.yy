#  Copyright (c) 2018, 2022, MariaDB Corporation Ab
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; version 2 of the License.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA */

#features Aria tables, RocksDB tables

query:
  ==FACTOR:10== { _set_db('ANY') } SET ROLE admin ;; admin_query |
  { _set_db('ANY') } SET ROLE NONE ;; admin_query
;

optional_wait:
  ==FACTOR:3== |
  WAIT _digit |
  NOWAIT
;

table_list:
  _basetable | table_list, _basetable
;

admin_query:
    admin_analyze_or_explain_query
  | admin_flush
  | ==FACTOR:10== admin_query_table_maint
  | admin_show
  | ==FACTOR:0.01== admin_cache_index
;

admin_query_table_maint:
# MDEV-33462 and some already fixed but not merged bug
#  OPTIMIZE admin_no_write_or_local TABLE table_list optional_wait |
  OPTIMIZE admin_no_write_or_local TABLE _basetable optional_wait |
  CHECK TABLE table_list check_option_list |
  REPAIR admin_no_write_or_local TABLE table_list repair_option_list
;

repair_option_list:
  |
  repair_option |
  repair_option repair_option_list ;

repair_option:
  QUICK | EXTENDED | USE_FRM | /*!110500 FORCE */;

check_option_list:
  |
  check_option |
  check_option check_option_list ;

check_option:
  FOR UPGRADE | QUICK | FAST | MEDIUM | EXTENDED | CHANGED ;

admin_cache_index:
  ==FACTOR:0.05== set_key_buffer_size |
  ==FACTOR:0.05== set_key_cache_block_size |
  cache_index |
  load_index
;

cache_index:
  CACHE INDEX _basetable IN cache_name |
  ==FACTOR:0.01== CACHE INDEX _basetable PARTITION ( ALL ) IN cache_name ;

load_index:
  LOAD INDEX INTO CACHE _basetable __ignore_leaves(50) |
  LOAD INDEX INTO CACHE _basetable PARTITION ( ALL ) __ignore_leaves(50) ;

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

admin_analyze_or_explain_query:
  SHOW admin_analyze_or_explain admin_format_json FOR { $prng->uint16($executors->[0]->connectionId()-10, $executors->[0]->connectionId()+10) } /* compatibility 10.11 */ |
  SHOW EXPLAIN admin_format_json FOR { $prng->uint16($executors->[0]->connectionId()-10, $executors->[0]->connectionId()+10) }
;

admin_analyze_or_explain:
  ANALYZE /* compatibility 10.9.1 */ | EXPLAIN
;

admin_format_json:
  | | FORMAT=JSON /* compatibility 10.9.1 */
;

admin_extended_or_partitions:
  | | | | | EXTENDED | EXTENDED | EXTENDED | EXTENDED | PARTITIONS
;

admin_flush:
    FLUSH admin_no_write_or_local admin_flush_list
  | FLUSH admin_no_write_or_local admin_flush_list
  | FLUSH admin_no_write_or_local admin_flush_list
  | FLUSH admin_no_write_or_local admin_flush_list
  | FLUSH admin_no_write_or_local admin_flush_list
  | RESET QUERY CACHE
;

admin_no_write_or_local:
  ==FACTOR:3== |
  NO_WRITE_TO_BINLOG |
  LOCAL
;

admin_flush_list_or_item:
    admin_flush_tables
  | admin_flush_list
  | admin_flush_list
;

admin_flush_list:
  admin_flush_option | admin_flush_option, admin_flush_list
;

admin_flush_tables:
  | TABLES admin_table_list FOR EXPORT; UNLOCK TABLES
  | TABLES WITH READ LOCK ;; UNLOCK TABLES
  | TABLES WITH READ LOCK AND DISABLE CHECKPOINT ;; UNLOCK TABLES
  | TABLE admin_table_list
  | TABLES
;

admin_flush_option:
#    CHANGED_PAGE_BITMAPS
#    CLIENT_STATISTICS # userstat
    DES_KEY_FILE
  | HOSTS
#  | INDEX_STATISTICS # userstat
  | admin_flush_log_type LOGS
# Disabled due to MDEV-17977
#  | MASTER
  | PRIVILEGES
  | QUERY CACHE
#  | QUERY_RESPONSE_TIME # query_response_time
  | SLAVE
  | STATUS
#  | TABLE_STATISTICS # userstat
  | USER_RESOURCES
#  | USER_STATISTICS # userstat
;

admin_flush_log_type:
  | | | ERROR | ENGINE | GENERAL | SLOW | BINARY | RELAY
;

admin_table_list:
  _table | _table, admin_table_list
;

admin_show:
    SHOW AUTHORS
  | SHOW BINARY LOGS
  | SHOW MASTER LOGS
  | SHOW BINLOG EVENTS admin_show_binlog_in admin_show_binlog_from admin_binlog_limit_offset
  | SHOW CHARACTER SET admin_show_like_or_where
#  | SHOW CLIENT_STATISTICS # userstat
  | SHOW COLLATION admin_show_like_or_where
  | SHOW admin_full admin_columns_or_fields admin_from_table admin_from_in_db admin_show_where
  | SHOW CONTRIBUTORS
  | SHOW CREATE admin_db_or_schema admin_db_name
  | SHOW CREATE EVENT _letter
  | SHOW CREATE FUNCTION _letter
  | SHOW CREATE PACKAGE admin_package_name  /* compatibility 10.3.5 */
  | SHOW CREATE PACKAGE BODY admin_package_name /* compatibility 10.3.5 */
  | SHOW CREATE PROCEDURE _letter
  | SHOW CREATE SEQUENCE admin_sequence_name /* compatibility 10.3.5 */
  | SHOW CREATE TABLE _table
  | SHOW CREATE TRIGGER _letter
  | SHOW CREATE USER admin_user_name
  | SHOW CREATE VIEW _view /* EXECUTOR_FLAG_NON_EXISTING_ALLOWED */
  | SHOW admin_dbs_or_schemas admin_show_like_or_where
  | SHOW ENGINE admin_engine admin_status_or_mutex
  | SHOW admin_storage ENGINES
  | SHOW ERRORS admin_limit_offset
  | SHOW COUNT(*) ERRORS
  | SHOW EVENTS admin_from_in_db admin_show_like_or_where
  | SHOW EXPLAIN FOR _tinyint_unsigned
  | SHOW FUNCTION CODE _letter
  | SHOW FUNCTION STATUS admin_show_like_or_where
  | SHOW GRANTS admin_for_user
  | SHOW admin_index_keys admin_from_table admin_from_in_db admin_show_where
#  | SHOW INDEX_STATISTICS # userstat
#  | SHOW LOCALES # Plugin locales
  | SHOW MASTER STATUS
  | SHOW OPEN TABLES admin_from_in_db admin_show_like_or_where
  | SHOW PACKAGE BODY STATUS admin_show_like_or_where /* compatibility 10.3.5 */
  | SHOW PACKAGE STATUS admin_show_like_or_where /* compatibility 10.3.5 */
  | SHOW PLUGINS
#  | SHOW PLUGINS SONAME <soname>
  | SHOW PRIVILEGES
  | SHOW PROCEDURE CODE _letter
  | SHOW PROCEDURE STATUS admin_show_like_or_where
  | SHOW admin_full PROCESSLIST
  | SHOW PROFILE admin_opt_profile_type_list admin_limit_offset
#  | SHOW QUERY_RESPONSE_TIME # Plugin query_response_time
#  | SHOW RELAYLOG ['connection_name'] EVENTS  [IN 'log_name'] [FROM pos] [LIMIT [offset,] row_count]
  | SHOW SLAVE HOSTS
  | SHOW admin_session_global STATUS admin_show_like_or_where
  | SHOW TABLE STATUS admin_from_in_db admin_show_like_or_where
  | SHOW admin_full TABLES admin_from_in_db admin_show_like_or_where
#  | SHOW TABLE_STATISTICS # userstat
  | SHOW TRIGGERS admin_from_in_db admin_show_like_or_where
#  | SHOW USER_STATISTICS # userstat
  | SHOW admin_session_global VARIABLES admin_show_like_or_where
  | SHOW WARNINGS admin_limit_offset
  | SHOW COUNT(*) WARNINGS
#  | SHOW WSREP_MEMBERSHIP # Plugin wsrep_info
#  | SHOW WSREP_STATUS # Plugin wsrep_info
;

admin_session_global:
  | | SESSION | GLOBAL
;

admin_opt_profile_type_list:
  | | admin_profile_type_list
;

admin_profile_type_list:
  admin_profile_type | admin_profile_type, admin_profile_type_list
;

admin_profile_type:
    ALL
  | BLOCK IO
  | CONTEXT SWITCHES
  | CPU
  | IPC
  | MEMORY
  | PAGE FAULTS
  | SOURCE
  | SWAPS
;

admin_profile_for_query:
  | | FOR QUERY _smallint_unsigned
;

admin_db_or_schema:
  DATABASE | SCHEMA
;

admin_index_keys:
  INDEX | INDEXES | KEYS
;

admin_dbs_or_schemas:
  DATABASES | SCHEMAS
;

admin_for_user:
  | | FOR admin_user_name
;

admin_storage:
  | | | STORAGE
;

admin_engine:
  InnoDB | MyISAM | Aria | MEMORY | CSV | RocksDB | PERFORMANCE_SCHEMA
;

admin_status_or_mutex:
  STATUS | MUTEX
;

admin_db_name:
  mysql | information_schema | performance_schema | test | _letter
;

admin_package_name:
  test._letter | _letter
;

admin_sequence_name:
  { 'seq'.$prng->int(0,9) } | _table | _letter
;

admin_user_name:
  _letter | _letter@localhost | _letter@'%' | '' | root@localhost | root
;

admin_from_table_list:
  admin_from_table | admin_from_table, admin_from_table_list
;

admin_from_table:
  FROM _table
;

admin_from_in_db:
  | | FROM admin_db_name | IN admin_db_name
;

admin_full:
  | | FULL
;

admin_columns_or_fields:
  COLUMNS | FIELDS
;

admin_show_binlog_in:
  | | | IN 'master-bin.000001' | IN 'mysql-bin.000001'
;

admin_show_binlog_from:
  | | | FROM _smallint_unsigned
;

admin_binlog_limit_offset:
  | LIMIT _smallint_unsigned | LIMIT _smallint_unsigned,_smallint_unsigned
;

admin_limit_offset:
  |
  | LIMIT _smallint_unsigned
  | LIMIT _smallint_unsigned OFFSET _smallint_unsigned
  | LIMIT _smallint_unsigned | LIMIT _smallint_unsigned,_smallint_unsigned
;

# TODO: extend
admin_show_like_or_where:
  admin_show_where | admin_show_like
;

admin_show_where:
;

admin_show_like:
;
