query:
    seq_create
  | seq_alter
  | seq_drop
  | seq_rename
;

seq_rename:
  RENAME TABLE seq_rename_list
;

seq_rename_list:
  seq_name TO seq_name | seq_rename_list, seq_name TO seq_name
;

seq_drop:
  DROP SEQUENCE seq_if_exists_optional seq_drop_list
;

seq_drop_list:
  seq_name | seq_name | seq_name, seq_drop_list
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

# Due to MDEV-14761, cannot have more than one MINVALUE / MAXVALUE
seq_alter_element:
    RESTART seq_with_or_equal_optional seq_start_value 
  | seq_increment
  | seq_min_if_not_defined
  | seq_max_if_not_defined
  | seq_start_with
;

seq_create:
  CREATE seq_or_replace_if_not_exists seq_name seq_start_with_optional seq_min_optional seq_max_optional seq_increment_optional seq_cache_optional seq_cycle_optional seq_engine
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
  ENGINE=MyISAM | ENGINE=Aria
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

seq_or_replace_if_not_exists:
  SEQUENCE | OR REPLACE SEQUENCE | SEQUENCE IF NOT EXISTS
;

seq_name:
  { 'seq'.$prng->int(1,10) }
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
