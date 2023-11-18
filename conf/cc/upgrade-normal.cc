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

use strict;

$combinations = [
  [
  '
    --threads=2
    --duration=120
    --seed=time
    --grammar=conf/yy/acl.yy
    --grammar=conf/yy/dml.yy
    --grammar=conf/yy/alter_table_safe.yy
    --gendata=conf/zz/innodb.zz
    --gendata=conf/zz/innodb-page-compression.zz
    --gendata=advanced
    --views
    --vcols
    --partitions
    --reporters=Backtrace,Deadlock,FeatureUsage
    --mysqld=--server-id=111
    --mysqld=--log_output=FILE
    --mysqld=--loose-max-statement-time=20
    --mysqld=--lock-wait-timeout=10
    --mysqld=--innodb-lock-wait-timeout=5
    --scenario=NormalUpgrades
  '],
  [
    '--mysqld=--innodb_compression_algorithm=none',
    '--mysqld=--innodb_compression_default=on',
  ],[
    '--mysqld=--innodb_page_size=4K',
    '--mysqld=--innodb_page_size=8K',
    '--mysqld=--innodb_page_size=16K',
    '--mysqld=--innodb_page_size=32K',
    '--mysqld=--innodb_page_size=64K'
  ],
  [ '',
    '--mysqld=--innodb-encrypt-tables
     --mysqld=--innodb-encrypt-log
     --mysqld=--innodb-encryption-threads=4
     --mysqld=--aria-encrypt-tables=1
     --mysqld=--encrypt-tmp-disk-tables=1
     --mysqld=--encrypt-binlog
     --mysqld=--file-key-management
     --mysqld=--file-key-management-filename='.$ENV{RQG_HOME}.'/util/file_key_management_keys.txt
     --mysqld=--plugin-load-add=file_key_management
    '
  ],
];
