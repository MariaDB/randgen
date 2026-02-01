query_init:
     CREATE TABLE test.t (i INT, pk TIMESTAMP PRIMARY KEY) ENGINE=Aria PARTITION BY key (pk) partitions 2
  ;; ALTER TABLE test.t DISABLE KEYS
  ;; INSERT INTO test.t VALUES (5, '2000-01-01 00:00:01')
  ;; ALTER TABLE test.t ENABLE KEYS
;

query:
	SELECT 1;
