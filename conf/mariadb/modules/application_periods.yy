#  Copyright (c) 2019, MariaDB
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


########################################################################
# Application periods (10.4+),
# MDEV-16973, MDEV-16974, MDEV-16975, MDEV-17082
#
# Can be used as a standalone or redefining grammar.
#
# ATTENTION:
# It assumes the use of basics.yy as a redefining grammar for primitives.
#
# Specifics:
# Some statements produce syntax errors on purpose, to cover changes in
# sql_yacc*.yy
#
########################################################################

query_init_add:
  { $max_cols= 0; '' }
  ; { $tname= 't1'; '' } app_periods_init_create
  ; { $tname= 't2'; '' } app_periods_init_create
  ; { $tname= 't3'; '' } app_periods_init_create
  ; { $tname= 't4'; '' } app_periods_init_create
  ; { $tname= 't5'; '' } app_periods_init_create
  ; { $tname= 't6'; '' } app_periods_init_create
  ; { $tname= 't7'; '' } app_periods_init_create
  ; { $tname= 't8'; '' } app_periods_init_create
  ; { $tname= 't9'; '' } app_periods_init_create
  ; { $tname= 't10'; '' } app_periods_init_create
  ; { $tname= 'ts1'; '' } app_periods_init_create_preversioned
  ; { $tname= 'ts2'; '' } app_periods_init_create_preversioned
  ; { $tname= 'ts3'; '' } app_periods_init_create_preversioned
  ; { $tname= 'ts4'; '' } app_periods_init_create_preversioned
  ; { $tname= 'ts5'; '' } app_periods_init_create_preversioned
  ; { $tname= 'ts6'; '' } app_periods_init_create_preversioned
  ; { $tname= 'ts7'; '' } app_periods_init_create_preversioned
  ; { $tname= 'ts8'; '' } app_periods_init_create_preversioned
  ; { $tname= 'ts9'; '' } app_periods_init_create_preversioned
  ; { $tname= 'ts10'; '' } app_periods_init_create_preversioned
  ; SET system_versioning_alter_history=KEEP
;

query_add:
  app_periods_query ;

app_periods_init_create:
  CREATE TABLE IF NOT EXISTS { @cols= (); $inds= 1; $periods= 0; $periodtype= 'DATE'; $last_table= $tname } ( app_periods_table_elements ) _basics_main_engine_clause_50pct _basics_table_options app_periods_partitioning_definition { $max_cols= scalar(@cols) if scalar(@cols) > $max_cols; @cols= (); '' } ;

app_periods_init_create_preversioned:
  CREATE TABLE IF NOT EXISTS { @cols= (); $inds= 1; $periods= 0; $periodtype= 'DATE'; $last_table= $tname } ( app_periods_preversioned_table_elements ) _basics_main_engine_clause_50pct _basics_table_options app_periods_partitioning_definition { $max_cols= scalar(@cols) if scalar(@cols) > $max_cols; @cols= (); '' } ;

app_periods_query:
# Main functionality
  app_periods_create | app_periods_create | app_periods_create |
  app_periods_alter | app_periods_alter |
  app_periods_delete_portion | app_periods_delete_portion | app_periods_delete_portion |
  app_periods_update_portion | app_periods_update_portion | app_periods_update_portion |
  app_periods_update_portion | app_periods_update_portion | app_periods_update_portion |
  app_periods_select | app_periods_select | app_periods_select |
# Extra statements for coverage
  app_periods_admin_table |
  app_periods_alter; SHOW CREATE TABLE { $last_table } ; app_periods_select |
  app_periods_insert | app_periods_insert | app_periods_insert | app_periods_insert | app_periods_insert | app_periods_insert |
  app_periods_delete_data |
  app_periods_triggers |
#  app_periods_set_sql_mode |
  app_periods_create_view
;

app_periods_create:
  { @cols= (); $inds= 1; $periods= 0; $periodtype= 'DATE'; '' }  app_periods_create_table { $max_cols= scalar(@cols) if scalar(@cols) > $max_cols; @cols= (); '' } ;

