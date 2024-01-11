# Copyright (c) 2003, 2012, Oracle and/or its affiliates. All rights reserved.
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
#
##########################################################################
# This grammar contains ddl for partitions as well as partition extentions to dml.
# The grammar doesn't rely on the predefined tables, but uses instead
# tables defined in init.
# Rules common with other partitioning types are in the include file
##########################################################################

#include <conf/yy/include/partition_by.inc>


query_init:
     CREATE DATABASE IF NOT EXISTS partition_db
  ;; SET ROLE admin
     # PS is a workaround for MDEV-30190
  ;; EXECUTE IMMEDIATE CONCAT('GRANT ALL ON partition_db.* TO ',CURRENT_USER,' WITH GRANT OPTION')
  ;; SET ROLE NONE
  ;; {$tblnum=0 ; _set_db('partition_db') } init_db ;

create:
  CREATE TABLE if_not_exists { $new_table= 'tlist_'.(++$tblnum).'_'.$generator->threadId() } (
                `col_int_nokey` INTEGER,
                `col_int_key` INTEGER NOT NULL,
                KEY (`col_int_key` __asc_x_desc(33,33))
  ) engine_clause partition ;

dml_table_name:
  _table PARTITION (partition_name_list) ;

partition_name_list:
  partition_name_comb                 |
  partition_name_comb                 |
  partition_name_comb                 |
  partition_name                      |
  partition_name                      |
  partition_name                      |
  partition_name                      |
  partition_name                      |
  partition_name, partition_name_list ;

partition_name_comb:
  p0,p1       |
  p0,p1,p2    |
  p0,p1,p2,p3 |
  p1,p2       |
  p1,p2,p3    |
  p2,p3       |
  p2,p3,p1    |
  p3,p1       |
  p0,p2       |
  p0,p3       ;

partition_name:
  { 'p'.$prng->uint16(0,3) . ($prng->uint16(0,3) ? '' : 'sp'.$prng->uint16(0,3)) } ;

partition:
  partition_by_list ;

partition_by_list:
  PARTITION BY LIST ( part_field ) subpartition partition_by_list_definition
;

partition_by_list_definition:
  ( populate_digits
    PARTITION p0 VALUES IN ( shift_digit, NULL ),
    PARTITION p1 VALUES IN ( shift_digit, shift_digit, shift_digit ),
    PARTITION p2 VALUES IN ( shift_digit, shift_digit, shift_digit ),
    PARTITION p3 VALUES IN ( shift_digit, shift_digit, shift_digit )
    default_list_partition
  )
;

default_list_partition:
  | , PARTITION pdef DEFAULT ;

populate_digits:
  { @digits = @{$prng->shuffleArray([0..9])} ; return undef };

shift_digit:
  { shift @digits };

partition_extra:
  VALUES IN ( { @vals = @{$prng->shuffleArray([10..100])}; join ',', @vals } ) |
  DEFAULT
;

alter_convert_table_to_part:
  ALTER TABLE _table[invariant] CONVERT TABLE tp_exchange TO PARTITION pn partition_extra opt_with_without_validation ;; ALTER TABLE _table[invariant] DROP PARTITION pn
;

value:
  _digit ;
