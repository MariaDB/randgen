# Bug signatures for recognizing known bugs by server and test logs

##############################################################################
# Strong matches
##############################################################################

MENT-809:
=~ mariabackup: Aria engine: starting recovery
=~ Got error 127 when executing|Got error 175 when executing
MENT-808:
=~ signal|AddressSanitizer|\`page_offset != 0 && page_offset <= page_length && page_length + length <= max_page_size'|\`page_offset - length <= page_length'|\`page_offset >= keypage_header && page_offset <= page_length'|\`page_offset != 0 && page_offset + length <= page_length'
=~ maria_apply_log
=~ BACKUP_FAILURE
MENT-368:
=~ Assertion \`inline_mysql_file_tell(.*, file, (myf) (0)) == base_pos+ (16 + 5\*8 + 6\*4 + 11\*2 + 6 + 5\*2 + 1 + 16)'
=~ maria_create
=~ create_internal_tmp_table
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
# Fixed in CS 10.4+, but affects ES 10.2-10.3
MDEV-18286: [pagecache->cnt_for_resize_op == 0]
=~ Assertion \`pagecache->cnt_for_resize_op == 0'
=~ check_pagecache_is_cleaned_up
=~ plugin_shutdown
=~ Version: '10\.[2-3]
# Only 10.5 CS, but also 10.4 ES
MDEV-22913:
=~ error: can't open
=~ Error: xtrabackup_apply_delta(): failed to apply
=~ Version: '10\.4
# Only in 10.4+ CS, but also in 10.2+ ES
TODO-842: [m_status == DA_OK_BULK - LOCK]
=~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
=~ Diagnostics_area::set_ok_status
=~ my_ok
=~ LOCK.*TABLES
=~ Version: '10\.[2-9]


##########
# Fixed in the next release
##########

MDEV-24455:
=~ Assertion \`!m_freed_space'
=~ mtr_t::start
=~ btr_free_externally_stored_field
=~ Version: '10\.[5-9]
MDEV-24442:
=~ Assertion \`space->referenced()'
=~ fil_crypt_space_needs_rotation
=~ Version: '10\.[5-9]
MDEV-24220:
=~ signal|AddressSanitizer
=~ base_list_iterator::next|TABLE_LIST::is_recursive_with_table
=~ st_select_lex::cleanup
=~ sp_instr_stmt::execute|Prepared_statement::execute

##############################################################################
# Weak matches
##############################################################################

##########
# Fixed in the next release
##########

