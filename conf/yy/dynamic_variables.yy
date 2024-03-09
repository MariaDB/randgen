#  Copyright (c) 2020, 2022, MariaDB Corporation
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

#include <conf/yy/include/basics.inc>

thread1_init:
    dynvar_initial_settings;

query:
                   SET SESSION dynvar_session_variable
  | ==FACTOR:0.1== SET GLOBAL dynvar_global_variable_runtime
;

dynvar_initial_settings:
  dynvar_global_setting /* initial setting */ |
  ==FACTOR:10== dynvar_global_setting /* initial setting */ ;; dynvar_initial_settings
;

dynvar_global_setting:
  ==FACTOR:100== SET GLOBAL dynvar_global_variable |
  ==FACTOR:0.1== SET NAMES _charset_name |
  ==FACTOR:0.001== SET GLOBAL dynvar_charset_variable
;

dynvar_global_variable_runtime:
    INNODB_BUFFER_POOL_DUMP_NOW= dynvar_boolean
  | INNODB_BUFFER_POOL_LOAD_ABORT= dynvar_boolean
  | INNODB_BUFFER_POOL_LOAD_NOW= dynvar_boolean
# Undocumented debug-only variable which at least according to this commit comment
# https://github.com/MariaDB/server/commit/0ba299da02
# is known to cause raice conditions
#  | INNODB_LOG_CHECKPOINT_NOW= dynvar_boolean
  | INNODB_READ_ONLY_COMPRESSED= dynvar_boolean /* compatibility 10.6.0 */
  | BINLOG_COMMIT_WAIT_COUNT= { $prng->arrayElement([1,10,100]) }
  | BINLOG_COMMIT_WAIT_USEC= { $prng->arrayElement([0,1000,1000000,10000000]) }
# Synonym of MAX_BINLOG_TOTAL_SIZE (hopefully)
  | ==FACTOR:0.5== BINLOG_SPACE_LIMIT= { $prng->arrayElement([0,4096,1048576,16777216]) } /* compatibility 11.4.0 */
  | LOG_QUERIES_NOT_USING_INDEXES= dynvar_boolean
  | LOG_SLOW_ADMIN_STATEMENTS= dynvar_boolean
  | LOG_SLOW_SLAVE_STATEMENTS= dynvar_boolean
# Synonym of BINLOG_SPACE_LIMIT (hopefully)
  | ==FACTOR:0.5== MAX_BINLOG_TOTAL_SIZE= { $prng->arrayElement([0,4096,1048576,16777216]) } /* compatibility 11.4.0 */
  | RPL_SEMI_SYNC_MASTER_ENABLED= dynvar_boolean /* compatibility 10.3 */
  | RPL_SEMI_SYNC_SLAVE_ENABLED= dynvar_boolean /* compatibility 10.3 */
  | SLAVE_CONNECTIONS_NEEDED_FOR_PURGE= { $prng->uint16(0,2) } /* compatibility 11.4.0 */
  | USERSTAT= dynvar_boolean
;

dynvar_charset_variable:
    CHARACTER_SET_CLIENT= _charset_name
  | CHARACTER_SET_CONNECTION= _charset_name
  | CHARACTER_SET_DATABASE= _charset_name
  | CHARACTER_SET_FILESYSTEM= _charset_name
  | CHARACTER_SET_RESULTS= _charset_name
  | CHARACTER_SET_SERVER= _charset_name
  | COLLATION_CONNECTION= _collation_name
  | COLLATION_DATABASE= _collation_name
  | COLLATION_SERVER= _collation_name
;

dynvar_session_variable:
    ALTER_ALGORITHM= { $prng->arrayElement(['DEFAULT','COPY','INPLACE','NOCOPY','INSTANT']) } /* compatibility 10.3.7 */
  | ANALYZE_SAMPLE_PERCENTAGE= { $prng->int(0,100) } /* compatibility 10.4.3 */
  | ARIA_REPAIR_THREADS= { $prng->int(1,10) }
# TODO: 4096 disabled due to MDEV-28990
  | ARIA_SORT_BUFFER_SIZE= { $prng->arrayElement([16384,65536,1048576,134217728,268434432]) }
  | ARIA_STATS_METHOD= { $prng->arrayElement(['nulls_equal','nulls_unequal','nulls_ignored']) }
  | AUTOCOMMIT= dynvar_boolean
  | AUTO_INCREMENT_INCREMENT= { $prng->arrayElement([1,1,1,1,2,2,2,3,3,65535]) }
  | AUTO_INCREMENT_OFFSET= { $prng->arrayElement([1,1,1,1,2,2,2,3,3,65534,65535]) }
# TODO: big_tables is deprecated in 10.5.0
  | BIG_TABLES= dynvar_boolean
  | BINLOG_ALTER_TWO_PHASE= dynvar_boolean /* compatibility 10.8.1 */
  | BINLOG_ANNOTATE_ROW_EVENTS= dynvar_boolean
  | BINLOG_DIRECT_NON_TRANSACTIONAL_UPDATES= dynvar_boolean
  | BINLOG_FORMAT= { $prng->arrayElement(['MIXED','ROW','MIXED','ROW','MIXED','ROW','STATEMENT']) }
  | BINLOG_ROW_IMAGE= { $prng->arrayElement(['FULL','NOBLOB','MINIMAL']) }
  | BULK_INSERT_BUFFER_SIZE= { $prng->arrayElement([0,1024,1048576,4194304,8388608]) }
# Charset variables are moved to a separate rule
#  | CHARACTER_SET_CLIENT= _charset_name
#  | CHARACTER_SET_CONNECTION= _charset_name
#  | CHARACTER_SET_DATABASE= _charset_name
#  | CHARACTER_SET_FILESYSTEM= _charset_name
#  | CHARACTER_SET_RESULTS= _charset_name
#  | CHARACTER_SET_SERVER= _charset_name
  | CHECK_CONSTRAINT_CHECKS= dynvar_boolean /* compatibility 10.2.1 */
# Charset variables are moved to a separate rule
#  | COLLATION_CONNECTION= _collation_name
#  | COLLATION_DATABASE= _collation_name
#  | COLLATION_SERVER= _collation_name
  | COLUMN_COMPRESSION_THRESHOLD= { $prng->arrayElement([0,8,100,1024,65535]) } /* compatibility 10.3.2 */
  | COLUMN_COMPRESSION_ZLIB_LEVEL= { $prng->int(1,9) } /* compatibility 10.3.2 */
  | COLUMN_COMPRESSION_ZLIB_STRATEGY= { $prng->arrayElement(['DEFAULT_STRATEGY','FILTERED','HUFFMAN_ONLY','RLE','FIXED']) } /* compatibility 10.3.2 */
  | COLUMN_COMPRESSION_ZLIB_WRAP= dynvar_boolean /* compatibility 10.3.2 */
  | COMPLETION_TYPE= { $prng->arrayElement([0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,2]) }
  | DEADLOCK_SEARCH_DEPTH_LONG= { $prng->int(0,33) }
  | DEADLOCK_SEARCH_DEPTH_SHORT= { $prng->int(0,32) }
  | DEADLOCK_TIMEOUT_LONG= { $prng->arrayElement([0,1,10000,50000000,4294967295]) }
  | DEADLOCK_TIMEOUT_SHORT= { $prng->arrayElement([0,1,10000,50000000,4294967295]) }
