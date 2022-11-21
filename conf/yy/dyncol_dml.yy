# Copyright (c) 2010, 2012, Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2022, MariaDB
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

########################################################################
# Should be used with dyncol_dml.zz or something equally rich of blobs
########################################################################

query:
  select | insert | update | delete ;

select:
  SELECT select_list FROM _table where_clause |
  SELECT column_delete FROM _table where_clause ;

select_list:
  select_item |
  select_item , select_list ;

select_item:
  column |
  column_delete |
  column_exists |
  column_list ;

insert:
  INSERT INTO _table SET insert_list ;

update:
  UPDATE _table SET column_name = column where_clause ORDER BY pk LIMIT 1;

delete:
  DELETE FROM _table where_clause ORDER BY pk LIMIT 1 ;

where_clause:
  WHERE where_expr |
  WHERE where_expr __and_x_or where_expr ;

where_expr:
  __not(50) column_exists |
  __not(50) column = column |
  __not(50) column_get comp_op value |
  column_get IS __not(50) NULL ;

comp_op:
  = | < | > | <= | >= | != | <> | <=> ;

insert_list:
  column_name = column_create |
  column_name = column_create , insert_list ;

column:
  column_name |
  column_create |
  column_add ;

column_create:
  COLUMN_CREATE( column_number_value_list );

column_add:
  COLUMN_ADD( column , column_number_value_list );

column_delete:
  COLUMN_DELETE( column , column_number );

column_get:
  COLUMN_GET( column , column_number AS type );

column_exists:
  COLUMN_EXISTS( column , column_number );

column_list:
  COLUMN_LIST( column );

column_number_value_list:
  column_number_value |
  column_number_value , column_number_value ;

column_number_value:
  column_number , column_value ;

column_number:
  _digit | _tinyint_unsigned ;

column_value:
  value |
  value AS type ;

value:
  column_get | _digit | _varchar(1) | _varchar(512) | _tinyint_unsigned | NULL ;

type:
#  BINARY | BINARY( width ) |
  CHAR |
#  CHAR( width ) |
  DATE |  # bug 778905
  DATETIME |
#  DATETIME( time_precision ) |  # requires millisecond precision
#  DECIMAL | DECIMAL( precision ) | DECIMAL( precision , scale ) |
  DOUBLE |
  INTEGER |
#  SIGNED INTEGER |
  TIME ;
#  TIME( time_precision )     # requires millisecond precision
#  UNSIGNED INTEGER ;

width:
  _digit | _tinyint_unsigned ;

time_precision:
  0 | 3 | 6 ;

precision:
  5 | 6 | 7 | 8 | 9;

scale:
  1 | 2 | 3 | 4 ;

column_name:
  _field_no_pk ;
