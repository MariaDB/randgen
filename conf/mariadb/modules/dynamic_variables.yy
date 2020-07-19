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

thread1_init_add:
    SET GLOBAL dynvar_set_global_list ;

query_add:
    ==FACTOR:0.1==   SET SESSION dynvar_session_variable
  | ==FACTOR:0.001== SET GLOBAL dynvar_global_variable_runtime
;

dynvar_set_global_list:
                 dynvar_global_variable
  | ==FACTOR:3== dynvar_global_variable, dynvar_set_global_list
;

dynvar_global_variable_runtime:
    innodb_buffer_pool_dump_now= dynvar_boolean
  | innodb_buffer_pool_load_abort= dynvar_boolean
  | innodb_buffer_pool_load_now= dynvar_boolean
  | innodb_log_checkpoint_now= dynvar_boolean
;

dynvar_session_variable:
    alter_algorithm= { $prng->arrayElement(['DEFAULT','COPY','INPLACE','NOCOPY','INSTANT']) } /* compatibility 10.3.7 */
  | analyze_sample_percentage= { $prng->int(0,100) } /* compatibility 10.4.3 */
  | aria_repair_threads= { $prng->int(1,10) }
# Disabled due to MDEV-22500
# | ARIA_SORT_BUFFER_SIZE= { $prng->arrayElement([4096,16384,65536,1048576,134217728,268434432]) }
  | aria_stats_method= { $prng->arrayElement(['nulls_equal','nulls_unequal','nulls_ignored']) }
  | autocommit= dynvar_boolean
  | auto_increment_increment= { $prng->arrayElement([1,1,1,1,2,2,2,3,3,65535]) }
  | auto_increment_offset= { $prng->arrayElement([1,1,1,1,2,2,2,3,3,65534,65535]) }
# TODO: big_tables is deprecated in 10.5.0
  | big_tables= dynvar_boolean
  | binlog_annotate_row_events= dynvar_boolean
  | binlog_direct_non_transactional_updates= dynvar_boolean
  | binlog_format= { $prng->arrayElement(['MIXED','ROW','MIXED','ROW','MIXED','ROW','STATEMENT']) }
  | binlog_row_image= { $prng->arrayElement(['FULL','NOBLOB','MINIMAL']) }
  | bulk_insert_buffer_size= { $prng->arrayElement([0,1024,1048576,4194304,8388608]) }
  | character_set_client= _charset_name
  | character_set_connection= _charset_name
  | character_set_database= _charset_name
  | character_set_filesystem= _charset_name
  | character_set_results= _charset_name
  | character_set_server= _charset_name
  | check_constraint_checks= dynvar_boolean /* compatibility 10.2.1 */
  | collation_connection= _collation_name
  | collation_database= _collation_name
  | collation_server= _collation_name
  | column_compression_threshold= { $prng->arrayElement([0,8,100,1024,65535]) }
  | column_compression_zlib_level= { $prng->int(1,9) }
  | column_compression_zlib_strategy= { $prng->arrayElement(['DEFAULT_STRATEGY','FILTERED','HUFFMAN_ONLY','RLE','FIXED']) }
  | column_compression_zlib_wrap= dynvar_boolean
  | completion_type= { $prng->arrayElement([0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,2]) }
  | deadlock_search_depth_long= { $prng->int(0,33) }
  | deadlock_search_depth_short= { $prng->int(0,32) }
  | deadlock_timeout_long= { $prng->arrayElement([0,1,10000,50000000,4294967295]) }
  | deadlock_timeout_short= { $prng->arrayElement([0,1,10000,50000000,4294967295]) }
# | DEBUG
# | DEBUG_DBUG
# | DEBUG_SYNC
  | default_master_connection= { $prng->arrayElement(["''",'m1']) }
  | default_regex_flags= dynvar_default_regex_flags_value
  | default_storage_engine= DEFAULT
  | default_tmp_storage_engine= { $prng->arrayElement(['InnoDB','Aria','MyISAM','MEMORY']) }
  | default_week_format= { $prng->int(0,7) }
  | div_precision_increment= { $prng->int(0,30) }
  | enforce_storage_engine= { $prng->arrayElement(['DEFAULT','DEFAULT','DEFAULT','DEFAULT','DEFAULT','DEFAULT','DEFAULT','InnoDB','Aria','MyISAM','MEMORY']) }
  | eq_range_index_dive_limit= { $prng->arrayElement([0,1,200,10000]) }
  | expensive_subquery_limit= { $prng->arrayElement([0,1,10,100,1000,10000]) }
  | foreign_key_checks= dynvar_boolean
  | group_concat_max_len= { $prng->arrayElement([4,1024,65536,1048576]) }
  | gtid_domain_id= { $prng->int(0,5) }
  | gtid_seq_no= { $prng->int(0,4294967295) }
  | histogram_size= { $prng->int(0,255) }
  | histogram_type= { $prng->arrayElement(['SINGLE_PREC_HB','DOUBLE_PREC_HB']) }
