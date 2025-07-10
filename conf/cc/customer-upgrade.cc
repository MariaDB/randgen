# Copyright (c) 2025 MariaDB
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

unless ($ENV{WORKSPACE}) {
  die "Environment variable WORKSPACE must be defined";
}
my $ws= $ENV{WORKSPACE};
my $new_basedir= (-d "$ws/11.4-enterprise" ? "$ws/11.4-enterprise" : "$ws/11.4");

foreach my $d ("$ws/10.6.18-14", "$ws/10.5.29-23", $new_basedir) {
  unless (-d "$d") {
    die "$d does not exist or is not a directory";
  }
}

$combinations = [
  ['
    --seed=time
    --reporters=Backtrace,Deadlock
    --grammar=conf/yy/alter_table_safe.yy
    --gendata=conf/zz/blobs.zz
    --gendata=conf/zz/current_timestamp.zz
    --gendata=conf/zz/custom.zz
    --gendata=conf/zz/full_text_search.zz
    --gendata=conf/zz/oltp-aria.zz
    --gendata=conf/zz/oltp.zz
    --gendata=conf/zz/optimizer_basic.zz
    --gendata=conf/zz/temporal.zz
    --gendata=data/dbt3/dbt3-s0.0001.dump
    --gendata=advanced
    --views=MERGE,TEMPTABLE
    --vcols
    --partitions
    --reporters=Backtrace,Deadlock,FeatureUsage
  '],
  [
    "
      --scenario=NormalUpgrades
      --threads=1
      --duration=60
      --queries=10
      --server1-basedir=$ws/10.6.18-14
      --server2-basedir=$new_basedir
      --genconfig=conf/cnf/custom1-master.cnf
      --compatibility=10.6
    ",
    "
      --scenario=Replication
      --threads=4
      --duration=300
      --server1-basedir=$ws/10.6.18-14
      --server2-basedir=$new_basedir
      --server1-genconfig=conf/cnf/custom1-master.cnf
      --server2-genconfig=conf/cnf/custom1-slave.cnf
      --compatibility=10.6
      --filter=conf/ff/replication.ff
      --mysqld=--explicit_defaults_for_timestamp=ON
    ",
    "
      --scenario=NormalUpgrades
      --threads=1
      --duration=60
      --queries=10
      --server1-basedir=$ws/10.5.29-23
      --server2-basedir=$new_basedir
      --compatibility=10.5
    ",
    "
      --scenario=Replication
      --threads=4
      --duration=300
      --server1-basedir=$ws/10.5.29-23
      --server2-basedir=$new_basedir
      --compatibility=10.5
      --filter=conf/ff/replication.ff
      --mysqld=--explicit_defaults_for_timestamp=ON
      --mysqld=--slave_type_conversions=ALL_NON_LOSSY
      --mysqld=--binlog-format=row
    "
  ],
];
