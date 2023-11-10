# Copyright (c) 2023, MariaDB
# Use is subject to license terms.
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

# Basic compound statement syntax, placeholder
# TODO: to be extended

#features ROW type

query:
  { _set_db('NON-SYSTEM') } BEGIN NOT ATOMIC compound_block ; END ;

compound_block:
  declare_row_type |
  declare_row_type_default
;

declare_row_type:
    DECLARE r ROW TYPE OF _table[invariant]
  ; SELECT * INTO r FROM _table[invariant] LIMIT 1
  ; SELECT r._field
;

declare_row_type_default:
    DECLARE r ROW TYPE OF _table[invariant] DEFAULT (SELECT * FROM _table[invariant] LIMIT 1)
  ; SELECT r._field
;
