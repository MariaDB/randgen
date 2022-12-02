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

query_init:
     get_charsets
     # We are doing it this way because otherwise set_db later may pick up a newly created empty spider database
     { @all_databases=(); foreach my $s (@{$executors->[0]->metaAllSchemas()}) { push @all_databases, $s if $s !~ /^spider_db(_remote)?/ }; @user_databases=(); foreach my $s (@{$executors->[0]->metaUserSchemas()}) { push @user_databases, $s if $s !~ /^spider_db(_remote)?$/ }; '' }
     CREATE DATABASE IF NOT EXISTS spider_db
  ;; CREATE DATABASE IF NOT EXISTS spider_db_remote
  ;; CREATE USER IF NOT EXISTS spider_user@'127.0.0.1' IDENTIFIED BY 'SpdrUs3r!pw'
  ;; GRANT ALL ON *.* TO spider_user@'127.0.0.1'
  ;; SET STATEMENT binlog_format=statement FOR INSERT IGNORE INTO mysql.servers (Server_name, Host, Db, Username, Password, Port, Wrapper) VALUES ('s','127.0.0.1','spider_db_remote','spider_user','SpdrUs3r!pw',@@port,'mysql')
  ;; FLUSH PRIVILEGES
     { @remote_tables= (); '' }
  ;; create_remote_table_init ;; create_remote_table_init ;; create_remote_table_init
  ;; create_remote_table_init ;; create_remote_table_init ;; create_remote_table_init
  ;; create_spider_table_init ;; create_spider_table_init ;; create_spider_table_init
  ;; create_spider_table_init ;; create_spider_table_init ;; create_spider_table_init
;

get_charsets:
  { @charsets= (); map { push @charsets, $_ if ($_ ne 'utf32' && $_ ne 'utf16' && $_ ne 'ucs2' && $_ ne 'utf16le') } @{$executors->[0]->metaCharactersets()}; '' };

query:
    ==FACTOR:6== create_spider_table
  | ==FACTOR:2== { _set_db('spider_db') } ALTER TABLE _table __force(50)
  |               create_remote_table
  |              { _set_db('spider_db') } DROP TABLE IF EXISTS _table
;

create_spider_table:
  { _set_db('spider_db_remote') }
     CREATE OR REPLACE TABLE spider_db. _table LIKE { $last_table }
  ;; ALTER TABLE spider_db.{$last_table} ENGINE=SPIDER COMMENT = { '"wrapper '."'mysql', srv 's', table '".$last_table."'".'"' } CHARACTER SET { $prng->arrayElement(\@charsets) };

create_spider_table_init:
  { _set_db('spider_db_remote') }
     CREATE OR REPLACE TABLE spider_db. { $last_table= $prng->arrayElement(\@remote_tables) } LIKE { $last_table }
  ;; ALTER TABLE spider_db.{ $last_table } ENGINE=SPIDER COMMENT = { '"wrapper '."'mysql', srv 's', table '".$last_table."'".'"' } CHARACTER SET { $prng->arrayElement(\@charsets) };

create_remote_table:
  { _set_db('user') } CREATE OR REPLACE TABLE spider_db_remote._table LIKE { $last_table } ;; INSERT IGNORE INTO spider_db_remote.{ $last_table } SELECT * FROM { $last_table } |
  { _set_db('any') }  CREATE OR REPLACE TABLE spider_db_remote._table AS SELECT * FROM { $last_table }
;

create_remote_table_init:
  { _set_db($prng->arrayElement(\@user_databases)) } CREATE OR REPLACE TABLE spider_db_remote._table LIKE { $last_table } ;; INSERT IGNORE INTO spider_db_remote.{ $last_table } SELECT * FROM { $last_table }  { push @remote_tables, $last_table; '' } |
  { _set_db($prng->arrayElement(\@all_databases)) } CREATE OR REPLACE TABLE spider_db_remote._table AS SELECT * FROM { $last_table } { push @remote_tables, $last_table; '' }
;
