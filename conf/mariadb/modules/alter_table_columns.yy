#  Copyright (c) 2018, MariaDB
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


query_add:
  query | query | query | alttcol_query
;

alttcol_query:
  ALTER alttcol_online alttcol_ignore TABLE _table /*!100301 alttcol_wait */ alttcol_list_with_optional_order_by
;

alttcol_online:
  | | | ONLINE
;

alttcol_ignore:
  | | IGNORE
;

alttcol_wait:
  | | | WAIT _digit | NOWAIT
;

alttcol_list_with_optional_order_by:
  alttcol_list alttcol_order_by
;

alttcol_list:
  alttcol_item_alg_lock | alttcol_item_alg_lock | alttcol_item_alg_lock, alttcol_list
;

# Can't put it on the list, as ORDER BY should always go last
alttcol_order_by:
# Disabled due to MDEV-17725
#  | | | | | | | | | | , ORDER BY alttcol_column_list
;

alttcol_item_alg_lock:
  alttcol_item alttcol_algorithm alttcol_lock
;

alttcol_item:
    alttcol_add_column | alttcol_add_column | alttcol_add_column
  | alttcol_alter_column
  | alttcol_change_column | alttcol_change_column
  | alttcol_modify_column | alttcol_modify_column
  | alttcol_drop_column
;

alttcol_add_column:
    ADD alttcol_column_word alttcol_if_not_exists alttcol_col_name alttcol_add_definition alttcol_location
  | ADD alttcol_column_word alttcol_if_not_exists ( alttcol_add_list )
;

alttcol_alter_column:
    ALTER alttcol_column_word /*!100305 alttcol_if_exists */ alttcol_col_name SET DEFAULT alttcol_default_val
  | ALTER alttcol_column_word /*!100305 alttcol_if_exists */ alttcol_col_name DROP DEFAULT
;

alttcol_change_column:
    CHANGE alttcol_column_word alttcol_if_exists alttcol_col_name alttcol_col_name alttcol_add_definition alttcol_location
;

alttcol_modify_column:
    MODIFY alttcol_column_word alttcol_if_exists alttcol_col_name alttcol_add_definition alttcol_location
;

alttcol_drop_column:
    DROP alttcol_column_word alttcol_if_exists alttcol_col_name alttcol_restrict_cascade
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
  | alttcol_virt_col_definition alttcol_virt_type alttcol_invisible alttcol_check_constraint
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
  | /*!100201 DEFAULT ST_GEOMFROMTEXT('Point(1 1)') */ ;


alttcol_virt_col_definition:
    alttcol_int_type alttcol_generated_always AS ( alttcol_col_name )
  | alttcol_int_type alttcol_generated_always AS ( alttcol_col_name + _digit )
  | alttcol_num_type alttcol_generated_always AS ( alttcol_col_name + _digit )
  | alttcol_num_type alttcol_generated_always AS ( alttcol_col_name + _digit )
  | alttcol_temporal_type alttcol_generated_always AS ( alttcol_col_name )
  | alttcol_timestamp_type alttcol_generated_always AS ( alttcol_col_name )
  | alttcol_text_type alttcol_generated_always AS ( alttcol_col_name )
  | alttcol_text_type alttcol_generated_always AS ( SUBSTR(alttcol_col_name, _digit, _digit ) )
  | alttcol_enum_type alttcol_generated_always AS ( alttcol_col_name )
  | alttcol_geo_type alttcol_generated_always AS ( alttcol_col_name )
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
  | /*!100201 STORED */ /*!!100201 PERSISTENT */ | VIRTUAL
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
  NULL | '' | _char(1)
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
  | | | | | | | /*!100303 INVISIBLE */
;

alttcol_check_constraint:
  | | | | | | | /*!100201 CHECK (alttcol_check_constraint_expression) */
;

# TODO: extend
alttcol_check_constraint_expression:
    alttcol_col_name alttcol_operator alttcol_col_name
  | alttcol_col_name alttcol_operator _digit
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
  NULL | alttcol_default_char_val | alttcol_default_int_val
;

alttcol_default_int_val:
  NULL | 0 | 0 | 0 | _digit | _tinyint
;

alttcol_column_word:
  | COLUMN
;

alttcol_if_not_exists:
  | IF NOT EXISTS | IF NOT EXISTS | IF NOT EXISTS | IF NOT EXISTS
;

alttcol_if_exists:
  | IF EXISTS | IF EXISTS | IF EXISTS | IF EXISTS
;

alttcol_col_name:
  _field | _letter
;

alttcol_add_list:
  alttcol_col_name alttcol_add_definition | alttcol_col_name alttcol_add_definition, alttcol_add_list
;

alttcol_location:
  | | | | | FIRST | AFTER alttcol_col_name
;

alttcol_restrict_cascade:
  | | | | | | | RESTRICT | CASCADE
;

alttcol_algorithm:
  | | | | , ALGORITHM=DEFAULT | , ALGORITHM=INPLACE | , ALGORITHM=COPY | /*!100307 , ALGORITHM=NOCOPY */ | /*!100307 , ALGORITHM=INSTANT */
;

alttcol_lock:
  | | | | , LOCK=DEFAULT | , LOCK=NONE | , LOCK=SHARED | , LOCK=EXCLUSIVE
;
  
