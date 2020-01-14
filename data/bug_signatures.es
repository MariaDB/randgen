# Bug signatures for recognizing known bugs by server and test logs

##############################################################################
# Strong matches
##############################################################################

MENT-438:
=~ signal 11
=~ MDL_lock::incompatible_granted_types_bitmap
=~ MDL_ticket::has_stronger_or_equal_type|MDL_ticket::is_incompatible_when_granted
=~ Version: '10\.2|Version: '10\.3
MENT-438:
=~ AddressSanitizer: heap-use-after-free|signal 11
=~ MDL_ticket::has_stronger_or_equal_type|inline_mysql_prlock_wrlock
=~ MDL_context::upgrade_shared_lock
=~ run_backup_stage|backup_flush
=~ Version: '10\.2|Version: '10\.3
MENT-438:
=~ signal 11
=~ MDL_lock::Ticket_list::clear_bit_if_not_in_list
=~ MDL_context::upgrade_shared_lock
=~ backup_flush
=~ Version: '10\.2|Version: '10\.3
MENT-438:
=~ Assertion \`this == ticket->get_ctx()'|clear_bit_if_not_in_list
=~ MDL_context::release_lock
=~ Version: '10\.2|Version: '10\.3
MENT-438:
=~ Assertion \`ticket->m_duration == MDL_EXPLICIT'|AddressSanitizer: heap-use-after-free
=~ MDL_context::release_lock
=~ backup_end
=~ Version: '10\.2|Version: '10\.3
MENT-438:
=~ signal 11
=~ backup_end
=~ run_backup_stage|THD::cleanup|unlink_thd
=~ Version: '10\.2|Version: '10\.3
MENT-438:
=~ signal 11
=~ I_P_List
=~ MDL_lock.*Ticket_list.*clear_bit_if_not_in_list|MDL_lock.*Ticket_list.*remove_ticket
=~ MDL_context.*upgrade_shared_lock
=~ Version: '10\.2|Version: '10\.3
MENT-438:
=~ signal 6
=~ futex_fatal_error
=~ MDL_lock::remove_ticket
=~ backup_end
MENT-416:
=~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
=~ Diagnostics_area::set_ok_status
=~ mysql_alter_table
=~ RENAME
=~ Version: '10\.2
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
=~ Error on file .*\.M.* open during .*seq.* table copy
MENT-263:
=~ server_audit2
=~ Assertion \`global_status_var\.global_memory_used == 0'
=~ mysqld_exit
=~ Version: '10\.4
MENT-189:
=~ InnoDB: Failing assertion: opt_no_lock
=~ recv_parse_log_recs
=~ xtrabackup_copy_log
MENT-189:
=~ Failing assertion: opt_no_lock
=~ backup_file_op_fail
=~ fil_name_parse
=~ recv_parse_or_apply_log_rec_body
#
# Fixed in the next release
#
MDEV-18875:
=~ Assertion \`thd->transaction\.stmt\.ha_list == __null \|\| trans == &thd->transaction\.stmt'
=~ ha_rollback_trans
=~ mysql_trans_commit_alter_copy_data|trans_commit
MDEV-18460:
=~ signal 11|AddressSanitizer: SEGV
=~ tdc_create_key
=~ THD::create_tmp_table_def_key
=~ THD::open_temporary_table
MDEV-18046:
=~ Assertion \`(buf[0] & 0xe0) == 0x80'|signal 11
=~ binlog_get_uncompress_len
=~ Rows_log_event::uncompress_buf|Query_compressed_log_event::Query_compressed_log_event
=~ mysql_show_binlog_events
MDEV-18046:
=~ AddressSanitizer: unknown-crash
=~ my_strndup
=~ Rotate_log_event::Rotate_log_event
=~ Log_event::read_log_event
=~ mysql_show_binlog_events
MDEV-18046:
=~ Assertion \`var_header_len >= 2'
=~ Rows_log_event::Rows_log_event
=~ mysql_show_binlog_events|SHOW BINLOG EVENTS
MDEV-18046:
=~ Assertion \`m_field_metadata_size <= (m_colcnt \* 2)'
=~ Table_map_log_event::Table_map_log_event
=~ mysql_show_binlog_events
MDEV-18046:
=~ signal 11|signal 7
=~ my_bitmap_free
=~ Update_rows_log_event::~Update_rows_log_event
=~ mysql_show_binlog_events
MDEV-18046:
=~ Assertion \`(end - pos) >= infoLen'
=~ Rows_log_event::Rows_log_event
=~ mysql_show_binlog_events
MDEV-18046:
=~ AddressSanitizer: heap-buffer-overflow
=~ net_field_length
=~ Rows_log_event::Rows_log_event
=~ mysql_show_binlog_events
MDEV-18046:
=~ Assertion \`lenlen >= 1 && lenlen <= 4'
=~ binlog_get_uncompress_len
=~ Rows_log_event.*uncompress_buf
=~ mysql_show_binlog_events
MDEV-18046:
=~ Assertion \`(end - pos) >= EXTRA_ROW_INFO_HDR_BYTES'|Assertion \`(end - pos) >= 2'
=~ Rows_log_event::Rows_log_event
=~ mysql_show_binlog_events
MDEV-21405:
=~ Assertion \`(flags & ulint(~BTR_KEEP_IBUF_BITMAP)) == BTR_NO_LOCKING_FLAG'
=~ btr_cur_pessimistic_insert
=~ Version: '10\.3
MDEV-19176:
=~ InnoDB: Starting crash recovery from checkpoint
=~ InnoDB: Difficult to find free blocks in the buffer pool (21 search iterations)! 21 failed attempts to flush a page! Consider increasing innodb_buffer_pool_size\. Pending flushes
MDEV-18865:
=~ Assertion \`t->first->versioned_by_id()'
=~ innodb_prepare_commit_versioned
=~ mysql_alter_table

##############################################################################
# Weak matches
##############################################################################

#
# Fixed in the next release
#
MDEV-18046:
=~ var_header_len >= 2
MDEV-18046:
=~ in Rotate_log_event::Rotate_log_event
MDEV-18046:
=~ m_field_metadata_size <=
MDEV-18046:
=~ in inline_mysql_mutex_destroy
MDEV-18046:
=~ Update_rows_log_event::~Update_rows_log_event
