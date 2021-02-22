# Copyright (c) 2008,2012 Oracle and/or its affiliates. All rights reserved.
# Use is subject to license terms.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2020, MariaDB Corporation
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

package GenTest::Executor::MySQL;

require Exporter;

@ISA = qw(GenTest::Executor);

use strict;
use Carp;
use DBI;
use GenTest;
use GenTest::Constants;
use GenTest::Result;
use GenTest::Executor;
use GenTest::QueryPerformance;
use Time::HiRes;
use Digest::MD5;

use constant RARE_QUERY_THRESHOLD    => 5;
use constant MAX_ROWS_THRESHOLD        => 7000000;

my %reported_errors;

my @errors = (
    "The target table .*? of the .*? is",
    "Duplicate entry '.*?' for key '.*?'",
    "Can't DROP '.*?'",
    "Duplicate key name '.*?'",
    "Duplicate column name '.*?'",
    "Record has changed since last read in table '.*?'",
    "savepoint does not exist",
    "'.*?' doesn't exist",
    " .*? does not exist",
    "'.*?' already exists",
    "Unknown database '.*?'",
    "Unknown table '.*?'",
    "Unknown column '.*?'",
    "Unknown event '.*?'",
    "Column '.*?' specified twice",
    "Column '.*?' cannot be null",
    "Column '.*?' in .*? clause is ambiguous",
    "Duplicate partition name .*?",
    "Tablespace '.*?' not empty",
    "Tablespace '.*?' already exists",
    "Tablespace data file '.*?' already exists",
    "Can't find file: '.*?'",
    "Table '.*?' already exists",
    "You can't specify target table '.*?' for update",
    "Illegal mix of collations .*?, .*?, .*? for operation '.*?'",
    "Illegal mix of collations .*? and .*? for operation '.*?'",
    "Invalid .*? character string: '.*?'",
    "This version of MySQL doesn't yet support '.*?'",
    "PROCEDURE .*? already exists",
    "FUNCTION .*? already exists",
    "'.*?' isn't in GROUP BY",
    "non-grouping field '.*?' is used in HAVING clause",
    "Table has no partition for value .*?",
    "Unknown prepared statement handler (.*?) given to EXECUTE",
    "Unknown prepared statement handler (.*?) given to DEALLOCATE PREPARE",
    "Can't execute the query because you have a conflicting read lock",
    "Can't execute the given command because you have active locked tables or an active transaction",
    "Not unique table/alias: '.*?'",
    "View .* references invalid table(s) or column(s) or function(s) or definer/invoker of view lack rights to use them",
    "Unknown thread id: .*?" ,
    "Unknown table '.*?' in .*?",
    "Table '.*?' is read only",
    "Duplicate condition: .*?",
    "Duplicate condition information item '.*?'",
    "Undefined CONDITION: .*?",
    "Incorrect .*? value '.*?'",
    "Recursive limit \d+ (as set by the max_sp_recursion_depth variable) was exceeded for routine .*?",
        "There is no such grant defined for user '.*?' on host '.*?' on table '.*?'",
    "There is no such grant defined for user '.*?' on host '.*?'",
    "'.*?' is not a .*?",
    "Incorrect usage of .*? and .*?",
    "Can't reopen table: '.*?'",
    "Trigger's '.*?' is view or temporary table",
    "Column '.*?' is not updatable"
);

my @patterns = map { qr{$_}i } @errors;

use constant EXECUTOR_MYSQL_AUTOCOMMIT => 101;
use constant EXECUTOR_MYSQL_SERVER_VARIABLES => 102;

#
# Column positions for SHOW SLAVES
#

use constant SLAVE_INFO_HOST => 1;
use constant SLAVE_INFO_PORT => 2;

#
# MySQL error codes
#

use constant  ER_OUTOFMEMORY2                                      => 5;  # returned by some storage engines
use constant  ER_CRASHED1                                        => 126;
use constant  ER_CRASHED2                                        => 145;
use constant  ER_AUTOINCREMENT                                   => 167;
use constant  ER_INCOMPATIBLE_FRM                                => 190;

