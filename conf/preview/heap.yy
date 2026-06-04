query:
  { _set_db('NON-SYSTEM') } coverage_fixes ;

coverage_fixes:
                 aggregate |
  ==FACTOR:0.1== compressed_columns |
  ==FACTOR:0.1== cast |
  ==FACTOR:0.1== geometry |
                 dml
;

aggregate:
  optional_group_concat_limit SELECT /* _table[invariant] */ LENGTH(GROUP_CONCAT(_field ORDER BY _field[invariant])) FROM _table[invariant] GROUP BY _field[invariant] |
  SELECT /* _table[invariant] */ _field[invariant], COUNT(DISTINCT CONCAT(_field, REPEAT(_digit,_smallint_unsigned))) FROM _table[invariant] GROUP BY _field[invariant] |
  SELECT 1 FROM _table GROUP BY DEFAULT(_field) |
  
;

optional_group_concat_limit:
  | SET STATEMENT group_concat_max_len= _smallint_unsigned FOR
;

compressed_columns:
  ALTER TABLE _table MODIFY _field __text_x_blob __compressed(30) optional_default ;

optional_default:
  | DEFAULT LENGTH(UUID())
;

cast:
  CREATE OR REPLACE TABLE test.tmp AS SELECT /* _table[invariant] */
    CAST(_field[invariant] AS BINARY(4)) AS cb4,
    CAST(_field[invariant] AS BINARY) AS cb,
    CAST(_field[invariant] AS BINARY(16)) AS cb16,
    CAST(_field[invariant] AS BINARY(32)) AS cb32,
    CAST(_field[invariant] AS BINARY(530)) AS cb530,
    CAST(_field[invariant] AS BINARY(65535)) AS cb65535,
    CAST(_field[invariant] AS BINARY(66000)) AS cb66000,
    CAST(_field[invariant] AS BINARY(16777215)) AS cb16777215,
    CAST(_field[invariant] AS BINARY(16777216)) AS cb16777216
    FROM _table[invariant] LIMIT 0;

geometry:
  CREATE OR REPLACE TABLE test.tmp_geom (f GEOMETRY) |
  INSERT INTO test.tmp_geom VALUES (POINT(_digit,_digit)), (POINT(_digit,_digit)) |
  SET NAMES latin1
  ;; SELECT /* geom_table[invariant] */ LENGTH(GROUP_CONCAT(IF(TRUE, { $last_field }, POINT(0,0))
     ORDER BY 1)) > 0 AS ok FROM geom_table[invariant]
  ;; SET NAMES default |
     CREATE OR REPLACE VIEW test.v_geom AS SELECT /* geom_table[invariant] _field */ ST_GeomFromwkb(ST_ASBINARY({ $last_field })) FROM geom_table[invariant]
  ;; DESCRIBE test.v_geom
; 

geom_table:
  ==FACTOR:20== { $last_database = 'test'; $last_table = 'tmp_geom'; 'test.tmp_geom' } |
  _table
;

dml:
  UPDATE _table
  SET _field = REPEAT(CHAR(65 + ( _tinyint_unsigned % 26)), 10000 + (_tinyint_unsigned % 5) * 2000)
  WHERE id = _tinyint_unsigned;