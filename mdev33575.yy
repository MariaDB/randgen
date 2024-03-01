query_init:
  SET ROLE admin ;; USE simple_db ;

query:
  OPTIMIZE TABLE simple_db.E;
;

thread1:
  OPTIMIZE TABLE mysql.innodb_index_stats;
