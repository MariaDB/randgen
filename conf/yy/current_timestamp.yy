# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Use is subject to license terms.
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

query:
  { _set_db('NON-SYSTEM') } current_ts_query ;

current_ts_query:
  select | insert | insert | insert | delete | replace | update | transaction | 
  wl_query | wl_query | wl_query | wl_query | wl_query | wl_query | wl_query |
  wl_query | wl_query | wl_query | wl_query | wl_query | wl_query | wl_query ;
  
wl_query:
  alter | proc_func | views | outfile_infile | insert_on_dup | update_multi | create_table ;

transaction:
  | | START TRANSACTION | COMMIT | ROLLBACK | SAVEPOINT A | ROLLBACK TO SAVEPOINT A | FLUSH TABLES ;

select:
  SELECT /* _table[invariant] */ select_item FROM _table[invariant] where order_by limit ;
  
select_item:
  _field | _field null | _field op _field | _field sign _field | select_item, _field ;
  
where:
  | WHERE _field sign value ;

order_by:
  | ORDER BY _field ;

limit:
  | LIMIT _digit ;
  
null:
  IS NULL | IS NOT NULL ;

op:
  + | / | DIV ;   # - | * | removed due to BIGINT bug (ERROR 1690 (22003): BIGINT UNSIGNED value is out of range)
  
sign:
  < | > | = | >= | <= | <> | != ;

insert:
  INSERT __ignore(80) INTO _table ( _field , _field , _field ) VALUES ( value , value , value ) |
  INSERT __ignore(80) INTO _table ( _field_no_pk , _field_no_pk , _field_no_pk ) VALUES ( value , value , value ) ;

insert_delayed:
  INSERT priority_insert __ignore(80) INTO _table ( _field , _field , _field ) VALUES ( value , value , value ) |
  INSERT priority_insert __ignore(80) INTO _table ( _field_no_pk , _field_no_pk , _field_no_pk ) VALUES ( value , value , value ) ;
  
insert_on_dup:
  INSERT priority_insert __ignore(80) INTO _table ( _field ) VALUES ( value ) ON DUPLICATE KEY UPDATE _field_no_pk = value |
  INSERT priority_insert __ignore(80) INTO _table ( _field ) VALUES ( value ) ON DUPLICATE KEY UPDATE _field = value ;
  
priority_insert:
  | | | | | | | LOW_PRIORITY  | DELAYED | HIGH_PRIORITY ;

update:
  UPDATE priority_update __ignore(80) _table SET _field_no_pk = value where order_by limit ;
  
update_multi:
  UPDATE priority_update __ignore(80) _table t1, _table t2 SET t1._field_no_pk = value WHERE t1._field sign value ;

priority_update:
  | LOW_PRIORITY ;

delete:
  | | | | | | | | DELETE FROM _table where order_by limit ;
  
replace:
  REPLACE INTO _table ( _field_no_pk ) VALUES ( value ) ;
  
create_table:
  DROP TABLE IF EXISTS _letter[invariant] ;; DROP VIEW IF EXISTS _letter[invariant] ;; CREATE temp TABLE _letter[invariant] LIKE _table[invariant] ;; INSERT INTO _letter[invariant] SELECT * FROM _table[invariant] |
  DROP TABLE IF EXISTS _letter[invariant] ;; DROP VIEW IF EXISTS _letter[invariant] ;; CREATE temp TABLE _letter[invariant] SELECT * FROM _table ;
  
temp:
  | | | | | | TEMPORARY ;

