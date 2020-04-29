# Bug signatures for recognizing known bugs by server and test logs

##############################################################################
# Strong matches
##############################################################################

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
=~ Version: '10\.3|Version: '10\.4
MENT-328:
=~ scenario=MariaBackup
=~ For  BASE TABLE ROW_FORMAT= .* : Error : Can't find file: '.*seq.*MAI' (errno: 2 "No such file or directory")
=~ status STATUS_BACKUP_FAILURE
=~ Version: '10\.3|Version: '10\.4
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
#
# Fixed in the next release
#
MDEV-22102:
=~ Assertion \`w == OPT'
=~ trx_undo_header_create
=~ Version: '10\.5
MDEV-21899:
=~ Not applying DELETE_ROW_FORMAT_DYNAMIC due to corruption on
=~ Version: '10\.5
MDEV-21850:
=~ AddressSanitizer:
=~ page_cur_insert_rec_low
=~ page_cur_tuple_insert
=~ Version: '10\.5
# Currently in 10.5e due to rebase, but not in 10.4e yet
MDEV-21792:
=~ signal 8|AddressSanitizer: FPE
=~ dict_index_add_to_cache|os_file_create_simple_func
=~ create_index|prep_alter_part_table
=~ Version: '10\.4
# Currently in 10.5e due to rebase, but not in 10.4e yet
MDEV-20370:
=~ Assertion \`mtr->get_log_mode() == MTR_LOG_NO_REDO'
=~ page_cur_insert_rec_write_log
=~ Version: '10\.2|Version: '10\.3|Version: '10\.4
# Currently in 10.5e due to rebase, but not in 10.4e yet
MDEV-21658:
=~ Assertion \`log->blobs'
=~ row_log_table_apply_update
=~ ha_innobase::inplace_alter_table
=~ Version: '10\.4
# Currently in 10.5e due to rebase, but not in 10.4e yet
MDEV-21658:
=~ Assertion \`extra_size \|\| !is_instant'
=~ row_log_table_apply_op
=~ ha_innobase::inplace_alter_table
=~ Version: '10\.2|Version: '10\.3|Version: '10\.4
# Currently in 10.5e due to rebase, but not in 10.4e yet
MDEV-21645:
=~ AddressSanitizer:|signal 11
=~ innobase_get_computed_value
=~ row_merge_read_clustered_index
=~ ha_innobase::inplace_alter_table
=~ Version: '10\.4
# Currently in 10.5e due to rebase, but not in 10.4e yet
MDEV-21564:
=~ Assertion \`srv_undo_sources \|\| trx->undo_no == 0 \|\| (!purge_sys\.enabled() && (srv_is_being_started \|\| trx_rollback_is_active \|\| srv_force_recovery >= SRV_FORCE_NO_BACKGROUND)) \|\| ((trx->mysql_thd \|\| trx->internal) && srv_fast_shutdown)'|Assertion \`srv_undo_sources \|\| trx->undo_no == 0 \|\| ((srv_is_being_started \|\| trx_rollback_or_clean_is_active) && purge_sys->state == PURGE_STATE_INIT) \|\| (srv_force_recovery >= SRV_FORCE_NO_BACKGROUND && purge_sys->state == PURGE_STATE_DISABLED) \|\| ((trx->in_mysql_trx_list \|\| trx->internal) && srv_fast_shutdown)'
=~ trx_purge_add_undo_to_history
=~ trx_write_serialisation_history
=~ fts_optimize_words|dict_table_close|kill_server
=~ Version: '10\.2|Version: '10\.3|Version: '10\.4
# Currently in 10.5e due to rebase, but not in 10.4e yet
MDEV-21550:
=~ Assertion \`!table->fts->in_queue'|InnoDB: Failing assertion: !table->fts->in_queue
=~ fts_optimize_remove_table
=~ row_drop_table_for_mysql
=~ Version: '10\.2|Version: '10\.3|Version: '10\.4
# Currently in 10.5e due to rebase, but not in 10.4e yet
MDEV-17844:
=~ Assertion \`ulint(rec) == offsets[2]'
=~ rec_offs_validate
=~ page_zip_write_trx_id_and_roll_ptr
=~ row_undo
=~ Version: '10\.2|Version: '10\.3|Version: '10\.4
MDEV-22332:
=~ Assertion \`mtr_started == mtr\.is_active()'
=~ row_merge_read_clustered_index
=~ Version: '10\.5
MDEV-22218:
=~ InnoDB: Failing assertion: node->pcur->rel_pos == BTR_PCUR_ON
=~ row_update_for_mysql
=~ Version: '10\.5
MDEV-22139:
=~ InnoDB: Not applying DELETE_ROW_FORMAT_REDUNDANT
=~ mariabackup: innodb_init() returned 39 (Data structure corruption)
=~ Version: '10\.5
MDEV-22077:
=~ Assertion \`table->no_keyread \|\| !table->covering_keys\.is_set(tab->index) \|\| table->file->keyread == tab->index'
=~ join_read_first
=~ Version: '10\.5
MDEV-22075:
=~ signal 11|AddressSanitizer
=~ wsrep_should_replicate_ddl_iterate
=~ mysql_create_view
MDEV-22062:
=~ Assertion \`!table->file->keyread_enabled()'
=~ close_thread_table
=~ Version: '10\.5
MDEV-22051:
=~ WSREP: Server paused at:
=~ Assertion \`0'
=~ Protocol::end_statement
=~ Version: '10\.4|Version: '10\.5
MDEV-22275:
=~ Assertion \`global_status_var\.global_memory_used == 0'
=~ mysqld_exit
MDEV-22275:
=~ LeakSanitizer: detected memory leaks
=~ my_malloc
MDEV-21946:
=~ signal 11|AddressSanitizer:
=~ store_length
=~ Type_handler_string_result::make_sort_key_part
=~ Version: '10\.5
MDEV-21941:
=~ Assertion \`0'
=~ get_fieldno_by_name
=~ mysql_alter_table
=~ Version: '10\.5
MDEV-21757:
=~ Assertion \`purpose == FIL_TYPE_TABLESPACE'
=~ fil_space_t::modify_check
=~ fseg_free_page_low
=~ Version: '10\.5
MDEV-21688:
=~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
=~ Diagnostics_area::set_ok_status
=~ mysql_alter_table
=~ DROP SYSTEM VERSIONING
=~ Version: '10\.3|Version: '10\.4|Version: '10\.5
MDEV-21056:
=~ Assertion \`global_status_var\.global_memory_used == 0'
=~ mysqld_exit
=~ mysqld_main
=~ Version: '10\.2|Version: '10\.3|Version: '10\.4|Version: '10\.5
MDEV-21342:
=~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
=~ Diagnostics_area::set_ok_status
=~ my_ok
=~ mysql_update
=~ versioning
=~ Version: '10\.3|Version: '10\.4|Version: '10\.5
MDEV-21342:
=~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
=~ Diagnostics_area::set_ok_status
=~ mysql_update
=~ UPDATE .* FOR PORTION
MDEV-20494:
=~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
=~ fast_end_partition
=~ mysql_alter_table
=~ versioning
=~ Version: '10\.4|Version: '10\.5
MDEV-19092:
=~ Assertion \`foreign->referenced_index != __null'|signal 11|Assertion \`new_index != __null'|InnoDB: Failing assertion: new_index != __null
=~ dict_mem_table_col_rename_low
MDEV-17177:
=~ signal 11|AddressSanitizer: use-after-poison
=~ Item_func_in::cleanup
=~ Item::delete_self
=~ Query_arena::free_items
=~ THD::cleanup_after_query
MDEV-17091:
=~ Assertion \`old_part_id == m_last_part'
=~ ha_partition::update_row
=~ mysql_update|Update_rows_log_event::do_exec_row|mysql_multi_update|mysql_load|mysql_delete|write_record
MDEV-10466:
=~ SEL_ARG::store_min
=~ ror_scan_selectivity
=~ SQL_SELECT::test_quick_select
MDEV-22128:
=~ signal 11|AddressSanitizer
=~ do_rename|rename_tables
=~ wsrep_on
=~ Version: '10\.5
# Not merged to 10.5 yet
MDEV-18286: [pagecache->cnt_for_resize_op == 0]
=~ Assertion \`pagecache->cnt_for_resize_op == 0'
=~ check_pagecache_is_cleaned_up
=~ plugin_shutdown

##############################################################################
# Weak matches
##############################################################################

#
# Fixed in the next release
#

MDEV-21471:
=~ Version: '10\.4|Version: '10\.5
=~ is marked as crashed and should be repaired
=~ versioning
MDEV-20515:
=~ 1032: Can't find record in .*|1034: Index for table .* is corrupt; try to repair it|1030: Got error 176 "Read page with wrong checksum" from storage engine Aria
MDEV-20494:
=~ mysqld: Incorrect information in file: .*
=~ versioning
=~ Version: '10\.4|Version: '10\.5
MDEV-21899:
=~ InnoDB: Not applying .* due to corruption on
=~ InnoDB: Set innodb_force_recovery=1 to ignore corruption
=~ Version: '10\.5
