#  Copyright (c) 2019, 2022, MariaDB Corporation Ab
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
# not primitive enough for auto-generation in Random,
# so that it doesn't have to be done in every grammar
# (unless the grammar needs it to be different)
########################################################################

_basics_wait_nowait:
  ==FACTOR:3== | WAIT _digit | NOWAIT ;

# TODO: add virtual
_basics_column_type:
    ==FACTOR:4== _basics_num_column_type
  | ==FACTOR:3== _basics_char_column_type
  | ==FACTOR:3== _basics_temporal_column_type
  |              _basics_blob_column_type
  |              _basics_special_column_type
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

# TODO: adjust probabilities when virtual columns start working
_basics_base_or_virtual_column_attributes:
    ==FACTOR:99== _basics_base_column_attributes
  |               _basics_virtual_column_attributes
;

_basics_base_column_attributes:
  _basics_column_autoincrement _basics_column_nullable _basics_column_default _basics_column_versioning_5pct __invisible(5) _basics_comment_10pct _basics_column_check_constraint_10pct ;

_basics_column_versioning_5pct:
   | ==FACTOR:0.05== __with_x_without(60) SYSTEM VERSIONING ;

_basics_virtual_column_attributes:
  _basics_prepare_type_dependent_value { $last_column_type eq 'SERIAL' ? '' : "GENERATED ALWAYS AS ($last_type_value) ".$prng->arrayElement( [ '', 'PERSISTENT', 'STORED', 'VIRTUAL', 'VIRTUAL' ] ) } ;

_basics_column_nullable:
  { $last_nullable= ($last_column_type eq 'SERIAL' ? '' : $prng->arrayElement( [ '', 'NULL', 'NOT NULL' ] )) };

_basics_prepare_type_dependent_value:
  { $last_type_value= 'NULL'
    ;  if ($last_column_type =~ /INT/) { $last_type_value= 0 }
    elsif ($last_column_type =~ /DOUBLE/ or $last_column_type =~ /FLOAT/) { $last_type_value= 0.0 }
    elsif ($last_column_type =~ /CHAR/ or $last_column_type =~ /BINARY/ or $last_column_type =~ /BLOB/ or $last_column_type =~ /TEXT/ or $last_column_type =~ /SET/ or $last_column_type =~ /ENUM/ or $last_column_type =~ /JSON/) { $last_type_value= "''" }
    elsif ($last_column_type =~ /TIMESTAMP/ or $last_column_type =~ /DATETIME/) { $last_type_value= $prng->datetime() }
    elsif ($last_column_type =~ /DATE/) { $last_type_value= $prng->date() }
    elsif ($last_column_type =~ /TIME/) { $last_type_value= $prng->time() }
    elsif ($last_column_type =~ /GEOMETRY/) { $last_type_value= "POINT(0,0)" }
    elsif ($last_column_type =~ /INET6/) { $last_type_value= $prng->inet6() }
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
    elsif ($last_column_type =~ /TIMESTAMP/ or $last_column_type =~ /DATETIME/) { @defaults= (@defaults, $prng->datetime(), 'CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP') }
    elsif ($last_column_type =~ /DATE/) { @defaults= (@defaults, $prng->date()) }
    elsif ($last_column_type =~ /TIME/) { @defaults= (@defaults, $prng->time()) }
    elsif ($last_column_type =~ /GEOMETRY/) { @defaults= (@defaults, "POINT(0,0)") }
    elsif ($last_column_type =~ /INET6/) { @defaults= (@defaults, $prng->inet6()) }
    ; ($prng->int(0,1) and scalar(@defaults) and $last_column_type ne 'SERIAL' and ! $last_autoincrement ) ? 'DEFAULT '.$prng->arrayElement(\@defaults) : ''
  }
;

_basics_column_check_constraint_10pct:
  | ==FACTOR:0.1== _basics_simple_check_constraint ;

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

# Expects that $partition_field would be initialized by now
# (either as a colum of the existing engine, for ALTER, or a newly created
# one, for CREATE)
_basics_table_partitioning:
  ==FACTOR:2== _basics_partition_by_hash_or_key |
               _basics_partition_by_value |
               _basics_partition_by_range |
               _basics_partition_by_system_time
;

