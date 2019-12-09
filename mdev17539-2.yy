query:
  SELECT * FROM _table INTO OUTFILE { "'load_$last_table'" } ; LOAD DATA INFILE { "'load_$last_table'" } INTO TABLE { $last_table } |
  OPTIMIZE TABLE { $my_last_table = 't'.$prng->int(1,10) };