# | IDENTITY= { $prng->int(0,4294967295) } # == last_insert_id
  | idle_readonly_transaction_timeout= { $prng->arrayElement([0,3600]) }
  | idle_transaction_timeout= { $prng->arrayElement([0,3600]) }
  | idle_write_transaction_timeout= { $prng->arrayElement([0,3600]) }
  | innodb_compression_default= dynvar_boolean
  | innodb_default_encryption_key_id= { $prng->int(1,10) }
  | innodb_ft_enable_stopword= dynvar_boolean
# | innodb_ft_user_stopword_table= { $prng->arrayElement(["''","'test/stop'","'test/t1'"]) }
  | innodb_lock_wait_timeout= { $prng->arrayElement(['DEFAULT',0,1]) }
  | innodb_strict_mode= dynvar_boolean
  | innodb_table_locks= dynvar_boolean
  | innodb_tmpdir= DEFAULT
  | insert_id= { $prng->int(0,4294967295) }
  | interactive_timeout= { $prng->arrayElement(['DEFAULT',0,1]) }
  | in_predicate_conversion_threshold= { $prng->arrayElement([0,1,2,100,1000,65536,4294967295]) }
  | join_buffer_size= { $prng->arrayElement([128,1024,65536,131072,262144]) }
  | join_buffer_space_limit= { $prng->arrayElement([2048,16384,131072,1048576,2097152]) }
  | join_cache_level= { $prng->int(0,8) }
  | keep_files_on_create= dynvar_boolean
  | last_insert_id= { $prng->int(0,4294967295) }
  | lc_messages= { $prng->arrayElement(['en_US','en_GB','fi_FI','ru_RU','zh_CN']) }
  | lc_time_names= { $prng->arrayElement(['en_US','en_GB','fi_FI','ru_RU','zh_CN']) }
  | lock_wait_timeout= { $prng->arrayElement(['DEFAULT',0,1]) }
  | log_disabled_statements= { $prng->arrayElement(["''",'sp','slave',"'slave,sp'"]) }
  | log_queries_not_using_indexes= dynvar_boolean
  | log_slow_admin_statements= dynvar_boolean
  | log_slow_disabled_statements= { $prng->arrayElement(["''",'sp','slave',"'slave,sp'"]) }
  | log_slow_filter= dynvar_log_slow_filter_value
  | log_slow_rate_limit= { $prng->int(1,1000) }
  | log_slow_slave_statements= dynvar_boolean
  | log_slow_verbosity= dynvar_log_slow_verbosity_value
  | log_warnings= { $prng->int(0,20) }
  | long_query_time= { $prng->int(0,600) }
  | low_priority_updates= dynvar_boolean
# | MAX_ALLOWED_PACKET # Dynamic conditionally
  | max_delayed_threads= { $prng->arrayElement([0,20,'DEFAULT']) }
  | max_error_count= { $prng->arrayElement([0,1,64,65535]) }
  | max_heap_table_size= { $prng->arrayElement([16384,65535,1048576,16777216]) }
# | MAX_INSERT_DELAYED_THREADS # == max_delayed_threads
  | max_join_size= { $prng->arrayElement(['DEFAULT',1,65535,18446744073709551615]) }
  | max_length_for_sort_data= { $prng->arrayElement(['DEFAULT',4,1024,1048576,8388608]) }
  | max_recursive_iterations= { $prng->arrayElement(['DEFAULT',0,1,1048576,4294967295]) }
# Disabled due to MDEV-22524
# | MAX_RELAY_LOG_SIZE= { $prng->arrayElement([0,4096,1048576,16777216]) }
  | max_rowid_filter_size= { $prng->arrayElement([1024,4096,65536,131072,1048576]) }
  | max_seeks_for_key= { $prng->arrayElement([1,4096,1048576,4294967295]) }
  | max_session_mem_used= { $prng->arrayElement([8192,1048576,4294967295,9223372036854775807,18446744073709551615]) }
  | max_sort_length= { $prng->arrayElement([8,512,1024,2048,4096,65535,1048576,8388608]) }
  | max_sp_recursion_depth= { $prng->int(0,255) }
  | max_statement_time= { $prng->arrayElement(['DEFAULT',0,1]) }
