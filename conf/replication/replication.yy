# Copyright (C) 2008 Sun Microsystems, Inc. All rights reserved.
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

query:
	binlog_event | binlog_event | binlog_event | binlog_event | binlog_event |
	binlog_event | binlog_event | binlog_event | binlog_event | binlog_event |
	binlog_event | binlog_event | binlog_event | binlog_event | binlog_event |
	binlog_event | binlog_event | binlog_event | binlog_event | binlog_event | ddl ;

binlog_event:
	delete_rows_event |
	write_rows_event |
	update_rows_event |
	xid_event |
	query_event |
	intvar_event |
	rand_event |
	user_var_event |
	rotate_event ;

rotate_event:
	FLUSH LOGS ;
	
query_event:
	dml ; dml ; dml ; dml ; 

intvar_event:
	intvar_event_pk | intvar_event_last_insert_id ;

intvar_event_pk:
	INSERT INTO _table ( `pk` ) VALUES ( NULL ) ; 

intvar_event_last_insert_id:
	INSERT INTO _table ( _field ) VALUES ( LAST_INSERT_ID() ) ; 

rand_event:
	rand_event_dml ;

rand_event_dml:
	INSERT INTO _table ( _field ) VALUES ( RAND () ) |
	UPDATE _table SET _field = RAND() where ORDER BY RAND () limit |
	DELETE FROM _table WHERE _field < RAND() limit ;

user_var_event:
	SET @a = value ; user_var_dml ; 

user_var_dml:
	INSERT INTO _table ( _field ) VALUES ( @a ) |
	UPDATE _table SET _field = @a ORDER BY _field LIMIT _digit |
	DELETE FROM _table WHERE _field < @a LIMIT 1 ;

xid_event:
	START TRANSACTION | COMMIT | ROLLBACK |
	SAVEPOINT A | ROLLBACK TO SAVEPOINT A | RELEASE SAVEPOINT A |
	implicit_commit ;

implicit_commit:
	CREATE DATABASE ic ; CREATE TABLE ic . _letter SELECT * FROM _table LIMIT _digit ; DROP DATABASE ic |
	CREATE USER _letter | DROP USER _letter | RENAME USER _letter TO _letter |
	SET AUTOCOMMIT = ON | SET AUTOCOMMIT = OFF |
	CREATE TABLE IF NOT EXISTS _letter ENGINE = engine SELECT * FROM _table LIMIT _digit |
	RENAME TABLE _letter TO _letter |
	TRUNCATE TABLE _letter |
	DROP TABLE IF EXISTS _letter |
	LOCK TABLE _table WRITE ; UNLOCK TABLES |
	SELECT * FROM _table LIMIT _digit INTO OUTFILE _tmpnam ; LOAD DATA INFILE _tmpnam REPLACE INTO TABLE _table ;

begin_load_query_event:
	load_data_infile ;

execute_load_query_event:
	load_data_infile ;

load_data_infile:
	SELECT * FROM _table ORDER BY _field LIMIT _digit INTO OUTFILE _tmpnam ; LOAD DATA INFILE _tmpnam REPLACE INTO TABLE _table ;

write_rows_event:
	insert ;

update_rows_event:
	update ; 

delete_rows_event:
	delete ;

binlog_format_statement:
	SET @binlog_format_saved = @@binlog_format ; SET BINLOG_FORMAT = 'STATEMENT' ;

binlog_format_row:
	SET @binlog_format_saved = @@binlog_format ; SET BINLOG_FORMAT = 'ROW' ;

binlog_format_restore:
	SET BINLOG_FORMAT = @binlog_format_saved ;

dml:
	insert | update | delete ;

insert:
	INSERT INTO _table ( _field ) VALUES ( value ) ;

update:
	UPDATE _table SET _field = value where order_by limit ;

delete:
	DELETE FROM _table where LIMIT 1 ;

ddl:
	CREATE TRIGGER _letter trigger_time trigger_event ON _table FOR EACH ROW BEGIN procedure_body ; END |
	CREATE EVENT IF NOT EXISTS _letter ON SCHEDULE EVERY _digit SECOND ON COMPLETION PRESERVE DO BEGIN procedure_body ; END ;
	CREATE PROCEDURE _letter () BEGIN procedure_body ; END ;

trigger_time:
        BEFORE | AFTER ;

trigger_event:
        INSERT | UPDATE ;

procedure_body:
	binlog_event ; binlog_event ; binlog_event ; CALL _letter () ;

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
