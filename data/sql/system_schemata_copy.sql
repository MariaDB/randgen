DELIMITER $
CREATE OR REPLACE PROCEDURE mysql.copy_system_schemata()
BEGIN
DECLARE done INT DEFAULT FALSE;
DECLARE db VARCHAR(255);
DECLARE tbl VARCHAR(255);
DECLARE cur_tables CURSOR FOR SELECT table_schema, table_name FROM INFORMATION_SCHEMA.TABLES WHERE table_schema IN ('mysql','information_schema','performance_schema','sys') AND TABLE_TYPE NOT LIKE 'VIEW'; 
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

OPEN cur_tables;
tables_loop: LOOP
  FETCH cur_tables INTO db, tbl;
  IF done THEN
    LEAVE tables_loop;
  END IF;
  EXECUTE IMMEDIATE CONCAT("CREATE DATABASE IF NOT EXISTS ",db,"_db_copy");
  IF db = 'performance_schema' THEN
    EXECUTE IMMEDIATE CONCAT("CREATE TABLE IF NOT EXISTS ",db,"_db_copy.",tbl," IGNORE AS SELECT * FROM ",db,".",tbl);
  ELSE
    EXECUTE IMMEDIATE CONCAT("CREATE OR REPLACE TABLE ",db,"_db_copy.",tbl," LIKE ",db,".",tbl);
    EXECUTE IMMEDIATE CONCAT("ALTER TABLE ",db,"_db_copy.",tbl," ENGINE=",@@default_storage_engine);
    EXECUTE IMMEDIATE CONCAT("INSERT IGNORE INTO ",db,"_db_copy.",tbl," SELECT * FROM ",db,".",tbl);
  END IF;
END LOOP;
CLOSE cur_tables;

END $
DELIMITER ;
CALL mysql.copy_system_schemata;
DROP PROCEDURE mysql.copy_system_schemata;