# | MAX_TMP_TABLES # Said to be unused
# | MAX_USER_CONNECTIONS # Dynamic conditionally
  | min_examined_row_limit= { $prng->arrayElement([0,1,1024,1048576,4294967295]) }
  | mrr_buffer_size= { $prng->arrayElement([8192,65535,262144,1048576]) }
  | myisam_repair_threads= { $prng->int(1,10) }
  | myisam_sort_buffer_size= { $prng->arrayElement([131072,1048576,268434432]) }
  | myisam_stats_method= { $prng->arrayElement(['nulls_equal','nulls_unequal','nulls_ignored']) }
# | NET_BUFFER_LENGTH # Doesn't seem to be dynamic
  | net_read_timeout= { $prng->int(10,60) }
  | net_retry_count= { $prng->int(1,100) }
  | net_write_timeout= { $prng->int(20,90) }
  | old= dynvar_boolean
# | OLD_ALTER_TABLE # == from 10.3.7 same as alter_algorithm
  | old_mode= dynvar_old_mode_value
  | old_passwords= dynvar_boolean
  | optimizer_prune_level= dynvar_boolean
  | optimizer_search_depth= { $prng->int(0,63) }
  | optimizer_selectivity_sampling_limit= { $prng->arrayElement([10,50,100,1000,10000]) }
  | optimizer_switch= dynvar_optimizer_switch_value
  | optimizer_trace= { "'enabled=".{ $prng->arrayElement(['on','off','default']) }."'" } /* compatibility 10.4.3 */
  | optimizer_trace_max_mem_size= { $prng->arrayElement([1,16384,1048576,8388608]) } /* compatibility 10.4.3 */
  | optimizer_use_condition_selectivity= { $prng->int(1,5) }
  | preload_buffer_size= { $prng->arrayElement([1024,8192,32768,1048576]) }
  | profiling= dynvar_boolean
  | profiling_history_size= { $prng->int(0,100) }
  | progress_report_time= { $prng->int(0,60) }
  | pseudo_slave_mode= dynvar_boolean
  | pseudo_thread_id= { $prng->int(0,1000) }
  | query_alloc_block_size= { $prng->arrayElement([1024,8192,16384,1048576]) }
  | query_cache_strip_comments= dynvar_boolean
# | QUERY_CACHE_TYPE= { $prng->int(0,2) } # Dynamic conditionally
  | query_cache_wlock_invalidate= dynvar_boolean
  | query_prealloc_size= { $prng->arrayElement([1024,8192,16384,24576,1048576]) }
  | rand_seed1= { $prng->int(0,18446744073709551615) }
  | rand_seed2= { $prng->int(0,18446744073709551615) }
  | range_alloc_block_size= { $prng->arrayElement([4096,8192,16384,1048576]) }
  | read_buffer_size= { $prng->arrayElement([8200,16384,131072,1048576]) }
  | read_rnd_buffer_size= { $prng->arrayElement([8200,65536,262144,1048576]) }
  | rowid_merge_buff_size= { $prng->arrayElement([0,65536,1048576,8388608]) }
  | server_id= { $prng->int(1,1000) }
  | session_track_schema= dynvar_boolean
  | session_track_state_change= dynvar_boolean
# Disabled due to MDEV-22524
  | session_track_system_variables= dynvar_session_track_system_variables_value
  | session_track_transaction_info= { $prng->arrayElement(['OFF','STATE','CHARACTERISTICS']) }
  | session_track_user_variables= dynvar_boolean
  | skip_parallel_replication= dynvar_boolean
  | skip_replication= dynvar_boolean
  | slow_query_log= dynvar_boolean
  | sort_buffer_size= { $prng->arrayElement([16384,262144,1048576,2097152,4194304]) }
  | sql_auto_is_null= dynvar_boolean
  | sql_big_selects= dynvar_boolean
  | sql_buffer_result= dynvar_boolean
  | sql_if_exists= dynvar_boolean
  | sql_log_bin= dynvar_boolean
# | SQL_LOG_OFF
  | sql_mode= dynvar_sql_mode_value
  | sql_notes= dynvar_boolean
  | sql_quote_show_create= dynvar_boolean
  | sql_safe_updates= dynvar_boolean
  | sql_select_limit= { $prng->arrayElement([0,1,1024,18446744073709551615,'DEFAULT']) }
  | sql_slave_skip_counter= { $prng->int(0,2) }
  | sql_warnings= dynvar_boolean
  | standard_compliant_cte= dynvar_boolean
# | STORAGE_ENGINE # Deprecated
  | system_versioning_alter_history= { $prng->arrayElement(['ERROR','KEEP']) }
  | system_versioning_asof= { $prng->arrayElement(['DEFAULT',"'1970-01-01 00:00:00'","'2020-01-01 00:00:00'","'2050-01-01 00:00:00'"]) }
  | tcp_nodelay= dynvar_boolean
  | thread_pool_priority= { $prng->arrayElement(['DEFAULT','high','low','auto']) }
