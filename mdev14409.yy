thread2_init:
  CREATE TABLE `t1` (
    `t1` TEXT,
    `v1` VARCHAR(1),
    `t2` TEXT,
    `v2` VARCHAR(1),
    UNIQUE (`v2`),
    UNIQUE (`t2`(255))
  ) ENGINE=InnoDB ROW_FORMAT=DYNAMIC
  ; CREATE TABLE `t2` LIKE `t1`
  ; CREATE TABLE `t3` LIKE `t1`
  ; CREATE TABLE `t4` LIKE `t1`
  ; INSERT IGNORE INTO `t1` VALUES vals,vals,vals,vals,vals,vals,vals,vals,vals,vals 
  ; INSERT IGNORE INTO `t2` VALUES vals,vals,vals,vals,vals,vals,vals,vals,vals,vals 
  ; INSERT IGNORE INTO `t3` VALUES vals,vals,vals,vals,vals,vals,vals,vals,vals,vals 
  ; INSERT IGNORE INTO `t4` VALUES vals,vals,vals,vals,vals,vals,vals,vals,vals,vals 
  ; SELECT * FROM `t1` INTO OUTFILE 'load.data.t1'
  ; SELECT * FROM `t2` INTO OUTFILE 'load.data.t2'
  ; SELECT * FROM `t3` INTO OUTFILE 'load.data.t3'
  ; SELECT * FROM `t4` INTO OUTFILE 'load.data.t4'
;

vals:
  (_char(1024),_char(1),_char(1024),_char(1));

thread1:
	SHOW ENGINE INNODB STATUS;

query:
	DELETE FROM my_table LIMIT _digit |
  LOAD DATA INFILE { "'load.data.t".$prng->int(1,4)."'" } REPLACE INTO TABLE my_table
;

my_table:
  t1 | t2 | t3 | t4 ;

