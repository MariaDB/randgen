# Copyright (c) 2008,2011 Oracle and/or its affiliates. All rights reserved.
# Copyright (C) 2022, 2023 MariaDB
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

package GenTest::Validator;

@ISA = qw(GenTest);

use strict;
use GenTest::Result;
use GenUtil;
use File::Temp qw/tempfile/;
use Carp;

use constant VALIDATOR_CONNECTION => 0;
use constant VALIDATOR_INVALIDATED_TABlES  => 1;

use constant ER_QUERY_EXCEEDED_ROWS_EXAMINED_LIMIT => 1931;

sub new {
  my $class = shift;
  my $validator= $class->SUPER::new({}, @_);
  $validator->[VALIDATOR_INVALIDATED_TABlES]= {};
  return $validator;
}

sub init {
  return 1;
}

sub configure {
    return 1;
}

sub prerequsites {
  return undef;
}

sub compatibility {
  return '000000';
}

sub invalidated_tables {
  return $_[0]->[VALIDATOR_INVALIDATED_TABlES];
}

sub invalidate_table {
  $_[0]->[VALIDATOR_INVALIDATED_TABlES]->{$_[1]}= 1;
}

sub reconcile_table {
  my ($self, $table, $executors)= @_;
  my $table_backup= $table;
  my $table_tmp= $table;
  # If the table name comes with backticks, we put the suffix into the backticks,
  # otherwise just append it
  if ($table_backup =~ s/`$/_validator_bk`/) {
    $table_tmp =~ s/\`$/_validator_tmp`/;
  } else {
    $table_backup.= '_v_bk';
    $table_tmp.= '_v_new';
  }
  my $create = $executors->[0]->connection->selectcol_get_value("SHOW CREATE TABLE $table", 1, 2);
  $create =~ s/^.*?\(/\(/;
  my ($dump_fh, $dump)= tempfile("validatorXXXXXX", DIR => $executors->[0]->vardir);
  unlink($dump);
  $executors->[0]->connection->execute("SELECT * INTO OUTFILE '$dump' FROM $table");
  foreach my $e (@$executors) {
    $e->connection->execute("SET \@sql_mode.validator= \@\@sql_mode; SET sql_mode= ''; CREATE OR REPLACE TABLE $table_tmp $create; RENAME TABLE $table TO $table_backup, $table_tmp TO $table; DROP TABLE $table_backup; SET sql_mode= \@sql_mode.validator");
    if ($e->connection->err) {
      sayWarning("Could not reconcile table $table: ".$e->connection->print_error);
      $e->connection->execute("DROP TABLE IF EXISTS $table_backup, $table_tmp; SET sql_mode= \@sql_mode.validator");
      unlink($dump);
      return 1;
    } else {
      # LOAD is the best effort
      $e->connection->execute("LOAD DATA LOCAL INFILE '$dump' IGNORE INTO TABLE $table");
    }
  }
  unlink($dump);
  return 0;
}

sub is_table_invalidated {
  return (exists $_[0]->[VALIDATOR_INVALIDATED_TABlES]->{$_[1]} ? 1 : 0);
}

sub vindicate_table {
  delete %{$_[0]->[VALIDATOR_INVALIDATED_TABlES]}{$_[1]};
}

sub resultsetsNotComparable {
  my ($self, $results)= @_;
  if ($results->[0]->query() =~ /RESULTSETS_NOT_COMPARABLE/) {
    sayDebug("Results are not comparable according to the flag in the query");
    return 1;
  }
  if ($results->[0]->query() =~ /(?:FETCH|OFFSET|LIMIT)/i and $results->[0]->query() !~ /ORDER\s+BY/i) {
    sayDebug("Results are not comparable due to the use of LIMIT without ORDER BY\n".$results->[0]->query());
    return 1;
  }
  foreach my $i (0..$#$results) {
    if ($results->[$i]->warnings()) {
      foreach my $w (@{$results->[$i]->warnings()}) {
        if ($w->[1] == ER_QUERY_EXCEEDED_ROWS_EXAMINED_LIMIT) {
          sayDebug("Results are not comparable as the query has hit ER_QUERY_EXCEEDED_ROWS_EXAMINED_LIMIT (at least) on server ".($i+1));
          return 1;
        }
      }
    }
  }
  return 0;
}

1;
