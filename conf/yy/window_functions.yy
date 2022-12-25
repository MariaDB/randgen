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
  window_function_list
  FROM _table[invariant]
;

window_function_list:
  window_function |
  window_function, window_function_list ;

window_function:
  non_aggregate_function |
  aggregate_function over_expression_optional
;

non_aggregate_function:
  function_requiring_order_by over_expression_mandatory_order_by |
  function_with_optional_over over_expression_optional |
  function_without_order_by OVER (optional_partition_by) |
  function_without_frame OVER (optional_partition_by ORDER BY order_list) |
  function_percentile WITHIN GROUP (ORDER BY expr) OVER (optional_partition_by)
;

function_requiring_order_by:
  CUME_DIST()                |
  DENSE_RANK()               |
  LAG(expr optional_offset)  |
  LEAD(expr optional_offset) |
  NTH_VALUE(expr offset)
;

function_with_optional_over:
  FIRST_VALUE(_field_int) |
  LAST_VALUE(_field_int)
;

function_without_order_by:
  MEDIAN(_field_int) ;

function_without_frame:
  NTILE(ntile_arg) |
  PERCENT_RANK()   |
  RANK()           |
  ROW_NUMBER()
;

function_percentile:
  PERCENTILE_CONT({$a= $prng->uint16(0,99); $a/$prng->uint16($a+1,100)}) |
# Cannot have a truly random value (e.g. > 1) due to MDEV-30292
  PERCENTILE_DISC({$a= $prng->uint16(0,99); $a/$prng->uint16($a+1,100)})
;

aggregate_function:
  AVG(expr)                |
  BIT_AND(expr)            |
  BIT_OR(expr)             |
  BIT_XOR(expr)            |
  COUNT(expr)              |
  MAX(__distinct(50) expr) |
  MIN(__distinct(50) expr) |
  STD(expr)                |
  STDDEV(expr)             |
  STDDEV_POP(expr)         |
  STDDEV_SAMP(expr)        |
  SUM(expr)                |
  VAR_POP(expr)            |
  VAR_SAMP(expr)           |
  VARIANCE(expr)
;

ntile_arg:
  ==FACTOR:50== { $prng->uint16(1,10) } |
  ==FACTOR:10== { $prng->uint16(1,1000) } |
  _field_int
;

over_expression_mandatory_order_by:
  OVER (
    optional_partition_by
    order_by
  )
;

over_expression_optional:
  OVER (
    optional_partition_by
    optional_order_by
  )
;

aggr_expr:
  * | __distinct(50) expr_list ;

optional_offset:
  | offset ;

offset:
  , _tinyint_unsigned | , _field ;

optional_partition_by:
  ==FACTOR:4== |
  PARTITION BY expr_list ;

expr_list:
  expr |
  expr, expr_list ;

optional_order_by:
  ==FACTOR:4== |
  order_by ;

order_by:
  ORDER BY order_list |
  ORDER BY order_element __rows_x_range frame_between |
  ORDER BY order_list ROWS frame_start |
  ORDER BY order_element RANGE CURRENT ROW
;

order_list:
  order_element |
  order_element, order_list ;

order_element:
  expr __asc_x_desc(30,30) ;

optional_frame_clause:
  __rows_x_range frame_border_expression ;

frame_border_expression:
  frame_start | frame_between ;

frame_between:
  BETWEEN frame_start AND frame_end |
  BETWEEN UNBOUNDED PRECEDING AND _tinyint_unsigned PRECEDING |
  BETWEEN _tinyint_unsigned PRECEDING AND _tinyint_unsigned PRECEDING |
  BETWEEN _tinyint_unsigned FOLLOWING AND UNBOUNDED FOLLOWING |
  BETWEEN _tinyint_unsigned FOLLOWING AND _tinyint_unsigned FOLLOWING
;

frame_start:
    UNBOUNDED PRECEDING
  | _tinyint_unsigned PRECEDING
  | CURRENT ROW
;

frame_end:
    CURRENT ROW
  | _tinyint_unsigned FOLLOWING
  | UNBOUNDED FOLLOWING
;

# TODO: expand
expr:
  _field ;
