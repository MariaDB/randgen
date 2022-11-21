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
  SET debug_dbug = '' | SET debug_dbug = sql_table_dbug_execute_if ;

sql_table_dbug_execute_if:
  '+d,hack01_rm_table_no_locks_before_delete_table' |
  '+d,hack02_rm_table_no_locks_before_binlog' |
  '+d,hack03_locked_table_name' |
  '+d,hack04_create_table_like_after_open' |
  '+d,hack05_create_table_like_before_binlog' |
  '+d,hack06_alter_table_enable_indexes' |
  '+d,hack07_alter_table_inplace_after_lock_upgrade' |
  '+d,hack08_alter_table_inplace_after_lock_downgrade' |
  '+d,hack09_alter_table_inplace_before_lock_upgrade' |
  '+d,hack10_alter_table_inplace_before_commit' |
  '+d,hack11_alter_table_inplace_after_commit' |
  '+d,hack12_alter_table_before_open_tables' |
  '+d,hack13_alter_table_after_open_tables' |
  '+d,hack14_alter_opened_table' |
  '+d,hack15_locked_table_name' |
  '+d,hack16_alter_table_before_create_table_no_lock' |
  '+d,hack17_alter_table_copy_after_lock_upgrade' |
  '+d,hack18_alter_table_intermediate_table_created' |
  '+d,hack19_alter_table_before_rename_result_table' |
  '+d,hack20_alter_table_before_main_binlog' |
  '+d,hack21_alter_table_inplace_trans_commit' |
  '+d,hack22_alter_table_after_temp_table_drop' |
  '+d,hack23_alter_table_after_temp_table_drop' |
  '+d,hack24_alter_table_copy_trans_commit' |
  '+d,hack25_alter_table_online_progress' |
  '+d,hack26_alter_table_online_downgraded' |
  '+d,hack27_copy_data_between_tables_before' |
  '+d,hack28_alter_table_copy_end' |
  '+d,hack29_alter_table_online_before_lock' |
  '+d,hack30_copy_data_between_tables_before_reset_backup_lock'
;