# | TIMESTAMP # Tempting, but causes problems, especially with versioning
  | time_zone= { sprintf("'%s%02d:%02d'",$prng->arrayElement(['+','-']),$prng->int(0,12),$prng->int(0,59)) }
# Very low values disabled due to MDEV-23212
  | tmp_disk_table_size= { $prng->arrayElement(['DEFAULT',65536,8388608,18446744073709551615]) }
# | TMP_MEMORY_TABLE_SIZE # == tmp_table_size
  | tmp_table_size= { $prng->arrayElement(['DEFAULT',0,1024,4194304,16777216,4294967295]) }
  | transaction_alloc_block_size= { $prng->arrayElement(['DEFAULT',1024,8192,16384,65536]) }
  | transaction_prealloc_size= { $prng->arrayElement(['DEFAULT',1024,8192,16384,65536]) }
  | tx_isolation= { $prng->arrayElement(["'READ-UNCOMMITTED'","'READ-COMMITTED'","'REPEATABLE-READ'","'SERIALIZABLE'"]) }
  | tx_read_only= dynvar_boolean
  | unique_checks= dynvar_boolean
  | updatable_views_with_limit= dynvar_boolean
  | use_stat_tables= { $prng->arrayElement(['NEVER','PREFERABLY','COMPLEMENTARY','COMPLEMENTARY_FOR_QUERIES /* compatibility 10.4.1 */','PREFERABLY_FOR_QUERIES /* compatibility 10.4.1 */']) }
# | WAIT_TIMEOUT= { $prng->arrayElement([0,3600]) }
  | wsrep_causal_reads= dynvar_boolean
  | wsrep_dirty_reads= dynvar_boolean
  | wsrep_gtid_seq_no= { $prng->int(0,18446744073709551615) } /* compatibility 10.5.1 */
# Disabled due to MDEV-22443
# | WSREP_ON= dynvar_boolean
  | wsrep_osu_method= { $prng->arrayElement(['TOI','RSU']) }
  | wsrep_retry_autocommit= { $prng->int(0,10000) }
  | wsrep_sync_wait= { $prng->int(0,15) }
# Disabled due to MDEV-22148
# | WSREP_TRX_FRAGMENT_SIZE= { $prng->arrayElement(['DEFAULT',0,1,16384,1048576]) }
  | wsrep_trx_fragment_unit= { $prng->arrayElement(['bytes',"'rows'",'segments']) }
;

dynvar_global_variable:
    aria_checkpoint_interval= { $prng->int(0,300) }
  | aria_checkpoint_log_activity= { $prng->arrayElement([0,1024,8192,16384,65536,1048576,4194304,16777216]) }
# Disabled due to MDEV-18496
# | aria_encrypt_tables= dynvar_boolean
  | aria_group_commit= { $prng->arrayElement(['none','hard','soft']) }
  | aria_group_commit_interval= { $prng->arrayElement([0,1000,1000000,10000000,60000000]) }
  | aria_log_file_size= { $prng->arrayElement([65536,1048576,134217728,1073741824]) }
  | aria_log_purge_type= { $prng->arrayElement(['immediate','external','at_flush']) }
  | aria_max_sort_file_size= { $prng->arrayElement([65536,1048576,134217728,1073741824,9223372036854775807]) }
  | aria_pagecache_age_threshold= { $prng->arrayElement([100,1000,10000,9999900]) }
  | aria_pagecache_division_limit= { $prng->int(1,100) }
  | aria_page_checksum= dynvar_boolean
  | aria_recover_options= dynvar_recover_options_value
  | aria_sync_log_dir= { $prng->arrayElement(['NEWFILE','NEVER','ALWAYS']) }
  | automatic_sp_privileges= dynvar_boolean
  | binlog_cache_size= { $prng->arrayElement([4096,16384,1048576]) }
  | binlog_checksum= { $prng->arrayElement(['CRC32','NONE']) }
  | binlog_commit_wait_count= { $prng->arrayElement([1,10,100]) }
  | binlog_commit_wait_usec= { $prng->arrayElement([0,1000,1000000,10000000]) }
  | binlog_file_cache_size= { $prng->arrayElement([8192,65536,1048576]) }
  | binlog_row_metadata= { $prng->arrayElement(['NO_LOG','MINIMAL','FULL']) } /* compatibility 10.5.0 */
  | binlog_stmt_cache_size= { $prng->arrayElement([4096,65536,1048576]) }
  | concurrent_insert= { $prng->arrayElement(['AUTO','NEVER','ALWAYS']) }
