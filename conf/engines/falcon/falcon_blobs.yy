# Copyright (C) 2008 Sun Microsystems, Inc. All rights reserved.
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

query_init_add:
	START TRANSACTION ;

query_add:
 	update | insert | delete ;

update:
 	UPDATE _table SET _field_no_pk = value WHERE condition LIMIT 1 ;

delete:
	DELETE FROM _table WHERE condition LIMIT 1 ;

insert:
	INSERT INTO _table ( _field ) VALUES ( value ) ;

condition:
	pk = _digit ;

value:
	_data | _varchar(1024) ;