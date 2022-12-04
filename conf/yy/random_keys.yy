# Copyright (c) 2016, 2022, MariaDB Corporation
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


thread1_init:
    # rkr_indexes is a hash: table => hash of index numbers
    { %primary_keys = (); %rkr_indexes = (); '' }
;

query:
  { _set_db('user') } random_keys_query ;

random_keys_query:
      ==FACTOR:3==    add_key
    |                 drop_key
    | ==FACTOR:0.01== add_autoinc_pk
;

new_key_name:
    {
          %{$rkr_indexes{"$last_database.$last_table"}} = () unless defined $rkr_indexes{"$last_database.$last_table"}
        ; @rkr_table_indexes = (keys %{$rkr_indexes{$last_table}} ? sort {$b <=> $a} keys %{$rkr_indexes{"$last_database.$last_table"}} : (0) )
        ; $rkr_index_num = $rkr_table_indexes[0]+1
        ; ${$rkr_indexes{"$last_database.$last_table"}}{$rkr_index_num} = 1
        ; 'rkr_index_'.$rkr_index_num
    }
;

key_name_to_drop:
    {
          @rkr_table_indexes = keys %{$rkr_indexes{"$last_database.$last_table"}} or ()
        ; $rkr_index_num = $prng->arrayElement(\@rkr_table_indexes)
        ; delete ${$rkr_indexes{"$last_database.$last_table"}}{$rkr_index_num} if $rkr_index_num
        ; ( $rkr_index_num ? 'rkr_index_'.$rkr_index_num : 'non_existing_rk_index' )
    }
;

add_autoinc_pk:
    { $tries = 0
        ; $tables = $executors->[0]->metaBaseTables($last_database)
        ; do {
              $last_table = $prng->arrayElement($tables)
            ; $tries++
        } until ($tries > @{$tables} or not $primary_keys{"$last_database.$last_table"})
        ; ''
    } LOCK TABLE { $last_table } WRITE
    ;; UPDATE { $last_table } SET _field_int = 0
    ;; ALTER TABLE { $last_table } MODIFY { $last_field } INT AUTO_INCREMENT, ADD PRIMARY KEY ($last_field  __asc_x_desc(33,33))
    ;; UNLOCK TABLES
    { $primary_keys{"$last_database.$last_table"} = 1; '' }
;

add_key:
    ALTER TABLE _basetable ADD index_type_and_name ( { %index_fields = (); 'index_field_list' } ) ;

index_type_and_name:
      non_unique_key
    | non_unique_key
    | non_unique_key
    | non_unique_key
    | unique_key
    | pk_if_possible
;

pk_if_possible:
    { if ($primary_keys{"$last_database.$last_table"}) { 'non_unique_key' } else { $primary_keys{"$last_database.$last_table"} = 1; 'PRIMARY KEY' } } ;

unique_key:
    UNIQUE non_unique_key;

non_unique_key:
    KEY __if_not_exists(90) new_key_name ;

drop_key:
    ALTER TABLE _basetable DROP KEY __if_exists(90) key_name_to_drop ;

index_field_list:
      partially_covered_column
    | partially_covered_column, partially_covered_column
    | partially_covered_column, index_field_list
;

partially_covered_column:
    unique_field index_length __asc_x_desc(33,33);

unique_field:
    { $tries = 0; $fields = $executors->[0]->metaColumns($last_table, $last_database); do { $last_field = $prng->arrayElement($fields); $tries++ } until ( not defined $index_fields{$last_field} or $tries >= @{$fields} ); $index_fields{$last_field} = 1; $item = '`'.$last_field.'`' } ;

index_length:
    # Index length 3072 is too much for most cases, but we only take it as an upper limit.
    # Some index creations will fail, let it be so for now
    { $metatype = $executors->[0]->columnMetaType($last_field, $last_table,$last_database); $maxfldlength = $executors->[0]->columnMaxLength($last_field, $last_table,$last_database); $maxlength = ( $maxfldlength > 3072 ? 3072 : $maxfldlength ); if ($metatype eq 'char' or $metatype eq 'binary') { (rand()<0.3 ? '('.(int(rand($maxlength))+1).')' : '') } elsif ($metatype eq 'blob' or $metatype eq 'text') { '('.(int(rand($maxlength))+1).')' } else { '' } };


