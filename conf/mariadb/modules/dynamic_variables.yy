#  Copyright (c) 2020, MariaDB Corporation
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

query_add:
    dynvar_set;

dynvar_set:
    dynvar_sql_mode
    | dynvar_innodb_threads
;

dynvar_innodb_threads:
    # MENT-599
    /* compatibility 10.5.2-0 */ SET GLOBAL innodb_purge_threads = { $prng->int(0,33) } |
    # MENT-661
    /* compatibility 10.5.2-0 */ SET GLOBAL innodb_read_io_threads = { $prng->int(0,65) } |
    /* compatibility 10.5.2-0 */ SET GLOBAL innodb_write_io_threads = { $prng->int(0,65) }
;

dynvar_sql_mode:
    SET dynvar_session_or_global SQL_MODE= dynvar_sql_mode_value;

dynvar_sql_mode_value:
    DEFAULT
    | { @modes= qw(
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
          NO_ZERO_IN_DATE
          ONLY_FULL_GROUP_BY
          PAD_CHAR_TO_FULL_LENGTH
          PIPES_AS_CONCAT
          POSTGRESQL
          REAL_AS_FLOAT
          SIMULTANEOUS_ASSIGNMENT
          STRICT_ALL_TABLES
          STRICT_TRANS_TABLES
          TIME_ROUND_FRACTIONAL
        ); $length=$prng->int(0,scalar(@modes)); "'" . (join ',', @{$prng->shuffleArray(\@modes)}[0..$length]) . "'"
    }
;

dynvar_session_or_global:
  | | | | | SESSION | SESSION | SESSION | GLOBAL ;
