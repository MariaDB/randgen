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

$combinations = [

# Test options
  [ @{$options{test_common_option_combinations}} ], # seed, reporters, timeouts
  [ @{$options{test_concurrency_combinations}} ],
  [ @{$options{optional_gendata_views}} ],
  [ @{$options{optional_variators}} ],
  [ @{$options{gendata}} ],

# Server options
  [ @{$options{optional_aria_variables}} ],
  [ @{$options{optional_binlog_safe_variables}} ],
#  [ @{$options{optional_innodb_compression}} ],
  [ @{$options{optional_innodb_pagesize}} ],
  [ @{$options{optional_innodb_variables}} ],
  [ @{$options{optional_perfschema}} ],
  [ @{$options{optional_server_variables}} ],
  [ @{$options{optional_charsets_safe}} ],
#  [ @{$options{optional_encryption}} ],
  [ '--mysqld=--innodb-adaptive-hash-index=on' ],

  [ '--grammar=conf/yy/dml.yy' ],
  [ '--grammar=conf/yy/admin.yy', '', '', '', '' ],
  [ '--grammar=conf/yy/alter_table_columns.yy', '', '', '' ],
  [ '--grammar=conf/yy/alter_table_data_types.yy', '', '', '' ],
  [ '--grammar=conf/yy/alter_table.yy', '', '', '' ],
  [ '--grammar=conf/yy/bulk_insert.yy', '', '' ],
  [ '--grammar=conf/yy/concurrent.yy', '', '', '', '' ],
  [ '--grammar=conf/yy/create_or_replace.yy', '', '', '', '' ],
  [ '--grammar=conf/yy/sequences.yy', '', '', '', '', '', '', '', '' ],
  [ '--grammar=conf/yy/dbt3-dml.yy --grammar=conf/yy/dbt3-joins.yy --grammar=conf/yy/dbt3-ranges.yy --gendata=data/dbt3/dbt3-s0.001.dump', '--grammar=conf/yy/dbt3-dml.yy --grammar=conf/yy/dbt3-joins.yy --grammar=conf/yy/dbt3-ranges.yy --gendata=data/dbt3/dbt3-s0.0001.dump', '', '', '', '' ],
  [ '--grammar=conf/yy/joins.yy --grammar=conf/yy/optimizer.yy', '', '', '', '', '' ],
  [ '--grammar=conf/yy/dynamic_variables.yy', '', '', '', '', '', '', '', '', '' ],
  [ '--grammar=conf/yy/foreign_keys.yy', '', '', '', '', '', '', '', '', '' ],
  [ '--grammar=conf/yy/indexes_and_constraints.yy', '', '', '' ],
  [ '--grammar=conf/yy/information_schema.yy', '', '', '', '', '', '', '', '', '' ],
  [ '--grammar=conf/yy/multi_update.yy --gendata=simple --grammar=conf/yy/optimizer_subquery_semijoin.yy', '', '', '', '', '', '', '', '', '' ],
  [ '--grammar=conf/yy/oltp-write.yy --gendata=conf/zz/oltp.zz', '', '', '', '' ],
  [ '--grammar=conf/yy/partition-dml.yy --gendata=conf/zz/partition_by_columns.zz', '', '', '', '' ],
  [ '--grammar=conf/yy/random_keys.yy', '', '', '', '' ],
  [ '--grammar=conf/yy/replication.yy', '', '', '', '' ],
  [ '--grammar=conf/yy/transaction.yy', '', '', '', '', '', '', '', '', '' ],
  [ '--grammar=conf/yy/trx_stress.yy', '', '', '', '' ],
  [ '--grammar=conf/yy/versioning.yy', '', '', '', '' ],
  [ '--grammar=conf/yy/xa.yy', '', '', '', '', '', '', '', '', '', '', '', '', '' ],
  [ '--engine=InnoDB' ],
  [ '--mysqld=--log-bin', '', '', '' ],
  [ '--scenario=Standard', '--scenario=Standard', '--scenario=Restart', '--scenario=AtomicDDL', '--scenario=CrashRecovery', '--scenario=Restart --scenario-restart-type=kill', '--scenario=MariaBackupFull', '--scenario=MariaBackupIncremental', '--scenario=ImportTablespace' ],
  [ '--filter=conf/ff/optimize.ff' ],
];
