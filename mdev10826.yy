query_init:
    CREATE TABLE IF NOT EXISTS t1 (a INT);

query:
    FLUSH TABLES |
    SELECT * FROM t1 |
    DELETE FROM t1
;