app_periods_create_table:
  _basics_create_table_clause app_periods_nonstrict_table_name ( app_periods_table_elements ) _basics_main_engine_clause_50pct _basics_table_options app_periods_partitioning_definition |
  { @cols= (); $inds= 1; $periods= 0; $periodtype= 'DATE'; '' } _basics_create_table_clause app_periods_strict_preversioned_table_name ( app_periods_preversioned_table_elements ) _basics_main_engine_clause_50pct _basics_table_options app_periods_partitioning_definition |
  _basics_create_table_clause app_periods_nonstrict_table_name LIKE app_periods_nonstrict_table_name |
  _basics_create_table_clause app_periods_strict_preversioned_table_name LIKE app_periods_strict_preversioned_table_name
;

app_periods_create_view:
  CREATE OR REPLACE _basics_view_algorithm_50pct VIEW app_periods_view_name AS SELECT * FROM app_periods_table |
  CREATE OR REPLACE _basics_view_algorithm_50pct VIEW app_periods_view_name AS SELECT * FROM app_periods_table FOR SYSTEM_TIME ALL |
  CREATE OR REPLACE _basics_view_algorithm_50pct VIEW app_periods_view_name AS SELECT * FROM app_periods_table alias1 NATURAL JOIN app_periods_table alias2
;

app_periods_admin_table:
  SHOW CREATE TABLE app_periods_table |
  DESCRIBE app_periods_table |
  SHOW INDEX IN app_periods_table |
  SHOW TABLE STATUS |
  ANALYZE TABLE app_periods_table |
  FLUSH TABLES |
  CHECK TABLE app_periods_table EXTENDED
;

app_periods_select:
  _basics_explain_analyze_5pct SELECT * FROM app_periods_table app_periods_for_system_time_clause |
  _basics_explain_analyze_5pct SELECT COUNT(*) FROM app_periods_table app_periods_for_system_time_clause |
  _basics_explain_analyze_5pct SELECT * FROM app_periods_strict_preversioned_table_name app_periods_for_system_time_clause WHERE `from` BETWEEN CURDATE() AND DATE_ADD(CURDATE(), app_periods_interval) |
  _basics_explain_analyze_5pct SELECT MAX(`from`), MIN(`to`) FROM app_periods_strict_preversioned_table_name app_periods_for_system_time_clause
;

app_periods_for_system_time_clause:
  | | | | | | | | | | | | | | | | | | | FOR SYSTEM_TIME app_periods_system_time_condition ;

app_periods_system_time_condition:
  ALL | ALL | ALL | ALL |
  AS OF CURRENT_TIMESTAMP |
  AS OF _smallint_unsigned |
  BETWEEN CURRENT_TIMESTAMP AND DATE_ADD(CURRENT_TIMESTAMP, app_periods_interval) |
  BETWEEN _smallint_unsigned AND _smallint_unsigned + _smallint_unsigned |
  FROM CURRENT_TIMESTAMP TO DATE_ADD(CURRENT_TIMESTAMP, app_periods_interval) |
  FROM _smallint_unsigned TO _smallint_unsigned + _smallint_unsigned
;

app_periods_insert:
  _basics_insert_ignore_replace_clause INTO app_periods_table () VALUES (),(),(),() |
  # 157680000 seconds is 5 years
  _basics_insert_ignore_replace_clause INTO app_periods_strict_preversioned_table_name (`from`,`to`) VALUES ({ $tm = time + $prng->int(-157680000,157680000); '' } app_periods_period_boundary_literal, { $tm = $tm + $prng->int(-0,157680000); '' } app_periods_period_boundary_literal) |
  _basics_insert_ignore_replace_clause app_periods_table SELECT * FROM { $last_table } _basics_order_by_limit_50pct |
  INSERT INTO app_periods_strict_preversioned_table_name SELECT * FROM { $last_table } _basics_order_by_limit_50pct ON DUPLICATE KEY UPDATE `from` = DATE_SUB(CURDATE(), INTERVAL _digit DAY), `to` = DATE_ADD(CURDATE(), INTERVAL _digit DAY)
;

app_periods_interval:
  INTERVAL _digit _basics_big_interval |
  INTERVAL _smallint_unsigned _basics_small_interval
;

app_periods_delete_data:
  app_periods_single_row_delete | app_periods_single_row_delete | app_periods_single_row_delete | app_periods_single_row_delete | app_periods_single_row_delete |
  app_periods_single_row_delete | app_periods_single_row_delete | app_periods_single_row_delete | app_periods_single_row_delete | app_periods_single_row_delete |
  app_periods_truncate |
  app_periods_delete_history
