#  Copyright (c) 2024, MariaDB
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

#compatibility 11.7.0

query_init:
     SET ROLE admin
  ;; SET GLOBAL mhnsw_max_cache_size=8*1024*1024*1024
  ;; CREATE DATABASE IF NOT EXISTS vector_db
  ;; USE vector_db
  ;; { $create_table_name = 't1_'.abs($$); '' } create_vector_table
  ;; { $create_table_name = 't2_'.abs($$); '' } create_vector_table
  ;; { $create_table_name = 't3_'.abs($$); '' } create_vector_table
  ;; { $create_table_name = 't4_'.abs($$); '' } create_vector_table
  ;; GRANT ALL ON vector_db.* TO CURRENT_USER()
  ;; SET GLOBAL mhnsw_max_cache_size=DEFAULT
  ;; SET ROLE NONE
;

query:
  { _set_db('NON-SYSTEM') } vector_query |
  ==FACTOR:10== { _set_db('vector_db') } vector_spec_query ;

create_vector_table:
  CREATE TABLE IF NOT EXISTS { $create_table_name } (pk INT AUTO_INCREMENT PRIMARY KEY, veccol VECTOR({$dimensions=$prng->uint16(1,100)}) NOT NULL, VECTOR(veccol) opt_max_edges_per_node opt_distance_func) opt_engine
  ;; increase_max_statement_time REPLACE INTO { $create_table_name } (pk, veccol) SELECT s2.seq AS pk, VEC_FROMTEXT(concat('[', GROUP_CONCAT(FORMAT((-1 + 2*RAND())/(10*_digit),_digit)), ']')) AS veccol FROM { 'seq_1_to_'.$dimensions } s1, { 'seq_1_to_'.$prng->uint16(1,1000) } s2 GROUP BY s2.seq
;

view_algorithm:
  ==FACTOR:3== |
  ALGORITHM=MERGE |
  ALGORITHM=TEMPTABLE
;

opt_engine:
  |
  ENGINE=MyISAM |
  ENGINE=Aria |
  ENGINE=InnoDB
;

vector_query:
  vector_creation |
  column_creation |
  ==FACTOR:10== vector_search |
  vector_update |
  ==FACTOR:0.1== create_vector_table |
  ==FACTOR:0.1== vector_column_alter |
  ==FACTOR:0.1== vector_var |
;

vector_spec_query:
  ==FACTOR:10== vector_search |
  vector_update |
  vector_insert |
  vector_delete |
  ==FACTOR:0.01== vector_addition |
  ==FACTOR:0.1== SELECT veccol_name INTO @veccol_val FROM _table LIMIT 1 |
  ==FACTOR:0.01== vector_truncate
;

vector_truncate:
  CREATE OR REPLACE TEMPORARY TABLE vec_tmp AS SELECT * FROM _table ;; TRUNCATE TABLE { $last_table } ;; INSERT INTO { $last_table } SELECT * FROM vec_tmp ;

vector_column_alter:
  ALTER TABLE IF EXISTS _basetable MODIFY COLUMN IF EXISTS veccol_name veccol_type NOT NULL |
  ALTER TABLE IF EXISTS _basetable CHANGE COLUMN IF EXISTS veccol_name veccol_name veccol_type NOT NULL |
  ==FACTOR:0.5== ALTER TABLE _basetable FORCE vector_column_alter_alg
;

vector_column_alter_alg:
  | , ALGORITHM=COPY | , ALGORITHM=INPLACE | , ALGORITHM=NOCOPY ;

vector_var:
  SET __session_x_global mhnsw_ef_search = min_limit |
  SET GLOBAL mhnsw_max_cache_size = cache_size |
  SET __session_x_global mhnsw_default_distance = __euclidean_x_cosine |
  SET __session_x_global mhnsw_default_m = { $prng->uint16(0,201) }
;

# MDEV-35214: 0 | 1 | 1048576 |
cache_size:
  16*1048576 | 256*1048576 | 1024*1048576 | 8*1024*1048576 | DEFAULT ;

