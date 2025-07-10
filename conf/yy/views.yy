# Copyright (c) 2010, 2012, Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2022, 2025 MariaDB
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
# This grammar creates random chains of possibly updateable views
# and tries to execute DML queries against them. The following princples apply:
########################################################################

query_init:
    { $view_no= 0; '' }
    SET DEFAULT ROLE admin ;; SET ROLE admin
  ;; CREATE DATABASE IF NOT EXISTS views_db
  # Because of MDEV-30999 it is not enough to use the role here
  # and PS is a workaround for MDEV-30190
  ;; EXECUTE IMMEDIATE CONCAT('GRANT ALL ON views_db.* TO ',CURRENT_USER,' WITH GRANT OPTION')
  ;; { _set_db('NON-SYSTEM') }
  ;; create_new_view_with_basetable
  ;; create_new_view_with_basetable
  ;; create_new_view_with_basetable
;

query:
  { $view_to_create= 0; _set_db('views_db') } upd_views_query ;

upd_views_query:
  ==FACTOR:20==  dml |
                 ddl |
  ==FACTOR:0.1== TRUNCATE _basetable
;

dml:
  ==FACTOR:2== select |
  ==FACTOR:2== insert |
               update |
               delete ;

ddl:
  create_or_replace |
  create_if_not_exists |
  { _set_db('NON-SYSTEM') } create_new_view_with_basetable ;

# OR REPLACE is just in case here, there should be no existing tables or views
# with the same name
create_new_view_with_basetable:
     CREATE OR REPLACE TABLE views_db.{'basetable_'.abs($$).'_'.(++$view_no)} LIKE _basetable
  ;; CREATE OR REPLACE optional_algorithm VIEW views_db.{'view_'.abs($$).'_'.$view_no} AS SELECT * FROM views_db.{'basetable_'.abs($$).'_'.$view_no}
;

view_to_create:
  _view | {'view_'.abs($$).'_'.$view_no} ;

create_if_not_exists:
  CREATE optional_algorithm VIEW __if_not_exists(95) view_to_create AS select_for_create check_option ;

create_or_replace:
  CREATE __or_replace(95) optional_algorithm VIEW view_to_create AS select_for_create check_option ;

field_list_with_names:
               _field AS { 'field'.(++$fno) } |
  ==FACTOR:2== _field AS { 'field'.(++$fno) }, field_list_with_names ;

aggregate_column:
  MAX(_field) | COUNT(_field) | GROUP_CONCAT(_field) ;

select_for_create:
  ==FACTOR:9== /* _table[invariant] */ { $fno=0 ; '' } SELECT field_list_with_names FROM _table[invariant] where |
  ==FACTOR:3== /* _table[invariant] */ { $fno=0 ; '' } SELECT aggregate_column AS field0, field_list_with_names FROM _table[invariant] where GROUP BY field0 |
               ( select_for_create[invariant] ) __union_x_except_x_intersect ( select_for_create[invariant] ) ;

select:
  /* _view[invariant] */ SELECT field_list_with_names FROM _view[invariant] where |
  /* _view[invariant] */ SELECT v1._field[invariant] FROM _view AS v1[invariant] __left_x_right(30,10) JOIN _view v2 ON (v1._field[invariant] cmp_op v2._field) ORDER BY 1 LIMIT _digit
;

insert:
  insert_single | insert_select |
  insert_multi | insert_multi ;

insert_single:
  insert_replace INTO _view SET value_list ;

insert_multi:
  insert_replace INTO _view ( _field, _field ) VALUES row_list;

insert_select:
  insert_replace INTO _view (_field) SELECT /* _table[invariant] */ _field FROM _table[invariant] ORDER BY _field LIMIT _digit ;

update:
  UPDATE __ignore(95) _view SET value_list where ORDER BY _field limit ;

limit:
  | LIMIT _digit ;

delete:
  DELETE FROM _view where ORDER BY _field LIMIT _digit ;

insert_replace:
  INSERT IGNORE | REPLACE ;

value_list:
  value_list , value_item |
  value_item , value_item ;

row_list:
  row_list , row_item |
  row_item , row_item ;

row_item:
  ( value , value );

value_item:
  _field = value ;

where:
  |
  WHERE _field cmp_op value ;

value:
  _digit | _tinyint_unsigned | _varchar(1) | _english | NULL ;

cmp_op:
  = | > | < | >= | <= | <> | != | <=> ;

check_option:
  | | | | WITH cascaded_local CHECK OPTION;

cascaded_local:
  CASCADED | LOCAL ;

optional_algorithm:
  ==FACTOR:5== |
  ALGORITHM = algorithm
;

algorithm:
  ==FACTOR:30== MERGE |
                TEMPTABLE |
                UNDEFINED
;
