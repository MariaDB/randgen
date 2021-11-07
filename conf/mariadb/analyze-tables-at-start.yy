thread1_init_add:
  ANALYZE TABLE { join ',', @{$executors->[0]->baseTables()} } PERSISTENT FOR ALL;