# | connect_timeout
  | debug_binlog_fsync_sleep= { $prng->arrayElement([1000,500000,1000000]) }
  | default_password_lifetime= { $prng->arrayElement([150,300,600]) }
  | delayed_insert_limit= { $prng->arrayElement([1,50,1000,10000]) }
  | delayed_insert_timeout= { $prng->arrayElement([10,100,600]) }
  | delayed_queue_size= { $prng->arrayElement([10,100,10000]) }
  | delay_key_write= { $prng->arrayElement(['ON','OFF','ALL']) }
  | disconnect_on_expired_password= dynvar_boolean
# | encrypt_tmp_disk_tables
# | event_scheduler
  | expire_logs_days= { $prng->int(0,99) }
  | extra_max_connections= { $prng->int(1,10) }
  | flush= dynvar_boolean
  | flush_time= { $prng->arrayElement([1,30,300]) }
# | ft_boolean_syntax
# | general_log
# | general_log_file
  | gtid_binlog_state= ''
  | gtid_cleanup_batch_size= { $prng->int(0,10000) } /* compatibility 10.4.1 */
  | gtid_ignore_duplicates= dynvar_boolean
  | gtid_pos_auto_engines= dynvar_engines_list_value
  | gtid_slave_pos= ''
  | gtid_strict_mode= dynvar_boolean
  | host_cache_size= { $prng->arrayElement([0,1,2,10,16,100,1024]) }
  | init_connect= { "SELECT $$ as Perl_PID" }
  | init_slave= { "SELECT $$ as Perl_PID" }
  | innodb_adaptive_flushing= dynvar_boolean
  | innodb_adaptive_flushing_lwm= { $prng->int(0,70) }
  | innodb_adaptive_hash_index= dynvar_boolean
  | innodb_adaptive_max_sleep_delay= { $prng->arrayElement([0,1000,10000,100000,1000000]) }
  | innodb_autoextend_increment= { $prng->int(1,1000) }
# Debug variable
  | innodb_background_drop_list_empty= dynvar_boolean
# Deprecated since 10.5.2
  | innodb_background_scrub_data_check_interval= { $prng->arrayElement([1,10,60,300]) }
# Deprecated since 10.5.2
  | innodb_background_scrub_data_compressed= dynvar_boolean
# Deprecated since 10.5.2
  | innodb_background_scrub_data_interval= { $prng->arrayElement([10,100,300]) }
# Deprecated since 10.5.2
  | innodb_background_scrub_data_uncompressed= dynvar_boolean
  | innodb_buffer_pool_dump_at_shutdown= dynvar_boolean
  | innodb_buffer_pool_dump_pct= { $prng->int(1,100) }
  | innodb_buffer_pool_evict= { $prng->arrayElement(["''","'uncompressed'"]) }
  | innodb_buffer_pool_filename= 'ibbpool'
# Debug variable
  | innodb_buffer_pool_load_pages_abort= { $prng->arrayElement([1,100,1000,100000]) }
  | innodb_buffer_pool_size= { $prng->arrayElement([67108864,268435456,1073741824,2147483648]) }
  | innodb_buf_dump_status_frequency= { $prng->arrayElement([10,50,99]) }
# Debug variable
  | innodb_buf_flush_list_now= dynvar_boolean
  | innodb_change_buffering= { $prng->arrayElement(['inserts','none','deletes','purges','changes','all']) }
# Debug variable, 2 causes intentional crash
# | innodb_change_buffering_debug
  | innodb_change_buffer_max_size= { $prng->int(0,50) }
# Skipping strict values to avoid aborts
  | innodb_checksum_algorithm= { $prng->arrayElement(['full_crc32','crc32','innodb','none']) }
  | innodb_cmp_per_index_enabled= dynvar_boolean
# Can't really be set to non-default at runtime
# | innodb_commit_concurrency
  | innodb_compression_algorithm= { $prng->arrayElement(['none','zlib','lz4','lzo','lzma','bzip2','snappy']) }
  | innodb_compression_failure_threshold_pct= { $prng->int(0,100) }
  | innodb_compression_level= { $prng->int(1,9) }
  | innodb_compression_pad_pct_max= { $prng->int(0,75) }
  | innodb_concurrency_tickets= { $prng->arrayElement([1,2,10,100,1000,10000,100000]) }
  | innodb_deadlock_detect= dynvar_boolean
  | innodb_default_row_format= { $prng->arrayElement(['redundant','compact','dynamic']) }
  | innodb_defragment= dynvar_boolean
  | innodb_defragment_fill_factor= { $prng->arrayElement([0.7,0.8,0.9,1]) }
  | innodb_defragment_fill_factor_n_recs= { $prng->int(1,100) }
  | innodb_defragment_frequency= { $prng->arrayElement([1,2,100,1000]) }
  | innodb_defragment_n_pages= { $prng->int(2,32) }
  | innodb_defragment_stats_accuracy= { $prng->arrayElement([1,2,10,100,1000,10000]) }
  | innodb_dict_stats_disabled_debug= dynvar_boolean
  | innodb_disable_resize_buffer_pool_debug= dynvar_boolean
  | innodb_disable_sort_file_cache= dynvar_boolean
