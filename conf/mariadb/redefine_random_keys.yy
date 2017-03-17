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


thread1_init_add:
    # rkr_indexes is a hash: table => hash of index numbers
    { %primary_keys = (); %rkr_indexes = (); '' }
#      LOCK TABLE { join ' WRITE, ', @{$executors->[0]->tables()} } WRITE
      rkr_add_autoinc_pk ; rkr_add_autoinc_pk ; rkr_add_autoinc_pk
    ; rkr_add_autoinc_pk ; rkr_add_autoinc_pk ; rkr_add_autoinc_pk
    ; rkr_add_key ; rkr_add_key ; rkr_add_key ; rkr_add_key ; rkr_add_key
    ; rkr_add_key ; rkr_add_key ; rkr_add_key ; rkr_add_key ; rkr_add_key
    ; rkr_add_key ; rkr_add_key ; rkr_add_key ; rkr_add_key ; rkr_add_key
#    ; UNLOCK TABLES
;

thread1_add:
      query | query | query | query | query | query | query
    | query | query | query | query | query | query | query
    | query | query | query | query | query | query | query
    | query | query | query | query | query | query | query
    | query | query | query | query | query | query | query
    | rkr_add_key | rkr_add_key | rkr_drop_key
    | rkr_analyze_tables
;

rkr_analyze_tables:
    ANALYZE TABLE { join ',', @{$executors->[0]->baseTables()} };

rkr_new_key_name:
    {
          %{$rkr_indexes{$last_table}} = () unless defined $rkr_indexes{$last_table}
        ; @rkr_table_indexes = (keys %{$rkr_indexes{$last_table}} ? sort {$b <=> $a} keys %{$rkr_indexes{$last_table}} : (0) )
        ; $rkr_index_num = $rkr_table_indexes[0]+1
        ; ${$rkr_indexes{$last_table}}{$rkr_index_num} = 1
        ; 'rkr_index_'.$rkr_index_num
    }
;

rkr_key_name_to_drop:
    {
          @rkr_table_indexes = keys %{$rkr_indexes{$last_table}} or ()
        ; $rkr_index_num = $prng->arrayElement(\@rkr_table_indexes)
        ; delete ${$rkr_indexes{$last_table}}{$rkr_index_num} if $rkr_index_num
        ; ( $rkr_index_num ? 'rkr_index_'.$rkr_index_num : 'non_existing_rk_index' )
    }
;

rkr_add_autoinc_pk:
    { $tries = 0
        ; $tables = $executors->[0]->metaBaseTables($last_database)
        ; do {
              $last_table = $prng->arrayElement($tables)
            ; $tries++
        } until ($tries > @{$tables} or not $primary_keys{$last_table})
        ; ''
    } LOCK TABLE { $last_table } WRITE
    ; UPDATE { $last_table } SET _field_int = 0
    ; ALTER TABLE { $last_table } MODIFY { $last_field } INT AUTO_INCREMENT PRIMARY KEY
    ; UNLOCK TABLES
    { $primary_keys{$last_table} = 1; '' }
;

rkr_add_key:
    ALTER TABLE _basetable ADD rkr_index_type_and_name ( { %index_fields = (); 'rkr_index_field_list' } ) ;

rkr_index_type_and_name:
      rkr_non_unique_key
    | rkr_non_unique_key
    | rkr_non_unique_key
    | rkr_non_unique_key
    | rkr_unique_key
    | rkr_pk_if_possible
;

rkr_pk_if_possible:
    { if ($primary_keys{$last_table}) { 'rkr_non_unique_key' } else { $primary_keys{$last_table} = 1; 'PRIMARY KEY' } } ;

rkr_unique_key:
    UNIQUE rkr_non_unique_key;

rkr_non_unique_key:
    KEY rkr_new_key_name ;

rkr_drop_key:
    ALTER TABLE _basetable DROP KEY rkr_key_name_to_drop ;

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


