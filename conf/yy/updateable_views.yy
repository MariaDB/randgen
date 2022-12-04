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
# This grammar creates random chains of possibly updateable vies
# and tries to execute DML queries against them. The following princples apply:
#
# * The base tables are defined in an .init file, to have almost identical outside structure but different indexes, internal storage etc.
#
# * Since dropping a view that already participates in a definition is known to be unsafe, we do not use CREATE OR REPLACE and
# we do not DROP individual views. Instead, we periodically drop all views as a block and start creating them again
#
########################################################################

query_init:
  { $my_spec_file= "data/sql/updateable_views.sql"
    ; if (open(CONF, $my_spec_file)) {
        read(CONF, my $spec_text, -s $my_spec_file)
        ; close(CONF)
        ; $spec_text
      } else { print "ERROR: Could not load data from $my_spec_file: $!, proceeding without it\n" }
  }
  ;; { _set_db('updateable_views_db') }
     create_with_redundancy
  # This is to prevent other grammars from altering the underlying tables
  ;; GRANT INSERT, UPDATE, DELETE, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, SHOW VIEW ON updateable_views_db.* TO CURRENT_USER
  ;; GRANT ALL ON updateable_views_db.view1 TO CURRENT_USER
  ;; GRANT ALL ON updateable_views_db.view2 TO CURRENT_USER
  ;; GRANT ALL ON updateable_views_db.view3 TO CURRENT_USER
  ;; GRANT ALL ON updateable_views_db.view4 TO CURRENT_USER
  ;; GRANT ALL ON updateable_views_db.view5 TO CURRENT_USER
;

query:
  { _set_db('updateable_views_db') } upd_views_query ;

upd_views_query:
  ==FACTOR:20== dml |
  dml_or_drop
;

dml:
  select | select | insert | insert | update | delete ;

dml_or_drop:
  dml | dml | create_or_replace | create_if_not_exists | drop_all_views | truncate ;

drop_all_views:
  DROP VIEW IF EXISTS view1 , view2 , view3 , view4 , view5 ; create_with_redundancy;

# Since some creation may fail, we can make two attempts for each view
# for better chances that all views are created.
# Since it's "create if not exists" (mostly), the redundancy is reasonably cheap.
# And we also won't use other views while creating, for simplicity.
create_with_redundancy:
    { $base_tables_only=1; '' }
      { $view_to_create= 'view1'; '' } create_if_not_exists ; create_if_not_exists
    ; { $view_to_create= 'view2'; '' } create_if_not_exists ; create_if_not_exists
    ; { $view_to_create= 'view3'; '' } create_if_not_exists ; create_if_not_exists
    ; { $view_to_create= 'view4'; '' } create_if_not_exists ; create_if_not_exists
    ; { $view_to_create= 'view5'; '' } create_if_not_exists ; create_if_not_exists
    { $base_tables_only=0; $view_to_create='' }
;

create_if_not_exists:
  CREATE ALGORITHM = algorithm VIEW __if_not_exists(95) view_name AS select check_option ;

create_or_replace:
  CREATE __or_replace(95) VIEW view_name AS select check_option ;

truncate:
  TRUNCATE TABLE table_name ;

select:
    select_single | select_single | select_single |
    SELECT field1 , field2 , field3 , field4 FROM ( select_single ) AS select1 where |
    # Union view is not updateable
    ==FACTOR:0.05== ( select_single ) UNION ( select_single )
;

select_single:
    SELECT field1 , field2 , field3 , field4 FROM table_view_name where |
    ==FACTOR:0.1== SELECT field1 , min(field2) as field2 , max(field3) as field3 , count(field4) as field4 FROM table_view_name where GROUP BY field1 |
    SELECT a1_2 . field1 AS field1 , a1_2 . field2 AS field2 , a1_2 . field3 AS field3 , a1_2 . field4 AS field4 FROM join where_join |
    SELECT a1_2 . field1 AS field1 , a1_2 . field2 AS field2 , a1_2 . field3 AS field3 , a1_2 . field4 AS field4 FROM comma_join where_comma_join ;

a1_2:
  a1 | a2 ;

join:
  table_view_name AS a1 JOIN table_view_name AS a2 join_condition |
  table_view_name AS a1 STRAIGHT_JOIN table_view_name AS a2 ON join_cond_expr |
  table_view_name AS a1 left_right JOIN table_view_name AS a2 join_condition ;

comma_join:
  table_view_name AS a1 , table_view_name AS a2 ;

join_condition:
  USING ( field_name ) |
  ON join_cond_expr ;

join_cond_expr:
  a1 . field_name cmp_op a2 . field_name ;

left_right:
  LEFT | RIGHT ;

insert:
  insert_single | insert_select |
  insert_multi | insert_multi ;

insert_single:
  insert_replace INTO view_name SET value_list ;

insert_multi:
  insert_replace INTO view_name ( field1 , field2 , field3 , field4 ) VALUES row_list ;

insert_select:
  insert_replace INTO view_name ( field1 , field2 , field3 , field4 ) select ORDER BY field1 , field2 , field3 , field4 LIMIT _digit ;;

update:
  UPDATE view_name SET value_list where ORDER BY field1 , field2 , field3 , field4 limit ;

limit:
  | LIMIT _digit ;

delete:
  DELETE FROM view_name where ORDER BY field1 , field2 , field3 , field4 LIMIT _digit ;

insert_replace:
  INSERT IGNORE | REPLACE ;

value_list:
  value_list , value_item |
  value_item , value_item ;

row_list:
  row_list , row_item |
  row_item , row_item ;

row_item:
  ( value , value , value , value );

value_item:
  field_name = value ;

table_view_name:
    ==FACTOR:3== table_name |
    { $base_tables_only ? 'table_name' : 'view_name' } ;

where:
  |
  WHERE field_name cmp_op value ;

where_join:
  WHERE a1_2 . field_name cmp_op value |
  WHERE a1_2 . field_name cmp_op value and_or a1_2 . field_name cmp_op value ;

where_comma_join:
  WHERE join_cond_expr and_or a1_2 . field_name cmp_op value ;

and_or:
  AND | AND | AND | AND | OR ;

field_name:
  field1 | field2 | field3 | field4 ;

value:
  _digit | _tinyint_unsigned | _varchar(1) | _english | NULL ;

cmp_op:
  = | > | < | >= | <= | <> | != | <=> ;

# Disabled CHECK OPTION for 5.5 due to MDEV-10558
check_option:
  | | | | /*!100012 WITH cascaded_local CHECK OPTION */;

cascaded_local:
  CASCADED | LOCAL ;

table_name:
    table_merge |
    table_merge_child |
    table_multipart |
    table_partitioned |
    table_standard |
    table_virtual
;

view_name:
  { $view_to_create ? $view_to_create : 'view'.$prng->uint16(1,5) };

algorithm:
  MERGE | MERGE | MERGE | MERGE | MERGE |
  MERGE | MERGE | MERGE | TEMPTABLE | UNDEFINED ;
