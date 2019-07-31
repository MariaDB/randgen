# Bug signatures for recognizing known bugs by server and test logs

##############################################################################
# Strong matches
##############################################################################

MENT-253:
=~ AddressSanitizer: SEGV|signal 11
=~ filter_query_type
=~ log_statement
=~ auditing
MDEV-19914:
=~ Assertion \`id != LATCH_ID_NONE'
=~ Context::Context
=~ fil_space_crypt_close_tablespace
MDEV-19776:
=~ Assertion \`to_len >= 8'
=~ convert_to_printable
=~ String::append_semi_hex|replace_db_table
MDEV-19774:
=~ Assertion \`sec\.sec() <= 0x7FFFFFFFL'
=~ Item_func_from_unixtime::get_date
=~ Protocol::send_result_set_row
MDEV-19716:
=~ AddressSanitizer: use-after-poison
=~ Query_log_event::Query_log_event
=~ THD::log_events_and_free_tmp_shares
=~ THD::close_temporary_tables
MDEV-19595:
=~ Table .* is marked as crashed and should be repaired
=~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
=~ Diagnostics_area::set_ok_status
=~ my_ok
=~ mysql_alter_table|Sql_cmd_truncate_table::execute|mysqld_show_create
MDEV-19595:
=~ Assertion \`! is_set()' failed
=~ Diagnostics_area::set_eof_status
=~ mysqld_show_create
MDEV-19175:
=~ signal 11|AddressSanitizer: SEGV on unknown address
=~ ha_partition::vers_can_native
=~ TABLE_SHARE::init_from_binary_frm_image
MDEV-19049:
=~ AddressSanitizer: stack-buffer-overflow
=~ Field_blob::get_key_image
=~ key_copy
=~ check_duplicate_long_entry_key
MDEV-19049:
=~ stack smashing detected
=~ __fortify_fail
=~ check_duplicate_long_entry_key
MDEV-18078:
=~ Assertion \`trnman_has_locked_tables(trn) > 0'
=~ ha_maria::external_lock
=~ mysql_unlock_tables
MDEV-17857:
=~ tmp != ((long long) 0x8000000000000000LL)
=~ TIME_from_longlong_datetime_packed
MDEV-17636:
=~ Assertion \`pagecache->block_root[i]\.status == 0'
=~ check_pagecache_is_cleaned_up
=~ end_pagecache
MDEV-17627:
=~ Assertion \`inited==RND'
=~ handler::ha_rnd_end|translog_advance_pointer
=~ handler::ha_rnd_init_with_error|handler::read_first_row|handler::print_error
MDEV-17576:
=~ Assertion \`share->reopen == 1'
=~ maria_extra
=~ mysql_alter_table|mysql_create_or_drop_trigger
MDEV-17005:
=~ AddressSanitizer: heap-use-after-free|AddressSanitizer: heap-buffer-overflow
=~ innobase_get_computed_value
=~ row_upd_clust_step|row_ins_clust_index_entry
MDEV-16866:
=~ InnoDB: redo log checkpoint: 0 [ chk key ]:
=~ InnoDB: Redo log crypto: failed to decrypt log block. Reason could be
MDEV-16222:
=~ InnoDB: tried to purge non-delete-marked record in index
=~ Assertion \`0'
=~ row_purge_remove_sec_if_poss_leaf
=~ row_purge
MDEV-15572:
=~ signal 11|AddressSanitizer: SEGV
=~ ha_maria::end_bulk_insert|ha_maria::extra
=~ select_insert::abort_result_set
MDEV-14996:
=~ Assertion \`!thd->get_stmt_da()->is_sent() \|\| thd->killed == KILL_CONNECTION'
=~ int ha_maria::external_lock
=~ Status: KILL_CONNECTION|Status: KILL_SERVER

##############################################################################
# Weak matches
##############################################################################

MDEV-17884:
=~ is marked as crashed and should be repaired
MDEV-17659:
=~ File too short; Expected more data in file
MDEV-17551:
=~ _ma_state_info_write
