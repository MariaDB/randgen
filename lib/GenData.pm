# Copyright (C) 2009, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2020, 2023, MariaDB Corporation Ab.
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
  GD_VARDIR
  GD_PARTITIONS
  GD_COMPATIBILITY
  GD_VCOLS
  GD_RAND
  GD_GIS
  GD_UNIQUE_HASH_KEYS
  doGenData
);

use Carp;
use Data::Dumper;

use GenData::PopulateSchema;
use GenTest;
use Constants;
use GenTest::Executor;
use GenTest::Random;
use GenTest::Transform;
use GenUtil;
use Connection::Perl;

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
use constant GD_VARDIR => 15;
use constant GD_PARTITIONS => 16;
use constant GD_COMPATIBILITY => 17;
use constant GD_VCOLS => 18;
use constant GD_RAND => 19;
use constant GD_BASEDIR => 20;
use constant GD_TABLES => 21;
use constant GD_SERVER => 22;
use constant GD_GIS => 23;
use constant GD_UNIQUE_HASH_KEYS => 24;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new({
        'spec_file' => GD_SPEC,
        'debug' => GD_DEBUG,
        'seed' => GD_SEED,
        'engine' => GD_ENGINE,
        'executor_id' => GD_EXECUTOR_ID,
        'gis' => GD_GIS,
        'rows' => GD_ROWS,
        'views' => GD_VIEWS,
        'short_column_names' => GD_SHORT_COLUMN_NAMES,
        'server' => GD_SERVER,
        'sqltrace' => GD_SQLTRACE,
        'vardir' => GD_VARDIR,
        'partitions' => GD_PARTITIONS,
        'compatibility' => GD_COMPATIBILITY,
        'vcols' => GD_VCOLS,
        'basedir' => GD_BASEDIR,
        'tables' => GD_TABLES,
        'uhashkeys' => GD_UNIQUE_HASH_KEYS,
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
      $self->[GD_EXECUTOR]->admin();
    }

    return $self;
}

sub doGenData {
  my $props= shift;
  my $server_num= shift;
  # If server number is defined, generate data only there, ignore all other servers.
  # It is a scenario of upgrade tests, for example.
  # Otherwise generate data on each server (e.g. for comparison tests).
  my @server_numbers= ($server_num ? ($server_num) : sort { $a <=> $b } keys %{$props->server_specific});
  my @generators= ();
  my $result= STATUS_OK;
  foreach my $gd (@{$props->gendata}) {
    my $gd_class= 'GendataFromFile';
    if ($gd eq 'simple') {
      $gd_class= 'GendataSimple';
    } elsif ($gd eq 'advanced') {
      $gd_class= 'GendataAdvanced';
    }
    $gd_class="GenData::$gd_class";
    eval ("require $gd_class") or croak $@;
    foreach my $i (@server_numbers) {
      my $so= $props->server_specific->{$i};
      next unless $so->{active};
      say("Running $gd_class".($gd_class eq 'GenData::GendataFromFile' ? " from $gd" : "")." on server $i");
      my $res= $gd_class->new(
         basedir => $so->{basedir},
         compatibility => $props->compatibility,
         debug => $props->debug,
         engine => $so->{engine},
         executor_id => $i,
         gis => $so->{gis},
         partitions => $so->{partitions},
         rows => $props->rows,
         seed => $props->seed(),
         short_column_names => $props->short_column_names,
         server => $so->{server},
         spec_file => $gd,
         sqltrace=> $props->sqltrace,
         uhashkeys => $so->{uhashkeys},
         vardir => $props->vardir,
         vcols => $so->{vcols},
         views => $so->{views},
      )->run();
      
      if ($res > STATUS_CRITICAL_FAILURE) {
        sayError("$gd_class finished with result ".status2text($res).", aborting data generation");
        return $res;
      } elsif ($res > $result) {
        $result= $res;
      }
      say("$gd_class finished with result ".status2text($res));
    }
  }
  if ($result < STATUS_CRITICAL_FAILURE && scalar(@server_numbers) > 1) {
    $result= validateData($props);
  }
  return $result;
}

