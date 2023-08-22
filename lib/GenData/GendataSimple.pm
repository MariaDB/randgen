# Copyright (C) 2009 Sun Microsystems, Inc. All rights reserved.
# Copyright (c) 2021, 2022, MariaDB Corporation
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

package GenData::GendataSimple;
@ISA = qw(GenData);

use strict;

use GenData;
use GenTest;
use Constants;
use GenTest::Random;
use GenTest::Executor;
use GenUtil;

use Data::Dumper;

use constant GDS_DEFAULT_ROWS => [0, 1, 20, 100, 1000, 0, 1, 20, 100];
use constant GDS_DEFAULT_NAMES => ['A', 'B', 'C', 'D', 'E', 'AA', 'BB', 'CC', 'DD'];
use constant GDS_DEFAULT_DB => 'simple_db';

# We use the same "remote" database for all federation engines,
# and we don't want to re-create re-populate it each time, so we will
# use it as a flag that we have already created the schema
# if we have more than one federation engines
my $remote_created= undef;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    return $self;
}

sub run {
    my ($self) = @_;

    my $executor = $self->executor();

    my $names = GDS_DEFAULT_NAMES;
    my $rows;

    if (defined $self->rows()) {
        $rows = [split(',', $self->rows())];
    } else {
        $rows = GDS_DEFAULT_ROWS;
    }

    say("GendataSimple is creating tables");
    $executor->execute("CREATE DATABASE IF NOT EXISTS ".$self->GDS_DEFAULT_DB);
    # PS is a workaround for MENT-30190
    $executor->execute("EXECUTE IMMEDIATE CONCAT('GRANT ALL ON ".$self->GDS_DEFAULT_DB.".* TO ',CURRENT_USER,' WITH GRANT OPTION')");

    my @engines= ($self->engine ? split /,/, $self->engine : '');

    foreach my $e (@engines) {
      if (isFederatedEngine($e) and not $remote_created) {
        unless ($self->setupRemote($self->GDS_DEFAULT_DB) == STATUS_OK) {
          sayError("Could not set up remote access for engine $e");
          return STATUS_ENVIRONMENT_FAILURE;
        }
        # Create remote tables with default engine
        foreach my $i (0..$#$names) {
          my $gen_table_result = $self->gen_table($executor, $names->[$i], $rows->[$i], '', $self->GDS_DEFAULT_DB.'_remote');
          return $gen_table_result if $gen_table_result >= STATUS_CRITICAL_FAILURE;
        }
        $remote_created= 1;
      }

      foreach my $i (0..$#$names) {
        my $name= ($e eq $self->engine ? $names->[$i] : $names->[$i].'_'.$e);
        my $gen_table_result = $self->gen_table($executor, $name, $rows->[$i], $e, $self->GDS_DEFAULT_DB);
        return $gen_table_result if $gen_table_result != STATUS_OK;
      }
    }
    return STATUS_OK;
}

sub asc_desc_key {
    my ($asc_desc, $engine) = @_;
    # As of 10.8 RocksDB refuses to create DESC keys
    return '' if lc($engine) eq 'rocksdb';
    return ($asc_desc == 1 ? ' ASC' : ($asc_desc == 2 ? ' DESC' : ''));
}

