#  Copyright (c) 2021, 2022, MariaDB
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

########################################
# MDEV-13756 Implement descending index
########################################

query_init:
  { $ind=1; _set_db('NON-SYSTEM') } add_8 ;

add_8:
  add_4 ;; add_4 ;

add_4:
  add ;; add ;; add ;; add ;

add:
  ALTER __online(10) TABLE _basetable ADD key_or_unique IF NOT EXISTS { 'ord_index_'.($ind++).'_'.abs($$) } ( field_list ) algorithm_optional;

query:
  { _set_db('NON-SYSTEM') } desc_indexes_query ;

desc_indexes_query:
    add
  | ==FACTOR:2== ALTER __online(10) TABLE _basetable DROP KEY IF EXISTS { 'ord_index_'.$prng->uint16(1,$ind).'_'.abs($$) } algorithm_optional
  | ==FACTOR:0.05== ALTER TABLE _basetable DROP PRIMARY KEY algorithm_optional
  | ==FACTOR:0.2== ANALYZE TABLE _basetable PERSISTENT FOR ALL
  | ==FACTOR:0.05== ALTER __online(10) TABLE _basetable FORCE algorithm_optional
  | /* _table */ SELECT _field FROM { $last_table } WHERE { $last_field } LIKE { "'" . $prng->unquotedString($prng->uint16(0,8)) ."%'" }
;

algorithm_optional:
  | , ALGORITHM = __default_x_inplace_x_copy_x_nocopy_x_instant ;

key_or_unique:
  ==FACTOR:20== KEY |
  UNIQUE |
  PRIMARY KEY
;

field_list:
  _field  __asc_x_desc(33,33) |
  _field_char (_tinyint_unsigned)  __asc_x_desc(33,33) |
  ==FACTOR:2== _field  __asc_x_desc(33,33), field_list
;
