#  Copyright (c) 2024, MariaDB
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

#include <conf/yy/include/basics.inc>

thread1_init:
    dynvar_initial_settings;

query:
    SET SESSION dynvar_session_variable
  | dynvar_global_setting
  | wsrep_table_action
;

wsrep_table_action:
  ==FACTOR:10== SELECT * FROM wsrep_table |
                SET ROLE admin ;; DELETE FROM mysql.wsrep_streaming_log ;; SET ROLE NONE
;

wsrep_table:
  mysql.wsrep_streaming_log | mysql.wsrep_cluster | mysql.wsrep_cluster_members ;

dynvar_initial_settings:
  ==FACTOR:2== dynvar_global_setting /* initial setting */ |
               dynvar_global_setting /* initial setting */ ;; dynvar_initial_settings
;

dynvar_global_setting:
  SET GLOBAL dynvar_global_variable ;

dynvar_session_variable:
                    WSREP_CAUSAL_READS= __0_x_1 /* incompatibility 11.3.0 */
  |                 WSREP_DIRTY_READS= __0_x_1
# Internal server usage, doesn't seem to be settable
# |                 WSREP_GTID_SEQ_NO= { $prng->int(0,18446744073709551615) } /* compatibility 10.5.1 */
# Not settable to ON without provider
  | ==FACTOR:0.01== WSREP_ON= __0_x_1
  |                 WSREP_OSU_METHOD= { $prng->arrayElement(['TOI','RSU']) }
  |                 WSREP_RETRY_AUTOCOMMIT= { $prng->int(0,10000) }
  |                 WSREP_SYNC_WAIT= { $prng->int(0,15) }
  |                 WSREP_TRX_FRAGMENT_SIZE= { $prng->arrayElement(['DEFAULT',0,1,16384,1048576]) } /* compatibility 10.4.2 */
  |                 WSREP_TRX_FRAGMENT_UNIT= { $prng->arrayElement(['bytes',"'rows'",'statements']) } /* compatibility 10.4.2 */
;

dynvar_global_variable:
                     WSREP_AUTO_INCREMENT_CONTROL= __0_x_1
  |                  WSREP_CERTIFICATION_RULES= __strict_x_optimized /* compatibility 10.4.3 */
  |                  WSREP_CERTIFY_NONPK= __0_x_1
# Unsafe
# | wsrep_cluster_name
  |                  WSREP_CONVERT_LOCK_TO_TRX= __0_x_1
# Unused
# | wsrep_dbug_option
# Extremely verbose
  | ==FACTOR:0.001== WSREP_DEBUG= { $prng->arrayElement(['NONE','SERVER','TRANSACTION','STREAMING','CLIENT']) } /* compatibility 10.4.3 */
  |                  WSREP_DEBUG= NONE /* compatibility 10.4.3 */
# Makes the cluster unusable
  | ==FACTOR:0.001== WSREP_DESYNC= __0_x_1
  |                  WSREP_DESYNC= 0
  |                  WSREP_DRUPAL_282555_WORKAROUND= __0_x_1
# WSREP doesn't really work with STATEMENT?
  | ==FACTOR:0.001== WSREP_FORCED_BINLOG_FORMAT= { $prng->arrayElement(['STATEMENT','ROW','MIXED','NONE']) }
  |                  WSREP_FORCED_BINLOG_FORMAT= NONE
  |                  WSREP_GTID_DOMAIN_ID= { $prng->uint16(1,10) }
  |                  WSREP_GTID_MODE= __0_x_1
  |                  WSREP_IGNORE_APPLY_ERRORS= { $prng->uint16(0,7) }
# Deprecated in 10.6
#  | WSREP_LOAD_DATA_SPLITTING= __0_x_1
  |                  WSREP_LOG_CONFLICTS= __0_x_1
  |                  WSREP_MAX_WS_ROWS= { $prng->uint16(0,1048576) }
  |                  WSREP_MAX_WS_SIZE= { $prng->uint16(1024,2147483647) }
# As of 10.6.17-11.5.1:
# STRICT_REPLICATION,BINLOG_ROW_FORMAT_ONLY,REQUIRED_PRIMARY_KEY,REPLICATE_MYISAM,REPLICATE_ARIA,DISALLOW_LOCAL_GTID,BF_ABORT_MARIABACKUP
# Repeated intentionally, to give it higher probability but with focus on REPLICATE_MYISAM/ARIA
  |                  WSREP_MODE= { $prng->uint16(0,127) } /* compatibility 10.6 */
  |                  WSREP_MODE= 'REPLICATE_MYISAM' /* compatibility 10.6 */
  |                  WSREP_MODE= 'REPLICATE_ARIA' /* compatibility 10.6 */
  |                  WSREP_MODE= 'REPLICATE_MYISAM,REPLICATE_ARIA' /* compatibility 10.6 */
  |                  WSREP_NODE_NAME= { 'random_node_name_'.$prng->uint16(1,100) }
# TODO
# | wsrep_provider_options  global
# Don't want it in tests
# | wsrep_reject_queries    global
# Deprecated
# | wsrep_replicate_myisam  global
 |                   WSREP_RESTART_SLAVE= __0_x_1
 |                   WSREP_SLAVE_FK_CHECKS= __0_x_1
# Hangs, MDEV-30418
# |                   WSREP_SLAVE_THREADS= { $prng->uint16(1,8) }
 |                   WSREP_SLAVE_UK_CHECKS= __0_x_1
# TODO (maybe)
# | wsrep_sst_auth  global
# | wsrep_sst_donor global
 |                   WSREP_SST_DONOR_REJECTS_QUERIES= __0_x_1
 |                   WSREP_SST_METHOD= { $prng->arrayElement(['rsync','mysqldump','mariabackup']) }
# | wsrep_sst_receive_address       global
# | wsrep_start_position    global
# Deprecated in 10.6
#  | wsrep_strict_ddl= __0_x_1 /* compatibility 10.5 */
 |                   WSREP_TRX_FRAGMENT_SIZE= { $prng->uint16(0,2147483647) } /* compatibility 10.4 */
 |                   WSREP_TRX_FRAGMENT_UNIT= { $prng->arrayElement(['bytes',"'rows'",'statements']) } /* compatibility 10.4 */
;
