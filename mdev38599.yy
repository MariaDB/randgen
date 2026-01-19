query_init:
  CREATE TABLE IF NOT EXISTS test.t (a INT) ENGINE=InnoDB ;

query:
  ==FACTOR:2== INSERT INTO test.t VALUES (_int),(_int),(_int),(_int) |
  DELETE FROM test.t ORDER BY a LIMIT _digit
;

thread1:
  REPAIR TABLE test.t;