use constant  ER_CANT_CREATE_TABLE                              => 1005;
use constant  ER_DB_CREATE_EXISTS                               => 1007;
use constant  ER_DB_DROP_EXISTS                                 => 1008;
use constant  ER_CANT_LOCK                                      => 1015;
use constant  ER_FILE_NOT_FOUND                                 => 1017;
use constant  ER_CHECKREAD                                      => 1020;
use constant  ER_DISK_FULL                                      => 1021;
use constant  ER_DUP_KEY                                        => 1022;
use constant  ER_ERROR_ON_RENAME                                => 1025;
use constant  ER_FILSORT_ABORT                                  => 1028;
use constant  ER_GET_ERRNO                                      => 1030;
use constant  ER_ILLEGAL_HA                                     => 1031;
use constant  ER_KEY_NOT_FOUND                                  => 1032;
use constant  ER_NOT_FORM_FILE                                  => 1033;
use constant  ER_NOT_KEYFILE                                    => 1034;
use constant  ER_OPEN_AS_READONLY                               => 1036;
use constant  ER_OUTOFMEMORY                                    => 1037;
use constant  ER_OUT_OF_SORTMEMORY                              => 1038;
use constant  ER_UNEXPECTED_EOF                                 => 1039;
use constant  ER_CON_COUNT_ERROR                                => 1040;
use constant  ER_OUT_OF_RESOURCES                               => 1041;
use constant  ER_DBACCESS_DENIED_ERROR                          => 1044;
use constant  ER_NO_DB_ERROR                                    => 1046;
use constant  ER_BAD_NULL_ERROR                                 => 1048;
use constant  ER_BAD_DB_ERROR                                   => 1049;
use constant  ER_TABLE_EXISTS_ERROR                             => 1050;
use constant  ER_BAD_TABLE_ERROR                                => 1051;
use constant  ER_NON_UNIQ_ERROR                                 => 1052;
use constant  ER_SERVER_SHUTDOWN                                => 1053;
use constant  ER_BAD_FIELD_ERROR                                => 1054;
use constant  ER_WRONG_FIELD_WITH_GROUP                         => 1055;
use constant  ER_WRONG_GROUP_FIELD                              => 1056;
use constant  ER_DUP_FIELDNAME                                  => 1060;
use constant  ER_DUP_KEYNAME                                    => 1061;
use constant  ER_DUP_ENTRY                                      => 1062;
use constant  ER_WRONG_FIELD_SPEC                               => 1063;
use constant  ER_PARSE_ERROR                                    => 1064;
use constant  ER_NONUNIQ_TABLE                                  => 1066;
use constant  ER_INVALID_DEFAULT                                => 1067;
use constant  ER_MULTIPLE_PRI_KEY                               => 1068;
use constant  ER_TOO_MANY_KEYS                                  => 1069;
use constant  ER_TOO_LONG_KEY                                   => 1071;
use constant  ER_KEY_COLUMN_DOES_NOT_EXIST                      => 1072;
use constant  ER_TOO_BIG_FIELDLENGTH                            => 1074;
use constant  ER_WRONG_AUTO_KEY                                 => 1075;
use constant  ER_FILE_EXISTS_ERROR                              => 1086;
use constant  ER_WRONG_SUB_KEY                                  => 1089;
use constant  ER_CANT_REMOVE_ALL_FIELDS                         => 1090;
use constant  ER_CANT_DROP_FIELD_OR_KEY                         => 1091;
use constant  ER_UPDATE_TABLE_USED                              => 1093;
use constant  ER_NO_SUCH_THREAD                                 => 1094;
use constant  ER_TABLE_NOT_LOCKED_FOR_WRITE                     => 1099;
use constant  ER_TABLE_NOT_LOCKED                               => 1100;
use constant  ER_TOO_BIG_SELECT                                 => 1104;
use constant  ER_UNKNOWN_TABLE                                  => 1109;
use constant  ER_FIELD_SPECIFIED_TWICE                          => 1110;
use constant  ER_INVALID_GROUP_FUNC_USE                         => 1111;
use constant  ER_TABLE_MUST_HAVE_COLUMNS                        => 1113;
use constant  ER_RECORD_FILE_FULL                               => 1114;
use constant  ER_TOO_BIG_ROWSIZE                                => 1118;
use constant  ER_STACK_OVERRUN                                  => 1119;
use constant  ER_PASSWORD_NO_MATCH                              => 1133;
use constant  ER_CANT_CREATE_THREAD                             => 1135;
use constant  ER_WRONG_VALUE_COUNT_ON_ROW                       => 1136;
use constant  ER_CANT_REOPEN_TABLE                              => 1137;
use constant  ER_MIX_OF_GROUP_FUNC_AND_FIELDS                   => 1140;
use constant  ER_NONEXISTING_GRANT                              => 1141;
use constant  ER_NO_SUCH_TABLE                                  => 1146;
use constant  ER_NONEXISTING_TABLE_GRANT                        => 1147;
use constant  ER_SYNTAX_ERROR                                   => 1149;
use constant  ER_TABLE_CANT_HANDLE_BLOB                         => 1163;
use constant  ER_WRONG_MRG_TABLE                                => 1168;
use constant  ER_BLOB_KEY_WITHOUT_LENGTH                        => 1170;
use constant  ER_TOO_MANY_ROWS                                  => 1172;
use constant  ER_UPDATE_WITHOUT_KEY_IN_SAFE_MODE                => 1175;
use constant  ER_KEY_DOES_NOT_EXITS                             => 1176;
use constant  ER_CHECK_NOT_IMPLEMENTED                          => 1178;
use constant  ER_FLUSH_MASTER_BINLOG_CLOSED                     => 1186;
use constant  ER_FT_MATCHING_KEY_NOT_FOUND                      => 1191;
use constant  ER_LOCK_OR_ACTIVE_TRANSACTION                     => 1192;
use constant  ER_UNKNOWN_SYSTEM_VARIABLE                        => 1193;
use constant  ER_CRASHED_ON_USAGE                               => 1194;
use constant  ER_TRANS_CACHE_FULL                               => 1197;
use constant  ER_LOCK_WAIT_TIMEOUT                              => 1205;
use constant  ER_WRONG_ARGUMENTS                                => 1210;
use constant  ER_LOCK_DEADLOCK                                  => 1213;
use constant  ER_TABLE_CANT_HANDLE_FT                           => 1214;
use constant  ER_ROW_IS_REFERENCED                              => 1217;
use constant  ER_ERROR_WHEN_EXECUTING_COMMAND                   => 1220;
use constant  ER_WRONG_USAGE                                    => 1221;
use constant  ER_CANT_UPDATE_WITH_READLOCK                      => 1223;
use constant  ER_DUP_ARGUMENT                                   => 1225;
use constant  ER_WRONG_VALUE_FOR_VAR                            => 1231;
use constant  ER_VAR_CANT_BE_READ                               => 1233;
use constant  ER_CANT_USE_OPTION_HERE                           => 1234;
use constant  ER_NOT_SUPPORTED_YET                              => 1235;
use constant  ER_WRONG_FK_DEF                                   => 1239;
use constant  ER_OPERAND_COLUMNS                                => 1241;
use constant  ER_UNKNOWN_STMT_HANDLER                           => 1243;
use constant  ER_ILLEGAL_REFERENCE                              => 1247;
use constant  ER_SPATIAL_CANT_HAVE_NULL                         => 1252;
use constant  ER_WARN_TOO_FEW_RECORDS                           => 1261;
use constant  ER_WARN_TOO_MANY_RECORDS                          => 1262;
use constant  ER_WARN_NULL_TO_NOTNULL                           => 1263;
use constant  ER_WARN_DATA_OUT_OF_RANGE                         => 1264;
use constant  WARN_DATA_TRUNCATED                               => 1265;
use constant  ER_CANT_AGGREGATE_2COLLATIONS                     => 1267;
use constant  ER_CANT_AGGREGATE_3COLLATIONS                     => 1270;
use constant  ER_CANT_AGGREGATE_NCOLLATIONS                     => 1271;
use constant  ER_BAD_FT_COLUMN                                  => 1283;
use constant  ER_UNKNOWN_KEY_CACHE                              => 1284;
use constant  ER_UNKNOWN_STORAGE_ENGINE                         => 1286;
use constant  ER_NON_UPDATABLE_TABLE                            => 1288;
use constant  ER_FEATURE_DISABLED                               => 1289;
use constant  ER_OPTION_PREVENTS_STATEMENT                      => 1290;
use constant  ER_TRUNCATED_WRONG_VALUE                          => 1292;
use constant  ER_UNSUPPORTED_PS                                 => 1295;
use constant  ER_UNKNOWN_TIME_ZONE                              => 1298;
use constant  ER_INVALID_CHARACTER_STRING                       => 1300;
use constant  ER_SP_NO_RECURSIVE_CREATE                         => 1303;
use constant  ER_SP_ALREADY_EXISTS                              => 1304;
use constant  ER_SP_DOES_NOT_EXIST                              => 1305;
use constant  ER_SP_BADSTATEMENT                                => 1314;
use constant  ER_QUERY_INTERRUPTED                              => 1317;
use constant  ER_SP_COND_MISMATCH                               => 1319;
use constant  ER_SP_NORETURNEND                                 => 1321;
use constant  ER_SP_DUP_PARAM                                   => 1330;
use constant  ER_SP_DUP_COND                                    => 1332;
use constant  ER_STMT_NOT_ALLOWED_IN_SF_OR_TRG                  => 1336;
use constant  ER_WRONG_OBJECT                                   => 1347;
use constant  ER_NONUPDATEABLE_COLUMN                           => 1348;
use constant  ER_VIEW_SELECT_DERIVED                            => 1349;
use constant  ER_VIEW_SELECT_TMPTABLE                           => 1352;
use constant  ER_VIEW_INVALID                                   => 1356;
use constant  ER_SP_NO_DROP_SP                                  => 1357;
use constant  ER_TRG_ALREADY_EXISTS                             => 1359;
use constant  ER_TRG_DOES_NOT_EXIST                             => 1360;
use constant  ER_TRG_ON_VIEW_OR_TEMP_TABLE                      => 1361;
use constant  ER_NO_DEFAULT_FOR_FIELD                           => 1364;
use constant  ER_TRUNCATED_WRONG_VALUE_FOR_FIELD                => 1366;
use constant  ER_NO_BINARY_LOGGING                              => 1381;
use constant  ER_KEY_PART_0                                     => 1391;
use constant  ER_VIEW_NO_INSERT_FIELD_LIST                      => 1394;
use constant  ER_VIEW_DELETE_MERGE_VIEW                         => 1395;
use constant  ER_CANNOT_USER                                    => 1396;
use constant  ER_XAER_NOTA                                      => 1397;
use constant  ER_XAER_INVAL                                     => 1398;
use constant  ER_XAER_RMFAIL                                    => 1399;
use constant  ER_XAER_OUTSIDE                                   => 1400;
use constant  ER_NONEXISTING_PROC_GRANT                         => 1403;
use constant  ER_DATA_TOO_LONG                                  => 1406;
use constant  ER_TABLE_DEF_CHANGED                              => 1412;
use constant  ER_SP_DUP_HANDLER                                 => 1413;
use constant  ER_SP_NO_RETSET                                   => 1415;
use constant  ER_CANT_CREATE_GEOMETRY_OBJECT                    => 1416;
use constant  ER_BINLOG_UNSAFE_ROUTINE                          => 1418;
use constant  ER_COMMIT_NOT_ALLOWED_IN_SF_OR_TRG                => 1422;
use constant  ER_NO_DEFAULT_FOR_VIEW_FIELD                      => 1423;
use constant  ER_SP_NO_RECURSION                                => 1424;
use constant  ER_TOO_BIG_SCALE                                  => 1425;
use constant  ER_XAER_DUPID                                     => 1440;
use constant  ER_CANT_UPDATE_USED_TABLE_IN_SF_OR_TRG            => 1442;
use constant  ER_MALFORMED_DEFINER                              => 1446;
use constant  ER_ROW_IS_REFERENCED_2                            => 1451;
use constant  ER_NO_REFERENCED_ROW_2                            => 1452;
use constant  ER_SP_RECURSION_LIMIT                             => 1456;
use constant  ER_SP_PROC_TABLE_CORRUPT                          => 1457;
use constant  ER_NON_GROUPING_FIELD_USED                        => 1463;
use constant  ER_TABLE_CANT_HANDLE_SPKEYS                       => 1464;
use constant  ER_NO_TRIGGERS_ON_SYSTEM_SCHEMA                   => 1465;
use constant  ER_WRONG_STRING_LENGTH                            => 1470;
use constant  ER_NON_INSERTABLE_TABLE                           => 1471;
use constant  ER_ILLEGAL_HA_CREATE_OPTION                       => 1478;
use constant  ER_PARTITION_WRONG_VALUES_ERROR                   => 1480;
use constant  ER_PARTITION_MAXVALUE_ERROR                       => 1481;
use constant  ER_FIELD_NOT_FOUND_PART_ERROR                     => 1488;
use constant  ER_MIX_HANDLER_ERROR                              => 1497;
use constant  ER_BLOB_FIELD_IN_PART_FUNC_ERROR                  => 1502;
use constant  ER_UNIQUE_KEY_NEED_ALL_FIELDS_IN_PF               => 1503;
use constant  ER_NO_PARTS_ERROR                                 => 1504;
use constant  ER_PARTITION_MGMT_ON_NONPARTITIONED               => 1505;
use constant  ER_FOREIGN_KEY_ON_PARTITIONED                     => 1506;
use constant  ER_DROP_PARTITION_NON_EXISTENT                    => 1507;
use constant  ER_DROP_LAST_PARTITION                            => 1508;
use constant  ER_COALESCE_ONLY_ON_HASH_PARTITION                => 1509;
use constant  ER_REORG_HASH_ONLY_ON_SAME_NO                     => 1510;
use constant  ER_REORG_NO_PARAM_ERROR                           => 1511;
use constant  ER_ONLY_ON_RANGE_LIST_PARTITION                   => 1512;
use constant  ER_SAME_NAME_PARTITION                            => 1517;
use constant  ER_PLUGIN_IS_NOT_LOADED                           => 1524;
use constant  ER_WRONG_VALUE                                    => 1525;
use constant  ER_NO_PARTITION_FOR_GIVEN_VALUE                   => 1526;
use constant  ER_EVENT_ALREADY_EXISTS                           => 1537;
use constant  ER_EVENT_DOES_NOT_EXIST                           => 1539;
use constant  ER_EVENT_INTERVAL_NOT_POSITIVE_OR_TOO_BIG         => 1542;
use constant  ER_EVENT_ENDS_BEFORE_STARTS                       => 1543;
use constant  ER_EVENT_SAME_NAME                                => 1551;
use constant  ER_DROP_INDEX_FK                                  => 1553;
use constant  ER_TEMP_TABLE_PREVENTS_SWITCH_OUT_OF_RBR          => 1559;
use constant  ER_STORED_FUNCTION_PREVENTS_SWITCH_BINLOG_FORMAT  => 1560;
use constant  ER_PARTITION_NO_TEMPORARY                         => 1562;
use constant  ER_WRONG_PARTITION_NAME                           => 1567;
use constant  ER_CANT_CHANGE_TX_ISOLATION                       => 1568;
use constant  ER_EVENT_RECURSION_FORBIDDEN                      => 1576;
use constant  ER_EVENTS_DB_ERROR                                => 1577;
use constant  ER_EVENT_CANNOT_ALTER_IN_THE_PAST                 => 1589;
use constant  ER_XA_RBDEADLOCK                                  => 1614;
use constant  ER_NEED_REPREPARE                                 => 1615;
use constant  ER_DELAYED_NOT_SUPPORTED                          => 1616;
use constant  WARN_NO_MASTER_INFO                               => 1617;
use constant  ER_DUP_SIGNAL_SET                                 => 1641;
use constant  ER_SIGNAL_EXCEPTION                               => 1644;
use constant  ER_RESIGNAL_WITHOUT_ACTIVE_HANDLER                => 1645;
use constant  ER_SIGNAL_BAD_CONDITION_TYPE                      => 1646;
use constant  ER_BACKUP_RUNNING                                 => 1651;
use constant  ER_FIELD_TYPE_NOT_ALLOWED_AS_PARTITION_FIELD      => 1659;
use constant  ER_PARTITION_FIELDS_TOO_LONG                      => 1660;
use constant  ER_BINLOG_STMT_MODE_AND_ROW_ENGINE                => 1665;
use constant  ER_BACKUP_SEND_DATA1                              => 1670;
use constant  ER_INSIDE_TRANSACTION_PREVENTS_SWITCH_BINLOG_FORMAT => 1679;
use constant  ER_TABLESPACE_EXIST                               => 1683;
use constant  ER_NO_SUCH_TABLESPACE                             => 1684;
use constant  ER_INSIDE_TRANSACTION_PREVENTS_SWITCH_BINLOG_DIRECT => 1685;
use constant  ER_BACKUP_SEND_DATA2                              => 1687;
use constant  ER_DATA_OUT_OF_RANGE                              => 1690;
use constant  ER_BACKUP_PROGRESS_TABLES                         => 1691;
use constant  ER_INSIDE_TRANSACTION_PREVENTS_SWITCH_SQL_LOG_BIN => 1694;
use constant  ER_SET_PASSWORD_AUTH_PLUGIN                       => 1699;
use constant  ER_MULTI_UPDATE_KEY_CONFLICT                      => 1706;
use constant  ER_INDEX_COLUMN_TOO_LONG                          => 1709;
use constant  ER_TABLESPACE_NOT_EMPTY                           => 1721;
use constant  ER_TABLESPACE_DATAFILE_EXIST                      => 1726;
use constant  ER_PARTITION_EXCHANGE_PART_TABLE                  => 1732;
use constant  ER_PARTITION_INSTEAD_OF_SUBPARTITION              => 1734;
use constant  ER_UNKNOWN_PARTITION                              => 1735;
use constant  ER_PARTITION_CLAUSE_ON_NONPARTITIONED             => 1747;
use constant  ER_ROW_DOES_NOT_MATCH_GIVEN_PARTITION_SET         => 1748;
use constant  ER_BACKUP_NOT_ENABLED                             => 1789;
use constant  ER_CANT_EXECUTE_IN_READ_ONLY_TRANSACTION          => 1792;
use constant  ER_INNODB_NO_FT_TEMP_TABLE                        => 1796;
use constant  ER_FK_NO_INDEX_CHILD                              => 1821;
use constant  ER_FK_NO_INDEX_PARENT                             => 1822;
use constant  ER_DUP_CONSTRAINT_NAME                            => 1826;
use constant  ER_FK_COLUMN_CANNOT_DROP                          => 1828;
use constant  ER_FK_COLUMN_CANNOT_CHANGE                        => 1832;
use constant  ER_FK_COLUMN_CANNOT_CHANGE_CHILD                  => 1833;
use constant  ER_ALTER_OPERATION_NOT_SUPPORTED                  => 1845;
use constant  ER_ALTER_OPERATION_NOT_SUPPORTED_REASON           => 1846;
use constant  ER_VIRTUAL_COLUMN_FUNCTION_IS_NOT_ALLOWED         => 1901;
use constant  ER_KEY_BASED_ON_GENERATED_VIRTUAL_COLUMN          => 1904;
use constant  ER_WARNING_NON_DEFAULT_VALUE_FOR_GENERATED_COLUMN => 1906;
use constant  ER_CONST_EXPR_IN_VCOL                             => 1908;
use constant  ER_UNKNOWN_OPTION                                 => 1911;
use constant  ER_BAD_OPTION_VALUE                               => 1912;
use constant  ER_CANT_DO_ONLINE                                 => 1915;
use constant  ER_CONNECTION_KILLED                              => 1927;
use constant  ER_INSIDE_TRANSACTION_PREVENTS_SWITCH_SKIP_REPLICATION => 1929;
use constant  ER_NO_SUCH_TABLE_IN_ENGINE                        => 1932;
use constant  ER_TARGET_NOT_EXPLAINABLE                         => 1933;
use constant  ER_INSIDE_TRANSACTION_PREVENTS_SWITCH_GTID_DOMAIN_ID_SEQ_NO => 1953;
use constant  ER_INVALID_ROLE                                   => 1959;
use constant  ER_INVALID_CURRENT_USER                           => 1960;
use constant  ER_IT_IS_A_VIEW                                   => 1965;
use constant  ER_STATEMENT_TIMEOUT                              => 1969;

