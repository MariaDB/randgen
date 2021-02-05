#  Copyright (c) 2019, 2021, MariaDB Corporation Ab
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
# Instrumentational grammar to define commonly used clauses,
# both primitive and complicated,
# so that it doesn't have to be done in every grammar
# (unless the grammar needs it to be different from standard)
########################################################################

_basics_inbuilt_engine_weighted:
  { @engines=qw(InnoDB InnoDB InnoDB InnoDB InnoDB InnoDB InnoDB InnoDB MyISAM MyISAM MyISAM MyISAM Aria Aria Aria Aria HEAP HEAP CSV)
    ; $last_table_engine= $prng->arrayElement(\@engines) } ;

_basics_main_engine_weighted:
  { @engines=qw(InnoDB InnoDB InnoDB InnoDB MyISAM MyISAM MyISAM Aria)
    ; $last_table_engine= $prng->arrayElement(\@engines) } ;

_basics_inbuilt_engine_clause_50pct:
  | ENGINE=_basics_inbuilt_engine_weighted ;

_basics_main_engine_clause_50pct:
  | ENGINE=_basics_main_engine_weighted ;

_basics_optional_engine_clause_50pct:
  | _basics_inbuilt_engine_clause ;

_basics_create_table_clause:
  _basics_create_table_clause_with_optional_if_not_exists |
  _basics_create_clause_with_optional_or_replace _basics_temporary_5pct TABLE |
  _basics_create_clause_with_optional_or_replace _basics_temporary_5pct TABLE
;

_basics_create_trigger_clause:
  _basics_create_trigger_clause_with_optional_if_not_exists |
  _basics_create_clause_with_optional_or_replace TRIGGER |
  _basics_create_clause_with_optional_or_replace TRIGGER
;

_basics_insert_ignore_replace_clause:
  INSERT _basics_delayed_5pct _basics_ignore_80pct |
  REPLACE _basics_delayed_5pct | REPLACE _basics_delayed_5pct |
  REPLACE _basics_delayed_5pct | REPLACE _basics_delayed_5pct
;

_basics_delayed_5pct:
  | | | | | | | | | | | | | | | | | | | DELAYED ;

_basics_left_right:
  LEFT | RIGHT ;

_basics_outer_50pct:
  | OUTER ;

_basics_ignore_33pct:
  | | IGNORE ;

_basics_ignore_80pct:
  | IGNORE | IGNORE | IGNORE | IGNORE ;

_basics_replace_80pct:
  | REPLACE | REPLACE | REPLACE | REPLACE ;

_basics_create_table_clause_with_optional_if_not_exists:
  CREATE _basics_temporary_5pct TABLE _basics_if_not_exists_95pct ;

_basics_create_trigger_clause_with_optional_if_not_exists:
  CREATE TRIGGER _basics_if_not_exists_95pct ;

_basics_create_clause_with_optional_or_replace:
  CREATE _basics_or_replace_95pct ;

_basics_if_not_exists_80pct:
  | IF NOT EXISTS | IF NOT EXISTS | IF NOT EXISTS | IF NOT EXISTS ;

_basics_if_not_exists_95pct:
  | IF NOT EXISTS | IF NOT EXISTS | IF NOT EXISTS | IF NOT EXISTS |
  IF NOT EXISTS | IF NOT EXISTS | IF NOT EXISTS | IF NOT EXISTS | IF NOT EXISTS |
  IF NOT EXISTS | IF NOT EXISTS | IF NOT EXISTS | IF NOT EXISTS | IF NOT EXISTS |
  IF NOT EXISTS | IF NOT EXISTS | IF NOT EXISTS | IF NOT EXISTS | IF NOT EXISTS |
;

_basics_global_or_session_optional:
  | GLOBAL | SESSION | SESSION | SESSION ;

_basics_temporary_5pct:
  | | | | | | | | | | | | | | | | | | | TEMPORARY ;

_basics_temporary_50pct:
  | TEMPORARY ;

_basics_if_exists_80pct:
  | IF EXISTS | IF EXISTS | IF EXISTS | IF EXISTS ;

