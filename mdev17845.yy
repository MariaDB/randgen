query:
  ALTER TABLE mysql.plugin FORCE ; FLUSH TABLES
;

thread1:
  SELECT db FROM mysql.db ORDER BY db LIMIT 0
;

thread2:
  SHOW STATUS LIKE 'Open_files' /* Validate 2 < 1000000000000 for row 1 */
;
