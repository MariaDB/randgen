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
# Fixed in the next release (10.2.44 / 10.3.35 / 10.4.25 / 10.5.15 / 10.6.8)
##########

MDEV-28274:
=~ Assertion \`s <= READ_FIX'
=~ buf_page_t::set_state
=~ buf_read_page_low
=~ Version: '10\.[6-9]|Server version: 10\.[6-9]
MDEV-27668:
=~ Assertion \`item->type_handler()->is_traditional_scalar_type() \|\| item->type_handler() == type_handler()'
=~ Field_inet6::can_optimize_keypart_ref
=~ Version: '10\.[5-9]|Server version: 10\.[5-9]
MDEV-26551:
=~ InnoDB: Failing assertion: DICT_TF_HAS_DATA_DIR(table->flags)
=~ dict_save_data_dir_path
=~ Version: '10\.[6-9]|Server version: 10\.[6-9]
MDEV-25214:
=~ Assertion \`!node->is_open()'|signal 11
=~ fil_node_open_file
=~ fil_crypt_find_space_to_rotate
=~ Version: '10\.[6-9]|Server version: 10\.[6-9]
MDEV-23210:
=~ Assertion \`(length % 4) == 0'
=~ my_lengthsp_utf32
MDEV-22973:
=~ Assertion \`records_are_comparable(table)'
=~ compare_record
=~ multi_update::do_updates
=~ versioning|FeatureUsage detected system-versioned
=~ Version: '10\.[3-4]
MDEV-19631:
=~ Assertion \`0'
=~ st_select_lex_unit::optimize
=~ mysql_explain_union
=~ Prepared_statement::execute|sp_head::execute
MDEV-17223:
=~ Assertion \`thd->killed != 0'
=~ ha_maria::enable_indexes
=~ handler::ha_end_bulk_insert

##############################################################################
# Weak matches
##############################################################################

##########
# Fixed in the next release (10.2.44 / 10.3.35 / 10.4.25 / 10.5.15 / 10.6.8)
##########

