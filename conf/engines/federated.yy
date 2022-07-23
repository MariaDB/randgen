thread1_init_add:
    CREATE DATABASE IF NOT EXISTS fed_db
  ;; CREATE USER IF NOT EXISTS fed_user@'127.0.0.1' IDENTIFIED BY 'FdrUs3r!pw'
  ;; GRANT ALL ON *.* TO fed_user@'127.0.0.1'
  ;; SET STATEMENT binlog_format=statement FOR INSERT INTO mysql.servers (Server_name, Host, Db, Username, Password, Port, Wrapper) VALUES ('fedlink','127.0.0.1','test','fed_user','FdrUs3r!pw',@@port,'mysql')
  ;; FLUSH PRIVILEGES
  ;; fed_create_federated_table
  ;; fed_create_federated_table
  ;; fed_create_federated_table
  ;; fed_create_federated_table
  ;; fed_create_federated_table
  ;; fed_create_federated_table
  ;; fed_create_federated_table
  ;; fed_create_federated_table
;  

fed_create_federated_table:
    SELECT CONCAT("CREATE TABLE IF NOT EXISTS fed_db.", table_name, " ENGINE=FEDERATED CONNECTION='fedlink/", table_name, "'") INTO @stmt FROM information_schema.tables WHERE table_schema = 'test' AND table_type = 'BASE TABLE' ORDER BY RAND(_int_unsigned) LIMIT 1
  ; PREPARE stmt FROM @stmt
  ; EXECUTE stmt
  ; DEALLOCATE PREPARE stmt
;
