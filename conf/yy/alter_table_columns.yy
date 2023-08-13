#  Copyright (c) 2018, 2022, MariaDB Corporation
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

#include <conf/yy/include/basics.inc>

query_init:
  { $colnum=0; '' } ;

query:
  { _set_db('NON-SYSTEM') } alttcol_query
;

alttcol_query:
  ALTER alttcol_online alttcol_ignore TABLE _basetable _basics_wait_nowait alttcol_list_with_optional_order_by
;

alttcol_online:
  | | | ONLINE
;

alttcol_ignore:
  | | IGNORE
;

alttcol_list_with_optional_order_by:
  alttcol_list alttcol_order_by
;

alttcol_list:
  ==FACTOR:5== alttcol_item_alg_lock |
  alttcol_item_alg_lock, alttcol_list
;

# Can't put it on the list, as ORDER BY should always go last
alttcol_order_by:
  | | | | | | | | | | , ORDER BY alttcol_column_list ;

alttcol_column_list:
  _field | _field, alttcol_column_list ;

alttcol_item_alg_lock:
  alttcol_item alttcol_algorithm alttcol_lock
;

alttcol_item:
  ==FACTOR:4== alttcol_add_column |
               alttcol_alter_column |
  ==FACTOR:2== alttcol_change_column |
               alttcol_rename_column |
  ==FACTOR:6== alttcol_modify_column |
               alttcol_drop_column
;

alttcol_add_column:
    ADD alttcol_column_word __if_not_exists(95) alttcol_col_new_name alttcol_add_definition alttcol_location
  | ADD alttcol_column_word __if_not_exists(95) ( alttcol_add_list )
;

alttcol_alter_column:
    ALTER alttcol_column_word __if_exists(95) _field SET DEFAULT alttcol_default_val
  | ALTER alttcol_column_word __if_exists(95) _field DROP DEFAULT
;

alttcol_change_column:
    CHANGE alttcol_column_word __if_exists(95) _field alttcol_new_or_existing_col_name alttcol_add_definition alttcol_location
;

alttcol_rename_column:
    /* compatibility 10.5.2 */ RENAME COLUMN __if_exists(95) _field TO alttcol_new_or_existing_col_name
;

alttcol_modify_column:
    MODIFY alttcol_column_word __if_exists(95) _field alttcol_add_definition alttcol_location
;

alttcol_drop_column:
    DROP alttcol_column_word __if_exists(95) _field alttcol_restrict_cascade
;

alttcol_new_or_existing_col_name:
  ==FACTOR:20== alttcol_col_new_name |
  _field
;

alttcol_add_definition:
    BIT alttcol_null alttcol_default_int_or_auto_increment alttcol_invisible alttcol_check_constraint
  | alttcol_int_type alttcol_unsigned alttcol_zerofill alttcol_null alttcol_default_int_or_auto_increment alttcol_invisible alttcol_check_constraint
  | alttcol_int_type alttcol_unsigned alttcol_zerofill alttcol_null alttcol_default_int_or_auto_increment alttcol_invisible alttcol_check_constraint
  | alttcol_int_type alttcol_unsigned alttcol_zerofill alttcol_null alttcol_default_int_or_auto_increment alttcol_invisible alttcol_check_constraint
  | SERIAL alttcol_invisible alttcol_check_constraint
  | alttcol_num_type alttcol_unsigned alttcol_zerofill alttcol_null alttcol_optional_default alttcol_invisible alttcol_check_constraint
  | alttcol_temporal_type alttcol_null alttcol_optional_default alttcol_invisible alttcol_check_constraint
  | alttcol_timestamp_type alttcol_null alttcol_optional_default_or_current_timestamp alttcol_invisible alttcol_check_constraint
  | alttcol_text_type alttcol_null alttcol_optional_default_char alttcol_invisible alttcol_check_constraint
  | alttcol_text_type alttcol_null alttcol_optional_default_char alttcol_invisible alttcol_check_constraint
  | alttcol_text_type alttcol_null alttcol_optional_default_char alttcol_invisible alttcol_check_constraint
  | alttcol_enum_type alttcol_null alttcol_optional_default alttcol_invisible alttcol_check_constraint
# TODO: vcols: adjust probability when virtual columns start working
  | ==FACTOR:0.01== alttcol_virt_col_definition alttcol_virt_type alttcol_invisible alttcol_check_constraint
  | alttcol_geo_type alttcol_null alttcol_geo_optional_default alttcol_invisible alttcol_check_constraint
;

alttcol_int_type:
    INT
  | TINYINT | SMALLINT | MEDIUMINT | BIGINT
;

alttcol_num_type:
  DECIMAL | FLOAT | DOUBLE
;

