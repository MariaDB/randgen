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
    {$rand_xid= "'xid".abs($$)."'"; '' } complete_xa
  | {$rand_xid= "'xid".abs($$)."'"; '' } no_commit_xa
;

complete_xa:
  xa_2phase | xa_1phase | xa_rollback_idle | xa_rollback_prepared
;

no_commit_xa:
  xa_2phase_upto_prepare | xa_1phase_upto_end
; 

xa_2phase:
    XA START { $rand_xid }
  ; normal_query_list
  ; XA END { $rand_xid }
  ; XA PREPARE { $rand_xid }
  ; XA COMMIT { $rand_xid }
;

xa_1phase:
    XA START { $rand_xid }
  ; normal_query_list
  ; XA END { $rand_xid }
  ; XA COMMIT { $rand_xid } ONE PHASE
;

xa_rollback_idle:
    XA START { $rand_xid }
  ; normal_query_list
  ; XA END { $rand_xid }
  ; XA ROLLBACK { $rand_xid }
;

xa_rollback_prepared:
    XA START { $rand_xid }
  ; normal_query_list
  ; XA END { $rand_xid }
  ; XA PREPARE { $rand_xid }
  ; XA ROLLBACK { $rand_xid }
;

xa_2phase_upto_prepare:
    XA START { $rand_xid }
  ; normal_query_list
  ; XA END { $rand_xid }
  ; XA PREPARE { $rand_xid }
;

xa_1phase_upto_end:
     XA START { $rand_xid }
  ; normal_query_list
  ; XA END { $rand_xid }
;

normal_query_list:
  normal_query |
  normal_query ; normal_query_list
;

normal_query:
  selects | inserts | updates | deletes ;

inserts:
  insert1 | insert2 | insert3 | insert4 ;

insert1:
INSERT INTO _table
(col_int_unsigned_unique,
col_int_unsigned_not_null_unique,
col_char_255_utf8_unique,
col_char_255_utf8_not_null,
col_int_unsigned_key,
col_int_unsigned_not_null_key,
col_char_255_utf8,
col_int_unsigned_unique_default_null,
col_char_255_utf8_key_default_null,
col_int_unsigned,
col_char_255_utf8_not_null_key,
col_char_255_utf8_default_null,
col_char_255_utf8_key,
col_int_unsigned_not_null,
col_char_255_utf8_not_null_unique,
col_int_unsigned_default_null,
col_char_255_utf8_unique_default_null,
col_int_unsigned_key_default_null) 
VALUES
(_int_unsigned,
_int_unsigned,
_char(255),
_char(255),
_int_unsigned,
_int_unsigned,
_char(255),
_int_unsigned,
_char(255),
_int_unsigned,
_char(255),
_char(255),
_char(255),
_int_unsigned,
_char(255),
_int_unsigned,
_char(255),
_int_unsigned);

insert2:
INSERT INTO _table
(col_int_unsigned_unique,
col_int_unsigned_not_null_unique,
col_char_255_utf8_unique,
col_char_255_utf8_not_null,
col_int_unsigned_key,
col_int_unsigned_not_null_key,
col_char_255_utf8,
col_int_unsigned_unique_default_null,
col_char_255_utf8_key_default_null,
col_int_unsigned,
col_char_255_utf8_not_null_key,
col_char_255_utf8_default_null,
col_char_255_utf8_key,
col_int_unsigned_not_null,
col_char_255_utf8_not_null_unique,
col_int_unsigned_default_null,
col_char_255_utf8_unique_default_null,
col_int_unsigned_key_default_null) 
VALUES
(NULL,
_int_unsigned,
_char(255),
_char(1),
NULL,
_digit,
NULL,
_int_unsigned,
_char(1),
NULL,
_char(1),
_char(1),
NULL,
_digit,
_char(255),
_digit,
_char(255),
_digit);


insert3:
INSERT INTO _table
(col_int_unsigned_unique,
col_int_unsigned_not_null_unique,
col_char_255_utf8_unique,
col_char_255_utf8_not_null,
col_int_unsigned_key,
col_int_unsigned_not_null_key,
col_char_255_utf8,
col_int_unsigned,
col_char_255_utf8_not_null_key,
col_char_255_utf8_key,
col_int_unsigned_not_null,
col_char_255_utf8_not_null_unique) 
VALUES
(_int_unsigned,
_int_unsigned,
_char(255),
_char(255),
_int_unsigned,
_int_unsigned,
_char(255),
_int_unsigned,
_char(255),
_char(255),
_int_unsigned,
_char(255));

