# Copyright (C) 2009, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2020, 2021, MariaDB Corporation Ab.
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

package GenTest::GenData;

@ISA = qw(GenTest);

use Carp;
use Data::Dumper;
use DBI;

use GenUtil;
use GenTest;
use GenTest::Constants;
use GenTest::Executor;
use GenTest::Random;
use GenData::PopulateSchema;

use strict;

use constant FIELD_TYPE			=> 0;
use constant FIELD_CHARSET		=> 1;
use constant FIELD_COLLATION		=> 2;
use constant FIELD_SIGN			=> 3;
use constant FIELD_NULLABILITY		=> 4;
use constant FIELD_INDEX		=> 5;
use constant FIELD_AUTO_INCREMENT	=> 6;
use constant FIELD_SQL			=> 7;
use constant FIELD_INDEX_SQL		=> 8;
use constant FIELD_NAME			=> 9;
use constant FIELD_DEFAULT => 10;
use constant FIELD_NAMES    => 11;
use constant FIELD_SQLS     => 12;
use constant FIELD_INDEX_SQLS   => 13;

use constant TABLE_ROW		=> 0;
use constant TABLE_ENGINE	=> 1;
use constant TABLE_CHARSET	=> 2;
use constant TABLE_COLLATION	=> 3;
use constant TABLE_ROW_FORMAT	=> 4;
use constant TABLE_EXTRA_OPTS	=> 5;
use constant TABLE_PK		=> 6;
use constant TABLE_SQL		=> 7;
use constant TABLE_NAME		=> 8;
use constant TABLE_VIEWS	=> 9;
use constant TABLE_MERGES	=> 10;
use constant TABLE_NAMES	=> 11;
use constant TABLE_PARTITION	=> 12;

use constant DATA_NUMBER	=> 0;
use constant DATA_STRING	=> 1;
use constant DATA_BLOB		=> 2;
use constant DATA_TEMPORAL	=> 3;
use constant DATA_ENUM		=> 4;


use constant GD_SPEC => 0;
use constant GD_DEBUG => 1;
use constant GD_DSN => 2;
use constant GD_SEED => 3;
use constant GD_ENGINE => 4;
use constant GD_ROWS => 5;
use constant GD_VIEWS => 6;
use constant GD_SERVER_ID => 8;
use constant GD_SQLTRACE => 9;
use constant GD_SHORT_COLUMN_NAMES => 11;
use constant GD_EXECUTOR_ID => 13;
use constant GD_VARIATORS => 14;
use constant GD_VARDIR => 15;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new({
        'spec_file' => GD_SPEC,
        'debug' => GD_DEBUG,
        'dsn' => GD_DSN,
        'seed' => GD_SEED,
        'engine' => GD_ENGINE,
        'rows' => GD_ROWS,
        'views' => GD_VIEWS,
        'short_column_names' => GD_SHORT_COLUMN_NAMES,	
        'server_id' => GD_SERVER_ID,
        'executor_id' => GD_EXECUTOR_ID,
        'variators' => GD_VARIATORS,
        'sqltrace' => GD_SQLTRACE,
        'vardir' => GD_VARDIR,
      },@_);

    if (not defined $self->[GD_SEED]) {
        $self->[GD_SEED] = 1;
    } elsif ($self->[GD_SEED] eq 'time') {
        $self->[GD_SEED] = time();
        say("Converting --seed=time to --seed=".$self->[GD_SEED]);
    }

    my @variators= ();
    foreach my $vn (@{$self->[GD_VARIATORS]}) {
        eval ("require GenTest::Transform::'".$vn) or croak $@;
        my $variator = ('GenTest::Transform::'.$vn)->new();
        $variator->setSeed($self->[GD_SEED]);
        push @variators, $variator;
    }
    $self->[GD_VARIATORS] = [ @variators ];

    return $self;
}


sub spec_file {
return $_[0]->[GD_SPEC];
}


sub debug {
    return $_[0]->[GD_DEBUG];
}


sub dsn {
    return $_[0]->[GD_DSN];
}


sub seed {
    return $_[0]->[GD_SEED];
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

sub server_id {
    return $_[0]->[GD_SERVER_ID];
}

sub sqltrace {
    return $_[0]->[GD_SQLTRACE];
}

sub short_column_names {
    return $_[0]->[GD_SHORT_COLUMN_NAMES];
}

sub executor_id {
    return $_[0]->[GD_EXECUTOR_ID] || '';
}

sub variate_and_execute {
  my ($self, $executor, $query)= @_;
  foreach my $v (@{$self->[GD_VARIATORS]}) {
    # 1 stands for "it's gendata, variate with caution"
    $query= $v->variate($query,$executor,1);
  }
  return ($query ? $executor->execute($query) : STATUS_OK);
}

# To be overridden
sub run {}

1;
