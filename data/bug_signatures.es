# Bug signatures for recognizing known bugs by server and test logs

##############################################################################
# Strong matches
##############################################################################

MENT-809:
=~ mariabackup: Aria engine: starting recovery
=~ Got error 127 when executing|Got error 175 when executing
MENT-808:
=~ signal|AddressSanitizer|\`page_offset != 0 && page_offset <= page_length && page_length + length <= max_page_size'|\`page_offset - length <= page_length'|\`page_offset >= keypage_header && page_offset <= page_length'|\`page_offset != 0 && page_offset + length <= page_length'
=~ mariabackup
=~ exec_REDO_LOGREC_REDO_INDEX
=~ maria_apply_log
MENT-368:
=~ Assertion \`inline_mysql_file_tell(.*, file, (myf) (0)) == base_pos+ (16 + 5\*8 + 6\*4 + 11\*2 + 6 + 5\*2 + 1 + 16)'
=~ maria_create
=~ create_internal_tmp_table
MENT-361:
=~ AddressSanitizer: heap-use-after-free
=~ filter_query_type
=~ log_statement
=~ Prepared_statement
MENT-328:
=~ mariabackup: File '.*seq.*MAI' not found (Errcode: 2 "No such file or directory")
=~ Error on aria table file open .*seq.*MAI
=~ Version: '10\.[3-4]
MENT-328:
=~ scenario=MariaBackup
=~ For  BASE TABLE ROW_FORMAT= .* : Error : Can't find file: '.*seq.*MAI' (errno: 2 "No such file or directory")
=~ status STATUS_BACKUP_FAILURE
=~ Version: '10\.[3-4]
MENT-319:
=~ Assertion \`backup_flush_ticket == 0'
=~ backup_start
MENT-264:
=~ Error on file .*\.M.* open during .* table copy
MENT-263:
=~ server_audit2
=~ Assertion \`global_status_var\.global_memory_used == 0'
=~ mysqld_exit
=~ Version: '10\.4
# Fixed in CS 10.4+, but affects ES 10.2-10.3
MDEV-18286: [pagecache->cnt_for_resize_op == 0]
=~ Assertion \`pagecache->cnt_for_resize_op == 0'
=~ check_pagecache_is_cleaned_up
=~ plugin_shutdown
=~ Version: '10\.[2-3]
# Only 10.5 CS, but also 10.4 ES
MDEV-22913:
=~ error: can't open
=~ Error: xtrabackup_apply_delta(): failed to apply
=~ Version: '10\.4

##########
# Fixed in the next release
##########

MDEV-20661:
=~ Assertion \`btr_validate_index(index, 0)'
=~ row_upd_sec_index_entry
=~ ha_innobase::delete_row
=~ DELETE HISTORY
MDEV-12059:
=~ Assertion \`precision > 0'
=~ decimal_bin_size
=~ Field_new_decimal::create_from_item
=~ create_tmp_table
=~  OVER
=~ Version: '10\.[2-9]
MDEV-18371:
=~ Conditional jump or move depends on uninitialised value|signal 11|AddressSanitizer: SEGV
=~ cmp_key_rowid_part_id
=~ ha_partition::handle_ordered_index_scan|ha_partition::handle_ordered_next
MDEV-21619:
=~ signal 11
=~ my_datetime_to_str
=~ Datetime::to_string|my_TIME_to_str
=~ Item::print_value
=~ Version: '10\.[2-9]
MDEV-21619:
=~ Assertion \`fsp <= 6'|Assertion \`digits <= 6'
=~ my_mmssff_to_str|my_datetime_to_str
=~ my_TIME_to_str
=~ Version: '10\.[2-9]
MDEV-22222:
=~ Assertion \`state() == s_executing \|\| state() == s_preparing \|\| state() == s_prepared \|\| state() == s_must_abort \|\| state() == s_aborting \|\| state() == s_cert_failed \|\| state() == s_must_replay'
=~ wsrep::transaction::before_rollback
=~ Version: '10\.[4-9]
MDEV-22370:
=~ safe_mutex: Trying to lock uninitialized mutex at .*/sql/rpl_parallel\.cc|Got error 22 when trying to lock mutex LOCK_rpl_thread_pool
=~ rpl_pause_for_ftwrl|rpl_unpause_after_ftwrl
=~ Version: '10\.[4-9]
MDEV-22390:
=~ Assertion \`m_next_rec_ptr >= m_rawmem'
=~ Filesort_buffer::spaceleft
=~ SORT_INFO::isfull
MDEV-22520:
=~ Assertion \`gathered_length == thd->lex->comment\.length'
=~ binlog_defragment
=~ mysql_client_binlog_statement
MDEV-22553:
=~ Assertion \`info->lastpos == (~ (my_off_t) 0)'
=~ mi_rkey
=~ Mrr_simple_index_reader
=~ QUICK_RANGE_SELECT
=~ Version: '10\.[4-9]
MDEV-22771:
=~ Assertion \`c\.same_type(\*o)'|Assertion \`fields\[i\]\.same(instant\.fields\[i\])'
=~ dict_table_t::instant_column
=~ Version: '10\.[4-9]
MDEV-22866:
=~ signal|AddressSanitizer
=~ JOIN::fix_all_splittings_in_plan
=~ not_null_range_scan=on
=~ Version: '10\.[5-9]
MDEV-22866:
=~ Assertion \`join->best_read < double(1\.79769313486231570815e+308L)'
=~ greedy_search
=~ not_null_range_scan=on
=~ Version: '10\.[5-9]
MDEV-22890:
=~ FATAL.* InnoDB: .* Deadlock Detected
=~ Thread .* has waited at row0sel\.cc line|Thread .* has waited at row0row\.cc line
=~ Thread .* has waited at row0quiesce\.cc line
=~ Thread .* has waited at btr0cur\.cc line
=~ Version: '10\.[5-9]
MDEV-22899:
=~ Assertion \`field->col->is_binary() \|\| field->prefix_len % field->col->mbmaxlen == 0'
=~ dict_index_add_to_cache
=~ create_index_dict
=~ Version: '10\.[4-9]
MDEV-22899:
=~ InnoDB: Failing assertion: !(prefix_len % mbmaxlen)
=~ dtype_validate
=~ row_merge_read_clustered_index
=~ Version: '10\.[4-9]
MDEV-22970:
=~ Assertion \`!m_freed_pages'
=~ mtr_t::init
=~ fsp_init_file_page
=~ Version: '10\.[5-9]
MDEV-23241:
=~ Assertion \`lock->trx->dict_operation != TRX_DICT_OP_NONE'
=~ lock_check_dict_lock
=~ commit_in_memory
=~ Version: '10\.[4-9]
MDEV-23240:
=~ Assertion \`!table->is_temporary()'
=~ lock_check_dict_lock
=~ commit_in_memory
=~ Version: '10\.[4-9]
MDEV-23239:
=~ InnoDB: Failing assertion: ((list)\.init == UT_LIST_INITIALISED)
=~ ut_list_remove
=~ trx_commit_in_memory
=~ Version: '10\.[3-9]
MDEV-22061:
=~ was not found on update: TUPLE
=~ Assertion \`btr_validate_index(index, 0, false)'
=~ row_upd_sec_index_entry
=~ Version: '10\.3
=~ versioning
MDEV-22061:
=~ was not found on update: TUPLE
=~ Assertion \`btr_validate_index(index, 0)'
=~ row_upd_sec_index_entry
=~ Version: '10\.[4-9]
=~ versioning
MDEV-22816:
=~ Assertion \`node->space == fil_system\.sys_space'
=~ fil_aio_callback
=~ tpool::task_group::execute
=~ Version: '10\.5
MDEV-22758:
=~ Assertion \`!item->null_value'
=~ Type_handler_inet6::make_sort_key_part
MDEV-22751:
=~ signal|AddressSanitizer
=~ dict_acquire_mdl_shared
=~ row_purge
=~ Version: '10\.5
MDEV-22746:
=~ Assertion \`(&(&pagecache->cache_lock)->m_mutex)->count > 0 && pthread_equal(pthread_self(), (&(&pagecache->cache_lock)->m_mutex)->thread)'
=~ dec_counter_for_resize_op
=~ Version: '10\.5
MDEV-22686:
=~ Assertion \`trn'
=~ ha_maria::start_stmt
=~ check_lock_and_start_stmt
=~ Version: '10\.5
MDEV-22686:
=~ AddressSanitizer|signal
=~ maria_status
=~ ha_maria::info
=~ Sql_cmd_create_table_like
=~ Version: '10\.5
MDEV-22413:
=~ Assertion \`old_part_id == m_last_part'|Assertion \`part_id == m_last_part'
=~ ha_partition::update_row|ha_partition::delete_row
=~ Version: '10\.[3-5]
=~ versioning
MDEV-22339:
=~ Assertion \`str_length < len'
=~ Binary_string::realloc_raw
=~ mysql_lock_abort_for_thread
=~ Version: '10\.[4-5]
MDEV-22283:
=~ signal 11|AddressSanitizer
=~ key_copy
=~ write_record
=~ mysql_insert
=~ Version: '10\.[4-5]
MDEV-22283:
=~ Aria table .* is in use (most likely by a MERGE table)
=~ Version: '10\.[4-5]
MDEV-22206:
=~ InnoDB: Failing assertion: heap_no == ULINT_UNDEFINED
=~ trx/trx0i_s\.cc line
=~ add_trx_relevant_locks_to_cache
=~ Version: '10\.5
MDEV-22051:
=~ WSREP: Server paused at:
=~ Assertion \`0'
=~ Protocol::end_statement
=~ Version: '10\.5
MDEV-22048:
=~ Assertion \`binlog_table_maps == 0 \|\| locked_tables_mode == LTM_LOCK_TABLES'
=~ reset_for_next_command
=~ Version: '10\.5
MDEV-22027:
=~ Assertion \`oldest_lsn >= log_sys\.last_checkpoint_lsn'
=~ log_checkpoint
=~ Version: '10\.5
MDEV-22002:
=~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
=~ TEMPORARY
=~ xa\.yy
=~ sequence
=~ Version: '10\.[3-5]
MDEV-21995:
=~ signal 11|AddressSanitizer:
=~ Item_field::real_type_handler
=~ join_type_handlers_for_tvc
=~ Version: '10\.[3-5]
MDEV-21936:
=~ Assertion \`!btr_search_own_any(RW_LOCK_S)'
=~ btr_search_drop_page_hash_index
=~ buf_block_try_discard_uncompressed
=~ Version: '10\.[3-5]
MDEV-21398:
=~ Assertion \`! is_set() \|\| m_can_overwrite_status'
=~ Diagnostics_area::set_error_status
=~ THD::raise_condition
=~ my_message_sql
=~ KILL_QUERY|KILL_TIMEOUT|KILL_SERVER|ABORT_QUERY
MDEV-21127:
=~ Assertion \`(size_t)(ptr - buf) < MAX_TEXT - 4'
=~ key_text::key_text
=~ Version: '10\.5
MDEV-20984:
=~ Assertion \`args\[0\]->type_handler()->mysql_timestamp_type() == MYSQL_TIMESTAMP_DATETIME'
=~ Item_func_round::date_op
=~ Type_handler_temporal_result::Item_func_hybrid_field_type_get_date
MDEV-20578:
=~ error 126 when executing undo undo_key_delete
=~ Version: '10\.[2-5]
MDEV-20366:
=~ signal 11|AddressSanitizer: SEGV
=~ change_password
=~ set_var_password
=~ sp_instr_stmt::exec_core
=~ Version: '10\.5
MDEV-20015:
=~ Assertion \`!in_use->is_error()'
=~ update_virtual_field
=~ compute_vcols|innobase_get_computed_value
MDEV-19622:
=~ Assertion \`!table \|\| (!table->read_set \|\| bitmap_is_set(table->read_set, field_index))'|Assertion \`!table \|\| (!table->read_set \|\| bitmap_is_set(table->read_set, field_index) \|\| (!(ptr >= table->record\[0\] && ptr < table->record\[0\] + table->s->reclength)))'|Assertion \`marked_for_read()'
=~ ha_partition::set_auto_increment_if_higher
=~ ha_partition::update_row
MDEV-19114:
=~ Assertion \`n_fields > 0'
=~ rec_offs_set_n_fields
=~ row_purge_remove_sec_if_poss_leaf
MDEV-18794:
=~ Assertion \`!m_innodb' failed
=~ ha_partition::cmp_ref
=~ read_keys_and_merge_scans
MDEV-18457: [bitmap->full_head_size]
=~ Assertion \`(bitmap->map + (bitmap->full_head_size/6\*6)) <= full_head_end'
=~ _ma_check_bitmap
MDEV-19745:
=~ Backup did not finish in due time
=~ Version: '10\.[3-9]

##############################################################################
# Weak matches
##############################################################################

##########
# Fixed in the next release
##########

MDEV-19320:
=~ UPDATE.* 1032 Can't find record in|DELETE.* 1032 Can't find record in|SELECT SETVAL.* 1032 Can't find record in|SELECT.* 1032 Can't find record in|INSERT.* 1032 Can't find record in
=~ will exit with exit status STATUS_DATABASE_CORRUPTION
=~ sequence
=~ Version: '10\.[3-5]
MDEV-22061: [cursor->index->is_committed - Versioning]
=~ was not found on update: TUPLE
=~ Failing assertion: !cursor->index->is_committed()
=~ row_ins_sec_index_entry_by_modify
=~ Version: '10\.[3-9]
=~ versioning
MDEV-20661:
=~ InnoDB: Record in index .* of table .* was not found on update: TUPLE (info_bits=.* fields):
=~ versioning
=~ will exit with exit status STATUS_DATABASE_CORRUPTION
MDEV-20661:
=~ failed: 126: Index for table './test/t1.MYI' is corrupt; try to repair it
=~ versioning
MDEV-5924:
=~ Query_cache::register_all_tables
