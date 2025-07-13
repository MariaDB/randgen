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

# New
  [ '--grammar=conf/yy/vector.yy:3 --gendata=data/sql/vector_gist_960_1K.sql --gendata=data/sql/vector_deep_image_96_10K.sql' ],
  [ '--mysqld=--mhnsw_max_cache_size=128M', '--mysqld=--mhnsw_max_cache_size=8G', '--mysqld=--mhnsw_max_cache_size=4G', '--mysqld=--mhnsw_max_cache_size=1G', '--mysqld=--mhnsw_max_cache_size=1M' ],
  [ '--mysqld=--mhnsw_default_m=3', '--mysqld=--mhnsw_default_m=4', '--mysqld=--mhnsw_default_m=20', '--mysqld=--mhnsw_default_m=100', '', '' ],
  [ '--mysqld=--mhnsw_ef_search=1', '--mysqld=--mhnsw_ef_search=2', '--mysqld=--mhnsw_ef_search=5', '--mysqld=--mhnsw_ef_search=10', '--mysqld=--mhnsw_ef_search=20', '--mysqld=--mhnsw_ef_search=100', '--mysqld=--mhnsw_ef_search=200', '--mysqld=--mhnsw_ef_search=4096', '--mysqld=--mhnsw_ef_search=65535', '' ],
  [ '--mysqld=--mhnsw_default_distance=euclidean', '--mysqld=--mhnsw_default_distance=cosine' ],

  [ ' --grammar=conf/yy/functions.yy:2', '' ],

  ##### Engines and scenarios
  [
    {
      custom_rpl => [
        [ '--scenario=Replication' ],
        [ ''. '--scenario-nosync'  ],
        [ '--engine=InnoDB' ],
        [ '--variator=ExecuteAsOracleSP', '' ],
        [ '--variator=ExecuteAsPackageSP', '' ],
        [ '--grammar=conf/yy/dml.yy' ],
        [ '--filter=conf/ff/replication.ff' ],
        [ '--server1-genconfig=conf/cnf/custom1-master.cnf --server2-genconfig=conf/cnf/custom1-slave.cnf --mysqld=--innodb-buffer-pool-size=1G' ],
        $options{dml_grammars}, $options{ddl_grammars},
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
      replication => [
        $options{scenario_replication_combinations},
        [ ''. '--scenario-nosync'  ],
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
      replication_rbr => [
        $options{scenario_replication_combinations},
         [ ''. '--scenario-nosync'  ],
       [ '--mysqld=--log-bin --mysqld=--binlog-format=row' ],
        [ '--grammar=conf/yy/replication.yy --filter=conf/ff/replication.ff' ],
        $options{engine_basic_combinations},
        $options{optional_charsets_safe},
        $options{optional_replication_safe_variables},
        $options{dml_grammars}, $options{ddl_grammars},
        $options{optional_server_variables},
      ],
    }
  ],
];
