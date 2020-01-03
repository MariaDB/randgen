query_init:
    CREATE TABLE IF NOT EXISTS t1 (`pk` INT AUTO_INCREMENT, a VARCHAR(8), FULLTEXT(a), PRIMARY KEY(`pk`)) ENGINE=InnoDB;

query:
    INSERT INTO t1 () VALUES () |
    ALTER TABLE t1 CHANGE IF EXISTS my_field my_field INT, ALGORITHM=COPY;

my_field:
    a | b ;
