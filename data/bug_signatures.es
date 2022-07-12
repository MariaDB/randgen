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
# Fixed in the next release (10.3.36 / 10.4.26 / 10.5.16 / 10.6.9)
##########

MDEV-28950:
=~ Assertion \`\*err == DB_SUCCESS'
=~ btr_page_split_and_insert
=~ btr_root_raise_and_insert
=~ Version: '10\.[6-9]|Server version: 10\.[6-9]|Version: '10\.1[0-9]|Server version: 10\.1[0-9]
MDEV-28897:
=~ Assertion \`table\.get_ref_count() <= 1'
=~ trx_t::drop_table
=~ ha_partition::truncate
=~ Version: '10\.[6-9]|Server version: 10\.[6-9]|Version: '10\.1[0-9]|Server version: 10\.1[0-9]
MDEV-28897:
=~ Failing assertion: table->get_ref_count() == 0
=~ dict_sys_t::remove
=~ ha_partition::truncate
=~ Version: '10\.[6-9]|Server version: 10\.[6-9]|Version: '10\.1[0-9]|Server version: 10\.1[0-9]
MDEV-26979:
=~ AddressSanitizer|signal
=~ dict_sys_t::allow_eviction
=~ i_s_sys_tables_fill_table_stats
=~ Version: '10\.[6-9]|Server version: 10\.[6-9]|Version: '10\.1[0-9]|Server version: 10\.1[0-9]
MDEV-26127:
=~ Failing assertion: id != 0
=~ dict_table_t::rename_tablespace
=~ row_undo
=~ Query .* PARTITION
MDEV-26127:
=~ Assertion \`err != DB_DUPLICATE_KEY'
=~ row_rename_table_for_mysql
=~ handler::ha_rename_partitions
=~ Query .* PARTITION
MDEV-21027:
=~ Assertion \`part_share->auto_inc_initialized \|\| !can_use_for_auto_inc_init()'
=~ ha_partition::set_auto_increment_if_higher
=~ ha_partition::write_row
=~ Version: '10\.[3-9]|Server version: 10\.[3-9]|Version: '10\.1[0-9]|Server version: 10\.1[0-9]
MDEV-14642:
=~ Assertion \`table->s->db_create_options == part_table->s->db_create_options'
=~ compare_table_with_partition
=~ Sql_cmd_alter_table_exchange_partition::exchange_partition

##############################################################################
# Weak matches
##############################################################################

##########
# Fixed in the next release (10.3.36 / 10.4.26 / 10.5.16 / 10.6.9)
##########