# | DEBUG
# | DEBUG_DBUG
# | DEBUG_SYNC
  | DEFAULT_MASTER_CONNECTION= { $prng->arrayElement(["''",'m1']) }
  | DEFAULT_REGEX_FLAGS= dynvar_default_regex_flags_value
  | DEFAULT_STORAGE_ENGINE= DEFAULT
  | DEFAULT_TMP_STORAGE_ENGINE= { $prng->arrayElement(['InnoDB','Aria','MyISAM','MEMORY']) }
  | DEFAULT_WEEK_FORMAT= { $prng->int(0,7) }
  | DIV_PRECISION_INCREMENT= { $prng->int(0,30) }
  | ENFORCE_STORAGE_ENGINE= { $prng->arrayElement(['DEFAULT','DEFAULT','DEFAULT','DEFAULT','DEFAULT','DEFAULT','DEFAULT','InnoDB','Aria','MyISAM','MEMORY']) }
  | EQ_RANGE_INDEX_DIVE_LIMIT= { $prng->arrayElement([0,1,200,10000]) }
  | EXPENSIVE_SUBQUERY_LIMIT= { $prng->arrayElement([0,1,10,100,1000,10000]) }
  | FOREIGN_KEY_CHECKS= dynvar_boolean
  | GROUP_CONCAT_MAX_LEN= { $prng->arrayElement([4,1024,65536,1048576]) }
  | GTID_DOMAIN_ID= { $prng->int(0,5) }
  | GTID_SEQ_NO= { $prng->int(0,4294967295) }
  | HISTOGRAM_SIZE= { $prng->int(0,255) }
  | HISTOGRAM_TYPE= { $prng->arrayElement(['SINGLE_PREC_HB','DOUBLE_PREC_HB','JSON_HB /* compatibility 10.8.0 */']) }
# | IDENTITY= { $prng->int(0,4294967295) } # == last_insert_id
  | IDLE_READONLY_TRANSACTION_TIMEOUT= { $prng->arrayElement([0,3600]) } /* compatibility 10.3.0 */
  | IDLE_TRANSACTION_TIMEOUT= { $prng->arrayElement([0,3600]) } /* compatibility 10.3.0 */
  | IDLE_WRITE_TRANSACTION_TIMEOUT= { $prng->arrayElement([0,3600]) } /* compatibility 10.3.0 */
  | INNODB_COMPRESSION_DEFAULT= dynvar_boolean
  | INNODB_DEFAULT_ENCRYPTION_KEY_ID= { $prng->int(1,10) }
  | INNODB_FT_ENABLE_STOPWORD= dynvar_boolean
# | innodb_ft_user_stopword_table= { $prng->arrayElement(["''","'test/stop'","'test/t1'"]) }
  | INNODB_LOCK_WAIT_TIMEOUT= { $prng->arrayElement(['DEFAULT','1', '0 /* compatibility 10.3 */']) }
  | INNODB_STRICT_MODE= dynvar_boolean
  | INNODB_TABLE_LOCKS= dynvar_boolean
  | INNODB_TMPDIR= DEFAULT
  | INSERT_ID= { $prng->int(0,4294967295) }
  | INTERACTIVE_TIMEOUT= { $prng->arrayElement(['DEFAULT',1,30]) }
  | IN_PREDICATE_CONVERSION_THRESHOLD= { $prng->arrayElement([0,1,2,5,10,20,50,100,1000,65536,4294967295]) } /* compatibility 10.3.18 */
  | JOIN_BUFFER_SIZE= { $prng->arrayElement([128,1024,65536,131072,262144]) }
  | JOIN_BUFFER_SPACE_LIMIT= { $prng->arrayElement([2048,16384,131072,1048576,2097152]) }
  | JOIN_CACHE_LEVEL= { $prng->int(0,8) }
  | KEEP_FILES_ON_CREATE= dynvar_boolean
  | LAST_INSERT_ID= { $prng->int(0,4294967295) }
  | LC_MESSAGES= { $prng->arrayElement(['en_US','en_GB','fi_FI','ru_RU','zh_CN']) }
  | LC_TIME_NAMES= { $prng->arrayElement(['en_US','en_GB','fi_FI','ru_RU','zh_CN']) }
  | LOCK_WAIT_TIMEOUT= { $prng->arrayElement(['DEFAULT','1','0 /* compatibility 10.3 */']) }
  | LOG_DISABLED_STATEMENTS= { $prng->arrayElement(["''",'sp','slave',"'slave,sp'"]) } /* compatibility 10.3.1 */
# Was global in 10.2
  | LOG_QUERIES_NOT_USING_INDEXES= dynvar_boolean /* compatibility 10.3.1 */
# Was global in 10.2
  | LOG_SLOW_ADMIN_STATEMENTS= dynvar_boolean /* compatibility 10.3.1 */
  | LOG_SLOW_DISABLED_STATEMENTS= dynvar_log_slow_disabled_statements_value /* compatibility 10.3.1 */
  | LOG_SLOW_FILTER= dynvar_log_slow_filter_value
  | LOG_SLOW_RATE_LIMIT= { $prng->int(1,1000) }
# Was global in 10.2
  | LOG_SLOW_SLAVE_STATEMENTS= dynvar_boolean /* compatibility 10.3.1 */
  | LOG_SLOW_VERBOSITY= dynvar_log_slow_verbosity_value
  | LOG_WARNINGS= { $prng->int(0,20) }
  | LONG_QUERY_TIME= { $prng->int(0,30) }
  | LOW_PRIORITY_UPDATES= dynvar_boolean
# | MAX_ALLOWED_PACKET # Dynamic conditionally
  | MAX_DELAYED_THREADS= { $prng->arrayElement([0,20,'DEFAULT']) }
  | MAX_ERROR_COUNT= { $prng->arrayElement([0,1,64,65535]) }
  | MAX_HEAP_TABLE_SIZE= { $prng->arrayElement([16384,65536,1048576,16777216]) }
# | MAX_INSERT_DELAYED_THREADS # == max_delayed_threads
  | MAX_JOIN_SIZE= { $prng->arrayElement(['DEFAULT',1,65535,18446744073709551615]) }
  | MAX_LENGTH_FOR_SORT_DATA= { $prng->arrayElement(['DEFAULT',4,1024,1048576,8388608]) }
  | MAX_RECURSIVE_ITERATIONS= { $prng->arrayElement(['DEFAULT',0,1,1048576,4294967295]) }
# 0 can only be set at startup
# Most of the time not settable as there is no master connection
  | ==FACTOR:0.1== MAX_RELAY_LOG_SIZE= { $prng->arrayElement([4096,1048576,16777216]) }
  | MAX_ROWID_FILTER_SIZE= { $prng->arrayElement([1024,4096,65536,131072,1048576]) } /* compatibility 10.4.3 */
  | MAX_SEEKS_FOR_KEY= { $prng->arrayElement([1,4096,1048576,4294967295]) }
# Too many problems
#  | MAX_SESSION_MEM_USED= { $prng->arrayElement([8192,1048576,4294967295,9223372036854775807,18446744073709551615]) }
  | MAX_SORT_LENGTH= { $prng->arrayElement([64,512,1024,2048,4096,65535,1048576,8388608]) }
# Limited instead of max 255, to fit into the default thread_stack
  | MAX_SP_RECURSION_DEPTH= { $prng->int(0,25) }
  | MAX_STATEMENT_TIME= { $prng->arrayElement(['DEFAULT',1,10]) }
# | MAX_TMP_TABLES # Said to be unused
# | MAX_USER_CONNECTIONS # Dynamic conditionally
  | MIN_EXAMINED_ROW_LIMIT= { $prng->arrayElement([0,1,1024,1048576,4294967295]) }
  | MRR_BUFFER_SIZE= { $prng->arrayElement([8192,65535,262144,1048576]) }
# Too many problems: MDEV-23294, MDEV-23318, MDEV-23363, MDEV-23364, ...
# | MYISAM_REPAIR_THREADS= { $prng->int(1,10) }
# Too many problems with low values, removing 131072 from the array
# e.g. MDEV-23398
  | MYISAM_SORT_BUFFER_SIZE= { $prng->arrayElement([1048576,268434432]) }
  | MYISAM_STATS_METHOD= { $prng->arrayElement(['nulls_equal','nulls_unequal','nulls_ignored']) }
# | NET_BUFFER_LENGTH # Doesn't seem to be dynamic
  | NET_READ_TIMEOUT= { $prng->int(10,60) }
  | NET_RETRY_COUNT= { $prng->int(1,100) }
  | NET_WRITE_TIMEOUT= { $prng->int(20,90) }
  | OLD= dynvar_boolean
