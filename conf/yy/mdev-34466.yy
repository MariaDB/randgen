#  Copyright (c) 2018, 2022 MariaDB Corporation
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
# While the grammar can be used alone, it mainly implies that there are
# queries from other grammars interleaved with its XA actions,
# otherwise it just produces empty XA transactions
########################################################################

#features XA transactions

query_init:
  # Need debug build. 
  # It removes the restrictions for master, i.e. unmodified records are unlocked for master also, 
  # normally it is done only for slave workers. It would increase the probability to catch some bug in the code
  SET GLOBAL innodb_enable_xap_unlock_unmodified_for_primary_debug = 1
;

query:
  {$rand_xid= "'xid".abs($$)."'"; '' } complete_xa
                                     | normal_trans 
;

thread1_init:
      USE oltp_db
  ;;  DROP TABLE IF EXISTS t1
  ;;  CREATE TABLE t1 (a int, b int, c int, INDEX i1(a), INDEX i2(b)) 
  ;;  INSERT INTO t1 VALUES (1,1,0), (1,2,0), (2,1,0), (2,2,0)
;

complete_xa:
   custom_sql | xa_2phase | xa_1phase | xa_rollback_idle | xa_rollback_prepared
;

custom_sql:
      custom_sql_1
  ;;  custom_sql_2
;

custom_sql_1:
      
      USE oltp_db
  ;;  XA START { $rand_xid }
  ;;  DELETE FROM t1
  ;;  INSERT INTO t1 VALUES (1,1,0), (1,2,0), (2,1,0), (2,2,0)
  ;;  UPDATE t1 FORCE INDEX (i2) SET c=c+1 WHERE a=1 AND b=1
  ;;  XA END { $rand_xid }
  ;;  XA PREPARE { $rand_xid }
  ;;  XA COMMIT { $rand_xid }
;

custom_sql_2:
      USE oltp_db
  ;;  SELECT * FROM t1 FORCE INDEX (i1) WHERE a=2 AND b=1 FOR UPDATE
;

xa_2phase:
     XA START { $rand_xid }
  ;; normal_query_list
  ;; XA END { $rand_xid }
  ;; XA PREPARE { $rand_xid }
  ;; XA COMMIT { $rand_xid }
;

xa_1phase:
     XA START { $rand_xid }
  ;; normal_query_list
  ;; XA END { $rand_xid }
  ;; XA COMMIT { $rand_xid } ONE PHASE
;

xa_rollback_idle:
     XA START { $rand_xid }
  ;; normal_query_list
  ;; XA END { $rand_xid }
  ;; XA ROLLBACK { $rand_xid }
;

xa_rollback_prepared:
     XA START { $rand_xid }
  ;; normal_query_list
  ;; XA END { $rand_xid }
  ;; XA PREPARE { $rand_xid }
  ;; XA ROLLBACK { $rand_xid }
;

normal_trans:
  normal_trans_commit | normal_trans_rollback
;

normal_trans_commit:
      START TRANSACTION
  ;;  normal_query_list
  ;;  COMMIT
;

normal_trans_rollback:
      START TRANSACTION
  ;;  normal_query_list
  ;;  ROLLBACK
;

normal_query_list:
  normal_query | 
  normal_query ;; normal_query_list
;

normal_query:
  select | insert | insert | update | delete ;

select:
    point_select | simple_range | sum_range | order_range | distinct_range
;

point_select:
    SELECT k FROM _table WHERE _field_pk = _smallint_unsigned ;

simple_range:
    SELECT k FROM _table WHERE _field_pk BETWEEN _smallint_unsigned AND _smallint_unsigned ;

sum_range:
    SELECT SUM(k) FROM _table WHERE _field_pk BETWEEN _smallint_unsigned AND _smallint_unsigned ;

order_range:
    SELECT k FROM _table WHERE _field_pk BETWEEN _smallint_unsigned AND _smallint_unsigned ORDER BY _field ;

distinct_range:
    SELECT DISTINCT k FROM _table WHERE _field_pk BETWEEN _smallint_unsigned AND _smallint_unsigned ORDER BY _field ;

insert:
  INSERT IGNORE INTO _table ( k, c, pad)  VALUES ( _int, _string, _string )
;

update:
  index_update | non_index_update ;

delete:
  DELETE FROM _table WHERE _field_pk = _smallint_unsigned ;

index_update:
  UPDATE IGNORE _table SET _field_int_indexed = _field_int_indexed + 1 WHERE _field_pk = _smallint_unsigned ;

# It relies on char fields being unindexed.
# If char fields happen to be indexed in the table spec, then this update can be indexed as well. No big harm though.
non_index_update:
  UPDATE _table SET _field_char = _string WHERE _field_pk = _smallint_unsigned ;
