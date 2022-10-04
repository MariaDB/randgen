# Copyright (C) 2008-2009 Sun Microsystems, Inc. All rights reserved.
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

thread1:
	dml ; SELECT SLEEP (10) ;

query_add:
	select | select | select | select | select |
	select | select | select | select | select |
	select | select | select | select | select |
	dml | dml | dml | dml | dml |
	transaction ;
dml:
	update | insert | delete ;

select:
	SELECT select_item FROM join where order_by limit;

select_item:
	* | X . falcon_limit_field ;

join:
	falcon_limit_table AS X | 
	_big_table AS X LEFT JOIN _small_table AS Y USING ( falcon_limit_field ) ;

where:
	|
	WHERE X . falcon_limit_field < value |
	WHERE X . falcon_limit_field > value |
	WHERE X . falcon_limit_field = value ;

where_delete:
	|
	WHERE falcon_limit_field < value |
	WHERE falcon_limit_field > value |
	WHERE falcon_limit_field = value ;

order_by:
	ORDER BY X . falcon_limit_field ;

delete_order_by:
	ORDER BY falcon_limit_field ;

limit:
	LIMIT digit ;
	
insert:
	INSERT INTO falcon_limit_table ( falcon_limit_field , falcon_limit_field ) VALUES ( value , value ) ;

update:
	UPDATE falcon_limit_table AS X SET falcon_limit_field = value where order_by limit ;

delete:
	DELETE FROM falcon_limit_table where_delete delete_order_by LIMIT digit ;

transaction: START TRANSACTION | COMMIT | ROLLBACK ;

alter:
	ALTER TABLE falcon_limit_table DROP KEY letter |
	ALTER TABLE falcon_limit_table DROP KEY falcon_limit_field |
	ALTER TABLE falcon_limit_table ADD KEY letter ( falcon_limit_field ) ;

value:
	' letter ' | digit | _date | _datetime | _time ;

# Use only medimum - sized tables for this test

falcon_limit_table:
	C | D | E ;

_big_table:
	C | D | E ;

_small_table:
	A | B | C ;

# Use only indexed fields:

falcon_limit_field:
	`col_int_key` | `col_date_key` | `col_datetime_key` | `col_varchar_key` ;

