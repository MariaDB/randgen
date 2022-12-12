# Copyright (c) 2010, 2012, Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2022, MariaDB
# Use is subject to license terms.
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
# This grammar aims at obtaining higher concurrency by running non-conflicting transactions in parallel.
# This is achieved by using the following characteristics:
#
# * Transactions are short and of bounded length
# * Each thread operates on a separate part of the integer space by using CONNECTION_ID()
# * All DML statements involve keys and/or LIMIT, to avoid full table scans and table-wide locks
#
# To get maximum concurrency, extra MySQLd options should be used, such as:
# * --mysqld=--innodb_flush_log_at_trx_commit=2
# * --mysqld=--transaction_isolation=READ-UNCOMMITTED
# * --innodb-lock-wait-timeout=0
# * --mysqld=--log-output=none
# * --mysqld=--skip-log-slave-updates
########################################################################

query_init:
  SET SQL_SAFE_UPDATES=1;
query:
  { _set_db('NON-SYSTEM') } transaction;

transaction:
  START TRANSACTION ;; query_list ;; commit_rollback ;

query_list:
  query_item |
  query_item ;; query_list ;

query_item:
  insert | update | delete ;

commit_rollback:
  COMMIT | COMMIT | COMMIT | COMMIT | COMMIT |
  COMMIT | COMMIT | COMMIT | COMMIT | ROLLBACK ;

insert:
  insert_replace INTO _table ( _field , _field ) VALUES ( value , value );

insert_replace:
  INSERT | REPLACE ;

update:
  UPDATE _table SET _field = value dml_filter;

delete:
  DELETE FROM _table dml_filter ;

dml_filter:
  WHERE `pk` = value |
  WHERE _field_indexed = value LIMIT 1;

value:
  CONNECTION_ID() |
  (CONNECTION_ID() * _thread_count) + _digit |
  (CONNECTION_ID() * _thread_count) + (_digit * 10) ;
