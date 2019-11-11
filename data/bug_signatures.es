# Bug signatures for recognizing known bugs by server and test logs

##############################################################################
# Strong matches
##############################################################################

MENT-438:
=~ signal 11
=~ MDL_lock::incompatible_granted_types_bitmap
=~ MDL_ticket::has_stronger_or_equal_type|MDL_ticket::is_incompatible_when_granted
=~ run_backup_stage
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
=~ Assertion \`this == ticket->get_ctx()'
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
MENT-360:
=~ AddressSanitizer: heap-use-after-free|signal 11
=~ strmake_root
=~ Query_arena::strmake
=~ mysqld_list_processes
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
=~ Error on file .*\.M.*I open during .*seq.* table copy
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
MDEV-20814:
=~ Assertion \`index->is_instant()'
=~ rec_init_offsets
=~ que_run_threads
=~ srv_start
=~ Version: '10\.3|Version: '10\.4
MDEV-20813:
=~ Assertion \`!srv_safe_truncate \|\| !newest_lsn \|\| fil_page_get_type(page)'
=~ buf_flush_init_for_writing
=~ buf_flush_write_block_low
=~ Version: '10\.2
MDEV-20813:
=~ Assertion \`!newest_lsn \|\| fil_page_get_type(page)'
=~ buf_flush_init_for_writing
=~ buf_flush_write_block_low
=~ Version: '10\.3
MDEV-20788:
=~ Assertion \`page_rec_is_infimum(rec) \|\| !(rec_get_info_bits(page + offs, comp) & 0x10UL)'
=~ page_rec_get_next_low
MDEV-20639:
=~ AddressSanitizer: SEGV
=~ get_prefix
=~ find_body
=~ Field_timestamp::conversion_depends_on_sql_mode
=~ Version: '10\.4|Version: '10\.5
MDEV-20495:
=~ Assertion \`precision > 0'
=~ decimal_bin_size
=~ select_create::create_table_from_items|Field_new_decimal::create_from_item
MDEV-20320:
=~ Failed to find tablespace for table .* in the cache\. Attempting to load the tablespace with space id
MDEV-20320:
=~ InnoDB: Refusing to load .* (id=.*, flags=.*); dictionary contains id=.*, flags=.*
=~ InnoDB: Operating system error number 2 in a file operation
=~ InnoDB: Could not find a valid tablespace file for .*
MDEV-20090:
=~ Assertion \`pos < index->n_def'
=~ dict_index_get_nth_field
=~ row_purge_parse_undo_rec
=~ srv_task_execute
=~ Version: '10\.4|Version: '10\.5
MDEV-19536:
=~ AddressSanitizer: heap-use-after-free|signal 11|Invalid read of size
=~ is_temporary_table|Index_stat::set_full_table_name|Stat_table::Stat_table|statistics_for_tables_is_needed
=~ read_statistics_for_tables_if_needed
MDEV-19536:
=~ signal 11
=~ read_statistics_for_tables_if_needed
=~ fill_schema_table_by_open
MDEV-19406:
=~ Assertion \`marked_for_write_or_computed()'|Assertion \`is_stat_field \|\| !table \|\| (!table->write_set \|\| bitmap_is_set(table->write_set, field_index) \|\| (!(ptr >= table->record[0] && ptr < table->record[0] + table->s->reclength))) \|\| (table->vcol_set && bitmap_is_set(table->vcol_set, field_index))'
=~ Field_date_common::store_TIME_with_warning
=~ Field::do_field_temporal
=~ multi_update::do_updates
MDEV-19406:
=~ Assertion \`bitmap_is_set_all(&table->s->all_set)'
=~ handler::ha_reset
=~ close_thread_table
MDEV-17939:
=~ Assertion \`++loop_count < 2'
=~ trx_undo_report_rename
=~ fts_drop_table|my_xpath_parse_EqualityExpr
=~ mysql_alter_table|Alter_info::vers_prohibited
MDEV-19647:
=~ Assertion \`find(table)'
=~ dict_sys_t::prevent_eviction
=~ fts_optimize_add_table
=~ dict_load_columns
MDEV-19189:
=~ AddressSanitizer: memcpy-param-overlap: memory ranges
=~ fill_alter_inplace_info
=~ mysql_alter_table
MDEV-18546:
=~ AddressSanitizer: heap-use-after-free|AddressSanitizer: heap-buffer-overflow
=~ innobase_get_computed_value
=~ row_vers_build_clust_v_col
MDEV-18546:
=~ InnoDB: tried to purge non-delete-marked record in index
=~ signal 11
=~ row_vers_build_clust_v_col
=~ row_vers_old_has_index_entry
MDEV-18451:
=~ signal 11|AddressSanitizer: SEGV on unknown address
=~ maria_create_trn_for_mysql
=~ _ma_setup_live_state
=~ trans_commit_implicit
MDEV-17333:
=~ next_insert_id >= auto_inc_interval_for_cur_row\.minimum

##############################################################################
# Weak matches
##############################################################################