# This will make everything stop
# | innodb_disallow_writes= dynvar_boolean
  | innodb_encryption_rotate_key_age= { $prng->arrayElement([0,1,2,100,1000,10000,100000]) }
  | innodb_encryption_rotation_iops= { $prng->arrayElement([0,1,2,100,1000,10000]) }
  | innodb_encryption_threads= { $prng->arrayElement([0,1,2,4,8]) }
# | innodb_encrypt_tables
  | innodb_evict_tables_on_commit_debug= dynvar_boolean
  | innodb_fast_shutdown= { $prng->int(0,3) }
  | innodb_file_per_table= dynvar_boolean
  | innodb_fill_factor= { $prng->int(10,100) }
# | innodb_fil_make_page_dirty_debug
  | innodb_flushing_avg_loops= { $prng->arrayElement([1,2,10,100,1000]) }
  | innodb_flush_log_at_timeout= { $prng->arrayElement([0,1,2,10,100,300]) }
  | innodb_flush_log_at_trx_commit= { $prng->int(0,3) }
  | innodb_flush_neighbors= { $prng->int(0,2) }
  | innodb_flush_sync= dynvar_boolean
  | innodb_force_primary_key= dynvar_boolean
  | innodb_ft_aux_table= 'test/ft_innodb'
  | innodb_ft_enable_diag_print= dynvar_boolean
  | innodb_ft_num_word_optimize= { $prng->arrayElement([0,1,2,10,1000,10000]) }
  | innodb_ft_result_cache_limit= { $prng->arrayElement([1000000,10000000,100000000,1000000000,4000000000]) }
# | innodb_ft_server_stopword_table
  | innodb_idle_flush_pct= { $prng->int(0,100) }
  | innodb_immediate_scrub_data_uncompressed= dynvar_boolean
  | innodb_instant_alter_column_allowed= { $prng->arrayElement(['never','add_last','add_drop_reorder']) }
  | innodb_io_capacity= { $prng->arrayElement([100,500,1000]) }
  | innodb_io_capacity_max= { $prng->arrayElement([100,1000,5000]) }
  | innodb_limit_optimistic_insert_debug= { $prng->arrayElement([1,10,100,1000,10000]) }
  | innodb_log_checksums= dynvar_boolean
  | innodb_log_compressed_pages= dynvar_boolean
  | innodb_log_optimize_ddl= dynvar_boolean
  | innodb_log_write_ahead_size= { $prng->arrayElement([512,1024,10000,16384]) }
  | innodb_lru_scan_depth= { $prng->arrayElement([100,512,2048,16384]) }
# | innodb_master_thread_disabled_debug
  | innodb_max_dirty_pages_pct= { $prng->int(0,99) }
  | innodb_max_dirty_pages_pct_lwm= { $prng->int(0,99) }
  | innodb_max_purge_lag= { $prng->arrayElement([1,10,100,1000,10000]) }
  | innodb_max_purge_lag_delay= { $prng->arrayElement([100,1000,10000,100000]) }
  | innodb_max_undo_log_size= { $prng->arrayElement([10485760,41943040,167772160]) }
# | innodb_merge_threshold_set_all_debug
  | innodb_monitor_disable= '%'
  | innodb_monitor_enable= '%'
  | innodb_monitor_reset= '%'
  | innodb_monitor_reset_all= '%'
  | innodb_old_blocks_pct= { $prng->int(5,95) }
  | innodb_old_blocks_time= { $prng->arrayElement([0,100,10000,100000]) }
  | innodb_online_alter_log_max_size= { $prng->arrayElement([65536,33554432,268435456]) }
  | innodb_optimize_fulltext_only= dynvar_boolean
  | innodb_page_cleaners= { $prng->int(1,8) }
  | innodb_page_cleaner_disabled_debug= dynvar_boolean
  | innodb_prefix_index_cluster_optimization= dynvar_boolean
  | innodb_print_all_deadlocks= dynvar_boolean
  | innodb_purge_batch_size= { $prng->arrayElement([1,2,10,100,1000]) }
  | innodb_purge_rseg_truncate_frequency= { $prng->arrayElement([1,2,10,64]) }
  | innodb_random_read_ahead= dynvar_boolean
  | innodb_read_ahead_threshold= { $prng->int(0,64) }
  | innodb_replication_delay= { $prng->arrayElement([1,100,1000,10000]) }
# | innodb_saved_page_number_debug
# Deprecated since 10.5.2
  | innodb_scrub_log_speed= { $prng->arrayElement([1,2,16,1024]) }
