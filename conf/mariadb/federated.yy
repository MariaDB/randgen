thread1_init_add:
    CREATE DATABASE fed_db
  ; fed_create_federated_table
  ; fed_create_federated_table
  ; fed_create_federated_table
  ; fed_create_federated_table
  ; fed_create_federated_table
  ; fed_create_federated_table
  ; fed_create_federated_table
  ; fed_create_federated_table
;  

query_add:
  USE fed_database
;

fed_create_federated_table:
    SELECT CONCAT('CREATE OR REPLACE TABLE fed_db.', table_name, ' ENGINE=FEDERATED CONNECTION=\'mysql://root@127.0.0.1:',@@port,'/test/', table_name, '\'') FROM information_schema.tables WHERE table_schema = 'test' AND table_type = 'BASE TABLE' ORDER BY RAND(_int_unsigned) LIMIT 1 INTO @stmt
  ; PREPARE stmt FROM @stmt
  ; EXECUTE stmt
  ; DEALLOCATE PREPARE stmt
;

fed_database:
  fed_db | test
;
