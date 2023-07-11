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

our (%server_options);

# Version should be defined in the combinations options
$version='999999' unless defined $version;

require "$ENV{RQG_HOME}/conf/cc/include/parameter_presets";
require "$ENV{RQG_HOME}/conf/cc/include/combo.grammars";

my %options;

foreach my $comb (keys %server_options) {
  my @opts= ();
  my $opts= $server_options{$comb};
  VERSIONS:
  foreach my $ver (reverse sort keys %$opts) {
    if ($ver le $version) {
      push @opts, (ref $opts->{$ver} eq 'ARRAY' ? @{$opts->{$ver}} : $opts->{$ver});
      last VERSIONS;
    }
  }
  $options{$comb}= [ @opts ];
}

$combinations = [
  ['
    --threads=2
    --seed=time
    --grammar=conf/yy/dml.yy
    --gendata=conf/zz/innodb.zz
    --gendata=conf/zz/innodb-page-compression.zz
    --gendata=advanced
    --reporters=Backtrace,ErrorLog,Deadlock
    --mysqld=--server-id=111
    --mysqld=--log_output=FILE
    --mysqld=--loose-max-statement-time=20
    --mysqld=--lock-wait-timeout=10
    --mysqld=--innodb-lock-wait-timeout=5
  '],
  [ @{$options{innodb_compression_combinations}} ],
  [ @{$options{innodb_pagesize_combinations}} ],
  [ '', $options{all_encryption_options} ],
  [
    '--scenario=NormalUpgrades --duration=180',
    '--scenario=CrashUpgrade --duration=180',
    '--scenario=UndoLogUpgrade --duration=300',
  ]
];