;

app_periods_truncate:
  TRUNCATE TABLE app_periods_table |
  DELETE FROM app_periods_table
;

app_periods_single_row_delete:
  DELETE FROM app_periods_table ORDER BY RAND() LIMIT 1 ;

app_periods_delete_history:
  DELETE HISTORY FROM app_periods_table app_periods_before_system_time ;

app_periods_before_system_time:
  | BEFORE SYSTEM_TIME NOW() ;

app_periods_table:
  app_periods_nonstrict_table_name | app_periods_nonstrict_table_name | app_periods_nonstrict_table_name | app_periods_nonstrict_table_name |
  app_periods_nonstrict_table_name | app_periods_nonstrict_table_name | app_periods_nonstrict_table_name | app_periods_nonstrict_table_name |
  app_periods_nonstrict_table_name | app_periods_nonstrict_table_name | app_periods_nonstrict_table_name | app_periods_nonstrict_table_name |
  app_periods_strict_preversioned_table_name | app_periods_strict_preversioned_table_name | app_periods_strict_preversioned_table_name | app_periods_strict_preversioned_table_name |
  app_periods_strict_preversioned_table_name | app_periods_strict_preversioned_table_name | app_periods_strict_preversioned_table_name | app_periods_strict_preversioned_table_name |
  app_periods_strict_preversioned_table_name | app_periods_strict_preversioned_table_name | app_periods_strict_preversioned_table_name | app_periods_strict_preversioned_table_name |
  app_periods_view_name
;

app_periods_view_name:
  { $last_table = 'v'.$prng->int(1,10) } ;

app_periods_nonstrict_table_name:
  { $last_table = 't'.$prng->int(1,10) } ;

app_periods_strict_preversioned_table_name:
  { $last_table = 'ts'.$prng->int(1,10) } ;

app_periods_table_elements:
  app_periods_column_definition | app_periods_table_elements, app_periods_table_element | app_periods_table_element, app_periods_table_elements ;

app_periods_preversioned_table_elements:
  app_periods_period_definition_strict | app_periods_period_definition_strict |
  app_periods_column_definition, app_periods_preversioned_table_elements |
  app_periods_column_definition, app_periods_preversioned_table_elements |
  app_periods_column_definition, app_periods_preversioned_table_elements |
  app_periods_preversioned_table_elements, app_periods_column_definition |
  app_periods_preversioned_table_elements, app_periods_column_definition |
  app_periods_preversioned_table_elements, app_periods_column_definition |
  app_periods_table_element, app_periods_preversioned_table_elements, app_periods_column_definition |
  app_periods_column_definition, app_periods_preversioned_table_elements, app_periods_table_element
;

app_periods_table_element:
  app_periods_column_definition | app_periods_column_definition | app_periods_column_definition |
  app_periods_column_definition | app_periods_column_definition | app_periods_column_definition |
  app_periods_period_definition_random | app_periods_period_definition_random | app_periods_period_definition_random |
  app_periods_index_definition |
  app_periods_constraint_definition
;

app_periods_column_definition:
  app_periods_new_column_name _basics_column_specification ;

app_periods_new_column_name:
  { $last_field= 'c'.(scalar(@cols)+1); push @cols, $last_field; '`'.$last_field.'`' } ;

app_periods_existing_column_name:
  { $last_field= scalar(@cols) ? $prng->arrayElement(\@cols) : 'c'.$prng->int(1,$max_cols); '`'.$last_field.'`' } ;

app_periods_random_column_name:
  { $last_field= ( $prng->int(0,10) ? ( $prng->int(0,10) ? 'c'.$prng->int(1,$max_cols) : 'to' ) : 'from' ); '`'.$last_field.'`' } ;

app_periods_existing_column_list:
  app_periods_existing_column_name | app_periods_existing_column_name | app_periods_existing_column_name | app_periods_existing_column_name, app_periods_existing_column_list ;

