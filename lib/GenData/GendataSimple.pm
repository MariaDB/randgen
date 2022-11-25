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
use DBI;

use GenData;
use GenTest;
use GenTest::Constants;
use GenTest::Random;
use GenTest::Executor;
use GenUtil;

use Data::Dumper;

use constant GDS_DEFAULT_ROWS => [0, 1, 20, 100, 1000, 0, 1, 20, 100];
use constant GDS_DEFAULT_NAMES => ['A', 'B', 'C', 'D', 'E', 'AA', 'BB', 'CC', 'DD'];

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    return $self;
}

sub run {
    my ($self) = @_;

    say("Running GendataSimple");
    my $executor = $self->executor();

    my $names = GDS_DEFAULT_NAMES;
    my $rows;

    if (defined $self->rows()) {
        $rows = [split(',', $self->rows())];
    } else {
        $rows = GDS_DEFAULT_ROWS;
    }

    say("GendataSimple is creating tables in default schema");
    foreach my $i (0..$#$names) {
        my $gen_table_result = $self->gen_table($executor, $names->[$i], $rows->[$i]);
        return $gen_table_result if $gen_table_result != STATUS_OK;
    }

    my $private_db= 'private_gendata_simple';
    say("GendataSimple is creating tables in $private_db");
    my $res= $executor->execute("CREATE DATABASE IF NOT EXISTS $private_db");
    if ($res->status() != STATUS_OK) {
        sayError("Could not create database $private_db");
        return $res->status;
    }
    $executor->execute("USE $private_db");
    $executor->execute("SET SQL_MODE= CONCAT(\@\@sql_mode,',NO_ENGINE_SUBSTITUTION'), ENFORCE_STORAGE_ENGINE= NULL");
    foreach my $i (0..$#$names) {
        my $gen_table_result = $self->gen_table($executor, $names->[$i], $rows->[$i]);
        return $gen_table_result if $gen_table_result != STATUS_OK;
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
  my ($self, $executor, $basename, $size) = @_;

    my $prng = $self->rand;

    ### NULL is not a valid ANSI constraint, (but NOT NULL of course,
    ### is)

    my $engine = $self->engine();
    my $vcols = $self->vcols();
    my $views = $self->views();

    my @engines= ($engine ? split /,/, $engine : '');
    foreach my $e (@engines)
    {
      my $name = ( $e eq $engine ? $basename : $basename . '_'.$e );
      # For backward compatibility, only extend names
      # if multiple engines were provided

      say("Creating table $name, size $size rows, engine $e .");

      ### This variant is needed due to
      ### http://bugs.mysql.com/bug.php?id=47125

      $executor->execute("DROP TABLE /*! IF EXISTS */ $name");
      # RocksDB does not support virtual columns
      if ($vcols and lc($engine) ne 'rocksdb') {
          $executor->variate_and_execute(
          "CREATE TABLE $name (
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
              , my $gendata=1);
      } else {
          $executor->variate_and_execute(
          "CREATE TABLE $name (
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
          ) ".(length($name) > 1 ? " AUTO_INCREMENT=".(length($name) * 5) : "").($e ne '' ? " ENGINE=$e" : "")
                             # For tables named like CC and CCC, start auto_increment with some offset. This provides better test coverage since
                             # joining such tables on PK does not produce only 1-to-1 matches.
              , my $gendata=1);
      }

    if (defined $views) {
      if ($views ne '') {
        $executor->variate_and_execute("CREATE ALGORITHM=$views VIEW view_".$name.' AS SELECT * FROM '.$name, my $gendata=1);
      } else {
        $executor->variate_and_execute('CREATE VIEW view_'.$name.' AS SELECT * FROM '.$name, my $gendata=1);
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
        my $insert_result = $executor->variate_and_execute(
        "INSERT /*! IGNORE */ INTO $name (
          col_int_key, col_int_nokey,
          col_date_key, col_date_nokey,
          col_time_key, col_time_nokey,
          col_datetime_key, col_datetime_nokey,
          col_varchar_key, col_varchar_nokey
        ) VALUES " . join(",",@values),
        my $gendata=1);
        return $insert_result->status() if $insert_result->status() != STATUS_OK;
        @values = ();
      }
    }
  }
  return STATUS_OK;
}

1;
