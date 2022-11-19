# Copyright (c) 2008, 2011 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2019, 2022, MariaDB Corporation Ab.
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

package GenTest::Validator::ResultsetComparator;

require Exporter;
@ISA = qw(GenTest GenTest::Validator);

use strict;

use GenUtil;
use GenTest;
use GenTest::Constants;
use GenTest::Comparator;
use GenTest::Result;
use GenTest::Validator;

sub validate {
  my ($comparator, $executors, $results) = @_;

  return STATUS_OK if scalar(@$results) < 2;
  foreach my $r (@$results) {
    return STATUS_WONT_HANDLE if $r->status() != STATUS_OK;
  }

  my $query = $results->[0]->query();
  return STATUS_WONT_HANDLE if $query =~ m{skip\s+ResultsetComparator}sio;
  return STATUS_WONT_HANDLE if $query =~ m{EXPLAIN}sio;
  return STATUS_WONT_HANDLE if $query =~ m{ANALYZE}sio;

  my $status= STATUS_OK;

  foreach my $i (1..$#$results)
  {
    my $compare_outcome = ($query =~ /OUTCOME_ORDERED_MATCH/ ? GenTest::Comparator::compare_as_ordered($results->[0], $results->[$i]) : GenTest::Comparator::compare_as_unordered($results->[0], $results->[$i]));
    if ( ($compare_outcome == STATUS_LENGTH_MISMATCH) ||
         ($compare_outcome == STATUS_CONTENT_MISMATCH) 
    ) {
      say("---------- RESULT COMPARISON ISSUE START ----------");
      if ($compare_outcome == STATUS_LENGTH_MISMATCH) {
        if ($query =~ m{^\s*select}io) {
          say("Query: $query failed: result length mismatch between servers 1 and ".($i+1)." (".$results->[0]->rows()." vs. ".$results->[$i]->rows().")");
          say(GenTest::Comparator::dumpDiff($results->[0], $results->[$i]));
        } else {
          say("Query: $query failed: affected_rows mismatch between servers 1 and ".($i+1)." (".$results->[0]->affectedRows()." vs. ".$results->[$i]->affectedRows().")");
        }
      } elsif ($compare_outcome == STATUS_CONTENT_MISMATCH) {
        say("Query: ".$query." failed: result content mismatch between servers 1 and ".($i+1));
        say(GenTest::Comparator::dumpDiff($results->[0], $results->[$i]));
      }
      say("---------- RESULT COMPARISON ISSUE END ------------");
    } elsif ($compare_outcome != STATUS_OK) {
      sayError("Result comparison for query $query failed with an unexpected error ".status2text($compare_outcome));
    }
    $status= $compare_outcome if $compare_outcome > $status;
  }
  return $status;
}

1;