# == from 10.3.7 same as alter_algorithm, removed in 11.2
  | OLD_ALTER_TABLE = dynvar_boolean /* incompatibility 10.3.7 */
  | OLD_ALTER_TABLE= { $prng->arrayElement(['DEFAULT','COPY','INPLACE','NOCOPY','INSTANT']) } /* compatibility 10.3.7 */ /* incompatibility 11.2.0 */
  | OLD_MODE= dynvar_old_mode_value
# Old passwords cause an error due to secure-auth mode or
# due to the absence of mysql_old_password plugin
# | OLD_PASSWORDS= dynvar_boolean
  | OPTIMIZER_PRUNE_LEVEL= dynvar_boolean
  | OPTIMIZER_SEARCH_DEPTH= { $prng->int(0,62) }
  | OPTIMIZER_SELECTIVITY_SAMPLING_LIMIT= { $prng->arrayElement([10,50,100,1000,10000]) }
  | OPTIMIZER_SWITCH= dynvar_optimizer_switch_value
  | OPTIMIZER_TRACE= { "'enabled=".$prng->arrayElement(['on','off','default']) ."'" } /* compatibility 10.4.3 */
  | OPTIMIZER_TRACE_MAX_MEM_SIZE= { $prng->arrayElement([1,16384,1048576,8388608]) } /* compatibility 10.4.3 */
  | OPTIMIZER_USE_CONDITION_SELECTIVITY= { $prng->int(1,5) }
  | PRELOAD_BUFFER_SIZE= { $prng->arrayElement([1024,8192,32768,1048576]) }
  | PROFILING= dynvar_boolean
  | PROFILING_HISTORY_SIZE= { $prng->int(0,100) }
  | PROGRESS_REPORT_TIME= { $prng->int(0,60) }
  | PSEUDO_SLAVE_MODE= dynvar_boolean
  | PSEUDO_THREAD_ID= { $prng->int(0,1000) }
  | QUERY_ALLOC_BLOCK_SIZE= { $prng->arrayElement([1024,8192,16384,1048576]) }
  | QUERY_CACHE_STRIP_COMMENTS= dynvar_boolean
# | QUERY_CACHE_TYPE= { $prng->int(0,2) } # Dynamic conditionally
  | QUERY_CACHE_WLOCK_INVALIDATE= dynvar_boolean
  | QUERY_PREALLOC_SIZE= { $prng->arrayElement([1024,8192,16384,24576,1048576]) }
  | RAND_SEED1= { $prng->int(0,18446744073709551615) }
  | RAND_SEED2= { $prng->int(0,18446744073709551615) }
  | RANGE_ALLOC_BLOCK_SIZE= { $prng->arrayElement([4096,8192,16384,1048576]) }
  | READ_BUFFER_SIZE= { $prng->arrayElement([8192,16384,131072,1048576]) }
  | READ_RND_BUFFER_SIZE= { $prng->arrayElement([8200,65536,262144,1048576]) }
  | ROWID_MERGE_BUFF_SIZE= { $prng->arrayElement([0,65536,1048576,8388608]) }
  | SERVER_ID= { $prng->int(1,1000) }
  | SESSION_TRACK_SCHEMA= dynvar_boolean
  | SESSION_TRACK_STATE_CHANGE= dynvar_boolean
  | SESSION_TRACK_SYSTEM_VARIABLES= dynvar_session_track_system_variables_value
  | SESSION_TRACK_TRANSACTION_INFO= { $prng->arrayElement(['OFF','STATE','CHARACTERISTICS']) }
  # Disabled due to MDEV-16470 (functionality is disabled)
# | SESSION_TRACK_USER_VARIABLES= dynvar_boolean
  | SKIP_PARALLEL_REPLICATION= dynvar_boolean
  | SKIP_REPLICATION= dynvar_boolean
  | SLOW_QUERY_LOG= dynvar_boolean
# Too many problems with low values, removing 16384 from the array
  | SORT_BUFFER_SIZE= { $prng->arrayElement([262144,1048576,2097152,4194304]) }
  | SQL_AUTO_IS_NULL= dynvar_boolean
  | SQL_BIG_SELECTS= dynvar_boolean
  | SQL_BUFFER_RESULT= dynvar_boolean
  | SQL_IF_EXISTS= dynvar_boolean /* compatibility 10.5.2 */
  | SQL_LOG_BIN= dynvar_boolean
# | SQL_LOG_OFF
  | SQL_MODE= _basics_sql_mode_value
  | SQL_NOTES= dynvar_boolean
  | SQL_QUOTE_SHOW_CREATE= dynvar_boolean
  | SQL_SAFE_UPDATES= dynvar_boolean
#  | SQL_SELECT_LIMIT= { $prng->arrayElement([0,1,1024,18446744073709551615,'DEFAULT']) }
# Most of the time not settable as there is no master connection
  | ==FACTOR:0.1== SQL_SLAVE_SKIP_COUNTER= { $prng->int(0,2) }
  | SQL_WARNINGS= dynvar_boolean
  | STANDARD_COMPLIANT_CTE= dynvar_boolean
# | STORAGE_ENGINE # Deprecated
  | SYSTEM_VERSIONING_ALTER_HISTORY= { $prng->arrayElement(['ERROR','KEEP']) } /* compatibility 10.3.4 */
  | SYSTEM_VERSIONING_ASOF= { $prng->arrayElement(['DEFAULT',"'".$prng->int(1970,2039)."-01-01 00:00:00'"]) } /* compatibility 10.3.4 */
  | TCP_NODELAY= dynvar_boolean /* compatibility 10.4.0 */
  | THREAD_POOL_PRIORITY= { $prng->arrayElement(['DEFAULT','high','low','auto']) }
# | TIMESTAMP # Tempting, but causes problems, especially with versioning
  | TIME_ZONE= dynvar_tz_value
# Very low values disabled due to MDEV-23212
  | TMP_DISK_TABLE_SIZE= { $prng->arrayElement(['DEFAULT',65536,8388608,18446744073709551615]) }
# | TMP_MEMORY_TABLE_SIZE # == tmp_table_size
  | TMP_TABLE_SIZE= { $prng->arrayElement(['DEFAULT',1024,4194304,16777216,4294967295],'0 /* compatibility 10.5.0 */') }
  | TRANSACTION_ALLOC_BLOCK_SIZE= { $prng->arrayElement(['DEFAULT',1024,8192,16384,65536]) }
  | TRANSACTION_PREALLOC_SIZE= { $prng->arrayElement(['DEFAULT',1024,8192,16384,65536]) }
  | TX_ISOLATION= { $prng->arrayElement(["'READ-UNCOMMITTED'","'READ-COMMITTED'","'REPEATABLE-READ'","'SERIALIZABLE'"]) }
  | TX_READ_ONLY= dynvar_boolean
  | UNIQUE_CHECKS= dynvar_boolean
  | UPDATABLE_VIEWS_WITH_LIMIT= dynvar_boolean
  | USE_STAT_TABLES= { $prng->arrayElement(['NEVER','PREFERABLY','COMPLEMENTARY','COMPLEMENTARY_FOR_QUERIES /* compatibility 10.4.1 */','PREFERABLY_FOR_QUERIES /* compatibility 10.4.1 */']) }
# | WAIT_TIMEOUT= { $prng->arrayElement([0,3600]) }
  | WSREP_CAUSAL_READS= dynvar_boolean /* incompatibility 11.3.0 */
  | WSREP_DIRTY_READS= dynvar_boolean
# Internal server usage, doesn't seem to be settable
# | WSREP_GTID_SEQ_NO= { $prng->int(0,18446744073709551615) } /* compatibility 10.5.1 */
# Not settable to ON without provider
  | ==FACTOR:0.01== WSREP_ON= dynvar_boolean
  | WSREP_OSU_METHOD= { $prng->arrayElement(['TOI','RSU']) }
  | WSREP_RETRY_AUTOCOMMIT= { $prng->int(0,10000) }
  | WSREP_SYNC_WAIT= { $prng->int(0,15) }
