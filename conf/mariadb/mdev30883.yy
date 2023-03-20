alt_alter_item:
	ENGINE MyISAM |
	RENAME TO { $my_last_table = 't'.$prng->int(1,10) };

alt_query:
	CREATE OR REPLACE TABLE { $my_last_table = 't'.$prng->int(1,10) } ({ $last_column = 'bcol'.$prng->int(1,10) } BIT ) |
	ALTER TABLE { $my_last_table = 't'.$prng->int(1,10) } /*!100301 WAIT _digit */ alt_alter_item;

query:
	alt_query;