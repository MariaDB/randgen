thread1_init_add:
  CREATE USER IF NOT EXISTS spider_user@'127.0.0.1'; GRANT ALL ON *.* TO spider_user@'127.0.0.1'; SET STATEMENT binlog_format=statement FOR INSERT INTO mysql.servers (Server_name, Host, Db, Username, Port, Wrapper) VALUES ('s','127.0.0.1','test','spider_user',@@port,'mysql'); FLUSH PRIVILEGES ;

query_add:
  ==FACTOR:0.01== CREATE TABLE IF NOT EXISTS { $last_table = $prng->arrayElement($executors->[0]->metaTables($last_database)); $last_table.'_SPIDER' } LIKE { $last_table }; ALTER TABLE { $last_table.'_SPIDER' } ENGINE=SPIDER COMMENT = { '"wrapper '."'mysql', srv 's', table '".$last_table."'".'"' };
