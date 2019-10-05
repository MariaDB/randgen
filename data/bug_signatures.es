# Bug signatures for recognizing known bugs by server and test logs

##############################################################################
# Strong matches
##############################################################################

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
MDEV-20495:
=~ Assertion \`precision > 0'
=~ decimal_bin_size
=~ Type_handler::make_and_init_table_field
=~ Item_func::create_field_for_create_select
=~ select_create::create_table_from_items
MDEV-20320:
=~ Failed to find tablespace for table .* in the cache\. Attempting to load the tablespace with space id
MDEV-20320:
=~ InnoDB: Refusing to load .* (id=.*, flags=.*); dictionary contains id=.*, flags=.*
=~ InnoDB: Operating system error number 2 in a file operation
=~ InnoDB: Could not find a valid tablespace file for .*
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

##############################################################################
# Weak matches
##############################################################################
