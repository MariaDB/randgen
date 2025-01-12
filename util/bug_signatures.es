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
# Closed in the next release (10.4.32 / 10.5.23 / 10.6.16)
##########

##############################################################################
# Weak matches
##############################################################################
