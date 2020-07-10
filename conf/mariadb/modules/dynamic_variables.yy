#  Copyright (c) 2020, MariaDB Corporation
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

query_add:
                    dynvar_set_session
  | ==FACTOR:0.01== dynvar_set_global
;

dynvar_set_session:
    SET SESSION dynvar_session_variable ;

dynvar_set_global:
    SET GLOBAL dynvar_global_variable ;

dynvar_session_variable:
    ALTER_ALGORITHM= { $prng->arrayElement(['DEFAULT','COPY','INPLACE','NOCOPY','INSTANT']) } /* compatibility 10.3.7 */
  | ANALYZE_SAMPLE_PERCENTAGE= { $prng->int(0,100) } /* compatibility 10.4.3 */
  | ARIA_REPAIR_THREADS= { $prng->int(1,10) }
# Disabled due to MDEV-22500
# | ARIA_SORT_BUFFER_SIZE= { $prng->arrayElement([4096,16384,65536,1048576,134217728,268434432]) }
  | ARIA_STATS_METHOD= { $prng->arrayElement(['nulls_equal','nulls_unequal','nulls_ignored']) }
  | AUTOCOMMIT= dynvar_boolean
  | AUTO_INCREMENT_INCREMENT= { $prng->arrayElement([1,1,1,1,2,2,2,3,3,65535]) }
  | AUTO_INCREMENT_OFFSET= { $prng->arrayElement([1,1,1,1,2,2,2,3,3,65534,65535]) }
  # TODO: big_tables is deprecated in 10.5.0
  | BIG_TABLES= dynvar_boolean
  | BINLOG_ANNOTATE_ROW_EVENTS= dynvar_boolean
  | BINLOG_DIRECT_NON_TRANSACTIONAL_UPDATES= dynvar_boolean
  | BINLOG_FORMAT= { $prng->arrayElement(['MIXED','ROW','MIXED','ROW','MIXED','ROW','STATEMENT']) }
  | BINLOG_ROW_IMAGE= { $prng->arrayElement(['FULL','NOBLOB','MINIMAL']) }
  | BULK_INSERT_BUFFER_SIZE= { $prng->arrayElement([0,1024,1048576,4194304,8388608]) }
  | CHARACTER_SET_CLIENT= _charset_name
  | CHARACTER_SET_CONNECTION= _charset_name
  | CHARACTER_SET_DATABASE= _charset_name
  | CHARACTER_SET_FILESYSTEM= _charset_name
  | CHARACTER_SET_RESULTS= _charset_name
  | CHARACTER_SET_SERVER= _charset_name
  | CHECK_CONSTRAINT_CHECKS= dynvar_boolean /* compatibility 10.2.1 */
  | COLLATION_CONNECTION= _collation_name
  | COLLATION_DATABASE= _collation_name
  | COLLATION_SERVER= _collation_name
  | COLUMN_COMPRESSION_THRESHOLD= { $prng->arrayElement([0,8,100,1024,65535]) }
  | COLUMN_COMPRESSION_ZLIB_LEVEL= { $prng->int(1,9) }
  | COLUMN_COMPRESSION_ZLIB_STRATEGY= { $prng->arrayElement(['DEFAULT_STRATEGY','FILTERED','HUFFMAN_ONLY','RLE','FIXED']) }
  | COLUMN_COMPRESSION_ZLIB_WRAP= dynvar_boolean
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
  | HISTOGRAM_TYPE= { $prng->arrayElement(['SINGLE_PREC_HB','DOUBLE_PREC_HB']) }
