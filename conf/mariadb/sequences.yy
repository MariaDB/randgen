query_add:
  seq_query
;

seq_query:
    seq_create
  | seq_show
  | seq_next_val
  | seq_prev_val
  | seq_alter
  | seq_set_val
  | seq_drop
  | seq_select
  | seq_lock_unlock
  | seq_rename
  | seq_insert
;

seq_lock_unlock:
    LOCK TABLE seq_lock_list
  | UNLOCK TABLES
  | UNLOCK TABLES
  | UNLOCK TABLES
;

seq_rename:
  RENAME TABLE seq_rename_list
;

seq_rename_list:
  seq_name TO seq_name | seq_rename_list, seq_name TO seq_name
;

seq_lock_list:
  seq_name seq_lock_type | seq_lock_list, seq_name seq_lock_type
;

seq_lock_type:
  READ | WRITE
;

seq_select:
  SELECT seq_select_list FROM seq_name
;

seq_select_list:
  * | seq_select_field_list
;

seq_select_field_list:
    seq_field
  | seq_field, seq_select_field_list
  | seq_field, seq_select_field_list
;

seq_field:
    NEXT_NOT_CACHED_VALUE
  | MINIMUM_VALUE
  | MAXIMUM_VALUE
  | START_VALUE
  | INCREMENT
  | CACHE_SIZE
  | CYCLE_OPTION
  | CYCLE_COUNT
;

seq_drop:
  DROP seq_temporary SEQUENCE seq_if_exists_optional seq_drop_list
;

seq_drop_list:
  seq_name | seq_name | seq_name, seq_drop_list
;

# Due to MDEV-14762, TEMPORARY sequences are disabled
seq_temporary:
#  | | | TEMPORARY
;

seq_set_val:
  SELECT SETVAL(seq_name, seq_start_value)
;

# Due to MDEV-14761, cannot have more than one MINVALUE / MAXVALUE
seq_alter:
  { $min_defined= 0; $max_defined= 0; '' } ALTER SEQUENCE seq_if_exists_optional seq_name seq_alter_list
;

seq_if_exists_optional:
  | IF EXISTS | IF EXISTS | IF EXISTS 
;

seq_alter_list:
  seq_alter_element | seq_alter_element seq_alter_list
;

seq_insert:
  INSERT INTO seq_name VALUES (seq_start_value, seq_start_value, seq_end_value, seq_start_value, seq_increment_value, _tinyint_unsigned, seq_zero_or_one, seq_zero_or_one)
;

# Due to MDEV-14761, cannot have more than one MINVALUE / MAXVALUE
seq_alter_element:
    RESTART seq_with_or_equal_optional seq_start_value 
  | seq_increment
  | seq_min_if_not_defined
  | seq_max_if_not_defined
  | seq_start_with
;

seq_zero_or_one:
  0 | 1
;

seq_next_val:
    SELECT NEXT VALUE FOR seq_name
  | SELECT NEXTVAL( seq_name )
  | SET STATEMENT `sql_mode`=ORACLE FOR SELECT seq_name.nextval
;

seq_prev_val:
    SELECT PREVIOUS VALUE FOR seq_name
  | SELECT LASTVAL( seq_name )
  | SET STATEMENT `sql_mode`=ORACLE FOR SELECT seq_name.currval
;

seq_create:
  CREATE seq_or_replace_if_not_exists seq_name seq_start_with_optional seq_min_optional seq_max_optional seq_increment_optional seq_cache_optional seq_cycle_optional seq_engine_optional
;

seq_cache:
    CACHE _tinyint_unsigned
  | CACHE = _tinyint_unsigned
;

seq_cache_optional:
  | | | seq_cache
;

seq_cycle:
  NOCYCLE | CYCLE
;

seq_cycle_optional:
  | | | seq_cycle
;

seq_engine:
  ENGINE=InnoDB | ENGINE=MyISAM | ENGINE=Aria
;

seq_engine_optional:
  | | | seq_engine
;

# Due to MDEV-14761, cannot have more than one MINVALUE / MAXVALUE

seq_min_if_not_defined:
  { if (! $min_defined) { $min_defined= 1; seq_min } else { '' } }
;

seq_max_if_not_defined:
  { if (! $max_defined) { $max_defined= 1; seq_max } else { '' } }
;

seq_min:
    MINVALUE = seq_start_value
  | MINVALUE seq_start_value
  | NO MINVALUE
  | NOMINVALUE
;

seq_min_optional:
  | | seq_min
;

seq_max:
    MAXVALUE = seq_end_value
  | MAXVALUE seq_end_value
  | NO MAXVALUE
  | NOMAXVALUE
;

seq_max_optional:
  | | seq_max
;

seq_show:
    SHOW CREATE SEQUENCE seq_name
  | SHOW CREATE TABLE seq_name
  | SHOW TABLES
;

seq_or_replace_if_not_exists:
  seq_temporary SEQUENCE | OR REPLACE seq_temporary SEQUENCE | seq_temporary SEQUENCE IF NOT EXISTS
;

seq_name:
  { 'seq'.$prng->int(1,10) }
;

seq_or_table_name:
    seq_name | seq_name | seq_name | seq_name | seq_name | seq_name
  | _table
;

seq_start_with:
    START seq_start_value
  | START seq_with_or_equal_optional seq_start_value
  | START seq_with_or_equal_optional seq_start_value
;

seq_with_or_equal_optional:
  | WITH | =
;

seq_start_with_optional:
  | | | seq_start_with
;

seq_start_value:
  0 | _tinyint | _smallint_unsigned | _bigint
;

seq_end_value:
  0 | _smallint_unsigned | _int_unsigned | _bigint
;

seq_increment:
    INCREMENT BY seq_increment_value
  | INCREMENT = seq_increment_value
  | INCREMENT seq_increment_value
;

seq_increment_optional:
  | | | seq_increment
;

seq_increment_value:
  _positive_digit | _positive_digit | _positive_digit | _tinyint
;
