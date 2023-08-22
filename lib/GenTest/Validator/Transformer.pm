# Copyright (c) 2008,2011 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2021, 2023 MariaDB
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

package GenTest::Validator::Transformer;

require Exporter;
@ISA = qw(GenTest::Validator GenTest);

use strict;

use Carp;
use Data::Dumper;
use GenUtil;
use GenTest;
use Constants;
use GenTest::Comparator;

my %transform_outcomes = (
    'TRANSFORM_OUTCOME_EXACT_MATCH'            => \&isOrderedMatch,
    'TRANSFORM_OUTCOME_UNORDERED_MATCH'        => \&isUnorderedMatch,
    'TRANSFORM_OUTCOME_SUPERSET'               => \&isSuperset,
    'TRANSFORM_OUTCOME_SUBSET'                 => \&isSubset,
    'TRANSFORM_OUTCOME_SINGLE_ROW'             => \&isSingleRow,
    'TRANSFORM_OUTCOME_FIRST_ROW'              => \&isFirstRow,
    'TRANSFORM_OUTCOME_DISTINCT'               => \&isDistinct,
    'TRANSFORM_OUTCOME_COUNT'                  => \&isCountNormal,
    'TRANSFORM_OUTCOME_EMPTY_RESULT'           => \&isEmptyResult,
    'TRANSFORM_OUTCOME_SINGLE_INTEGER_ONE'     => \&isSingleIntegerOne,
    'TRANSFORM_OUTCOME_EXAMINED_ROWS_LIMITED'  => \&isRowsExaminedObeyed,
    'TRANSFORM_OUTCOME_COUNT_NOT_NULL'         => \&isCountNotNull,
    'TRANSFORM_OUTCOME_COUNT_REVERSE'          => \&isCountReverse,
    'TRANSFORM_OUTCOME_COUNT_NOT_NULL_REVERSE' => \&isCountNotNullReverse
);

my @transformer_names;
my @transformers;

