# Copyright (C) 2016, 2022, MariaDB Corporation.
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
# Rough imitation of OLTP-readonly test (sysbench-like)
########################################################################

query:
    { my @dbs=(); push @dbs, 'oltp_db' if $executors->[0]->databaseExists('oltp_db')
                ; push @dbs, 'oltp_aria_db' if $executors->[0]->databaseExists('oltp_aria_db')
                ; push @dbs, 'NON-SYSTEM'
                ; _set_db($prng->arrayElement(\@dbs))
    } SELECT /* _table[invariant] */ select_body ;

select_body:
    point_select |
    simple_range |
    sum_range |
    order_range |
    distinct_range
;

point_select:
    _field FROM _table[invariant] WHERE _field_pk = _smallint_unsigned ;

simple_range:
    _field FROM _table[invariant] WHERE _field_pk BETWEEN _smallint_unsigned AND _smallint_unsigned ;

sum_range:
    SUM(_field) FROM _table[invariant] WHERE _field_pk BETWEEN _smallint_unsigned AND _smallint_unsigned ;

order_range:
    _field FROM _table[invariant] WHERE _field_pk BETWEEN _smallint_unsigned AND _smallint_unsigned ORDER BY _field ;

distinct_range:
    DISTINCT _field FROM _table[invariant] WHERE _field_pk BETWEEN _smallint_unsigned AND _smallint_unsigned ORDER BY _field ;