# | innodb_simulate_comp_failures
  | innodb_spin_wait_delay= { $prng->arrayElement([1,2,16,1024]) }
  | innodb_stats_auto_recalc= dynvar_boolean
  | innodb_stats_include_delete_marked= dynvar_boolean
  | innodb_stats_method= { $prng->arrayElement(['nulls_equal','nulls_unequal','nulls_ignored']) }
  | innodb_stats_modified_counter= { $prng->arrayElement([1,2,16,1024]) }
  | innodb_stats_on_metadata= dynvar_boolean
  | innodb_stats_persistent= dynvar_boolean
  | innodb_stats_persistent_sample_pages= { $prng->arrayElement([1,2,10,100,1000]) }
  | innodb_stats_traditional= dynvar_boolean
  | innodb_stats_transient_sample_pages= { $prng->arrayElement([1,2,10,100,1000]) }
  | innodb_status_output= dynvar_boolean
  | innodb_status_output_locks= dynvar_boolean
  | innodb_sync_spin_loops= { $prng->arrayElement([0,1,2,10,100,1000]) }
  | innodb_thread_concurrency= { $prng->int(1,8) }
  | innodb_thread_sleep_delay= { $prng->arrayElement([0,100,1000,100000]) }
# | innodb_trx_purge_view_update_only_debug
# | innodb_trx_rseg_n_slots_debug
  | innodb_undo_logs= { $prng->int(0,128) }
  | innodb_undo_log_truncate= dynvar_boolean
  | key_buffer_size= { $prng->arrayElement([8,1024,1048576,16777216]) }
  | key_cache_age_threshold= { $prng->arrayElement([100,500,1000,10000]) }
  | key_cache_block_size= { $prng->arrayElement([512,2048,4096,16384]) }
  | key_cache_division_limit= { $prng->int(1,100) }
  | key_cache_file_hash_size= { $prng->int(128,16384) }
  | key_cache_segments= { $prng->int(1,64) }
  | local_infile= dynvar_boolean
  | log_bin_compress= dynvar_boolean
  | log_bin_compress_min_len= { $prng->int(10,1024) }
  | log_bin_trust_function_creators= dynvar_boolean
  | log_output= { $prng->arrayElement(["'FILE'","'TABLE,FILE'"]) }
  | master_verify_checksum= dynvar_boolean
  | max_binlog_cache_size= { $prng->arrayElement([1048576,16777216,1073741824]) }
  | max_binlog_size= { $prng->arrayElement([1048576,16777216,2147483648]) }
  | max_binlog_stmt_cache_size= { $prng->arrayElement([1048576,16777216,1073741824]) }
# | max_connections
# | max_connect_errors
  | max_password_errors= { $prng->arrayElement([128,1024,1048576]) }
  | max_prepared_stmt_count= { $prng->arrayElement([0,1,1024,1048576]) }
  | max_write_lock_count= { $prng->arrayElement([0,1,1024,1048576]) }
  | myisam_data_pointer_size= { $prng->int(2,7) }
  | myisam_max_sort_file_size= { $prng->arrayElement([0,1,1024,1048576,33554432,268435456,1073741824]) }
  | myisam_use_mmap= dynvar_boolean
  | mysql56_temporal_format= dynvar_boolean
  | proxy_protocol_networks= '*' /* compatibility 10.3.1 */
  | query_cache_limit= { $prng->arrayElement([0,1,8,1024,1048576,4294967295]) }
  | query_cache_min_res_unit= { $prng->arrayElement([0,1,8,1024,1048576,4294967295]) }
  | query_cache_size= { $prng->arrayElement([0,1024,8192,1048576,134217728]) }
  | read_binlog_speed_limit= { $prng->arrayElement([1024,8192,1048576,134217728]) }
  | read_only= dynvar_boolean
  | relay_log_purge= dynvar_boolean
  | relay_log_recovery= dynvar_boolean
  | replicate_do_db= 'test'
# | replicate_do_table
  | replicate_events_marked_for_skip= { $prng->arrayElement(['REPLICATE','FILTER_ON_SLAVE','FILTER_ON_MASTER']) }
  | replicate_ignore_db= 'mysql'
  | replicate_ignore_table= 'test.dummy'
  | replicate_wild_do_table= 'test.%,mysql.%'
  | replicate_wild_ignore_table= 'mysql.%'
