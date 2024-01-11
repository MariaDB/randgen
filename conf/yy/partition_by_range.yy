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
  ;; SET time_zone = _timezone
  ;; SET ROLE admin
     # PS is a workaround for MDEV-30190
  ;; EXECUTE IMMEDIATE CONCAT('GRANT ALL ON partition_db.* TO ',CURRENT_USER,' WITH GRANT OPTION')
  ;; SET ROLE NONE
  ;; {our $nb_parts= 50; $tblnum=0 ; _set_db('partition_db') } init_db ;

create:
  CREATE TABLE if_not_exists { $new_table= 'trange_'.(++$tblnum).'_'.$generator->threadId() } (
                `col_int_nokey` INTEGER,
                `col_int_key` INTEGER NOT NULL,
                KEY (`col_int_key` __asc_x_desc(33,33))
  ) engine_clause partition |
  CREATE TABLE if_not_exists { $new_table= 'trange_'.(++$tblnum).'_'.$generator->threadId() } (`col_ts` TIMESTAMP) engine_clause PARTITION BY RANGE (UNIX_TIMESTAMP(col_ts)) {$ts=0; $max_ts=2147483647; $pn=0; $part_field= '`col_ts`'; ''} (partition_unix_timestamp_list) |
  CREATE TABLE if_not_exists { $new_table= 'trange_'.(++$tblnum).'_'.$generator->threadId() } (`col_ts` TIMESTAMP)  engine_clause PARTITION BY RANGE (UNIX_TIMESTAMP(col_ts)) {$ts=0; $max_ts=4294967295; $pn=0; $part_field= '`col_ts`'; ''} (partition_unix_timestamp_list) /* compatibility 11.4 */
;

partition_unix_timestamp_list:
  partition_unix_ts_list optional_max_value_partition
;

partition_unix_ts_list:
  partition_unix_ts |
  ==FACTOR:3== partition_unix_ts_list, partition_unix_ts
;

partition_unix_ts:
  PARTITION { 'p'.($pn++) } VALUES LESS THAN ({$ts= $prng->uint16($ts,$max_ts)});

optional_max_value_partition:
  ==FACTOR:2== |
  , PARTITION { 'p'.($pn++) } VALUES LESS THAN ($max_ts) |
  , PARTITION { 'p'.($pn++) } VALUES LESS THAN (MAXVALUE) |
  , PARTITION { 'p'.($pn++) } VALUES LESS THAN ($max_ts) , PARTITION { 'p'.($pn++) } VALUES LESS THAN (MAXVALUE)
;

dml_table_name:
  { our $ind= 0; return undef }
  _table PARTITION (partition_name_list) ;

part_list:
        part_list_elem_10 |
        part_list part_list_elem_10 |
        part_list part_list_elem_10 |
        part_list part_list_elem_10 |
        part_list part_list_elem_10
;

part_list_elem_10:
        part_elem part_elem part_elem part_elem part_elem
        part_elem part_elem part_elem part_elem part_elem ;

part_elem:
        { return "p".$ind++."," } ;

last_part_elem:
        { return "p".$ind++ } ;

partition_name_list:
  { our $ind= 0; return undef }
  part_list last_part_elem ;

partition_name:
  { our $nb_part_list= $prng->uint16(0,$nb_parts); 'p'.$nb_part_list . ($prng->uint16(0,3) ? '' : 'sp'.$prng->uint16(0,3)) } ;

partition:
  { our $nb_part_list= $prng->uint16($nb_parts-5,$nb_parts); return undef }
  partition_by_range ;

partition_by_range:
          range_elements { our $ind= 0; return undef }
          PARTITION BY RANGE ( part_field ) subpartition (
          range_list
          PARTITION {"p".$ind++} VALUES LESS THAN partition_top_limit );

partition_top_limit:
  ({$prng->uint16(10000,2**32-1)}) |
  MAXVALUE
;

range_elements:
          { our @range_list; for (my $i=0; $i<$nb_parts; $i++) { push (@range_list, "PARTITION p$i VALUES LESS THAN (".(($i+1)*3)."),")}; return undef } ;

range_list_elem_10:
        range_elem range_elem range_elem range_elem range_elem
        range_elem range_elem range_elem range_elem range_elem ;

range_list:
  range_list_elem_10 range_list_elem_10 range_list_elem_10 range_list_elem_10
  range_list_elem_10 range_list_elem_10 range_list_elem_10 range_list_elem_10
  range_list_elem_10 range_list_elem_10
;

range_elem:
        { $ind<$nb_part_list ? return @range_list[$ind++] : "" } ;

alter_convert_table_to_part:
  ALTER TABLE _table[invariant] CONVERT TABLE tp_exchange TO PARTITION pn VALUES LESS THAN partition_top_limit opt_with_without_validation ;; ALTER TABLE _table[invariant] DROP PARTITION pn
;

value:
  ==FACTOR:3== _digit |
  { $prng->uint16(0,2147483647) } |
  ==FACTOR:0.1== FROM_UNIXTIME({ $prng->uint16(2147483647,4294967295) }) |
  ==FACTOR:0.1== FROM_UNIXTIME(4294967295)
;
