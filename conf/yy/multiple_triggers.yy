# Copyright (C) 2016, 2022 MariaDB Corporation.
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

#
# MDEV-6112 - multiple triggers per table
# Introduced in 10.2.3
#

# Expected error codes (when used with various grammars):

#    7 - Error on rename of './test/tr.TRN~' to './test/tr.TRN' (Errcode: 2 - No such file or directory)
# 1044 - (ER_DBACCESS_DENIED_ERROR): Access denied for user '%s'@'%s' to database '%-.192s'
# 1099 - (ER_TABLE_NOT_LOCKED_FOR_WRITE): Table '%-.192s' was locked with a READ lock and can't be updated
# 1100 - (ER_TABLE_NOT_LOCKED): Table '%-.192s' was not locked with LOCK TABLES
# 1146 - (ER_NO_SUCH_TABLE): Table '%-.192s.%-.192s' doesn't exist
# 1347 - (ER_WRONG_OBJECT): '%-.192s.%-.192s' is not %s
# 1359 - (ER_TRG_ALREADY_EXISTS): Trigger already exists
# 1360 - (ER_TRG_DOES_NOT_EXIST): Trigger does not exist
# 1361 - (ER_TRG_ON_VIEW_OR_TEMP_TABLE): Trigger's '%-.192s' is view or temporary table
# 1465 - (ER_NO_TRIGGERS_ON_SYSTEM_SCHEMA): Triggers can not be created on system tables
# 2013 - (ER_SERVER_LOST): Lost connection to MySQL server during query
# 4031 (new) - (ER_REFERENCED_TRG_DOES_NOT_EXIST): Referenced trigger '%s' for the given action time and event type does not exist

# Notes:
# ERROR 7 is here because of MDEV-10932 (Concurrent trigger creation causes errors and corrupts the trigger)
# ERROR 1360 for CREATE OR REPLACE TRIGGER is added because of MDEV-10912 (CREATE OR REPLACE TRIGGER produces ER_TRG_DOES_NOT_EXIST)
# ERROR 1360 for DROP TRIGGER IF EXISTS is also because of one of these two problems

query_init:
     CREATE DATABASE IF NOT EXISTS multi_trigger_db
  ;; SET ROLE admin
     # PS is a workaround for MDEV-30190
  ;; EXECUTE IMMEDIATE CONCAT('GRANT ALL ON multi_trigger_db.* TO ',CURRENT_USER,' WITH GRANT OPTION')
  ;; SET ROLE NONE
     # To prevent the tables from being modified, as we need the structures
     # PS is a workaround for MDEV-30190
  ;; EXECUTE IMMEDIATE CONCAT('REVOKE ALTER, DROP ON multi_trigger_db FROM ',CURRENT_USER)
  ;; { _set_db('multi_trigger_db') }
  CREATE TABLE IF NOT EXISTS multi_trigger_db.tlog (
    pk INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    dt TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    tbl VARCHAR(16),
    tp ENUM('BEFORE','AFTER'),
    op ENUM('INSERT','UPDATE','DELETE'),
    fld BLOB
  )
  ;; CREATE TABLE IF NOT EXISTS multi_trigger_db.tlog2 (
      log_id INT NOT NULL,
      dt TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
      val BLOB NOT NULL DEFAULT '_'
  )
;

query:
    ==FACTOR:4== { _set_db('NON-SYSTEM') } create_trigger |
    ==FACTOR:2== { _set_db('NON-SYSTEM') } drop_trigger |
    { _set_db('ANY') } create_log_trigger |
    { _set_db('ANY') } create_log2_trigger
;

create_log_trigger:
    create_clause multi_trigger_db.trigger_name before_after INSERT ON multi_trigger_db.tlog FOR EACH ROW precedes_follows INSERT INTO multi_trigger_db.tlog2 VALUES ( NEW.`pk`, NOW(), NEW.`fld` );

create_log2_trigger:
    create_clause multi_trigger_db. trigger_name BEFORE INSERT ON multi_trigger_db.tlog2 FOR EACH ROW precedes_follows SET NEW.`val` = IFNULL(NEW.`val`,'');

create_trigger:
    create_clause /* _basetable[invariant] */ { $last_database }.trigger_name before_after ins_upd_del ON _basetable[invariant] FOR EACH ROW precedes_follows INSERT INTO multi_trigger_db.tlog (tbl,tp,op) VALUES ( { "'$last_table','$tp','$op'," . ($op eq 'DELETE' ? 'OLD' : 'NEW') } . _field );

trigger_name:
    _letter ;

drop_trigger:
  DROP TRIGGER __if_exists(90) trigger_name ;

create_clause: 
  CREATE __or_replace_trigger_x_trigger_if_not_exists_x_trigger(50,40) ;

precedes_follows:
    ==FACTOR:4== |
    PRECEDES _letter |
    FOLLOWS _letter
;

before_after:
    { $tp = ($prng->int(0,1) ? 'BEFORE' : 'AFTER' ) };

ins_upd_del:
    { $r = $prng->int(1,3); $op = ($r == 1 ? 'INSERT' : ( $r == 2 ? 'UPDATE' : 'DELETE' ) ) };
