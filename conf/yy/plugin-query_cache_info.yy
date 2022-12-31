#  Copyright (c) 2022, MariaDB Corporation Ab
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
# The grammar should be used with
# --mysqld=--plugin-load-add=query_cache_info --mysqld=--loose-query-cache-info
########################################################################

#compatibility 10.7.0

query:
  SELECT STATEMENT_SCHEMA, STATEMENT_TEXT, RESULT_BLOCKS_COUNT, RESULT_BLOCKS_SIZE FROM INFORMATION_SCHEMA.QUERY_CACHE_INFO |
  SELECT * FROM INFORMATION_SCHEMA.QUERY_CACHE_INFO |
  SHOW CREATE TABLE INFORMATION_SCHEMA.QUERY_CACHE_INFO
;
