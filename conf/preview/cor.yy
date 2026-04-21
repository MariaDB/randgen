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
#features GIS columns, system-versioned tables, sequences

### GIS is included via _basics_column_type
### system-versioned tables is included via _basics_column_attributes

query:
  { _set_db('NON-SYSTEM') } crea_query;

crea_query:
  CREATE OR REPLACE __temporary(50) TABLE crea_table_name LIKE _table |
  CREATE OR REPLACE __temporary(50) TABLE crea_table_name optional_engine AS SELECT * FROM _table LIMIT crea_limit |
  CREATE OR REPLACE __temporary(50) TABLE crea_table_name crea_table_definition |
  CREATE OR REPLACE __temporary(10) SEQUENCE crea_sequence_name crea_sequence_definition |
  ==FACTOR:0.1==
       LOCK TABLE crea_table_name[invariant] WRITE, _table[invariant] WRITE
    ;; CREATE OR REPLACE __temporary(50) TABLE crea_table_name[invariant] LIKE _table[invariant]
    ;; UNLOCK TABLES |
  ==FACTOR:0.1==
       LOCK TABLE crea_table_name[invariant] WRITE, _table[invariant] WRITE
    ;; CREATE OR REPLACE __temporary(50) TABLE crea_table_name[invariant] optional_engine AS SELECT * FROM _table[invariant] LIMIT crea_limit
    ;; UNLOCK TABLES |
  ==FACTOR:0.1==
       LOCK TABLE create_table_name[invariant] WRITE
    ;; CREATE OR REPLACE __temporary(50) TABLE crea_table_name[invariant] crea_table_definition
    ;; UNLOCK TABLES |
  ==FACTOR:0.1==
       LOCK TABLE crea_sequence_name[invariant] WRITE
    ;; CREATE OR REPLACE __temporary(10) SEQUENCE crea_sequence_name[invariant] crea_sequence_definition
    ;; UNLOCK TABLES |
  ==FACTOR:0.1==
    CREATE OR REPLACE TRIGGER { 'tr'.$prng->uint16(1,100) } __before_x_after __insert_x_update_x_delete ON crea_table_name FOR EACH ROW BEGIN END |
  ==FACTOR:0.01== SET __session_x_global DROP_BEFORE_CREATE_OR_REPLACE = __on_x_off
;

crea_sequence_definition:
  optional_engine ;

crea_sequence_name:
    `CreateOrReplaceSequence` | { 'CreateOrReplaceSequence'.abs($$) } | _sequence | _table ;

crea_table_name:
  `CreateOrReplaceTable` |
  { 'CreateOrReplaceTable'.abs($$) } |
  _table |
  ==FACTOR:0.1== { 'test.`'.chr(35).'cortable`' } |
  ==FACTOR:0.1== { '`'.chr(35).'cortable`' } |
  ==FACTOR:0.1== { 'test.`'.chr(64).'cortable`' } ;

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

