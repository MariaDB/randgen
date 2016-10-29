#
# Redefining grammar for MDEV-5535 - cannot reopen temporary table
#

thread2_add:
    mdev5535;

thread3_add:
    mdev5535;

mdev5535:
      query | query | query | query | query | query | query | query | query | query | query
    | query | query | query | query | query | query | query | query | query | query | query
    | create_temporary_table | create_temporary_table | create_temporary_table
    | drop_temporary_table
;

create_temporary_table:
      { $i = int(rand(scalar @{$executors->[0]->baseTables()})); $tbl_name = ${$executors->[0]->baseTables()}[$i]; '' }
      CREATE OR REPLACE TEMPORARY TABLE `tmp` LIKE { $tbl_name }
    ; INSERT INTO `tmp` SELECT * FROM { $tbl_name }
    ; DROP TEMPORARY TABLE IF EXISTS { $tbl_name }
    ; ALTER TABLE `tmp` RENAME TO { $tbl_name }
    ;

drop_temporary_table:
    DROP TEMPORARY TABLE IF EXISTS _table;
