#  Copyright (c) 2019, 2022, MariaDB Corporation Ab
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

#
# The test should be run with
# --mysqld=--plugin-load-add=sql_errlog --mysqld=--loose-sql-errlog
#

query_add:
    ==FACTOR:0.05== SET GLOBAL plugin_sql_errlog_vars ;

plugin_sql_errlog_vars:
    plugin_sql_errlog_var | plugin_sql_errlog_var | plugin_sql_errlog_var |
    plugin_sql_errlog_var, plugin_sql_errlog_vars ;

plugin_sql_errlog_var:
# Not dynamic
#    SQL_ERROR_LOG_FILENAME = plugin_sql_errlog_file |
    SQL_ERROR_LOG_RATE = plugin_sql_errlog_rate |
    SQL_ERROR_LOG_ROTATE =  _basics_off_on
# Not dynamic
#    SQL_ERROR_LOG_ROTATIONS = { $prng->int(0,999) } |
# Not dynamic
#    SQL_ERROR_LOG_SIZE_LIMIT = { $prng->int(0,1024*1024*1024) }
;

plugin_sql_errlog_rate:
    0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 2 | 2 | 2 | 2 | 10 | 100 ;

plugin_sql_errlog_file:
    'sql_errors.log' | 'sqlerr.log' ;