# These two don't seem settable, but let's keep them for now
  | ==FACTOR:0.01== WSREP_TRX_FRAGMENT_SIZE= { $prng->arrayElement(['DEFAULT',0,1,16384,1048576]) } /* compatibility 10.4.2 */
  | ==FACTOR:0.01== WSREP_TRX_FRAGMENT_UNIT= { $prng->arrayElement(['bytes',"'rows'",'segments']) } /* compatibility 10.4.2 */
;

dynvar_global_variable:
    ARIA_CHECKPOINT_INTERVAL= { $prng->int(0,300) }
  | ARIA_CHECKPOINT_LOG_ACTIVITY= { $prng->arrayElement([0,1024,8192,16384,65536,1048576,4194304,16777216]) }
# Disabled due to MDEV-24640
# | ARIA_ENCRYPT_TABLES= dynvar_boolean
  | ARIA_GROUP_COMMIT= { $prng->arrayElement(['none','hard','soft']) }
  | ARIA_GROUP_COMMIT_INTERVAL= { $prng->arrayElement([0,1000,1000000,10000000,60000000]) }
  | ARIA_LOG_FILE_SIZE= { $prng->arrayElement([65536,1048576,134217728,1073741824]) }
  | ARIA_LOG_PURGE_TYPE= { $prng->arrayElement(['immediate','external','at_flush']) }
  | ARIA_MAX_SORT_FILE_SIZE= { $prng->arrayElement([65536,1048576,134217728,1073741824,9223372036854775807]) }
  | ARIA_PAGECACHE_AGE_THRESHOLD= { $prng->arrayElement([100,1000,10000,9999900]) }
  | ARIA_PAGECACHE_DIVISION_LIMIT= { $prng->int(1,100) }
  | ARIA_PAGE_CHECKSUM= dynvar_boolean
  | ARIA_RECOVER_OPTIONS= dynvar_recover_options_value
  | ARIA_SYNC_LOG_DIR= { $prng->arrayElement(['NEWFILE','NEVER','ALWAYS']) }
  | AUTOMATIC_SP_PRIVILEGES= dynvar_boolean
  | BINLOG_CACHE_SIZE= { $prng->arrayElement([4096,16384,1048576]) }
  | BINLOG_CHECKSUM= { $prng->arrayElement(['CRC32','NONE']) }
  | BINLOG_FILE_CACHE_SIZE= { $prng->arrayElement([8192,65536,1048576]) } /* compatibility 10.3.3 */
  | BINLOG_ROW_METADATA= { $prng->arrayElement(['NO_LOG','MINIMAL','FULL']) } /* compatibility 10.5.0 */
  | BINLOG_STMT_CACHE_SIZE= { $prng->arrayElement([4096,65536,1048576]) }
  | CONCURRENT_INSERT= { $prng->arrayElement(['AUTO','NEVER','ALWAYS']) }
# | CONNECT_TIMEOUT
  | DEBUG_BINLOG_FSYNC_SLEEP= { $prng->arrayElement([1000,500000,1000000]) }
  | DEFAULT_PASSWORD_LIFETIME= { $prng->arrayElement([150,300,600]) } /* compatibility 10.4.3 */
  | DELAYED_INSERT_LIMIT= { $prng->arrayElement([1,50,1000,10000]) }
  | DELAYED_INSERT_TIMEOUT= { $prng->arrayElement([10,100,600]) }
  | DELAYED_QUEUE_SIZE= { $prng->arrayElement([10,100,10000]) }
  | DELAY_KEY_WRITE= { $prng->arrayElement(['ON','OFF','ALL']) }
  | DISCONNECT_ON_EXPIRED_PASSWORD= dynvar_boolean /* compatibility 10.4.3 */
# Moved to startup options
# | ENCRYPT_TMP_DISK_TABLES
  | EVENT_SCHEDULER= dynvar_boolean
  | EXPIRE_LOGS_DAYS= { $prng->int(0,99) }
  | EXTRA_MAX_CONNECTIONS= { $prng->int(1,10) }
  | FLUSH= dynvar_boolean
  | FLUSH_TIME= { $prng->arrayElement([1,30,300]) }
# Unlikely used in practice
# | FT_BOOLEAN_SYNTAX
# Pre-defined in tests
# | GENERAL_LOG
# | GENERAL_LOG_FILE
  | GTID_BINLOG_STATE= ''
  | GTID_CLEANUP_BATCH_SIZE= { $prng->int(0,10000) } /* compatibility 10.4.1 */
  | GTID_IGNORE_DUPLICATES= dynvar_boolean
  | GTID_POS_AUTO_ENGINES= dynvar_engines_list_value /* compatibility 10.3.1 */
  | GTID_SLAVE_POS= ''
  | GTID_STRICT_MODE= dynvar_boolean
  | HOST_CACHE_SIZE= { $prng->arrayElement([0,1,2,10,16,100,1024]) }
  | INIT_CONNECT= { "'"."SELECT $$ as Perl_PID"."'" }
  | INIT_SLAVE= { "'"."SELECT $$ as Perl_PID"."'" }
  | INNODB_ADAPTIVE_FLUSHING= dynvar_boolean
  | INNODB_ADAPTIVE_FLUSHING_LWM= { $prng->int(0,70) }
  | INNODB_ADAPTIVE_HASH_INDEX= dynvar_boolean
  | INNODB_ADAPTIVE_MAX_SLEEP_DELAY= { $prng->arrayElement([0,1000,10000,100000,1000000]) } /* incompatibility 10.6.0 */
  | INNODB_AUTOEXTEND_INCREMENT= { $prng->int(1,1000) }
# Debug variable
  | INNODB_BACKGROUND_DROP_LIST_EMPTY= dynvar_boolean
# Deprecated since 10.5.2
  | INNODB_BACKGROUND_SCRUB_DATA_CHECK_INTERVAL= { $prng->arrayElement([1,10,60,300]) } /* incompatibility 10.6.0 */
# Deprecated since 10.5.2
  | INNODB_BACKGROUND_SCRUB_DATA_COMPRESSED= dynvar_boolean /* incompatibility 10.6.0 */
# Deprecated since 10.5.2
  | INNODB_BACKGROUND_SCRUB_DATA_INTERVAL= { $prng->arrayElement([10,100,300]) } /* incompatibility 10.6.0 */
# Deprecated since 10.5.2
  | INNODB_BACKGROUND_SCRUB_DATA_UNCOMPRESSED= dynvar_boolean /* incompatibility 10.6.0 */
  | INNODB_BUFFER_POOL_DUMP_AT_SHUTDOWN= dynvar_boolean
  | INNODB_BUFFER_POOL_DUMP_PCT= { $prng->int(1,100) }
  | INNODB_BUFFER_POOL_EVICT= { $prng->arrayElement(["''","'uncompressed'"]) }
  | INNODB_BUFFER_POOL_FILENAME= 'ibbpool'
  | INNODB_BUFFER_POOL_LOAD_PAGES_ABORT= { $prng->arrayElement([1,100,1000,100000]) } /* compatibility 10.3.0 */
  | INNODB_BUFFER_POOL_SIZE= { $prng->arrayElement([67108864,268435456,1073741824,2147483648]) }
  | INNODB_BUF_DUMP_STATUS_FREQUENCY= { $prng->arrayElement([10,50,99]) }
# Debug variable
  | INNODB_BUF_FLUSH_LIST_NOW= dynvar_boolean
# Deprecated since 10.9.0, removed in 11.0.1 (MDEV-29694)
# | INNODB_CHANGE_BUFFERING= { $prng->arrayElement(['inserts','none','deletes','purges','changes','all']) } /* incompatibility 10.9.0 */
# Debug variable, 2 causes intentional crash
# | INNODB_CHANGE_BUFFERING_DEBUG
  | INNODB_CHANGE_BUFFER_MAX_SIZE= { $prng->int(0,50) }
