#  Copyright (c) 2021, 2022, MariaDB Corporation Ab
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

#features sequences, Aria tables

# Error codes to ignore on slave: slave-skip-errors=1049,1305,1539,1505,1317,1568

query_init:
     { _set_db('test') }
     seq_create ;; seq_create ;; seq_create ;; seq_create ;; seq_create
  ;; seq_create ;; seq_create ;; seq_create ;; seq_create ;; seq_create
;

query:
  { _set_db('test') } seq_query ;

seq_query:
    ==FACTOR:2==   seq_create
  |                seq_show
  | ==FACTOR:30==  seq_next_prev_val
  |                seq_alter
  |                seq_set_val
  | ==FACTOR:0.1== seq_drop
  |                seq_select
  |                seq_lock_unlock
  | ==FACTOR:0.5== seq_rename
  |                seq_insert
  | ==FACTOR:0.5== seq_default
;

seq_default:
  { ($s,$t) = @{$prng->arrayElement($executors->[0]->metaBaseTables('NON-SYSTEM'))}; '' } ALTER TABLE { "$s.$t" } MODIFY _field __int_x_bigint DEFAULT(NEXTVAL(test._sequence)) optional_algorithm optional_lock ;

optional_algorithm:
  ==FACTOR:5== |
  , ALGORITHM = __copy_x_nocopy_x_inplace_x_instant_x_default ;

optional_lock:
  ==FACTOR:5== |
  , LOCK = __none_x_shared_x_exclusive ;

seq_lock_unlock:
    LOCK TABLE seq_lock_list
  | ==FACTOR:5== UNLOCK TABLES
;

seq_rename:
  RENAME TABLE seq_rename_list
;

seq_rename_list:
  ==FACTOR:3== _sequence TO seq_name |
  seq_rename_list, _sequence TO seq_name
;

seq_lock_list:
  ==FACTOR:2== _sequence __read_x_write |
  seq_lock_list, __sequence __read_x_write
;

seq_select:
  SELECT seq_select_list FROM _sequence
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
  DROP __temporary(5) SEQUENCE __if_exists(90) seq_drop_list
;

seq_drop_list:
  ==FACTOR:4== _sequence |
  _sequence, seq_drop_list
;

seq_set_val:
  SELECT SETVAL(_sequence, seq_start_value)
;

seq_alter:
  ALTER SEQUENCE __if_exists(90) _sequence seq_alter_list
;

seq_alter_list:
  seq_alter_element | seq_alter_element seq_alter_list
;

seq_insert:
  INSERT INTO _sequence VALUES (seq_start_value, seq_start_value, seq_end_value, seq_start_value, seq_increment_value, _tinyint_unsigned, __0_x_1, __0_x_1)
;

seq_alter_element:
    RESTART seq_with_or_equal_optional seq_start_value
  | seq_increment
  | seq_min
  | seq_max
  | seq_start_with
;

seq_next_prev_val:
    SELECT __next_value_x_previous_value FOR _sequence
  | SELECT __nextval_x_lastval( _sequence )
# Set statement doesn't work here, it throws ER_UNKNOWN_TABLE
  | SET @sql_mode.save= @@sql_mode, @@sql_mode='ORACLE' ;; SELECT _sequence.nextval_or_currval ;; SET @@sql_mode= @sql_mode.save
;

nextval_or_currval:
  nextval | currval;

seq_create:
  CREATE seq_or_replace_if_not_exists seq_name
  seq_start_with_optional
  seq_min_optional
  seq_max_optional
  seq_increment_optional
  seq_cache_optional
  seq_cycle_optional
  seq_engine_optional
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
    SHOW CREATE SEQUENCE _sequence
  | SHOW CREATE TABLE _sequence
  | SHOW TABLES
;

seq_or_replace_if_not_exists:
  __temporary(5) SEQUENCE |
  ==FACTOR:10== OR REPLACE __temporary(5) SEQUENCE |
  __temporary(5) SEQUENCE IF NOT EXISTS
;

seq_name:
  { 'seq'.$prng->int(1,20) }
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