# MDEV-35213:  | 65535
min_limit:
  0 | 1 | 2 | 10 | DEFAULT | 100 | 1000;

column_creation:
  ALTER TABLE _basetable DROP COLUMN IF EXISTS veccol_name, ADD COLUMN veccol_name veccol_type NOT NULL DEFAULT default_vector_value;

vector_creation:
  ALTER TABLE _basetable DROP INDEX IF EXISTS vecind_name ;; increase_max_statement_time ALTER TABLE { $last_table } ADD VECTOR INDEX opt_vecind_name (veccol_name) opt_distance_func opt_max_edges_per_node |
  vector_addition
;

vector_addition:
  increase_max_statement_time ALTER TABLE _basetable ADD VECTOR INDEX IF NOT EXISTS opt_vecind_name (veccol_name) opt_max_edges_per_node opt_distance_func
;

vectortype:
  ==FACTOR:10==  VECTOR({$dim=$prng->uint16(1,20)}) |
  ==FACTOR:5==   VECTOR({$dim=$prng->uint16(1,100)}) |
  ==FACTOR:0.5== VECTOR({$dim=$prng->uint16(1,300)})
;

veccol_type:
  ==FACTOR:50== vectortype |
  vector_wrongtype ;

vector_wrongtype:
  ==FACTOR:20== BLOB |
  ==FACTOR:10== LONGBLOB |
  ==FACTOR:10== MEDIUMBLOB |
                TINYBLOB |
                TEXT |
                LONGTEXT |
                VARBINARY(8192) |
                VARBINARY(1024) |
                BINARY(255)
;

veccol_name:
  ==FACTOR:100== veccol |
                veccol2
;

opt_vecind_name:
  ==FACTOR:20== vecind_name |
;

vecind_name:
  ==FACTOR:100== vecind |
                veccol |
                veccol2
;

increase_max_statement_time:
  SET STATEMENT max_statement_time= @@max_statement_time*10 FOR ;

vector_search:
  ==FACTOR:10== vector_search_select |
  vector_search_view
;

vector_search_view:
  CREATE OR REPLACE view_algorithm VIEW { 'v_search_'.abs($$) } AS vector_search_select ;; SELECT * FROM { 'v_search_'.abs($$) } ;; DROP VIEW { 'v_search_'.abs($$) } ;

vector_search_select:
  SELECT fields_for_select FROM table_list optional_where_clause ORDER BY order_by_clause limit_clause ;

vector_delete:
  DELETE FROM _table optional_where_clause ORDER BY order_by_clause LIMIT _digit ;

vector_insert:
  __insert_ignore_x_replace_x_insert INTO _table (veccol_name) SELECT veccol_name FROM { $last_table } tb1 optional_where_clause ORDER BY order_by_clause LIMIT _digit ;

limit_clause:
  |
  ==FACTOR:30== LIMIT _tinyint_unsigned;

vector_update:
  UPDATE __ignore(50) _table tb1 SET veccol_name = sample_vector optional_where_clause ORDER BY order_by_clause limit_clause ;

table_list:
  ==FACTOR:10==  _table tb1 { $tb2='' } |
                 _table tb1 JOIN _table { $tb2='tb2' } |
  ==FACTOR:0.1== _table tb1 STRAIGHT_JOIN _table { $tb2='tb2' } |
                 _table tb1 __left_x_right(35,15) JOIN _table { $tb2='tb2' } join_condition |
  ==FACTOR:0.1== _table tb1 STRAIGHT_JOIN _table { $tb2='tb2' } join_condition |
  ==FACTOR:0.1== _table tb1 NATURAL __left_x_right(20,20) JOIN _table { $tb2='tb2' }
;

join_condition:
  ON (simple_where_clause_list);

fields_for_select:
  select_alias . _field | select_alias . _field, vector_function | vector_function, select_alias. _field ;

select_alias:
  ==FACTOR:10== tb1 |
  tb2
;

vector_function:
  vector_distance |
  VEC_TOTEXT(select_alias.veccol_name) ;

