thread1_init_add:
  SET STATEMENT binlog_format=statement FOR INSERT INTO mysql.servers (Server_name, Host, Db, Username, Port, Wrapper) VALUES ('s','127.0.0.1','test','root',@@port,'mysql'); FLUSH PRIVILEGES ;

query_add:
  ==FACTOR:0.01== { $last_table = $prng->arrayElement($executors->[0]->metaTables($last_database)); '' } CREATE TABLE IF NOT EXISTS { $last_table.'_SPIDER' } LIKE { $last_table }; ALTER TABLE { $last_table.'_SPIDER' } ENGINE=SPIDER COMMENT = { '"wrapper '."'mysql', srv 's', table '".$last_table."'".'"' };
