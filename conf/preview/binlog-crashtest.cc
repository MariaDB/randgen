# Copyright (c) 2022, 2025 MariaDB
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

########################################################################

use Data::Dumper;
use strict;

our (%parameters, %options);

require "$ENV{RQG_HOME}/conf/cc/include/parameter_presets";

# Choose options based on $version value
# ($version may be defined via config-version, otherwise 999999 will be used)
local @ARGV = ($version);
require "$ENV{RQG_HOME}/conf/cc/include/versioned_options.pl";

$combinations = [

# Test options
  $options{test_common_option_combinations}, # seed, reporters
  $options{test_concurrency_combinations},   # threads and timeouts
  $options{gendata},
# Disabled for now, too frequent DBD problems
#  $options{optional_ps_protocol},

  [ '--mysqld=--sql-mode=STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER' ],
  [ '--filter=conf/preview/new_binlog.ff --filter=conf/ff/replication.ff --engine=InnoDB --mysqld=--enforce-storage-engine=InnoDB --nometadata-reload' ],
  [ '--mysqld=--binlog-format=mixed', '--mysqld=--binlog-format=row --mysqld=--innodb-force-primary-key' ],
  [
    '--mysqld=--log_bin --mysqld=--binlog_storage_engine=innodb --scenario-use-gtid',
    '--mysqld=--log_bin --mysqld=--binlog_storage_engine=innodb --scenario-use-gtid',
    '--mysqld=--log_bin --mysqld=--binlog_storage_engine=innodb --scenario-use-gtid',
    '--mysqld=--log_bin --mysqld=--binlog_storage_engine=innodb --mysqld=--max_binlog_size=32M --scenario-use-gtid',
  ],
  [ '--mysqld=--binlog-directory=binlogs --mysqld=--ignore-db-dirs=binlogs',
    ''
  ],
  [ '--mysqld=--innodb_flush_log_at_trx_commit=0', '--mysqld=--innodb_flush_log_at_trx_commit=1', '--mysqld=--innodb_flush_log_at_trx_commit=2', '--mysqld=--innodb_flush_log_at_trx_commit=3' ],
  $options{optional_binlog_safe_variables},

  [
    '--grammar=conf/yy/transaction.yy:0.1',
    '--grammar=conf/yy/transaction.yy',
    '--grammar=conf/yy/transaction.yy:0.001'
  ],
  [ '', '', '', '', '', '', '', '', '', '', '--grammar=conf/yy/xa.yy', '--grammar=conf/yy/xa.yy:0.1', '--grammar=conf/yy/xa.yy:0.01'],
  [ '--grammar=conf/yy/bulk_insert.yy', '', '' ],
  [ '--grammar=conf/yy/dml.yy', '' ],
#  [ '--grammar=conf/preview/server_domain_id.yy:0.05', '', '', '', '', '' ],

  [ '--reporter=PurgeBinaryLogs', '', '', '', '' ],


  $options{dml_grammars},

  ##### Engines and scenarios
  [
    {
      random => [
        [
          '','','',
          '--mysqld=--transaction-isolation=READ-UNCOMMITTED',
          '--mysqld=--transaction-isolation=SERIALIZABLE',
          '--mysqld=--transaction-isolation=READ-COMMITTED',
          '--mysqld=--transaction-isolation=REPEATABLE-READ',
        ],
        $options{optional_binlog_safe_variables},
        $options{optional_charsets_safe},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_replication_safe_variables},
        $options{optional_server_variables},
      ],
      random_with_variators => [
        [
          '','','',
          '--mysqld=--transaction-isolation=READ-UNCOMMITTED',
          '--mysqld=--transaction-isolation=SERIALIZABLE',
          '--mysqld=--transaction-isolation=READ-COMMITTED',
          '--mysqld=--transaction-isolation=REPEATABLE-READ',
        ],
        $options{read_only_grammars},
        $options{optional_binlog_safe_variables},
        $options{optional_charsets_safe},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_replication_safe_variables},
        $options{optional_server_variables},
        ['','','','--variator=ExecuteAsDeleteReturning'],
        ['','','','--variator=ExecuteAsExecuteImmediate'],
        ['','','','--variator=ExecuteAsFunctionTwice'],
        ['','','','--variator=ExecuteAsInsertSelect'],
        ['','','','--variator=ExecuteAsPreparedOnce'],
        ['','','','--variator=ExecuteAsSPTwice'],
        ['','','','--variator=ExecuteAsUpdateDelete'],
        ['','','','--variator=ExecuteAsView'],
      ],
      custom_rpl => [
        [ '--engine=InnoDB' ],
        [ '--variator=ExecuteAsOracleSP', '' ],
        [ '--variator=ExecuteAsPackageSP', '' ],
        [ '--grammar=conf/yy/dml.yy' ],
        $options{custom_options_1},
        $options{custom_options_1_master},
        $options{custom_options_1_slave},
      ],
      locking => [
        [ '--grammar=conf/yy/backup-locks.yy --grammar=conf/yy/locks.yy' ],
        [
          '','','',
          '--mysqld=--transaction-isolation=READ-UNCOMMITTED',
          '--mysqld=--transaction-isolation=SERIALIZABLE',
          '--mysqld=--transaction-isolation=READ-COMMITTED',
          '--mysqld=--transaction-isolation=REPEATABLE-READ',
        ],
        $options{optional_binlog_safe_variables},
        $options{optional_charsets_safe},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_replication_safe_variables},
        $options{optional_server_variables},
        $options{read_only_grammars}, $options{dml_grammars},
      ],
    }
  ],
];
