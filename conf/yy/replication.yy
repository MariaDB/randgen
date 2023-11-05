# Copyright (C) 2008 Sun Microsystems, Inc. All rights reserved.
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
# Rather random set of statements which is meant to employ replication
########################################################################

query:
  { _set_db('NON-SYSTEM') } replication_query ;

replication_query:
  ==FACTOR:20== binlog_event_chain |
  ddl
;

binlog_event_chain:
  dml_list |
  user_var_set ;; user_var_dml |
  implicit_commit_chain |
  FLUSH LOGS |
  ==FACTOR:10== binlog_event
;

dml_list:
  dml |
  ==FACTOR:3== dml ;; dml_list ;

binlog_event:
  delete |
  insert |
  update |
  xid_event |
  implicit_commit |
  dml |
  intvar_event |
  rand_event_dml |
  user_var_set |
  user_var_dml ;

intvar_event:
  intvar_event_pk | intvar_event_last_insert_id ;

intvar_event_pk:
  INSERT __ignore(90) INTO _table ( _field_pk ) VALUES ( NULL ) ;

intvar_event_last_insert_id:
  INSERT __ignore(90) INTO _table ( _field ) VALUES ( LAST_INSERT_ID() ) ;

rand_event_dml:
  INSERT __ignore(90) INTO _table ( _field ) VALUES ( RAND (_int_unsigned) ) |
  UPDATE __ignore(90) _table SET _field = RAND(_int_unsigned) where ORDER BY RAND (_int_unsigned) limit |
  DELETE FROM _table WHERE _field < RAND(_int_unsigned) limit ;

user_var_set:
  SET @a = value ;

user_var_dml:
  INSERT __ignore(90) INTO _table ( _field ) VALUES ( @a ) |
  UPDATE __ignore(90) _table SET _field = @a ORDER BY _field LIMIT _digit |
  DELETE FROM _table WHERE _field < @a LIMIT 1 ;

xid_event:
  START TRANSACTION | COMMIT | ROLLBACK |
  SAVEPOINT A | ROLLBACK TO SAVEPOINT A | RELEASE SAVEPOINT A ;

implicit_commit_chain:
  CREATE DATABASE ic ;; CREATE TABLE ic.ic SELECT * FROM _table LIMIT _digit ;; DROP DATABASE ic |
  LOCK TABLE _table WRITE ;; UNLOCK TABLES |
  SELECT * INTO OUTFILE _tmpnam FROM _table LIMIT _digit ;; LOAD DATA INFILE _tmpnam REPLACE INTO TABLE _table |
  ==FACTOR:10== implicit_commit
;

implicit_commit:
  CREATE USER _letter | DROP USER _letter | RENAME USER _letter TO _letter |
  SET AUTOCOMMIT = ON | SET AUTOCOMMIT = OFF |
  CREATE __table_if_not_exists_x_or_replace_table test.{ 'rpl_'.$prng->uint16(1,9) } ENGINE = engine SELECT * FROM _table LIMIT _digit |
  RENAME TABLE test.{ 'rpl_'.$prng->uint16(1,9) } TO test.{ 'rpl_'.$prng->uint16(1,9) } |
  TRUNCATE TABLE test.{ 'rpl_'.$prng->uint16(1,9) } |
  DROP TABLE IF EXISTS test.{ 'rpl_'.$prng->uint16(1,9) } |
  CREATE DATABASE IF NOT EXISTS ic |
  CREATE TABLE IF NOT EXISTS ic.ic SELECT * FROM _table LIMIT _digit |
  DROP DATABASE ic
;

begin_load_query_event:
  load_data_infile ;

execute_load_query_event:
  load_data_infile ;

load_data_infile:
  SELECT * INTO OUTFILE _tmpnam FROM _table ORDER BY _field LIMIT _digit;; LOAD DATA INFILE _tmpnam REPLACE INTO TABLE _table ;

binlog_format_statement:
  SET @binlog_format_saved = @@binlog_format ;; SET BINLOG_FORMAT = 'STATEMENT' ;

binlog_format_row:
  SET @binlog_format_saved = @@binlog_format ;; SET BINLOG_FORMAT = 'ROW' ;

binlog_format_restore:
  SET BINLOG_FORMAT = @binlog_format_saved ;

dml:
  insert | update | delete ;

insert:
  INSERT __ignore(90) INTO _table ( _field ) VALUES ( value ) ;

update:
  UPDATE __ignore(90) _table SET _field = value where order_by limit ;

delete:
  DELETE FROM _table where LIMIT 1 ;

ddl:
  CREATE TRIGGER _letter trigger_time trigger_event ON _table FOR EACH ROW BEGIN procedure_body ; END |
  CREATE EVENT IF NOT EXISTS _letter ON SCHEDULE EVERY _digit SECOND ON COMPLETION PRESERVE DO BEGIN procedure_body ; END |
  CREATE PROCEDURE _letter () BEGIN procedure_body ; END
;

# It is a procedure body, so it should not be split to separate statements, hence no ';;'
procedure_body:
  binlog_event ; binlog_event ; binlog_event ; CALL _letter ()
;

trigger_time:
        BEFORE | AFTER ;

trigger_event:
        INSERT | UPDATE ;

engine:
  Innodb | MyISAM ;

where:
  WHERE _field > value |
  WHERE _field < value |
  WHERE _field = value ;

order_by:
  | ORDER BY _field ;

limit:
  | LIMIT _digit ;

value:
  _digit | _english | NULL ;
