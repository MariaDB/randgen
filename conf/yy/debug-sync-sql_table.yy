# Copyright (c) 2022, MariaDB
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
# USA

########################################################################

query:
  SET debug_sync= RESET |
  ==FACTOR:2== SET debug_sync= 'now SIGNAL goforit' |
  ==FACTOR:0.1== SET debug_sync= sql_table_debug_sync
;

sql_table_debug_sync:
  'rm_table_no_locks_before_delete_table WAIT_FOR goforit' |
  'rm_table_no_locks_before_binlog WAIT_FOR goforit' |
  'locked_table_name WAIT_FOR goforit' |
  'create_table_like_after_open WAIT_FOR goforit' |
  'create_table_like_before_binlog WAIT_FOR goforit' |
  'alter_table_enable_indexes WAIT_FOR goforit' |
  'alter_table_inplace_after_lock_upgrade WAIT_FOR goforit' |
  'alter_table_inplace_after_lock_downgrade WAIT_FOR goforit' |
  'alter_table_inplace_before_lock_upgrade WAIT_FOR goforit' |
  'alter_table_inplace_before_commit WAIT_FOR goforit' |
  'alter_table_inplace_after_commit WAIT_FOR goforit' |
  'alter_table_before_open_tables WAIT_FOR goforit' |
  'alter_table_after_open_tables WAIT_FOR goforit' |
  'alter_opened_table WAIT_FOR goforit' |
  'locked_table_name WAIT_FOR goforit' |
  'alter_table_before_create_table_no_lock WAIT_FOR goforit' |
  'alter_table_copy_after_lock_upgrade WAIT_FOR goforit' |
  'alter_table_intermediate_table_created WAIT_FOR goforit' |
  'alter_table_before_rename_result_table WAIT_FOR goforit' |
  'alter_table_before_main_binlog WAIT_FOR goforit' |
  'alter_table_inplace_trans_commit WAIT_FOR goforit' |
  'alter_table_after_temp_table_drop WAIT_FOR goforit' |
  'alter_table_after_temp_table_drop WAIT_FOR goforit' |
  'alter_table_copy_trans_commit WAIT_FOR goforit' |
  'alter_table_online_progress WAIT_FOR goforit' |
  'alter_table_online_downgraded WAIT_FOR goforit' |
  'copy_data_between_tables_before WAIT_FOR goforit' |
  'alter_table_copy_end WAIT_FOR goforit' |
  'alter_table_online_before_lock WAIT_FOR goforit' |
  'copy_data_between_tables_before_reset_backup_lock WAIT_FOR goforit'
;
