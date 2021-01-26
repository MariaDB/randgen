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
  { %bulk_load_per_table=(); '' } ;

# Don't be too greedy, or the data will grow huge
query_add:
  ==FACTOR:0.1== bulk_insert_load
;

bulk_insert_load:
  # Select from any table into any table. High chance of wrong field types/count
    _basics_insert_ignore_replace_clause INTO _table SELECT * FROM _table
  # Select from any table into the same table
  | _basics_insert_ignore_replace_clause INTO _table SELECT * FROM { $last_table }
  # Load a random file into a table. High chance of wrong field types/count,
  # but it's not as critical for LOAD as it is for INSERT
  | LOAD DATA INFILE { $t= ($prng->arrayElement([keys %bulk_load_per_table]) or $last_table); $n= $prng->int(1,$bulk_load_per_table{$t}); "'load_${t}_${n}'" } bulk_replace_ignore INTO TABLE _table
  # Create a load file and load it into the same table
  | /* _table */ { $bulk_load_per_table{$last_table} = (defined $bulk_load_per_table{$last_table} ? $bulk_load_per_table{$last_table} + 1 : 1); '' }
      SELECT * INTO OUTFILE { $f= "'load_${last_table}_$bulk_load_per_table{$last_table}'" } FROM { $last_table }
    ; LOAD DATA INFILE { $f } bulk_replace_ignore INTO TABLE { $last_table }
;

bulk_replace_ignore:
  REPLACE | IGNORE
;
