# Copyright (c) 2011, Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2021, MariaDB Corporation Ab.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# 51 Franklin Street, Suite 500, Boston, MA 02110-1335 USA

query_init_add:
  UPDATE mysql.proc SET definer = 'root@localhost'; FLUSH TABLES; FLUSH PRIVILEGES; 

query_add:
  infoschema_query { $last_database= undef; $last_table= undef; '' } ;

infoschema_query:
  ==FACTOR:10== { @nonaggregates = () ; @table_names = () ; @database_names = () ; $tables = 0 ; $fields = 0 ; "" } infoschema_select_or_select_join |
  infoschema_show ;

infoschema_select_or_select_join:
  infoschema_select |
  infoschema_select_join ;

infoschema_show:
#  SHOW BINARY LOGS |
  SHOW BINLOG EVENTS |  
  SHOW CHARACTER SET  |
  SHOW COLLATION  |
  SHOW COLUMNS FROM _table |
  SHOW CREATE DATABASE  _letter |
  SHOW CREATE FUNCTION  _letter |
  SHOW CREATE PROCEDURE _letter |
  SHOW CREATE TABLE _letter |
  SHOW CREATE VIEW  _letter |
  SHOW DATABASES  |
#  SHOW ENGINE  |
  SHOW ENGINES  |
  SHOW ERRORS  |
  SHOW FUNCTION CODE _letter |
  SHOW FUNCTION STATUS | 
  SHOW GRANTS  |
  SHOW INDEX FROM _table |
#  SHOW INNODB STATUS  |
#  SHOW LOGS  |
  SHOW MASTER STATUS  |
#  SHOW MUTEX STATUS  |
  SHOW OPEN TABLES  |
  SHOW PRIVILEGES  |
  SHOW PROCEDURE CODE _letter |
  SHOW PROCEDURE STATUS | 
  SHOW PROCESSLIST  |
  SHOW PROFILE  |
  SHOW PROFILES  |
  SHOW SLAVE HOSTS  |
  SHOW SLAVE STATUS  |
  SHOW STATUS  |
  SHOW TABLE STATUS  |
  SHOW TABLES  |
  SHOW TRIGGERS | 
  SHOW VARIABLES | 
  SHOW WARNINGS ;  

infoschema_select:
  SELECT *
  FROM infoschema_new_table_item
  infoschema_where
  infoschema_group_by
  infoschema_having
  infoschema_order_by_limit
;

infoschema_select_join :
  SELECT *
  FROM infoschema_join_list
  infoschema_where
  infoschema_group_by
  infoschema_having
  LIMIT _digit
;

infoschema_select_list:
  infoschema_new_select_item |
  infoschema_new_select_item , infoschema_select_list ;

infoschema_join_list:
  infoschema_new_table_item |
  (infoschema_new_table_item infoschema_join_type infoschema_new_table_item ON ( infoschema_current_table_item . _field = infoschema_previous_table_item . _field ) ) ;

infoschema_join_type:
  INNER JOIN | _basics_left_right _basics_outer_50pct JOIN | STRAIGHT_JOIN ;  

infoschema_where:
  WHERE infoschema_where_list ;

infoschema_where_list:
  not infoschema_where_item |
  not (infoschema_where_list AND infoschema_where_item) |
  not (infoschema_where_list OR infoschema_where_item) ;

infoschema_where_item:
  infoschema_existing_table_item . _field infoschema_sign infoschema_value |
  infoschema_existing_table_item . _field infoschema_sign infoschema_existing_table_item . _field ;

infoschema_group_by:
  { scalar(@nonaggregates) > 0 ? " GROUP BY ".join (', ' , @nonaggregates ) : "" };

infoschema_having:
  | HAVING infoschema_having_list;

infoschema_having_list:
  _basics_not_33pct infoschema_having_item |
  _basics_not_33pct (infoschema_having_list AND infoschema_having_item) |
  _basics_not_33pct (infoschema_having_list OR infoschema_having_item) |
  infoschema_having_item IS _basics_not_33pct NULL ;

infoschema_having_item:
  infoschema_existing_table_item . _field infoschema_sign infoschema_value ;

infoschema_order_by_limit:
  |
  ORDER BY infoschema_order_by_list |
  ORDER BY infoschema_order_by_list LIMIT _digit ;

infoschema_order_by_list:
  infoschema_order_by_item |
  infoschema_order_by_item , infoschema_order_by_list ;

infoschema_order_by_item:
  infoschema_existing_table_item . _field ;

infoschema_new_select_item:
  infoschema_nonaggregate_select_item |
  infoschema_nonaggregate_select_item |
  infoschema_aggregate_select_item;

infoschema_nonaggregate_select_item:
  infoschema_table_one_two . _field AS { my $f = "field".++$fields ; push @nonaggregates , $f ; $f} ;

infoschema_aggregate_select_item:
  infoschema_aggregate infoschema_table_one_two . _field ) AS { "field".++$fields };

# Only 20% table2, since sometimes table2 is not present at all

infoschema_table_one_two:
  table1 { $last_table = $tables[1] } | 
  table2 { $last_table = $tables[2] } ;

infoschema_aggregate:
  COUNT( | SUM( | MIN( | MAX( ;

infoschema_new_table_item:
  infoschema_database . _table AS { $database_names[++$tables] = $last_database ; $table_names[$tables] = $last_table ; "table".$tables };

infoschema_database:
  { $last_database = $prng->arrayElement(['mysql','INFORMATION_SCHEMA','test']); return $last_database };

infoschema_current_table_item:
  { $last_database = $database_names[$tables] ; $last_table = $table_names[$tables] ; "table".$tables };

infoschema_previous_table_item:
  { $last_database = $database_names[$tables-1] ; $last_table = $table_names[$tables-1] ; "table".($tables - 1) };

infoschema_existing_table_item:
  { my $i = $prng->int(1,$tables) ; $last_database = $database_names[$i]; $last_table = $table_names[$i] ; "table".$i };

infoschema_sign:
  = | > | < | != | <> | <= | >= ;
  
infoschema_value:
  _digit | _char(2) | _datetime ;