_basics_if_exists_95pct:
  | IF EXISTS | IF EXISTS | IF EXISTS | IF EXISTS |
  IF EXISTS | IF EXISTS | IF EXISTS | IF EXISTS | IF EXISTS |
  IF EXISTS | IF EXISTS | IF EXISTS | IF EXISTS | IF EXISTS |
  IF EXISTS | IF EXISTS | IF EXISTS | IF EXISTS | IF EXISTS |
;

_basics_or_replace_80pct:
  | OR REPLACE | OR REPLACE | OR REPLACE | OR REPLACE ;

_basics_or_replace_95pct:
  | OR REPLACE | OR REPLACE | OR REPLACE | OR REPLACE |
  OR REPLACE | OR REPLACE | OR REPLACE | OR REPLACE | OR REPLACE |
  OR REPLACE | OR REPLACE | OR REPLACE | OR REPLACE | OR REPLACE |
  OR REPLACE | OR REPLACE | OR REPLACE | OR REPLACE | OR REPLACE |
;

_basics_wait_nowait_40pct:
  | | | WAIT _digit | NOWAIT ;

# TODO: add virtual
_basics_column_type:
  _basics_num_column_type | _basics_num_column_type | _basics_num_column_type | _basics_num_column_type |
  _basics_char_column_type | _basics_char_column_type | _basics_char_column_type |
  _basics_temporal_column_type | _basics_temporal_column_type | _basics_temporal_column_type |
  _basics_blob_column_type |
  _basics_special_column_type
;

# TODO: maybe add lengths
_basics_num_column_type:
  { @column_types= qw( TINYINT BOOLEAN SMALLINT MEDIUMINT INT BIGINT DECIMAL FLOAT DOUBLE BIT SERIAL ); $last_column_type= $prng->arrayElement(\@column_types) } ;

_basics_char_column_type:
  { @column_types= ( 'CHAR', 'CHAR('.$prng->int(0,255).')', 'VARCHAR('.$prng->int(0,65535).')', 'VARCHAR('.$prng->int(1,4096).')', 'BINARY', 'BINARY('.$prng->int(0,255).')', 'VARBINARY('.$prng->int(0,65535).')', 'VARBINARY('.$prng->int(1,4096).')' ); $last_column_type= $prng->arrayElement(\@column_types) } ;

_basics_temporal_column_type:
  { @column_types= ( 'TIMESTAMP', 'TIMESTAMP('.$prng->int(0,6).')', 'DATETIME', 'DATETIME('.$prng->int(0,6).')', 'TIME', 'TIME('.$prng->int(0,6).')', 'DATE' ); $last_column_type= $prng->arrayElement(\@column_types) } ;

_basics_blob_column_type:
  { @column_types= qw( TINYBLOB BLOB MEDIUMBLOB LONGBLOB TINYTEXT TEXT MEDIUMTEXT LONGTEXT ); $last_column_type= $prng->arrayElement(\@column_types) } ;

# TODO: add other spatial and what not
_basics_special_column_type:
  { @column_types= ( 'SET(\'\', \'Africa\', \'North America\', \'South America\', \'Asia\', \'Antarctica\', \'Australia\', \'Europe\')', 'ENUM(\'\', \'Africa\', \'North America\', \'South America\', \'Asia\', \'Antarctica\', \'Australia\', \'Europe\')', 'JSON', 'YEAR', 'GEOMETRY', '/*!100500 INET6 *//*!!100500 CHAR(39) */' ); $last_column_type= $prng->arrayElement(\@column_types) } ;

_basics_column_attributes:
  _basics_column_zerofill _basics_base_or_virtual_column_attributes;

# TODO: vcols
_basics_base_or_virtual_column_attributes:
    ==FACTOR:49== _basics_base_column_attributes
#  |               _basics_virtual_column_attributes
;

_basics_base_column_attributes:
  _basics_column_autoincrement _basics_column_nullable _basics_column_default _basics_column_versioning_5pct _basics_column_invisible_5pct _basics_comment_10pct _basics_column_check_constraint_10pct ;

_basics_column_versioning_5pct:
  | | | | | | | | | | | | | | | | | | | /*!100306 _basics_with_without SYSTEM VERSIONING */;

_basics_column_invisible_5pct:
  | | | | | | | | | | | | | | | | | | | /*!100306 INVISIBLE */;

