# Bug signatures for recognizing known bugs by server and test logs
# The file is deprecated, use bug_signatures (with correct version numbers) instead

# 10.6+
# =~ Version: '10\.[6-9]\.[0-9][0-9]*-[0-9][0-9]*|Server version: 10\.[6-9]\.[0-9][0-9]*-[0-9][0-9]*|Version: '10\.1[01]\.[0-9][0-9]*-[0-9][0-9]*|Server version: 10\.1[01]\.[0-9][0-9]*-[0-9][0-9]*|Version: '1[1-9]\.[0-9][0-9]*\.[0-9][0-9]*-[0-9][0-9]*|Server version: 1[1-9]\.[0-9][0-9]*\.[0-9][0-9]*-[0-9][0-9]*
# 11.4+
# =~ Version: '11\.[4-9]\.[0-9][0-9]*-[0-9][0-9]*|Server version: 11\.[4-9]\.[0-9][0-9]*-[0-9][0-9]*|Version: '1[2-9]\.[0-9][0-9]*\.[0-9][0-9]*-[0-9][0-9]*|Server version: 1[2-9]\.[0-9][0-9]*\.[0-9][0-9]*-[0-9][0-9]*
# 11.8+
# =~ Version: '11\.[8-9]\.[0-9][0-9]*-[0-9][0-9]*|Server version: 11\.[8-9]\.[0-9][0-9]*-[0-9][0-9]*|Version: '1[2-9]\.[0-9][0-9]*\.[0-9][0-9]*-[0-9][0-9]*|Server version: 1[2-9]\.[0-9][0-9]*\.[0-9][0-9]*-[0-9][0-9]*

##############################################################################
# Strong matches
##############################################################################

# 10.5 is EOL
MENT-1941: [MemorySanitizer, inline_mysql_file_write]
=~ MemorySanitizer
=~ inline_mysql_file_write
=~ backup_log_ddl
=~ mysql_alter_table
=~ Version: '10\.5|Server version: 10\.5

##########
# Backport-related
##########

##########
# Closed in the next release (10.4.32 / 10.5.23 / 10.6.16)
##########

##############################################################################
# Weak matches
##############################################################################
