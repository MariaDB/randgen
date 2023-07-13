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

use strict;

our (%server_options, %options);

require "$ENV{RQG_HOME}/conf/cc/include/parameter_presets";
require "$ENV{RQG_HOME}/conf/cc/include/combo.grammars";

# Choose options based on $version value
# ($version may be defined via config-version, otherwise 999999 will be used)
local @ARGV = ($version);
require "$ENV{RQG_HOME}/conf/cc/include/versioned_options.pl";

$combinations = [
  [
  '
    --threads=2
    --duration=120
    --seed=time
    --grammar=conf/yy/acl.yy
    --grammar=conf/yy/dml.yy
    --grammar=conf/yy/alter_table.yy
    --gendata=conf/zz/innodb.zz
    --gendata=conf/zz/innodb-page-compression.zz
    --gendata=advanced
    --views
    --vcols
    --partitions
    --reporters=Backtrace,ErrorLog,Deadlock
    --mysqld=--server-id=111
    --mysqld=--log_output=FILE
    --mysqld=--loose-max-statement-time=20
    --mysqld=--lock-wait-timeout=10
    --mysqld=--innodb-lock-wait-timeout=5
    --scenario=NormalUpgrades
  '],
  [ @{$options{innodb_compression_combinations}} ],
  [ @{$options{innodb_pagesize_combinations}} ],
  [ '', $options{all_encryption_options} ],
];
