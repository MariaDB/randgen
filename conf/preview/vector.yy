thread1_init:
  SET ROLE admin
  ;; CREATE DATABASE IF NOT EXISTS vector_db
  ;; USE vector_db
  ;; CREATE TABLE IF NOT EXISTS t2 (pk INT PRIMARY KEY, veccol BLOB NOT NULL, VECTOR(veccol) opt_max_edges_per_node opt_distance_func) ENGINE=MyISAM
       SELECT s2.seq AS pk, VEC_FROMTEXT(concat('[', GROUP_CONCAT(FORMAT(-1 + 2*RAND(),3)), ']')) AS veccol
       FROM seq_1_to_30 s1, seq_1_to_10000 s2 GROUP BY s2.seq
  ;; CREATE TABLE IF NOT EXISTS t4 (pk INT PRIMARY KEY, veccol BLOB NOT NULL, VECTOR(veccol)opt_max_edges_per_node opt_distance_func) ENGINE=MyISAM
       SELECT s2.seq AS pk, VEC_FROMTEXT(concat('[', GROUP_CONCAT(FORMAT(-1 + 2*RAND(),3)), ']')) AS veccol
       FROM seq_1_to_300 s1, seq_1_to_1000 s2 GROUP BY s2.seq
  ;; CREATE TABLE t1 LIKE t2
  ;; ALTER TABLE t1 ENGINE = InnoDB
  ;; SET STATEMENT max_statement_time=@@max_statement_time*10 FOR INSERT INTO t1 SELECT * FROM t2 ORDER BY pk LIMIT 1000
  ;; CREATE TABLE t3 LIKE t4
  ;; ALTER TABLE t3 ENGINE = InnoDB
  ;; SET STATEMENT max_statement_time=@@max_statement_time*10 FOR INSERT INTO t1 SELECT * FROM t4 ORDER BY pk DESC LIMIT 100
  ;; EXECUTE IMMEDIATE CONCAT('REVOKE DROP ON vector_db.* FROM ',CURRENT_USER) ;; EXECUTE IMMEDIATE CONCAT('REVOKE DROP ON vector_db.* FROM PUBLIC') ;; SET ROLE NONE ;

query:
  { _set_db('NON-SYSTEM') } vector_query |
  ==FACTOR:3== { _set_db('vector_db') } vector_spec_query ;

vector_query:
  vector_creation |
  vector_search |
  vector_update |
  ==FACTOR:0.1== vector_var
;

vector_spec_query:
  vector_search |
  vector_update |
  vector_insert |
  vector_delete |
  ==FACTOR:0.01== vector_truncate
;

vector_truncate:
  CREATE OR REPLACE TEMPORARY TABLE vec_tmp AS SELECT * FROM _table ;; TRUNCATE TABLE { $last_table } ;; INSERT INTO { $last_table } SELECT * FROM vec_tmp ;

vector_var:
  SET __session_x_global mhnsw_min_limit = min_limit |
  SET GLOBAL mhnsw_cache_size = cache_size |
  SET __session_x_global mhnsw_min_limit = __euclidean_x_cosine |
  SET __session_x_global mhnsw_max_edges_per_node = { $prng->uint16(0,201) }
;

cache_size:
  0 | 1 | 1048576 | 16*1048576 | 256*1048576 | 1024*1048576 | 8*1024*1048576 | DEFAULT ;

min_limit:
  0 | 1 | 2 | 10 | DEFAULT | 100 | 65535 ;

vector_creation:
  increase_max_statement_time ALTER TABLE _basetable DROP COLUMN IF EXISTS veccol_name, ADD COLUMN veccol_name veccol_type NOT NULL DEFAULT default_vector_value, ADD VECTOR INDEX opt_vecind_name (veccol_name) |
  increase_max_statement_time ALTER TABLE _basetable DROP INDEX IF EXISTS vecind_name, ADD VECTOR INDEX opt_vecind_name (veccol_name) opt_distance_func opt_max_edges_per_node |
  increase_max_statement_time ALTER TABLE _basetable ADD VECTOR INDEX IF NOT EXISTS opt_vecind_name (veccol_name) opt_max_edges_per_node opt_distance_func
;

veccol_type:
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
  SELECT fields_for_select FROM _table optional_where_clause ORDER BY order_by_clause limit_clause ;

vector_delete:
  DELETE FROM _table optional_where_clause ORDER BY order_by_clause LIMIT _digit ;

vector_insert:
  INSERT INTO _table (veccol_name) SELECT veccol_name FROM { $last_table } optional_where_clause ORDER BY order_by_clause LIMIT _digit ;

limit_clause:
  |
  ==FACTOR:20== LIMIT _tinyint_unsigned;

vector_update:
  UPDATE _table SET veccol_name = VEC_FROMTEXT(sample_vector) optional_where_clause ORDER BY order_by_clause limit_clause ;

fields_for_select:
  _field | _field, VEC_TOTEXT(veccol_name) | VEC_TOTEXT(veccol_name), _field ;

order_by_clause:
  vector_distance __asc_x_desc(33,33) |
  vector_distance __asc_x_desc(33,33), fields_for_order_by |
  fields_for_order_by, vector_distance __asc_x_desc(33,33)
;

fields_for_order_by:
  _field __asc_x_desc(33,33) | 1 __asc_x_desc(33,33) | _field __asc_x_desc(33,33), _field __asc_x_desc(33,33) ;

vector_distance:
  VEC_DISTANCE_EUCLIDEAN(veccol_name, sample_vector) | VEC_DISTANCE_COSINE(veccol_name, sample_vector) ;

optional_where_clause:
  | WHERE simple_where_clause ;

simple_where_clause:
  _field = _anyvalue | _field != _anyvalue | _field IS __not(50) NULL ;

opt_distance_func:
  |
  DISTANCE_FUNCTION=cosine |
  DISTANCE_FUNCTION=euclidean
;

opt_max_edges_per_node:
  | { 'max_edges_per_node='.$prng->arrayElement(['0','1','3','4','5','6','DEFAULT','10','12','24','60','200']) } ;

default_vector_value:
  ==FACTOR:100== VEC_FROMTEXT( { $n=$prng->uint16(0,10); @vals=(); foreach (1..$n) {push @vals, '0.0'}; "'[".(join ',',@vals)."]'" } ) |
  VEC_FROMTEXT( { $n=$prng->uint16(10,1000); @vals=(); foreach (1..$n) {push @vals, '0.0'}; "'[".(join ',',@vals)."]'" } ) |
  VEC_FROMTEXT(sample_vector)
;

sample_vector:
  { $dimensions= $prng->uint16(1,20); $min_value= $prng->uint16(-10,10); $max_value= $prng->uint16($min_value,$min_value+100); @vals= (); for (my $j=0; $j<$dimensions; $j++) { push @vals, sprintf("%.3f",$min_value + rand()*($max_value - $min_value)) }; "'[".(join ',', @vals)."]'" } ;

