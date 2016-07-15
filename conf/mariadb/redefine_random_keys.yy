# Copyright (c) 2016 MariaDB Corporation
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA

# rkr stands for "random_keys_redefine"
# this is to avoid overriding rule names from other grammars

thread2_init_add:
    { %primary_keys = (); '' }
      LOCK TABLE { join ' WRITE, ', @{$executors->[0]->tables()} } WRITE
    ; rkr_add_key ; rkr_add_key ; rkr_add_key ; rkr_add_key ; rkr_add_key
    ; rkr_add_key ; rkr_add_key ; rkr_add_key ; rkr_add_key ; rkr_add_key
    ; rkr_add_key ; rkr_add_key ; rkr_add_key ; rkr_add_key ; rkr_add_key
    ; rkr_add_key ; rkr_add_key ; rkr_add_key ; rkr_add_key ; rkr_add_key
    ; UNLOCK TABLES
;

rkr_add_key:
    { %index_fields = (); '' } ALTER TABLE _basetable ADD rkr_index_type KEY ( rkr_index_field_list );

rkr_index_type:
    | | | 
    # Some unique/primary keys will fail at creation due to duplicate values. That's okay
    | { if ($primary_keys{$last_table}) { '' } else { $primary_keys{$last_table} = 1; 'PRIMARY' } } 
    | UNIQUE ;
    
rkr_index_field_list:
      rkr_partially_covered_column 
    | rkr_partially_covered_column, rkr_partially_covered_column
    | rkr_partially_covered_column, rkr_index_field_list
;

rkr_partially_covered_column:
    rkr_unique_field rkr_index_length;
    
rkr_unique_field:
    { $tries = 0; $fields = $executors->[0]->metaColumns($last_table, $last_database); do { $last_field = $prng->arrayElement($fields); $tries++ } until ( not defined $index_fields{$last_field} or $tries >= @{$fields} ); $index_fields{$last_field} = 1; $item = '`'.$last_field.'`' } ;
    
rkr_index_length:
    # Index length 3072 is too much for most cases, but we only take it as an upper limit. 
    # Some index creations will fail, let it be so for now
    { $metatype = $executors->[0]->columnMetaType($last_field, $last_table,$last_database); $maxfldlength = $executors->[0]->columnMaxLength($last_field, $last_table,$last_database); $maxlength = ( $maxfldlength > 3072 ? 3072 : $maxfldlength ); if ($metatype eq 'char' or $metatype eq 'binary') { (rand()<0.3 ? '('.(int(rand($maxlength))+1).')' : '') } elsif ($metatype eq 'blob' or $metatype eq 'text') { '('.(int(rand($maxlength))+1).')' } else { '' } };


