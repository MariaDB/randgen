# Copyright (C) 2022 MariaDB Corporation Ab
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

#features S3 engine, S3 tables, Aria tables
#compatibility 10.5.0

query_init:
  { $s3_doable= $ENV{S3_DOABLE}; '' } ;

query:
  { _set_db('user') } s3_query ;

s3_query:
  ==FACTOR:0.01== { '/*'.$s3_doable.' ' } ALTER TABLE _table ENGINE=S3 */ |
  ==FACTOR:0.01== s3_alter_table_back
;

s3_alter_table_back:
    SET @stmt_sql= NULL
  ; SELECT CONCAT('ALTER TABLE ',table_schema,'.',table_name,' ENGINE=', s3_other_engine) INTO @stmt_sql FROM INFORMATION_SCHEMA.TABLES WHERE ENGINE='S3' ORDER BY table_schema, table_name LIMIT 1
  ; IF @stmt_sql IS NOT NULL THEN EXECUTE IMMEDIATE @stmt_sql
  ; END IF ;


s3_other_engine:
  ==FACTOR:3== 'Aria' |
  'InnoDB' |
  'MyISAM'
;
