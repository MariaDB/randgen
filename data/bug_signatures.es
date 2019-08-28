# Bug signatures for recognizing known bugs by server and test logs

##############################################################################
# Strong matches
##############################################################################

MENT-360:
=~ AddressSanitizer: heap-use-after-free|signal 11
=~ strmake_root
=~ Query_arena::strmake
=~ mysqld_list_processes
MENT-350:
=~ Installing MariaDB/MySQL system tables in
=~ MariaDB Audit Plugin version 2.* STARTED
=~ Assertion \`global_status_var\.global_memory_used == 0'
=~ mysqld_exit(int)
=~ AddressSanitizer: SEGV
=~ Server version: 10\.4
MENT-349:
=~ AddressSanitizer: heap-use-after-free
=~ filter_query_type
=~ log_statement
=~ auditing
MENT-341:
=~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
=~ mysql_create_or_drop_trigger|mysql_drop_view|mysql_create_view|Sql_cmd_create_table|mysql_rm_table|mysql_load|mysql_alter_table|Sql_cmd_truncate_table|mysql_rename_tables|mysql_create_db|FLUSH
=~ my_ok
MENT-319:
=~ Assertion \`backup_flush_ticket == 0'
=~ backup_start
=~ run_backup_stage
MENT-264:
=~ Error on file .*\.M.*I open during .*seq.* table copy
MENT-253:
=~ AddressSanitizer: SEGV|signal 11
=~ filter_query_type
=~ log_statement
=~ auditing
MENT-189:
=~ InnoDB: Failing assertion: opt_no_lock
=~ recv_parse_log_recs
=~ xtrabackup_copy_log
MDEV-19304:
=~ signal 11|AddressSanitizer: SEGV on unknown address
=~ row_sel_field_store_in_mysql_format_func|row_sel_store_mysql_rec
=~ row_search_mvcc
MDEV-19304:
=~ AddressSanitizer: unknown-crash on address
=~ my_timestamp_from_binary
=~ Field_timestampf::get_timestamp
=~ Column_definition::Column_definition|TABLE::validate_default_values_of_unset_fields
MDEV-19304:
=~ AddressSanitizer: SEGV on unknown address|signal 11
=~ calc_row_difference
=~ handler::ha_update_row
MDEV-19304:
=~ AddressSanitizer: unknown-crash|AddressSanitizer: heap-use-after-free|AddressSanitizer: heap-buffer-overflow|AddressSanitizer: use-after-poison
=~ compare_record
=~ mysql_update
MDEV-19304:
=~ AddressSanitizer: unknown-crash|AddressSanitizer: heap-buffer-overflow|AddressSanitizer: use-after-poison
=~ create_tmp_table
=~ select_unit::create_result_table
=~ mysql_derived_prepare
MDEV-19304:
=~ signal 11
=~ handler::ha_write_row
=~ ha_partition::write_row
=~ write_record
MDEV-19304:
=~ Server version: 10\.5|Server version: 10\.4|Server version: 10\.3
=~ AddressSanitizer: SEGV|signal 6|signal 11
=~ ha_partition::try_semi_consistent_read
=~ mysql_update
MDEV-19301:
=~ Assertion \`!is_valid_datetime() \|\| fraction_remainder(((item->decimals) < (6) ? (item->decimals) : (6))) == 0'
=~ Server version: 10\.5|Server version: 10\.4
=~ Datetime_truncation_not_needed::Datetime_truncation_not_needed
=~ Item_func_nullif::date_op
=~ Type_handler_temporal_result::Item_func_hybrid_field_type_get_date
MDEV-19166:
=~ Assertion \`!is_zero_datetime()'
=~ Timestamp_or_zero_datetime::tv
=~ Item_cache_timestamp::to_datetime
MDEV-19127:
=~ Assertion \`row_start_field'
=~ vers_prepare_keys
=~ mysql_create_frm_image

##############################################################################
# Weak matches
##############################################################################
