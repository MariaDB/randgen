# Bug signatures for recognizing known bugs by server and test logs

##############################################################################
# Strong matches
##############################################################################

MENT-1844:
=~ Assertion \`\*new_engine'
=~ check_engine
=~ Version: '10\.4|Server version: 10\.4
MENT-809:
=~ mariabackup: Aria engine: starting recovery
=~ Got error 127 when executing|Got error 175 when executing
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
# Only in 10.4+ CS, but also in 10.3 ES
MDEV-24349:
=~ AddressSanitizer|signal [16]|Assertion \`name\.length == strlen(name\.str)'
=~ get_quote_char_for_identifier|Item::print_item_w_name
=~ st_select_lex::print
=~ Version: '10\.3|Server version: 10\.3
# Only 10.4+ CS, but also 10.3 ES
MDEV-24349:
=~ AddressSanitizer|signal [16]|Assertion \`name\.length == strlen(name\.str)'
=~ get_quote_char_for_identifier|Item::print_item_w_name
=~ st_select_lex::print
=~ Version: '10\.3|Server version: 10\.3

##########
# Closed in the next release (10.4.31 / 10.5.22 / 10.6.15)
##########

MDEV-31380:
=~ Assertion \`s->table->opt_range_condition_rows <= s->found_records'
=~ apply_selectivity_for_table
=~ Version: '10\.[5-9]|Server version: 10\.[5-9]|Version: '10\.1[01]|Server version: 10\.1[01]
MDEV-31264:
=~ Assertion \`mode == 16 \|\| mode == 12'
=~ buf_page_get_low
=~ row_purge_del_mark
=~ Version: '10\.[6-9]|Server version: 10\.[6-9]|Version: '10\.1[01]|Server version: 10\.1[01]|Version: '1[1-9]\.[0-9]|Server version: 1[1-9]\.[0-9]
MDEV-31201:
=~ LeakSanitizer
=~ String::real_alloc
=~ cmp_item_sort_string_in_static::store_value
=~ Version: '10\.3|Server version: 10\.3

##############################################################################
# Weak matches
##############################################################################

##########
# Closed in the next release (10.4.31 / 10.5.22 / 10.6.15)
##########

