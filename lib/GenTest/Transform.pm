# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013 Monty Program Ab.
# Copyright (c) 2016, 2022 MariaDB Corporation Ab.
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

package GenTest::Transform;

require Exporter;
@ISA = qw(GenTest);

use strict;

use lib 'lib';
use GenUtil;
use GenTest;
use Constants;
use GenTest::Executor::MRDB;
use GenTest::Random;
use Data::Dumper;

use constant TRANSFORMER_QUERIES_PROCESSED   => 0;
use constant TRANSFORMER_QUERIES_TRANSFORMED => 1;
use constant TRANSFORMER_SEED => 2;
use constant TRANSFORMER_RANDOM => 3;
use constant TRANSFORMER_EXECUTOR => 4;
use constant TRANSFORMER_ALLOWED_ERRORS => 5;

use constant TRANSFORM_OUTCOME_EXACT_MATCH            => 1001;
use constant TRANSFORM_OUTCOME_UNORDERED_MATCH        => 1002;
use constant TRANSFORM_OUTCOME_SUPERSET               => 1003;
use constant TRANSFORM_OUTCOME_SUBSET                 => 1004;
use constant TRANSFORM_OUTCOME_SINGLE_ROW             => 1005;
use constant TRANSFORM_OUTCOME_FIRST_ROW              => 1006;
use constant TRANSFORM_OUTCOME_DISTINCT               => 1007;
use constant TRANSFORM_OUTCOME_COUNT                  => 1008; # Transformed result is a count of the original
use constant TRANSFORM_OUTCOME_EMPTY_RESULT           => 1009;
use constant TRANSFORM_OUTCOME_SINGLE_INTEGER_ONE     => 1010;
use constant TRANSFORM_OUTCOME_EXAMINED_ROWS_LIMITED  => 1011;
use constant TRANSFORM_OUTCOME_COUNT_NOT_NULL         => 1012; # Transformed result is a count or the original except NULLs (for col => COUNT(col))
use constant TRANSFORM_OUTCOME_COUNT_REVERSE          => 1013; # Original is a count of the transformed result
use constant TRANSFORM_OUTCOME_COUNT_NOT_NULL_REVERSE => 1014; # Transformed result is a count of the original result except NULLs (for COUNT(col) => col)

my %transform_outcomes = (
    'TRANSFORM_OUTCOME_EXACT_MATCH'            => \&isOrderedMatch,
    'TRANSFORM_OUTCOME_UNORDERED_MATCH'        => \&isUnorderedMatch,
    'TRANSFORM_OUTCOME_SUPERSET'               => \&isSuperset,
    'TRANSFORM_OUTCOME_SUBSET'                 => TRANSFORM_OUTCOME_SUBSET,
    'TRANSFORM_OUTCOME_SINGLE_ROW'             => \&isSingleRow,
    'TRANSFORM_OUTCOME_FIRST_ROW'              => \&isFirstRow,
    'TRANSFORM_OUTCOME_DISTINCT'               => \&isDistinct,
    'TRANSFORM_OUTCOME_COUNT'                  => \&isCount,
    'TRANSFORM_OUTCOME_EMPTY_RESULT'           => \&isEmptyResult,
    'TRANSFORM_OUTCOME_SINGLE_INTEGER_ONE'     => \&isSingleIntegerOne,
    'TRANSFORM_OUTCOME_EXAMINED_ROWS_LIMITED'  => \&isRowsExaminedObeyed,
    'TRANSFORM_OUTCOME_COUNT_NOT_NULL'         => TRANSFORM_OUTCOME_COUNT_NOT_NULL,
    'TRANSFORM_OUTCOME_COUNT_REVERSE'          => TRANSFORM_OUTCOME_COUNT_REVERSE,
    'TRANSFORM_OUTCOME_COUNT_NOT_NULL_REVERSE' => TRANSFORM_OUTCOME_COUNT_NOT_NULL_REVERSE
);

