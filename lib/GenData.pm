# Copyright (C) 2009, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2020, 2022, MariaDB Corporation Ab.
# Use is subject to license terms.
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

package GenData;
require Exporter;
@ISA = qw(GenTest);
@EXPORT= qw(
  FIELD_TYPE
  FIELD_CHARSET
  FIELD_COLLATION
  FIELD_SIGN
  FIELD_NULLABILITY
  FIELD_INDEX
  FIELD_AUTO_INCREMENT
  FIELD_SQL
  FIELD_INDEX_SQL
  FIELD_NAME
  FIELD_DEFAULT
  FIELD_NAMES
  FIELD_SQLS
  FIELD_INDEX_SQLS
  TABLE_ROW
  TABLE_ENGINE
  TABLE_CHARSET
  TABLE_COLLATION
  TABLE_ROW_FORMAT
  TABLE_EXTRA_OPTS
  TABLE_PK
  TABLE_SQL
  TABLE_NAME
  TABLE_VIEWS
  TABLE_MERGES
  TABLE_NAMES
  TABLE_PARTITION
  DATA_NUMBER
  DATA_STRING
  DATA_BLOB
  DATA_TEMPORAL
  DATA_ENUM
  GD_SPEC
  GD_DEBUG
  GD_SEED
  GD_ENGINE
  GD_ROWS
  GD_VIEWS
  GD_SQLTRACE
  GD_SHORT_COLUMN_NAMES
  GD_VARIATORS
  GD_VARDIR
  GD_PARTITIONS
  GD_COMPATIBILITY
  GD_VCOLS
  GD_RAND
  doGenData
);

use Carp;
use Data::Dumper;
use DBI;

use GenData::PopulateSchema;
use GenTest;
use GenTest::Constants;
use GenTest::Executor;
use GenTest::Random;
use GenTest::Transform;
use GenUtil;

use strict;

use constant FIELD_TYPE      => 0;
use constant FIELD_CHARSET    => 1;
use constant FIELD_COLLATION    => 2;
use constant FIELD_SIGN      => 3;
use constant FIELD_NULLABILITY    => 4;
use constant FIELD_INDEX    => 5;
use constant FIELD_AUTO_INCREMENT  => 6;
use constant FIELD_SQL      => 7;
use constant FIELD_INDEX_SQL    => 8;
use constant FIELD_NAME      => 9;
use constant FIELD_DEFAULT => 10;
use constant FIELD_NAMES    => 11;
use constant FIELD_SQLS     => 12;
use constant FIELD_INDEX_SQLS   => 13;

use constant TABLE_ROW    => 0;
use constant TABLE_ENGINE  => 1;
use constant TABLE_CHARSET  => 2;
use constant TABLE_COLLATION  => 3;
use constant TABLE_ROW_FORMAT  => 4;
use constant TABLE_EXTRA_OPTS  => 5;
use constant TABLE_PK    => 6;
use constant TABLE_SQL    => 7;
use constant TABLE_NAME    => 8;
use constant TABLE_VIEWS  => 9;
use constant TABLE_MERGES  => 10;
use constant TABLE_NAMES  => 11;
use constant TABLE_PARTITION  => 12;

use constant DATA_NUMBER  => 0;
use constant DATA_STRING  => 1;
use constant DATA_BLOB    => 2;
use constant DATA_TEMPORAL  => 3;
use constant DATA_ENUM    => 4;


