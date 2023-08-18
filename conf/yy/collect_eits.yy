#  Copyright (c) 2014, 2022, MariaDB
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


thread1_init:
  ANALYZE TABLE { @dbs= @{$executors->[0]->metaUserSchemas()}; @tables=(); foreach my $db (@dbs) { push @tables, (map { '`'.$db.'`.`'.$_.'`' } @{$executors->[0]->baseTables($db)}) } ; join ',',@tables } PERSISTENT FOR ALL;

query:
  { _set_db('NON-SYSTEM') } SET STATEMENT lock_wait_timeout=10 FOR analyze_persistent ;

analyze_persistent:
  ANALYZE TABLE _table PERSISTENT FOR ALL |
  ANALYZE TABLE _table, _table PERSISTENT FOR ALL |
  ANALYZE TABLE _table PERSISTENT FOR COLUMNS(_field) INDEXES (_index) |
  ANALYZE TABLE _table PERSISTENT FOR COLUMNS() INDEXES () |
  ANALYZE TABLE _table PERSISTENT FOR COLUMNS(_field) INDEXES ()
;
