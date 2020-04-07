#  Copyright (c) 2020, MariaDB Corporation
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; version 2 of the License.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA */

query_add:
    # MENT-599
    /* compatibility 10.5.2-0 */ SET GLOBAL innodb_purge_threads = { $prng->int(0,33) } |
    # MENT-661
    /* compatibility 10.5.2-0 */ SET GLOBAL innodb_read_io_threads = { $prng->int(0,65) } |
    /* compatibility 10.5.2-0 */ SET GLOBAL innodb_write_io_threads = { $prng->int(0,65) }
;
