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

# Rough imitation of OLTP-write test (sysbench-like)

query:
    { my @dbs=(); push @dbs, 'oltp_db' if $executors->[0]->databaseExists('oltp_db')
                ; push @dbs, 'oltp_aria_db' if $executors->[0]->databaseExists('oltp_aria_db')
                ; push @dbs, 'NON-SYSTEM'
                ; _set_db($prng->arrayElement(\@dbs))
    } /* _table[invariant] */ oltp_query ;

oltp_query:
    ==FACTOR:10== dml |
    START TRANSACTION |
    COMMIT
;

dml:
    update | delete | insert ;

insert:
    INSERT IGNORE INTO _table ( _field_pk ) VALUES ( NULL ) |
    INSERT IGNORE INTO _table ( _field_int ) VALUES ( _smallint_unsigned ) |
    INSERT IGNORE INTO _table ( _field_char ) VALUES ( _string ) |
    INSERT IGNORE INTO _table ( _field_pk, _field_int)  VALUES ( NULL, _int ) |
    INSERT IGNORE INTO _table ( _field_pk, _field_char ) VALUES ( NULL, _string ) |
    INSERT IGNORE INTO _table ( _field_pk ) VALUES ( NULL ),( NULL ),( NULL ),( NULL )
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
