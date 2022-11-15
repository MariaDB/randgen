#  Copyright (c) 2018, MariaDB
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; version 2 of the License.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA */


# Locking additions in 10.4:
# - MDEV-5336 - Lock for BACKUP

query_init_add:
  { @stages= ('START','FLUSH','BLOCK_DDL','BLOCK_COMMIT','END'); '' }
;

query_add:
  locks_104_query |
  query | query | query | query | query | query | query | query | query |
  query | query | query | query | query | query | query | query | query
;

locks_104_query:
  locks_104_backup_mariabackup_stages | locks_104_backup_mariabackup_stages |
  locks_104_backup_mariabackup_stages | locks_104_backup_mariabackup_stages |
  locks_104_backup_mariabackup_stages | locks_104_backup_mariabackup_stages |
  locks_104_backup_ordered_stages | locks_104_backup_ordered_stages |
  locks_104_backup_ordered_stages | locks_104_backup_ordered_stages |
  locks_104_backup_random_stage
;

locks_104_backup_random_stage:
  BACKUP STAGE { $prng->arrayElement(\@stages) } |
  BACKUP STAGE END |
  BACKUP STAGE END
;

locks_104_backup_mariabackup_stages:
  BACKUP STAGE START; BACKUP STAGE BLOCK_COMMIT; BACKUP STAGE END
;


locks_104_backup_ordered_stages:
  { $ordered_stages= ''; foreach $s (@stages) { $ordered_stages .= 'BACKUP STAGE '.$s.'; SELECT SLEEP(_digit); ' } }
;
