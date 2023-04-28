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
#
# Rules are named according to the names of folders and files in source
# code, e.g.
# sql_debug_sync are debug syncpoints in sql/*
# sql_table_debug_sync are debug syncpoints in sql/sql_table.cc
# etc.
#

query:
               SET debug_sync= RESET |
  ==FACTOR:4== SET debug_sync= 'now SIGNAL goforit' |
               SET debug_sync= sql_debug_sync
;

sql_debug_sync:
  ==FACTOR:1== admin_debug_sync |
  ==FACTOR:2== filesort_debug_sync |
  ==FACTOR:15== handler_debug_sync |
  ==FACTOR:2== ha_partition_debug_sync |
  ==FACTOR:1== item_debug_sync |
  ==FACTOR:1== item_func_debug_sync |
  ==FACTOR:4== lock_debug_sync |
  ==FACTOR:28== log_debug_sync |
  ==FACTOR:2== mdl_debug_sync |
  ==FACTOR:8== rpl_parallel_debug_sync |
  ==FACTOR:1== semisync_master_debug_sync |
  ==FACTOR:2== service_wsrep_debug_sync |
  ==FACTOR:1== sp_head_debug_sync |
  ==FACTOR:5== sql_admin_debug_sync |
  ==FACTOR:13== sql_base_debug_sync |
  ==FACTOR:7== sql_cache_debug_sync |
  ==FACTOR:4== sql_class_debug_sync |
  ==FACTOR:1== sql_db_debug_sync |
  ==FACTOR:7== sql_insert_debug_sync |
  ==FACTOR:10== sql_parse_debug_sync |
  ==FACTOR:3== sql_partition_admin_debug_sync |
  ==FACTOR:1== sql_plugin_debug_sync |
  ==FACTOR:1== sql_reload_debug_sync |
  ==FACTOR:2== sql_repl_debug_sync |
  ==FACTOR:2== sql_select_debug_sync |
  ==FACTOR:4== sql_show_debug_sync |
  ==FACTOR:7== sql_statistics_debug_sync |
  ==FACTOR:30== sql_table_debug_sync |
  ==FACTOR:1== sql_truncate_debug_sync |
  ==FACTOR:3== sql_udf_debug_sync |
  ==FACTOR:1== sql_view_debug_sync |
  ==FACTOR:1== table_cache_debug_sync |
  ==FACTOR:1== table_debug_sync |
  ==FACTOR:1== threadpool_common_debug_sync |
  ==FACTOR:1== transaction_debug_sync |
  ==FACTOR:1== wsrep_client_service_debug_sync |
  ==FACTOR:2== xa_debug_sync
;

admin_debug_sync:
  'ha_admin_try_alter WAIT_FOR goforit' ;

filesort_debug_sync:
  'filesort_start WAIT_FOR goforit' |
  'after_index_merge_phase1 WAIT_FOR goforit' ;

handler_debug_sync:
  'after_set_transaction_psi_before_set_transaction_gtid WAIT_FOR goforit' |
  'at_unlog_xa_prepare WAIT_FOR goforit' |
  'ha_commit_trans_after_acquire_commit_lock WAIT_FOR goforit' |
  'ha_commit_trans_after_prepare WAIT_FOR goforit' |
  'ha_commit_trans_before_log_and_order WAIT_FOR goforit' |
  'ha_commit_trans_after_log_and_order WAIT_FOR goforit' |
  'after_group_after_commit WAIT_FOR goforit' |
  'ha_commit_one_phase WAIT_FOR goforit' |
  'commit_one_phase_2 WAIT_FOR goforit' |
  'handler_rnd_next_end WAIT_FOR goforit' |
  'handler_ha_index_next_end WAIT_FOR goforit' |
  'handler_index_cond_check WAIT_FOR goforit' |
  'handler_rowid_filter_check WAIT_FOR goforit' |
  'ha_write_row_start WAIT_FOR goforit' |
  'ha_write_row_end WAIT_FOR goforit'
;

ha_partition_debug_sync:
  'before_rename_partitions WAIT_FOR goforit' |
  'partition_open_error WAIT_FOR goforit'
