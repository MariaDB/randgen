# Copyright (c) 2022, 2023 MariaDB
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

# Fillers to adjust probability of options
my @empty_set_5=  ('','','','','');
my @empty_set_10= (@empty_set_5,@empty_set_5);
my @empty_set_20= (@empty_set_10, @empty_set_10);
my @empty_set_30= (@empty_set_20, @empty_set_10);
my @empty_set_50= (@empty_set_30, @empty_set_20);

$combinations = [

# Test options
  [ @{$options{test_common_option_combinations}} ], # seed, reporters, timeouts
  [ @{$options{test_concurrency_combinations}} ],
  [ @{$options{optional_gendata_gis}} ],
  [ @{$options{optional_gendata_views}} ],
  [ @{$options{optional_gendata_vcols}} ],
  [ @{$options{optional_gendata_unique_hash_keys}} ],
  [ @{$options{optional_variators}} ],
  [ @{$options{gendata}} ],
# Disabled for now, too frequent DBD problems
#  [ @{$options{optional_ps_protocol}} ],

# Server options
  [ @{$options{optional_aria_variables}} ],
  [ @{$options{optional_binlog_safe_variables}} ],
  [ @{$options{optional_innodb_compression}} ],
  [ @{$options{optional_innodb_pagesize}} ],
  [ @{$options{optional_innodb_variables}} ],
  [ @{$options{optional_perfschema}} ],
  [ @{$options{optional_server_variables}} ],

  [ @empty_set_50, '--mysqld=--aria-block-size=16384 --dataset=0', '--mysqld=--aria-block-size=32768 --dataset=0' ],
  [ @empty_set_50, '--mysqld=--innodb_page_size=4K --dataset=0','--mysqld=--innodb_page_size=8K --dataset=0','--mysqld=--innodb_page_size=32K --dataset=0','--mysqld=--innodb_page_size=64K --dataset=0'],

  [ '--dataset=/data/tmp/vector/datadir' ],

# New
  [ '--grammar=conf/preview/vector.yy:3' ],
  [ '--mysqld=--mhnsw_max_cache_size=128M', '--mysqld=--mhnsw_max_cache_size=8G', '--mysqld=--mhnsw_max_cache_size=4G', '--mysqld=--mhnsw_max_cache_size=1G', '--mysqld=--mhnsw_max_cache_size=1M' ],
  [ '--mysqld=--mhnsw_default_m=3', '--mysqld=--mhnsw_default_m=4', '--mysqld=--mhnsw_default_m=20', '--mysqld=--mhnsw_max_cache_size=100', '', '' ],
  [ '--mysqld=--mhnsw_ef_search=1', '--mysqld=--mhnsw_ef_search=2', '--mysqld=--mhnsw_ef_search=5', '--mysqld=--mhnsw_ef_search=10', '--mysqld=--mhnsw_ef_search=20', '--mysqld=--mhnsw_ef_search=100', '--mysqld=--mhnsw_ef_search=200', '--mysqld=--mhnsw_ef_search=4096', '--mysqld=--mhnsw_ef_search=65535', '' ],
  [ '--mysqld=--mhnsw_default_distance=euclidean', '--mysqld=--mhnsw_default_distance=cosine' ],

  [ '--gendata=simple', '--gendata=advanced' ],
#  [ '--gendata=conf/preview/deep-image_96_10K.sql' ],
#  [ '--gendata=conf/preview/gist_960_1K.sql' ],
#  [ '--gendata=conf/preview/deep-image_96_50K.sql', '' ],
#  [ '--gendata=conf/preview/deep-image_96_20K.sql', '' ],
#  [ '--gendata=conf/preview/deep-image_96_100K.sql', '', '' ],
#  [ '--gendata=conf/preview/gist_fake_1920_1K.sql', '' ],

  ##### Engines and scenarios
  [
    {
      simple => [
        [ '--scenario=Standard' ],
        [ '--engine=InnoDB,MyISAM,Aria' ],
        [ '--mysqld=--default-storage-engine=InnoDB', '--mysqld=--default-storage-engine=MyISAM', '--mysqld=--default-storage-engine=Aria' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}} ],
      ],
      innodb => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ '--engine=InnoDB --mysqld=--enforce-storage-engine=InnoDB --mysqld=--default-storage-engine=InnoDB' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}} ],
      ],
      myisam => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ '--engine=MyISAM --mysqld=--default-storage-engine=MyISAM --mysqld=--enforce-storage-engine=MyISAM' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}} ],
      ],
      aria => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ '--engine=Aria --mysqld=--default-storage-engine=Aria --mysqld=--enforce-storage-engine=Aria' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}} ],
      ],
      normal => [
        [ '--scenario=Standard', '--scenario=Restart' ],
        [ @{$options{engine_basic_combinations}}, @{$options{engine_extra_supported_combinations}}, @{$options{engine_full_mix_combinations}} ],
        [ @{$options{optional_charsets_safe}}, @{$options{optional_charsets_unsafe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{optional_binlog_unsafe_variables}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}}, @{$options{debug_grammars}} ],
      ],
      recovery => [
        [ '--scenario=CrashRecovery', '--scenario=Restart --scenario-restart-type=kill' ],
        [ '--engine=InnoDB', '--engine=Aria --mysqld=--default-storage-engine=Aria', '--engine=InnoDB,Aria' ],
        [ '--filter=conf/ff/restrict_dynamic_vars.ff' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{debug_grammars}} ],
      ],
      upgrade => [
        [ '--scenario=NormalUpgrades' ],
        [ '--engine=InnoDB', '--engine=Aria --mysqld=--default-storage-engine=Aria', '--engine=InnoDB,Aria' ],
        [ '--filter=conf/ff/restrict_dynamic_vars.ff' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{debug_grammars}} ],
      ],
      binlog_recovery => [
        [ '--scenario=CrashRecovery', '--scenario=AtomicDDL' ],
        [ '--engine=InnoDB', '--engine=Aria --mysqld=--default-storage-engine=Aria', '--engine=InnoDB,Aria' ],
        [ '--mysqld=--log-bin' ],
        # extra XA engine
        [ '--mysqld=--plugin-load-add=ha_rocksdb', '' ],
        [ '--mysqld=--binlog-format=row', '--mysqld=--binlog-format=mixed' ],
        [ '--filter=conf/ff/restrict_dynamic_vars.ff' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{debug_grammars}} ],
      ],
      innodb_recovery => [
        [ @{$options{scenario_crash_combinations}} ],
        [ '--engine=InnoDB --mysqld=--enforce-storage-engine=InnoDB --mysqld=--default-storage-engine=InnoDB' ],
        [ '--filter=conf/ff/restrict_dynamic_vars.ff' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
      ],
      backup => [
        [ @{$options{scenario_mariabackup_combinations}} ],
        [ '--engine=InnoDB,MyISAM,Aria' ],
        [ '--mysqld=--default-storage-engine=InnoDB', '--mysqld=--default-storage-engine=MyISAM', '--mysqld=--default-storage-engine=Aria' ],
        [ '--filter=conf/ff/restrict_dynamic_vars.ff' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
      ],
      xa_recovery => [
        [ '--scenario=Standard', '--scenario=Restart', '--scenario=CrashRecovery', '--scenario=AtomicDDL' ],
        [ '--engine=InnoDB' ],
        [ '--mysqld=--default-storage-engine=InnoDB' ],
        [ '--grammar=conf/yy/xa.yy' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{optional_replication_safe_variables}}, @{$options{optional_replication_unsafe_variables}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
      ],
      replication => [
        [ @{$options{scenario_replication_combinations}} ],
        [ '--filter=conf/ff/replication.ff' ],
        [ '--engine=InnoDB,MyISAM,Aria' ],
        [ '--mysqld=--default-storage-engine=InnoDB', '--mysqld=--default-storage-engine=MyISAM', '--mysqld=--default-storage-engine=Aria' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{optional_replication_safe_variables}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
      ],
      binlog => [
        [ '--mysqld=--log-bin' ],
        [ '--reporter=BinlogDump' ],
        [ @{$options{scenario_non_crash_combinations}} ],
        [ @{$options{engine_basic_combinations}}, @{$options{engine_extra_supported_combinations}}, @{$options{engine_full_mix_combinations}} ],
        [ @{$options{optional_charsets_safe}}, @{$options{optional_charsets_unsafe}} ],
        [ @{$options{optional_encryption}} ],
        # We don't care about binlog safety here, because we are not checking consistency
        [ @{$options{optional_binlog_unsafe_variables}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}}, @{$options{variables_grammars}}, @{$options{debug_grammars}} ],
      ],
      galera => [
        [ '--scenario=Galera' ],
        [ '--filter=conf/ff/replication.ff' ],
        [ '--engine=InnoDB' ],
        [ '--engine=Aria,MyISAM --mysqld=--loose-wsrep-mode="REPLICATE_ARIA,REPLICATE_MYISAM"','--grammar=conf/yy/wsrep.yy','' ],
        [ @{$options{optional_charsets_safe}} ],
        [ @{$options{optional_encryption}} ],
        [ @{$options{read_only_grammars}}, @{$options{dml_grammars}}, @{$options{ddl_grammars}} ],
      ]
    }
  ],
];
