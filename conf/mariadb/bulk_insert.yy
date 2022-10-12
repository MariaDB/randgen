#  Copyright (c) 2021, 2022 MariaDB Corporation Ab
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

query_init_add:
  { %bulk_load_files=(); '' } SELECT NULL INTO OUTFILE 'load_data_anon';

query_add:
  /* _user_db . _table { $target_db= $last_database; $target_table= $last_table; '' } */ bulk_op ;

bulk_op:
  ==FACTOR:5== bulk_insert_load |
  bulk_load_with_variables
;

bulk_load_with_variables:
  bulk_create_datafile ;; TRUNCATE TABLE { $target_table } ;; bulk_set_variables ;; bulk_self_load ;; bulk_reset_variables |
  TRUNCATE TABLE { $target_table } ;; bulk_set_variables ;; bulk_self_insert ;; bulk_reset_variables
;

bulk_insert_load:
  ==FACTOR:4== bulk_create_datafile ;; bulk_self_load |
  ==FACTOR:4== bulk_self_insert |
  bulk_cross_load |
  bulk_cross_insert
;

# Select from any table into the same table
bulk_self_insert:
  _basics_insert_ignore_replace_clause INTO { $target_table } SELECT * FROM { $target_table } ;

# Select from any table into the table. For replace there is a good chance of an error (column doesn't have default value, type mismatch,...)
bulk_cross_insert:
    _basics_insert_ignore_replace_clause INTO { $target_table } ( _field ) SELECT _table._field FROM { $last_table } ;

bulk_create_datafile:
  SELECT * INTO OUTFILE bulk_new_datafile_name FROM { $target_table } bulk_store_datafile_num ;

# Presumably bulk_create_datafile was just called, and fname is set
bulk_self_load:
  LOAD DATA INFILE { "'$fname'" } __replace_x_ignore INTO TABLE { $target_table } ;

# Load a random data file into the table. High chance of wrong field types/count,
# but it's not as critical for LOAD as it is for INSERT
bulk_cross_load:
  LOAD DATA INFILE bulk_existing_datafile_name __replace_x_ignore INTO TABLE { $target_table } ;

bulk_set_variables:
  SET FOREIGN_KEY_CHECKS=0, UNIQUE_CHECKS=0, AUTOCOMMIT=0 ;

bulk_reset_variables:
  SET FOREIGN_KEY_CHECKS=1, UNIQUE_CHECKS=1, AUTOCOMMIT=1 ;

bulk_existing_datafile_name:
  /* _table */ { $fnum= $bulk_load_files{"last_table"}; $fname= ($fnum ? "load_${last_table}_".$prng->int(1,$fnum) : 'load_data_anon'); "'$fname'" };

bulk_new_datafile_name:
  { $fnum= ($bulk_load_files{"$target_db.$target_table"} or 0) + 1; $fname= "load_${target_table}_${fnum}"; "'$fname'" };

bulk_store_datafile_num:
  { if (-e $generator->vardir."/data/$target_db/load_${target_table}_${fnum}") { $bulk_load_files{"$target_db.$target_table"}= $fnum }; '' };