# Subset of semantic errors that we may want to allow during transforms.
my %semantic_errors = (
    # In case of FULL GROUP BY
    1004 => 'ER_NON_GROUPING_FIELD_USED',
    1028 => 'ER_FILSORT_ABORT',
    # Transformation for CREATE statement can cause ER_TABLE_EXISTS_ERROR
    1050 => 'ER_TABLE_EXISTS_ERROR',
    1055 => 'ER_WRONG_FIELD_WITH_GROUP',
    1056 => 'ER_WRONG_GROUP_FIELD',
    1060 => 'DUPLICATE_COLUMN_NAME',
    # Union, intersect, except can complain about missing locks even if
    # the origina query went all right
    1100 => 'ER_TABLE_NOT_LOCKED',
    1104 => 'ER_TOO_BIG_SELECT',
    1111 => 'ER_INVALID_GROUP_FUNC_USE',
    1140 => 'ER_MIX_OF_GROUP_FUNC_AND_FIELDS',
    1192 => 'ER_LOCK_OR_ACTIVE_TRANSACTION',
    1205 => 'ER_LOCK_WAIT_TIMEOUT',
    1247 => 'ER_ILLEGAL_REFERENCE',
    1304 => 'ER_SP_ALREADY_EXISTS',
    1317 => 'ER_QUERY_INTERRUPTED',
    1359 => 'ER_TRG_ALREADY_EXISTS',
    # Sometimes the original query doesn't violate XA state (e.g. "SELECT 1" for IDLE),
    # but the transformed one does
    1399 => 'ER_XAER_RMFAIL',
    1415 => 'ER_SP_NO_RETSET',
    1560 => 'ER_STORED_FUNCTION_PREVENTS_SWITCH_BINLOG_FORMAT',
    1615 => 'ER_NEED_REPREPARE',
    2006 => 'CR_SERVER_GONE_ERROR',
    2013 => 'CR_SERVER_LOST',
    # Sequence numbers are used on every call, they can run out during
    # transformations even if the original query went all right
    4084 => 'ER_SEQUENCE_RUN_OUT',
    4175 => 'ER_JSON_TABLE_ERROR_ON_FIELD',
);

# List of encountered errors that we want to suppress later in the test run.
my %suppressed_errors = ();

sub setSeed {
  $_[0]->[TRANSFORMER_SEED]= $_[1];
}

sub seed {
  return $_[0]->[TRANSFORMER_SEED];
}

sub random {
  unless ($_[0]->[TRANSFORMER_RANDOM]) {
    $_[0]->[TRANSFORMER_RANDOM]= GenTest::Random->new(seed => $_[0]->[TRANSFORMER_SEED]);
  }
  return $_[0]->[TRANSFORMER_RANDOM];
}

# To be overridden in a transformer if necessary
sub compatibility {
  return '000000';
}

sub transformExecuteValidate {
    my ($transformer, $original_query, $original_result, $executor) = @_;

    $transformer->[TRANSFORMER_QUERIES_PROCESSED]++;
    # Do not transform queries with /*executorN */ comments, they are for comparison
    return STATUS_OK if ($original_query =~ /\/\*executor\d/);

    my $transformer_output = $transformer->transform($original_query, $executor, $original_result);
    my $transform_blocks;

    if ($transformer_output =~ m{^\d+$}sgio) {
        if ($transformer_output == STATUS_WONT_HANDLE) {
            return STATUS_OK;
        } else {
            return $transformer_output;     # Error was returned and no queries
        }
    } elsif (ref($transformer_output) eq 'ARRAY') {
        if (ref($transformer_output->[0]) eq 'ARRAY') {
            # Transformation produced more than one block of queries
            $transform_blocks = $transformer_output;
        } else {
            # Transformation produced a single block of queries
            $transform_blocks = [ $transformer_output ];
        }
    } else {
        # Transformation produced a single query, convert it to a single block
        $transform_blocks = [ [ $transformer_output ] ];
    }

    # See a comment to sub cleanup()
    my $cleanup_block = pop @$transform_blocks;
    if ($cleanup_block->[0] =~ /TRANSFORM_CLEANUP/) {
        $cleanup_block->[0] = '/* '. $transformer->name .' */ ' . $cleanup_block->[0];
    } else {
        push @$transform_blocks, $cleanup_block;
        $cleanup_block = undef;
    }

    my @transformed_results;
    my $transform_outcome= STATUS_OK;
    my $transformed_count= 0;
   BLOCK:
    foreach my $transform_block (@$transform_blocks) {
      my @transformed_queries = @$transform_block;
      foreach my $transformed_query_part (@transformed_queries) {
        my $part_result = $executor->execute("/* ". $transformer->name ." */ ".$transformed_query_part);

        push @transformed_results, $part_result;

        $transform_outcome= $part_result->status() if $part_result->status() > $transform_outcome;
        last BLOCK if $transform_outcome > STATUS_CRITICAL_FAILURE;

        $transformed_count++ if ($transformed_query_part =~ /\WTRANSFORM_OUTCOME_\w+\W/);
      }
    }
    cleanup($executor, $cleanup_block);

    if ($transformed_count == 0) {
      sayError($transformer->name ." did not produce any queries which could be validated. Status will be set to ENVIRONMENT_FAILURE. ".
        "The following queries were produced: ".(Dumper $transform_blocks));
      return STATUS_ENVIRONMENT_FAILURE;
    }

    $transformer->[TRANSFORMER_QUERIES_TRANSFORMED]+= $transformed_count;
    return ($transform_outcome, \@transformed_results);
}

