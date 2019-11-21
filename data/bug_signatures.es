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

##############################################################################
# Weak matches
##############################################################################