# | IDENTITY= { $prng->int(0,4294967295) } # == last_insert_id
  | IDLE_READONLY_TRANSACTION_TIMEOUT= { $prng->arrayElement([0,3600]) }
  | IDLE_TRANSACTION_TIMEOUT= { $prng->arrayElement([0,3600]) }
  | IDLE_WRITE_TRANSACTION_TIMEOUT= { $prng->arrayElement([0,3600]) }
  | INNODB_COMPRESSION_DEFAULT= dynvar_boolean
  | INNODB_DEFAULT_ENCRYPTION_KEY_ID= { $prng->int(1,10) }
  | INNODB_FT_ENABLE_STOPWORD= dynvar_boolean
  | INNODB_FT_USER_STOPWORD_TABLE= { $prng->arrayElement(["''","'test/stop'","'test/t1'"]) }
  | INNODB_LOCK_WAIT_TIMEOUT= { $prng->arrayElement(['DEFAULT',0,1]) }
  | INNODB_STRICT_MODE= dynvar_boolean
  | INNODB_TABLE_LOCKS= dynvar_boolean
  | INNODB_TMPDIR= DEFAULT
  | INSERT_ID= { $prng->int(0,4294967295) }
  | INTERACTIVE_TIMEOUT= { $prng->arrayElement(['DEFAULT',0,1]) }
  | IN_PREDICATE_CONVERSION_THRESHOLD= { $prng->arrayElement([0,1,2,100,1000,65536,4294967295]) }
  | JOIN_BUFFER_SIZE= { $prng->arrayElement([128,1024,65536,131072,262144]) }
  | JOIN_BUFFER_SPACE_LIMIT= { $prng->arrayElement([2048,16384,131072,1048576,2097152]) }
  | JOIN_CACHE_LEVEL= { $prng->int(0,8) }
  | KEEP_FILES_ON_CREATE= dynvar_boolean
  | LAST_INSERT_ID= { $prng->int(0,4294967295) }
  | LC_MESSAGES= { $prng->arrayElement(['en_US','en_GB','fi_FI','ru_RU','zh_CN']) }
  | LC_TIME_NAMES= { $prng->arrayElement(['en_US','en_GB','fi_FI','ru_RU','zh_CN']) }
  | LOCK_WAIT_TIMEOUT= { $prng->arrayElement(['DEFAULT',0,1]) }
  | LOG_DISABLED_STATEMENTS= { $prng->arrayElement(["''",'sp','slave',"'slave,sp'"]) }
  | LOG_QUERIES_NOT_USING_INDEXES= dynvar_boolean
  | LOG_SLOW_ADMIN_STATEMENTS= dynvar_boolean
  | LOG_SLOW_DISABLED_STATEMENTS= { $prng->arrayElement(["''",'sp','slave',"'slave,sp'"]) }
  | LOG_SLOW_FILTER= dynvar_log_slow_filter_value
  | LOG_SLOW_RATE_LIMIT= { $prng->int(1,1000) }
  | LOG_SLOW_SLAVE_STATEMENTS= dynvar_boolean
  | LOG_SLOW_VERBOSITY= dynvar_log_slow_verbosity_value
  | LOG_WARNINGS= { $prng->int(0,20) }
  | LONG_QUERY_TIME= { $prng->int(0,600) }
  | LOW_PRIORITY_UPDATES= dynvar_boolean
# | MAX_ALLOWED_PACKET # Dynamic conditionally
  | MAX_DELAYED_THREADS= { $prng->arrayElement([0,20,'DEFAULT']) }
  | MAX_ERROR_COUNT= { $prng->arrayElement([0,1,64,65535]) }
  | MAX_HEAP_TABLE_SIZE= { $prng->arrayElement([16384,65535,1048576,16777216]) }
# | MAX_INSERT_DELAYED_THREADS # == max_delayed_threads
  | MAX_JOIN_SIZE= { $prng->arrayElement(['DEFAULT',1,65535,18446744073709551615]) }
  | MAX_LENGTH_FOR_SORT_DATA= { $prng->arrayElement(['DEFAULT',4,1024,1048576,8388608]) }
  | MAX_RECURSIVE_ITERATIONS= { $prng->arrayElement(['DEFAULT',0,1,1048576,4294967295]) }
