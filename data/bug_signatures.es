# Bug signatures for recognizing known bugs by server and test logs

##############################################################################
# Strong matches
##############################################################################

MENT-1199:
=~ signal 11|AddressSanitizer
=~ Sql_cmd_alter_table_exchange_partition::exchange_partition
=~ Version: '10\.4
MENT-809:
=~ mariabackup: Aria engine: starting recovery
=~ Got error 127 when executing|Got error 175 when executing
MENT-808:
=~ signal [16]|AddressSanitizer|\`page_offset != 0 && page_offset <= page_length && page_length + length <= max_page_size'|\`page_offset - length <= page_length'|\`page_offset >= keypage_header && page_offset <= page_length'|\`page_offset != 0 && page_offset + length <= page_length'
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
# Only in 10.4+ CS, but also in 10.3 ES
MDEV-24349:
=~ AddressSanitizer|signal [16]|Assertion \`name\.length == strlen(name\.str)'
=~ get_quote_char_for_identifier|Item::print_item_w_name
=~ st_select_lex::print
=~ Version: '10\.3|Server version: 10\.3
# Only 10.5 CS, but also 10.4 ES
MDEV-22913:
=~ error: can't open
=~ Error: xtrabackup_apply_delta(): failed to apply
=~ Version: '10\.4
# Only 10.4+ CS, but also 10.3 ES
MDEV-24349:
=~ AddressSanitizer|signal [16]|Assertion \`name\.length == strlen(name\.str)'
=~ get_quote_char_for_identifier|Item::print_item_w_name
=~ st_select_lex::print
=~ Version: '10\.3|Server version: 10\.3
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

MDEV-24929:
=~ signal [16]|AddressSanitizer
=~ thr_unlock
=~ thr_multi_unlock
=~ JOIN::optimize
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]
MDEV-24929:
=~ signal [16]|AddressSanitizer
=~ get_schema_tables_result
=~ JOIN::exec
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]
MDEV-24811:
=~ Assertion \`find(table)'
=~ dict_sys_t::remove
=~ trx_update_mod_tables_timestamp
=~ Version: '10\.[4-9]|Server version: 10\.[4-9]
MDEV-24811:
=~ Assertion \`str'
=~ ut_fold_string
=~ dict_table_remove_from_cache_low
=~ trx_update_mod_tables_timestamp
=~ Version: '10\.3|Server version: 10\.3
MDEV-24792:
=~ Assertion \`!newest_lsn \|\| fil_page_get_type(page)'
=~ buf_flush_init_for_writing
=~ mariabackup
=~ Version: '10\.4|Server version: 10\.4
MDEV-24779:
=~ Assertion \`sl->join == 0'
=~ reinit_stmt_before_use
=~ Prepared_statement::execute
MDEV-24763:
=~ signal [16]|AddressSanitizer
=~ dict_stats_try_drop_table
=~ innobase_reload_table
MDEV-24748:
=~ Assertion \`err != DB_SUCCESS \|\| btr_validate_index(m_index, __null.*) == DB_SUCCESS'
=~ BtrBulk::finish
=~ row_merge_read_clustered_index
MDEV-24748:
=~ [ERROR] InnoDB: Field .* len is .*, should be .*; COMPACT RECORD
MDEV-24710:
=~ Conditional jump or move depends on uninitialised value|Assertion \`len <= col->len \|\| ((col->mtype) == 5 \|\| (col->mtype) == 14) \|\| (col->len == 0 && col->mtype == 1)'
=~ rec_get_converted_size_comp_prefix_low
=~ row_ins_index_entry
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]
MDEV-24710:
=~ Conditional jump or move depends on uninitialised value
=~ _mi_rec_pack
=~ _mi_write_dynamic_record
=~ ha_myisam::write_row
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]
MDEV-24710:
=~ Error: Freeing overrun buffer .*mi_close\.c
=~ Allocated at .*mi_open\.c
=~ corrupted size vs. prev_size
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]
MDEV-24710:
=~ Conditional jump or move depends on uninitialised value|Assertion \`length <= column->length'
=~ _ma_write_init_block_record
=~ ha_maria::write_row
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]
MDEV-24664:
=~ Assertion \`! is_set()'
=~ Diagnostics_area::set_eof_status
=~ Explain_query::send_explain
=~ EXPLAIN.*DELETE
=~ Prepared_statement::execute
MDEV-24532:
=~ Assertion \`thd->transaction->stmt\.is_empty()'
=~ Locked_tables_list::unlock_locked_tables
=~ InnoDB: Table .* contains .* user defined columns in InnoDB, but .* columns in MariaDB
MDEV-24532:
=~ DATABASE_CORRUPTION
=~ InnoDB: Table .* contains .* user defined columns in InnoDB, but .* columns in MariaDB
=~ Table .* is marked as crashed and should be repaired|Table .* doesn't exist in engine
MDEV-24519:
=~ signal [16]|AddressSanitizer
=~ Charset::set_charset
=~ String::copy
=~ Item::remove_eq_conds
=~ Version: '10\.[4-9]|Server version: 10\.[4-9]
MDEV-23843:
=~ Assertion \`! is_set() \|\| m_can_overwrite_status'
=~ MDL_context::acquire_lock
=~ THD::binlog_query|ha_maria_implicit_commit
=~ Version: '10\.[4-9]|Server version: 10\.[4-9]
MDEV-23843:
=~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
=~ Diagnostics_area::set_ok_status
=~ Version: '10\.[4-9]|Server version: 10\.[4-9]
MDEV-22703:
=~ signal [16]|AddressSanitizer
=~ rec_convert_dtuple_to_rec_comp|rec_convert_dtuple_to_rec_old
=~ page_cur_tuple_insert
=~ row_ins_index_entry_step
MDEV-22562:
=~ Assertion \`next_insert_id == 0'
=~ handler::ha_external_lock
=~ mysql_unlock_tables
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]
=~ application_periods|versioning|FeatureUsage detected system-versioned|FeatureUsage detected application periods
MDEV-21697:
=~ Assertion \`!wsrep_has_changes(thd) \|\| (thd->lex->sql_command == SQLCOM_CREATE_TABLE && !thd->is_current_stmt_binlog_format_row())'
=~ wsrep_commit_empty
=~ Version: '10\.[4-9]|Server version: 10\.[4-9]


##############################################################################
# Weak matches
##############################################################################

##########
# Fixed in the next release
##########

