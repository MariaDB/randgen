thread1_init_add:
  ANALYZE TABLE { join ',', @{$executors->[0]->baseTables()} } PERSISTENT FOR ALL;

thread1_add:
  ==FACTOR:100== SET STATEMENT lock_wait_timeout=5 FOR ANALYZE TABLE _table PERSISTENT FOR ALL;