# | require_secure_transport
  | rpl_semi_sync_master_enabled= dynvar_boolean
  | rpl_semi_sync_master_timeout= { $prng->arrayElement([0,1,1000,100000]) }
  | rpl_semi_sync_master_trace_level= { $prng->arrayElement([1,16,32,64]) }
  | rpl_semi_sync_master_wait_no_slave= dynvar_boolean
  | rpl_semi_sync_master_wait_point= { $prng->arrayElement(['AFTER_COMMIT','AFTER_SYNC']) }
  | rpl_semi_sync_slave_delay_master= dynvar_boolean
  | rpl_semi_sync_slave_enabled= dynvar_boolean
  | rpl_semi_sync_slave_kill_conn_timeout= { $prng->arrayElement([0,1,10,100]) }
  | rpl_semi_sync_slave_trace_level= { $prng->arrayElement([1,16,32,64]) }
  | secure_auth= dynvar_boolean
  | slave_compressed_protocol= dynvar_boolean
  | slave_ddl_exec_mode= { $prng->arrayElement(['IDEMPOTENT','STRICT']) }
  | slave_domain_parallel_threads= { $prng->int(1,8) }
  | slave_exec_mode= { $prng->arrayElement(['IDEMPOTENT','STRICT']) }
# | slave_max_allowed_packet
# | slave_net_timeout
  | slave_parallel_max_queued= { $prng->arrayElement([0,1,2,1024,16384,1048576]) }
  | slave_parallel_mode= { $prng->arrayElement(['conservative','optimistic','none','aggressive','minimal']) }
  | slave_parallel_threads= { $prng->int(1,8) }
# | slave_parallel_workers # Same as slave_parallel_threads
  | slave_run_triggers_for_rbr= { $prng->arrayElement(['NO','YES','LOGGING','ENFORCE']) }
  | slave_sql_verify_checksum= dynvar_boolean
  | slave_transaction_retries= { $prng->int(0,1000) }
  | slave_transaction_retry_interval= { $prng->arrayElement([1,2,10,60,300]) }
  | slave_type_conversions= { $prng->arrayElement(['ALL_LOSSY','ALL_NON_LOSSY']) }
  | slow_launch_time= { $prng->int(0,300) }
# | slow_query_log_file
  | stored_program_cache= { $prng->arrayElement([257,1024,4096,524288]) }
  | strict_password_validation= dynvar_boolean
  | sync_binlog= { $prng->arrayElement([1,2,4,128,1024]) }
  | sync_frm= dynvar_boolean
  | sync_master_info= { $prng->arrayElement([0,1,100,100000]) }
  | sync_relay_log= { $prng->arrayElement([0,1,100,100000]) }
  | sync_relay_log_info= { $prng->arrayElement([0,1,100,100000]) }
# | table_definition_cache
  | table_open_cache= { $prng->arrayElement([1,2,10,100]) }
  | tcp_keepalive_interval= { $prng->int(1,300) }
  | tcp_keepalive_probes= { $prng->int(1,300) }
  | tcp_keepalive_time= { $prng->int(1,300) }
  | thread_cache_size= { $prng->arrayElement([1,2,8,128]) }
  | thread_pool_dedicated_listener= dynvar_boolean
  | thread_pool_exact_stats= dynvar_boolean
  | thread_pool_idle_timeout= { $prng->int(0,300) }
  | thread_pool_max_threads= { $prng->arrayElement([1,2,128,500,1000]) }
  | thread_pool_oversubscribe= { $prng->int(1,16) }
  | thread_pool_prio_kickup_timer= { $prng->arrayElement([0,1,2,128,500,10000]) }
  | thread_pool_size= { $prng->int(1,128) }
  | thread_pool_stall_limit= { $prng->arrayElement([10,100,1000,10000]) }
  | userstat= dynvar_boolean
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
# | wsrep_ignore_apply_errors       global
# | wsrep_load_data_splitting       global
# | wsrep_log_conflicts     global
# | wsrep_max_ws_rows       global
# | wsrep_max_ws_size       global
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
# | wsrep_sst_auth  global
# | wsrep_sst_donor global
# | wsrep_sst_donor_rejects_queries global
# | wsrep_sst_method        global
# | wsrep_sst_receive_address       global
# | wsrep_start_position    global
# | wsrep_strict_ddl        global
# MENT-599
  | innodb_purge_threads= { $prng->int(0,33) } /* compatibility 10.5.2-0 */
# MENT-661
  | innodb_read_io_threads= { $prng->int(0,65) } /* compatibility 10.5.2-0 */
  | innodb_write_io_threads= { $prng->int(0,65) } /* compatibility 10.5.2-0 */
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
# Disabled due to MDEV-22524
#  | '*'
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
        ); $length=$prng->int(0,scalar(@filters)); "'" . (join ',', @{$prng->shuffleArray(\@filters)}[0..$length]) . "'"
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
        ); $length=$prng->int(0,scalar(@filters)); "'" . (join ',', @{$prng->shuffleArray(\@filters)}[0..$length]) . "'"
    }
;

dynvar_boolean:
    0 | 1 ;