# Some transformations can end prematurely and leave the environment in a dirty state,
# e.g. with some variables changed.
# If a transformation changes the environment, it must have a block marked as TRANSFORM_CLEANUP
# (as a comment before the first statement in the block). If such a block exists,
# it will be executed even if the transformation is going to quit.
sub cleanup {
    my ($executor, $cleanup_block) = @_;
    if ($cleanup_block) {
        my @cleanup_queries = @$cleanup_block;
        foreach my $cleanup_query_part (@cleanup_queries) {
            $executor->execute($cleanup_query_part);
        }
    }
}

sub validate {
    my ($transformer, $original_result, $transformed_result, $transform_outcome) = @_;

    my $transformed_query = $transformed_result->query();

    if ($transform_outcome == TRANSFORM_OUTCOME_SINGLE_ROW) {
        return $transformer->isSingleRow($original_result, $transformed_result);
    } elsif ($transform_outcome == TRANSFORM_OUTCOME_DISTINCT) {
        return $transformer->isDistinct($original_result, $transformed_result);
    } elsif ($transform_outcome == TRANSFORM_OUTCOME_UNORDERED_MATCH) {
        return GenTest::Comparator::compare($original_result, $transformed_result);
    } elsif ($transform_outcome == TRANSFORM_OUTCOME_SUPERSET) {
        return $transformer->isSuperset($original_result, $transformed_result);
    } elsif ($transform_outcome == TRANSFORM_OUTCOME_FIRST_ROW) {
        return $transformer->isFirstRow($original_result, $transformed_result);
    } elsif ($transform_outcome == TRANSFORM_OUTCOME_COUNT) {
        return $transformer->isCount($original_result, $transformed_result);
    } elsif ($transform_outcome == TRANSFORM_OUTCOME_COUNT_REVERSE) {
        return $transformer->isCount($original_result, $transformed_result, my $reverse=1);
    } elsif ($transform_outcome == TRANSFORM_OUTCOME_COUNT_NOT_NULL) {
        return $transformer->isCount($original_result, $transformed_result, my $reverse=0, my $notnull=1);
    } elsif ($transform_outcome == TRANSFORM_OUTCOME_COUNT_NOT_NULL_REVERSE) {
        return $transformer->isCount($original_result, $transformed_result, my $reverse=1, my $notnull=1);
    } elsif ($transform_outcome == TRANSFORM_OUTCOME_EMPTY_RESULT) {
        return $transformer->isEmptyResult($original_result, $transformed_result);
    } elsif ($transform_outcome == TRANSFORM_OUTCOME_SINGLE_INTEGER_ONE) {
        return $transformer->isSingleIntegerOne($original_result, $transformed_result);
    } elsif ($transform_outcome == TRANSFORM_OUTCOME_EXAMINED_ROWS_LIMITED) {
        return $transformer->isRowsExaminedObeyed($transformed_query, $transformed_result);
        } elsif ($transform_outcome == TRANSFORM_OUTCOME_SUBSET) {
                return $transformer->isSuperset($transformed_result, $original_result);
    } elsif ($transform_outcome == TRANSFORM_OUTCOME_COUNT_NOT_NULL) {
        return $transformer->isCountNotNull($original_result, $transformed_result);
    } else {
        return STATUS_WONT_HANDLE;
    }
}

sub isFirstRow {
    my ($transformer, $original_result, $transformed_result) = @_;

    if (
        ($original_result->rows() == 0) &&
        ($transformed_result->rows() == 0)
    ) {
        return STATUS_OK;
    } else {
        my $row1 = join('<col>', @{$original_result->data()->[0]});
        my $row2 = join('<col>', @{$transformed_result->data()->[0]});
        return STATUS_CONTENT_MISMATCH if $row1 ne $row2;
    }
    return STATUS_OK;
}

sub isDistinct {
    my ($transformer, $original_result, $transformed_result) = @_;

    my $original_rows;
    my $transformed_rows;

    foreach my $row_ref (@{$original_result->data()}) {
        my $row = lc(join('<col>', map { defined $_ ? $_ : '<NULL>' } (@$row_ref)));
        $original_rows->{$row}++;
    }

    foreach my $row_ref (@{$transformed_result->data()}) {
        my $row = lc(join('<col>', map { defined $_ ? $_ : '<NULL>' } (@$row_ref)));
        $transformed_rows->{$row}++;
        if ($transformed_rows->{$row} > 1) {
          sayError("Non-distinct row: $row");
          # HERE:
          print Dumper $original_result->data();
          return STATUS_LENGTH_MISMATCH
        }
    }


    my $distinct_original = join ('<row>', sort keys %{$original_rows} );
    my $distinct_transformed = join ('<row>', sort keys %{$transformed_rows} );

    if ($distinct_original ne $distinct_transformed) {
        return STATUS_CONTENT_MISMATCH;
    } else {
        return STATUS_OK;
    }
}