insert4:
INSERT INTO _table
(col_int_unsigned_unique,
col_int_unsigned_not_null_unique,
col_char_255_utf8_unique,
col_char_255_utf8_not_null,
col_int_unsigned_key,
col_int_unsigned_not_null_key,
col_char_255_utf8,
col_int_unsigned,
col_char_255_utf8_not_null_key,
col_char_255_utf8_key,
col_int_unsigned_not_null,
col_char_255_utf8_not_null_unique) 
VALUES
(NULL,
_int_unsigned,
NULL,
_char(255),
NULL,
_int_unsigned,
NULL,
NULL,
_char(1),
NULL,
_digit,
_char(255));

selects:
    point_select_key_not_null | simple_range_key_not_null | sum_range_key_not_null | order_range_key_not_null | distinct_range_key_not_null
  | point_select_unique_key_not_null | simple_range_unique_key_not_null | sum_range_unique_key_not_null | order_range_unique_key_not_null | distinct_range_unique_key_not_null
  | point_select_unique_key_null | simple_range_unique_key_null | sum_range_unique_key_null | order_range_unique_key_null | distinct_range_unique_key_null
  | point_select_no_key_null | simple_range_no_key_null | sum_range_no_key_null | order_range_no_key_null | distinct_range_no_key_null
  | point_select_no_key_not_null | simple_range_no_key_not_null | sum_range_no_key_not_null | order_range_no_key_not_null | distinct_range_no_key_not_null  
; 
  
point_select_key_not_null:
    SELECT _field FROM _table WHERE col_int_unsigned_not_null_key = _smallint_unsigned ; SELECT _field FROM _table WHERE col_int_unsigned_not_null_key IS NULL ;

simple_range_key_not_null:
    SELECT _field FROM _table WHERE col_int_unsigned_not_null_key BETWEEN _digit AND _smallint_unsigned ;
  
sum_range_key_not_null:
    SELECT SUM(col_int_unsigned_not_null_key) FROM _table WHERE col_int_unsigned_not_null_key BETWEEN _digit AND _smallint_unsigned ;

order_range_key_not_null:
    SELECT _field FROM _table WHERE col_int_unsigned_not_null_key BETWEEN _digit AND _smallint_unsigned ORDER BY _field ;
   
distinct_range_key_not_null:
    SELECT DISTINCT _field FROM _table WHERE col_int_unsigned_not_null_key BETWEEN _smallint_unsigned AND _smallint_unsigned ORDER BY _field ;

point_select_key_null:
    SELECT _field FROM _table WHERE col_int_unsigned_key = _smallint_unsigned ; SELECT _field FROM _table WHERE col_int_unsigned_key IS NULL ;

simple_range_key_null:
    SELECT _field FROM _table WHERE col_int_unsigned_key BETWEEN _digit AND _smallint_unsigned ;
  
sum_range_key_null:
    SELECT SUM(col_int_unsigned_key) FROM _table WHERE col_int_unsigned_key BETWEEN _digit AND _smallint_unsigned ;

order_range_key_null:
    SELECT _field FROM _table WHERE col_int_unsigned_key BETWEEN _digit AND _smallint_unsigned ORDER BY _field ;
   
distinct_range_key_null:
    SELECT DISTINCT _field FROM _table WHERE col_int_unsigned_key BETWEEN _smallint_unsigned AND _smallint_unsigned ORDER BY _field ;

point_select_unique_key_not_null:
    SELECT _field FROM _table WHERE col_int_unsigned_not_null_unique = _smallint_unsigned ; SELECT _field FROM _table WHERE col_int_unsigned_not_null_unique IS NULL ;

simple_range_unique_key_not_null:
    SELECT _field FROM _table WHERE col_int_unsigned_not_null_unique BETWEEN _digit AND _smallint_unsigned ;
  
sum_range_unique_key_not_null:
    SELECT SUM(col_int_unsigned_not_null_unique) FROM _table WHERE col_int_unsigned_not_null_unique BETWEEN _digit AND _smallint_unsigned ;

order_range_unique_key_not_null:
    SELECT _field FROM _table WHERE col_int_unsigned_not_null_unique BETWEEN _digit AND _smallint_unsigned ORDER BY _field ;
   
distinct_range_unique_key_not_null:
    SELECT DISTINCT _field FROM _table WHERE col_int_unsigned_not_null_unique BETWEEN _smallint_unsigned AND _smallint_unsigned ORDER BY _field ;

point_select_unique_key_null:
    SELECT _field FROM _table WHERE col_int_unsigned_unique = _smallint_unsigned ; SELECT _field FROM _table WHERE col_int_unsigned_unique IS NULL ;