_basics_partition_by_hash_or_key:
  PARTITION BY __hash_x_key ( { $partition_field } ) ;

# TODO: add
_basics_partition_by_value:
;

_basics_partition_by_system_time:
  PARTITION BY SYSTEM_TIME _basics_versioning_partition_condition _basics_versioning_partition_list ;

_basics_versioning_partition_condition:
  |
  INTERVAL _digit _basics_big_interval |
  INTERVAL _smallint_unsigned _basics_small_interval |
  LIMIT _smallint_unsigned ;

_basics_versioning_partition_list:
  ( PARTITION p1 HISTORY, PARTITION p2 HISTORY, PARTITION pn CURRENT ) ;

# TODO: add
_basics_partition_by_range:
;

_basics_returning_5pct:
  ==FACTOR:38==  | RETURNING * | RETURNING _field ;

_basics_interval:
  _basics_small_interval | _basics_big_interval ;

_basics_small_interval:
  SECOND | MINUTE | HOUR ;

_basics_big_interval:
  DAY | WEEK | MONTH | YEAR ;

_basics_table_options:
  ==FACTOR:2== |
               _basics_table_option |
               _basics_table_options _basics_table_option
;

# TODO: Extend
_basics_table_option:
  __with_system_versioning(5) |
  _basics_row_format_25pct |
  _basics_comment_10pct
;

_basics_row_format_25pct:
  | ==FACTOR:0.25== ROW_FORMAT=_basics_row_format ;

_basics_comment_10pct:
  | ==FACTOR:0.1== COMMENT _english ;

_basics_row_format:
  { @formats= ('DEFAULT')
    ;  if (lc($last_table_engine) eq 'myisam') { @formats= (@formats, 'FIXED', 'DYNAMIC', 'COMPRESSED') }
    elsif (lc($last_table_engine) eq 'aria')   { @formats= (@formats, 'FIXED', 'DYNAMIC', 'PAGE') }
    elsif (lc($last_table_engine) eq 'innodb') { @formats= (@formats, 'COMPACT', 'DYNAMIC', 'REDUNDANT', 'COMPRESSED') }
    ; $prng->arrayElement(\@formats)
  }
;

_basics_limit_50pct:
  | LIMIT _digit ;

_basics_limit_90pct:
  | ==FACTOR:9== LIMIT _digit ;

_basics_order_by_limit_50pct:
  | ORDER BY 1 LIMIT _tinyint_unsigned ;

_basics_order_by_limit_50pct_offset_10pct:
  | ORDER BY 1 LIMIT _tinyint_unsigned _basics_offset_10pct ;

_basics_offset_10pct:
  | ==FACTOR:0.1== OFFSET _digit ;

_basics_explain_analyze:
  EXPLAIN _basics_explain_modifier |
  ANALYZE _basics_format_json_50pct
;

_basics_comparison_operator:
    = | != | < | > | >= | <= | <=> | __not(50) LIKE ;

_basics_explain_modifier:
               _basics_format_json_50pct |
  ==FACTOR:3== EXTENDED |
               PARTITIONS
;

_basics_format_json_50pct:
    | FORMAT=JSON ;

_basics_empty_values_list:
    () | (),_basics_empty_values_list | (),_basics_empty_values_list ;

_basics_any_value:
                NULL |
                _bit | _bool | _boolean | _tinyint | _smallint | _mediumint | _int | _integer | _bigint |
  ==FACTOR:10== _smallint_unsigned |
                _float | _double | _decimal | _dec | _numeric | _fixed |
                _char | _varchar | _binary | _varbinary |
  ==FACTOR:10== _word |
                _tinyblob | _blob | _mediumblob | _longblob | _tinytext | _text | _mediumtext | _longtext |
                _date | _time | _datetime | _timestamp | _year |
                _digit | _data | _ascii | _string | _empty | _hex | _quid | _uuid |
                _json | _jsonpath | _jsonkey | _jsonpath_no_wildcard
;

_basics_value_set:
    { $basic_values=['NULL','DEFAULT',$prng->int(0,99),$prng->int(0,99),$prng->int(0,99),$prng->text(8),$prng->string(1),$prng->string(1),$prng->string(1)]; @vals=(); $val_count= $prng->int(1,10) unless defined $val_count; foreach(1..$val_count) { push @vals, $prng->arrayElement($basic_values) }; '('.(join ',', @vals).')' } ;