# For several servers which may later participate in comparison,
# the initially generated data should be identical, otherwise no point
sub validateData {
  my $props= shift;
  my @exs= ();
  foreach my $i (sort { $a <=> $b } keys %{$props->server_specific}) {
    my $so= $props->server_specific->{$i};
    next unless $so->{active};
    my $e = GenTest::Executor->newFromServer(
      $so->{server},
      id => $i
    );
    $e->init();
    push @exs, $e;
  }
  say("Validating original datasets");
  my $dbs0= $exs[0]->connection->get_column('SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME NOT IN ('.$exs[0]->server->systemSchemaList().') ORDER BY SCHEMA_NAME');
  foreach my $i (1..$#exs) {
    my $dbs= $exs[$i]->connection->get_column('SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME NOT IN ('.$exs[$i]->server->systemSchemaList().') ORDER BY SCHEMA_NAME');
    if ("@$dbs0" ne "@$dbs") {
      sayError("GenData: Schemata mismatch after data generation between two servers (1 vs ".($i+1)."):\n\t@$dbs0\n\t@$dbs");
      return STATUS_CRITICAL_FAILURE;
    }
  }
  foreach my $db (@$dbs0) {
    my $tbs0= $exs[0]->connection->get_column("SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '$db' ORDER BY TABLE_NAME");
    foreach my $i (1..$#exs) {
      my $tbs= $exs[$i]->connection->get_column("SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '$db' ORDER BY TABLE_NAME");
      if ("@$tbs0" ne "@$tbs") {
        sayError("GenData: Table list mismatch after data generation between two servers (1 vs ".($i+1)."):\n\t@$tbs0\n\t@$tbs");
        return STATUS_CRITICAL_FAILURE;
      }
    }
    # First, try to compare checksum, and only compare contents when checksums don't match
    my @checksum_mismatch= ();
    foreach my $t (@$tbs0) {
      # Workaround for MDEV-22943 : don't run CHECKSUM on tables with virtual columns
      my $virt_cols= $exs[0]->connection->get_value("SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='$db' AND TABLE_NAME='$t' AND IS_GENERATED='ALWAYS'");
      if ($exs[0]->connection->err) {
        sayError("Check for virtual columns on server 1 for $db.$t ended with an error: ".$exs[0]->connection->print_error);
        return STATUS_CRITICAL_FAILURE;
      } elsif ($virt_cols > 0) {
        sayDebug("Found virt_cols virtual columns on server 1 for $db.$t, skipping CHECKSUM");
        push @checksum_mismatch, $t;
        next;
      }
      my $cs0= $exs[0]->connection->get_value("CHECKSUM TABLE $db.$t EXTENDED");
      if ($exs[0]->connection->err) {
        sayError("CHECKSUM on server 1 for $db.$t ended with an error: ".$exs[0]->connection->print_error);
        return STATUS_CRITICAL_FAILURE;
      }
      foreach my $i (1..$#exs) {
        my $cs= $exs[$i]->connection->get_value("CHECKSUM TABLE $db.$t EXTENDED");
        if ($exs[$i]->connection->err) {
          sayError("CHECKSUM on server ".($i+1)." for $db.$t ended with an error: ".$exs[$i]->connection->print_error);
          return STATUS_CRITICAL_FAILURE;
        }
        push @checksum_mismatch, $t if ($cs0 ne $cs);
        sayDebug("Checksums for $db.$t: server 1: $cs0, server ".($i+1).": $cs");
      }
    }
    foreach my $t (@checksum_mismatch) {
      my $rs0= $exs[0]->execute("SELECT * FROM $db.$t");
      if ($exs[0]->connection->err) {
        sayError("SELECT on server 1 from $db.$t ended with an error: ".$exs[0]->connection->print_error);
        return STATUS_CRITICAL_FAILURE;
      }
      foreach my $i (1..$#exs) {
        my $rs= $exs[$i]->execute("SELECT * FROM $db.$t");
        if ($exs[$i]->connection->err) {
          sayError("SELECT on server ".($i+1)." from $db.$t ended with an error: ".$exs[$i]->connection->print_error);
          return STATUS_CRITICAL_FAILURE;
        }
        if ( GenTest::Comparator::compare_as_unordered($rs0, $rs) != STATUS_OK ) {
          sayError("Data mismatch after data generation between two servers (1 vs ".($i+1).") in table `$db`.`$t`");
          return STATUS_CONTENT_MISMATCH;
        }
      }
    }
  }
  say("Original datasets are identical");
  return STATUS_OK;
}

# For federation-like engines
sub setupRemote {
  my ($self, $db)= @_;
  my $remote_db= $db.'_remote';
  # It's just a random line, nothing secret. Need it to keep password plugins happy
  my $remote_pass= 'jvc8vxe6fky-CEX@zax';
  my $res= $self->executor->execute("CREATE DATABASE IF NOT EXISTS $remote_db");
  return STATUS_ENVIRONMENT_FAILURE if $res->err;
  $res= $self->executor->execute('CREATE USER IF NOT EXISTS remote_user@localhost IDENTIFIED BY "'.$remote_pass.'"');
  return STATUS_ENVIRONMENT_FAILURE if $res->err;
  $res= $self->executor->execute('GRANT ALL ON '.$remote_db.'.* TO remote_user@localhost');
  return STATUS_ENVIRONMENT_FAILURE if $res->err;
  $res= $self->executor->execute('CREATE SERVER IF NOT EXISTS s_'.$db.' foreign data wrapper mysql options '.
    '(host "127.0.0.1", database "'.$remote_db.'", user "remote_user", password "'.$remote_pass.'", port '.$self->executor->server->port.')');
  return STATUS_ENVIRONMENT_FAILURE if $res->err;
  return STATUS_OK;
}

sub createView {
  my ($self, $alg, $table, $db)= @_;
  if (defined $alg) {
    if ($alg ne '') {
        $self->executor->execute("CREATE ALGORITHM=$alg VIEW $db.view_$table AS SELECT * FROM $db.$table");
    } else {
        $self->executor->execute("CREATE VIEW $db.view_$table AS SELECT * FROM $db.$table");
    }
  }
}

sub createFederatedTable {
  my ($self,$engine,$name,$db)= @_;
  my $connection_options= '';
  (my $remote_name= $name) =~ s/_$engine$//i;
  if (lc($engine) eq 'spider') {
    $connection_options= 'COMMENT = "wrapper '."'mysql', srv 's_".$db."', table '".$remote_name."'".'"';
    $self->executor->execute("CREATE TABLE $db.$name LIKE ${db}_remote.$remote_name");
    $self->executor->execute("ALTER TABLE $db.$name ENGINE=SPIDER $connection_options");
  } elsif (lc($engine) eq 'federated') {
    # We assume it's actually FederatedX, able to discover
    $connection_options= 'CONNECTION="s_'.$db.'/'.$remote_name.'"';
    $self->executor->execute("CREATE TABLE $db.$name ENGINE=FEDERATED $connection_options");
  }
  return STATUS_OK;
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

sub uhashkeys {
  return $_[0]->[GD_UNIQUE_HASH_KEYS];
}

sub gis {
    return $_[0]->[GD_GIS];
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
