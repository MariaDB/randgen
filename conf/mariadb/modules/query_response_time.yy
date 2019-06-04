#  Copyright (c) 2019, MariaDB
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

query_init_add:
    INSTALL SONAME 'query_response_time' ;

query_add:
    query | query | query | query | query | query | plugin_query_response_time ;

plugin_query_response_time:
    SHOW QUERY_RESPONSE_TIME | SHOW QUERY_RESPONSE_TIME | SHOW QUERY_RESPONSE_TIME |
    SHOW QUERY_RESPONSE_TIME | SHOW QUERY_RESPONSE_TIME | SHOW QUERY_RESPONSE_TIME |
    SELECT * FROM INFORMATION_SCHEMA.QUERY_RESPONSE_TIME |
    SELECT * FROM INFORMATION_SCHEMA.QUERY_RESPONSE_TIME |
    FLUSH QUERY_RESPONSE_TIME |
    SET GLOBAL plugin_query_response_vars
;

plugin_query_response_vars:
    plugin_query_response_var | plugin_query_response_var | plugin_query_response_var |
    plugin_query_response_var, plugin_query_response_vars
;

plugin_query_response_var:
    QUERY_RESPONSE_TIME_FLUSH = _basics_off_on |
    QUERY_RESPONSE_TIME_RANGE_BASE = { $prng->int(2,100) } |
    QUERY_RESPONSE_TIME_EXEC_TIME_DEBUG = { $prng->int(0,100000000) } |
    QUERY_RESPONSE_TIME_STATS = _basics_10pct_off_90pct_on
;