app_periods_period_name:
  app_periods_valid_period_name | app_periods_valid_period_name | app_periods_valid_period_name |
  app_periods_valid_period_name | app_periods_valid_period_name | app_periods_valid_period_name |
  app_periods_valid_period_name | app_periods_valid_period_name | app_periods_valid_period_name |
  app_periods_valid_period_name | app_periods_valid_period_name | app_periods_valid_period_name |
  app_periods_valid_period_name | app_periods_valid_period_name | app_periods_valid_period_name |
  app_periods_valid_period_name | app_periods_valid_period_name | app_periods_valid_period_name |
  app_periods_valid_period_name | app_periods_valid_period_name | app_periods_valid_period_name |
  app_periods_valid_period_name | app_periods_valid_period_name | app_periods_valid_period_name |
  app_periods_valid_period_name | app_periods_valid_period_name | app_periods_valid_period_name |
  app_periods_valid_period_name | app_periods_valid_period_name | app_periods_valid_period_name |
  app_periods_invalid_period_name
;

# TODO: '``' disabled due to MDEV-18873
app_periods_valid_period_name:
  { $last_period_name= $prng->arrayElement(['app','app','app','app','app','app','app','app','app','app','A','period']) } ;

# This will cause syntax errors, intentionally
app_periods_invalid_period_name:
  | SYSTEM_TIME | system_time | `system_time` | `SYSTEM_TIME` ;

app_periods_period_definition_fixed:
  { push @cols, 'from'; '' } `from` app_periods_period_type { $last_column_type= $periodtype; '' } _basics_column_attributes, { push @cols, 'to'; '' } `to` { $last_column_type } _basics_column_attributes, { $periods++ ? 'KEY' : 'PERIOD FOR ' } `app`(`from`, `to`) ;

app_periods_period_definition_fixed_with_random_temporal_types:
  { push @cols, 'from'; '' } `from` app_periods_period_type { $last_column_type= $periodtype; '' } _basics_column_attributes, { push @cols, 'to'; '' } `to` app_periods_period_type { $last_column_type= $periodtype; '' } _basics_column_attributes, { $periods++ ? 'KEY' : 'PERIOD FOR ' } `app`(`from`, `to`) ;

app_periods_period_definition_fixed_with_virtual_columns:
  app_periods_period_definition_fixed, { push @cols, 'vfrom'; '' } `vfrom` { $periodtype } GENERATED ALWAYS AS (`from`) _basics_stored_or_virtual, { push @cols, 'vto'; '' } `vto` { $periodtype } GENERATED ALWAYS AS  (`to`) _basics_stored_or_virtual;

app_periods_period_definition_strict:
  app_periods_period_definition_fixed | app_periods_period_definition_fixed |
  app_periods_period_definition_fixed | app_periods_period_definition_fixed |
  app_periods_period_definition_fixed | app_periods_period_definition_fixed |
  app_periods_period_definition_fixed | app_periods_period_definition_fixed |
  app_periods_period_definition_fixed_with_virtual_columns |
  app_periods_period_definition_fixed_with_random_temporal_types
;

app_periods_period_definition_random:
 { $periods++ ? 'KEY' : 'PERIOD FOR ' } app_periods_period_name ( app_periods_existing_column_name, app_periods_existing_column_name ) ;

app_periods_new_index_name_optional:
  | { $last_index_name= 'ind'.$inds++ } ;

app_periods_index_definition:
  KEY app_periods_new_index_name_optional (app_periods_existing_column_list) ;

app_periods_constraint_definition:
  app_periods_unique_key | app_periods_unique_key | app_periods_unique_key | app_periods_unique_key |
  app_periods_primary_key |
  app_periods_foreign_key |
  _basics_simple_check_constraint | _basics_simple_check_constraint | _basics_simple_check_constraint | _basics_simple_check_constraint
;

app_periods_unique_key:
  UNIQUE app_periods_new_index_name_optional (app_periods_existing_column_list) ;

app_periods_primary_key:
  PRIMARY KEY (app_periods_existing_column_list) ;

app_periods_foreign_key:
  CONSTRAINT app_periods_new_index_name_optional FOREIGN KEY (app_periods_random_column_name) REFERENCES app_periods_table (app_periods_random_column_name) ;

app_periods_alter:
  ALTER TABLE app_periods_table app_periods_alter_table_list ;

app_periods_alter_table_list:
  app_periods_alter_table_element | app_periods_alter_table_element | app_periods_alter_table_element |
  app_periods_alter_table_element, app_periods_alter_table_list
;

app_periods_alter_table_element:
# Main functionality
  app_periods_add_period | app_periods_add_period | app_periods_add_period | app_periods_add_period |
  app_periods_add_period | app_periods_add_period | app_periods_add_period | app_periods_add_period |
  app_periods_drop_period | app_periods_drop_period | app_periods_drop_period | app_periods_drop_period |
  app_periods_add_drop_column |
