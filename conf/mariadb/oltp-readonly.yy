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

# Rough imitation of OLTP-readonly test (sysbench-like)

query:
    select 
;

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

