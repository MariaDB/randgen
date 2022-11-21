#  Copyright (c) 2022, MariaDB Corporation Ab
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
    CREATE DATABASE IF NOT EXISTS fed_db
  ;; CREATE USER IF NOT EXISTS fed_user@'127.0.0.1' IDENTIFIED BY 'FdrUs3r!pw'
  ;; GRANT ALL ON *.* TO fed_user@'127.0.0.1'
  ;; SET STATEMENT binlog_format=statement FOR INSERT INTO mysql.servers (Server_name, Host, Db, Username, Password, Port, Wrapper) VALUES ('fedlink','127.0.0.1','test','fed_user','FdrUs3r!pw',@@port,'mysql')
  ;; FLUSH PRIVILEGES
  ;; fed_create_federated_table
  ;; fed_create_federated_table
  ;; fed_create_federated_table
  ;; fed_create_federated_table
  ;; fed_create_federated_table
  ;; fed_create_federated_table
  ;; fed_create_federated_table
  ;; fed_create_federated_table
;

fed_create_federated_table:
    SELECT CONCAT("CREATE OR REPLACE TABLE fed_db.", table_name, " ENGINE=FEDERATED CONNECTION='fedlink/", table_name, "'") INTO @stmt FROM information_schema.tables WHERE table_schema = 'test' AND table_type = 'BASE TABLE' ORDER BY RAND(_int_unsigned) LIMIT 1
  ; PREPARE stmt FROM @stmt
  ; EXECUTE stmt
  ; DEALLOCATE PREPARE stmt
;

query:
    ==FACTOR:5== fed_create_federated_table
  | ==FACTOR:2== { $last_database = 'fed_db' ; '' } ALTER TABLE fed_db . _table __force(50)
  |              { $last_database = 'fed_db' ; '' } DROP TABLE IF EXISTS fed_db . _table
;
