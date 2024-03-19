#  Copyright (c) 2018, 2024, MariaDB
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

query:
  ==FACTOR:5== SHOW show_item |
               FLUSH flush_list |
  ==FACTOR:5== SELECT * FROM INFORMATION_SCHEMA. show_item |
               SET GLOBAL userstat= __0_x_1
;

show_item:
    CLIENT_STATISTICS
  | INDEX_STATISTICS
  | TABLE_STATISTICS
  | USER_STATISTICS
;

flush_list:
  flush_option | flush_option, flush_list
;

flush_option:
    CLIENT_STATISTICS
  | INDEX_STATISTICS
  | TABLE_STATISTICS
  | USER_STATISTICS
;
