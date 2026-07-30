query:
  { _set_db('NON-SYSTEM') } coverage_fixes ;

coverage_fixes:
                 aggregate |
  ==FACTOR:0.1== ddl |
  ==FACTOR:0.1== cast |
  ==FACTOR:0.1== geometry |
                 dml |
                 compound
;

# Courtesy of Claude which says:
## Covers `plugin/type_cursor/plugin.cc:332` and `sql_derived.cc:897-906` — **5 lines**.
## 
## Two constraints: `make_new_field()` is the *field-copy* entry point, so an
## `Item_field` over a real `Field_sys_refcursor` is needed — a member of a `ROW` SP
## variable, whose `Virtual_tmp_table` holds the field (a function return value goes
## through `create_tmp_field_ex_from_handler()` instead). And `sql_derived.cc:897`
## needs a **materialized** derived table: a mergeable one returns at 830
## (`if (derived->merged)`), so block the merge with `LIMIT`.

compound:
  BEGIN NOT ATOMIC
    DECLARE rec ROW(c SYS_REFCURSOR);
    DECLARE c0 SYS_REFCURSOR;
    OPEN c0 FOR SELECT 1;
    SET rec.c= c0;
    SELECT * FROM (SELECT rec.c AS x FROM DUAL LIMIT 1) dt;
  END
;

aggregate:
  optional_group_concat_limit SELECT /* _table[invariant] */ LENGTH(GROUP_CONCAT(_field ORDER BY _field[invariant])) FROM _table[invariant] GROUP BY _field[invariant] |
  SELECT /* _table[invariant] */ _field[invariant], COUNT(DISTINCT CONCAT(_field, REPEAT(_digit,_smallint_unsigned))) FROM _table[invariant] GROUP BY _field[invariant] |
  SELECT 1 FROM _table GROUP BY DEFAULT(_field) |
  
;

optional_group_concat_limit:
  | SET STATEMENT group_concat_max_len= _smallint_unsigned FOR
;

ddl:
  ALTER TABLE _table MODIFY _field __text_x_blob __compressed(30) optional_default |
  ALTER TABLE _table table_min_max_rows_options
;

table_min_max_rows_options:
  | MIN_ROWS = table_min_max_rows
  | MAX_ROWS = table_min_max_rows
  | MIN_ROWS = table_min_max_rows MAX_ROWS = table_min_max_rows
;

table_min_max_rows:
  0 | 1 | 1000 | 1000000000;

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
  CREATE OR REPLACE TABLE test.tmp_geom (f GEOMETRY) ENGINE=HEAP |
  INSERT INTO test.tmp_geom VALUES (POINT(_digit,_digit)), (POINT(_digit,_digit)) |
  SET NAMES latin1
  ;; SELECT /* geom_table[invariant] */ LENGTH(GROUP_CONCAT(IF(TRUE, { $last_field }, POINT(0,0))
     ORDER BY 1)) > 0 AS ok FROM geom_table[invariant]
  ;; SET NAMES default |
     CREATE OR REPLACE VIEW test.v_geom AS SELECT /* geom_table[invariant] _field */ ST_GeomFromwkb(ST_ASBINARY({ $last_field })) FROM geom_table[invariant]
  ;; DESCRIBE test.v_geom
  ;; SELECT COUNT(*) FROM (SELECT DISTINCT ST_Centroid(f) AS x FROM test.tmp_geom) dt
; 

geom_table:
  ==FACTOR:20== { $last_database = 'test'; $last_table = 'tmp_geom'; 'test.tmp_geom' } |
  _table
;

dml:
  UPDATE _table
  SET _field = REPEAT(CHAR(65 + ( _tinyint_unsigned % 26)), 10000 + (_tinyint_unsigned % 5) * 2000)
  WHERE id = _tinyint_unsigned;