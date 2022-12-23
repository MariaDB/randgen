# Copyright (c) 2022, MariaDB Corporation Ab.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# 51 Franklin Street, Suite 500, Boston, MA 02110-1335 USA

query:
  { _set_db('ANY') }
  SELECT /* _table[invariant] */
  window_function
  FROM _table[invariant]
;

window_function:
#### Non-aggregate functions
#  CUME_DIST()                     |
#  DENSE_RANK()                    |
#  FIRST_VALUE(expr)               |
#  LAG(expr optional_offset)       |
#  LAST_VALUE(expr_list)           |
#  LAST_VALUE(expr_list) over_expression          |
#  LEAD(expr optional_offset)      |
#  MEDIAN(expr)                    |
#  NTH_VALUE(expr optional_offset) |
#  NTILE(_tinyint_unsigned)        |
#  PERCENT_RANK()                  |
  PERCENTILE_CONT({$a= $prng->uint16(0,99); $a/$prng->uint16($a+1,100)}) WITHIN GROUP (ORDER BY expr) OVER (optional_partition_by) |
# Cannot have a truly random value due to MDEV-30292
  PERCENTILE_DISC({$a= $prng->uint16(0,99); $a/$prng->uint16($a+1,100)}) WITHIN GROUP (ORDER BY expr) OVER (optional_partition_by) |
#  RANK()                          |
#  ROW_NUMBER()                    |
#### Aggregate functions
#  AVG(__distinct(50) expr)        |
#  BIT_AND(expr)                   |
#  BIT_OR(expr)                    |
#  BIT_XOR(expr)                   |
#  COUNT(aggr_expr)                |
#  MAX(__distinct(50) expr)        |
#  MIN(__distinct(50) expr)        |
#  STD(expr)                       |
#  STDDEV(expr)                    |
#  STDDEV_POP(expr)                |
#  STDDEV_SAMP(expr)               |
#  SUM(__distinct(50) expr)        |
#  VAR_POP(expr)                   |
#  VAR_SAMP(expr)                  |
#  VARIANCE(expr)
1
;

over_expression:
  OVER (
    optional_partition_by
    optional_order_by
  )
;

aggr_expr:
  * | __distinct(50) expr_list ;

optional_offset:
  | , _tinyint_unsigned ;

optional_partition_by:
  ==FACTOR:4== |
  PARTITION BY expr_list ;

expr_list:
  expr |
  expr, expr_list ;

optional_order_by:
  ==FACTOR:4== |
  ORDER BY order_list optional_frame_clause ;

order_list:
  expr __asc_x_desc(30,30) |
  expr __asc_x_desc(30,30), order_list ;

optional_frame_clause:
  __rows_x_range frame_border_expression ;

frame_border_expression:
  frame_start | frame_between ;

frame_between:
  BETWEEN frame_start AND frame_end ;

frame_start:
    UNBOUNDED PRECEDING
  | CURRENT ROW
  | _tinyint_unsigned PRECEDING
;

frame_end:
    UNBOUNDED PRECEDING
  | UNBOUNDED FOLLOWING
  | CURRENT ROW
  | _tinyint_unsigned PRECEDING
  | _tinyint_unsigned FOLLOWING
;

# TODO: expand
expr:
  _field ;
