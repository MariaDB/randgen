query_init:
  get_charsets ;

thread1_init:
     get_charsets
     CREATE USER IF NOT EXISTS spider_user@'127.0.0.1' IDENTIFIED BY 'SpdrUs3r!pw'
  ;; GRANT ALL ON *.* TO spider_user@'127.0.0.1'
  ;; SET STATEMENT binlog_format=statement FOR INSERT INTO mysql.servers (Server_name, Host, Db, Username, Password, Port, Wrapper) VALUES ('s','127.0.0.1','test','spider_user','SpdrUs3r!pw',@@port,'mysql')
  ;; FLUSH PRIVILEGES
;

get_charsets:
  { @charsets= (); map { push @charsets, $_ if ($_ ne 'utf32' && $_ ne 'utf16' && $_ ne 'ucs2' && $_ ne 'utf16le') } @{$executors->[0]->metaCharactersets()}; print "HERE: @charsets\n"; '' };

# Character set enforced due to MDEV-29562 (can't work with utf32/utf16/ucs2)
query:
  ==FACTOR:0.01== CREATE TABLE IF NOT EXISTS { $last_table = $prng->arrayElement($executors->[0]->metaTables($last_database)); $last_table.'_SPIDER' } LIKE { $last_table }; ALTER TABLE { $last_table.'_SPIDER' } ENGINE=SPIDER COMMENT = { '"wrapper '."'mysql', srv 's', table '".$last_table."'".'"' } CHARACTER SET { $prng->arrayElement(\@charsets) };