_basics_column_compressed_5pct:
  { if (! $prng->int(0,19) and ($last_column_type =~ /BLOB/ or $last_column_type =~ /TEXT/ or $last_column_type =~ /VARCHAR/ or $last_column_type =~ /VARBINARY/)) { '/*!100302 COMPRESSED */' } } ;

_basics_with_without:
  WITH | WITHOUT ;

_basics_before_after:
  BEFORE | AFTER ;

_basics_trigger_operation:
  INSERT | UPDATE | DELETE ;

_basics_virtual_column_attributes:
  _basics_prepare_type_dependent_value { $last_column_type eq 'SERIAL' ? '' : "GENERATED ALWAYS AS ($last_type_value) ".$prng->arrayElement( [ '', 'PERSISTENT', 'STORED', 'VIRTUAL', 'VIRTUAL' ] ) } ;

_basics_stored_or_virtual:
  | PERSISTENT | STORED | VIRTUAL | VIRTUAL ;

_basics_column_nullable:
  { $last_nullable= ($last_column_type eq 'SERIAL' ? '' : $prng->arrayElement( [ '', 'NULL', 'NOT NULL' ] )) }; 

_basics_prepare_type_dependent_value:
  { $last_type_value= 'NULL'
    ;  if ($last_column_type =~ /INT/) { $last_type_value= 0 }
    elsif ($last_column_type =~ /DOUBLE/ or $last_column_type =~ /FLOAT/) { $last_type_value= 0.0 }
    elsif ($last_column_type =~ /CHAR/ or $last_column_type =~ /BINARY/ or $last_column_type =~ /BLOB/ or $last_column_type =~ /TEXT/ or $last_column_type =~ /SET/ or $last_column_type =~ /ENUM/ or $last_column_type =~ /JSON/) { $last_type_value= "''" }
    elsif ($last_column_type =~ /TIMESTAMP/ or $last_column_type =~ /DATETIME/) { $last_type_value= "'2000-01-01 00:00:00'" }
    elsif ($last_column_type =~ /DATE/) { $last_type_value= "'2000-01-01'" }
    elsif ($last_column_type =~ /TIME/) { $last_type_value= "'00:00:00'" }
    elsif ($last_column_type =~ /GEOMETRY/) { $last_type_value= "POINT(0,0)" }
    elsif ($last_column_type =~ /INET6/) { $last_type_value= "'::'" }
    ; ''
  }
;

_basics_type_dependent_value:
    _basics_prepare_type_dependent_value { $last_type_value } ;

_basics_column_default:
  { @defaults= ($last_nullable eq 'NOT NULL' or $last_column_type eq 'SERIAL' or $last_column_type =~ /TIMESTAMP/ and $last_nullable ne 'NULL') ? () : ('NULL')
    ;  if ($last_column_type =~ /INT/) { @defaults= (@defaults, 0) }
    elsif ($last_column_type =~ /DOUBLE/ or $last_column_type =~ /FLOAT/) { @defaults= (@defaults, '0.0') }
    elsif ($last_column_type =~ /CHAR/ or $last_column_type =~ /BINARY/ or $last_column_type =~ /BLOB/ or $last_column_type =~ /TEXT/ or $last_column_type =~ /SET/ or $last_column_type =~ /ENUM/ or $last_column_type =~ /JSON/) { @defaults= (@defaults, "''") }
    elsif ($last_column_type =~ /TIMESTAMP/ or $last_column_type =~ /DATETIME/) { @defaults= (@defaults, "'2000-01-01 00:00:00'", 'CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP') }
    elsif ($last_column_type =~ /DATE/) { @defaults= (@defaults, "'2000-01-01'") }
    elsif ($last_column_type =~ /TIME/) { @defaults= (@defaults, "'00:00:00'") }
    elsif ($last_column_type =~ /GEOMETRY/) { @defaults= (@defaults, "POINT(0,0)") }
    elsif ($last_column_type =~ /INET6/) { @defaults= (@defaults, "'::'") }
    ; ($prng->int(0,1) and scalar(@defaults) and $last_column_type ne 'SERIAL' and ! $last_autoincrement ) ? 'DEFAULT '.$prng->arrayElement(\@defaults) : ''
  }
;

_basics_not_33pct:
  | | NOT ;

_basics_column_check_constraint_10pct:
  | | | | | | | | | _basics_simple_check_constraint ;