# Disabled due to MDEV-22524
# | MAX_RELAY_LOG_SIZE= { $prng->arrayElement([0,4096,1048576,16777216]) }
  | MAX_ROWID_FILTER_SIZE= { $prng->arrayElement([1024,4096,65536,131072,1048576]) }
  | MAX_SEEKS_FOR_KEY= { $prng->arrayElement([1,4096,1048576,4294967295]) }
  | MAX_SESSION_MEM_USED= { $prng->arrayElement([8192,1048576,4294967295,9223372036854775807,18446744073709551615]) }
  | MAX_SORT_LENGTH= { $prng->arrayElement([8,512,1024,2048,4096,65535,1048576,8388608]) }
  | MAX_SP_RECURSION_DEPTH= { $prng->int(0,255) }
  | MAX_STATEMENT_TIME= { $prng->arrayElement(['DEFAULT',0,1]) }
# | MAX_TMP_TABLES # Said to be unused
# | MAX_USER_CONNECTIONS # Dynamic conditionally
  | MIN_EXAMINED_ROW_LIMIT= { $prng->arrayElement([0,1,1024,1048576,4294967295]) }
  | MRR_BUFFER_SIZE= { $prng->arrayElement([8192,65535,262144,1048576]) }
  | MYISAM_REPAIR_THREADS= { $prng->int(1,10) }
  | MYISAM_SORT_BUFFER_SIZE= { $prng->arrayElement([4096,16384,65536,1048576,134217728,268434432]) }
  | MYISAM_STATS_METHOD= { $prng->arrayElement(['nulls_equal','nulls_unequal','nulls_ignored']) }
# | NET_BUFFER_LENGTH # Doesn't seem to be dynamic
  | NET_READ_TIMEOUT= { $prng->int(10,60) }
  | NET_RETRY_COUNT= { $prng->int(1,100) }
  | NET_WRITE_TIMEOUT= { $prng->int(20,90) }
  | OLD= dynvar_boolean
# | OLD_ALTER_TABLE # == from 10.3.7 same as alter_algorithm
  | OLD_MODE= dynvar_old_mode_value
  | OLD_PASSWORDS= dynvar_boolean
  | OPTIMIZER_PRUNE_LEVEL= dynvar_boolean
  | OPTIMIZER_SEARCH_DEPTH= { $prng->int(0,63) }
  | OPTIMIZER_SELECTIVITY_SAMPLING_LIMIT= { $prng->arrayElement([10,50,100,1000,10000]) }
  | OPTIMIZER_SWITCH= dynvar_optimizer_switch_value
  | OPTIMIZER_TRACE= { "'enabled=".{ $prng->arrayElement(['on','off','default']) }."'" } /* compatibility 10.4.3 */
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
  | READ_BUFFER_SIZE= { $prng->arrayElement([8200,16384,131072,1048576]) }
  | READ_RND_BUFFER_SIZE= { $prng->arrayElement([8200,65536,262144,1048576]) }
  | ROWID_MERGE_BUFF_SIZE= { $prng->arrayElement([0,65536,1048576,8388608]) }
  | SERVER_ID= { $prng->int(1,1000) }
  | SESSION_TRACK_SCHEMA= dynvar_boolean
  | SESSION_TRACK_STATE_CHANGE= dynvar_boolean
# Disabled due to MDEV-22524
  | SESSION_TRACK_SYSTEM_VARIABLES= dynvar_session_track_system_variables_value
  | SESSION_TRACK_TRANSACTION_INFO= { $prng->arrayElement(['OFF','STATE','CHARACTERISTICS']) }
  | SESSION_TRACK_USER_VARIABLES= dynvar_boolean
  | SKIP_PARALLEL_REPLICATION= dynvar_boolean
  | SKIP_REPLICATION= dynvar_boolean
  | SLOW_QUERY_LOG= dynvar_boolean
  | SORT_BUFFER_SIZE= { $prng->arrayElement([16384,262144,1048576,2097152,4194304]) }
  | SQL_AUTO_IS_NULL= dynvar_boolean
  | SQL_BIG_SELECTS= dynvar_boolean
  | SQL_BUFFER_RESULT= dynvar_boolean
  | SQL_IF_EXISTS= dynvar_boolean
  | SQL_LOG_BIN= dynvar_boolean
