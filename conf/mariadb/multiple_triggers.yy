# Copyright (C) 2016 MariaDB Corporation.
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

query_init_add:
    CREATE TABLE IF NOT EXISTS test.tlog (
      pk INT NOT NULL AUTO_INCREMENT PRIMARY KEY, 
      dt TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6), 
      tbl VARCHAR(16), 
      tp ENUM('BEFORE','AFTER'), 
      op ENUM('INSERT','UPDATE','DELETE'),
      fld BLOB
    ); CREATE TABLE IF NOT EXISTS test.tlog2 (
        log_id INT NOT NULL,
        dt TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
        val BLOB NOT NULL DEFAULT '_'
    );

query_add:
      mdev6112_create_trigger | mdev6112_create_trigger | mdev6112_create_trigger | mdev6112_create_trigger
    | mdev6112_drop_trigger | mdev6112_drop_trigger
    | mdev6112_create_log_trigger | mdev6112_create_log2_trigger
    | query | query | query | query | query | query | query | query | query | query | query | query
;

mdev6112_create_log_trigger:
    /* QProp.ERROR_1099 QProp.ERROR_1100 */ mdev6112_create_clause test. mdev6112_trigger_name mdev6112_before_after INSERT ON test.tlog FOR EACH ROW mdev6112_precedes_follows INSERT INTO test.tlog2 VALUES ( NEW.`pk`, NOW(), NEW.`fld` );

# While we are here, add something for MDEV-8605
mdev6112_create_log2_trigger:
    /* QProp.ERROR_1099 QProp.ERROR_1100 */ mdev6112_create_clause test. mdev6112_trigger_name BEFORE INSERT ON test.tlog2 FOR EACH ROW mdev6112_precedes_follows SET NEW.`val` = IFNULL(NEW.`val`,'');

mdev6112_create_trigger:
    /* QProp.ERROR_1100 */ mdev6112_create_clause mdev6112_last_database . mdev6112_trigger_name mdev6112_before_after mdev6112_ins_upd_del ON /* QProp.ERROR_1361 QProp.ERROR_1347 */ mdev6112_table FOR EACH ROW mdev6112_precedes_follows INSERT INTO tlog (tbl,tp,op) VALUES ( { "'$last_table','$tp','$op'," . ($op eq 'DELETE' ? 'OLD' : 'NEW') } . _field );

mdev6112_trigger_name:
    # ER_SERVER_LOST can happen on any query if the connection is killed.
    # If it happens because the server crashes, we'll know about it anyway.
    /* QProp.ERROR_2013 */ _letter;

mdev6112_table:
    mdev6112_database . _table { ( lc($last_database) eq 'performance_schema' or lc($last_database) eq 'information_schema' ) ? '/* QProp.ERROR_1044 */' : ( lc($last_database) eq 'mysql' ? '/* QProp.ERROR_1465 */' : '' ) };

mdev6112_database:
      /* QProp.ERROR_1146 */
    | mdev6112_last_database
;

mdev6112_last_database:
    { $last_database or $last_database = 'test' } ;

mdev6112_drop_trigger:
      /* QProp.ERROR_1099 QProp.ERROR_1100 */ /* QProp.ERROR_1360 */ DROP TRIGGER mdev6112_trigger_name
    | /* QProp.ERROR_1099 QProp.ERROR_1100 */ /* QProp.ERROR_1360 */ DROP TRIGGER IF EXISTS mdev6112_trigger_name
;
    
mdev6112_create_clause:
      /* QProp.ERROR_1359 QProp.ERROR_7 */ CREATE TRIGGER
    | /* QProp.ERROR_1360 QProp.ERROR_7 */ CREATE OR REPLACE TRIGGER
    | /* QProp.ERROR_1360 QProp.ERROR_7 */ CREATE OR REPLACE TRIGGER
    | /* QProp.ERROR_7 */ CREATE TRIGGER IF NOT EXISTS
;
    
mdev6112_precedes_follows:
    | | | | /* QProp.ERROR_4031 */ /*!100202 PRECEDES _letter */ | /* QProp.ERROR_4031 */ /*!100202 FOLLOWS _letter */ ;
    
mdev6112_before_after:
    { $tp = ($prng->int(0,1) ? 'BEFORE' : 'AFTER' ) };

mdev6112_ins_upd_del:
    { $r = $prng->int(1,3); $op = ($r == 1 ? 'INSERT' : ( $r == 2 ? 'UPDATE' : 'DELETE' ) ) };