# Extra statements for coverage
  app_periods_system_versioning |
  app_periods_change_modify_column |
  _basics_alter_table_element
;

app_periods_add_drop_column:
  ADD _basics_if_not_exists_95pct app_periods_column_definition |
  ADD _basics_if_not_exists_95pct app_periods_column_definition |
  DROP _basics_if_exists_95pct app_periods_random_column_name
;

app_periods_change_modify_column:
  MODIFY _basics_if_exists_95pct app_periods_random_column_name  _basics_column_specification |
  CHANGE _basics_if_exists_95pct app_periods_random_column_name app_periods_random_column_name _basics_column_specification
;

app_periods_system_versioning:
  ADD COLUMN `row_start` TIMESTAMP(6) AS ROW START, ADD COLUMN `row_end` TIMESTAMP(6) AS ROW END, ADD PERIOD FOR SYSTEM_TIME(`row_start`,`row_end`), WITH SYSTEM VERSIONING |
  ADD COLUMN `row_start` BIGINT UNSIGNED AS ROW START, ADD COLUMN `row_end` BIGINT UNSIGNED AS ROW END, ADD PERIOD FOR SYSTEM_TIME(`row_start`,`row_end`), WITH SYSTEM VERSIONING |
  WITH SYSTEM VERSIONING |
  DROP IF EXISTS `row_start`, DROP IF EXISTS `row_end`, DROP PERIOD FOR SYSTEM_TIME, DROP SYSTEM VERSIONING |
  DROP SYSTEM VERSIONING
;

app_periods_add_period:
  ADD PERIOD _basics_if_not_exists_95pct FOR app_periods_period_name ( app_periods_existing_column_name, app_periods_existing_column_name ) ;

app_periods_drop_period:
  DROP PERIOD _basics_if_exists_95pct FOR app_periods_nonstrict_table_name ;

app_periods_delete_portion:
  # Random
  _basics_explain_analyze_5pct DELETE _basics_ignore_80pct FROM app_periods_table app_periods_portion app_periods_optional_where_clause ORDER BY app_periods_existing_column_name _basics_limit_50pct |
  # Specific
  app_periods_get_valid_boundaries ; _basics_explain_analyze_5pct DELETE _basics_ignore_80pct FROM { $last_table } app_periods_exact_portion app_periods_optional_order_by_clause _basics_limit_50pct
;

app_periods_portion:
  FOR PORTION OF app_periods_period_name FROM app_periods_time_value TO app_periods_time_value |
  # 31536000 seconds is 1 year
  FOR PORTION OF `app` FROM { $tm = time + $prng->int(-31536000,31536000); '' } app_periods_period_boundary_literal TO { $tm = $tm + $prng->int(0,31536000); '' } app_periods_period_boundary_literal |
  # 86400 seconds is 1 day
  FOR PORTION OF `app` FROM { $tm = time + $prng->int(-86400,86400); '' } app_periods_period_boundary_literal TO { $tm = $tm + $prng->int(0,86400); '' } app_periods_period_boundary_literal
;

app_periods_optional_where_clause:
  | | WHERE app_periods_existing_column_name BETWEEN app_periods_time_value AND app_periods_time_value ;


app_periods_get_valid_boundaries:
  SELECT `from`, `to` INTO @tm1, @tm2 FROM app_periods_strict_preversioned_table_name ORDER BY `from` LIMIT 1 ;

# The rules below assume using the previous one, which sets @tm1, @tm2
app_periods_exact_portion:
  app_periods_for_portion_covering_whole_period |
  app_periods_for_portion_overlapping_left_border |
  app_periods_for_portion_overlapping_right_border |
  app_periods_for_portion_within_whole_period |
  app_periods_for_portion_identical_to_period
;

app_periods_for_portion_covering_whole_period:
  FOR PORTION OF `app` FROM DATE_SUB(@tm1, app_periods_interval) TO DATE_ADD(@tm2, app_periods_interval) ;

app_periods_for_portion_overlapping_left_border:
  FOR PORTION OF `app` FROM DATE_SUB(@tm1, app_periods_interval) TO DATE_SUB(@tm2, app_periods_interval) ;