order_by_clause:
  vector_distance __asc_x_desc(33,33) |
  vector_distance __asc_x_desc(33,33), fields_for_order_by |
  fields_for_order_by, vector_distance __asc_x_desc(33,33)
;

fields_for_order_by:
  fld_alias . _field __asc_x_desc(33,33) | fld_alias. _field __asc_x_desc(33,33), fld_alias. _field __asc_x_desc(33,33) ;

vector_distance:
  VEC_DISTANCE_EUCLIDEAN(vec_distance_arg, vec_distance_arg) |
  VEC_DISTANCE_COSINE(vec_distance_arg, vec_distance_arg)
;

vec_distance_arg:
  select_alias.veccol_name | sample_vector ;

optional_where_clause:
  | WHERE simple_where_clause_list ;

simple_where_clause_list:
  simple_where_clause | simple_where_clause __and_x_or simple_where_clause_list ;

fld_alias:
  { $tb2 ? 'tb'.$prng->uint16(1,2) : 'tb1' } ;

simple_where_clause:
  fld_alias . _field oper _anyvalue |
  fld_alias . _field IS __not(50) NULL |
  fld_alias . veccol_name __not(50) LIKE CONCAT(0x30303030,'%') |
  VEC_FROMTEXT(VEC_TOTEXT(fld_alias . veccol_name)) __not(50) LIKE CONCAT(0x30303030,'%') |
  VEC_TOTEXT(fld_alias . veccol_name) __not(50) LIKE '[%]' |
  fld_alias . veccol_name __not(50) BETWEEN 0x30303030 AND 0x7A7A7A7A |
  fld_alias . veccol_name __not(50) BETWEEN sample_vector AND sample_vector |
  fld_alias . veccol_name oper sample_vector |
  vector_function = _anyvalue
;

oper:
  > | < | >= | <= | != ;

opt_distance_func:
  |
  DISTANCE=cosine |
  DISTANCE=euclidean
;

opt_max_edges_per_node:
  | { 'm='.$prng->arrayElement(['0','1','3','4','5','6','DEFAULT','10','12','24','60','200']) } ;

default_vector_value:
  ==FACTOR:100== VEC_FROMTEXT( { $dim=$prng->uint16(0,10) unless $dim; @vals=(); foreach (1..$dim) {push @vals, '0.0'}; "'[".(join ',',@vals)."]'" } ) |
  VEC_FROMTEXT( { $n=$prng->uint16(0,10); @vals=(); foreach (1..$n) {push @vals, '0.0'}; "'[".(join ',',@vals)."]'" } ) |
  VEC_FROMTEXT( { $n=$prng->uint16(10,1000); @vals=(); foreach (1..$n) {push @vals, '0.0'}; "'[".(join ',',@vals)."]'" } ) |
  VEC_FROMTEXT(sample_vector)
;

sample_vector:
  VEC_FROMTEXT({ $dimensions= 96; $min_value= $prng->uint16(-10,10); $max_value= $prng->uint16($min_value,$min_value+100); @vals= (); for (my $j=0; $j<$dimensions; $j++) { push @vals, sprintf("%.3f",$min_value + rand()*($max_value - $min_value)) }; "'[".(join ',', @vals)."]'" }) |
  VEC_FROMTEXT({ $dimensions= $prng->uint16(1,20); $min_value= $prng->uint16(-10,10); $max_value= $prng->uint16($min_value,$min_value+100); @vals= (); for (my $j=0; $j<$dimensions; $j++) { push @vals, sprintf("%.3f",$min_value + rand()*($max_value - $min_value)) }; "'[".(join ',', @vals)."]'" }) |
  { '0x'.join ('', map { map { (0..9,'A'..'F')[$prng->uint16(0,15)] } (1..8) } (1..96) ) } |
  { '0x'.join ('', map { map { (0..9,'A'..'F')[$prng->uint16(0,15)] } (1..8) } (1..$prng->uint16(1,20)) ) } |
  ==FACTOR:0.1== @veccol_val
;

