#  Copyright (c) 2019, 2022, MariaDB Corporation Ab
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

#
# The test should be run with
# --mysqld=--plugin-load-add=metadata_lock_info --mysqld=--loose-metadata-lock-info
#

query_add:
  ==FACTOR:0.05== SELECT * FROM INFORMATION_SCHEMA.METADATA_LOCK_INFO metadata_lock_info_where
;

metadata_lock_info_where:
  | WHERE THREAD_ID = CONNECTION_ID() | WHERE THREAD_ID != CONNECTION_ID()
;