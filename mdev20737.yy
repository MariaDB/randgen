query:
    dml | dml | dml | dml | dml | dml | dml |
    bulk_insert_load
;

dml:
    update | update | update | 
    delete |
    insert | insert
;

insert:
    REPLACE INTO _table ( _field ) VALUES ( data_value ) |
    REPLACE INTO _table ( _field, _field )  VALUES ( data_value, data_value ) |
    REPLACE INTO _table ( _field, _field ) VALUES ( data_value, data_value ) |
    REPLACE INTO _table () VALUES () |
    REPLACE INTO _table () VALUES (),(),(),() |
;

data_value:
  NULL | DEFAULT | _tinyint_unsigned | _english | _char(1) | '' ;

update:
    UPDATE IGNORE _table SET _field = data_value ORDER BY _field LIMIT 1 ;

delete:
    DELETE FROM _table ORDER BY _field LIMIT 1 ;

bulk_insert_load:
    INSERT INTO _table SELECT * FROM _table
  | SELECT * FROM _table INTO OUTFILE { "'load_$last_table'" } ; LOAD DATA INFILE { "'load_$last_table'" } bulk_replace_ignore INTO TABLE { $last_table }
;

bulk_replace_ignore:
  REPLACE | IGNORE ;
