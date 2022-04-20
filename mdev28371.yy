query_add:
  mdev5535_query
;

mdev5535_query:
  create_temporary_table | create_temporary_table | drop_temporary_table
;

create_temporary_table:
  CREATE OR REPLACE TEMPORARY TABLE `tmp` LIKE _table
  ; INSERT INTO `tmp` SELECT * FROM { $last_table }
  ; DROP TEMPORARY TABLE IF EXISTS `tmp`
;

drop_temporary_table:
  DROP TEMPORARY TABLE IF EXISTS `tmp`;

