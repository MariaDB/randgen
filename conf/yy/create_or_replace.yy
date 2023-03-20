# Copyright (C) 2022, MariaDB
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

#include <conf/yy/include/basics.inc>
#features GIS columns, system-versioned tables
### GIS is included via _basics_column_type
### system-versioned tables is included via _basics_column_attributes

query:
  { _set_db('NON-SYSTEM') } crea_query;

crea_query:
  CREATE OR REPLACE TABLE crea_table_name LIKE _table |
  CREATE OR REPLACE TABLE crea_table_name optional_engine AS SELECT * FROM _table LIMIT crea_limit |
  CREATE OR REPLACE TABLE crea_table_name crea_table_definition
;

crea_table_name:
    `CreateOrReplaceTable` | { 'CreateOrReplaceTable'.abs($$) } | _table ;

crea_limit:
  0 | _digit | _smallint_unsigned ;

crea_table_definition:
  { $colnum=0; '' } ( crea_column_list ) optional_engine _basics_table_options __with_system_versioning(5) optional_partitioning ;

optional_engine:
  | ENGINE=_engine;

optional_partitioning:
  ==FACTOR:10== |
  { $partition_field = 'col'.$prng->uint16(1,$colnum); '' } _basics_table_partitioning ;

crea_column_list:
  crea_column |
  ==FACTOR:3== crea_column, crea_column_list ;

crea_column:
  { 'col'.(++$colnum) } _basics_column_type _basics_column_attributes;