use constant  ER_CONNECTION_ERROR                               => 2002;
use constant  ER_CONN_HOST_ERROR                                => 2003;
use constant  ER_SERVER_GONE_ERROR                              => 2006;
use constant  ER_SERVER_LOST                                    => 2013;
use constant  CR_COMMANDS_OUT_OF_SYNC                           => 2014;  # Caused by old DBD::mysql
use constant  ER_SERVER_LOST_EXTENDED                           => 2055;

#--- MySQL 5.7 ---

use constant  ER_FIELD_IN_ORDER_NOT_SELECT                      => 3065;

#--- MySQL 5.7 JSON-related errors ---

use constant  ER_INVALID_JSON_TEXT                              => 3140;
use constant  ER_INVALID_JSON_TEXT_IN_PARAM                     => 3141;
use constant  ER_INVALID_JSON_BINARY_DATA                       => 3142;
use constant  ER_INVALID_JSON_PATH                              => 3143;
use constant  ER_INVALID_JSON_CHARSET                           => 3144;
use constant  ER_INVALID_JSON_CHARSET_IN_FUNCTION               => 3145;
use constant  ER_INVALID_TYPE_FOR_JSON                          => 3146;
use constant  ER_INVALID_CAST_TO_JSON                           => 3147;
use constant  ER_INVALID_JSON_PATH_CHARSET                      => 3148;
use constant  ER_INVALID_JSON_PATH_WILDCARD                     => 3149;
use constant  ER_JSON_VALUE_TOO_BIG                             => 3150;
use constant  ER_JSON_KEY_TOO_BIG                               => 3151;
use constant  ER_JSON_USED_AS_KEY                               => 3152;
use constant  ER_JSON_VACUOUS_PATH                              => 3153;
use constant  ER_JSON_BAD_ONE_OR_ALL_ARG                        => 3154;
use constant  ER_NUMERIC_JSON_VALUE_OUT_OF_RANGE                => 3155;
use constant  ER_INVALID_JSON_VALUE_FOR_CAST                    => 3156;
use constant  ER_JSON_DOCUMENT_TOO_DEEP                         => 3157;
use constant  ER_JSON_DOCUMENT_NULL_KEY                         => 3158;

#--- end of MySQL 5.7 JSON errors ---

use constant  ER_CONSTRAINT_FAILED                              => 4025;
use constant  ER_EXPRESSION_REFERS_TO_UNINIT_FIELD              => 4026;
use constant  ER_REFERENCED_TRG_DOES_NOT_EXIST                  => 4031;
use constant  ER_UNSUPPORT_COMPRESSED_TEMPORARY_TABLE           => 4047;
use constant  ER_ISOLATION_MODE_NOT_SUPPORTED                   => 4057;
use constant  ER_MYROCKS_CANT_NOPAD_COLLATION                   => 4077;

#--- end of 10.2 errors ---

use constant  ER_ILLEGAL_PARAMETER_DATA_TYPES2_FOR_OPERATION    => 4078;
use constant  ER_SEQUENCE_RUN_OUT                               => 4084;
use constant  ER_SEQUENCE_INVALID_DATA                          => 4085;
use constant  ER_SEQUENCE_INVALID_TABLE_STRUCTURE               => 4086;
use constant  ER_NOT_SEQUENCE                                   => 4089;
use constant  ER_NOT_SEQUENCE2                                  => 4090;
use constant  ER_UNKNOWN_SEQUENCES                              => 4091;
use constant  ER_UNKNOWN_VIEW                                   => 4092;
use constant  ER_COMPRESSED_COLUMN_USED_AS_KEY                  => 4097;
use constant  ER_VERSIONING_REQUIRED                            => 4106;
use constant  ER_INVISIBLE_NOT_NULL_WITHOUT_DEFAULT             => 4108;
use constant  ER_VERS_FIELD_WRONG_TYPE                          => 4110;
use constant  ER_VERS_ENGINE_UNSUPPORTED                        => 4111;
use constant  ER_VERS_ALTER_NOT_ALLOWED                         => 4119;
use constant  ER_VERS_ALTER_ENGINE_PROHIBITED                   => 4120;
use constant  ER_VERS_NOT_VERSIONED                             => 4124;
use constant  ER_MISSING                                        => 4125; # Missing "with system versioning" or "AS ROW START" / "AS ROW END"
use constant  ER_VERS_PERIOD_COLUMNS                            => 4126;
use constant  ER_VERS_WRONG_PARTS                               => 4128;
use constant  ER_VERS_NO_TRX_ID                                 => 4129;
use constant  ER_VERS_ALTER_SYSTEM_FIELD                        => 4130;
use constant  ER_VERS_DUPLICATE_ROW_START_END                   => 4134;
use constant  ER_VERS_ALREADY_VERSIONED                         => 4135;
use constant  ER_VERS_TEMPORARY                                 => 4137;
use constant  ER_BACKUP_LOCK_IS_ACTIVE                          => 4145;
use constant  ER_BACKUP_NOT_RUNNING                             => 4146;
use constant  ER_BACKUP_WRONG_STAGE                             => 4147;

#--- end of 10.3 errors ---

#--- the codes below can still change---

use constant  ER_PERIOD_TEMPORARY_NOT_ALLOWED                   => 4152;
use constant  ER_PERIOD_TYPES_MISMATCH                          => 4153;
use constant  ER_MORE_THAN_ONE_PERIOD                           => 4154;
use constant  ER_PERIOD_FIELD_WRONG_ATTRIBUTES                  => 4155;
use constant  ER_PERIOD_NOT_FOUND                               => 4156;
use constant  ER_PERIOD_COLUMNS_UPDATED                         => 4157;
use constant  ER_PERIOD_CONSTRAINT_DROP                         => 4158;

