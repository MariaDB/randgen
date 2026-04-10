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

use lib "$ENV{RQG_HOME}/conf/cc/include";
use ConfigCommon qw($combinations %options);
require "$ENV{RQG_HOME}/conf/cc/small.cc";

push @$combinations, (
  [
    {
      acl => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ '--grammar=conf/yy/acl.yy', '--grammar=conf/yy/create_user.yy'],
        ['
          --mysqld=--plugin-load-add=auth_0x0100.so
          --mysqld=--plugin-load-add=auth_ed25519.so
          --mysqld=--plugin-load-add=auth_pam.so
          --mysqld=--plugin-load-add=password_reuse_check.so
          --mysqld=--plugin-load-add=cracklib_password_check.so
          --mysqld=--plugin-load-add=simple_password_check.so
          --mysqld=--loose-password-reuse-check-interval=1
        '],
        $options{engine_basic_combinations},
        $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_charsets_safe},
        $options{optional_variators},
        $options{optional_server_variables},
      ],
      bigbang => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        $options{optional_gendata_views},
        $options{optional_gendata_vcols},
        $options{optional_gendata_gis},
        $options{optional_gendata_unique_hash_keys},
        $options{engine_basic_combinations}, $options{engine_extra_supported_combinations}, $options{engine_full_mix_combinations},
        $options{optional_charsets_safe}, $options{optional_charsets_unsafe},
        $options{optional_encryption},
        $options{optional_binlog_unsafe_variables},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars}, $options{debug_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      bigbang_with_custom_config => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        $options{custom_options_1},
        $options{custom_options_1_master},
        $options{optional_gendata_views},
        $options{optional_gendata_vcols},
        $options{optional_gendata_gis},
        $options{optional_gendata_unique_hash_keys},
        $options{engine_basic_combinations}, $options{engine_extra_supported_combinations}, $options{engine_full_mix_combinations},
        $options{optional_charsets_safe}, $options{optional_charsets_unsafe},
        $options{optional_encryption},
        $options{optional_binlog_unsafe_variables},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars}, $options{debug_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      binlog_with_extra_options => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ '--reporter=BinlogDump' ],
        [ '--mysqld=--log-bin' ],
        $options{engine_basic_combinations}, $options{engine_extra_supported_combinations}, $options{engine_full_mix_combinations},
        $options{optional_charsets_safe}, $options{optional_charsets_unsafe},
        $options{optional_encryption},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars}, $options{debug_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        # We do not care about binlog safety here, because we are not checking consistency
        $options{optional_binlog_safe_variables}, $options{optional_binlog_unsafe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_server_variables},
      ],
      encryption => [
        [ '--scenario=Standard', '--scenario=CrashRecovery' ],
        [ '--engine=InnoDB,Aria' ],
        [ '--grammar=conf/yy/dml.yy' ],
        $options{key_management_hash},
        [ '
            --mysqld=--log-bin
            --mysqld=--innodb-encrypt-tables
            --mysqld=--innodb-encrypt-log
            --mysqld=--innodb-encryption-threads=4
            --mysqld=--aria-encrypt-tables=1
            --mysqld=--encrypt-tmp-disk-tables=1
            --mysqld=--encrypt-tmp-files=1
            --mysqld=--encrypt-binlog
        '],
        $options{optional_gendata_views},
        $options{optional_charsets_safe},
        $options{optional_binlog_unsafe_variables},
        $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars}, $options{debug_grammars},
        $options{optional_variators},
        $options{optional_binlog_safe_variables},
        $options{optional_server_variables},
      ],
      galera => [
        [ '--scenario=Galera' ],
        [ '--filter=conf/ff/replication.ff' ],
        [ '--engine=InnoDB' ],
        $options{optional_charsets_safe},
        $options{optional_encryption},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      gis => [
        [ '--scenario=Standard','--scenario=Replication --scenario-nosync' ],
        [ '--gendata=advanced --gis'],
        [ '--grammar=conf/yy/gis.yy --grammar=conf/yy/alter_table.yy'],
        [ '--filter=conf/ff/replication.ff' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_server_variables},
      ],
      index_with_extra_options => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ '--reporters=SecondaryIndexConsistency' ],
        [ '--grammar=conf/yy/many_indexes.yy' ],
        $options{engine_basic_combinations}, $options{engine_extra_supported_combinations},
        $options{optional_charsets_safe},
        $options{optional_encryption},
        $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars}, $options{debug_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      innodb_with_extra_options => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ '--engine=InnoDB' ],
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_variators},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_server_variables},
      ],
      innodb_compression => [
        [ '--scenario=Standard' ],
        [ '--engine=InnoDB' ],
        [ '--grammar=conf/yy/innodb_compression_algorithms.yy'],
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_variators},
        $options{optional_binlog_safe_variables},
        $options{mandatory_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_server_variables},
      ],
      mixed_flow_with_extra_options => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        $options{optional_gendata_views},
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{optional_binlog_unsafe_variables},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars}, $options{debug_grammars},
        $options{optional_variators},
        $options{optional_binlog_safe_variables},
        $options{optional_server_variables},
      ],
      optimizer_transform => [
        [ '--scenario=Standard' ],
        ['
          --gendata=simple
          --gendata=data/sql/world.sql
          --gendata=conf/zz/outer_join.zz
          --grammar=conf/yy/collect_eits.yy
          --grammar=conf/yy/optimizer_no_subquery.yy
          --grammar=conf/yy/optimizer_subquery_semijoin.yy
          --grammar=conf/yy/optimizer.yy
          --grammar=conf/yy/outer_join.yy
          --views
        ' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        [ '--validator=Transformer --transformer=ExecuteAsPreparedTwice --transformer=EnableOptimizations --transformer=DisableOptimizations' ],
        $options{optional_server_variables},
      ],
      perfschema => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_server_variables},
        [ '--mysqld=--performance-schema=on --mysqld=--performance-schema-instrument="%=ON" --grammar=conf/yy/performance_schema.yy' ],
        [ '--mysqld=--performance-schema-consumer-events-stages-current=ON', '--mysqld=--performance-schema-consumer-events-stages-history=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-stages-history-long=ON', '--mysqld=--performance-schema-consumer-events-stages-history-long=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-stages-history-long=ON', '--mysqld=--performance-schema-consumer-events-stages-history-long=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-statements-current=ON', '--mysqld=--performance-schema-consumer-events-statements-current=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-statements-history=ON', '--mysqld=--performance-schema-consumer-events-statements-history=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-statements-history-long=ON', '--mysqld=--performance-schema-consumer-events-statements-history-long=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-waits-current=ON', '--mysqld=--performance-schema-consumer-events-waits-current=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-waits-history=ON', '--mysqld=--performance-schema-consumer-events-waits-history=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-waits-history-long=ON', '--mysqld=--performance-schema-consumer-events-waits-history-long=OFF' ],
        [ '--mysqld=--performance-schema-consumer-global-instrumentation=ON', '--mysqld=--performance-schema-consumer-global-instrumentation=OFF' ],
        [ '--mysqld=--performance-schema-consumer-thread-instrumentation=ON', '--mysqld=--performance-schema-consumer-thread-instrumentation=OFF' ],
        [ '--mysqld=--performance-schema-consumer-statements-digest=ON', '--mysqld=--performance-schema-consumer-statements-digest=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-transactions-current=ON', '--mysqld=--performance-schema-consumer-events-transactions-current=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-transactions-history=ON', '--mysqld=--performance-schema-consumer-events-transactions-history=OFF' ],
        [ '--mysqld=--performance-schema-consumer-events-transactions-history-long=ON', '--mysqld=--performance-schema-consumer-events-transactions-history-long=OFF' ],
      ],
      plugins => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        ['
          --grammar=conf/yy/query_response_time.yy
          --mysqld=--plugin-load-add=query_response_time
          --mysqld=--loose-query-response-time
          --grammar=conf/yy/plugin-query_cache_info.yy
          --mysqld=--plugin-load-add=query_cache_info
          --mysqld=--loose-query-cache-info
          --mysqld=--query-cache-type=1
          --grammar=conf/yy/query_response_time.yy
          --mysqld=--plugin-load-add=query_response_time
          --mysqld=--loose-query-response-time
          --grammar=conf/yy/metadata_lock_info.yy
          --mysqld=--plugin-load-add=metadata_lock_info
          --mysqld=--loose-metadata-lock-info
          --grammar=conf/yy/locales.yy
          --mysqld=--plugin-load-add=locales
          --mysqld=--loose-locales
          --grammar=conf/yy/disks.yy
          --mysqld=--plugin-load-add=disks
          --mysqld=--loose-disks
          --grammar=conf/yy/sql_errlog.yy
          --mysqld=--plugin-load-add=sql_errlog
          --mysqld=--loose-sql-error-log
        '],
        $options{engine_basic_combinations},
        $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_charsets_safe},
        $options{optional_variators},
        $options{optional_server_variables},
      ],
      recovery => [
        $options{scenario_crash_combinations},
        [ '--engine=InnoDB', '--engine=Aria --mysqld=--default-storage-engine=Aria', '--engine=InnoDB,Aria' ],
        [ '--filter=conf/ff/restrict_dynamic_vars.ff' ],
        [ '--grammar=conf/yy/dml.yy' ],
        $options{optional_charsets_safe},
        $options{optional_encryption},
        $options{dml_grammars}, $options{ddl_grammars}, $options{debug_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      replication => [
        $options{scenario_replication_combinations},
        [ '--grammar=conf/yy/replication.yy --filter=conf/ff/replication.ff' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{optional_encryption},
        $options{optional_replication_safe_variables},
        $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      replication_mbr => [
        $options{scenario_replication_combinations},
        [ '--mysqld=--log-bin --mysqld=--binlog-format=mixed' ],
        [ '--grammar=conf/yy/replication.yy --filter=conf/ff/replication.ff' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{optional_replication_safe_variables},
        $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_server_variables},
      ],
      replication_rbr => [
        $options{scenario_replication_combinations},
        [ '--mysqld=--log-bin --mysqld=--binlog-format=row' ],
        [ '--grammar=conf/yy/replication.yy --filter=conf/ff/replication.ff' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{optional_replication_safe_variables},
        $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_server_variables},
      ],
      spider => [
        [ '--scenario=Standard' ],
        ['
          --mysqld=--plugin-load-add=ha_spider
          --mysqld=--loose-spider-same-server-link=on
          --mysqld=--loose-spider_table_crd_thread_count=1
          --mysqld=--loose-spider_table_sts_thread_count=1
          --grammar=conf/yy/engine-spider.yy
        '],
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_binlog_safe_variables},
        $options{optional_server_variables},
      ],
      upgrade_backup => [
        $options{scenario_mariabackup_combinations}, $options{scenario_upgrade_combinations},
        [ '--filter=conf/ff/restrict_dynamic_vars.ff' ],
        [ '--grammar=conf/yy/dml.yy' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{optional_encryption},
        $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_perfschema},
        $options{optional_server_variables},
      ],
      virtual_columns => [
        [ '--scenario=Standard','--scenario=Replication --scenario-nosync' ],
        [ '--filter=conf/ff/replication.ff' ],
        [ '--gendata=advanced' ],
        [ '--grammar=conf/yy/virtual_columns.yy' ],
        [ '--vcols', '--vcols=VIRTUAL', '--vcols=STORED' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{read_only_grammars}, $options{dml_grammars}, $options{ddl_grammars}, $options{variables_grammars},
        $options{optional_variators},
        $options{optional_aria_variables},
        $options{optional_binlog_safe_variables},
        $options{optional_innodb_compression},
        $options{optional_innodb_pagesize},
        $options{optional_innodb_variables},
        $options{optional_server_variables},
      ],
    }
  ],
);
