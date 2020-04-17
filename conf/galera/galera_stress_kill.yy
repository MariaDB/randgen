# Copyright (C) 2008 Sun Microsystems, Inc. All rights reserved.
# Copyright (c) 2013, Monty Program Ab.
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
# This grammar is a slightly modified version of engine_stress.yy,
# suitable for Galera testing
#

query:
	transaction |
	select | select |
	select | select |
	insert_replace | update | delete |
	insert_replace | update | delete |
	insert_replace | update | delete | ddl |
	insert_replace | update | delete | kill_query | ddl |
	insert_replace | update | delete | kill_query | ddl ;

ddl: base_table_ddl | base_table_ddl | base_table_ddl |
     truncate_table | table_maintenance_ddl ;

# Useful grammar rules ====================================================================================#

rand_val:
	{ $rand_val = $prng->int(0,100) / 100 } ;


kill_query:
        COMMIT ; own_id ; COMMIT; KILL QUERY @kill_id ; COMMIT ;

own_id:
        SET @kill_id = CONNECTION_ID();

ddl:
        COMMIT; CREATE TABLE IF NOT EXISTS galera_parent(a int not null primary key, b int , c int,key(b)) engine=innodb;
	CREATE TABLE IF NOT EXISTS galera_child(a int not null primary key, b int, c int, FOREIGN KEY (b) references galera_parent(b) ON UPDATE CASCADE ON DELETE CASCADE) engine=innodb;
	INSERT INTO galera_parent VALUES (1,1,1),(2,2,2),(3,3,3),(4,4,4),(5,5,5),(6,6,6);
	INSERT INTO galera_child VALUES (1,1,1),(2,2,2),(3,2,2)(4,4,4),(5,2,5),(6,3,3),(7,6,6);
	UPDATE galera_parent set b = b + 100 where b = 2;
	DELETE galera_parent where b = 102;
	OPTIMIZE TABLE galera_child;
	ANALYZE TABLE galera_parent;
	TRUNCATE TABLE galera_child;
	DROP TABLE IF EXISTS galera_child;
	DROP TABLE IF EXISTS galera_parent; COMMIT;

transaction:
	START TRANSACTION |
	COMMIT ; SET TRANSACTION ISOLATION LEVEL isolation_level |
	ROLLBACK ; SET TRANSACTION ISOLATION LEVEL isolation_level |
	SET AUTOCOMMIT=OFF | SET AUTOCOMMIT=ON ;

isolation_level:
	READ UNCOMMITTED | READ COMMITTED | REPEATABLE READ | SERIALIZABLE ;

select:
	SELECT select_list FROM join_list where LIMIT large_digit;

select_list:
	X . _field_key | X . _field_key |
	X . `pk` |
	X . _field |
	* |
	( subselect );

subselect:
	SELECT _field_key FROM _table WHERE `pk` = value ;

# Use index for all joins
join_list:
	_table AS X | 
	_table AS X LEFT JOIN _table AS Y USING ( _field_key );


# Insert more than we delete
insert_replace:
	i_r INTO _table (`pk`) VALUES (NULL) |
	i_r INTO _table ( _field_no_pk , _field_no_pk ) VALUES ( value , value ) , ( value , value ) |
	i_r INTO _table ( _field_no_pk ) SELECT _field_key FROM _table AS X where;

i_r:
	INSERT ignore |
	REPLACE;

ignore:
	| 
	IGNORE ;

update:
	UPDATE ignore _table AS X SET _field_no_pk = value where;

# We use a smaller limit on DELETE so that we delete less than we insert

delete:
	DELETE ignore FROM _table where_delete;

# Use an index at all times
where:
	|
	WHERE X . _field_key < value | 	# Use only < to reduce deadlocks
	WHERE X . _field_key IN ( value , value , value , value , value ) |
	WHERE X . _field_key BETWEEN small_digit AND large_digit |
	WHERE X . _field_key BETWEEN _tinyint_unsigned AND _int_unsigned |
	WHERE X . _field_key = ( subselect ) ;

where_delete:
	|
	WHERE _field_key = value |
	WHERE _field_key IN ( value , value , value , value , value ) |
	WHERE _field_key IN ( subselect ) |
	WHERE _field_key BETWEEN small_digit AND large_digit ;

large_digit:
	5 | 6 | 7 | 8 ;

small_digit:
	1 | 2 | 3 | 4 ;

value:
	_digit | _tinyint_unsigned | _varchar(1) | _int_unsigned ;

zero_one:
	0 | 0 | 1;