alttcol_temporal_type:
  DATE | TIME | YEAR
;

alttcol_timestamp_type:
  DATETIME | TIMESTAMP
;

alttcol_enum_type:
  ENUM('foo','bar') | SET('foo','bar')
;

alttcol_text_type:
  BLOB | TEXT | CHAR | VARCHAR(_smallint_unsigned) | BINARY | VARBINARY(_smallint_unsigned)
;

alttcol_geo_type:
  POINT | LINESTRING | POLYGON | MULTIPOINT | MULTILINESTRING | MULTIPOLYGON | GEOMETRYCOLLECTION | GEOMETRY
;

alttcol_geo_optional_default:
  | DEFAULT ST_GEOMFROMTEXT('Point(1 1)') ;


alttcol_virt_col_definition:
    alttcol_int_type alttcol_generated_always AS ( _field )
  | alttcol_int_type alttcol_generated_always AS ( _field + _digit )
  | alttcol_num_type alttcol_generated_always AS ( _field + _digit )
  | alttcol_num_type alttcol_generated_always AS ( _field + _digit )
  | alttcol_temporal_type alttcol_generated_always AS ( _field )
  | alttcol_timestamp_type alttcol_generated_always AS ( _field )
  | alttcol_text_type alttcol_generated_always AS ( _field )
  | alttcol_text_type alttcol_generated_always AS ( SUBSTR_field, _digit, _digit ) )
  | alttcol_enum_type alttcol_generated_always AS ( _field )
  | alttcol_geo_type alttcol_generated_always AS ( _field )
;

alttcol_null:
  | | NULL | NOT NULL | NOT NULL
;

alttcol_unsigned:
  | | | | UNSIGNED
;

alttcol_zerofill:
  | | | | ZEROFILL
;

alttcol_generated_always:
  | | | GENERATED ALWAYS
;

alttcol_virt_type:
  STORED | VIRTUAL
;

alttcol_default_int_or_auto_increment:
  alttcol_optional_default_int | alttcol_optional_default_int | alttcol_optional_default_int | alttcol_optional_auto_increment
;

alttcol_optional_default:
  | DEFAULT alttcol_default_val
;

alttcol_optional_default_int:
  | DEFAULT alttcol_default_int_val
;

alttcol_default_char_val:
  ==FACTOR:0.01== NULL |
                  '' |
                  _char(1)
;

alttcol_optional_default_or_current_timestamp:
  | DEFAULT alttcol_default_or_current_timestamp_val
;

alttcol_default_or_current_timestamp_val:
    '1970-01-01'
  | CURRENT_TIMESTAMP
  | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  | 0
;

alttcol_optional_auto_increment:
  | | | | | | |
  | AUTO_INCREMENT
  | AUTO_INCREMENT PRIMARY KEY
  | SERIAL DEFAULT VALUE
;

alttcol_optional_default_char:
  | DEFAULT alttcol_default_char_val
;

alttcol_invisible:
  | | | | | | | INVISIBLE
;

alttcol_check_constraint:
  | | | | | | | CHECK (alttcol_check_constraint_expression)
;

# TODO: extend
alttcol_check_constraint_expression:
    _field alttcol_operator _field
  | _field alttcol_operator _digit
;

alttcol_operator:
  = | != | LIKE | NOT LIKE | < | <= | > | >=
;

alttcol_alter_definition:
  SET DEFAULT alttcol_default_val |
  DROP DEFAULT
;

# TODO: expand
alttcol_default_val:
  ==FACTOR:0.01== NULL |
  alttcol_default_char_val |
  alttcol_default_int_val
;

alttcol_default_int_val:
  ==FACTOR:0.01== NULL |
  ==FACTOR:5==    0 |
                  _digit |
                  _tinyint
;

alttcol_column_word:
  | COLUMN
;

alttcol_col_new_name:
  { 'alttcol'.(++$colnum) } ;

alttcol_add_list:
  alttcol_col_new_name alttcol_add_definition | alttcol_col_new_name alttcol_add_definition, alttcol_add_list
;

alttcol_location:
  | | | | | FIRST | AFTER _field
;

alttcol_restrict_cascade:
  | | | | | | | RESTRICT | CASCADE
;

alttcol_algorithm:
  ==FACTOR:10== |
  ==FACTOR:2== , ALGORITHM=DEFAULT |
               , ALGORITHM=INPLACE |
  ==FACTOR:5== , ALGORITHM=COPY |
               , ALGORITHM=NOCOPY |
               , ALGORITHM=INSTANT
;

alttcol_lock:
  ==FACTOR:10== |
  ==FACTOR:2== , LOCK=DEFAULT |
               , LOCK=NONE |
               , LOCK=SHARED |
               , LOCK=EXCLUSIVE
;