# Skipping strict values to avoid aborts (moving to startup variables)
  | INNODB_CHECKSUM_ALGORITHM= IF(@@innodb_checksum_algorithm like 'strict%', @@innodb_checksum_algorithm, { $prng->arrayElement(['crc32','innodb','none','full_crc32 /* compatibility 10.4.3 */']) })
  | INNODB_CMP_PER_INDEX_ENABLED= dynvar_boolean
# Can't really be set to non-default at runtime, and deprecated/removed anyway
# | innodb_commit_concurrency
  | INNODB_COMPRESSION_ALGORITHM= { $prng->arrayElement(['none','zlib','lz4','lzo','lzma','bzip2','snappy']) }
  | INNODB_COMPRESSION_FAILURE_THRESHOLD_PCT= { $prng->int(0,100) }
  | INNODB_COMPRESSION_LEVEL= { $prng->int(1,9) }
  | INNODB_COMPRESSION_PAD_PCT_MAX= { $prng->int(0,75) }
  | INNODB_CONCURRENCY_TICKETS= { $prng->arrayElement([1,2,10,100,1000,10000,100000]) } /* incompatibility 10.6.0 */
  | INNODB_DEADLOCK_DETECT= dynvar_boolean
  | INNODB_DEADLOCK_REPORT= { $prng->arrayElement(['off','basic','full']) } /* compatibility 10.6.0 */
  | INNODB_DEFAULT_ROW_FORMAT= { $prng->arrayElement(['redundant','compact','dynamic']) }
### Removed in 11.1.0, MDEV-30545
#  | INNODB_DEFRAGMENT= dynvar_boolean
#  | INNODB_DEFRAGMENT_FILL_FACTOR= { $prng->arrayElement([0.7,0.8,0.9,1]) }
#  | INNODB_DEFRAGMENT_FILL_FACTOR_N_RECS= { $prng->int(1,100) }
#  | INNODB_DEFRAGMENT_FREQUENCY= { $prng->arrayElement([1,2,100,1000]) }
#  | INNODB_DEFRAGMENT_N_PAGES= { $prng->int(2,32) }
#  | INNODB_DEFRAGMENT_STATS_ACCURACY= { $prng->arrayElement([1,2,10,100,1000,10000]) }
###
  | INNODB_DICT_STATS_DISABLED_DEBUG= dynvar_boolean
  | INNODB_DISABLE_RESIZE_BUFFER_POOL_DEBUG= dynvar_boolean
  | INNODB_DISABLE_SORT_FILE_CACHE= dynvar_boolean
# This will make everything stop
# | innodb_disallow_writes= dynvar_boolean
  | INNODB_ENCRYPTION_ROTATE_KEY_AGE= { $prng->arrayElement([0,1,2,100,1000,10000,100000]) }
  | INNODB_ENCRYPTION_ROTATION_IOPS= { $prng->arrayElement([0,1,2,100,1000,10000]) }
  | INNODB_ENCRYPTION_THREADS= { $prng->arrayElement([0,1,2,4,8]) }
# | INNODB_ENCRYPT_TABLES
  | INNODB_EVICT_TABLES_ON_COMMIT_DEBUG= dynvar_boolean  /* compatibility 10.3.18 */
  | INNODB_FAST_SHUTDOWN= { $prng->arrayElement([0,1,2,'3 /* compatibility 10.3.6 */']) }
  | INNODB_FILE_PER_TABLE= dynvar_boolean
  | INNODB_FILL_FACTOR= { $prng->int(10,100) }
# | INNODB_FIL_MAKE_PAGE_DIRTY_DEBUG
  | INNODB_FLUSHING_AVG_LOOPS= { $prng->arrayElement([1,2,10,100,1000]) }
  | INNODB_FLUSH_LOG_AT_TIMEOUT= { $prng->arrayElement([0,1,2,10,100,300]) }
  | INNODB_FLUSH_LOG_AT_TRX_COMMIT= { $prng->int(0,3) }
  | INNODB_FLUSH_NEIGHBORS= { $prng->int(0,2) }
  | INNODB_FLUSH_SYNC= dynvar_boolean
  | INNODB_FORCE_PRIMARY_KEY= dynvar_boolean
  | INNODB_FT_AUX_TABLE= 'test/ft_innodb'
  | INNODB_FT_ENABLE_DIAG_PRINT= dynvar_boolean
  | INNODB_FT_NUM_WORD_OPTIMIZE= { $prng->arrayElement([0,1,2,10,1000,10000]) }
  | INNODB_FT_RESULT_CACHE_LIMIT= { $prng->arrayElement([1000000,10000000,100000000,1000000000,4000000000]) }
# | innodb_ft_server_stopword_table
  | INNODB_IDLE_FLUSH_PCT= { $prng->int(0,100) } /* incompatibility 10.5.9 */
  | INNODB_IMMEDIATE_SCRUB_DATA_UNCOMPRESSED= dynvar_boolean
  | INNODB_INSTANT_ALTER_COLUMN_ALLOWED= { $prng->arrayElement(['never','add_last','add_drop_reorder /* compatibility 10.4.13 */']) } /* compatibility 10.3.23 */
  | INNODB_IO_CAPACITY= { $prng->arrayElement([100,500,1000]) }
  | INNODB_IO_CAPACITY_MAX= { $prng->arrayElement([100,1000,5000]) }
  | INNODB_LIMIT_OPTIMISTIC_INSERT_DEBUG= { $prng->arrayElement([1,10,100,1000,10000]) }
  | INNODB_LOG_CHECKSUMS= dynvar_boolean /* incompatibility 10.6.0 */
  | INNODB_LOG_COMPRESSED_PAGES= dynvar_boolean /* incompatibility 10.6.0 */
  | INNODB_LOG_FILE_SIZE= { $prng->arrayElement([4194304,16777216,100663296,268435456,'DEFAULT']) } / compatibility 10.9.0 */
  | INNODB_LOG_OPTIMIZE_DDL= dynvar_boolean /* incompatibility 10.6.0 */
  | INNODB_LOG_WRITE_AHEAD_SIZE= { $prng->arrayElement([512,1024,10000,16384]) }
  | INNODB_LRU_FLUSH_SIZE= { $prng->arrayElement([1,8,32,128,256]) } /* compatibility 10.5 */
  | INNODB_LRU_SCAN_DEPTH= { $prng->arrayElement([100,512,2048,16384]) }
# | innodb_master_thread_disabled_debug
  | INNODB_MAX_DIRTY_PAGES_PCT= { $prng->int(0,99) }
  | INNODB_MAX_DIRTY_PAGES_PCT_LWM= { $prng->int(0,99) }
  | INNODB_MAX_PURGE_LAG= { $prng->arrayElement([1,10,100,1000,10000]) }
  | INNODB_MAX_PURGE_LAG_DELAY= { $prng->arrayElement([100,1000,10000,100000]) }
  | INNODB_MAX_UNDO_LOG_SIZE= { $prng->arrayElement([10485760,41943040,167772160]) }
# | innodb_merge_threshold_set_all_debug
  | INNODB_MONITOR_DISABLE= '%'
  | INNODB_MONITOR_ENABLE= '%'
  | INNODB_MONITOR_RESET= '%'
  | INNODB_MONITOR_RESET_ALL= '%'
  | INNODB_OLD_BLOCKS_PCT= { $prng->int(5,95) }
  | INNODB_OLD_BLOCKS_TIME= { $prng->arrayElement([0,100,10000,100000]) }
  | INNODB_ONLINE_ALTER_LOG_MAX_SIZE= { $prng->arrayElement([65536,33554432,268435456]) }
  | INNODB_OPTIMIZE_FULLTEXT_ONLY= dynvar_boolean
  | INNODB_PAGE_CLEANERS= { $prng->int(1,8) } /* compatibility 10.3.3 */ /* incompatibility 10.6.0 */
