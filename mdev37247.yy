query_init:
  USE test
  ;; SELECT v INTO @a FROM t WHERE pk = rand_pk
  ;; SELECT v INTO @b FROM t WHERE pk = rand_pk
  ;; SELECT v INTO @c FROM t WHERE pk = rand_pk
;

query:
    SELECT v INTO rand_var FROM t WHERE pk = rand_pk
  | UPDATE t SET v = rand_var ORDER BY pk LIMIT _digit
  | REPLACE INTO t (v) SELECT v FROM t ORDER BY VEC_DISTANCE_EUCLIDEAN(v, rand_var) LIMIT 1
;

rand_pk:
  { $prng->uint16(1,6000) };

rand_var:
  @a | @b | @c;
