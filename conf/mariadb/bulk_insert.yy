#  Copyright (c) 2021, MariaDB Corporation Ab
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

# Don't be too greedy, or the data will grow huge
query_add:
  ==FACTOR:0.1== bulk_insert_load
;

bulk_insert_load:

  # Select from any table into any table. High chance of wrong field types/count
    _basics_insert_ignore_replace_clause INTO _table SELECT * FROM _table

  # Select from any table into the same table
  | _basics_insert_ignore_replace_clause INTO _table SELECT * FROM { $last_table }

  # Load a file into a random table. High chance of wrong field types/count,
  # but it's not as critical for LOAD as it is for INSERT
  | LOAD DATA INFILE bulk_existing_datafile_name bulk_replace_ignore INTO TABLE _table

  # Load an existing file from a table into the same table (or a generic load file).
  # Also fair chance of wrong field types/count, as the table could have been altered since
  | LOAD DATA INFILE bulk_existing_datafile_name bulk_replace_ignore INTO TABLE { $last_table }

  # Create a load file and load it into the same table
  | SELECT * INTO OUTFILE bulk_new_datafile_name FROM { $last_table } bulk_store_datafile_num
    ; LOAD DATA INFILE { "'$fname'" } bulk_replace_ignore INTO TABLE { $last_table }
;

bulk_existing_datafile_name:
  /* _user_db . _table */ { $fnum= $bulk_load_files{"$last_database.$last_table"}; $fname= ($fnum ? "load_${last_table}_".$prng->int(1,$fnum) : 'load_data_anon'); "'$fname'" };

bulk_last_datafile_name:
  { -e "$generator->vardir/data/$last_database/$fname" ? "'$fname'" : "'load_data_anon'" };

bulk_new_datafile_name:
  /* _user_db . _table */ { $fnum= ($bulk_load_files{"$last_database.$last_table"} or 0) + 1; $fname= "load_${last_table}_${fnum}"; "'$fname'" };

bulk_store_datafile_num:
  { if (-e $generator->vardir."/data/$last_database/load_${last_table}_${fnum}") { $bulk_load_files{"$last_database.$last_table"}= $fnum }; '' };


bulk_replace_ignore:
  REPLACE | IGNORE
;
