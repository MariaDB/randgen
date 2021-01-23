# Bug signatures for recognizing known bugs by server and test logs

##############################################################################
# Strong matches
##############################################################################

MENT-809:
=~ mariabackup: Aria engine: starting recovery
=~ Got error 127 when executing|Got error 175 when executing
MENT-808:
=~ signal|AddressSanitizer|\`page_offset != 0 && page_offset <= page_length && page_length + length <= max_page_size'|\`page_offset - length <= page_length'|\`page_offset >= keypage_header && page_offset <= page_length'|\`page_offset != 0 && page_offset + length <= page_length'
=~ maria_apply_log
=~ BACKUP_FAILURE
MENT-368:
=~ Assertion \`inline_mysql_file_tell(.*, file, (myf) (0)) == base_pos+ (16 + 5\*8 + 6\*4 + 11\*2 + 6 + 5\*2 + 1 + 16)'
=~ maria_create
=~ create_internal_tmp_table
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
# Only in 10.4+ CS, but also in 10.2+ ES
TODO-842: [m_status == DA_OK_BULK - LOCK]
=~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
=~ Diagnostics_area::set_ok_status
=~ my_ok
=~ LOCK.*TABLES
=~ Version: '10\.[2-9]


##########
# Fixed in the next release
##########

MDEV-24455:
=~ Assertion \`!m_freed_space'
=~ mtr_t::start
=~ btr_free_externally_stored_field
=~ Version: '10\.[5-9]
MDEV-24444:
=~ AddressSanitizer|signal
=~ Item_func_in::get_func_mm_tree
=~ SQL_SELECT::test_quick_select
=~ Version: '10\.[2-9]|Server version: 10\.[2-9]
MDEV-24442:
=~ Assertion \`space->referenced()'
=~ fil_crypt_space_needs_rotation|fil_delete_tablespace
=~ Version: '10\.[5-9]
MDEV-24220:
=~ signal|AddressSanitizer
=~ base_list_iterator::next|TABLE_LIST::is_recursive_with_table
=~ st_select_lex::cleanup
=~ sp_instr_stmt::execute|Prepared_statement::execute
MDEV-23644:
=~ InnoDB: Duplicate FTS_DOC_ID value on table
=~ Assertion \`mode == 16 \|\| mode == 12 \|\| !fix_block->page\.file_page_was_freed'
=~ buf_page_get_low
=~ btr_copy_blob_prefix
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]
MDEV-23644:
=~ Assertion \`!dfield_is_ext(row_field)'
=~ row_ins_index_entry_set_vals
=~ row_update_cascade_for_mysql
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]
MDEV-23644:
=~ Assertion \`!bpage->file_page_was_freed'
=~ buf_page_get_zip
=~ btr_rec_copy_externally_stored_field|btr_copy_externally_stored_field
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]
MDEV-23644:
=~ InnoDB: FIL_PAGE_TYPE=.* on BLOB read space .* page .*
=~ ib::fatal::~fatal
=~ btr_check_blob_fil_page_type
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]
MDEV-23632:
=~ AddressSanitizer|signal
=~ row_mysql_store_col_in_innobase_format
=~ innobase_get_computed_value
=~ row_merge_buf_add
=~ Version: '10\.[3-9]
MDEV-22540:
=~ Assertion \`transactional_table \|\| !changed \|\| thd->transaction.*stmt\.modified_non_trans_table'|Assertion \`transactional_table \|\| !changed \|\| thd->transaction.*stmt\.modified_non_trans_table'|Assertion \`transactional_table \|\| !(info\.copied \|\| info\.deleted) \|\| thd->transaction.*stmt\.modified_non_trans_table'
=~ mysql_load|mysql_insert
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]
MDEV-22076: [cursor->index->is_committed - XA]
=~ InnoDB: Failing assertion: !cursor->index->is_committed()
=~ row_ins_sec_index_entry_by_modify
=~ xa\.yy
MDEV-22076:
=~ InnoDB: tried to purge non-delete-marked record in index
=~ Assertion \`0'
=~ row_purge_remove_sec_if_poss_leaf
=~ xa\.yy
MDEV-21138:
=~ Assertion \`col->ord_part'|Assertion \`f\.col->ord_part'
=~ row_build_index_entry_low
=~ row_update_vers_insert
=~ row_ins_foreign_check_on_constraint
MDEV-21138:
=~ Assertion \`mode == 16 \|\| mode == 12 \|\| !fix_block->page\.file_page_was_freed'
=~ buf_page_get_gen
=~ btr_copy_blob_prefix
=~ fts_parallel_tokenization
MDEV-21138:
=~ InnoDB: Flagged corruption of .* in table .* in CHECK TABLE; Wrong count
=~ For InnoDB SYSTEM VERSIONED .* : error : Corrupt
MDEV-21138:
=~ InnoDB: Failing assertion: buf != field_ref_zero
=~ row_merge_buf_add
=~ InnoDB: Duplicate FTS_DOC_ID value on table
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]
=~ versioning
MDEV-21138:
=~ InnoDB: InnoDB: FIL_PAGE_TYPE=.* on BLOB read space .* page .* flags .*
=~ btr_check_blob_fil_page_type
=~ InnoDB: Duplicate FTS_DOC_ID value on table
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]
=~ versioning
MDEV-22178:
=~ Assertion \`info->alias\.str'
=~ partition_info::check_partition_info
=~ versioning
=~ PARTITIONS 1
=~ Version: '10\.[5-9]|Server version: 10\.[5-9]
MDEV-19273:
=~ signal 11|AddressSanitizer: SEGV on unknown address
=~ MDL_ticket::has_stronger_or_equal_type
=~ MDL_context::upgrade_shared_lock
=~ wait_while_table_is_used
MDEV-19273:
=~ Assertion \`thd->mdl_context\.is_lock_owner(MDL_key::TABLE, table->db\.str, table->table_name\.str, MDL_SHARED)'|Assertion \`thd->mdl_context\.is_lock_owner(MDL_key::TABLE, db\.str, table_name\.str, MDL_SHARED)'
=~ mysql_rm_table_no_locks
MDEV-19273:
=~ signal 11|AddressSanitizer
=~ I_P_List
=~ MDL_lock::Ticket_list::remove_ticket
=~ MDL_context::release_lock
MDEV-17891:
=~ Assertion \`transactional_table \|\| !changed \|\| thd->transaction.*stmt\.modified_non_trans_table'
=~ select_insert::abort_result_set|mysql_insert
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]
MDEV-17891:
=~ The table .* is full|Warning: Enabling keys got errno 121
=~ Assertion \`transactional_table \|\| !(info\.copied \|\| info\.deleted) \|\| thd->transaction.*stmt\.modified_non_trans_table'
=~ mysql_load
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]
MDEV-15533:
=~ Assertion \`log->blobs'|InnoDB: Failing assertion: log->blobs
=~ row_log_table_apply_update
=~ mysql_alter_table
MDEV-15532:
=~ Assertion \`!log->same_pk'|InnoDB: Failing assertion: !log->same_pk
=~ row_log_table_apply_delete
=~ Version: '10\.[0-2]
MDEV-15532:
=~ Assertion \`err_key < ha_alter_info->key_count'
=~ alter_rebuild_apply_log
=~ Version: '10\.[0-2]
MDEV-15532:
=~ signal|AddressSanitizer
=~ Field::is_null
=~ field_unpack
=~ print_keydup_error
=~ alter_rebuild_apply_log
=~ Version: '10\.[0-2]

##############################################################################
# Weak matches
##############################################################################

##########
# Fixed in the next release
##########