my %err2type = (

    CR_COMMANDS_OUT_OF_SYNC() => STATUS_ENVIRONMENT_FAILURE,

    ER_ALTER_OPERATION_NOT_SUPPORTED()                  => STATUS_UNSUPPORTED,
    ER_ALTER_OPERATION_NOT_SUPPORTED_REASON()           => STATUS_UNSUPPORTED,
    ER_AUTOINCREMENT()                                  => STATUS_SEMANTIC_ERROR,
    ER_BACKUP_LOCK_IS_ACTIVE()                          => STATUS_SEMANTIC_ERROR,
    ER_BACKUP_NOT_ENABLED()                             => STATUS_ENVIRONMENT_FAILURE,
    ER_BACKUP_NOT_RUNNING()                             => STATUS_SEMANTIC_ERROR,
    ER_BACKUP_PROGRESS_TABLES()                         => STATUS_BACKUP_FAILURE,
    ER_BACKUP_RUNNING()                                 => STATUS_SEMANTIC_ERROR,
    ER_BACKUP_SEND_DATA1()                              => STATUS_BACKUP_FAILURE,
    ER_BACKUP_SEND_DATA2()                              => STATUS_BACKUP_FAILURE,
    ER_BACKUP_WRONG_STAGE()                             => STATUS_SEMANTIC_ERROR,
    ER_BAD_DB_ERROR()                                   => STATUS_SEMANTIC_ERROR,
    ER_BAD_FIELD_ERROR()                                => STATUS_SEMANTIC_ERROR,
    ER_BAD_FT_COLUMN()                                  => STATUS_SEMANTIC_ERROR,
    ER_BAD_NULL_ERROR()                                 => STATUS_SEMANTIC_ERROR,
    # Don't want to suppress it
    # ER_BAD_OPTION_VALUE()                               => STATUS_SEMANTIC_ERROR,
    ER_BAD_TABLE_ERROR()                                => STATUS_SEMANTIC_ERROR,
    ER_BINLOG_STMT_MODE_AND_ROW_ENGINE()                => STATUS_SEMANTIC_ERROR,
    ER_BINLOG_UNSAFE_ROUTINE()                          => STATUS_SEMANTIC_ERROR,
    ER_BLOB_FIELD_IN_PART_FUNC_ERROR()                  => STATUS_SEMANTIC_ERROR,
    ER_BLOB_KEY_WITHOUT_LENGTH()                        => STATUS_SEMANTIC_ERROR,
    ER_CANNOT_USER()                                    => STATUS_SEMANTIC_ERROR,
    ER_CANT_AGGREGATE_2COLLATIONS()                     => STATUS_SEMANTIC_ERROR,
    ER_CANT_AGGREGATE_3COLLATIONS()                     => STATUS_SEMANTIC_ERROR,
    ER_CANT_AGGREGATE_NCOLLATIONS()                     => STATUS_SEMANTIC_ERROR,
    ER_CANT_CHANGE_TX_ISOLATION()                       => STATUS_SEMANTIC_ERROR,
    ER_CANT_CREATE_GEOMETRY_OBJECT()                    => STATUS_SEMANTIC_ERROR,
    ER_CANT_CREATE_TABLE()                              => STATUS_SEMANTIC_ERROR,
    ER_CANT_CREATE_THREAD()                             => STATUS_ENVIRONMENT_FAILURE,
    ER_CANT_DO_ONLINE()                                 => STATUS_SEMANTIC_ERROR,
    ER_CANT_DROP_FIELD_OR_KEY()                         => STATUS_SEMANTIC_ERROR,
    ER_CANT_EXECUTE_IN_READ_ONLY_TRANSACTION()          => STATUS_SEMANTIC_ERROR,
    ER_CANT_LOCK()                                      => STATUS_SEMANTIC_ERROR,
    ER_CANT_REMOVE_ALL_FIELDS()                         => STATUS_SEMANTIC_ERROR,
    ER_CANT_REOPEN_TABLE()                              => STATUS_SEMANTIC_ERROR,
    ER_CANT_UPDATE_USED_TABLE_IN_SF_OR_TRG()            => STATUS_SEMANTIC_ERROR,
    ER_CANT_UPDATE_WITH_READLOCK()                      => STATUS_SEMANTIC_ERROR,
    ER_CANT_USE_OPTION_HERE()                           => STATUS_SEMANTIC_ERROR,
    ER_CHECKREAD()                                      => STATUS_TRANSACTION_ERROR,
    ER_CHECK_NOT_IMPLEMENTED()                          => STATUS_SEMANTIC_ERROR,
    ER_COALESCE_ONLY_ON_HASH_PARTITION()                => STATUS_SEMANTIC_ERROR,
    ER_TOO_BIG_FIELDLENGTH()                            => STATUS_SEMANTIC_ERROR,
    ER_COMMIT_NOT_ALLOWED_IN_SF_OR_TRG()                => STATUS_SEMANTIC_ERROR,
    ER_COMPRESSED_COLUMN_USED_AS_KEY()                  => STATUS_SEMANTIC_ERROR,
    ER_CONNECTION_ERROR()                               => STATUS_SERVER_CRASHED,
    ER_CONNECTION_KILLED()                              => STATUS_SEMANTIC_ERROR,
    ER_CONN_HOST_ERROR()                                => STATUS_SERVER_CRASHED,
    ER_CONSTRAINT_FAILED()                              => STATUS_SEMANTIC_ERROR,
    ER_CONST_EXPR_IN_VCOL()                             => STATUS_SEMANTIC_ERROR,
    ER_CON_COUNT_ERROR()                                => STATUS_ENVIRONMENT_FAILURE,
    ER_CRASHED1()                                       => STATUS_IGNORED_ERROR,
    ER_CRASHED2()                                       => STATUS_IGNORED_ERROR,
    ER_CRASHED_ON_USAGE()                               => STATUS_DATABASE_CORRUPTION,
    ER_DATA_OUT_OF_RANGE()                              => STATUS_SEMANTIC_ERROR,
    ER_DATA_TOO_LONG()                                  => STATUS_SEMANTIC_ERROR,
    ER_DBACCESS_DENIED_ERROR()                          => STATUS_SEMANTIC_ERROR,
    ER_DB_CREATE_EXISTS()                               => STATUS_SEMANTIC_ERROR,
    ER_DB_DROP_EXISTS()                                 => STATUS_SEMANTIC_ERROR,
    ER_DELAYED_NOT_SUPPORTED()                          => STATUS_SEMANTIC_ERROR,
    ER_DISK_FULL()                                      => STATUS_ENVIRONMENT_FAILURE,
    ER_DROP_INDEX_FK()                                  => STATUS_SEMANTIC_ERROR,
    ER_DROP_LAST_PARTITION()                            => STATUS_SEMANTIC_ERROR,
    ER_DROP_PARTITION_NON_EXISTENT()                    => STATUS_SEMANTIC_ERROR,
    ER_DUP_ARGUMENT()                                   => STATUS_SEMANTIC_ERROR,
    ER_DUP_CONSTRAINT_NAME()                            => STATUS_SEMANTIC_ERROR,
    ER_DUP_ENTRY()                                      => STATUS_TRANSACTION_ERROR,
    ER_DUP_FIELDNAME()                                  => STATUS_SEMANTIC_ERROR,
    ER_DUP_KEY()                                        => STATUS_TRANSACTION_ERROR,
    ER_DUP_KEYNAME()                                    => STATUS_SEMANTIC_ERROR,
    ER_DUP_SIGNAL_SET()                                 => STATUS_SEMANTIC_ERROR,
    ER_ERROR_ON_RENAME()                                => STATUS_SEMANTIC_ERROR,
    ER_ERROR_WHEN_EXECUTING_COMMAND()                   => STATUS_SEMANTIC_ERROR,
    ER_EVENT_ALREADY_EXISTS()                           => STATUS_SEMANTIC_ERROR,
    ER_EVENT_CANNOT_ALTER_IN_THE_PAST()                 => STATUS_SEMANTIC_ERROR,
    ER_EVENT_DOES_NOT_EXIST()                           => STATUS_SEMANTIC_ERROR,
    ER_EVENT_ENDS_BEFORE_STARTS()                       => STATUS_SEMANTIC_ERROR,
    ER_EVENT_INTERVAL_NOT_POSITIVE_OR_TOO_BIG()         => STATUS_SEMANTIC_ERROR,
    ER_EVENT_RECURSION_FORBIDDEN()                      => STATUS_SEMANTIC_ERROR,
    ER_EVENT_SAME_NAME()                                => STATUS_SEMANTIC_ERROR,
    ER_EVENTS_DB_ERROR()                                => STATUS_DATABASE_CORRUPTION,
    ER_EXPRESSION_REFERS_TO_UNINIT_FIELD()              => STATUS_SEMANTIC_ERROR,
    ER_FEATURE_DISABLED()                               => STATUS_SEMANTIC_ERROR,
    ER_FIELD_IN_ORDER_NOT_SELECT()                      => STATUS_SEMANTIC_ERROR,
    ER_FIELD_NOT_FOUND_PART_ERROR()                     => STATUS_SEMANTIC_ERROR,
    ER_FIELD_TYPE_NOT_ALLOWED_AS_PARTITION_FIELD()      => STATUS_SEMANTIC_ERROR,
    ER_FIELD_SPECIFIED_TWICE()                          => STATUS_SEMANTIC_ERROR,
    ER_FILE_EXISTS_ERROR()                              => STATUS_SEMANTIC_ERROR,
    ER_FILE_NOT_FOUND()                                 => STATUS_SEMANTIC_ERROR,
    ER_FILSORT_ABORT()                                  => STATUS_SKIP,
    ER_FK_COLUMN_CANNOT_CHANGE()                        => STATUS_SEMANTIC_ERROR,
    ER_FK_COLUMN_CANNOT_CHANGE_CHILD()                  => STATUS_SEMANTIC_ERROR,
    ER_FK_COLUMN_CANNOT_DROP()                          => STATUS_SEMANTIC_ERROR,
    ER_FK_NO_INDEX_CHILD()                              => STATUS_SEMANTIC_ERROR,
    ER_FK_NO_INDEX_PARENT()                             => STATUS_SEMANTIC_ERROR,
    ER_FLUSH_MASTER_BINLOG_CLOSED()                     => STATUS_SEMANTIC_ERROR,
    ER_FOREIGN_KEY_ON_PARTITIONED()                     => STATUS_SEMANTIC_ERROR,
    ER_FT_MATCHING_KEY_NOT_FOUND()                      => STATUS_SEMANTIC_ERROR,
    ER_GET_ERRNO()                                      => STATUS_SEMANTIC_ERROR,
    ER_ILLEGAL_HA()                                     => STATUS_SEMANTIC_ERROR,
    ER_ILLEGAL_HA_CREATE_OPTION()                       => STATUS_UNSUPPORTED,
    ER_ILLEGAL_PARAMETER_DATA_TYPES2_FOR_OPERATION()    => STATUS_SEMANTIC_ERROR,
    ER_ILLEGAL_REFERENCE()                              => STATUS_SEMANTIC_ERROR,
    ER_INCOMPATIBLE_FRM()                               => STATUS_DATABASE_CORRUPTION,
    ER_INDEX_COLUMN_TOO_LONG()                          => STATUS_SEMANTIC_ERROR,
    ER_INNODB_NO_FT_TEMP_TABLE()                        => STATUS_SEMANTIC_ERROR,
    ER_INSIDE_TRANSACTION_PREVENTS_SWITCH_BINLOG_DIRECT()         => STATUS_SEMANTIC_ERROR,
    ER_INSIDE_TRANSACTION_PREVENTS_SWITCH_BINLOG_FORMAT()         => STATUS_SEMANTIC_ERROR,
    ER_INSIDE_TRANSACTION_PREVENTS_SWITCH_GTID_DOMAIN_ID_SEQ_NO() => STATUS_SEMANTIC_ERROR,
    ER_INSIDE_TRANSACTION_PREVENTS_SWITCH_SKIP_REPLICATION()      => STATUS_SEMANTIC_ERROR,
    ER_INSIDE_TRANSACTION_PREVENTS_SWITCH_SQL_LOG_BIN() => STATUS_SEMANTIC_ERROR,
    ER_INVALID_CAST_TO_JSON()                           => STATUS_SEMANTIC_ERROR,
    ER_INVALID_CHARACTER_STRING()                       => STATUS_SEMANTIC_ERROR,
    ER_INVALID_CURRENT_USER()                           => STATUS_SEMANTIC_ERROR, # switch to something critical after MDEV-17943 is fixed
    ER_INVALID_DEFAULT()                                => STATUS_SEMANTIC_ERROR,
    ER_INVALID_GROUP_FUNC_USE()                         => STATUS_SEMANTIC_ERROR,
    ER_INVALID_JSON_BINARY_DATA()                       => STATUS_SEMANTIC_ERROR,
    ER_INVALID_JSON_CHARSET()                           => STATUS_SEMANTIC_ERROR,
    ER_INVALID_JSON_CHARSET_IN_FUNCTION()               => STATUS_SEMANTIC_ERROR,
    ER_INVALID_JSON_PATH()                              => STATUS_SEMANTIC_ERROR,
    ER_INVALID_JSON_PATH_CHARSET()                      => STATUS_SEMANTIC_ERROR,
    ER_INVALID_JSON_PATH_WILDCARD()                     => STATUS_SEMANTIC_ERROR,
    ER_INVALID_JSON_TEXT()                              => STATUS_SEMANTIC_ERROR,
    ER_INVALID_JSON_TEXT_IN_PARAM()                     => STATUS_SEMANTIC_ERROR,
    ER_INVALID_JSON_VALUE_FOR_CAST()                    => STATUS_SEMANTIC_ERROR,
    ER_INVALID_ROLE()                                   => STATUS_SEMANTIC_ERROR,
    ER_INVALID_TYPE_FOR_JSON()                          => STATUS_SEMANTIC_ERROR,
    ER_INVISIBLE_NOT_NULL_WITHOUT_DEFAULT()             => STATUS_SEMANTIC_ERROR,
    ER_ISOLATION_MODE_NOT_SUPPORTED()                   => STATUS_UNSUPPORTED,
    ER_JSON_BAD_ONE_OR_ALL_ARG()                        => STATUS_SEMANTIC_ERROR,
    ER_JSON_DOCUMENT_NULL_KEY()                         => STATUS_SEMANTIC_ERROR,
    ER_JSON_DOCUMENT_TOO_DEEP()                         => STATUS_SEMANTIC_ERROR,
    ER_JSON_KEY_TOO_BIG()                               => STATUS_SEMANTIC_ERROR,
    ER_JSON_VALUE_TOO_BIG()                             => STATUS_SEMANTIC_ERROR,
    ER_JSON_USED_AS_KEY()                               => STATUS_SEMANTIC_ERROR,
    ER_JSON_VACUOUS_PATH()                              => STATUS_SEMANTIC_ERROR,
    ER_IT_IS_A_VIEW()                                   => STATUS_SEMANTIC_ERROR,
    ER_KEY_BASED_ON_GENERATED_VIRTUAL_COLUMN()          => STATUS_SEMANTIC_ERROR,
    ER_KEY_COLUMN_DOES_NOT_EXIST()                      => STATUS_SEMANTIC_ERROR,
    ER_KEY_DOES_NOT_EXITS()                             => STATUS_SEMANTIC_ERROR,
    ER_KEY_NOT_FOUND()                                  => STATUS_IGNORED_ERROR,
    ER_KEY_PART_0()                                     => STATUS_SEMANTIC_ERROR,
    ER_LOCK_DEADLOCK()                                  => STATUS_TRANSACTION_ERROR,
    ER_LOCK_OR_ACTIVE_TRANSACTION()                     => STATUS_SEMANTIC_ERROR,
    ER_LOCK_WAIT_TIMEOUT()                              => STATUS_TRANSACTION_ERROR,
    ER_MALFORMED_DEFINER()                              => STATUS_SEMANTIC_ERROR,
    ER_MISSING()                                        => STATUS_SEMANTIC_ERROR,
    ER_MIX_HANDLER_ERROR()                              => STATUS_SEMANTIC_ERROR,
    ER_MIX_OF_GROUP_FUNC_AND_FIELDS()                   => STATUS_SEMANTIC_ERROR,
    ER_MORE_THAN_ONE_PERIOD()                           => STATUS_SEMANTIC_ERROR,
    ER_MULTIPLE_PRI_KEY()                               => STATUS_SEMANTIC_ERROR,
    ER_MULTI_UPDATE_KEY_CONFLICT()                      => STATUS_SEMANTIC_ERROR,
    ER_MYROCKS_CANT_NOPAD_COLLATION()                   => STATUS_SEMANTIC_ERROR,
    ER_NEED_REPREPARE()                                 => STATUS_SEMANTIC_ERROR,
    ER_NONEXISTING_GRANT()                              => STATUS_SEMANTIC_ERROR,
    ER_NONEXISTING_PROC_GRANT()                         => STATUS_SEMANTIC_ERROR,
    ER_NONEXISTING_TABLE_GRANT()                        => STATUS_SEMANTIC_ERROR,
    ER_NONUNIQ_TABLE()                                  => STATUS_SEMANTIC_ERROR,
    ER_NONUPDATEABLE_COLUMN()                           => STATUS_SEMANTIC_ERROR,
    ER_NON_GROUPING_FIELD_USED()                        => STATUS_SEMANTIC_ERROR,
    ER_NON_INSERTABLE_TABLE()                           => STATUS_SEMANTIC_ERROR,
    ER_NON_UNIQ_ERROR()                                 => STATUS_SEMANTIC_ERROR,
    ER_NON_UPDATABLE_TABLE()                            => STATUS_SEMANTIC_ERROR,
    ER_NOT_FORM_FILE()                                  => STATUS_DATABASE_CORRUPTION,
    ER_NOT_KEYFILE()                                    => STATUS_IGNORED_ERROR,
    ER_NOT_SEQUENCE()                                   => STATUS_SEMANTIC_ERROR,
    ER_NOT_SEQUENCE2()                                  => STATUS_SEMANTIC_ERROR,
    ER_NOT_SUPPORTED_YET()                              => STATUS_UNSUPPORTED,
    ER_NO_BINARY_LOGGING()                              => STATUS_SEMANTIC_ERROR,
    ER_NO_DB_ERROR()                                    => STATUS_SEMANTIC_ERROR,
    ER_NO_DEFAULT_FOR_FIELD()                           => STATUS_SEMANTIC_ERROR,
    ER_NO_DEFAULT_FOR_VIEW_FIELD()                      => STATUS_SEMANTIC_ERROR,
    ER_NO_PARTITION_FOR_GIVEN_VALUE()                   => STATUS_SEMANTIC_ERROR,
    ER_NO_PARTS_ERROR()                                 => STATUS_SEMANTIC_ERROR,
    ER_NO_REFERENCED_ROW_2()                            => STATUS_SEMANTIC_ERROR,
    ER_NO_SUCH_TABLE()                                  => STATUS_SEMANTIC_ERROR,
    ER_NO_SUCH_TABLE_IN_ENGINE()                        => STATUS_DATABASE_CORRUPTION,
    ER_NO_SUCH_TABLESPACE()                             => STATUS_SEMANTIC_ERROR,
    ER_NO_SUCH_THREAD()                                 => STATUS_SEMANTIC_ERROR,
    ER_NO_TRIGGERS_ON_SYSTEM_SCHEMA()                   => STATUS_SEMANTIC_ERROR,
    ER_NUMERIC_JSON_VALUE_OUT_OF_RANGE()                => STATUS_SEMANTIC_ERROR,
    ER_ONLY_ON_RANGE_LIST_PARTITION()                   => STATUS_SEMANTIC_ERROR,
    ER_OPEN_AS_READONLY()                               => STATUS_SEMANTIC_ERROR,
    ER_OPERAND_COLUMNS()                                => STATUS_SEMANTIC_ERROR,
    ER_OPTION_PREVENTS_STATEMENT()                      => STATUS_SEMANTIC_ERROR,
    ER_OUTOFMEMORY()                                    => STATUS_ENVIRONMENT_FAILURE,
    ER_OUTOFMEMORY2()                                   => STATUS_ENVIRONMENT_FAILURE,
    ER_OUT_OF_RESOURCES()                               => STATUS_ENVIRONMENT_FAILURE,
    ER_OUT_OF_SORTMEMORY()                              => STATUS_SEMANTIC_ERROR,
    ER_PARSE_ERROR()                                    => STATUS_SYNTAX_ERROR, # Don't mask syntax errors, fix them instead
    ER_PARTITION_CLAUSE_ON_NONPARTITIONED()             => STATUS_SEMANTIC_ERROR,
    ER_PARTITION_EXCHANGE_PART_TABLE()                  => STATUS_SEMANTIC_ERROR,
    ER_PARTITION_FIELDS_TOO_LONG()                      => STATUS_SEMANTIC_ERROR,
    ER_PARTITION_INSTEAD_OF_SUBPARTITION()              => STATUS_SEMANTIC_ERROR,
    ER_PARTITION_MAXVALUE_ERROR()                       => STATUS_SEMANTIC_ERROR,
    ER_PARTITION_MGMT_ON_NONPARTITIONED()               => STATUS_SEMANTIC_ERROR,
    ER_PARTITION_NO_TEMPORARY()                         => STATUS_SEMANTIC_ERROR,
    ER_PARTITION_WRONG_VALUES_ERROR()                   => STATUS_SEMANTIC_ERROR,
    ER_PASSWORD_NO_MATCH()                              => STATUS_SEMANTIC_ERROR,
    ER_PERIOD_COLUMNS_UPDATED()                         => STATUS_SEMANTIC_ERROR,
    ER_PERIOD_FIELD_WRONG_ATTRIBUTES()                  => STATUS_SEMANTIC_ERROR,
    ER_PERIOD_NOT_FOUND()                               => STATUS_SEMANTIC_ERROR,
    ER_PERIOD_TEMPORARY_NOT_ALLOWED()                   => STATUS_SEMANTIC_ERROR,
    ER_PERIOD_TYPES_MISMATCH()                          => STATUS_SEMANTIC_ERROR,
    ER_PLUGIN_IS_NOT_LOADED()                           => STATUS_SEMANTIC_ERROR,
    ER_QUERY_INTERRUPTED()                              => STATUS_SKIP,
    ER_RECORD_FILE_FULL()                               => STATUS_SEMANTIC_ERROR,
    ER_REFERENCED_TRG_DOES_NOT_EXIST()                  => STATUS_SEMANTIC_ERROR,
    ER_REORG_HASH_ONLY_ON_SAME_NO()                     => STATUS_SEMANTIC_ERROR,
    ER_REORG_NO_PARAM_ERROR()                           => STATUS_SEMANTIC_ERROR,
    ER_RESIGNAL_WITHOUT_ACTIVE_HANDLER()                => STATUS_SEMANTIC_ERROR,
    ER_ROW_DOES_NOT_MATCH_GIVEN_PARTITION_SET()         => STATUS_SEMANTIC_ERROR,
    ER_ROW_IS_REFERENCED()                              => STATUS_SEMANTIC_ERROR,
    ER_ROW_IS_REFERENCED_2()                            => STATUS_SEMANTIC_ERROR,
    ER_SAME_NAME_PARTITION()                            => STATUS_SEMANTIC_ERROR,
    ER_SERVER_GONE_ERROR()                              => STATUS_SEMANTIC_ERROR,
    ER_SERVER_LOST()                                    => STATUS_SERVER_CRASHED,
    ER_SERVER_LOST_EXTENDED()                           => STATUS_SERVER_CRASHED,
    ER_SERVER_SHUTDOWN()                                => STATUS_SERVER_KILLED,
    ER_SEQUENCE_INVALID_DATA()                          => STATUS_SEMANTIC_ERROR,
    ER_SEQUENCE_INVALID_TABLE_STRUCTURE()               => STATUS_SEMANTIC_ERROR,
    ER_SEQUENCE_RUN_OUT()                               => STATUS_SEMANTIC_ERROR,
    ER_SET_PASSWORD_AUTH_PLUGIN()                       => STATUS_SEMANTIC_ERROR,
    ER_SIGNAL_BAD_CONDITION_TYPE()                      => STATUS_SEMANTIC_ERROR,
    ER_SIGNAL_EXCEPTION()                               => STATUS_SEMANTIC_ERROR,
    ER_SP_ALREADY_EXISTS()                              => STATUS_SEMANTIC_ERROR,
    ER_SP_BADSTATEMENT()                                => STATUS_SEMANTIC_ERROR,
    ER_SP_COND_MISMATCH()                               => STATUS_SEMANTIC_ERROR,
    ER_SP_DOES_NOT_EXIST()                              => STATUS_SEMANTIC_ERROR,
    ER_SP_DUP_COND()                                    => STATUS_SEMANTIC_ERROR,
    ER_SP_DUP_HANDLER()                                 => STATUS_SEMANTIC_ERROR,
    ER_SP_DUP_PARAM()                                   => STATUS_SEMANTIC_ERROR,
    ER_SP_NORETURNEND()                                 => STATUS_SEMANTIC_ERROR,
    ER_SP_NO_DROP_SP()                                  => STATUS_SEMANTIC_ERROR,
    ER_SP_NO_RECURSION()                                => STATUS_SEMANTIC_ERROR,
    ER_SP_NO_RECURSIVE_CREATE()                         => STATUS_SEMANTIC_ERROR,
    ER_SP_NO_RETSET()                                   => STATUS_SEMANTIC_ERROR,
#    ER_SP_PROC_TABLE_CORRUPT()                          => STATUS_DATABASE_CORRUPTION,  # this error is bogus due to bug # 47870
    ER_SP_RECURSION_LIMIT()                             => STATUS_SEMANTIC_ERROR,
    ER_SPATIAL_CANT_HAVE_NULL()                         => STATUS_SEMANTIC_ERROR,
    ER_STACK_OVERRUN()                                  => STATUS_ENVIRONMENT_FAILURE,
    ER_STATEMENT_TIMEOUT()                              => STATUS_SKIP,
    ER_STMT_NOT_ALLOWED_IN_SF_OR_TRG()                  => STATUS_SEMANTIC_ERROR,
    ER_STORED_FUNCTION_PREVENTS_SWITCH_BINLOG_FORMAT()  => STATUS_SEMANTIC_ERROR,
    ER_SYNTAX_ERROR()                                   => STATUS_SYNTAX_ERROR,
    ER_TABLESPACE_DATAFILE_EXIST()                      => STATUS_SEMANTIC_ERROR,
    ER_TABLESPACE_EXIST()                               => STATUS_SEMANTIC_ERROR,
    ER_TABLESPACE_NOT_EMPTY()                           => STATUS_SEMANTIC_ERROR,
    ER_TABLE_CANT_HANDLE_BLOB()                         => STATUS_SEMANTIC_ERROR,
    ER_TABLE_CANT_HANDLE_FT()                           => STATUS_SEMANTIC_ERROR,
    ER_TABLE_CANT_HANDLE_SPKEYS()                       => STATUS_SEMANTIC_ERROR,
    ER_TABLE_DEF_CHANGED()                              => STATUS_SEMANTIC_ERROR,
    ER_TABLE_EXISTS_ERROR()                             => STATUS_SEMANTIC_ERROR,
    ER_TABLE_MUST_HAVE_COLUMNS()                        => STATUS_SEMANTIC_ERROR,
    ER_TABLE_NOT_LOCKED()                               => STATUS_SEMANTIC_ERROR,
    ER_TABLE_NOT_LOCKED_FOR_WRITE()                     => STATUS_SEMANTIC_ERROR,
    ER_TARGET_NOT_EXPLAINABLE()                         => STATUS_SEMANTIC_ERROR,
    ER_TEMP_TABLE_PREVENTS_SWITCH_OUT_OF_RBR()          => STATUS_SEMANTIC_ERROR,
    ER_TOO_BIG_ROWSIZE()                                => STATUS_SEMANTIC_ERROR,
    ER_TOO_BIG_SCALE()                                  => STATUS_SEMANTIC_ERROR,
    ER_TOO_BIG_SELECT()                                 => STATUS_SEMANTIC_ERROR,
    ER_TOO_LONG_KEY()                                   => STATUS_SEMANTIC_ERROR,
    ER_TOO_MANY_KEYS()                                  => STATUS_SEMANTIC_ERROR,
    ER_TOO_MANY_ROWS()                                  => STATUS_SEMANTIC_ERROR,
    ER_TRANS_CACHE_FULL()                               => STATUS_SEMANTIC_ERROR, # or STATUS_TRANSACTION_ERROR
    ER_TRG_ALREADY_EXISTS()                             => STATUS_SEMANTIC_ERROR,
    ER_TRG_DOES_NOT_EXIST()                             => STATUS_SEMANTIC_ERROR,
    ER_TRG_ON_VIEW_OR_TEMP_TABLE()                      => STATUS_SEMANTIC_ERROR,
    ER_TRUNCATED_WRONG_VALUE()                          => STATUS_SEMANTIC_ERROR,
    ER_TRUNCATED_WRONG_VALUE_FOR_FIELD()                => STATUS_SEMANTIC_ERROR,
    ER_UNEXPECTED_EOF()                                 => STATUS_DATABASE_CORRUPTION,
    ER_UNIQUE_KEY_NEED_ALL_FIELDS_IN_PF()               => STATUS_SEMANTIC_ERROR,
    ER_UNKNOWN_KEY_CACHE()                              => STATUS_SEMANTIC_ERROR,
    ER_UNKNOWN_OPTION()                                 => STATUS_SEMANTIC_ERROR,
    ER_UNKNOWN_PARTITION()                              => STATUS_SEMANTIC_ERROR,
    ER_UNKNOWN_SEQUENCES()                              => STATUS_SEMANTIC_ERROR,
    ER_UNKNOWN_STMT_HANDLER()                           => STATUS_SEMANTIC_ERROR,
# Some grammars refer to engines which are not always loaded
#    ER_UNKNOWN_STORAGE_ENGINE()                         => STATUS_ENVIRONMENT_FAILURE,
    ER_UNKNOWN_STORAGE_ENGINE()                         => STATUS_SEMANTIC_ERROR,
    ER_UNKNOWN_SYSTEM_VARIABLE()                        => STATUS_SEMANTIC_ERROR,
    ER_UNKNOWN_TABLE()                                  => STATUS_SEMANTIC_ERROR,
    ER_UNKNOWN_TIME_ZONE()                              => STATUS_SEMANTIC_ERROR,
    ER_UNKNOWN_VIEW()                                   => STATUS_SEMANTIC_ERROR,
    ER_UNSUPPORT_COMPRESSED_TEMPORARY_TABLE()           => STATUS_UNSUPPORTED,
    ER_UNSUPPORTED_PS()                                 => STATUS_UNSUPPORTED,
    ER_UPDATE_TABLE_USED()                              => STATUS_SEMANTIC_ERROR,
    ER_UPDATE_WITHOUT_KEY_IN_SAFE_MODE()                => STATUS_SEMANTIC_ERROR,
    ER_VAR_CANT_BE_READ()                               => STATUS_SEMANTIC_ERROR,
    ER_VERS_ALREADY_VERSIONED()                         => STATUS_SEMANTIC_ERROR,
    ER_VERS_ALTER_ENGINE_PROHIBITED()                   => STATUS_SEMANTIC_ERROR,
    ER_VERS_ALTER_NOT_ALLOWED()                         => STATUS_SEMANTIC_ERROR,
    ER_VERS_ALTER_SYSTEM_FIELD()                        => STATUS_SEMANTIC_ERROR,
    ER_VERS_DUPLICATE_ROW_START_END()                   => STATUS_SEMANTIC_ERROR,
    ER_VERS_ENGINE_UNSUPPORTED()                        => STATUS_UNSUPPORTED,
    ER_VERS_FIELD_WRONG_TYPE()                          => STATUS_SEMANTIC_ERROR,
    ER_VERS_NO_TRX_ID()                                 => STATUS_SEMANTIC_ERROR,
    ER_VERS_NOT_VERSIONED()                             => STATUS_SEMANTIC_ERROR,
    ER_VERS_PERIOD_COLUMNS()                            => STATUS_SEMANTIC_ERROR,
    ER_VERS_TEMPORARY()                                 => STATUS_SEMANTIC_ERROR,
    ER_VERS_WRONG_PARTS()                               => STATUS_SEMANTIC_ERROR,
    ER_VERSIONING_REQUIRED()                            => STATUS_SEMANTIC_ERROR,
    ER_VIEW_DELETE_MERGE_VIEW()                         => STATUS_SEMANTIC_ERROR,
    ER_VIEW_INVALID()                                   => STATUS_SEMANTIC_ERROR,
    ER_VIEW_NO_INSERT_FIELD_LIST()                      => STATUS_SEMANTIC_ERROR,
    ER_VIEW_SELECT_DERIVED()                            => STATUS_SEMANTIC_ERROR,
    ER_VIEW_SELECT_TMPTABLE()                           => STATUS_SEMANTIC_ERROR,
    ER_VIRTUAL_COLUMN_FUNCTION_IS_NOT_ALLOWED()         => STATUS_SEMANTIC_ERROR,
    ER_WARN_DATA_OUT_OF_RANGE()                         => STATUS_SEMANTIC_ERROR,
    ER_WARN_NULL_TO_NOTNULL()                           => STATUS_SEMANTIC_ERROR,
    ER_WARN_TOO_FEW_RECORDS()                           => STATUS_SEMANTIC_ERROR,
    ER_WARN_TOO_MANY_RECORDS()                          => STATUS_SEMANTIC_ERROR,
    ER_WARNING_NON_DEFAULT_VALUE_FOR_GENERATED_COLUMN() => STATUS_SEMANTIC_ERROR,
    ER_WRONG_ARGUMENTS()                                => STATUS_SEMANTIC_ERROR,
    ER_WRONG_AUTO_KEY()                                 => STATUS_SEMANTIC_ERROR,
    ER_WRONG_FIELD_SPEC()                               => STATUS_SEMANTIC_ERROR,
    ER_WRONG_FIELD_WITH_GROUP()                         => STATUS_SEMANTIC_ERROR,
    ER_WRONG_FK_DEF()                                   => STATUS_SEMANTIC_ERROR,
    ER_WRONG_GROUP_FIELD()                              => STATUS_SEMANTIC_ERROR,
    ER_WRONG_MRG_TABLE()                                => STATUS_SEMANTIC_ERROR,
    ER_WRONG_OBJECT()                                   => STATUS_SEMANTIC_ERROR,
    ER_WRONG_PARTITION_NAME()                           => STATUS_SEMANTIC_ERROR,
    ER_WRONG_STRING_LENGTH()                            => STATUS_SEMANTIC_ERROR,
    ER_WRONG_SUB_KEY()                                  => STATUS_SEMANTIC_ERROR,
    ER_WRONG_USAGE()                                    => STATUS_SEMANTIC_ERROR,
    ER_WRONG_VALUE()                                    => STATUS_SEMANTIC_ERROR,
    ER_WRONG_VALUE_COUNT_ON_ROW()                       => STATUS_SEMANTIC_ERROR,
    ER_WRONG_VALUE_FOR_VAR()                            => STATUS_SEMANTIC_ERROR,
    ER_XA_RBDEADLOCK()                                  => STATUS_SEMANTIC_ERROR,
    ER_XAER_DUPID()                                     => STATUS_SEMANTIC_ERROR,
    ER_XAER_INVAL()                                     => STATUS_SEMANTIC_ERROR,
    ER_XAER_NOTA()                                      => STATUS_SEMANTIC_ERROR,
    ER_XAER_OUTSIDE()                                   => STATUS_SEMANTIC_ERROR,
    ER_XAER_RMFAIL()                                    => STATUS_SEMANTIC_ERROR,
    
    WARN_DATA_TRUNCATED()                               => STATUS_SEMANTIC_ERROR,
    WARN_NO_MASTER_INFO()                               => STATUS_SEMANTIC_ERROR,
);

