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

########################################################################
# 1. This grammar is based on table discovery, so it requires FederatedX,
# does not work with old Federated.
#
# 2. Federated doesn't support GIS, so discovery fails with ugly errors
# when the remote table has geometry columns (MDEV-30149). The errors
# are suppressed by the executor, but when possible, it's better to avoid
# GIS in the same run with Federated
########################################################################

#features Federated tables

query_init:
     # We are doing it this way because otherwise set_db later may pick up a newly created empty federated database
     { @all_databases=(); foreach my $s (@{$executors->[0]->metaAllSchemas()}) { push @all_databases, $s if $s !~ /^fed_db(_remote)?/ }; @user_databases=(); foreach my $s (@{$executors->[0]->metaUserSchemas()}) { push @user_databases, $s if $s !~ /^fed_db(_remote)?$/ }; '' }
     CREATE DATABASE IF NOT EXISTS fed_db
  ;; CREATE DATABASE IF NOT EXISTS fed_db_remote
  ;; SET ROLE admin
     # PS is a workaround for MDEV-30190
  ;; EXECUTE IMMEDIATE CONCAT('GRANT ALL ON fed_db.* TO ',CURRENT_USER,' WITH GRANT OPTION')
  ;; EXECUTE IMMEDIATE CONCAT('GRANT ALL ON fed_db_remote.* TO ',CURRENT_USER,' WITH GRANT OPTION')
  ;; CREATE USER IF NOT EXISTS fed_user@'127.0.0.1' IDENTIFIED BY 'FdrUs3r!pw'
  ;; GRANT INSERT, UPDATE, DELETE, SELECT, EXECUTE ON *.* TO fed_user@'127.0.0.1'
  ;; SET STATEMENT binlog_format=statement FOR INSERT IGNORE INTO mysql.servers (Server_name, Host, Db, Username, Password, Port, Wrapper) VALUES ('fedlink','127.0.0.1','fed_db_remote','fed_user','FdrUs3r!pw',@@port,'mysql')
  ;; FLUSH PRIVILEGES
  ;; SET ROLE NONE
  ;; create_remote_table_init ;; create_remote_table_init ;; create_remote_table_init
  ;; create_remote_table_init ;; create_remote_table_init ;; create_remote_table_init
  ;; create_federated_table_init ;; create_federated_table_init ;; create_federated_table_init
  ;; create_federated_table_init ;; create_federated_table_init ;; create_federated_table_init
;

query:
    ==FACTOR:6== create_federated_table
  | ==FACTOR:2== { _set_db('fed_db') } ALTER TABLE _table __force(50)
  |               create_remote_table
  |              { _set_db('fed_db') } DROP TABLE IF EXISTS _table
;

create_federated_table:
    { _set_db('fed_db_remote') } CREATE OR REPLACE TABLE fed_db. _table ENGINE=FEDERATED CONNECTION = { "'fedlink/".$last_table."'" } ;

create_federated_table_init:
    { _set_db('fed_db_remote') } CREATE OR REPLACE TABLE fed_db. { $last_table= $prng->arrayElement(\@remote_tables) } ENGINE=FEDERATED CONNECTION = { "'fedlink/".$last_table."'" } ;

create_remote_table:
  { _set_db('NON-SYSTEM') } CREATE /* _basetable[invariant] */ OR REPLACE TABLE fed_db_remote.{ $last_table } LIKE _basetable[invariant] ;; INSERT IGNORE INTO fed_db_remote.{ $last_table } SELECT * FROM _basetable[invariant] |
  { _set_db('ANY') }  CREATE /* _table[invariant] */ OR REPLACE TABLE fed_db_remote.{ $last_table } AS SELECT * FROM _table[invariant]
;

create_remote_table_init:
  { _set_db('NON-SYSTEM') } CREATE /* _basetable[invariant] */ OR REPLACE TABLE fed_db_remote.{ $last_table } LIKE _basetable[invariant] ;; INSERT IGNORE INTO fed_db_remote.{ $last_table } SELECT * FROM _basetable[invariant]  { push @remote_tables, $last_table; '' } |
  { _set_db('ANY') } CREATE /* _table[invariant] */ OR REPLACE TABLE fed_db_remote.{ $last_table } AS SELECT * FROM _table[invariant] { push @remote_tables, $last_table; '' }
;