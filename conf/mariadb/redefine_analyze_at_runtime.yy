

Query:  SELECT alias1.`col_varchar_10_latin1` AS field1 FROM G AS alias1 LEFT JOIN C AS alias2 ON alias1.`pk` = alias2.`col_int` WHERE alias1.`col_varchar_1024_utf8` IS NULL AND alias1.`col_varchar_1024_utf8` LIKE ( 'w' ) OR alias1.`col_varchar_1024_utf8` BETWEEN 'j' AND 'z' AND alias2.`col_varchar_1024_utf8` LIKE ( "he######SINGLES######i######SINGLES######z######SINGLES######y######SINGLES######l######SINGLES######re" AND alias1.`col_varchar_1024_utf8` <= 's" ) OR alias2.`col_varchar_1024_utf8` > ' AND alias1.`col_varchar_1024_utf8` IN (' AND alias2.`col_varchar_1024_utf8` <= ', ' OR alias1.`col_varchar_1024_utf8` IN (', ', ') OR ( alias1.`pk` >= alias1.`col_int_key` AND alias2.`col_int` >= 8 )  failed: 1064 You have an error in your SQL syntax; check the manual that corresponds to your MariaDB server version for the right syntax to use near '' at line %d. Further errors of this kind will be suppressed.

HERE: sentence:  ALTER TABLE G ADD INDEX `test_idx` USING HASH (`col_varchar_1024_latin1`( 200 ), `col_varchar_1024_utf8`( 37 ) ) ; 
SELECT alias1.`col_varchar_1024_latin1_key` AS field1 FROM G AS alias1 LEFT OUTER JOIN H AS alias2 ON alias1
.`col_varchar_1024_latin1_key` = alias2.`col_varchar_10_utf8_key` WHERE alias1.`col_varchar_1024_utf8` > 'q' AND alias1.
`col_varchar_1024_utf8` <= 'z' AND alias1.`col_varchar_1024_latin1` IS NULL OR alias1.`col_varchar_1024_utf8` LIKE ( 'my
' ) AND alias1.`col_varchar_1024_latin1` >= 'could' AND alias1.`col_varchar_1024_latin1` < 'x' AND alias1.`col_varchar_1
024_latin1` NOT BETWEEN 'u' AND 'z' AND alias1.`col_varchar_1024_latin1` >= 'x' AND alias1.`col_varchar_1024_latin1` <= 
'z' AND alias1.`col_varchar_1024_latin1` IS NOT NULL OR alias1.`col_varchar_1024_utf8` > 'been' AND alias1.`col_varchar_
1024_utf8` <= 'l' OR alias1.`col_varchar_1024_utf8` >= 'been' AND alias1.`col_varchar_1024_utf8` < 'MKEAI' AND alias1.`c
ol_varchar_1024_utf8` BETWEEN 'z' AND 'z' OR alias1.`col_varchar_1024_utf8` NOT LIKE ( '_%' ) AND alias1.`col_varchar_10
24_latin1` >= 'u' AND alias1.`col_varchar_1024_latin1` <= 'z' AND alias2.`col_varchar_1024_utf8` > 'c' AND alias2.`col_v
archar_1024_utf8` <= 'z' ; 
SELECT alias2.`col_int` AS field1 FROM G AS alias1 LEFT JOIN view_A AS alias2 LEFT OUTER JOIN
 A AS alias3 ON alias2.`col_varchar_1024_utf8_key` = alias3.`col_varchar_1024_latin1_key` ON alias1.`col_int` = alias3.`
col_int` WHERE alias1.`col_varchar_1024_utf8` >= 'h' AND alias1.`col_varchar_1024_utf8` < 'i' AND alias1.`col_varchar_10
24_utf8` >= 's' AND alias1.`col_varchar_1024_utf8` <= 'z' ; 
SELECT alias1.`col_datetime_key` AS field1 FROM G AS alias1 
RIGHT OUTER JOIN view_C AS alias2 ON alias1.`col_varchar_10_utf8_key` = alias2.`col_varchar_1024_latin1_key` WHERE alias
2.`col_varchar_1024_utf8` NOT LIKE ( 'i' ) AND alias2.`col_varchar_1024_utf8` IS NULL OR alias2.`col_varchar_1024_utf8` 
>= 'q' AND alias2.`col_varchar_1024_utf8` < 'XVAZB' OR alias2.`col_varchar_1024_utf8` >= 'q' AND alias2.`col_varchar_102
4_utf8` <= 'z' AND alias2.`col_varchar_1024_utf8` >= 'q' AND alias2.`col_varchar_1024_utf8` < 'back' OR alias1.`col_varc
har_1024_latin1` IN ('e', 'f') GROUP BY field1 ; 


SELECT alias1.`col_varchar_10_latin1` AS field1 FROM G AS alias1 LEFT JOIN C AS alias2 ON alias1.`pk` = alias2.`col_int` WHERE alias1.`col_varchar_1024_utf8` IS NULL AND alias1.`col_varchar_1024_utf8` LIKE ( 'w' ) OR alias1.`col_varchar_1024_utf8` BETWEEN 'j' AND 'z' AND alias2.`col_varchar_1024_utf8` LIKE ( "he's" ) OR alias2.`col_varchar_1024_utf8` > 'i' AND alias2.`col_varchar_1024_utf8` <= 'z' OR alias1.`col_varchar_1024_utf8` IN ('y', 'l') AND alias1.`col_varchar_1024_utf8` >= "you're" AND alias1.`col_varchar_1024_utf8` <= 'q' AND alias1.`col_varchar_1024_utf8` IN ('n', 'w', 'd') OR ( alias1.`pk` >= alias1.`col_int_key` AND alias2.`col_int` >= 8 ) ; 

SELECT alias1.`col_varchar_10_latin1` AS field1 FROM G AS alias1 LEFT JOIN C AS alias2 ON alias1.`pk` = alias2.`col_int` WHERE alias1.`col_varchar_1024_utf8` IS NULL AND alias1.`col_varchar_1024_utf8` LIKE ( ######SINGLES###### ) OR alias1.`col_varchar_1024_utf8` BETWEEN ######SINGLES###### AND ######SINGLES###### AND alias2.`col_varchar_1024_utf8` LIKE ( "he######SINGLES######i######SINGLES######z######SINGLES######y######SINGLES######l######SINGLES######re" AND alias1.`col_varchar_1024_utf8` <= ######SINGLES###### AND alias1.`col_varchar_1024_utf8` IN (######SINGLES######, ######SINGLES######, ######SINGLES######) OR ( alias1.`pk` >= alias1.`col_int_key` AND alias2.`col_int` >= 8 ) ;

HERE: stored doubles: "he######SINGLES######i######SINGLES######z######SINGLES######y######SINGLES######l######SINGLES######re"

SELECT alias1.`col_varchar_10_latin1` AS field1 FROM G AS alias1 LEFT JOIN C AS alias2 ON alias1.`pk` = alias2.`col_int` WHERE alias1.`col_varchar_1024_utf8` IS NULL AND alias1.`col_varchar_1024_utf8` LIKE ( ######SINGLES###### ) OR alias1.`col_varchar_1024_utf8` BETWEEN ######SINGLES###### AND ######SINGLES###### AND alias2.`col_varchar_1024_utf8` LIKE ( ######DOUBLES###### AND alias1.`col_varchar_1024_utf8` <= ######SINGLES###### AND alias1.`col_varchar_1024_utf8` IN (######SINGLES######, ######SINGLES######, ######SINGLES######) OR ( alias1.`pk` >= alias1.`col_int_key` AND alias2.`col_int` >= 8 ) ######SEMICOLON######

SELECT a
lias2.`col_datetime` AS field1 FROM G AS alias1 LEFT JOIN B AS alias2 ON alias1.`col_varchar_1024_latin1_key` = alias2.`
col_varchar_10_utf8` WHERE alias2.`col_varchar_1024_latin1` NOT BETWEEN 'b' AND 'z' OR alias2.`col_varchar_1024_utf8` NO
T BETWEEN 'z' AND 'z' AND alias1.`col_varchar_1024_utf8` >= 'u' AND alias1.`col_varchar_1024_utf8` <= 'z' AND alias1.`co
l_varchar_1024_utf8` > 'n' AND alias1.`col_varchar_1024_utf8` <= 'u' ORDER BY field1, field1 DESC ; 
SELECT alias1.`col_i
nt_key` AS field1, alias2.`col_varchar_10_latin1_key` AS field2 FROM G AS alias1 LEFT JOIN view_F AS alias2 ON alias1.`c
ol_varchar_10_utf8_key` = alias2.`col_varchar_10_utf8_key` WHERE alias1.`col_varchar_1024_latin1` > 'b' AND alias1.`col_
varchar_1024_latin1` < 'z' AND alias2.`col_varchar_1024_latin1` >= 'p' AND alias2.`col_varchar_1024_latin1` <= 'z' ORDER
 BY field1, field2 LIMIT 100 OFFSET 50 ; DROP INDEX `test_idx` ON G