# Sub-error numbers (<nr>) from storage engine failures (ER_GET_ERRNO);
# "1030 Got error <nr> from storage engine", which should not lead to
# STATUS_DATABASE_CORRUPTION, as they are acceptable runtime errors.

my %acceptable_se_errors = (
        139                     => "TOO_BIG_ROW"
);

my $query_no = 0;


sub init {
    my $executor = shift;
    my $dbh = DBI->connect($executor->dsn(), undef, undef, {
        PrintError => 0,
        RaiseError => 0,
        AutoCommit => 1,
        mysql_multi_statements => 1,
        mysql_auto_reconnect => 1
    } );

    if (not defined $dbh) {
        say("connect() to dsn ".$executor->dsn()." failed: ".$DBI::errstr);
        return STATUS_ENVIRONMENT_FAILURE;
    }

    $executor->setDbh($dbh);

    my ($host) = $executor->dsn() =~ m/:host=([^:]+):/;
    $executor->setHost($host);
    my ($port) = $executor->dsn() =~ m/:port=([^:]+):/;
    $executor->setPort($port);

    $executor->version();
    $executor->serverVariables();
    if (not defined $executor->compatibility()) {
      $executor->setCompatibility($executor->serverNumericVersion());
    }

    #
    # Hack around bug 35676, optiimzer_switch must be set sesson-wide in order to have effect
    # So we read it from the GLOBAL_VARIABLE table and set it locally to the session
    # Please leave this statement on a single line, which allows easier correct parsing from general log.
    #

    $dbh->do("SET optimizer_switch=(SELECT variable_value FROM INFORMATION_SCHEMA.GLOBAL_VARIABLES WHERE VARIABLE_NAME='optimizer_switch')");
#    $dbh->do("SET TIMESTAMP=".Time::HiRes::time());

    $executor->defaultSchema($executor->currentSchema());

    if (
        ($executor->fetchMethod() == FETCH_METHOD_AUTO) ||
        ($executor->fetchMethod() == FETCH_METHOD_USE_RESULT)
    ) {
        say("Setting mysql_use_result to 1, so mysql_use_result() will be used.") if rqg_debug();
#        $dbh->{'mysql_use_result'} = 1;
    } elsif ($executor->fetchMethod() == FETCH_METHOD_STORE_RESULT) {
        say("Setting mysql_use_result to 0, so mysql_store_result() will be used.") if rqg_debug();
#        $dbh->{'mysql_use_result'} = 0;
    }

    my $cidref= $dbh->selectrow_arrayref("SELECT CONNECTION_ID()");
    if ($dbh->err) {
        sayError("Couldn't get connection ID: " . $dbh->err() . " (" . $dbh->errstr() .")");
    }

    $executor->setConnectionId($cidref->[0]);
    $executor->setCurrentUser($dbh->selectrow_arrayref("SELECT CURRENT_USER()")->[0]);

    say("Executor initialized. id: ".$executor->id()."; default schema: ".$executor->defaultSchema()."; connection ID: ".$executor->connectionId()) if rqg_debug();

    return STATUS_OK;
}

