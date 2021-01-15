query_init:
    CREATE TABLE IF NOT EXISTS t1 (f INT, KEY(f)) ENGINE=Aria
  ; CREATE TABLE IF NOT EXISTS t2 (f INT, KEY(f)) ENGINE=Aria
  ; CREATE TABLE IF NOT EXISTS t3 (f INT, KEY(f)) ENGINE=Aria
  ; INSERT INTO t2 VALUES (0)
  ; INSERT INTO t3 VALUES (NULL),(9)
;

my_table:
  t1 | t2 | t3 ;

query:
  binlog_event | binlog_event | binlog_event | binlog_event | binlog_event |
  binlog_event | binlog_event | binlog_event | binlog_event | binlog_event |
  binlog_event | binlog_event | binlog_event | binlog_event | binlog_event |
  binlog_event | binlog_event | binlog_event | binlog_event | binlog_event | create_trigger ;

binlog_event:
  dml | dml | dml |  xid_event ;

dml:
  delete | insert | update ;

xid_event:
  START TRANSACTION | COMMIT | ROLLBACK |
  SET AUTOCOMMIT = ON | SET AUTOCOMMIT = OFF ;

insert:
  INSERT INTO my_table ( f ) VALUES ( _digit ) ;

update:
  UPDATE my_table SET f = _digit WHERE f < _digit ORDER BY f LIMIT _digit ;

delete:
  DELETE FROM my_table ORDER BY f LIMIT 1 ;

create_trigger:
  CREATE TRIGGER _letter trigger_time trigger_event ON my_table FOR EACH ROW BEGIN trigger_body ; END ;

trigger_time:
  BEFORE | AFTER ;

trigger_event:
  INSERT | UPDATE ;

trigger_body:
  dml ; dml ; dml ; CALL _letter ;
