# Bug signatures for recognizing known bugs by server and test logs

##############################################################################
# Strong matches
##############################################################################

MENT-2202: [ASAN heap-use-after-free in vprint_msg_to_blackbox]
=~ AddressSanitizer: heap-use-after-free
=~ process_str_arg
=~ vprint_msg_to_blackbox
=~ Version: '11\.4|Server version: 11\.4
MENT-1942: [aria-block-size, can't open control file]
=~ Can't open Aria control file (0)
=~ mysqld=--aria-block-size=
MENT-1941: [MemorySanitizer, inline_mysql_file_write]
=~ MemorySanitizer
=~ inline_mysql_file_write
=~ backup_log_ddl
=~ mysql_alter_table
=~ Version: '10\.5|Server version: 10\.5
MENT-1844: [Assertion new_engine]
=~ Assertion \`\*new_engine'
=~ check_engine
=~ Version: '10\.4|Server version: 10\.4
MENT-809: [Error 127, 175 in mariabackup]
=~ mariabackup: Aria engine: starting recovery
=~ Got error 127 when executing|Got error 175 when executing
MENT-319: [backup_flush_ticket == 0]
=~ Assertion \`backup_flush_ticket == 0'
=~ backup_start

##########
# Backport-related
##########

# 10.11 CS, 10.6 ES
MDEV-37264:
=~ AddressSanitizer|signal
=~ key_copy
=~ ha_partition::position
=~ Version: '10\.[6-9]|Server version: 10\.[6-9]|Version: '10\.1[01]|Server version: 10\.1[01]|Version: '1[1-9]\.[0-9][0-9]*|Server version: 1[1-9]\.[0-9][0-9]*
MDEV-37264:
=~ InnoDB: Failing assertion: field->col->mtype == type
=~ row_sel_convert_mysql_key_to_innobase
=~ ha_partition::rnd_pos
=~ Version: '10\.[6-9]|Server version: 10\.[6-9]|Version: '10\.1[01]|Server version: 10\.1[01]|Version: '1[1-9]\.[0-9][0-9]*|Server version: 1[1-9]\.[0-9][0-9]*
MDEV-36906:
=~ signal|AddressSanitizer
=~ Rows_log_event::find_row
=~ apply_event_and_update_pos
=~ FeatureUsage detected partitioned tables
=~ Version: '10\.[6-9]|Server version: 10\.[6-9]|Version: '10\.1[01]|Server version: 10\.1[01]|Version: '1[1-9]\.[0-9][0-9]*|Server version: 1[1-9]\.[0-9][0-9]*
# 11.5 CS, 11.4 ES
MDEV-34134:
=~ Assertion \`!before_record \|\| bitmap_is_set_all(table->read_set)'
=~ online_alter_log_row
=~ Version: '11\.[4-9]|Server version: 11\.[4-9]|Version: '1[2-9]\.[0-9]|Server version: 1[2-9]\.[0-9]

##########
# Closed in the next release (10.4.32 / 10.5.23 / 10.6.16)
##########

##############################################################################
# Weak matches
##############################################################################
