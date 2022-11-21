#  Copyright (c) 2019, 2022, MariaDB
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
#
# MDEV-6111 Optimizer trace, MariaDB 10.4.3+
# https://mariadb.com/kb/en/library/optimizer-trace/
#
########################################################################

#include <conf/rr/basics.rr>


query:
  opttrace_query |
  query | query | query | query | query | query | query | query | query
;

opttrace_query:
  opttrace_set_max_mem_size |
  opttrace_enable_disable_trace |
  opttrace_is_select | opttrace_is_select | opttrace_is_select | opttrace_is_select |
  opttrace_is_select | opttrace_is_select | opttrace_is_select | opttrace_is_select
;

opttrace_enable_disable_trace:
  SET __session_x_global(60,20) optimizer_trace = opttrace_enabled_value ;

opttrace_enabled_value:
  'enabled=off' | 'enabled=on' | 'enabled=default' ;

opttrace_set_max_mem_size:
  SET __session_x_global(60,20) optimizer_trace_max_mem_size = opttrace_max_mem_size ;

opttrace_max_mem_size:
  opttrace_big_size | opttrace_small_size | DEFAULT ;

opttrace_big_size:
  { $prng->int(1048576,134217728) } ;

opttrace_small_size:
  { $prng->int(1,1048576) } ;

opttrace_is_select:
  SELECT * FROM INFORMATION_SCHEMA.OPTIMIZER_TRACE _basics_order_by_limit_50pct_offset_10pct ;