sub gen_table {
  my ($self, $executor, $name, $size, $e, $db) = @_;

    say("Creating table $db.$name, size $size rows, ".($e ? "engine $e" : "default engine"));

    my $prng = $self->rand;

    # Remote table should already be created and populated by now,
    # just need the local one
    if (isFederatedEngine($e)) {
      $self->createFederatedTable($e,$name,$db);
      $self->createView($self->views(),$name,$db) if defined $self->views();
      return STATUS_OK;
    }

    ### NULL is not a valid ANSI constraint, (but NOT NULL of course,
    ### is)

    my $vcols = $self->vcols();
    my $views = $self->views();

    # For backward compatibility, only extend names
    # if multiple engines were provided

    ### This variant is needed due to
    ### http://bugs.mysql.com/bug.php?id=47125

    $executor->execute("DROP TABLE /*! IF EXISTS */ $db.$name");
    # RocksDB does not support virtual columns
    if ($vcols and lc($e) ne 'rocksdb') {
        $executor->execute(
        "CREATE TABLE $db.$name (
            pk INTEGER AUTO_INCREMENT,
            col_int_nokey INTEGER,
            col_int_key INTEGER AS (col_int_nokey * 2) $vcols,

            col_date_key DATE AS (DATE_SUB(col_date_nokey, INTERVAL 1 DAY)) $vcols,
            col_date_nokey DATE,

            col_time_key TIME AS (TIME(col_time_nokey)) $vcols,
            col_time_nokey TIME,

            col_datetime_key DATETIME AS (DATE_ADD(col_datetime_nokey, INTERVAL 1 HOUR)) $vcols,
            col_datetime_nokey DATETIME,

            col_varchar_key VARCHAR(1) AS (CONCAT('virt-',col_varchar_nokey)) $vcols,
            col_varchar_nokey VARCHAR(1),

            PRIMARY KEY (pk".asc_desc_key($prng->uint16(0,2),$e)."),
            KEY (col_int_key".asc_desc_key($prng->uint16(0,2),$e)."),
            KEY (col_date_key".asc_desc_key($prng->uint16(0,2),$e)."),
            KEY (col_time_key".asc_desc_key($prng->uint16(0,2),$e)."),
            KEY (col_datetime_key".asc_desc_key($prng->uint16(0,2),$e)."),
            KEY (col_varchar_key".asc_desc_key($prng->uint16(0,2),$e).", col_int_key".asc_desc_key($prng->uint16(0,2),$e).")
        ) ".(length($name) > 1 ? " AUTO_INCREMENT=".(length($name) * 5) : "").($e ne '' ? " ENGINE=$e" : "")
                           # For tables named like CC and CCC, start auto_increment with some offset. This provides better test coverage since
                           # joining such tables on PK does not produce only 1-to-1 matches.
        );
    } else {
        my $connection_options= '';
        if (lc($e) eq 'spider') {
          (my $remote_name= $name) =~ s/_spider$//i;
          $connection_options= 'COMMENT = "wrapper '."'mysql', srv 's_".$self->GDS_DEFAULT_DB."', table '".$remote_name."'".'"';
        } elsif (lc($e) eq 'federated') {
          (my $remote_name= $name) =~ s/_federated$//i;
          $connection_options= 'CONNECTION="s_'.$self->GDS_DEFAULT_DB.'/'.$remote_name.'"';
        }
        $executor->execute(
        "CREATE TABLE $db.$name (
            pk INTEGER AUTO_INCREMENT,
            col_int_nokey INTEGER,
            col_int_key INTEGER,

            col_date_key DATE,
            col_date_nokey DATE,

            col_time_key TIME,
            col_time_nokey TIME,

            col_datetime_key DATETIME,
            col_datetime_nokey DATETIME,

            col_varchar_key VARCHAR(1),
            col_varchar_nokey VARCHAR(1),

            PRIMARY KEY (pk".asc_desc_key($prng->uint16(0,2),$e)."),
            KEY (col_int_key".asc_desc_key($prng->uint16(0,2),$e)."),
            KEY (col_date_key".asc_desc_key($prng->uint16(0,2),$e)."),
            KEY (col_time_key".asc_desc_key($prng->uint16(0,2),$e)."),
            KEY (col_datetime_key".asc_desc_key($prng->uint16(0,2),$e)."),
            KEY (col_varchar_key".asc_desc_key($prng->uint16(0,2),$e).", col_int_key".asc_desc_key($prng->uint16(0,2),$e).")
        ) ".(length($name) > 1 ? " AUTO_INCREMENT=".(length($name) * 5) : "").($e ne '' ? " ENGINE=$e" : "").($connection_options ? " $connection_options" : '')
                           # For tables named like CC and CCC, start auto_increment with some offset. This provides better test coverage since
                           # joining such tables on PK does not produce only 1-to-1 matches.
        );
    }

  if (defined $views) {
    if ($views ne '') {
      $executor->execute("CREATE ALGORITHM=$views VIEW $db.view_".$name.' AS SELECT * FROM '.$db.'.'.$name);
    } else {
      $executor->execute("CREATE VIEW $db.view_".$name.' AS SELECT * FROM '.$db.'.'.$name);
    }
  }

  my @values;

  foreach my $row (1..$size) {

    # 10% NULLs, 10% tinyint_unsigned, 80% digits

    my $pick1 = $prng->uint16(0,9);
    my $pick2 = $prng->uint16(0,9);

    my ($rnd_int1, $rnd_int2);
    $rnd_int1 = $pick1 == 9 ? "NULL" : ($pick1 == 8 ? $prng->int(0,255) : $prng->digit() );
    $rnd_int2 = $pick2 == 9 ? "NULL" : ($pick1 == 8 ? $prng->int(0,255) : $prng->digit() );

    # 10% NULLS, 10% '1900-01-01', pick real date/time/datetime for the rest

    my $rnd_date = $prng->date();
    $rnd_date = ($rnd_date, $rnd_date, $rnd_date, $rnd_date, $rnd_date, $rnd_date, $rnd_date, $rnd_date, "NULL", "'1900-01-01'")[$prng->uint16(0,9)];
    my $rnd_time = $prng->time();
    $rnd_time = ($rnd_time, $rnd_time, $rnd_time, $rnd_time, $rnd_time, $rnd_time, $rnd_time, $rnd_time, "NULL", "'00:00:00'")[$prng->uint16(0,9)];

    # 10% NULLS, 10% "1900-01-01 00:00:00', 20% date + " 00:00:00"

    my $rnd_datetime = $prng->datetime();
    my $rnd_datetime_round_date = "'".$prng->unquotedDate()." 00:00:00'";
    $rnd_datetime = ($rnd_datetime, $rnd_datetime, $rnd_datetime, $rnd_datetime, $rnd_datetime, $rnd_datetime, $rnd_datetime_round_date, $rnd_datetime_round_date, "NULL", "'1900-01-01 00:00:00'")[$prng->uint16(0,9)];

    my $rnd_varchar = $prng->uint16(0,9) == 9 ? "NULL" : $prng->string(1);

    push(@values, "($rnd_int1, $rnd_int2, $rnd_date, $rnd_date, $rnd_time, $rnd_time, $rnd_datetime, $rnd_datetime, $rnd_varchar, $rnd_varchar)");

    ## We do one insert per 500 rows for speed
    if ($row % 500 == 0 || $row == $size) {
      my $insert_result = $executor->execute(
      "INSERT /*! IGNORE */ INTO $db.$name (
        col_int_key, col_int_nokey,
        col_date_key, col_date_nokey,
        col_time_key, col_time_nokey,
        col_datetime_key, col_datetime_nokey,
        col_varchar_key, col_varchar_nokey
      ) VALUES " . join(",",@values));
      return $insert_result->status() if $insert_result->status() != STATUS_OK;
      @values = ();
    }
  }

  return STATUS_OK;
}

1;
