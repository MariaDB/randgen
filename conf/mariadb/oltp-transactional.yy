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

# Rough imitation of OLTP-read-write test (sysbench-like)

query:
    dml | dml | dml | dml | dml | dml | dml |
    START TRANSACTION | COMMIT ;

dml:
    select | 
    update |
    delete |
    insert
;

insert:
    INSERT IGNORE INTO _table ( _field_pk ) VALUES ( NULL ) |
    INSERT IGNORE INTO _table ( _field_int ) VALUES ( _smallint_unsigned ) |
    INSERT IGNORE INTO _table ( _field_char ) VALUES ( _string ) |
    INSERT IGNORE INTO _table ( _field_pk, _field_int)  VALUES ( NULL, _int ) |
    INSERT IGNORE INTO _table ( _field_pk, _field_char ) VALUES ( NULL, _string ) 
;

update:
    index_update |
    non_index_update
;

delete:
    DELETE FROM _table WHERE _field_pk = _smallint_unsigned ;

index_update:
    UPDATE IGNORE _table SET _field_int_indexed = _field_int_indexed + 1 WHERE _field_pk = _smallint_unsigned ;

# It relies on char fields being unindexed. 
# If char fields happen to be indexed in the table spec, then this update can be indexed as well. No big harm though. 
non_index_update:
    UPDATE _table SET _field_char = _string WHERE _field_pk = _smallint_unsigned ;

select:
    point_select |
    simple_range |
    sum_range |
    order_range |
    distinct_range 
;

point_select:
    SELECT _field FROM _table WHERE _field_pk = _smallint_unsigned ;

simple_range:
    SELECT _field FROM _table WHERE _field_pk BETWEEN _smallint_unsigned AND _smallint_unsigned ;

sum_range:
    SELECT SUM(_field) FROM _table WHERE _field_pk BETWEEN _smallint_unsigned AND _smallint_unsigned ;

order_range:
    SELECT _field FROM _table WHERE _field_pk BETWEEN _smallint_unsigned AND _smallint_unsigned ORDER BY _field ;

distinct_range:
    SELECT DISTINCT _field FROM _table WHERE _field_pk BETWEEN _smallint_unsigned AND _smallint_unsigned ORDER BY _field ;