# | SQL_LOG_OFF
  | SQL_MODE= dynvar_sql_mode_value
  | SQL_NOTES= dynvar_boolean
  | SQL_QUOTE_SHOW_CREATE= dynvar_boolean
  | SQL_SAFE_UPDATES= dynvar_boolean
  | SQL_SELECT_LIMIT= { $prng->arrayElement([0,1,1024,18446744073709551615,'DEFAULT']) }
  | SQL_SLAVE_SKIP_COUNTER= { $prng->int(0,2) }
  | SQL_WARNINGS= dynvar_boolean
  | STANDARD_COMPLIANT_CTE= dynvar_boolean
# | STORAGE_ENGINE # Deprecated
  | SYSTEM_VERSIONING_ALTER_HISTORY= { $prng->arrayElement(['ERROR','KEEP']) }
  | SYSTEM_VERSIONING_ASOF= { $prng->arrayElement(['DEFAULT',"'1970-01-01 00:00:00'","'2020-01-01 00:00:00'","'2050-01-01 00:00:00'"]) }
  | TCP_NODELAY= dynvar_boolean
  | THREAD_POOL_PRIORITY= { $prng->arrayElement(['DEFAULT','high','low','auto']) }
# | TIMESTAMP # Tempting, but causes problems, especially with versioning
  | TIME_ZONE= { sprintf("'%s%02d:%02d'",$prng->arrayElement(['+','-']),$prng->int(0,12),$prng->int(0,59)) }
  | TMP_DISK_TABLE_SIZE= { $prng->arrayElement(['DEFAULT',1024,8388608,18446744073709551615]) }
# | TMP_MEMORY_TABLE_SIZE # == tmp_table_size
  | TMP_TABLE_SIZE= { $prng->arrayElement(['DEFAULT',0,1024,4194304,16777216,4294967295]) }
  | TRANSACTION_ALLOC_BLOCK_SIZE= { $prng->arrayElement(['DEFAULT',1024,8192,16384,65536]) }
  | TRANSACTION_PREALLOC_SIZE= { $prng->arrayElement(['DEFAULT',1024,8192,16384,65536]) }
  | TX_ISOLATION= { $prng->arrayElement(["'READ-UNCOMMITTED'","'READ-COMMITTED'","'REPEATABLE-READ'","'SERIALIZABLE'"]) }
  | TX_READ_ONLY= dynvar_boolean
  | UNIQUE_CHECKS= dynvar_boolean
  | UPDATABLE_VIEWS_WITH_LIMIT= dynvar_boolean
  | USE_STAT_TABLES= { $prng->arrayElement(['NEVER','PREFERABLY','COMPLEMENTARY','COMPLEMENTARY_FOR_QUERIES /* compatibility 10.4.1 */','PREFERABLY_FOR_QUERIES /* compatibility 10.4.1 */']) }
  | WAIT_TIMEOUT= { $prng->arrayElement([0,3600]) }
  | WSREP_CAUSAL_READS= dynvar_boolean
  | WSREP_DIRTY_READS= dynvar_boolean
  | WSREP_GTID_SEQ_NO= { $prng->int(0,18446744073709551615) } /* compatibility 10.5.1 */
# Disabled due to MDEV-22443
# | WSREP_ON= dynvar_boolean
  | WSREP_OSU_METHOD= { $prng->arrayElement(['TOI','RSU']) }
  | WSREP_RETRY_AUTOCOMMIT= { $prng->int(0,10000) }
  | WSREP_SYNC_WAIT= { $prng->int(0,15) }
# Disabled due to MDEV-22148
#  | WSREP_TRX_FRAGMENT_SIZE= { $prng->arrayElement(['DEFAULT',0,1,16384,1048576]) }
  | WSREP_TRX_FRAGMENT_UNIT= { $prng->arrayElement(['bytes',"'rows'",'segments']) }
;

