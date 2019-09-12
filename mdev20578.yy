query_init:
      SELECT * FROM t1 INTO OUTFILE 'load_t1'
    ; SELECT * FROM t2 INTO OUTFILE 'load_t2'
    ; SELECT * FROM t3 INTO OUTFILE 'load_t3'
    ; SELECT * FROM t4 INTO OUTFILE 'load_t4'
    ; SELECT * FROM t5 INTO OUTFILE 'load_t5'
    ; SELECT * FROM t6 INTO OUTFILE 'load_t6'
    ; SELECT * FROM t7 INTO OUTFILE 'load_t7'
    ; SELECT * FROM t8 INTO OUTFILE 'load_t8'
    ; SELECT * FROM t9 INTO OUTFILE 'load_t9'
;

query:
    /* _table */ LOAD DATA INFILE { "'load_$last_table'" } REPLACE INTO TABLE { $last_table }
    | DELETE FROM _table LIMIT _tinyint_unsigned
;
