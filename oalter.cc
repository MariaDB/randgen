# Copyright (c) 2022, MariaDB
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

our ($common_options, $ps_protocol_options, $views_combinations, $vcols_combinations, $threads_low_combinations, $optional_variators);
our ($basic_engine_combinations, $enforced_engine_combinations, $extra_engine_combinations);
our ($non_crash_scenarios, $crash_scenarios, $mariabackup_scenarios);
our (%server_options, %options);
our ($grammars, $gendata);

my @empty_set= ('','','','','','','','','','','','','','','','','','');

require "$ENV{RQG_HOME}/conf/cc/include/parameter_presets";
require "$ENV{RQG_HOME}/conf/cc/include/combo.grammars";

# Choose options based on $version value
# ($version may be defined via config-version, otherwise 999999 will be used)
local @ARGV = ($version);
require "$ENV{RQG_HOME}/conf/cc/include/versioned_options.pl";

$combinations = [
  # For the  unlikely case when nothing else is picked
  [ $common_options ], # seed, reporters, timeouts
  [ '--threads=1','--threads=2 --grammar=oa-sync.yy --mysqld=--debug-sync-timeout=20','--threads=3','--threads=4' ],
  [ '--duration=180 --mysqld=--max-statement-time=20 --mysqld=--lock-wait-timeout=10 --mysqld=--innodb-lock-wait-timeout=5',
    '--duration=200 --mysqld=--max-statement-time=20 --mysqld=--lock-wait-timeout=10 --mysqld=--innodb-lock-wait-timeout=5',
    '--duration=250 --mysqld=--max-statement-time=25 --mysqld=--lock-wait-timeout=12 --mysqld=--innodb-lock-wait-timeout=10',
    '--duration=300 --mysqld=--max-statement-time=30 --mysqld=--lock-wait-timeout=15 --mysqld=--innodb-lock-wait-timeout=10',
  ],
  [ '--variator=AlterOnline' ],
  [ '--grammar=conf/yy/alter_table.yy:2','--grammar=conf/yy/alter_table_columns.yy:2','--grammar=conf/yy/alter_table_data_types.yy:2' ],
  [ '--grammar=conf/yy/transaction.yy:2','--grammar=conf/yy/dml.yy:2' ],

# @empty_set, @empty_set, 
  [ '--mysqld=--transaction_isolation=READ-UNCOMMITTED', '--mysqld=--transaction_isolation=READ-COMMITTED', '--mysqld=--transaction_isolation=SERIALIZABLE' ],

  [ '--mysqld=--log-bin', '' ],
  [ '--mysqld=--binlog-alter-two-phase=ON', '' ],
  [ '--mysqld=--binlog_annotate_row_events=OFF', '' ],
  [ '--mysqld=--binlog_checksum=NONE', '' ],
  [ '--mysqld=--binlog_commit_wait_count=5', '' ],
  [ '--mysqld=--binlog_direct_non_transactional_updates=on', '' ],
  [ '--mysqld=--binlog-format=mixed', '--mysqld=--binlog-format=mixed','--mysqld=--binlog-format=mixed','--mysqld=--binlog-format=mixed',
    '--mysqld=--binlog-format=row', '--mysqld=--binlog-format=row','--mysqld=--binlog-format=row','--mysqld=--binlog-format=row'
  ],
  [ '--mysqld=--binlog_optimize_thread_scheduling=OFF', '' ],
  [ '--mysqld=--binlog_row_event_max_size=256', '' ],
  [ '--mysqld=--binlog_row_image=NOBLOB', '--mysqld=--binlog_row_image=MINIMAL', '' ],
  [ '--mysqld=--binlog_row_metadata=MINIMAL', '--mysqld=--binlog_row_metadata=FULL', '' ],

  [ '--mysqld=--log_bin_compress=on', '' ],
  [ '--mysqld=--log_bin_compress_min_len=10', '' ],
  [ '--mysqld=--log-slave-updates=on', '--mysqld=--log-slave-updates=off' ],
  [ '--mysqld=--log_bin_trust_function_creators=on', '' ],
  [ '--mysqld=--log_slave_updates=on', '' ],

  [ '--mysqld=--master_verify_checksum=ON', '' ],
  [ '--mysqld=--read_binlog_speed_limit=1024', '' ],

  [ '--mysqld=--replicate_annotate_row_events=OFF', '' ],
  [ '--mysqld=--replicate_events_marked_for_skip=FILTER_ON_SLAVE', '--mysqld=--replicate_events_marked_for_skip=FILTER_ON_MASTER', '' ],

  [ '--mysqld=--slave_compressed_protocol=on', '' ],
  [ '--mysqld=--slave_ddl_exec_mode=STRICT', '' ],
  [ '--mysqld=--slave_exec_mode=IDEMPOTENT', '' ],
  [ '--mysqld=--slave_parallel_mode=conservative', '--mysqld=--slave_parallel_mode=none', '--mysqld=--slave_parallel_mode=aggressive', '--mysqld=--slave_parallel_mode=minimal', '' ],
  [ '--mysqld=--slave_parallel_threads=4', '' ],
  [ '--mysqld=--slave_run_triggers_for_rbr=YES', '' ],
  [ '--mysqld=--slave_sql_verify_checksum=OFF', '' ],
  [ '--mysqld=--slave_type_conversions=ALL_LOSSY','--mysqld=--slave_type_conversions=ALL_NON_LOSSY','--mysqld=--slave_type_conversions=ALL_LOSSY,ALL_NON_LOSSY','','','','' ],

  [ '--mysqld=--innodb-instant-alter-column-allowed=never', '--mysqld=--innodb-instant-alter-column-allowed=add_last', '' ],
  [ '--mysqld=--innodb-online-alter-log-max-size=65536', '--mysqld=--innodb-online-alter-log-max-size=1048576', '' ],
  [ '--mysqld=--system_versioning_alter_history=KEEP', '' ],
  [ '--mysqld=--system_versioning_insert_history=ON', '' ],
  [ '--mysqld=--alter_algorithm=COPY', '--mysqld=--alter_algorithm=INPLACE', '--mysqld=--alter_algorithm=NOCOPY', '--mysqld=--alter_algorithm=INSTANT',
    '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 
  ],
  [ '--mysqld=--max-binlog-cache-size=4096', '--mysqld=--max-binlog-stmt-cache-size=4096',
    '','','','','','','','','','','','','','','','','','','','','','','','',
  ],
  [ '--mysqld=--autocommit=OFF', @empty_set, @empty_set ],
  [ '--mysqld=--concurrent_insert=NEVER', '--mysqld=--concurrent_insert=ALWAYS', @empty_set ],

  [ @$views_combinations, '', '', '', '', '' ],
  [ @$vcols_combinations, '', '', '', '', '' ],
  [ '--mysqld=--low_priority_updates=1', @empty_set ],
  [ '--mysqld=--mysql56_temporal_format=OFF', @empty_set ],
  [ @$optional_variators ],
# Grammars
  [
    [@empty_set, '--grammar=conf/yy/admin.yy'],
    [@empty_set, '--grammar=conf/yy/application_periods.yy'],
    [@empty_set, '--grammar=conf/yy/backup-locks.yy:0.01'],
    [@empty_set, '--grammar=conf/yy/bulk_insert.yy'],
    [@empty_set, '--grammar=conf/yy/collect_eits.yy'],
    [@empty_set, '--grammar=conf/yy/concurrent.yy'],
    [@empty_set, '--grammar=conf/yy/current_timestamp.yy --gendata=conf/zz/current_timestamp.zz'],
    [@empty_set, '--grammar=conf/yy/dbt3-dml.yy --gendata=data/dbt3/dbt3-s0.0001.dump'],
    [@empty_set, '--grammar=conf/yy/desc_indexes.yy'],
    [@empty_set, '--grammar=conf/yy/dml.yy'],
    [@empty_set, '--grammar=conf/yy/dml-ps-params.yy'],
    [@empty_set, '--grammar=conf/yy/dyncol_dml.yy --gendata=conf/zz/dyncol_dml.zz'],
    [@empty_set, '--grammar=conf/yy/event.yy:0.1'],
    [@empty_set, '--grammar=conf/yy/foreign_keys.yy'], # Unsafe for replication
    [@empty_set, '--grammar=conf/yy/full_text_search.yy --gendata=conf/zz/full_text_search.zz'],
    [@empty_set, '--grammar=conf/yy/functions.yy'],
    [@empty_set, '--grammar=conf/yy/gis.yy'],
    [@empty_set, '--grammar=conf/yy/indexes_and_constraints.yy'],
    [@empty_set, '--grammar=conf/yy/locks.yy:0.1'],
    [@empty_set, '--grammar=conf/yy/many_indexes.yy'],
    [@empty_set, '--grammar=conf/yy/multiple_triggers.yy'],
    [@empty_set, '--grammar=conf/yy/multi_update.yy --gendata=simple'],
    [@empty_set, '--grammar=conf/yy/oltp-write.yy --gendata=conf/zz/oltp.zz', '--grammar=conf/yy/oltp-write.yy --gendata=conf/zz/oltp-aria.zz'],
    [@empty_set, '--grammar=conf/yy/random_keys.yy'],
    [@empty_set, '--grammar=conf/yy/replication.yy'],
    [@empty_set, '--grammar=conf/yy/sequences.yy'],
    [@empty_set, '--grammar=conf/yy/signal_resignal.yy'],
    [@empty_set, '--grammar=conf/yy/sql_mode.yy:0.01'],
    [@empty_set, '--grammar=conf/yy/transaction.yy'],
    [@empty_set, '--grammar=conf/yy/trx_stress.yy'],
    [@empty_set, '--grammar=conf/yy/versioning.yy'],
    [@empty_set, '--grammar=conf/yy/virtual_columns.yy'],
    [@empty_set, '--grammar=conf/yy/xa.yy'],
  ],
  [ @$gendata ],
  ##### Scenarios
  [
    {
      standard => [
        [ '--scenario=Standard' ],
        [ 
          @$basic_engine_combinations,
          @$extra_engine_combinations,
          '--engine=InnoDB', '--engine=InnoDB --mysqld=--default-storage-engine=InnoDB',
          '--engine=Aria', '--engine=Aria --mysqld=--default-storage-engine=Aria',
          '--engine=MyISAM', '--engine=MyISAM --mysqld=--default-storage-engine=MyISAM'
        ],
        [ '--mysqld=--binlog_ignore_db=test', '', '', '', '', '', '' ],
        [ '--mysqld=--replicate_ignore_db=test', '',  '',  '',  '',  '',  '',  '' ],
        [ "--mysqld=--replicate_rewrite_db='test->test'", '', '', '' ],
        [ '--mysqld=--replicate_wild_ignore_table=test.t%', '', '' , '' , '' ],
        [ '--mysqld=--binlog-format=statement', '', '', '', '', '', '', '', '', '', '', '', '' ],
        [ '--mysqld=--binlog_expire_logs_seconds=100', '' ],
        [ @empty_set, '--grammar=conf/yy/dynamic_variables.yy:0.01'],
        [ @{$options{optional_charsets}} ],
        [ '--threads=2 --grammar=oa-sync.yy --mysqld=--debug-sync-timeout=10', @empty_set ],
        [ @empty_set, $options{all_encryption_options} ],
      ],
      binlog => [
        [ '--scenario=Standard --reporters=BinlogConsistency --mysqld=--log-bin' ],
        [ 
          @$basic_engine_combinations,
          @$extra_engine_combinations,
          '--engine=InnoDB', '--engine=InnoDB --mysqld=--default-storage-engine=InnoDB',
          '--engine=Aria', '--engine=Aria --mysqld=--default-storage-engine=Aria',
          '--engine=MyISAM', '--engine=MyISAM --mysqld=--default-storage-engine=MyISAM'
        ],
        [ @{$options{safe_charsets}} ],
        # Cannot have binlog encryption here
        [ @empty_set, @empty_set, $options{aria_encryption_options}, $options{innodb_encryption_options} ],
      ],
      index => [
        [ '--scenario=Standard --reporters=SecondaryIndexConsistency' ],
        [ 
          @$basic_engine_combinations,
          @$extra_engine_combinations,
          '--engine=InnoDB', '--engine=InnoDB --mysqld=--default-storage-engine=InnoDB',
          '--engine=Aria', '--engine=Aria --mysqld=--default-storage-engine=Aria',
          '--engine=MyISAM', '--engine=MyISAM --mysqld=--default-storage-engine=MyISAM'
        ],
        [ @{$options{safe_charsets}} ],
        [ @empty_set, $options{all_encryption_options} ],
      ],
      restart => [
        [ '--scenario=Restart' ],
        [ 
          @$basic_engine_combinations,
          @$extra_engine_combinations,
          '--engine=InnoDB', '--engine=InnoDB --mysqld=--default-storage-engine=InnoDB',
          '--engine=Aria', '--engine=Aria --mysqld=--default-storage-engine=Aria',
          '--engine=MyISAM', '--engine=MyISAM --mysqld=--default-storage-engine=MyISAM'
        ],
        [@empty_set, '--grammar=conf/yy/dynamic_variables.yy:0.01'],
        [ @{$options{optional_charsets}} ],
        [ @empty_set, $options{all_encryption_options} ],
      ],
      recovery => [
        [ @$crash_scenarios ],
        [
          '--engine=InnoDB', '--engine=InnoDB --mysqld=--default-storage-engine=InnoDB',
          '--engine=Aria', '--engine=Aria --mysqld=--default-storage-engine=Aria'
        ],
        [ @{$options{safe_charsets}} ],
        [ @empty_set, $options{all_encryption_options} ],
      ],
      upgrade_backup => [
        [ @$mariabackup_scenarios ],
        [ @$basic_engine_combinations ],
        [ @{$options{safe_charsets}} ],
        [ @empty_set, $options{all_encryption_options} ],
      ],
      replication => [
        [ '--scenario=Replication' ],
        [ @$basic_engine_combinations ],
        [ @{$options{safe_charsets}} ],
        [ @empty_set, @empty_set, $options{all_encryption_options}, $options{non_innodb_encryption_options} ],
      ],
      cluster => [
        [ '--scenario=Replication', '--scenario=Galera' ],
        [ '--engine=InnoDB --mysqld=--default-storage-engine=InnoDB' ],
        [ @{$options{safe_charsets}} ],
        [ @empty_set, $options{all_encryption_options} ],
      ]
    }
  ],
  ##### Engine options
  [ @{$options{optional_innodb_variables}}, @{$options{innodb_compression_combinations}} ],
  [ @{$options{optional_aria_variables}} ],
  ##### Plugins
  [ @{$options{optional_plugins}} ],
  ##### PS protocol and low values of max-prepared-stmt-count
  [ '', '', '', '', '', '', '', '', '', '', $ps_protocol_options ],
  ##### Performance schema
  [ '', '', '', '', '', '', '', '', '', $options{perfschema_options}->[0] . ' --grammar=conf/yy/performance_schema.yy'],
  ##### Startup variables (general)
  [ @{$options{optional_server_variables}} ],
];
