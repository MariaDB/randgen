# Copyright (C) 2024, MariaDB
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

query:
  SET GLOBAL MAX_BINLOG_TOTAL_SIZE = max_binlog_total_size_value |
  SET GLOBAL SLAVE_CONNECTIONS_NEEDED_FOR_PURGE = { $prng->uint16(0,3) } |
  SET TIMESTAMP = timestamp_32k_value ;

max_binlog_total_size_value:
  0 | DEFAULT | 1024*1024*4 | 1024*1024*64 | 1024*1024*1024 ;

timestamp_32k_value:
  DEFAULT | { $prng->uint16(2147483648,4294967295) } | 4294967295 ;