my %allowed_globally = (
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
my %reported_errors = ();

sub configure {
    my ($self, $props) = @_;

    my $list = $props->transformers;

  if (defined $list and $#{$list} >= 0) {
    @transformer_names = @$list;
  } else {
    sayWarning("No transformers were defined to be run by Transformer validator");
    return;
  }

  say("Transformer validator will use the following transformers: ".join(', ', @transformer_names));

  foreach my $transformer_name (@transformer_names) {
    eval ("require GenTest::Transform::'".$transformer_name) or croak $@;
    my $transformer = ('GenTest::Transform::'.$transformer_name)->new();
    push @transformers, $transformer;
  }
}

# Executors and execution results are multiple in validate because
# GENERALLY a validator can receive results from several executors (different servers),
# and validate them against each other. But here in Transformer we assume
# one executor and hence one result only
sub validate {
  my ($validator, $executors, $results) = @_;

  my $original_result = $results->[0];
  my $executor = $executors->[0];
  my $original_query = $original_result->query();

  return STATUS_WONT_HANDLE if $original_result->status() != STATUS_OK;
  return STATUS_WONT_HANDLE if defined $original_result->warnings();
  return STATUS_WONT_HANDLE if not defined $original_result->data();
  # Also return a dataset, but we won't compare them
  return STATUS_WONT_HANDLE if $original_query =~ /^\s*(?:SHOW|ANALYZE|REPAIR|OPTIMIZE|EXPLAIN)/is;

  # Get the plan before doing any transformations. Still not a guarantee
  # that it's the right one, but better chance than getting it later
  my $original_explain;
  if ($original_query =~ m{^[\(\s]*(?:SELECT|WITH|VALUES)}is) {
    $original_explain= $executor->execute("EXPLAIN $original_query");
  }

  my $max_transformer_status= STATUS_OK;
  $executor->connection->execute("SELECT CONCAT('SET ROLE ',IFNULL(CURRENT_ROLE(),'NONE')) INTO ".'@role_stmt');
  if ($executor->connection->err) {
    sayError("Couldn't store current role in Transformer validator: ".$executor->connection->print_error);
    return STATUS_ENVIRONMENT_FAILURE;
  }
  $executor->connection->execute('SET ROLE admin');
  if ($executor->connection->err) {
    sayError("Couldn't set admin role in Transformer validator: ".$executor->connection->print_error);
    return STATUS_ENVIRONMENT_FAILURE;
  }
  
  foreach my $transformer (@transformers) {
    next if isOlderVersion($executor->server->version(),$transformer->compatibility);
    if (time() > $executor->end_time) {
      say("Transformer: Test duration has already been exceeded, exiting");
      last;
    }
    my $transformer_status = $validator->transform($transformer, $executor, $original_result, $original_explain);
    $max_transformer_status = $transformer_status if $transformer_status > $max_transformer_status;
    last if $transformer_status >= STATUS_CRITICAL_FAILURE;
  }
  $executor->connection->execute('EXECUTE IMMEDIATE @role_stmt');
  if ($executor->connection->err) {
    sayError("Couldn't restore previous role in Transformer validator");
    return STATUS_ENVIRONMENT_FAILURE;
  }
  return $max_transformer_status;
}

sub transform {
  my ($validator, $transformer, $executor, $original_result, $original_explain) = @_;
  my $original_query = $original_result->query();
  my $name= $transformer->name;
  my $allowed_by_transformer= $transformer->allowedErrors();

  my ($transform_outcome, $transformed_results) = $transformer->transformExecuteValidate($original_query, $original_result, $executor);

  if (
    ($transform_outcome >= STATUS_CRITICAL_FAILURE) ||
    ($transform_outcome == STATUS_WONT_HANDLE) ||
    ($transform_outcome == STATUS_SKIP)
  ) {
    return $transform_outcome;
  }

  $transform_outcome= STATUS_OK;
  my @transformed_queries= ();

  foreach my $tr (@$transformed_results) {
    push @transformed_queries, $tr->query;
    next unless $tr->query =~ /\W(TRANSFORM_OUTCOME_\w+)\W/;
    next if $tr->status == STATUS_SKIP;
    my $expected_outcome= $1;
    unless (defined $transform_outcomes{$expected_outcome}) {
      sayError("$name generated a query with unknown expected outcome: $expected_outcome. ENVIRONMENT_FAILURE will be returned");
      return STATUS_ENVIRONMENT_FAILURE;
    }

    if ($tr->status != STATUS_OK) {
      if (exists $allowed_globally{$tr->err()} || (defined $allowed_by_transformer and exists $allowed_by_transformer->{$tr->err()}))
      {
        # We return an error when a transformer returns certain semantic
        # or syntax errors, which allows detecting faulty
        # transformers, e.g. those which do not produce valid queries.
        #
        # Most often the required change to these transformers
        # would be to exclude the failing query by using
        # STATUS_WONT_HANDLE within the transformer.
        #
        # As such, we now return STATUS_WONT_HANDLE here, which allows
        # to continue without aborting, while covering almost
        # all situations (i.e. STATUS_WONT_HANDLE) correctly already.
        #
        # Additionally, some errors may need to be accepted in certain
        # situations or for certain transformations. They can be defined
        # via allowedErrors subroutine.
        #
        if (not defined $reported_errors{$name.':'.$tr->err()}) {
            say("$name: Ignoring transformation failures: ".$tr->err()." (".$tr->errstr().")");
            $reported_errors{$name.':'.$tr->err()}++;
        } else {
            sayDebug("$name: Ignoring transformation failure: ".$tr->err()." (".$tr->errstr().")");
        }
        sayDebug("Original query is: ".shorten_message($original_query)."\nOffending query is: ".shorten_message($tr->query));
      }
      else {
        # If we are here, the transformed query returned an error
        # and it's not on the allowed list
        sayWarning(
          "---------- TRANSFORM PROBLEM ($name) ----------\n".
          "$name: Transformation error: ".$tr->err()." ".$tr->errstr().
            "; RQG Status: ".status2text($tr->status())." (".$tr->status().")"."\n".
          "Original query is: ".shorten_message($original_query)."\n".
          "Offending query is: ".shorten_message($tr->query)."\n".
          "All previous transformed queries: \n".
          (join "\n", map { shorten_message($_) } (@transformed_queries))."\n".
          "----------------- END ($name) -----------------");
      }
      next;
    }

    # If we are here, the transformed query succeeded and we need to check
    # whether it matches the expected outcome.

    # First we do some normalization, e.g.
    # - zerofilled values can in some resultsets have leading zeros and in others not;
    # - also, trailing spaces are insignificant for comparison purposes
    # - we'll also convert undefs to <NULL> while we are here
    sub normalize {
      my $data= shift;
      foreach my $ri (0..$#$data) {
        foreach my $vi (0..$#{$data->[$ri]}) {
          $data->[$ri]->[$vi] = '<NULL>' if not defined $data->[$ri]->[$vi];
          $data->[$ri]->[$vi] =~ s/^0*(\d+)$/$1/;
          $data->[$ri]->[$vi] =~ s/(.*?)\s*$/$1/;
        }
      }
      return $data;
    }
    $original_result->data(normalize($original_result->data()));
    $tr->data(normalize($tr->data()));

    my $check= $transform_outcomes{$expected_outcome};

    my ($check_outcome, $report)= $validator->$check($original_result, $tr, $executor, $original_explain);

    if ($check_outcome != STATUS_OK) {
      # Get non-default session variables
      my $vars= $executor->connection->get_column('select concat(variable_name,"=",session_value) from information_schema.system_variables where session_value != global_value order by variable_name');
      say("---------- TRANSFORM ISSUE START ($name) ----------\n".
          "RQG Status: ".status2text($check_outcome)." ($check_outcome)\n".
          "Original query: ".shorten_message($original_query)."\n".
          "Transformed query: ".shorten_message($tr->query)."\n".
          $report.
          "All previous transformed queries: \n".
          (join "\n", map { shorten_message($_) } (@transformed_queries))."\n".
          (($vars && scalar(@$vars)) ? "Non-default session vars: \n".(join "\n", @$vars)."\n" : "").
          "----------------- END OF ($name) ------------------"
      );
      $transform_outcome= $check_outcome if $check_outcome > $transform_outcome;
    }
  }
  return $transform_outcome;
}

########################
# Checkers and reports

sub isMatch {
    my ($validator, $original_result, $transformed_result, $executor, $original_explain, $ordered) = @_;
    return (STATUS_OK, undef) if $validator->resultsetsNotComparable([$original_result, $transformed_result]);
    my $res= ($ordered ? GenTest::Comparator::compare_as_ordered($original_result, $transformed_result)
                       : GenTest::Comparator::compare($original_result, $transformed_result)
             );
    my $report= undef;
    if ($res != STATUS_OK) {
      $report= "Result set mismatch";
      if ($original_result->rows != $transformed_result->rows) {
        $report.= ' ('.$original_result->rows.' vs '.$transformed_result->rows.')';
      }
      $report.= ":\n".GenTest::Comparator::dumpDiff($original_result, $transformed_result);
      if ($original_explain && $original_explain->data()) {
        my $transformed_explain= pop @$transformed_result;
        if ($transformed_explain && $transformed_explain->data) {
          $report.= "EXPLAIN diff:\n".GenTest::Comparator::dumpDiff($original_explain, $transformed_explain);
        }
      }
    }
    return ($res, $report);
}

sub isUnorderedMatch {
    my ($validator, $original_result, $transformed_result, $executor, $original_explain) = @_;
    return $validator->isMatch($original_result, $transformed_result, $executor, $original_explain, my $ordered=0);
}

sub isOrderedMatch {
    my ($validator, $original_result, $transformed_result, $executor, $original_explain) = @_;
    return $validator->isMatch($original_result, $transformed_result, $executor, $original_explain, my $ordered=1);
}

sub isFirstRow {
    my ($validator, $original_result, $transformed_result) = @_;
    if (
        ($original_result->rows() == 0) &&
        ($transformed_result->rows() == 0)
    ) {
        return (STATUS_OK, undef);
    } else {
        my $row1 = join('<col>', @{$original_result->data()->[0]});
        my $row2 = join('<col>', @{$transformed_result->data()->[0]});
        if ($row1 ne $row2) {
          my $report= "First row mismatch:\n$row1\n$row2";
          return ($report, STATUS_CONTENT_MISMATCH);
        }
    }
    return (STATUS_OK, undef);
}

sub isDistinct {
    my ($validator, $original_result, $transformed_result) = @_;

    my $original_rows;
    my $transformed_rows;

    foreach my $row_ref (@{$original_result->data()}) {
      my $row = lc(join('<col>', @$row_ref));
      $original_rows->{$row}++;
    }

    my $report= "Distinct violation:\n";
    my $res= STATUS_OK;
    foreach my $row_ref (@{$transformed_result->data()}) {
      my $row = lc(join('<col>', @$row_ref));
      if (not defined $original_rows->{$row}) {
        $report.= "Unexpected row: $row\n";
        $res= STATUS_CONTENT_MISMATCH;
      }
      $transformed_rows->{$row}++;
      if ($transformed_rows->{$row} > 1) {
        $report.= "Non-distinct row: $row\n";
        $res= STATUS_CONTENT_MISMATCH;
      }
    }
    if ($res != STATUS_OK) {
      $report.= "\n".GenTest::Comparator::dumpDiff($original_result, $transformed_result);
    }
    return ($res, $report);
}

sub isSuperset {
    my ($validator, $original_result, $transformed_result) = @_;
    my %rows;

    foreach my $row_ref (@{$original_result->data()}) {
        my $row = join('<col>', @$row_ref);
        $rows{$row}++;
    }

    foreach my $row_ref (@{$transformed_result->data()}) {
        my $row = join('<col>', @$row_ref);
        $rows{$row}--;
    }
    my ($res, $report)= (STATUS_OK, "Subset/superset violation:\n");
    foreach my $row (keys %rows) {
      if ($rows{$row} > 0) {
        $report.= "Unexpected row(s): $row\n";
        $res= STATUS_LENGTH_MISMATCH;
      }
    }

    return ($res, $report);
}

sub isSubset {
    my ($validator, $original_result, $transformed_result) = @_;
    return $validator->isSuperset($transformed_result, $original_result);
}

sub isSingleRow {
    my ($validator, $original_result, $transformed_result) = @_;

    if (
        ($original_result->rows() == 0) &&
        ($transformed_result->rows() == 0 || $transformed_result->rows() == 1)
    ) {
        return (STATUS_OK, undef);
    } elsif ($transformed_result->rows() == 1) {
        my $transformed_row = join('<col>', @{$transformed_result->data()->[0]});
        foreach my $original_row_ref (@{$original_result->data()}) {
            my $original_row = join('<col>', @$original_row_ref);
            return (STATUS_OK, undef) if $original_row eq $transformed_row;
        }
        return (STATUS_CONTENT_MISMATCH, "Single row violation - not found in the original set:\n$transformed_row");
    } else {
        # More than one row, something is messed up
        return (STATUS_LENGTH_MISMATCH, "Single row violation: ".$transformed_result->rows()." rows found:\n".(Dumper $transformed_result->data));
    }
}

sub isCount {
    my ($validator, $resultset, $count, $executor, $notnull) = @_;

    unless ($count->rows() == 1) {
      return (STATUS_LENGTH_MISMATCH, "Count violation - ".$count->rows()." found in the COUNT query:\n".(Dumper $count));
    }

    my $countval= $count->data()->[0]->[0];

    if ($notnull) {
      my $notnull_count= 0;
      foreach my $r (@{$resultset->data()}) {
        $notnull_count++ if ($r->[0] ne '<NULL>');
      }
      if ($notnull_count == $countval) {
        return (STATUS_OK, undef);
      } else {
        return (STATUS_LENGTH_MISMATCH, "Count violation - resultset contains ".$notnull_count." non-null values, count returned $countval\n");
      }
    }
    elsif ($resultset->rows() == $countval) {
      return (STATUS_OK, undef);
    } else {
      return (STATUS_LENGTH_MISMATCH, "Count violation - resultset length is ".$resultset->rows().", count returned $countval\n");
    }
}

sub isCountNormal {
    my ($validator, $original_result, $transformed_result, $executor) = @_;
    return $validator->isCount($original_result, $transformed_result, $executor);
}

sub isCountNotNull {
    my ($validator, $original_result, $transformed_result, $executor) = @_;
    return $validator->isCount($original_result, $transformed_result, $executor, my $notnull=1);
}

sub isCountNotNullReverse {
    my ($validator, $original_result, $transformed_result, $executor) = @_;
    return $validator->isCount($transformed_result, $original_result, $executor, my $notnull=1);
}

sub isCountReverse {
    my ($validator, $original_result, $transformed_result, $executor) = @_;
    return $validator->isCount($transformed_result, $original_result, $executor);
}

sub isEmptyResult {
    my ($validator, $original_result, $transformed_result) = @_;

    if ($transformed_result->rows() == 0) {
        return (STATUS_OK, undef);
    } else {
        return (STATUS_LENGTH_MISMATCH, "Empty result violation - not empty\n".(Dumper $transformed_result->data()));
    }
}

sub isSingleIntegerOne {
    my ($validator, $original_result, $transformed_result) = @_;

    if (
        ($transformed_result->rows() == 1) &&
        ($#{$transformed_result->data()->[0]} == 0) &&
        ($transformed_result->data()->[0]->[0] eq '1')
    ) {
        return (STATUS_OK, undef);
    } else {
        return (STATUS_CONTENT_MISMATCH, "Result 1 violation - expected to get 1, but got ".$transformed_result->data()->[0]->[0]."\n")
    }
}

sub isRowsExaminedObeyed {
    my ($validator, $original_result, $transformed_result) = @_;
    my $transformed_query = $transformed_result->query();
    # The comment already contains the calculated maximum, including the margin,
    # we only need to do the comparison
    return (STATUS_WONT_HANDLE, undef) if ($transformed_query !~ m{TRANSFORM_OUTCOME_EXAMINED_ROWS_LIMITED\s+(\d+)}s);
    if ( $transformed_result->rows() > $1 ) {
        return (STATUS_LENGTH_MISMATCH, "Rows examined violation - number of returned rows " . $transformed_result->rows() . ", max allowed to examine $1\n");
    } else {
        return (STATUS_OK, undef);
    }
}

########################

sub DESTROY {
  @transformers = ();
}

1;