_basics_value_for_numeric_column:
    NULL | NULL | DEFAULT | _digit | _tinyint | _tinyint_unsigned | _smallint_unsigned | _int_unsigned;

_basics_value_for_char_column:
    NULL | NULL | DEFAULT | '' | _char(1) | _word ;

# MSSQL causes problems, specifically QUOTE() does not work properly.
# MAXDB is disabled due to MDEV-18864
# EMPTY_STRING_IS_NULL should be used in specific ORACLE mode tests,
#   otherwise it will cause endless semantic problems
#   (NULL being inserted into non-null column, etc.)

# 10.2: REAL_AS_FLOAT,PIPES_AS_CONCAT,ANSI_QUOTES,IGNORE_SPACE,IGNORE_BAD_TABLE_OPTIONS,ONLY_FULL_GROUP_BY,NO_UNSIGNED_SUBTRACTION,NO_DIR_IN_CREATE,POSTGRESQL,ORACLE,MSSQL,DB2,MAXDB,NO_KEY_OPTIONS,NO_TABLE_OPTIONS,NO_FIELD_OPTIONS,MYSQL323,MYSQL40,ANSI,NO_AUTO_VALUE_ON_ZERO,NO_BACKSLASH_ESCAPES,STRICT_TRANS_TABLES,STRICT_ALL_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ALLOW_INVALID_DATES,ERROR_FOR_DIVISION_BY_ZERO,TRADITIONAL,NO_AUTO_CREATE_USER,HIGH_NOT_PRECEDENCE,NO_ENGINE_SUBSTITUTION,PAD_CHAR_TO_FULL_LENGTH
# 10.3: + EMPTY_STRING_IS_NULL,SIMULTANEOUS_ASSIGNMENT
# 10.4: + TIME_ROUND_FRACTIONAL

_basics_all_sql_modes:
  { @modes= (
        'REAL_AS_FLOAT',
        'PIPES_AS_CONCAT',
        'ANSI_QUOTES',
        'IGNORE_SPACE',
        'IGNORE_BAD_TABLE_OPTIONS',
        'ONLY_FULL_GROUP_BY',
        'NO_UNSIGNED_SUBTRACTION',
        'NO_DIR_IN_CREATE',
        'POSTGRESQL',
  #     'ORACLE',
  #     'MSSQL',
        'DB2',
  #     'MAXDB',
        'NO_KEY_OPTIONS',
        'NO_TABLE_OPTIONS',
        'NO_FIELD_OPTIONS',
        'MYSQL323',
        'MYSQL40',
        'ANSI',
        'NO_AUTO_VALUE_ON_ZERO',
        'NO_BACKSLASH_ESCAPES',
        'STRICT_TRANS_TABLES',
        'STRICT_ALL_TABLES',
        'NO_ZERO_IN_DATE',
        'NO_ZERO_DATE',
        'ALLOW_INVALID_DATES',
        'ERROR_FOR_DIVISION_BY_ZERO',
        'TRADITIONAL',
        'NO_AUTO_CREATE_USER',
        'HIGH_NOT_PRECEDENCE',
        'NO_ENGINE_SUBSTITUTION',
        'PAD_CHAR_TO_FULL_LENGTH',
  #     'EMPTY_STRING_IS_NULL',
        'SIMULTANEOUS_ASSIGNMENT',
        'TIME_ROUND_FRACTIONAL',
    ); ''
  }
;
_basics_sql_mode_compatibility_markers:
  { if (index($val,'TIME_ROUND_FRACTIONAL') > -1) { $val.= ' /* compatibility 10.4 */' }
    elsif ((index($val,'EMPTY_STRING_IS_NULL') > -1) or (index($val, 'SIMULTANEOUS_ASSIGNMENT') > -1)) { $val .= ' /* compatibility 10.3 */' }
    ; $val }
;

_basics_sql_mode_value:
    DEFAULT
    | _basics_all_sql_modes
      { $length=$prng->int(0,scalar(@modes))
      ; $val= "'" . (join ',', @{$prng->shuffleArray(\@modes)}[0..$length-1]) . "'"
      ; ''
    } _basics_sql_mode_compatibility_markers
;
