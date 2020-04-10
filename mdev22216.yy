thread1_init:
    CREATE DATABASE IF NOT EXISTS db
    ; CREATE TABLE IF NOT EXISTS t1 (
        id INT NOT NULL auto_increment,
        k INT,
        PRIMARY KEY (id)
    ) ENGINE=InnoDB
    ; SET debug_dbug= '+d,sleep_before_update_checkpoint'
;

thread1:
    INSERT INTO t1 (k) VALUES (0);

thread2:
    CREATE TABLE db.t SELECT id FROM t1 LIMIT 0
    ; DROP TABLE IF EXISTS db.t
;

thread3:
    CREATE DATABASE IF NOT EXISTS db
    ; DROP TABLE IF EXISTS x
;