sub isSuperset {
    my ($transformer, $original_result, $transformed_result) = @_;
    my %rows;

    foreach my $row_ref (@{$original_result->data()}) {
        my $row = join('<col>', @$row_ref);
        $rows{$row}++;
    }

    foreach my $row_ref (@{$transformed_result->data()}) {
        my $row = join('<col>', @$row_ref);
        $rows{$row}--;
    }

    foreach my $row (keys %rows) {
        return STATUS_LENGTH_MISMATCH if $rows{$row} > 0;
    }

    return STATUS_OK;
}

sub isSingleRow {
    my ($transformer, $original_result, $transformed_result) = @_;

    if (
        ($original_result->rows() == 0) &&
        ($transformed_result->rows() == 0)
    ) {
        return STATUS_OK;
    } elsif ($transformed_result->rows() == 1) {
        my $transformed_row = join('<col>', @{$transformed_result->data()->[0]});
        foreach my $original_row_ref (@{$original_result->data()}) {
            my $original_row = join('<col>', @$original_row_ref);
            return STATUS_OK if $original_row eq $transformed_row;
        }
        return STATUS_CONTENT_MISMATCH;
    } else {
        # More than one row, something is messed up
        return STATUS_LENGTH_MISMATCH;
    }
}

sub isCount {
    my ($transformer, $original_result, $transformed_result, $reverse, $notnull) = @_;
    my ($resultset, $count);
    if ($reverse) {
      $count= $original_result;
      $resultset= $transformed_result;
    } else {
      $resultset= $original_result;
      $count= $transformed_result;
    }

    unless ($count->rows() == 1) {
      sayError("Expected 1 row in the COUNT resultset, found ".$count->rows());
      return STATUS_LENGTH_MISMATCH;
    }

    my $countval= $count->data()->[0]->[0];

    if ($notnull) {
      my $notnull_count= 0;
      foreach my $r (@{$resultset->data()}) {
        $notnull_count++ if defined $r->[0];
      }
      if ($notnull_count == $countval) {
        return STATUS_OK;
      } else {
        sayError("Resultset contains ".$notnull_count." non-null values, count returned $countval");
        return STATUS_LENGTH_MISMATCH;
      }
    }
    elsif ($resultset->rows() == $countval) {
      return STATUS_OK;
    } else {
      sayError("Resultset length is ".$resultset->rows().", count returned $countval");
      return STATUS_LENGTH_MISMATCH;
    }
}

sub isEmptyResult {
    my ($transformer, $original_result, $transformed_result) = @_;

    if ($transformed_result->rows() == 0) {
        return STATUS_OK;
    } else {
        return STATUS_LENGTH_MISMATCH;
    }
}

sub isSingleIntegerOne {
    my ($transformer, $original_result, $transformed_result) = @_;

    if (
        ($transformed_result->rows() == 1) &&
        ($#{$transformed_result->data()->[0]} == 0) &&
        ($transformed_result->data()->[0]->[0] eq '1')
    ) {
        return STATUS_OK;
    } else {
        return STATUS_LENGTH_MISMATCH;
    }
}

sub isRowsExaminedObeyed {
    my ($transformer, $original_result, $transformed_result) = @_;
    my $transformed_query = $transformed_result->query();
    # The comment already contains the calculated maximum, including the margin,
    # we only need to do the comparison
    return STATUS_WONT_HANDLE if ($transformed_query !~ m{TRANSFORM_OUTCOME_EXAMINED_ROWS_LIMITED\s+(\d+)}s);
    if ( $transformed_result->data()->[0]->[0] > $1 ) {
        sayDebug("Number of examined rows " . $transformed_result->data()->[0]->[0] . ", max allowed (with margin) $1");
        return STATUS_REQUIREMENT_UNMET;
    } else {
        return STATUS_OK;
    }
}

sub executor {
  my ($self, $executor)= @_;
  if ($executor) {
    $self->[TRANSFORMER_EXECUTOR]= $executor;
  } else {
    return $self->[TRANSFORMER_EXECUTOR];
  }
}

sub allowedErrors {
  my ($self, $errref)= @_;
  if ($errref) {
    $self->[TRANSFORMER_ALLOWED_ERRORS]= { %$errref };
  } else {
    return $self->[TRANSFORMER_ALLOWED_ERRORS];
  }
}

sub name {
    my $transformer = shift;
    my ($name) = $transformer =~ m{.*::([a-z]*)}sgio;
    return $name;
}


sub DESTROY {
  my $transformer = shift;
  if ($transformer->name ne 'Transform') {
    sayDebug($transformer->name.": queries_processed: ".($transformer->[TRANSFORMER_QUERIES_PROCESSED] || 0)."; queries_transformed: ".($transformer->[TRANSFORMER_QUERIES_TRANSFORMED] || 0));
  }
}

1;
