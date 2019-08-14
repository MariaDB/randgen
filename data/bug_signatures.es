# Bug signatures for recognizing known bugs by server and test logs

##############################################################################
# Strong matches
##############################################################################

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
=~ log_statement_ex
=~ auditing
=~ Version: '10\.3|Version: '10\.2
MENT-341:
=~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
=~ Diagnostics_area::set_ok_status
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

##############################################################################
# Weak matches
##############################################################################