simple_range_unique_key_null:
    SELECT _field FROM _table WHERE col_int_unsigned_unique BETWEEN _digit AND _smallint_unsigned ;
  
sum_range_unique_key_null:
    SELECT SUM(col_int_unsigned_unique) FROM _table WHERE col_int_unsigned_unique BETWEEN _digit AND _smallint_unsigned ;

order_range_unique_key_null:
    SELECT _field FROM _table WHERE col_int_unsigned_unique BETWEEN _digit AND _smallint_unsigned ORDER BY _field ;
   
distinct_range_unique_key_null:
    SELECT DISTINCT _field FROM _table WHERE col_int_unsigned_unique BETWEEN _smallint_unsigned AND _smallint_unsigned ORDER BY _field ;

point_select_no_key_null:
    SELECT _field FROM _table WHERE col_int_unsigned = _smallint_unsigned ; SELECT _field FROM _table WHERE col_int_unsigned IS NULL ;

simple_range_no_key_null:
    SELECT _field FROM _table WHERE col_int_unsigned BETWEEN _digit AND _smallint_unsigned ;
  
sum_range_no_key_null:
    SELECT SUM(col_int_unsigned) FROM _table WHERE col_int_unsigned BETWEEN _digit AND _smallint_unsigned ;

order_range_no_key_null:
    SELECT _field FROM _table WHERE col_int_unsigned BETWEEN _digit AND _smallint_unsigned ORDER BY _field ;
   
distinct_range_no_key_null:
    SELECT DISTINCT _field FROM _table WHERE col_int_unsigned BETWEEN _smallint_unsigned AND _smallint_unsigned ORDER BY _field ;

point_select_no_key_not_null:
    SELECT _field FROM _table WHERE col_int_unsigned_not_null = _smallint_unsigned ; SELECT _field FROM _table WHERE col_int_unsigned_not_null IS NULL ;

simple_range_no_key_not_null:
    SELECT _field FROM _table WHERE col_int_unsigned_not_null BETWEEN _digit AND _smallint_unsigned ;
  
sum_range_no_key_not_null:
    SELECT SUM(col_int_unsigned_not_null) FROM _table WHERE col_int_unsigned_not_null BETWEEN _digit AND _smallint_unsigned ;

order_range_no_key_not_null:
    SELECT _field FROM _table WHERE col_int_unsigned_not_null BETWEEN _digit AND _smallint_unsigned ORDER BY _field ;
   
distinct_range_no_key_not_null:
    SELECT DISTINCT _field FROM _table WHERE col_int_unsigned_not_null BETWEEN _smallint_unsigned AND _smallint_unsigned ORDER BY _field ;

deletes:
    delete1 | delete2 | delete3 | delete4 | delete5 | delete6 ;

delete1:
    DELETE FROM _table WHERE col_int_unsigned = _tinyint_unsigned ; 
delete2:
    DELETE FROM _table WHERE col_int_unsigned_not_null = _smallint_unsigned ;
delete3:
    DELETE FROM _table WHERE col_int_unsigned_key = _tinyint_unsigned ;
delete4:
    DELETE FROM _table WHERE col_int_unsigned_not_null_key = _smallint_unsigned ;
delete5:
    DELETE FROM _table WHERE col_int_unsigned_unique = _tinyint_unsigned ;
delete6:
    DELETE FROM _table WHERE col_int_unsigned_not_null_unique = _smallint_unsigned ;


updates:
    update1 | update2 | update3 | update4 | update5 | update6 ;

update1:
    UPDATE _table SET col_int_unsigned = col_int_unsigned + 1  WHERE (col_int_unsigned % 9) = 0; 
update2:
    UPDATE _table SET col_int_unsigned_not_null = col_int_unsigned_not_null + 1 WHERE (col_int_unsigned % 9) = 0 ;
update3:
    UPDATE _table SET col_int_unsigned_key = col_int_unsigned_key + 1 WHERE (col_int_unsigned % 9) = 0 ;
update4:
    UPDATE _table SET col_int_unsigned_not_null_key = col_int_unsigned_not_null_key + 1 WHERE (col_int_unsigned % 9) = 0 ;
update5:
    UPDATE _table SET col_int_unsigned_unique = col_int_unsigned_unique + 1 WHERE (col_int_unsigned % 9) = 0 ;
update6:
    UPDATE _table SET col_int_unsigned_not_null_unique = col_int_unsigned_not_null_unique + 1 WHERE (col_int_unsigned % 9) = 0 ;
