# Copyright (C) 2008-2010 Sun Microsystems, Inc. All rights reserved.
# Use is subject to license terms.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
# USA

#
# This test performs zero-sum queries, that is, queries after which the average value of all integers in the table remains the same.
# Some queries move values within a single row, others between rows and some insert new values or delete existing ones.
#
# The values in the first 10 rows are updated so that values from one row may move into another row. This makes those rows unsuitable for random
# insertions and deletions.
#
# Rows beyond the 10th are just inserted and delted randomly because each row in that part of the table is self-contained
#

#query_init:
#	SET AUTOCOMMIT=OFF ; START TRANSACTION ;

query:
	{ $savepoints = 0; "" }
	START TRANSACTION ; savepoint ; body ; savepoint ; rollback_to_savepoint; commit_rollback ;

body:
	update_all |
	update_multi |
	update_one |
	update_between |
#	update_two |	# Not fully consistent
	update_in |
	insert_one |	# Broken with Falcon
	insert_multi |	# Broken with Falcon
	insert_select | # Broken with Falcon
	insert_delete |	# Broken with Falcon
#	insert_update | # Not fully consistent
	replace |	# Broken in Falcon
	delete_one | 
	delete_multi 
;

savepoint:
	| | | | { ++$savepoints; "SAVEPOINT SP$savepoints" }
;

rollback_to_savepoint:
	| | |
	{ my $x = ($savepoints < 1? "": "ROLLBACK TO SAVEPOINT SP".$prng->int(1,$savepoints--)); $x } |
;

commit_rollback:
	{ $savepoints = 0; "COMMIT" } |
	rollback
;

rollback:
	{ $savepoints = 0; "ROLLBACK" }
;

update_all:
	UPDATE _table SET update_both ;

update_multi:
	UPDATE _table SET update_both WHERE key_nokey_pk > _digit ;

update_one:
	UPDATE _table SET update_both WHERE `pk` = value ;

update_between:
	UPDATE _table SET update_both WHERE `pk` >= half_digit[invariant] AND `pk` <= half_digit[invariant] + 1 |
	UPDATE _table SET update_both WHERE `pk` BETWEEN half_digit[invariant] AND half_digit[invariant] + 1 ;
	
update_two:
	UPDATE table[invariant] SET `col_int_key` = `col_int_key` - 10 WHERE `pk` = small ; UPDATE table[invariant] SET `col_int_key` = `col_int_key` + 10 WHERE `pk` = big ;

update_in:
	UPDATE _table SET update_one_half  + CASE WHEN `pk` % 2 = 1 THEN 30 ELSE -30 END WHERE `pk` IN ( even_odd ) ;

insert_one:
	INSERT INTO _table ( `pk` , `col_int_key` , `col_int`) VALUES ( DEFAULT , 100 , 100 ) |
	INSERT INTO _table ( `pk` ) VALUES ( DEFAULT ) ; rollback ;

insert_multi:
	INSERT INTO _table ( `pk` , `col_int_key` , `col_int`) VALUES ( DEFAULT , 100 , 100 ) , ( DEFAULT , 100 , 100 ) |
	INSERT INTO _table ( `pk` ) VALUES ( DEFAULT ) , ( DEFAULT ) , ( DEFAULT ) ; rollback ;

insert_select:
	INSERT INTO _table ( `col_int_key` , `col_int` ) SELECT `col_int` , `col_int_key` FROM _table WHERE `pk` > 10 ;

insert_delete:
	INSERT INTO table[invariant] ( `pk` , `col_int_key` , `col_int` ) VALUES ( DEFAULT , 50 , 60 ) ; DELETE FROM table[invariant] WHERE `pk` = lastval() ;

insert_update:
	INSERT INTO table[invariant] ( `pk` , `col_int_key` , `col_int` ) VALUES ( DEFAULT, 170 , 180 ) ; UPDATE table[invariant] SET `col_int_key` = `col_int_key` - 80 , `col_int` = `col_int` - 70 WHERE `pk` = _digit ;

replace:
	INSERT INTO _table ( `pk` , `col_int_key` , `col_int` ) VALUES ( DEFAULT, 100 , 100 ) ON CONFLICT ( `pk` ) DO UPDATE SET (`col_int_key` , `col_int`) = (100, 100) |
	INSERT INTO _table ( `pk` ) VALUES ( _digit ) ON CONFLICT ( `pk` ) DO UPDATE SET `pk` = _digit ; rollback ;

delete_one:
	DELETE FROM _table WHERE `pk` = _tinyint_unsigned AND `pk` > 10;

delete_multi:
	DELETE FROM _table WHERE `pk` > _tinyint_unsigned AND `pk` > 10 ;

update_both:
	`col_int_key` = `col_int_key` - 20, `col_int` = `col_int` + 20 |
	`col_int` = `col_int` + 30, `col_int_key` = `col_int_key` - 30 ;

update_one_half:
	`col_int_key` = `col_int_key` |
	`col_int` = `col_int` ;

table:
	_table ;

key_nokey_pk:
	`col_int_key` | `col_int` | `pk` ;

value:
	_digit;

half_digit:
	1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 ;

even_odd:
	odd , even | even , odd ;

odd:
	1 | 3 | 5 | 7 | 9 ;

even:
	2 | 4 | 6 | 8 ;

small:
	1 | 2 | 3 | 4 ;

big:
	5 | 6 | 7 | 8 | 9 ;

_digit:
	1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 ;
