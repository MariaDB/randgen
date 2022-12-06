# Copyright (c) 2010, 2012, Oracle and/or its affiliates. All rights reserved.
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

########################################################################
# This grammar goes together with the respective SQL file which creates the tables
########################################################################

query_init:
  # This is to prevent other grammars from altering the schema
  GRANT INSERT, UPDATE, DELETE, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, SHOW VIEW ON oqgraph_db.* TO CURRENT_USER
;

query:
  { _set_db('oqgraph_db') } oqgraph_query ;

oqgraph_query:
  ==FACTOR:5== insert |
  update |
  delete |
  ==FACTOR:5== select ;

select:
  SELECT * FROM oqgraph_table |
  SELECT * FROM oqgraph_table WHERE latch = 0 |
  SELECT * FROM oqgraph_table WHERE latch = 0 AND origid = nodeid |
  SELECT * FROM oqgraph_table WHERE latch = 0 AND destid = nodeid |
  SELECT * FROM oqgraph_table WHERE latch = 1 AND origid = nodeid AND destid = nodeid |
  SELECT * FROM oqgraph_table WHERE latch = 1 AND origid = nodeid |
  SELECT * FROM oqgraph_table WHERE latch = 1 AND destid = nodeid |
  SELECT * FROM oqgraph_table WHERE latch = 2 AND origid = nodeid AND destid = nodeid |
  SELECT * FROM oqgraph_table WHERE latch = 2 AND origid = nodeid |
  SELECT * FROM oqgraph_table WHERE latch = 2 AND destid = nodeid ;

insert:
  insert_single | insert_select |
  insert_multi | insert_multi | insert_multi | insert_multi ;

insert_single:
  INSERT IGNORE INTO oqgraph_backing_table ( `origid` , `destid` ) VALUES ( nodeid , nodeid );

insert_multi:
  INSERT IGNORE INTO oqgraph_backing_table ( `origid` , `destid` ) VALUES insert_multi_list_noweight ;

insert_multi_list_noweight:
  insert_multi_item_noweight |
  insert_multi_list_noweight , insert_multi_item_noweight |
  insert_multi_list_noweight , insert_multi_item_noweight |
  insert_multi_list_noweight , insert_multi_item_noweight ;

insert_multi_item_noweight:
  ( nodeid , nodeid );

insert_select:
  INSERT IGNORE INTO oqgraph_backing_table ( `origid` , `destid` ) SELECT `origid` , `destid` FROM oqgraph_table where  ;

update:
  UPDATE oqgraph_backing_table SET update_list where ;

update_list:
  update_item |
  update_item , update_list ;

update_item:
  `destid` = nodeid |
  `origid` = nodeid ;

delete:
  DELETE FROM oqgraph_backing_table ;

where:
;

nodeid:
  _digit | _tinyint_unsigned | _tinyint_unsigned | _smallint_unsigned | _smallint_unsigned ;

oqgraph_table:
  oqgraph1 | oqgraph2 ;

oqgraph_backing_table:
  oq_backing1 | oq_backing2 ;