# Makes server stall
# | innodb_page_cleaner_disabled_debug= dynvar_boolean
# Deprecated and ignored in 10.10.0 (MDEV-28540)
#  | INNODB_PREFIX_INDEX_CLUSTER_OPTIMIZATION= dynvar_boolean /* incompatibility 10.10.0 */
  | INNODB_PRINT_ALL_DEADLOCKS= dynvar_boolean
  | INNODB_PURGE_BATCH_SIZE= { $prng->arrayElement([1,2,10,100,1000]) }
  | INNODB_PURGE_RSEG_TRUNCATE_FREQUENCY= { $prng->arrayElement([1,2,10,64]) }
# MENT-599
  | INNODB_PURGE_THREADS= { $prng->int(0,33) } /* compatibility 10.5.2-0 10.7.1 */
  | INNODB_RANDOM_READ_AHEAD= dynvar_boolean
  | INNODB_READ_AHEAD_THRESHOLD= { $prng->int(0,64) }
# MENT-661
  | INNODB_READ_IO_THREADS= { $prng->int(0,65) } /* compatibility 10.5.2-0 */
  | INNODB_READ_ONLY_COMPRESSED= dynvar_boolean /* compatibility 10.6.0 */
  | INNODB_REPLICATION_DELAY= { $prng->arrayElement([1,100,1000,10000]) } /* incompatibility 10.6.0 */
# | innodb_saved_page_number_debug
# Deprecated since 10.5.2
  | INNODB_SCRUB_LOG_SPEED= { $prng->arrayElement([1,2,16,1024]) } /* incompatibility 10.6.0 */
# | innodb_simulate_comp_failures
  | INNODB_SPIN_WAIT_DELAY= { $prng->arrayElement([1,2,16,1024]) }
  | INNODB_STATS_AUTO_RECALC= dynvar_boolean
  | INNODB_STATS_INCLUDE_DELETE_MARKED= dynvar_boolean
  | INNODB_STATS_METHOD= { $prng->arrayElement(['nulls_equal','nulls_unequal','nulls_ignored']) }
  | INNODB_STATS_MODIFIED_COUNTER= { $prng->arrayElement([1,2,16,1024]) }
  | INNODB_STATS_ON_METADATA= dynvar_boolean
  | INNODB_STATS_PERSISTENT= dynvar_boolean
  | INNODB_STATS_PERSISTENT_SAMPLE_PAGES= { $prng->arrayElement([1,2,10,100,1000]) }
  | INNODB_STATS_TRADITIONAL= dynvar_boolean
  | INNODB_STATS_TRANSIENT_SAMPLE_PAGES= { $prng->arrayElement([1,2,10,100,1000]) }
  | INNODB_STATUS_OUTPUT= dynvar_boolean
  | INNODB_STATUS_OUTPUT_LOCKS= dynvar_boolean
  | INNODB_SYNC_SPIN_LOOPS= { $prng->arrayElement([0,1,2,10,100,1000]) }
# Disabled due to MDEV-24759 (and it's deprecated in 10.5, removed in 10.6)
#  | INNODB_THREAD_CONCURRENCY= { $prng->int(1,8) }
  | INNODB_THREAD_SLEEP_DELAY= { $prng->arrayElement([0,100,1000,100000]) } /* incompatibility 10.6.0 */
# | innodb_trx_purge_view_update_only_debug
# | innodb_trx_rseg_n_slots_debug
  | INNODB_UNDO_LOGS= { $prng->int(0,128) } /* incompatibility 10.6.0 */
  | INNODB_UNDO_LOG_TRUNCATE= dynvar_boolean
# MENT-661
  | INNODB_WRITE_IO_THREADS= { $prng->int(0,65) } /* compatibility 10.5.2-0 */
  | KEY_BUFFER_SIZE= { $prng->arrayElement([8,1024,1048576,16777216]) }
  | KEY_CACHE_AGE_THRESHOLD= { $prng->arrayElement([100,500,1000,10000]) }
  | KEY_CACHE_BLOCK_SIZE= { $prng->arrayElement([512,2048,4096,16384]) }
  | KEY_CACHE_DIVISION_LIMIT= { $prng->int(1,100) }
  | KEY_CACHE_FILE_HASH_SIZE= { $prng->int(128,16384) }
  | KEY_CACHE_SEGMENTS= { $prng->int(1,64) }
  | LOCAL_INFILE= dynvar_boolean
  | LOG_BIN_COMPRESS= dynvar_boolean
  | LOG_BIN_COMPRESS_MIN_LEN= { $prng->int(10,1024) }
  | LOG_BIN_TRUST_FUNCTION_CREATORS= dynvar_boolean
  | LOG_OUTPUT= { $prng->arrayElement(["'FILE'","'TABLE,FILE'"]) }
  | MASTER_VERIFY_CHECKSUM= dynvar_boolean
  | MAX_BINLOG_CACHE_SIZE= { $prng->arrayElement([1048576,16777216,1073741824]) }
  | MAX_BINLOG_SIZE= { $prng->arrayElement([1048576,16777216,2147483648]) }
  | MAX_BINLOG_STMT_CACHE_SIZE= { $prng->arrayElement([1048576,16777216,1073741824]) }
# | max_connections
# | max_connect_errors
  | MAX_PASSWORD_ERRORS= { $prng->arrayElement([128,1024,1048576]) } /* compatibility 10.4.2 */
# Low values interfere with --ps-protocol mode, moving 0 and 1 to startup options
  | MAX_PREPARED_STMT_COUNT= { $prng->arrayElement([1024,8192,65528,1048576]) }
  | MAX_WRITE_LOCK_COUNT= { $prng->arrayElement([0,1,1024,1048576]) }
# Moved to startup settings due to MDEV-24174
# | MYISAM_DATA_POINTER_SIZE= { $prng->int(2,7) }
  | MYISAM_MAX_SORT_FILE_SIZE= { $prng->arrayElement([0,1,1024,1048576,33554432,268435456,1073741824]) }
  | MYISAM_USE_MMAP= dynvar_boolean
  | MYSQL56_TEMPORAL_FORMAT= dynvar_boolean
# MENT-661
  | NET_BUFFER_LENGTH= { $prng->arrayElement([1024,4096,16384,65536,1048576]) }
  | OPTIMIZER_MAX_SEL_ARG_WEIGHT= { $prng->arrayElement([0,1,10,100,1000,10000,50000,100000]) } /* compatibility 10.5.9 */
  | PROXY_PROTOCOL_NETWORKS= '*' /* compatibility 10.3.1 */
  | QUERY_CACHE_LIMIT= { $prng->arrayElement([0,1,8,1024,1048576,4294967295]) }
  | QUERY_CACHE_MIN_RES_UNIT= { $prng->arrayElement([0,1,8,1024,1048576,4294967295]) }
  | QUERY_CACHE_SIZE= { $prng->arrayElement([0,1024,8192,1048576,134217728]) }
  | READ_BINLOG_SPEED_LIMIT= { $prng->arrayElement([1024,8192,1048576,134217728]) }
  | READ_ONLY= dynvar_boolean
  | RELAY_LOG_PURGE= dynvar_boolean
  | RELAY_LOG_RECOVERY= dynvar_boolean
  | REPLICATE_DO_DB= 'test'
# | replicate_do_table
  | REPLICATE_EVENTS_MARKED_FOR_SKIP= { $prng->arrayElement(['REPLICATE','FILTER_ON_SLAVE','FILTER_ON_MASTER']) }
  | REPLICATE_IGNORE_DB= 'mysql'
  | REPLICATE_IGNORE_TABLE= 'test.dummy'
  | REPLICATE_WILD_DO_TABLE= 'test.%,mysql.%'
  | REPLICATE_WILD_IGNORE_TABLE= 'mysql.%'
