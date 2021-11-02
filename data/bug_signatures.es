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
# Fixed in the next release
##########

MDEV-26903:
=~ Assertion \`ctx->trx->state == TRX_STATE_ACTIVE'
=~ rollback_inplace_alter_table
=~ Version: '10\.[6-9]|Server version: 10\.[6-9]
MDEV-26772:
=~ Assertion \`err != DB_DUPLICATE_KEY'
=~ row_rename_table_for_mysql
=~ Version: '10\.[6-9]|Server version: 10\.[6-9]
MDEV-26220:
=~ signal|AddressSanitizer
=~ Field::register_field_in_read_map
=~ ha_partition::index_init
MDEV-25803:
=~ AddressSanitizer|signal 11
=~ skip_trailing_space|my_ismbchar
=~ _mi_pack_key
=~ ha_myisam::records_in_range
=~ Version: '10\.[5-9]|Server version: 10\.[5-9]
MDEV-24742:
=~ signal [16]|AddressSanitizer
=~ String::numchars
=~ in_string::set
=~ Item_func::fix_fields
MDEV-24619:
=~ Assertion \`0'
=~ Item::val_native
=~ Type_handler_inet6::Item_val_native_with_conversion|Inet6_null::Inet6_null
MDEV-24585:
=~ Assertion \`je->s\.cs == nice_js->charset()'
=~ json_nice
=~ Item_func_json_insert::val_str
MDEV-24467:
=~ Direct leak of|Memory not freed|blocks are definitely lost
=~ Binary_string::real_alloc|String::real_alloc
=~ Field_.*::store|Field_.*::val_.*
=~ FeatureUsage detected delayed inserts
MDEV-23408:
=~ Assertion \`!alias_arg \|\| strlen(alias_arg->str) == alias_arg->length'
=~ TABLE_LIST::init_one_table
=~ Locked_tables_list::init_locked_tables
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]
MDEV-23391:
=~ signal [16]|AddressSanitizer
=~ close_thread_table
=~ drop_open_table
=~ select_create::abort_result_set
MDEV-23391:
=~ Assertion \`thd->mdl_context\.is_lock_owner(MDL_key::TABLE, table->s->db\.str, table->s->table_name\.str, MDL_.*)'
=~ close_thread_table|TDC_element::flush
=~ Locked_tables_list::unlock_locked_tables|drop_open_table
=~ select_create::abort_result_set
MDEV-23365:
=~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
=~ Diagnostics_area::set_ok_status
=~ Sql_cmd_truncate_table::execute
=~ Version: '10\.[1-2]
MDEV-22660:
=~ signal [16]|AddressSanitizer
=~ Assertion \`row_end'|is_versioning_timestamp|Vers_type_timestamp::check_sys_fields|Vers_parse_info::check_sys_fields
=~ Table_scope_and_contents_source_st::check_fields
=~ mysql_alter_table
MDEV-22601:
=~ Assertion \`0'
=~ Protocol::end_statement
=~ Can't find record in|Невозможно найти запись в
=~ FeatureUsage detected sequences
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]
MDEV-22445:
=~ InnoDB: Assertion failure in file .*innobase/trx/trx0trx\.cc
=~ trx_start_if_not_started_xa_low
=~ ha_innobase::init_table_handle_for_HANDLER
MDEV-22284:
=~ signal 11|AddressSanitizer
=~ _ma_keylength_part|_ma_row_pos_from_key|memcpy|_ma_search_no_save
=~ ha_maria::index_read_idx_map
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]
MDEV-22284:
=~ Assertion \`info->last_key\.keyinfo == key->keyinfo'
=~ _ma_search_no_save
=~ ha_maria::index_read_idx_map
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]
MDEV-22118:
=~ Assertion \`nr != 0'
=~ handler::update_auto_increment
=~ handler::ha_write_row
MDEV-21555:
=~ InnoDB: foreign constraints: secondary index is out of sync
=~ Assertion \`!"secondary index is out of sync"'|Assertion \`"secondary index is out of sync" == 0'
=~ dict_index_t::vers_history_row
=~ row_upd_check_references_constraints|row_ins_check_foreign_constraint
MDEV-20131:
=~ Assertion \`!pk->has_virtual()'
=~ instant_alter_column_possible
=~ ha_innobase::check_if_supported_inplace_alter
MDEV-19522:
=~ Assertion \`val <= 4294967295u'|InnoDB: Failing assertion: val <= 4294967295u
=~ fts_encode_int
=~ fts_cache_node_add_positions
=~ fts_commit_table
MDEV-19522:
=~ InnoDB: Failing assertion: doc_id == src_node->last_doc_id
=~ fts_optimize_node
=~ ha_innobase::optimize
MDEV-18734:
=~ AddressSanitizer: heap-use-after-free|Invalid read of size
=~ my_strnxfrm_simple_internal
=~ Field_blob::sort_string


##############################################################################
# Weak matches
##############################################################################

##########
# Fixed in the next release
##########

MDEV-22601: [Can't find record in]
=~ Can't find record in|Невозможно найти запись в
=~ will exit with exit status STATUS_DATABASE_CORRUPTION
=~ FeatureUsage detected sequences
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]
=~ will exit with exit status STATUS_DATABASE_CORRUPTION
MDEV-14846:
=~ prebuilt->trx, TRX_STATE_ACTIVE
MDEV-14846:
=~ state == TRX_STATE_FORCED_ROLLBACK
