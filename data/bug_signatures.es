# Bug signatures for recognizing known bugs by server and test logs

##############################################################################
# Strong matches
##############################################################################

MENT-809:
=~ mariabackup: Aria engine: starting recovery
=~ Got error 127 when executing|Got error 175 when executing
MENT-808:
=~ signal|AddressSanitizer|\`page_offset != 0 && page_offset <= page_length && page_length + length <= max_page_size'|\`page_offset - length <= page_length'|\`page_offset >= keypage_header && page_offset <= page_length'|\`page_offset != 0 && page_offset + length <= page_length'
=~ mariabackup
=~ exec_REDO_LOGREC_REDO_INDEX
=~ maria_apply_log
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

MDEV-23463:
=~ fil_page_compress
=~ buf_page_encrypt_before_write
=~ sp_head::execute
=~ Version: '10\.[2-4]
MDEV-23447:
=~ signal|AddressSanitizer
=~ fil_system_t::keyrotate_next
=~ fil_crypt_find_space_to_rotate
MDEV-23439:
=~ Assertion \`size == space->size'
=~ buf_read_ahead_random
=~ buf_page_get_gen
MDEV-23388:
=~ Assertion \`args\[0\]->decimals == 0'
=~ Item_func_round::fix_arg_int
=~ Type_handler_date_common
=~ Version: '10\.[4-9]
MDEV-23054:
=~ Assertion \`!item->null_value'
=~ Type_handler_inet6::make_sort_key_part
=~ make_sortkey
=~ Version: '10\.[5-9]
MDEV-19526:
=~ Assertion \`((val << shift) & mask) == (val << shift)'
=~ rec_set_bit_field_2
MDEV-14836:
=~ Assertion \`m_status == DA_ERROR'
=~ Diagnostics_area::sql_errno
=~ fill_schema_table_by_open
=~ LIMIT ROWS EXAMINED
MDEV-14119:
=~ Assertion \`cmp_rec_rec(rec, old_rec, offsets, old_offsets, m_index) > 0'
=~ PageBulk::insert
=~ row_merge_insert_index_tuples
=~ Version: '10\.[2-9]


##############################################################################
# Weak matches
##############################################################################

##########
# Fixed in the next release
##########

