query_init:
     CREATE TABLE test.table1_aria_timestamp_key_pk_parts_2 (i int, pk timestamp primary key) ENGINE=Aria PARTITION BY key (pk) partitions 2
  ;; ALTER TABLE test.table1_aria_timestamp_key_pk_parts_2 DISABLE KEYS
  ;; INSERT INTO test.table1_aria_timestamp_key_pk_parts_2 VALUES  (5, '2000-01-01 00:00:01')
  ;; ALTER TABLE test.table1_aria_timestamp_key_pk_parts_2 ENABLE KEYS
  ;;
;

query:
  SELECT 1;