# | require_secure_transport /* compatibility 10.5 */
  | RPL_SEMI_SYNC_MASTER_TIMEOUT= { $prng->arrayElement([0,1,1000,100000]) } /* compatibility 10.3 */
  | RPL_SEMI_SYNC_MASTER_TRACE_LEVEL= { $prng->arrayElement([1,16,32,64]) } /* compatibility 10.3 */
  | RPL_SEMI_SYNC_MASTER_WAIT_NO_SLAVE= dynvar_boolean /* compatibility 10.3 */
  | RPL_SEMI_SYNC_MASTER_WAIT_POINT= { $prng->arrayElement(['AFTER_COMMIT','AFTER_SYNC']) } /* compatibility 10.3 */
  | RPL_SEMI_SYNC_SLAVE_DELAY_MASTER= dynvar_boolean /* compatibility 10.3 */
  | RPL_SEMI_SYNC_SLAVE_KILL_CONN_TIMEOUT= { $prng->arrayElement([0,1,10,100]) } /* compatibility 10.3 */
  | RPL_SEMI_SYNC_SLAVE_TRACE_LEVEL= { $prng->arrayElement([1,16,32,64]) } /* compatibility 10.3 */
  | SECURE_AUTH= dynvar_boolean
  | SLAVE_COMPRESSED_PROTOCOL= dynvar_boolean
  | SLAVE_DDL_EXEC_MODE= { $prng->arrayElement(['IDEMPOTENT','STRICT']) }
  | SLAVE_DOMAIN_PARALLEL_THREADS= { $prng->int(1,8) }
  | SLAVE_EXEC_MODE= { $prng->arrayElement(['IDEMPOTENT','STRICT']) }
# | slave_max_allowed_packet
# | slave_net_timeout
  | SLAVE_PARALLEL_MAX_QUEUED= { $prng->arrayElement([0,1,2,1024,16384,1048576]) }
  | SLAVE_PARALLEL_MODE= { $prng->arrayElement(['conservative','optimistic','none','aggressive','minimal']) }
  | SLAVE_PARALLEL_THREADS= { $prng->int(1,8) }
# | slave_parallel_workers # Same as slave_parallel_threads
  | SLAVE_RUN_TRIGGERS_FOR_RBR= { $prng->arrayElement(['NO','YES','LOGGING','ENFORCE /* compatibility 10.5.2 */']) }
  | SLAVE_SQL_VERIFY_CHECKSUM= dynvar_boolean
  | SLAVE_TRANSACTION_RETRIES= { $prng->int(0,1000) }
  | SLAVE_TRANSACTION_RETRY_INTERVAL= { $prng->arrayElement([1,2,10,60,300]) } /* compatibility 10.3.3 */
  | SLAVE_TYPE_CONVERSIONS= { $prng->arrayElement(['ALL_LOSSY','ALL_NON_LOSSY']) }
  | SLOW_LAUNCH_TIME= { $prng->int(0,300) }
# | slow_query_log_file
  | STORED_PROGRAM_CACHE= { $prng->arrayElement([257,1024,4096,524288]) }
  | STRICT_PASSWORD_VALIDATION= dynvar_boolean
  | SYNC_BINLOG= { $prng->arrayElement([1,2,4,128,1024]) }
  | SYNC_FRM= dynvar_boolean
  | SYNC_MASTER_INFO= { $prng->arrayElement([0,1,100,100000]) }
  | SYNC_RELAY_LOG= { $prng->arrayElement([0,1,100,100000]) }
  | SYNC_RELAY_LOG_INFO= { $prng->arrayElement([0,1,100,100000]) }
# | table_definition_cache
  | TABLE_OPEN_CACHE= { $prng->arrayElement([1,2,10,100]) }
  | TCP_KEEPALIVE_INTERVAL= { $prng->int(1,300) } /* compatibility 10.3.3 */
  | TCP_KEEPALIVE_PROBES= { $prng->int(1,300) } /* compatibility 10.3.3 */
  | TCP_KEEPALIVE_TIME= { $prng->int(1,300) } /* compatibility 10.3.3 */
  | THREAD_CACHE_SIZE= { $prng->arrayElement([1,2,8,128]) }
  | THREAD_POOL_DEDICATED_LISTENER= dynvar_boolean /* compatibility 10.5.0 */
  | THREAD_POOL_EXACT_STATS= dynvar_boolean /* compatibility 10.5.0 */
  | THREAD_POOL_IDLE_TIMEOUT= { $prng->int(0,300) }
  | THREAD_POOL_MAX_THREADS= { $prng->arrayElement([1,2,128,500,1000]) }
  | THREAD_POOL_OVERSUBSCRIBE= { $prng->int(1,16) }
  | THREAD_POOL_PRIO_KICKUP_TIMER= { $prng->arrayElement([0,1,2,128,500,10000]) }
  | THREAD_POOL_SIZE= { $prng->int(1,128) }
  | THREAD_POOL_STALL_LIMIT= { $prng->arrayElement([10,100,1000,10000]) }
  | TIME_ZONE= dynvar_tz_value
# Galera is not normally used in tests
# | wsrep_auto_increment_control    global
# | wsrep_certification_rules       global
# | wsrep_certify_nonpk     global
# | wsrep_cluster_address   global
# | wsrep_cluster_name      global
# | wsrep_convert_lock_to_trx       global
# | wsrep_dbug_option       global
# | wsrep_debug     global
# | wsrep_desync    global
# | wsrep_drupal_282555_workaround  global
# | wsrep_forced_binlog_format      global
# | wsrep_gtid_domain_id    global
# | wsrep_gtid_mode global
# | wsrep_ignore_apply_errors       global /* compatibility 10.4 */
# | wsrep_load_data_splitting       global
# | wsrep_log_conflicts     global
# | wsrep_max_ws_rows       global
# | wsrep_max_ws_size       global
# | WSREP_MODE /* compatibility 10.6.0 */
# | wsrep_mysql_replication_bundle  global
# | wsrep_node_address      global
# | wsrep_node_incoming_address     global
# | wsrep_node_name global
# | wsrep_notify_cmd        global
# | wsrep_provider  global
# | wsrep_provider_options  global
# | wsrep_reject_queries    global
# | wsrep_replicate_myisam  global
# | wsrep_restart_slave     global
# | wsrep_slave_fk_checks   global
# | wsrep_slave_threads     global
# | wsrep_slave_uk_checks   global
# | WSREP_SR_STORE /* compatibility 10.4 */
# | wsrep_sst_auth  global
# | wsrep_sst_donor global
# | wsrep_sst_donor_rejects_queries global
# | wsrep_sst_method        global
# | wsrep_sst_receive_address       global
# | wsrep_start_position    global
# | wsrep_strict_ddl        global /* compatibility 10.5 */
# | WSREP_TRX_FRAGMENT_SIZE /* compatibility 10.4 */
# | WSREP_TRX_FRAGMENT_UNIT /* compatibility 10.4 */
;

# EXTENDED_MORE added in 10.5

dynvar_default_regex_flags_value:
    { @flags= qw(
          DOTALL
          DUPNAMES
          EXTENDED
          EXTENDED_MORE
          EXTRA
          MULTILINE
          UNGREEDY
        ); $length=$prng->int(0,scalar(@flags))
        ; $val= "'" . (join ',', @{$prng->shuffleArray(\@flags)}[0..$length-1]) . "'"
        ; if (index($val,'EXTENDED_MORE') > -1) { $val.= '/* compatibility 10.5 */' }
        ; $val
    }
;

dynvar_tz_value:
  { sprintf("'%s%02d:%02d'",$prng->arrayElement(['+','-']),$prng->int(0,12),$prng->int(0,59)) } |
  _timezone
;

# 10.2: admin,filesort,filesort_on_disk,full_join,full_scan,query_cache,query_cache_miss,tmp_table,tmp_table_on_disk
# 10.3: + filesort_priority_queue,not_using_index

