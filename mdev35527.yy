query:
  OPTIMIZE TABLE mysql.gtid_slave_pos NOWAIT |
  UPDATE simple_db.B SET col_int_nokey = DEFAULT
;