dynvar_global_variable:
  # MENT-599
    innodb_purge_threads = { $prng->int(0,33) } /* compatibility 10.5.2-0 */
  # MENT-661
  | innodb_read_io_threads = { $prng->int(0,65) } /* compatibility 10.5.2-0 */
  | innodb_write_io_threads = { $prng->int(0,65) } /* compatibility 10.5.2-0 */
  | net_buffer_length= { $prng->arrayElement([1024,4096,16384,65536,1048576]) }
;

dynvar_default_regex_flags_value:
    { @flags= qw(
          DOTALL
          DUPNAMES
          EXTENDED
          EXTRA
          MULTILINE
          UNGREEDY
        ); $length=$prng->int(0,scalar(@flags)); "'" . (join ',', @{$prng->shuffleArray(\@flags)}[0..$length]) . "'"
    }
;

dynvar_sql_mode_value:
    DEFAULT
    | { @modes= qw(
          ALLOW_INVALID_DATES
          ANSI
          ANSI_QUOTES
          DB2
          EMPTY_STRING_IS_NULL
          ERROR_FOR_DIVISION_BY_ZERO
          HIGH_NOT_PRECEDENCE
          IGNORE_BAD_TABLE_OPTIONS
          IGNORE_SPACE
          MSSQL
          MYSQL323
          MYSQL40
          NO_AUTO_CREATE_USER
          NO_AUTO_VALUE_ON_ZERO
          NO_BACKSLASH_ESCAPES
          NO_DIR_IN_CREATE
          NO_ENGINE_SUBSTITUTION
          NO_FIELD_OPTIONS
          NO_KEY_OPTIONS
          NO_TABLE_OPTIONS
          NO_UNSIGNED_SUBTRACTION
          NO_ZERO_IN_DATE
          ONLY_FULL_GROUP_BY
          PAD_CHAR_TO_FULL_LENGTH
          PIPES_AS_CONCAT
          POSTGRESQL
          REAL_AS_FLOAT
          SIMULTANEOUS_ASSIGNMENT
          STRICT_ALL_TABLES
          STRICT_TRANS_TABLES
          TIME_ROUND_FRACTIONAL
        ); $length=$prng->int(0,scalar(@modes)); "'" . (join ',', @{$prng->shuffleArray(\@modes)}[0..$length]) . "'"
    }
;

dynvar_log_slow_filter_value:
    DEFAULT
    | { @filters= qw(
          admin
          filesort
          filesort_on_disk
          filesort_priority_queue
          full_join
          full_scan
          query_cache
          query_cache_miss
          tmp_table
          tmp_table_on_disk
        ); $length=$prng->int(0,scalar(@filters)); "'" . (join ',', @{$prng->shuffleArray(\@filters)}[0..$length]) . "'"
    }
;

dynvar_log_slow_verbosity_value:
    { @vals= qw(
          query_plan
          innodb
          explain
        ); $length=$prng->int(0,scalar(@vals)); "'" . (join ',', @{$prng->shuffleArray(\@vals)}[0..$length]) . "'"
    }
;

dynvar_old_mode_value:
    { @modes= qw(
          NO_DUP_KEY_WARNINGS_WITH_IGNORE
          NO_PROGRESS_INFO
          ZERO_DATE_TIME_CAST
        ); $length=$prng->int(0,scalar(@modes)); "'" . (join ',', @{$prng->shuffleArray(\@modes)}[0..$length]) . "'"
    }
;

dynvar_optimizer_switch_value:
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
        ); $length=$prng->int(0,scalar(@modes)); "'" . (join ',', map {$_.'='.$prng->arrayElement(['on','off'])} @{$prng->shuffleArray(\@modes)}[0..$length]) . "'"
    }
;

dynvar_session_track_system_variables_value:
    { @vars= keys %{$executors->[0]->serverVariables()}
      ; $length=$prng->int(0,scalar(@vars)/2)
      ; "'" . (join ',', @{$prng->shuffleArray(\@vars)}[0..$length]) . "'"
    }
#  | '*'
  | DEFAULT
;

dynvar_boolean:
    0 | 1 ;