dynvar_log_slow_filter_value:
    DEFAULT
    | { @filters= qw(
          admin
          filesort
          filesort_on_disk
          filesort_priority_queue
          full_join
          full_scan
          not_using_index
          query_cache
          query_cache_miss
          tmp_table
          tmp_table_on_disk
        ); $length=$prng->int(0,scalar(@filters))
        ; $val= "'" . (join ',', @{$prng->shuffleArray(\@filters)}[0..$length-1]) . "'"
        ; if ((index($val,'filesort_priority_queue') > -1) or (index($val,'not_using_index') > -1)) { $val.= ' /* compatibility 10.3.1 */' }
        ; $val
      }
;

dynvar_log_slow_disabled_statements_value:
    { @values= qw(admin call slave sp) ; $length= $prng->int(0,scalar(@values)); "'" . (join ',', @{$prng->shuffleArray(\@values)}[0..$length-1]) . "'" }
;

dynvar_log_slow_verbosity_value:
    { @vals= qw(
          query_plan
          innodb
          explain
        ); $length=$prng->int(0,scalar(@vals)); "'" . (join ',', @{$prng->shuffleArray(\@vals)}[0..$length-1]) . "'"
    }
;

dynvar_old_mode_value:
    { @modes= qw(
          NO_DUP_KEY_WARNINGS_WITH_IGNORE
          NO_PROGRESS_INFO
          ZERO_DATE_TIME_CAST
        ); $length=$prng->int(0,scalar(@modes)); "'" . (join ',', @{$prng->shuffleArray(\@modes)}[0..$length-1]) . "'"
    } |
    { @modes= qw(
          NO_DUP_KEY_WARNINGS_WITH_IGNORE
          NO_PROGRESS_INFO
          ZERO_DATE_TIME_CAST
          UTF8_IS_UTF8MB3
        ); $length=$prng->int(0,scalar(@modes)); "'" . (join ',', @{$prng->shuffleArray(\@modes)}[0..$length-1]) . "'"
    } /* compatibility 10.6.1 */ |
    { @modes= qw(
          NO_DUP_KEY_WARNINGS_WITH_IGNORE
          NO_PROGRESS_INFO
          ZERO_DATE_TIME_CAST
          UTF8_IS_UTF8MB3
          IGNORE_INDEX_ONLY_FOR_JOIN
          COMPAT_5_1_CHECKSUM
        ); $length=$prng->int(0,scalar(@modes)); "'" . (join ',', @{$prng->shuffleArray(\@modes)}[0..$length-1]) . "'"
    } /* compatibility 10.9.1 */ |
    { @modes= qw(
          NO_DUP_KEY_WARNINGS_WITH_IGNORE
          NO_PROGRESS_INFO
          ZERO_DATE_TIME_CAST
          UTF8_IS_UTF8MB3
          IGNORE_INDEX_ONLY_FOR_JOIN
          COMPAT_5_1_CHECKSUM
          NO_NULL_COLLATION_IDS
        ); $length=$prng->int(0,scalar(@modes)); "'" . (join ',', @{$prng->shuffleArray(\@modes)}[0..$length-1]) . "'"
    } /* compatibility 10.11.7 */ |
    { @modes= qw(
          NO_DUP_KEY_WARNINGS_WITH_IGNORE
          NO_PROGRESS_INFO
          ZERO_DATE_TIME_CAST
          LOCK_ALTER_TABLE_COPY
          UTF8_IS_UTF8MB3
          IGNORE_INDEX_ONLY_FOR_JOIN
          COMPAT_5_1_CHECKSUM
          NO_NULL_COLLATION_IDS
        ); $length=$prng->int(0,scalar(@modes)); "'" . (join ',', @{$prng->shuffleArray(\@modes)}[0..$length-1]) . "'"
    } /* compatibility 11.2.1 */
;

# 10.2:  index_merge,index_merge_union,index_merge_sort_union,index_merge_intersection,index_merge_sort_intersection,engine_condition_pushdown,index_condition_pushdown,derived_merge,derived_with_keys,firstmatch,loosescan,materialization,in_to_exists,semijoin,partial_match_rowid_merge,partial_match_table_scan,subquery_cache,mrr,mrr_cost_based,mrr_sort_keys,outer_join_with_cache,semijoin_with_cache,join_cache_incremental,join_cache_hashed,join_cache_bka,optimize_join_buffer_size,table_elimination,extended_keys,exists_to_in,orderby_uses_equalities,condition_pushdown_for_derived
# 10.3: + split_materialized
# 10.4: + condition_pushdown_for_subquery,rowid_filter,condition_pushdown_from_having
# 10.5: + not_null_range_scan

dynvar_all_optimizer_switches:
  { @modes= qw(
            index_merge
            index_merge_union
            index_merge_sort_union
            index_merge_intersection
            index_merge_sort_intersection
            engine_condition_pushdown
            index_condition_pushdown
            derived_merge
            derived_with_keys
            firstmatch
            loosescan
            materialization
            in_to_exists
            semijoin
            partial_match_rowid_merge
            partial_match_table_scan
            subquery_cache
            mrr
            mrr_cost_based
            mrr_sort_keys
            outer_join_with_cache
            semijoin_with_cache
            join_cache_incremental
            join_cache_hashed
            join_cache_bka
            optimize_join_buffer_size
            table_elimination
            extended_keys
            exists_to_in
            orderby_uses_equalities
            condition_pushdown_for_derived
            split_materialized
            condition_pushdown_for_subquery
            rowid_filter
            condition_pushdown_from_having
            not_null_range_scan
    ); ''
  };

dynvar_optimizer_switch_compatibility_markers:
  { if (index($val,'not_null_range_scan') > -1) { $val.= ' /* compatibility 10.5 */' }
    elsif ((index($val,'condition_pushdown_for_subquery') > -1) or (index($val,'rowid_filter') > -1) or (index($val,'condition_pushdown_from_having') > -1)) { $val.= ' /* compatibility 10.4 */' }
    elsif (index($val,'split_materialized') > -1) { $val.= ' /* compatibility 10.3.4 */' }
    ; $val }
  ;

dynvar_optimizer_switch_value:
    DEFAULT
    | dynvar_all_optimizer_switches
    { $length=$prng->int(0,scalar(@modes))
        ; $switch= (join ',', map {$_.'='.$prng->arrayElement(['on','off'])} @{$prng->shuffleArray(\@modes)}[0..$length-1])
        ; if ($switch =~ /materialization=off/) {
            if ($switch =~ /in_to_exists=off/) { $switch =~ s/in_to_exists=off/in_to_exists=on/ }
            elsif ($switch !~ /in_to_exists/) { $switch .= ',in_to_exists=on' }
          } elsif ($switch =~ /in_to_exists=off/) {
            if ($switch =~ /materialization=off/) { $switch =~ s/materialization=off/materialization=on/ }
            elsif ($switch !~ /materialization/) { $switch .= ',materialization=on' }
          }
        ; $val= "'" . $switch . "'"
        ; ''
    } dynvar_optimizer_switch_compatibility_markers
;

dynvar_session_track_system_variables_value:
    { @vars= keys %{$executors->[0]->server->serverVariables()}
      ; $length=$prng->int(0,scalar(@vars)/2)
      ; "'" . (join ',', @{$prng->shuffleArray(\@vars)}[0..$length-1]) . "'"
    }
  | '*'
  | DEFAULT
;

dynvar_recover_options_value:
    DEFAULT
    | { @filters= qw(
          BACKUP
          QUICK
          NORMAL
          FORCE
          OFF
        ); $length=$prng->int(0,scalar(@filters)); "'" . (join ',', @{$prng->shuffleArray(\@filters)}[0..$length-1]) . "'"
    }
;

dynvar_engines_list_value:
    DEFAULT
    | { @filters= qw(
          InnoDB
          MyISAM
          Aria
          MEMORY
          CSV
        ); $length=$prng->int(0,scalar(@filters)); "'" . (join ',', @{$prng->shuffleArray(\@filters)}[0..$length-1]) . "'"
    }
;

dynvar_boolean:
    0 | 1 ;