_basics_simple_check_constraint:
  CHECK (TRUE) |
  CHECK ( { '`'.$last_field.'`' } ) |
  CHECK ( { '`'.$last_field.'`' } IS NOT NULL ) |
  CHECK ( { '`'.$last_field.'`' } IS NULL OR { '`'.$last_field.'`' } )
;

_basics_column_zerofill:
  { $last_zerofill= ($last_column_type =~ /INT/ and ! $prng->int(0,9) ? 'ZEROFILL' : '') } ;

_basics_column_autoincrement:
  { $last_autoincrement= ($last_column_type =~ /INT/ and ! $prng->int(0,9) ? 'AUTO_INCREMENT' : '') } ;

_basics_column_specification:
  _basics_column_type _basics_column_attributes ;

_basics_table_partitioning_10pct:
  | | | | | | | | | _basics_table_partitioning
;

_basics_table_partitioning:
  _basics_partition_by_hash_or_key | _basics_partition_by_hash_or_key
  _basics_partition_by_value |
  _basics_partition_by_range |
  _basics_partition_by_system_time
;

_basics_hash_or_key:
  HASH | KEY ;

_basics_unique_10pct:
    ==FACTOR:9==
  | UNIQUE
;

_basics_returning_5pct:
    ==FACTOR:38==
  | RETURNING *
  | RETURNING _field
;

_basics_interval:
  _basics_small_interval | _basics_big_interval ;

_basics_small_interval:
  SECOND | MINUTE | HOUR ;

_basics_big_interval:
  DAY | WEEK | MONTH | YEAR ;

_basics_table_options:
  | | _basics_table_option | _basics_table_options _basics_table_option ;

# TODO: Extend
_basics_table_option:
  _basics_row_format_25pct |
  _basics_system_versioning_5pct
  _basics_comment_10pct
;

_basics_row_format_25pct:
  | | | ROW_FORMAT=_basics_row_format ;

_basics_system_versioning_5pct:
  | | | | | | | | | | | | | | | | | | | WITH SYSTEM VERSIONING ;

_basics_comment_10pct:
  | | | | | | | | | COMMENT _english ;

_basics_row_format:
  { @formats= ('DEFAULT')
    ;  if (lc($last_table_engine) eq 'myisam') { @formats= (@formats, 'FIXED', 'DYNAMIC', 'COMPRESSED') }
    elsif (lc($last_table_engine) eq 'aria')   { @formats= (@formats, 'FIXED', 'DYNAMIC', 'PAGE') }
    elsif (lc($last_table_engine) eq 'innodb') { @formats= (@formats, 'COMPACT', 'DYNAMIC', 'REDUNDANT', 'COMPRESSED') }
    ; $prng->arrayElement(\@formats)
  }
;

# TODO: Extend
_basics_alter_table_element:
  FORCE | FORCE | FORCE | FORCE | FORCE | FORCE |
  ENGINE=_basics_inbuilt_engine_weighted |
  _basics_alter_table_algorithm | _basics_alter_table_algorithm |
  _basics_alter_table_lock
;

_basics_online_10pct:
  | | | | | | | | | ONLINE ;

_basics_alter_table_algorithm:
  ALGORITHM=DEFAULT | ALGORITHM=INPLACE | ALGORITHM=COPY | ALGORITHM=NOCOPY /* compatibility 10.3.7 */ | ALGORITHM=INSTANT /* compatibility 10.3.7 */ ;

_basics_alter_table_lock:
  LOCK=DEFAULT | LOCK=NONE | LOCK=SHARED | LOCK=EXCLUSIVE ;

_basics_base_table_or_view_90_10pct:
  _basetable | _basetable | _basetable | _basetable | _basetable | _basetable | _basetable | _basetable | _basetable | _view ;

_basics_limit_50pct:
  | LIMIT _digit ;

_basics_limit_90pct:
  | ==FACTOR:9== LIMIT _digit ;

_basics_order_by_50pct:
  | ORDER BY 1 ;

_basics_order_by_limit_50pct:
  | ORDER BY 1 LIMIT _tinyint_unsigned ;

_basics_order_by_limit_50pct_offset_10pct:
  | ORDER BY 1 LIMIT _tinyint_unsigned _basics_offset_10pct ;

_basics_offset_10pct:
  | | | | | | | | | OFFSET _digit ;

