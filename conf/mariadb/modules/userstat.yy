#  Copyright (c) 2018, MariaDB
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

query_add:
  query | query | query | query | query | query | query | userstat_query
;

userstat_query:
    userstat_show | userstat_show | userstat_show | userstat_show
  | FLUSH userstat_flush_list
  | userstat_set
;

userstat_show:
    SHOW CLIENT_STATISTICS
  | SHOW INDEX_STATISTICS
  | SHOW TABLE_STATISTICS
  | SHOW USER_STATISTICS
;

userstat_set:
    SET GLOBAL userstat= 1
  | SET GLOBAL userstat= 0
;

userstat_flush_list:
  userstat_flush_option | userstat_flush_option, userstat_flush_list
;

userstat_flush_option:
    CLIENT_STATISTICS
  | INDEX_STATISTICS
  | TABLE_STATISTICS
  | USER_STATISTICS
;
