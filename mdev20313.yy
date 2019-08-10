query_init:
    SET SQL_MODE='';

query:
    dml | dml | dml | dml | dml | dml | dml |
    load | load | load | load | load | load | load
;

trx:
  START TRANSACTION | COMMIT ;

dml:
    update | update | update | 
    delete |
    insert | insert
;

load:
  SELECT * FROM _table INTO OUTFILE { $nm= "'load_$last_table".'_'.time().'_'.$$."'" } ; LOAD DATA INFILE { $nm } REPLACE INTO TABLE { $last_table } ;

insert:
    insert_op INTO _table ( _field ) VALUES ( data_value ) |
    insert_op INTO _table () VALUES () |
    insert_op INTO _table () VALUES (),(),(),() |
;

insert_op:
  INSERT IGNORE | REPLACE ;

data_value:
  NULL | DEFAULT | _tinyint_unsigned | _english | _char(1) | '' ;

update:
    UPDATE IGNORE _table SET _field = data_value ORDER BY _field LIMIT 1 ;

delete:
    DELETE FROM _table ORDER BY _field LIMIT 1 ;
