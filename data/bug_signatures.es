# Bug signatures for recognizing known bugs by server and test logs

##############################################################################
# Strong matches
##############################################################################

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