use constant GD_SPEC => 0;
use constant GD_DEBUG => 1;
use constant GD_SEED => 3;
use constant GD_ENGINE => 4;
use constant GD_ROWS => 5;
use constant GD_VIEWS => 6;
use constant GD_EXECUTOR_ID => 7;
use constant GD_SQLTRACE => 9;
use constant GD_SHORT_COLUMN_NAMES => 10;
use constant GD_EXECUTOR => 11;
use constant GD_VARIATORS => 12;
use constant GD_VARIATOR_MANAGER => 13;
use constant GD_VARDIR => 15;
use constant GD_PARTITIONS => 16;
use constant GD_COMPATIBILITY => 17;
use constant GD_VCOLS => 18;
use constant GD_RAND => 19;
use constant GD_BASEDIR => 20;
use constant GD_TABLES => 21;
use constant GD_SERVER => 22;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new({
        'spec_file' => GD_SPEC,
        'debug' => GD_DEBUG,
        'seed' => GD_SEED,
        'engine' => GD_ENGINE,
        'executor_id' => GD_EXECUTOR_ID,
        'rows' => GD_ROWS,
        'views' => GD_VIEWS,
        'short_column_names' => GD_SHORT_COLUMN_NAMES,
        'server' => GD_SERVER,
        'variators' => GD_VARIATORS,
        'sqltrace' => GD_SQLTRACE,
        'vardir' => GD_VARDIR,
        'partitions' => GD_PARTITIONS,
        'compatibility' => GD_COMPATIBILITY,
        'vcols' => GD_VCOLS,
        'basedir' => GD_BASEDIR,
        'tables' => GD_TABLES,
      },@_);

    if (not defined $self->[GD_SEED]) {
        $self->[GD_SEED] = 1;
    } elsif ($self->[GD_SEED] eq 'time') {
        $self->[GD_SEED] = time();
        say("Converting --seed=time to --seed=".$self->[GD_SEED]);
    }
    $self->[GD_RAND]= GenTest::Random->new(seed => $self->seed());

    if ($self->server) {
      $self->[GD_EXECUTOR] = GenTest::Executor->newFromServer(
        $self->[GD_SERVER],
        sqltrace => $self->sqltrace,
        vardir => $self->vardir,
        seed => $self->seed,
      );
      $self->[GD_EXECUTOR]->init();
    }

    return $self;
}

sub doGenData {
  my $props= shift;
  my @generators= ();
  foreach my $gd (@{$props->gendata}) {
    my $gd_class= 'GendataFromFile';
    if ($gd eq 'simple') {
      $gd_class= 'GendataSimple';
    } elsif ($gd eq 'advanced') {
      $gd_class= 'GendataAdvanced';
    }
    $gd_class="GenData::$gd_class";
    eval ("require $gd_class") or croak $@;
    foreach my $i (sort { $a <=> $b } keys %{$props->server_specific}) {
      my $so= $props->server_specific->{$i};
      next unless $so->{active};
      my $res= $gd_class->new(
         compatibility => $props->compatibility,
         debug => $props->debug,
         engine => $so->{engine},
         executor_id => $i,
         partitions => $so->{partitions},
         rows => $props->rows,
         seed => $props->seed(),
         short_column_names => $props->short_column_names,
         server => $so->{server},
         spec_file => $gd,
         sqltrace=> $props->sqltrace,
         vardir => $props->vardir,
         variators => $props->variators,
         vcols => $so->{vcols},
         views => $so->{views},
      )->run();
      say("$gd_class finished with result ".status2text($res));
    }
  }
}

sub executor {
  return $_[0]->[GD_EXECUTOR];
}

sub executor_id {
  return $_[0]->[GD_EXECUTOR_ID];
}

sub vardir {
  return $_[0]->[GD_VARDIR];
}

sub rand {
  return $_[0]->[GD_RAND];
}

sub spec_file {
    return $_[0]->[GD_SPEC];
}

sub debug {
    return $_[0]->[GD_DEBUG];
}

sub seed {
    return $_[0]->[GD_SEED];
}

sub server {
  return $_[0]->[GD_SERVER];
}

sub engine {
    return $_[0]->[GD_ENGINE];
}

sub rows {
    return $_[0]->[GD_ROWS];
}

sub views {
    return $_[0]->[GD_VIEWS];
}

sub partitions {
    return $_[0]->[GD_PARTITIONS];
}

sub sqltrace {
    return $_[0]->[GD_SQLTRACE];
}

sub short_column_names {
    return $_[0]->[GD_SHORT_COLUMN_NAMES];
}

sub compatibility {
    return $_[0]->[GD_COMPATIBILITY];
}

sub vcols {
    return $_[0]->[GD_VCOLS];
}

sub tables {
    return $_[0]->[GD_TABLES];
}

sub basedir {
    return $_[0]->[GD_BASEDIR];
}

# To be overridden
sub run {}

1;
