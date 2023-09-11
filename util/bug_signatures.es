# Bug signatures for recognizing known bugs by server and test logs

##############################################################################
# Strong matches
##############################################################################

MENT-1941:
=~ MemorySanitizer
=~ inline_mysql_file_write
=~ backup_log_ddl
=~ mysql_alter_table
=~ Version: '10\.5|Server version: 10\.5
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

##########
# Closed in the next release (10.4.32 / 10.5.23 / 10.6.16)
##########

##############################################################################
# Weak matches
##############################################################################
