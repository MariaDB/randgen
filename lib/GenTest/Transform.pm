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

sub setSeed {
  $_[0]->[TRANSFORMER_SEED]= $_[1];
}

sub seed {
  return $_[0]->[TRANSFORMER_SEED];
}

sub random {
  unless ($_[0]->[TRANSFORMER_RANDOM]) {
    $_[0]->[TRANSFORMER_RANDOM]= GenTest::Random->new(seed => $_[0]->[TRANSFORMER_SEED], compatibility => $_[0]->compatibility);
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

        $transform_outcome= $part_result->status() if $part_result->status() > $transform_outcome;
        last BLOCK if $transform_outcome >= STATUS_CRITICAL_FAILURE;

        if ($transformed_query_part =~ /\WTRANSFORM_OUTCOME_\w+\W/) {
          $transformed_count++;
          if ($transformed_query_part =~ /^[\s\(]*(?:SELECT|WITH|VALUES)/si) {
            my $explain= $executor->execute("EXPLAIN $transformed_query_part");
            push @$part_result, $explain;
          }
        }
        push @transformed_results, $part_result;
      }
    }
    cleanup($executor, $cleanup_block);

    if ($transform_outcome < STATUS_CRITICAL_FAILURE and $transformed_count == 0) {
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
