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

query_init:
  { %bulk_load_files=(); $path= $executors->[0]->vardir.'/loaddata'; mkpath($path); _set_db('NON-SYSTEM') } SELECT NULL INTO OUTFILE { "'$path/load_data_anon'" };

query:
  { _set_db('NON-SYSTEM') } bulk_op ;

bulk_op:
  ==FACTOR:5== insert_load |
  load_with_variables
;

load_with_variables:
  create_datafile ;; TRUNCATE TABLE _table ;; set_variables ;; self_load ;; reset_variables |
  TRUNCATE TABLE _table ;; set_variables ;; self_insert ;; reset_variables
;

insert_load:
  ==FACTOR:4== create_datafile ;; self_load |
  ==FACTOR:4== self_insert |
  cross_load |
  cross_insert
;

# Select from any table into the same table
self_insert:
  insert_replace INTO _table[invariant] SELECT * FROM _table[invariant] ;

# Select from any table into the table. For replace there is a good chance of an error (column doesn't have default value, type mismatch,...)
cross_insert:
  insert_replace INTO _table ( _field ) SELECT _table[invariant]._field FROM _table[invariant] ;

insert_replace:
  ==FACTOR:49== __replace_x_insert_ignore |
                __replace_x_insert DELAYED
;

create_datafile:
  SELECT * INTO OUTFILE /* _table[invariant] */ new_datafile_name FROM _table[invariant] store_datafile_num ;

# Presumably create_datafile was just called, and fname is set
self_load:
  LOAD DATA __low__priority_x_concurrent(10,20) LOCAL INFILE { "'$fname'" } __replace_x_ignore INTO TABLE _table[invariant] ;

# Load a random data file into the table. High chance of wrong field types/count,
# but it's not as critical for LOAD as it is for INSERT
cross_load:
  LOAD DATA __low__priority_x_concurrent(10,20) LOCAL INFILE existing_datafile_name __replace_x_ignore INTO TABLE _table ;

set_variables:
  SET FOREIGN_KEY_CHECKS=0, UNIQUE_CHECKS=0, AUTOCOMMIT=0 ;

reset_variables:
  SET FOREIGN_KEY_CHECKS=1, UNIQUE_CHECKS=1, AUTOCOMMIT=1 ;

existing_datafile_name:
  /* _table[invariant] */ { $fnum= $bulk_load_files{"$last_database.$last_table"}; $fname= ($fnum ? "$path/load_".abs($$)."_${last_table}_".$prng->int(1,$fnum) : "$path/load_data_anon" ); "'$fname'" };

new_datafile_name:
  { $fnum= ($bulk_load_files{"$last_database.$last_table"} or 0) + 1; $fname= "$path/load_".abs($$)."_${last_table}_${fnum}"; "'$fname'" };

store_datafile_num:
  { if (-e "$path/load_".abs($$)."_${last_table}_${fnum}") { $bulk_load_files{"$last_database.$last_table"}= $fnum; };  '' };