;

item_debug_sync:
  'after_Item_default_value_calculate WAIT_FOR goforit' ;

item_func_debug_sync:
  'before_acos_function WAIT_FOR goforit' ;

lock_debug_sync:
  'after_wait_locked_schema_name WAIT_FOR goforit' |
  'before_wait_locked_pname WAIT_FOR goforit' |
  'after_wait_locked_pname WAIT_FOR goforit' |
  'ftwrl_before_lock WAIT_FOR goforit'
;

log_debug_sync:
  'binlog_open_before_update_index WAIT_FOR goforit' |
  'reset_logs_after_set_reset_master_pending WAIT_FOR goforit' |
  'at_purge_logs_before_date WAIT_FOR goforit' |
  'after_purge_logs_before_date WAIT_FOR goforit' |
  'rotate_after_acquire_LOCK_log WAIT_FOR goforit' |
  'rotate_after_rotate WAIT_FOR goforit' |
  'group_commit_waiting_for_prior WAIT_FOR goforit' |
  'group_commit_waiting_for_prior_killed WAIT_FOR goforit' |
  'commit_before_enqueue WAIT_FOR goforit' |
  'commit_before_prepare_ordered WAIT_FOR goforit' |
  'commit_after_prepare_ordered WAIT_FOR goforit' |
  'commit_after_release_LOCK_prepare_ordered WAIT_FOR goforit' |
  'after_semisync_queue WAIT_FOR goforit' |
  'commit_loop_entry_commit_ordered WAIT_FOR goforit' |
  'commit_after_group_run_commit_ordered WAIT_FOR goforit' |
  'commit_before_get_LOCK_log WAIT_FOR goforit' |
  'commit_after_get_LOCK_log WAIT_FOR goforit' |
  'commit_before_update_binlog_end_pos WAIT_FOR goforit' |
  'commit_before_get_LOCK_after_binlog_sync WAIT_FOR goforit' |
  'commit_after_release_LOCK_log WAIT_FOR goforit' |
  'commit_before_get_LOCK_commit_ordered WAIT_FOR goforit' |
  'commit_after_release_LOCK_after_binlog_sync WAIT_FOR goforit' |
  'commit_loop_entry_commit_ordered WAIT_FOR goforit' |
  'commit_after_group_run_commit_ordered WAIT_FOR goforit' |
  'commit_after_group_release_commit_ordered WAIT_FOR goforit' |
  'commit_after_run_commit_ordered WAIT_FOR goforit' |
  'binlog_after_log_and_order WAIT_FOR goforit' |
  'binlog_background_thread_before_mark_xid_done WAIT_FOR goforit'
;

mdl_debug_sync:
  'mdl_acquire_lock_wait WAIT_FOR goforit' |
  'mdl_upgrade_lock WAIT_FOR goforit'
;

rpl_parallel_debug_sync:
  'rpl_parallel_start_waiting_for_prior WAIT_FOR goforit' |
  'rpl_parallel_start_waiting_for_prior_killed WAIT_FOR goforit' |
  'rpl_parallel_retry_after_unmark WAIT_FOR goforit' |
  'rpl_parallel_simulate_wait_at_retry WAIT_FOR goforit' |
  'rpl_parallel_before_mark_start_commit WAIT_FOR goforit' |
  'rpl_parallel_after_mark_start_commit WAIT_FOR goforit' |
  'rpl_parallel_simulate_temp_err_xid WAIT_FOR goforit' |
  'rpl_parallel_end_of_group WAIT_FOR goforit'
;

semisync_master_debug_sync:
  'rpl_semisync_master_commit_trx_before_lock WAIT_FOR goforit' ;

service_wsrep_debug_sync:
  'wsrep_before_SR_rollback WAIT_FOR goforit' |
  'before_wsrep_ordered_commit WAIT_FOR goforit'
;

sp_head_debug_sync:
  'sp_head_execute_before_loop WAIT_FOR goforit' ;

