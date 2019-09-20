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
MENT-360:
=~ AddressSanitizer: heap-use-after-free|signal 11
=~ strmake_root
=~ Query_arena::strmake
=~ mysqld_list_processes
MENT-341:
=~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
=~ mysql_create_or_drop_trigger|mysql_drop_view|mysql_create_view|Sql_cmd_create_table|mysql_rm_table|mysql_load|mysql_alter_table|Sql_cmd_truncate_table|mysql_rename_tables|mysql_create_db|FLUSH
=~ my_ok
MENT-328:
=~ mariabackup: File '.*seq.*MAI' not found (Errcode: 2 "No such file or directory")
=~ Error on aria table file open .*seq.*MAI
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
MDEV-17939:
=~ Assertion \`++loop_count < 2'
=~ trx_undo_report_rename
=~ fts_drop_table|my_xpath_parse_EqualityExpr
=~ mysql_alter_table|Alter_info::vers_prohibited

##############################################################################
# Weak matches
##############################################################################
