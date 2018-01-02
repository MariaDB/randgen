query_add:
  bulk_insert_load
;

bulk_insert_load:
    INSERT INTO _table SELECT * FROM _table
  | SELECT * FROM _table INTO OUTFILE { "'load_$last_table'" } ; LOAD DATA INFILE { "'load_$last_table'" } bulk_replace_ignore INTO TABLE { $last_table }
;

bulk_replace_ignore:
  REPLACE | IGNORE
;
