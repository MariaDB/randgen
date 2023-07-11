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
our (%server_options);
our ($grammars, $gendata);

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
  # For the  unlikely case when nothing else is picked
  [ '--grammar=conf/yy/all_selects.yy:0.0001' ],
  [ $common_options ], # seed, reporters, timeouts
  [ @$threads_low_combinations ],
  [ @$views_combinations, '', '', '' ],
  [ @$vcols_combinations, '--vcols=STORED',
   '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''
  ],
  [ @$optional_variators ],
  [ @$grammars ],
  [ @$gendata ],

  ##### Engines and engine=specific options
  [
    {
      basic_engines => [
        [ @$basic_engine_combinations, @$enforced_engine_combinations ],
        [ '','','','','','','','', '', '', '', @$non_crash_scenarios ],
      ],
      extra_engines => [
        [ @$extra_engine_combinations ],
        [ '','','','','','','','', '', '', '', @$non_crash_scenarios ],
      ],
      innodb => [
        [ '--engine=InnoDB', '--engine=InnoDB --mysqld=--default-storage-engine=InnoDB --mysqld=--enforce-storage-engine=InnoDB' ],
        [ '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', @$crash_scenarios, @$non_crash_scenarios, @$mariabackup_scenarios ],
        @{$options{optional_innodb_variables}},
        @{$options{innodb_compression_combinations}},
      ],
      aria => [
        [ '--engine=Aria', '--engine=Aria --mysqld=--default-storage-engine=Aria --mysqld=--enforce-storage-engine=Aria' ],
        [ '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', @$crash_scenarios, @$non_crash_scenarios, @$mariabackup_scenarios ],
        @{$options{optional_aria_variables}},
      ],
      myisam => [
        [ '--engine=MyISAM', '--engine=MyISAM --mysqld=--default-storage-engine=MyISAM --mysqld=--enforce-storage-engine=MyISAM' ],
        [ '','','','','','','','', '', '', '', @$non_crash_scenarios ],
      ],
    }
  ],
  [ @{$options{optional_plugins}} ],
  ##### PS protocol and low values of max-prepared-stmt-count
  [ '', '', '', '', '', '', '', '', '', '', $ps_protocol_options ],
  ##### Encryption
  [ '', '', '', '', '', '', '', '', '', '', $options{all_encryption_options}, $options{aria_encryption_options}, $options{innodb_encryption_options}, $options{non_innodb_encryption_options} ],
  ##### Binary logging
  [ '', '', [ @{$options{binlog_combinations}} ] ],
  ##### Performance schema
  [ '', '', '', '', '', '', '', '', '', $options{perfschema_options}->[0] . ' --grammar=conf/yy/performance_schema.yy'],
  ##### Startup variables (general)
  [ @{$options{optional_server_variables}} ],
  [ @{$options{optional_charsets}} ],
];
