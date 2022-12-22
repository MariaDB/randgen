# Copyright (c) 2008,2011 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2021, 2022 MariaDB Corporation Ab.
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
use GenUtil;
use GenTest;
use GenTest::Constants;
use GenTest::Comparator;

my @transformer_names;
my @transformers;

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

sub validate {
  my ($validator, $executors, $results) = @_;

  my $executor = $executors->[0];
  my $original_result = $results->[0];
  my $original_query = $original_result->query();

  return STATUS_WONT_HANDLE if $original_query !~ m{^\s*(SELECT|HANDLER)}is;
  return STATUS_WONT_HANDLE if defined $results->[0]->warnings();
    foreach my $r (@{$results}) {
        return STATUS_WONT_HANDLE if $r->status() != STATUS_OK;
    };

  my $max_transformer_status= STATUS_OK;
  $executor->dbh->do("SELECT CONCAT('SET ROLE ',IFNULL(CURRENT_ROLE(),'NONE')) INTO ".'@role_stmt');
  if ($executor->dbh->err) {
    sayError("Couldn't store current role in Transformer validator: ".$executor->dbh->err." ".$executor->dbh->errstr);
    return STATUS_ENVIRONMENT_FAILURE;
  }
  $executor->dbh->do('SET ROLE admin');
  if ($executor->dbh->err) {
    sayError("Couldn't set admin role in Transformer validator: ".$executor->dbh->err." ".$executor->dbh->errstr);
    return STATUS_ENVIRONMENT_FAILURE;
  }
  
  foreach my $transformer (@transformers) {
        next if isOlderVersion($executor->server->version(),$transformer->compatibility);
        if (time() > $executor->end_time) {
            say("Transformer: Test duration has already been exceeded, exiting");
            last;
        }
    my $transformer_status = $validator->transform($transformer, $executor, $results);
    if (($transformer_status == STATUS_CONTENT_MISMATCH) && ($original_query =~ m{LIMIT}is)) {
      # We avoid reporting bugs on content mismatch with LIMIT queries
      say('WARNING: Got STATUS_CONTENT_MISMATCH from transformer. This is likely'.
        ' a FALSE POSITIVE given that there is a LIMIT clause but possibly'.
        ' no complete ORDER BY. Hence we return STATUS_OK. The previous transform issue can likely be ignored.');
      $transformer_status = STATUS_OK
    }
    $max_transformer_status = $transformer_status if $transformer_status > $max_transformer_status;
    last if $transformer_status >= STATUS_CRITICAL_FAILURE;
  }
  $executor->dbh->do('EXECUTE IMMEDIATE @role_stmt');
  if ($executor->dbh->err) {
    sayError("Couldn't restore previous role in Transformer validator");
    return STATUS_ENVIRONMENT_FAILURE;
  }
  return $max_transformer_status;
}

sub transform {
  my ($validator, $transformer, $executor, $results) = @_;
  my $original_result = $results->[0];
  my $original_query = $original_result->query();

  my ($transform_outcome, $transformed_queries, $transformed_results, $cleanup_block) = $transformer->transformExecuteValidate($original_query, $original_result, $executor);

  if (
    ($transform_outcome >= STATUS_CRITICAL_FAILURE) ||
    ($transform_outcome == STATUS_OK) ||
    ($transform_outcome == STATUS_SKIP) ||
    ($transform_outcome == STATUS_WONT_HANDLE)
  ) {
    return $transform_outcome;
  }

  say("---------- TRANSFORM ISSUE START ----------");
  say("Original query: $original_query failed transformation with Transformer ".$transformer->name().
    "; RQG Status: ".status2text($transform_outcome)." ($transform_outcome)");
  if (not defined $transformed_queries) {
    say("WARNING: Transformer was unable to produce a transformed query.".
      " This is likely an issue with the test configuration or the ".
      $transformer->name()." transformer itself. See above for possible".
      " errors caused by the transformed query.");
    if ($transform_outcome == STATUS_UNKNOWN_ERROR) {
      # We want to know about unknown errors returned by transformed queries.
      say('ERROR: Unknown error from transformer, likely a test issue. '.
        'Raising status to STATUS_ENVIRONMENT_FAILURE');
      return STATUS_ENVIRONMENT_FAILURE;
    }
    say("----------- TRANSFORM ISSUE END -----------");
    return $transform_outcome;
  }

  say("Transformed query: ".join('; ', @$transformed_queries));
  say("Result diff:");
  say(GenTest::Comparator::dumpDiff($original_result, $transformed_results->[0]));

  my @orig_explains;
  $orig_explains[0] = $executor->execute("EXPLAIN ".$original_query);
  foreach my $transformed_query (@$transformed_queries) {
    $executor->execute($transformed_query);
    if ($transformed_query eq $transformed_results->[0]->query()) {
      $orig_explains[1] = $executor->execute("EXPLAIN ".$transformed_query);
    }
  }

  say("EXPLAIN diff:");
  say(GenTest::Comparator::dumpDiff(@orig_explains));
  say("------- END OF TRANSFORM ISSUE -------");
  GenTest::Transform::cleanup($executor, $cleanup_block);

  return $transform_outcome;
}

sub DESTROY {
  @transformers = ();
}

1;
