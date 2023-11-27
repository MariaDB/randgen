query_init:
  CREATE TABLE IF NOT EXISTS test.t (pk INT PRIMARY KEY);

query:
  REPLACE INTO test.t (`pk`) VALUES (1) |
  SELECT ID INTO @kill FROM INFORMATION_SCHEMA.PROCESSLIST WHERE USER != 'system user' AND Command != 'Sleep' ORDER BY ID LIMIT 1 ;; KILL @kill ;