sub reportError {
    my ($self, $query, $err, $errstr, $execution_flags) = @_;

    my $msg = [$query,$err,$errstr];

    if (defined $self->channel) {
        $self->sendError($msg) if not ($execution_flags & EXECUTOR_FLAG_SILENT);
    } elsif (not defined $reported_errors{$errstr}) {
        my $query_for_print= shorten_message($query);
        say("Executor: Query: $query_for_print failed: $err $errstr (" . status2text($err2type{$err} || -1) . "). Further errors of this kind will be suppressed.") if not ($execution_flags & EXECUTOR_FLAG_SILENT);
        $reported_errors{$errstr}++;
    }
}

sub execute {
    my ($executor, $query, $execution_flags) = @_;
    $execution_flags= 0 unless defined $execution_flags;

    if ($query =~ s/\/\*\s*EXECUTOR_FLAG_SILENT\s*\*\///g) {
        $execution_flags |= EXECUTOR_FLAG_SILENT;
    }

    # First check the query for compatibility markers
    my @compat_requirements= $query=~ /\/\*\s*compatibility\s+([\d\.]+(?:e|-[0-9]+)?(?:,[\d\.]+(?:e|-[0-9]+)?)*)\s*\*\//g;
    foreach my $cr (@compat_requirements) {
        my @cr= split /,/, $cr;
        my $compat= 0;
        foreach my $c (@cr) {
            $compat= $executor->is_compatible($c);
            last if $compat;
        }
        unless ($compat) {
            my $err_type= STATUS_SKIP;
            # The query is not compatible with this test run
            $executor->[EXECUTOR_STATUS_COUNTS]->{$err_type}++;
            return GenTest::Result->new(
                        query       => $query,
                        status      => $err_type,
                        err         => 0,
                        errstr      => 'Not compatible',
                        sqlstate    => undef,
                        start_time  => undef,
                        end_time    => undef,
                        performance => undef
                   );

        }
    }

    # Process "reverse executable comments" -- imitation of feature MDEV-7381
    # Syntax is /*!!nnnnnn ... */.
    # If nnnnnn is less than the server version, it should be executed,
    # and we'll convert it into a normal executable comment.
    # Otherwise (if nnnnnn is greater or equal than the server version),
    # it shouldn't be executed, and we'll convert it into a normal comment.

    while ($query =~ /\/\*\!\!(\d+).*?\*\//) {
      my $ver= $1;
      if ($executor->versionNumeric() lt $ver) {
        $query =~ s/\/\*\!\!$ver/\/\*\!/g;
      } else {
        $query =~ s/\/\*\!\!$ver/\/\*/g;
      }
    }

    # It turns out that MySQL fails with a syntax error upon executable comments of the kind /*!100101 ... */
    # (with 6 digits for the version), so we have to process them here as well.
    # To avoid complicated logic, we'll replace such versions with 99999,
    # but only when the server logic is 5xxxx. This way the server won't execute
    # the comment, which is what we need, and we don't need to search for the end of the comment

    if ($executor->versionNumeric() =~ /^05\d{4}$/) {
      while ($query =~ s/\/\*\!1\d{5}/\/\*\!99999/g) {};
    }

    # Filter out any /*executor */ comments that do not pertain to this particular Executor/DBI
    if (index($query, 'executor') > -1) {
        my $executor_id = $executor->id();
        $query =~ s{/\*executor$executor_id (.*?) \*/}{$1}sg;
        $query =~ s{/\*executor.*?\*/}{}sgo;
    }

    # Due to use of empty rules in stored procedure bodies and alike,
    # the query can have a sequence of semicolons "; ;" or "BEGIN ; ..."
    # which will cause syntax error. We'll clean them up
    while ($query =~ s/;\s*;/;/g) {}
    while ($query =~ s/(PROCEDURE.*)BEGIN\s*;/${1}BEGIN /g) {}

    my $qno_comment= 'QNO ' . (++$query_no) . ' CON_ID ' . $executor->connectionId();
    # If a query starts with an executable comment, we'll put QNO right after the executable comment
    if ($query =~ s/^\s*(\/\*\!.*?\*\/)/$1 \/\* $qno_comment \*\//) {}
    # If a query starts with a non-executable comment, we'll put QNO into this comment
    elsif ($query =~ s/^\s*\/\*(.*?)\*\//\/\* $qno_comment $1 \*\//) {}
    # Otherwise we'll put QNO comment after the first token (it should be a keyword specifying the operation)
    elsif ($query =~ s/^\s*(\w+)/$1 \/\* $qno_comment \*\//) {}
    # Finally, if it's something else that we didn't expect, we'll add QNO at the end of the query
    else { $query .= " /* $qno_comment */" };

    # Check for execution flags in query comments. They can, for example,
    # indicate that a query is intentionally invalid, and the error
    # doesn't need to be reported.
    # The format for it is /* EXECUTOR_FLAG_SILENT */, currently only this flag is supported in queries

    # Add global flags if any are set
    $execution_flags = $execution_flags | $executor->flags();

    my $dbh = $executor->dbh();

    return GenTest::Result->new( query => $query, status => STATUS_UNKNOWN_ERROR ) if not defined $dbh;

    $query = $executor->preprocess($query);

    if (
        (not defined $executor->[EXECUTOR_MYSQL_AUTOCOMMIT]) &&
        ($query =~ m{^\s*(start\s+transaction|begin|commit|rollback)}io)
    ) {
        $dbh->do("SET AUTOCOMMIT=OFF");
        $executor->[EXECUTOR_MYSQL_AUTOCOMMIT] = 0;

        if ($executor->fetchMethod() == FETCH_METHOD_AUTO) {
            say("Transactions detected. Setting mysql_use_result to 0, so mysql_store_result() will be used.") if rqg_debug();
            $dbh->{'mysql_use_result'} = 0;
        }
    }

    my $trace_query;
    my $trace_me = 0;


    # Write query to log before execution so it's sure to get there
    if ($executor->sqltrace) {
        if ($query =~ m{(procedure|function)}sgio) {
            $trace_query = "DELIMITER |\n$query|\nDELIMITER ";
        } else {
            $trace_query = $query;
        }
        # MarkErrors logging can only be done post-execution
        if ($executor->sqltrace eq 'MarkErrors') {
            $trace_me = 1;   # Defer logging
        } else {
            print "$trace_query;\n";
        }
    }

    my $performance;

    if ($execution_flags & EXECUTOR_FLAG_PERFORMANCE) {
        $performance = GenTest::QueryPerformance->new(
            dbh => $executor->dbh(),
            query => $query
        );
    }

    my $start_time = Time::HiRes::time();
    my $sth = $dbh->prepare($query);

    if (not defined $sth) {            # Error on PREPARE
        my $errstr_prepare = $executor->normalizeError($dbh->errstr());
        $executor->[EXECUTOR_ERROR_COUNTS]->{$errstr_prepare}++ if not ($execution_flags & EXECUTOR_FLAG_SILENT);
        return GenTest::Result->new(
            query        => $query,
            status        => $err2type{$dbh->err()} || STATUS_UNKNOWN_ERROR,
            err        => $dbh->err(),
            errstr         => $dbh->errstr(),
            sqlstate    => $dbh->state(),
            start_time    => $start_time,
            end_time    => Time::HiRes::time()
        );
    }

    my $affected_rows = $sth->execute();
    my $end_time = Time::HiRes::time();
    my $execution_time = $end_time - $start_time;

    my $err = $sth->err();
    my $errstr = $executor->normalizeError($sth->errstr()) if defined $sth->errstr();
    my $err_type = STATUS_OK;
    if (defined $err) {
      $err_type= $err2type{$err} || STATUS_OK;
      if ($err == ER_GET_ERRNO) {
          my ($se_err) = $sth->errstr() =~ m{^Got error\s+(\d+)\s+from storage engine}sgio;
          $err_type = STATUS_OK if (defined $acceptable_se_errors{$se_err});
      }
    }
    $executor->[EXECUTOR_STATUS_COUNTS]->{$err_type}++ if not ($execution_flags & EXECUTOR_FLAG_SILENT);
    my $mysql_info = $dbh->{'mysql_info'};
    $mysql_info= '' unless defined $mysql_info;
    my ($matched_rows, $changed_rows) = $mysql_info =~ m{^Rows matched:\s+(\d+)\s+Changed:\s+(\d+)}sgio;

    my $column_names = $sth->{NAME} if $sth and $sth->{NUM_OF_FIELDS};
    my $column_types = $sth->{mysql_type_name} if $sth and $sth->{NUM_OF_FIELDS};

    if (defined $performance) {
        $performance->record();
        $performance->setExecutionTime($execution_time);
    }

    if ($trace_me eq 1) {
        if (defined $err) {
                # Mark invalid queries in the trace by prefixing each line.
                # We need to prefix all lines of multi-line statements also.
                $trace_query =~ s/\n/\n# [sqltrace]    /g;
                print '# [$$] [sqltrace] ERROR '.$err.": $trace_query;\n";
        } else {
            print "[$$] $trace_query;\n";
        }
    }

    my $result;
    if (defined $err) {            # Error on EXECUTE

        if ($err_type == STATUS_SYNTAX_ERROR) {
            $executor->[EXECUTOR_ERROR_COUNTS]->{$errstr}++ if not ($execution_flags & EXECUTOR_FLAG_SILENT);
            $err_type= undef;
        }
        if (
            ($err_type == STATUS_SKIP) ||
            ($err_type == STATUS_UNSUPPORTED) ||
            ($err_type == STATUS_SEMANTIC_ERROR) ||
            ($err_type == STATUS_TRANSACTION_ERROR)
        ) {
            $executor->[EXECUTOR_ERROR_COUNTS]->{$errstr}++ if not ($execution_flags & EXECUTOR_FLAG_SILENT);
            $executor->reportError($query, $err, $errstr, $execution_flags);
        } elsif (
            ($err_type == STATUS_SERVER_CRASHED) ||
            ($err_type == STATUS_SERVER_KILLED)
        ) {
            $dbh = DBI->connect($executor->dsn(), undef, undef, {
                PrintError => 0,
                RaiseError => 0,
                AutoCommit => 1,
                mysql_multi_statements => 1,
                mysql_auto_reconnect => 1
            } );

            # If server is still connectable, it is not a real crash, but most likely a KILL query

            if (defined $dbh) {
                say("Executor::MySQL::execute: Successfully reconnected after getting " . status2text($err_type));
                $err_type = STATUS_SEMANTIC_ERROR;
                $executor->setDbh($dbh);
            } else {
                sayError("Executor::MySQL::execute: Failed to reconnect after getting " . status2text($err_type));
            }

            my $query_for_print= shorten_message($query);
            say("Executor::MySQL::execute: Query: $query_for_print failed: $err ".$sth->errstr().($err_type?" (".status2text($err_type).")":"")) if not ($execution_flags & EXECUTOR_FLAG_SILENT);
        } elsif (not ($execution_flags & EXECUTOR_FLAG_SILENT)) {
            $executor->[EXECUTOR_ERROR_COUNTS]->{$sth->errstr()}++;
            my $query_for_print= shorten_message($query);
            say("Executor::MySQL::execute: Query: $query_for_print failed: $err ".$sth->errstr().($err_type?" (".status2text($err_type).")":""));
        }

        $result = GenTest::Result->new(
            query        => $query,
            status        => $err_type || STATUS_UNKNOWN_ERROR,
            err        => $err,
            errstr        => $errstr,
            sqlstate    => $sth->state(),
            start_time    => $start_time,
            end_time    => $end_time,
            performance    => $performance
        );
    } elsif ((not defined $sth->{NUM_OF_FIELDS}) || ($sth->{NUM_OF_FIELDS} == 0)) {
        $result = GenTest::Result->new(
            query        => $query,
            status        => STATUS_OK,
            affected_rows    => $affected_rows,
            matched_rows    => $matched_rows,
            changed_rows    => $changed_rows,
            info        => $mysql_info,
            start_time    => $start_time,
            end_time    => $end_time,
            performance    => $performance
        );
        $executor->[EXECUTOR_ERROR_COUNTS]->{'(no error)'}++ if not ($execution_flags & EXECUTOR_FLAG_SILENT);
    } else {
        my @data;
        my %data_hash;
        my $row_count = 0;
        my $result_status = STATUS_OK;

        while (my @row = $sth->fetchrow_array()) {
            $row_count++;
            if ($execution_flags & EXECUTOR_FLAG_HASH_DATA) {
                $data_hash{substr(Digest::MD5::md5_hex(@row), 0, 3)}++;
            } else {
                push @data, \@row;
            }

            last if ($row_count > MAX_ROWS_THRESHOLD);
        }

        # Do one extra check to catch 'query execution was interrupted' error
        if (defined $sth->err()) {
            $result_status = $err2type{$sth->err()};
            @data = ();
        } elsif ($row_count > MAX_ROWS_THRESHOLD) {
            my $query_for_print= shorten_message($query);
            say("Query: $query_for_print returned more than MAX_ROWS_THRESHOLD (".MAX_ROWS_THRESHOLD().") rows. Killing it ...");
            $executor->[EXECUTOR_RETURNED_ROW_COUNTS]->{'>MAX_ROWS_THRESHOLD'}++;

            my $kill_dbh = DBI->connect($executor->dsn(), undef, undef, { PrintError => 1 });
            $kill_dbh->do("KILL QUERY ".$executor->connectionId());
            $kill_dbh->disconnect();
            $sth->finish();
            $dbh->do("SELECT 1 FROM DUAL /* Guard query so that the KILL QUERY we just issued does not affect future queries */;");
            @data = ();
            $result_status = STATUS_SKIP;
        } elsif ($execution_flags & EXECUTOR_FLAG_HASH_DATA) {
            while (my ($key, $value) = each %data_hash) {
                push @data, [ $key , $value ];
            }
        }

        $result = GenTest::Result->new(
            query        => $query,
            status        => $result_status,
            affected_rows     => $affected_rows,
            data        => \@data,
            start_time    => $start_time,
            end_time    => $end_time,
            column_names    => $column_names,
            column_types    => $column_types,
            performance    => $performance
        );

        $executor->[EXECUTOR_ERROR_COUNTS]->{'(no error)'}++ if not ($execution_flags & EXECUTOR_FLAG_SILENT);
    }

    $sth->finish();

    if ($sth->{mysql_warning_count} > 0) {
        eval {
            my $warnings = $dbh->selectall_arrayref("SHOW WARNINGS");
            $result->setWarnings($warnings);
        }
    }

    if ( (rqg_debug()) && (! ($execution_flags & EXECUTOR_FLAG_SILENT)) ) {
        if ($query =~ m{^\s*select}sio) {
            $executor->explain($query);

            if ($result->status() != STATUS_SKIP) {
                my $row_group = $result->rows() > 100 ? '>100' : ($result->rows() > 10 ? ">10" : sprintf("%5d",$sth->rows()) );
                $executor->[EXECUTOR_RETURNED_ROW_COUNTS]->{$row_group}++;
            }
        } elsif ($query =~ m{^\s*(update|delete|insert|replace)}sio) {
            my $row_group = $affected_rows > 100 ? '>100' : ($affected_rows > 10 ? ">10" : sprintf("%5d",$affected_rows) );
            $executor->[EXECUTOR_AFFECTED_ROW_COUNTS]->{$row_group}++;
        }
    }

    return $result;
}

sub serverVariables {
    my $executor= shift;
    if (not keys %{$executor->[EXECUTOR_MYSQL_SERVER_VARIABLES]}) {
        my $sth = $executor->dbh()->prepare("SHOW VARIABLES");
        $sth->execute();
        my %vars = ();
        while (my $array_ref = $sth->fetchrow_arrayref()) {
            $vars{$array_ref->[0]} = $array_ref->[1];
        }
        $sth->finish();
        $executor->[EXECUTOR_MYSQL_SERVER_VARIABLES] = \%vars;
    }
    return $executor->[EXECUTOR_MYSQL_SERVER_VARIABLES];
}

sub serverVariable {
    my ($executor, $variable_name)= @_;
    return $executor->dbh()->selectrow_array('SELECT @@'.$variable_name);
}

sub version {
    my $executor = shift;
    my $ver= $executor->serverVersion;
    unless ($ver) {
        $ver= $executor->dbh()->selectrow_array("SELECT VERSION()");
        $executor->setServerVersion($ver);
        $ver =~ /([0-9]+)\.([0-9]+)\.([0-9]+)/;
        $executor->setServerNumericVersion(sprintf("%02d%02d%02d",int($1),int($2),int($3)));
        $ver =~ /^(\d+\.\d+)/;
        $executor->setServerMajorVersion($1);
    }
    return $ver;
}

sub versionNumeric {
#    my $executor = shift;
#    version() =~ /([0-9]+)\.([0-9]+)\.([0-9]+)/;
#    return sprintf("%02d%02d%02d",int($1),int($2),int($3));
    return $_[0]->serverNumericVersion;
}

sub majorVersion {
#    my $executor = shift;
#    version() =~ /([0-9]+)\.([0-9]+)\.([0-9]+)/;
#    return sprintf("%02d%02d%02d",int($1),int($2),int($3));
    return $_[0]->serverMajorVersion;
}

sub serverName {
    return ($_[0]->serverVersion =~ /mariadb/i ? 'MariaDB' : 'MySQL');
}

sub slaveInfo {
    my $executor = shift;
    my $slave_info = $executor->dbh()->selectrow_arrayref("SHOW SLAVE HOSTS");
    return ($slave_info->[SLAVE_INFO_HOST], $slave_info->[SLAVE_INFO_PORT]);
}

sub masterStatus {
    my $executor = shift;
    return $executor->dbh()->selectrow_array("SHOW MASTER STATUS");
}

#
# Run EXPLAIN on the query in question, recording all notes in the EXPLAIN's Extra field into the statistics
#

sub explain {
    my ($executor, $query) = @_;

    return unless is_query_explainable($executor,$query);

    my $sth_output = $executor->dbh()->prepare("EXPLAIN /*!50100 PARTITIONS */ $query");

    $sth_output->execute();

    my @explain_fragments;

    while (my $explain_row = $sth_output->fetchrow_hashref()) {
        push @explain_fragments, "select_type: ".($explain_row->{select_type} || '(empty)');

        push @explain_fragments, "type: ".($explain_row->{type} || '(empty)');

        push @explain_fragments, "partitions: ".$explain_row->{table}.":".$explain_row->{partitions} if defined $explain_row->{partitions};

        push @explain_fragments, "ref: ".$explain_row->{ref};

        foreach my $extra_item (split('; ', ($explain_row->{Extra} || '(empty)')) ) {
            $extra_item =~ s{0x.*?\)}{%d\)}sgio;
            $extra_item =~ s{PRIMARY|[a-z_]+_key|i_l_[a-z_]+}{%s}sgio;
            push @explain_fragments, "extra: ".$extra_item;
        }
    }

    $executor->dbh()->do("EXPLAIN EXTENDED $query");
    my $explain_extended = $executor->dbh()->selectrow_arrayref("SHOW WARNINGS");
    if (defined $explain_extended) {
        push @explain_fragments, $explain_extended->[2] =~ m{<[a-z_0-9\-]*?>}sgo;
    }

    foreach my $explain_fragment (@explain_fragments) {
        $executor->[EXECUTOR_EXPLAIN_COUNTS]->{$explain_fragment}++;
        if ($executor->[EXECUTOR_EXPLAIN_COUNTS]->{$explain_fragment} > RARE_QUERY_THRESHOLD) {
            delete $executor->[EXECUTOR_EXPLAIN_QUERIES]->{$explain_fragment};
        } else {
            push @{$executor->[EXECUTOR_EXPLAIN_QUERIES]->{$explain_fragment}}, $query;
        }
    }

}

# If Oracle ever issues 5.10.x, this logic will stop working.
# Until then it should be fine
sub is_query_explainable {
    my ($executor, $query) = @_;
    if ( $executor->majorVersion > 5.5 ) {
        return $query =~ /^\s*(?:SELECT|UPDATE|DELETE|INSERT)/i;
    } else {
        return $query =~ /^\s*SELECT/;
    }
}

sub disconnect {
    my $executor = shift;
    $executor->dbh()->disconnect() if defined $executor->dbh();
    $executor->setDbh(undef);
}

sub DESTROY {
    my $executor = shift;
    $executor->disconnect();

    say("-----------------------");
    say("Statistics for Executor ".$executor->dsn());
    if (
        (rqg_debug()) &&
        (defined $executor->[EXECUTOR_STATUS_COUNTS])
    ) {
        use Data::Dumper;
        $Data::Dumper::Sortkeys = 1;
        say("Rows returned:");
        print Dumper $executor->[EXECUTOR_RETURNED_ROW_COUNTS];
        say("Rows affected:");
        print Dumper $executor->[EXECUTOR_AFFECTED_ROW_COUNTS];
        say("Explain items:");
        print Dumper $executor->[EXECUTOR_EXPLAIN_COUNTS];
        say("Errors:");
        print Dumper $executor->[EXECUTOR_ERROR_COUNTS];
#        say("Rare EXPLAIN items:");
#        print Dumper $executor->[EXECUTOR_EXPLAIN_QUERIES];
    }
    say("Statuses: ".join(', ', map { status2text($_).": ".$executor->[EXECUTOR_STATUS_COUNTS]->{$_}." queries" } sort keys %{$executor->[EXECUTOR_STATUS_COUNTS]}));
    say("-----------------------");
}

sub currentSchema {
    my ($executor,$schema) = @_;

    return undef if not defined $executor->dbh();

    if (defined $schema) {
        $executor->execute("USE $schema");
    }

    return $executor->dbh()->selectrow_array("SELECT DATABASE()");
}


sub errorType {
    return undef if not defined $_[0];
    return $err2type{$_[0]} || STATUS_UNKNOWN_ERROR ;
}

sub normalizeError {
    my ($executor, $errstr) = @_;

    foreach my $i (0..$#errors) {
        last if $errstr =~ s{$patterns[$i]}{$errors[$i]}s;
    }

    $errstr =~ s{\d+}{%d}sgio if $errstr !~ m{from storage engine}sio; # Make all errors involving numbers the same, e.g. duplicate key errors

    $errstr =~ s{\.\*\?}{%s}sgio;

    return $errstr;
}


sub getSchemaMetaData {
    ## Return the result from a query with the following columns:
    ## 1. Schema (aka database) name
    ## 2. Table name
    ## 3. TABLE for tables VIEW for views and MISC for other stuff
    ## 4. Column name
    ## 5. PRIMARY for primary key, INDEXED for indexed column and "ORDINARY" for all other columns
    ## 6. generalized data type (INT, FLOAT, BLOB, etc.)
    ## 7. real data type
    my ($self, $redo) = @_;

    # TODO: recognize SEQUENCE as a separate type with separate logic

    # Unset max_statement_time in case it was set in test configuration
    $self->dbh()->do('/*!100108 SET @@max_statement_time= 0 */');
    my $query = 
        "SELECT DISTINCT ".
                "CASE WHEN table_schema = 'information_schema' ".
                     "THEN 'INFORMATION_SCHEMA' ".  ## Hack due to
                                                    ## weird MySQL
                                                    ## behaviour on
                                                    ## schema names
                                                    ## (See Bug#49708)
                     "ELSE table_schema END AS table_schema, ".
               "table_name, ".
               "CASE WHEN table_type = 'BASE TABLE' THEN 'table' ".
                    "WHEN table_type = 'SYSTEM VERSIONED' THEN 'table' ".
                    "WHEN table_type = 'SEQUENCE' THEN 'table' ".
                    "WHEN table_type = 'VIEW' THEN 'view' ".
                    "WHEN table_type = 'SYSTEM VIEW' then 'view' ".
                    "ELSE 'misc' END AS table_type, ".
               "column_name, ".
               "CASE WHEN column_key = 'PRI' THEN 'primary' ".
                    "WHEN column_key IN ('MUL','UNI') THEN 'indexed' ".
                    "ELSE 'ordinary' END AS column_key, ".
               "CASE WHEN data_type IN ('bit','tinyint','smallint','mediumint','int','bigint') THEN 'int' ".
                    "WHEN data_type IN ('float','double') THEN 'float' ".
                    "WHEN data_type IN ('decimal') THEN 'decimal' ".
                    "WHEN data_type IN ('datetime','timestamp') THEN 'timestamp' ".
                    "WHEN data_type IN ('char','varchar','binary','varbinary') THEN 'char' ".
                    "WHEN data_type IN ('tinyblob','blob','mediumblob','longblob') THEN 'blob' ".
                    "WHEN data_type IN ('tinytext','text','mediumtext','longtext') THEN 'blob' ".
                    "ELSE data_type END AS data_type_normalized, ".
               "data_type, ".
               "character_maximum_length, ".
               "table_rows ".
         "FROM information_schema.tables INNER JOIN ".
              "information_schema.columns USING(table_schema,table_name) ".

          "WHERE table_name <> 'DUMMY'";
    # Do not reload metadata for system tables
    if ($redo) {
      $query.= " AND table_schema NOT IN ('performance_schema','information_schema','mysql')";
    }

    my $res = $self->dbh()->selectall_arrayref($query);
    if ($res) {
        say("Finished reading metadata from the database: $#$res entries");
    } else {
        sayError("Failed to retrieve schema metadata: " . $self->dbh()->err . " " . $self->dbh()->errstr);
    }
    $self->dbh()->do('/*!100108 SET @@max_statement_time= @@global.max_statement_time */');

    return $res;
}

sub getCollationMetaData {
    ## Return the result from a query with the following columns:
    ## 1. Collation name
    ## 2. Character set
    my ($self) = @_;
    my $query =
        "SELECT collation_name,character_set_name FROM information_schema.collations";

    return $self->dbh()->selectall_arrayref($query);
}

sub read_only {
    my $executor = shift;
    my $dbh = $executor->dbh();
    my ($grant_command) = $dbh->selectrow_array("SHOW GRANTS FOR CURRENT_USER()");
    my ($grants) = $grant_command =~ m{^grant (.*?) on}sio;
    if (uc($grants) eq 'SELECT') {
        return 1;
    } else {
        return 0;
    }
}

1;
