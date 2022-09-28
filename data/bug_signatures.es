# Bug signatures for recognizing known bugs by server and test logs

##############################################################################
# Strong matches
##############################################################################

MENT-809:
=~ mariabackup: Aria engine: starting recovery
=~ Got error 127 when executing|Got error 175 when executing
MENT-808:
=~ signal [16]|AddressSanitizer|\`page_offset != 0 && page_offset <= page_length && page_length + length <= max_page_size'|\`page_offset - length <= page_length'|\`page_offset >= keypage_header && page_offset <= page_length'|\`page_offset != 0 && page_offset + length <= page_length'
=~ maria_apply_log
=~ BACKUP_FAILURE
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
# Fixed in the next release (10.3.37 / 10.4.27 / 10.5.17 / 10.6.11)
##########

MDEV-29561:
=~ Could not re-create table .*: 1064: You have an error in your SQL syntax; check the manual that corresponds to your MariaDB server version for the right syntax to use near 'binary
MDEV-29559:
=~ Starting final batch to recover .* pages from redo log
=~ Not applying INSERT_HEAP_DYNAMIC due to corruption on
=~ InnoDB: Plugin initialization aborted at srv0start
=~ Version: '10\.[4-9]|Server version: 10\.[4-9]|Version: '10\.1[0-9]|Server version: 10\.1[0-9]
MDEV-29520:
=~ signal|AddressSanitizer
=~ rec_convert_dtuple_to_rec_comp
=~ btr_cur_optimistic_insert
=~ row_merge_spatial_rows
=~ mysql_alter_table
MDEV-29314:
=~ Assertion \`n_fields > n_cols'
=~ dict_index_t::init_change_cols
=~ mysql_inplace_alter_table
=~ Version: '10\.[6-9]|Server version: 10\.[6-9]|Version: '10\.1[0-9]|Server version: 10\.1[0-9]
MDEV-29291:
=~ Assertion \`!table->fts'
=~ dict_table_can_be_evicted
=~ Version: '10\.[6-9]|Server version: 10\.[6-9]|Version: '10\.1[0-9]|Server version: 10\.1[0-9]
MDEV-29008:
=~ Assertion \`field'|signal|AddressSanitizer
=~ spider_db_open_item_ident
=~ spider_group_by_handler
=~ Pushdown_query::execute
MDEV-23801:
=~ Assertion \`index->table->instant \|\| block->page\.id\.page_no() != index->page'|Assertion \`block->page\.id\.page_no() != index->page'
=~ btr_pcur_store_position
=~ row_search_mvcc
=~ Version: '10\.[3-4]|Server version: 10\.[3-4]
MDEV-22918:
=~ InnoDB: Plugin initialization aborted with error Generic error
=~ mariabackup: innodb_init() returned 11 (Generic error)
=~ Version: '10\.4|Server version: 10\.4
MDEV-22913:
=~ error: can't open
=~ Error: xtrabackup_apply_delta(): failed to apply
=~ Version: '10\.[5-9]|Server version: 10\.[5-9]|Version: '10\.1[0-9]|Server version: 10\.1[0-9]
MDEV-22647:
=~ safe_mutex: Trying to lock mutex at .*sql_plugin\.cc, line .*, when the mutex was already locked at .*sys_vars_shared.h
=~ sync_dynamic_session_variables
=~ get_loc_info
=~ Version: '10\.[2-9]|Server version: 10\.[2-9]|Version: '10\.1[0-9]|Server version: 10\.1[0-9]
MDEV-22647:
=~ Assertion \`!check_audit_mask(mysql_global_audit_mask, event_class_mask)'
=~ mysql_audit_acquire_plugins
=~ my_message_sql
=~ Version: '10\.[2-9]|Server version: 10\.[2-9]|Version: '10\.1[0-9]|Server version: 10\.1[0-9]


##############################################################################
# Weak matches
##############################################################################

##########
# Fixed in the next release (10.3.37 / 10.4.27 / 10.5.17 / 10.6.11)
##########