_basics_view_algorithm_50pct:
  | ALGORITHM=MERGE | ALGORITHM=TEMPTABLE ;

;
# MAXDB is disabled permanently due to MDEV-18864
_basics_sql_mode_list:
  { @modes= qw(
      ALLOW_INVALID_DATES
      ANSI
      ANSI_QUOTES
      DB2
      EMPTY_STRING_IS_NULL
      ERROR_FOR_DIVISION_BY_ZERO
      HIGH_NOT_PRECEDENCE
      IGNORE_BAD_TABLE_OPTIONS
      IGNORE_SPACE
      MSSQL
      MYSQL323
      MYSQL40
      NO_AUTO_CREATE_USER
      NO_AUTO_VALUE_ON_ZERO
      NO_BACKSLASH_ESCAPES
      NO_DIR_IN_CREATE
      NO_ENGINE_SUBSTITUTION
      NO_FIELD_OPTIONS
      NO_KEY_OPTIONS
      NO_TABLE_OPTIONS
      NO_UNSIGNED_SUBTRACTION
      NO_ZERO_DATE
      NO_ZERO_IN_DATE
      ONLY_FULL_GROUP_BY
      ORACLE
      PAD_CHAR_TO_FULL_LENGTH
      PIPES_AS_CONCAT
      POSTGRESQL
      REAL_AS_FLOAT
      SIMULTANEOUS_ASSIGNMENT
      STRICT_ALL_TABLES
      STRICT_TRANS_TABLES
      TIME_ROUND_FRACTIONAL
      TRADITIONAL
    ); $length=$prng->int(1,scalar(@modes)); "'" . (join ',', @{$prng->shuffleArray(\@modes)}[0..$length]) . "'"
  }
;

_basics_explain_analyze:
  EXPLAIN _basics_explain_modifier |
  ANALYZE _basics_format_json_50pct
;

_basics_distinct_50pct:
  | DISTINCT ;

_basics_comparison_operator:
    = | != | < | > | >= | <= ;

_basics_logical_operator:
    AND | OR ;

_basics_extended_50pct:
  | EXTENDED ;

_basics_explain_modifier:
  _basics_format_json_50pct | EXTENDED | EXTENDED | EXTENDED | PARTITIONS ;

_basics_format_json_50pct:
    | FORMAT=JSON ;

_basics_explain_analyze_5pct:
  | | | | | | | | | | | | | | | | | | | _basics_explain_analyze ;

_basics_off_on:
    OFF | ON ;

_basics_10pct_off_90pct_on:
    OFF | ON | ON | ON | ON | ON | ON | ON | ON | ON ;

_basics_empty_values_list:
    () | (),_basics_empty_values_list | (),_basics_empty_values_list ;

_basics_any_value:
  _bit | _bool | _boolean | _tinyint | _smallint | _mediumint | _int | _integer | _bigint |
  _float | _double | _decimal | _dec | _numeric | _fixed |
  _char | _varchar | _binary | _varbinary |
  _tinyblob | _blob | _mediumblob | _longblob | _tinytext | _text | _mediumtext | _longtext |
  _date | _time | _datetime | _timestamp | _year |
  _enum | _set |
  _null | _letter | _digit | _data | _ascii | _string | _empty | _hex | _quid |
  _json | _jsonpath | _jsonkey | _jsonvalue | _jsonarray | _jsonpair | _jsonobject | _jsonpath_no_wildcard ;

_basics_value_set:
    { $basic_values=['NULL','DEFAULT',$prng->int(0,99),$prng->int(0,99),$prng->int(0,99),"'".$prng->text(8)."'","'".$prng->string(1)."'","'".$prng->string(1)."'","'".$prng->string(1)."'"]; @vals=(); $val_count= $prng->int(1,10) unless defined $val_count; foreach(1..$val_count) { push @vals, $prng->arrayElement($basic_values) }; '('.(join ',', @vals).')' } ;

_basics_value_for_numeric_column:
    NULL | NULL | DEFAULT | _digit | _tinyint | _tinyint_unsigned | _smallint_unsigned | _int_unsigned;

_basics_value_for_char_column:
    NULL | NULL | DEFAULT | '' | _char(1) | _english ;

_basics_reload_metadata:
    { $executors->[0]->cacheMetaData(1); '' };