app_periods_for_portion_overlapping_right_border:
  FOR PORTION OF `app` FROM DATE_ADD(@tm1, app_periods_interval) TO DATE_ADD(@tm2, app_periods_interval) ;

app_periods_for_portion_within_whole_period:
  FOR PORTION OF `app` FROM DATE_ADD(@tm1, app_periods_interval) TO DATE_SUB(@tm2, app_periods_interval) ;

app_periods_for_portion_identical_to_period:
  FOR PORTION OF `app` FROM @tm1 TO @tm2 ;


app_periods_update_portion:
  # Random
  _basics_explain_analyze_5pct UPDATE _basics_ignore_80pct app_periods_table app_periods_portion SET app_periods_update_list app_periods_optional_where_clause app_periods_optional_order_by_clause _basics_limit_50pct |
  # Specific
  app_periods_get_valid_boundaries ; _basics_explain_analyze_5pct UPDATE _basics_ignore_80pct { $last_table } app_periods_exact_portion SET app_periods_update_list app_periods_optional_order_by_clause _basics_limit_50pct
;

app_periods_optional_order_by_clause:
  | | | ORDER BY app_periods_existing_column_list ;
  
app_periods_update_list:
  app_periods_existing_column_name = app_periods_time_value |
  app_periods_existing_column_name = app_periods_time_value |
  app_periods_existing_column_name = app_periods_time_value |
  app_periods_random_column_name = app_periods_time_value |
  app_periods_update_list , app_periods_existing_column_name = app_periods_time_value
;

app_periods_period_type:
  { $periodtype= $prng->arrayElement(['TIMESTAMP','TIMESTAMP(1)','TIMESTAMP(2)','TIMESTAMP(3)','TIMESTAMP(4)','TIMESTAMP(5)','TIMESTAMP(6)','DATETIME','DATETIME(1)','DATETIME(2)','DATETIME(3)','DATETIME(4)','DATETIME(5)','DATETIME(6)','DATE']) }
;

app_periods_period_boundary_literal:
  app_periods_make_timestamp | app_periods_make_date ;

app_periods_make_timestamp:
  { $tm = time unless defined $tm; use POSIX; "'".strftime("%Y-%m-%d %H:%M:%S",localtime($tm))."'" } ;

app_periods_make_date:
  { $tm = time unless defined $tm; use POSIX; "'".strftime("%Y-%m-%d",localtime($tm))."'" } ;

app_periods_time_value:
  _timestamp | _date |
  CURRENT_TIMESTAMP + _tinyint |
  CURDATE | SYSDATE() |
  NOW() | NOW(6) |
  DATE_ADD(_timestamp, INTERVAL _positive_digit _basics_interval) |
  DATE_SUB(_timestamp, INTERVAL _positive_digit _basics_interval) |
  DATE_SUB(NOW(), INTERVAL _positive_digit _basics_interval) |
  { $tm = time - $prng->int(-100,100); '' } app_periods_period_boundary_literal |
  @tm | @tm1 | @tm2 |
  app_periods_existing_column_name
;

app_periods_partitioning_definition:
  | | | | | | | | | PARTITION BY _basics_hash_or_key(app_periods_existing_column_name) PARTITIONS _positive_digit ;

app_periods_trigger_name:
  { 'tr'.$prng->int(1,20) } ;

app_periods_trigger_body:
  app_periods_insert | app_periods_insert |
  app_periods_update_portion |
  app_periods_delete_portion |
  app_periods_single_row_delete |
  SET @tm = app_periods_time_value
;

app_periods_triggers:
  _basics_create_trigger_clause app_periods_trigger_name _basics_before_after _basics_trigger_operation ON app_periods_table FOR EACH ROW app_periods_trigger_body |
  _basics_create_trigger_clause app_periods_trigger_name _basics_before_after _basics_trigger_operation ON app_periods_table FOR EACH ROW app_periods_trigger_body |
  DROP TRIGGER _basics_if_exists_95pct app_periods_trigger_name
;

app_periods_set_sql_mode:
  SET SQL_MODE= _basics_sql_mode_list |
  SET SQL_MODE= DEFAULT | SET SQL_MODE= DEFAULT | SET SQL_MODE= DEFAULT | SET SQL_MODE= DEFAULT |
  SET SQL_MODE= ORACLE |
  SET SQL_MODE= @@global.sql_mode
;
