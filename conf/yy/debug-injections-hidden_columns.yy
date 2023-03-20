# Copyright (c) 2022, MariaDB
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

query:
  set_debug_invisible
;

# test_completely_invisible disabled due to MDEV-15130 (won't fix)
# test_pseudo_invisible disabled due to MDEV-15130 (won't fix)
set_debug_invisible:
  | SET debug_dbug="+d,test_invisible_index"
  | SET debug_dbug="+d,test_pseudo_invisible,test_invisible_index"
  | SET debug_dbug=""
  | SET debug_dbug=""
  | SET debug_dbug=""
;

