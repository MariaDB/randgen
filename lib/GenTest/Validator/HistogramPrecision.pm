# Copyright (c) 2021, MariaDB Corporation Ab.
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

package GenTest::Validator::HistogramPrecision;

require Exporter;
@ISA = qw(GenTest GenTest::Validator);

use strict;

use GenTest;
use GenTest::Constants;
use GenTest::Comparator;
use GenTest::Result;
use GenTest::Validator;
use Data::Dumper;

use constant HISTOGRAM_PRECISION_CRITICAL_DIFFERENCE_PCT => 20;
# If the baseline 'filtered' value differs from r_filtered by more
# than this percentage points, the difference won't be raised to critical
use constant HISTOGRAM_PRECISION_MAX_BASELINE_ERROR => 20;

sub validate {
  my ($comparator, $executors, $results) = @_;

  return STATUS_OK if $#$results != 1;

  return STATUS_WONT_HANDLE if $results->[0]->status() == STATUS_SEMANTIC_ERROR || $results->[1]->status() == STATUS_SEMANTIC_ERROR;
  return STATUS_WONT_HANDLE if $results->[0]->status() == STATUS_SYNTAX_ERROR;
  return STATUS_ERROR_MISMATCH if $results->[1]->status() == STATUS_SYNTAX_ERROR;

  my $query = $results->[0]->query();
  return STATUS_WONT_HANDLE if $query !~ m{ANALYZE.*SELECT}sio;
  return STATUS_WONT_HANDLE if $query =~ m{skip\s+HistogramPrecision}sio;

#  print Dumper $results->[0];
#  return STATUS_OK;

  my $compare_outcome = GenTest::Comparator::compare($results->[0], $results->[1]);

  if ( ($compare_outcome == STATUS_LENGTH_MISMATCH) ||
       ($compare_outcome == STATUS_CONTENT_MISMATCH) 
  ) {
    my $plans_differ= 0;
    my $precision_differs= '';
    my $critical_difference= 0;
    # MDEV-26849
    my $known_bugs= '';

    my ($plan1, $plan2) = ($results->[0]->data(), $results->[1]->data);
    if (scalar(@$plan1) != scalar(@$plan2)) {
      $plans_differ= 1;
    } else {
      foreach my $i (0..$#$plan1) {
        my ($id1, $select_type1, $table1, $type1, $possible_keys1, $key1, $key_len1, $ref1, $rows1, $r_rows1, $filtered1, $r_filtered1, $extra1)= @{$plan1->[$i]};
        my ($id2, $select_type2, $table2, $type2, $possible_keys2, $key2, $key_len2, $ref2, $rows2, $r_rows2, $filtered2, $r_filtered2, $extra2)= @{$plan2->[$i]};
        if ($id1 ne $id2
          or $select_type1 ne $select_type2
          or $table1 ne $table2
          or $type1 ne $type2
          or $possible_keys1 ne $possible_keys2
          or $key1 ne $key2
          or $key_len1 ne $key_len2
          or $ref1 ne $ref2
          or $extra1 ne $extra2
          or $r_rows1 ne $r_rows2
          or $r_filtered1 ne $r_filtered2
        ) {
          $plans_differ= 1;
          last;
        }
        if ($rows1 ne $rows2 and defined $r_rows1)
        {
          # We'll consider it a critical failure if "deviation" of our target rows1
          # is worse than the "deviation" of the baseline by more than
          # the configured amount of percent points and at the same time
          # the value is big enough for comparison
          if ($r_rows1 == 0) {
            $known_bugs.= 'MDEV-26849 ';
          } else {
            my $dev_pct1= sprintf("%.2f",(abs($rows1-$r_rows1)/$r_rows1)*100);
            my $dev_pct2= sprintf("%.2f",(abs($rows2-$r_rows1)/$r_rows1)*100);
            if ($dev_pct1 > $dev_pct2) {
              $precision_differs.= "[rows1=$rows1 rows2=$rows2 r_rows=$r_rows1 ($dev_pct1% vs $dev_pct2%)] ";
            }
          }
        }
        # The same consideration applies
        if ($filtered1 ne $filtered2 and defined $r_filtered1)
        {
          if ($r_filtered1 == 0) {
            $known_bugs.= 'MDEV-26849 ';
          } else {
            my $dev_pct1= sprintf("%.2f",(abs($filtered1-$r_filtered1)/$r_filtered1)*100);
            my $dev_pct2= sprintf("%.2f",(abs($filtered2-$r_filtered1)/$r_filtered1)*100);
            if ($dev_pct1 > $dev_pct2) {
              if ($dev_pct1 - $dev_pct2 > HISTOGRAM_PRECISION_CRITICAL_DIFFERENCE_PCT and abs($rows2 - $r_filtered1) <= HISTOGRAM_PRECISION_MAX_BASELINE_ERROR) {
                $critical_difference= 1;
                # For post-test filtering
                $precision_differs.= "CRITICAL DIFFERENCE:"
              }
              $precision_differs.= "[filtered1=$filtered1 filtered2=$filtered2 r_filtered=$r_filtered1 ($dev_pct1% vs $dev_pct2%)] ";
            }
          }
        }
      }
    }
    if ($plans_differ) {
      say("For query [ $query ]: execution plans differ between servers");
      sayDebug(GenTest::Comparator::dumpDiff($results->[0], $results->[1]));
      # We are not interested in essentially different plans here
      return STATUS_OK;
    } elsif ($precision_differs) {
      say("---------- HISTOGRAM PRECISION COMPARISON ISSUE ----------");
      sayError("For query [ $query ]: estimation precision differs between servers");
      say(GenTest::Comparator::dumpDiff($results->[0], $results->[1]));
      say("HistogramPrecision difference: ".$precision_differs);
      if ($known_bugs) {
        say("HistogramPrecision: Possibly encountered $known_bugs");
      }
      return $compare_outcome;
    }
  }
}

1;