sql_admin_debug_sync:
  'ha_admin_try_alter WAIT_FOR goforit' |
  'admin_command_kill_before_modify WAIT_FOR goforit' |
  'after_admin_flush WAIT_FOR goforit' |
  'ha_admin_open_ltable WAIT_FOR goforit' |
  'admin_command_kill_after_modify WAIT_FOR goforit'
;

sql_base_debug_sync:
  'after_flush_unlock WAIT_FOR goforit' |
  'after_purge_tables WAIT_FOR goforit' |
  'before_tc_release_table WAIT_FOR goforit' |
  'before_close_thread_tables WAIT_FOR goforit' |
  'reopen_history_partition WAIT_FOR goforit' |
  'before_open_table_wait_refresh WAIT_FOR goforit' |
  'after_open_table_mdl_shared WAIT_FOR goforit' |
  'add_history_partition WAIT_FOR goforit' |
  'open_and_process_table WAIT_FOR goforit' |
  'create_table_before_check_if_exists WAIT_FOR goforit' |
  'open_tables_after_open_and_process_table WAIT_FOR goforit' |
  'before_lock_tables_takes_lock WAIT_FOR goforit' |
  'after_lock_tables_takes_lock WAIT_FOR goforit'
;

sql_cache_debug_sync:
  'wait_in_query_cache_insert WAIT_FOR goforit' |
  'wait_in_query_cache_store_query WAIT_FOR goforit' |
  'wait_after_query_cache_invalidate WAIT_FOR goforit' |
  'wait_in_query_cache_flush1 WAIT_FOR goforit' |
  'wait_in_query_cache_flush2 WAIT_FOR goforit' |
  'wait_in_query_cache_invalidate1 WAIT_FOR goforit' |
  'wait_in_query_cache_invalidate2 WAIT_FOR goforit'
;

sql_class_debug_sync:
  'THD_cleanup_after_set_killed WAIT_FOR goforit' |
  'thd_report_wait_for WAIT_FOR goforit' |
  'wait_for_prior_commit_waiting WAIT_FOR goforit' |
  'wait_for_prior_commit_killed WAIT_FOR goforit'
;

sql_db_debug_sync:
  'before_db_dir_check WAIT_FOR goforit' ;

sql_insert_debug_sync:
  'before_write_delayed WAIT_FOR goforit' |
  'after_write_delayed WAIT_FOR goforit' |
  'write_row_replace WAIT_FOR goforit' |
  'write_row_noreplace WAIT_FOR goforit' |
  'create_table_select_before_create WAIT_FOR goforit' |
  'create_table_select_before_open WAIT_FOR goforit' |
  'create_table_select_before_lock WAIT_FOR goforit'
;

sql_parse_debug_sync:
  'before_do_command_net_read WAIT_FOR goforit' |
  'wsrep_before_before_command WAIT_FOR goforit' |
  'dispatch_command_before_set_time WAIT_FOR goforit' |
  'dispatch_command_end WAIT_FOR goforit' |
  'before_execute_sql_command WAIT_FOR goforit' |
  'after_mysql_insert WAIT_FOR goforit' |
  'execute_command_after_close_tables WAIT_FOR goforit' |
  'wsrep_after_statement_enter WAIT_FOR goforit' |
  'found_killee WAIT_FOR goforit' |
  'before_awake_no_mutex WAIT_FOR goforit'
;

sql_partition_admin_debug_sync:
  'swap_partition_after_compare_tables WAIT_FOR goforit' |
  'swap_partition_after_wait WAIT_FOR goforit' |
  'swap_partition_before_rename WAIT_FOR goforit'
;

sql_plugin_debug_sync:
  'acquired_LOCK_plugin WAIT_FOR goforit' ;

sql_reload_debug_sync:
  'flush_tables_with_read_lock_after_acquire_locks WAIT_FOR goforit';

sql_repl_debug_sync:
  'after_show_binlog_events WAIT_FOR goforit' |
  'at_after_lock_index WAIT_FOR goforit'
;

sql_select_debug_sync:
  'before_join_optimize WAIT_FOR goforit' |
  'inside_make_join_statistics WAIT_FOR goforit'
;