alter:
  ALTER __ignore(50) TABLE _table MODIFY _field DATETIME optional_length NULL AFTER _field |
  ALTER __ignore(50) TABLE _table MODIFY _field DATETIME optional_length NOT NULL FIRST |
  ALTER __ignore(50) TABLE _table MODIFY _field DATETIME optional_length NULL DEFAULT 0 AFTER _field |
  ALTER __ignore(50) TABLE _table MODIFY _field DATETIME optional_length NOT NULL DEFAULT 0 FIRST |
  ALTER __ignore(50) TABLE _table MODIFY _field DATETIME optional_length NULL DEFAULT CURRENT_TIMESTAMP optional_length AFTER _field |
  ALTER __ignore(50) TABLE _table MODIFY _field DATETIME optional_length NOT NULL DEFAULT CURRENT_TIMESTAMP optional_length FIRST |
  ALTER __ignore(50) TABLE _table MODIFY _field DATETIME optional_length NOT NULL DEFAULT CURRENT_TIMESTAMP optional_length ON UPDATE CURRENT_TIMESTAMP optional_length AFTER _field |
  ALTER __ignore(50) TABLE _table MODIFY _field DATETIME optional_length NULL DEFAULT CURRENT_TIMESTAMP optional_length ON UPDATE CURRENT_TIMESTAMP optional_length FIRST |
  ALTER __ignore(50) TABLE _table MODIFY _field DATETIME optional_length NULL ON UPDATE CURRENT_TIMESTAMP optional_length AFTER _field |
  ALTER __ignore(50) TABLE _table MODIFY _field DATETIME optional_length NOT NULL ON UPDATE CURRENT_TIMESTAMP optional_length FIRST |
  ALTER __ignore(50) TABLE _table MODIFY _field DATETIME optional_length NOT NULL DEFAULT '2000-01-01 00:00:00' AFTER _field |
  ALTER __ignore(50) TABLE _table MODIFY _field DATETIME optional_length NULL DEFAULT '2000-01-01 00:00:00' FIRST |
  ALTER __ignore(50) TABLE _table MODIFY _field DATETIME optional_length NOT NULL DEFAULT '2000-01-01 00:00:00' ON UPDATE CURRENT_TIMESTAMP optional_length AFTER _field |
  ALTER __ignore(50) TABLE _table MODIFY _field DATETIME optional_length NULL DEFAULT '2000-01-01 00:00:00' ON UPDATE CURRENT_TIMESTAMP optional_length FIRST |
  ALTER __ignore(50) TABLE _table MODIFY _field TIMESTAMP optional_length AFTER _field |
  ALTER __ignore(50) TABLE _table MODIFY _field TIMESTAMP optional_length NULL FIRST |
  ALTER __ignore(50) TABLE _table MODIFY _field TIMESTAMP optional_length NULL DEFAULT 0 AFTER _field |
  ALTER __ignore(50) TABLE _table MODIFY _field TIMESTAMP optional_length NOT NULL DEFAULT 0 FIRST |
  ALTER __ignore(50) TABLE _table MODIFY _field TIMESTAMP optional_length NULL DEFAULT CURRENT_TIMESTAMP optional_length AFTER _field |
  ALTER __ignore(50) TABLE _table MODIFY _field TIMESTAMP optional_length NOT NULL DEFAULT CURRENT_TIMESTAMP optional_length FIRST |
  ALTER __ignore(50) TABLE _table MODIFY _field TIMESTAMP optional_length NOT NULL DEFAULT CURRENT_TIMESTAMP optional_length ON UPDATE CURRENT_TIMESTAMP optional_length AFTER _field |
  ALTER __ignore(50) TABLE _table MODIFY _field TIMESTAMP optional_length NULL DEFAULT CURRENT_TIMESTAMP optional_length ON UPDATE CURRENT_TIMESTAMP optional_length FIRST |
  ALTER __ignore(50) TABLE _table MODIFY _field TIMESTAMP optional_length NULL ON UPDATE CURRENT_TIMESTAMP optional_length AFTER _field |
  ALTER __ignore(50) TABLE _table MODIFY _field TIMESTAMP optional_length NOT NULL ON UPDATE CURRENT_TIMESTAMP optional_length FIRST |
  ALTER __ignore(50) TABLE _table MODIFY _field TIMESTAMP optional_length NOT NULL DEFAULT '2000-01-01 00:00:00' AFTER _field |
  ALTER __ignore(50) TABLE _table MODIFY _field TIMESTAMP optional_length NULL DEFAULT '2000-01-01 00:00:00' FIRST |
  ALTER __ignore(50) TABLE _table MODIFY _field TIMESTAMP optional_length NOT NULL DEFAULT '2000-01-01 00:00:00' ON UPDATE CURRENT_TIMESTAMP optional_length AFTER _field |
  ALTER __ignore(50) TABLE _table MODIFY _field TIMESTAMP optional_length NULL DEFAULT '2000-01-01 00:00:00' ON UPDATE CURRENT_TIMESTAMP optional_length FIRST ;

proc_func:
  DROP PROCEDURE IF EXISTS _letter[invariant] ;; CREATE PROCEDURE _letter[invariant] ( proc_param ) BEGIN SELECT /* _table[invariant] */ COUNT( _field ) INTO @a FROM _table[invariant] ; END ;; CALL _letter[invariant](@a) |
  DROP FUNCTION IF EXISTS _letter[invariant] ;; CREATE FUNCTION _letter[invariant] ( func_param ) RETURNS time_field DETERMINISTIC READS SQL DATA BEGIN DECLARE out1 time_field ; SELECT _table[invariant]._field INTO out1 FROM _table[invariant] ; RETURN out1 ; END
;
    
proc_param:
  IN _letter time_field | OUT _letter time_field | IN _letter time_field , proc_param | OUT _letter time_field , proc_param ;
  
func_param:
  _letter time_field | _letter time_field , func_param ;
  
time_field:
  DATETIME optional_length | DATETIME optional_length | TIMESTAMP optional_length | TIMESTAMP optional_length | DATE | TIME optional_length ;
  
views:
  DROP TABLE IF EXISTS _letter[invariant] ;; DROP VIEW IF EXISTS _letter[invariant] ;; CREATE VIEW _letter[invariant] AS SELECT * FROM _table ;; INSERT INTO _letter[invariant] ( _field ) VALUES ( value ) ;
  
outfile_infile:
  SELECT * INTO OUTFILE _tmpnam FROM _table[invariant] ;; TRUNCATE _table[invariant] ;; LOAD DATA INFILE _tmpnam INTO TABLE _table[invariant] ;

value:
  _date(6) | _time(6) | _datetime(6) | _datetime(6) | _datetime(6) | _timestamp(6) | _timestamp(6) | _timestamp(6) | _year | NULL | NULL | NULL |
  _date    | _time    | _datetime    | _datetime    | _datetime    | _timestamp    | _timestamp    | _timestamp    | NULL | NULL | NULL |
  _digit | 0 | 1 | -1 | _data | _bigint_unsigned | _bigint | _mediumint | _english | _letter | _char(64) | _varchar(8) ;

optional_length:
  | ({$prng->uint16(0,6)}) ;
