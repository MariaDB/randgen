query:
    INSERT INTO t5 SELECT * FROM t5 |
    INSERT IGNORE INTO t5 SELECT * FROM t5 |
    REPLACE INTO t5 SELECT * FROM t5
;

data_value:
    NULL | _tinyint_unsigned | _char(1) ;