sql_show_debug_sync:
  'fill_schema_processlist_after_unow WAIT_FOR goforit' |
  'after_open_table_ignore_flush WAIT_FOR goforit' |
  'before_open_in_get_all_tables WAIT_FOR goforit' |
  'get_schema_column WAIT_FOR goforit'
;

sql_statistics_debug_sync:
  'statistics_collection_start1 WAIT_FOR goforit' |
  'statistics_collection_start2 WAIT_FOR goforit' |
  'statistics_collection_start WAIT_FOR goforit' |
  'statistics_update_start WAIT_FOR goforit' |
  'statistics_mem_alloc_start1 WAIT_FOR goforit' |
  'statistics_mem_alloc_start2 WAIT_FOR goforit' |
  'statistics_read_start WAIT_FOR goforit'
;

sql_table_debug_sync:
  'rm_table_no_locks_before_delete_table WAIT_FOR goforit' |
  'rm_table_no_locks_before_binlog WAIT_FOR goforit' |
  'locked_table_name WAIT_FOR goforit' |
  'create_table_like_after_open WAIT_FOR goforit' |
  'create_table_like_before_binlog WAIT_FOR goforit' |
  'alter_table_enable_indexes WAIT_FOR goforit' |
  'alter_table_inplace_after_lock_upgrade WAIT_FOR goforit' |
  'alter_table_inplace_after_lock_downgrade WAIT_FOR goforit' |
  'alter_table_inplace_before_lock_upgrade WAIT_FOR goforit' |
  'alter_table_inplace_before_commit WAIT_FOR goforit' |
  'alter_table_inplace_after_commit WAIT_FOR goforit' |
  'alter_table_before_open_tables WAIT_FOR goforit' |
  'alter_table_after_open_tables WAIT_FOR goforit' |
  'alter_opened_table WAIT_FOR goforit' |
  'locked_table_name WAIT_FOR goforit' |
  'alter_table_before_create_table_no_lock WAIT_FOR goforit' |
  'alter_table_copy_after_lock_upgrade WAIT_FOR goforit' |
  'alter_table_intermediate_table_created WAIT_FOR goforit' |
  'alter_table_before_rename_result_table WAIT_FOR goforit' |
  'alter_table_before_main_binlog WAIT_FOR goforit' |
  'alter_table_inplace_trans_commit WAIT_FOR goforit' |
  'alter_table_after_temp_table_drop WAIT_FOR goforit' |
  'alter_table_after_temp_table_drop WAIT_FOR goforit' |
  'alter_table_copy_trans_commit WAIT_FOR goforit' |
  'alter_table_online_progress WAIT_FOR goforit' |
  'alter_table_online_downgraded WAIT_FOR goforit' |
  'copy_data_between_tables_before WAIT_FOR goforit' |
  'alter_table_copy_end WAIT_FOR goforit' |
  'alter_table_online_before_lock WAIT_FOR goforit' |
  'copy_data_between_tables_before_reset_backup_lock WAIT_FOR goforit'
;

sql_truncate_debug_sync:
  'upgrade_lock_for_truncate WAIT_FOR goforit';

sql_udf_debug_sync:
  'find_udf_before_lock WAIT_FOR goforit' |
  'mysql_create_function_after_lock WAIT_FOR goforit' |
  'mysql_drop_function_after_lock WAIT_FOR goforit'
;

sql_view_debug_sync:
  'after_cached_view_opened WAIT_FOR goforit' ;

table_cache_debug_sync:
  'before_wait_for_refs WAIT_FOR goforit' ;

table_debug_sync:
  'TABLE_after_field_clone WAIT_FOR goforit' ;

threadpool_common_debug_sync:
  'before_do_command_net_read WAIT_FOR goforit' ;

transaction_debug_sync:
  'after_set_transaction_psi_before_set_transaction_gtid WAIT_FOR goforit' ;

wsrep_client_service_debug_sync:
  'wsrep_before_fragment_removal WAIT_FOR goforit' ;

xa_debug_sync:
  'xa_after_search WAIT_FOR goforit' |
  'trans_xa_commit_after_acquire_commit_lock WAIT_FOR goforit'
;
