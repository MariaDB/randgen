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
# --mysqld=--plugin-load-add=server_audit --mysqld=--loose-server-audit --mysqld=--loose-server-audit-logging=on
#

query:
    ==FACTOR:0.05== SET GLOBAL plugin_server_audit_var ;

plugin_server_audit_vars:
    plugin_server_audit_var | plugin_server_audit_var, plugin_server_audit_vars ;

plugin_server_audit_var:
    SERVER_AUDIT_EVENTS = plugin_server_audit_events |
# Variables disabled due to MDEV-19665
#    SERVER_AUDIT_EXCL_USERS = plugin_server_audit_users |
#    SERVER_AUDIT_FILE_PATH = plugin_server_audit_file |
#    SERVER_AUDIT_FILE_ROTATE_NOW = __on_x_off(90) |
#    SERVER_AUDIT_FILE_ROTATE_SIZE = { $prng->int(100,1024*1024*1024) } |
#    SERVER_AUDIT_FILE_ROTATIONS = { $prng->int(0,999) } |
#    SERVER_AUDIT_INCL_USERS = plugin_server_audit_users |
#    SERVER_AUDIT_LOGGING = __on_x_off(90) |
#    SERVER_AUDIT_MODE = plugin_server_audit_mostly_0 |
#    SERVER_AUDIT_OUTPUT_TYPE = plugin_server_audit_output |
    SERVER_AUDIT_QUERY_LOG_LIMIT = { $prng->int(0,1024*1024*1024) } |
    SERVER_AUDIT_SYSLOG_FACILITY = plugin_server_audit_facility |
#    SERVER_AUDIT_SYSLOG_IDENT = plugin_server_audit_string |
    SERVER_AUDIT_SYSLOG_INFO = plugin_server_audit_string
#    SERVER_AUDIT_SYSLOG_PRIORITY = plugin_server_audit_priority
;

plugin_server_audit_events:
    { @events= qw(CONNECT QUERY TABLE QUERY_DDL QUERY_DML QUERY_DML_NO_SELECT QUERY_DCL)
      ; $length=$prng->int(1,scalar(@events)); "'" . (join ',', @{$prng->shuffleArray(\@events)}[0..$length]) . "'" }
;

plugin_server_audit_users:
    '' |
    { @users= ('root@localhost','rqg@localhost','root','rqg'); $length=$prng->int(1,scalar(@users)); "'" . (join ',', @{$prng->shuffleArray(\@users)}[0..$length]) . "'" }
;

plugin_server_audit_file:
    'server_audit.log' | 'audit.log' ;

plugin_server_audit_mostly_0:
    0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 ;

plugin_server_audit_output:
    file | file | file | file | file | syslog ;

plugin_server_audit_facility:
    LOG_USER | LOG_MAIL | LOG_DAEMON | LOG_AUTH | LOG_SYSLOG | LOG_LPR |
    LOG_NEWS | LOG_UUCP | LOG_CRON | LOG_AUTHPRIV | LOG_FTP | LOG_LOCAL0 |
    LOG_LOCAL1 | LOG_LOCAL2 | LOG_LOCAL3 | LOG_LOCAL4 | LOG_LOCAL5 |
    LOG_LOCAL6 | LOG_LOCAL7
;

plugin_server_audit_string:
    NULL | 'mysql-server_auditing' | '>>>' | '' ;

plugin_server_audit_priority:
    LOG_EMERG | LOG_ALERT | LOG_CRIT | LOG_ERR | LOG_WARNING |
    LOG_NOTICE | LOG_INFO | LOG_DEBUG
;
