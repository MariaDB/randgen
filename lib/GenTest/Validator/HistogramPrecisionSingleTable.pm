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

package GenTest::Validator::HistogramPrecisionSingleTable;

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
use constant HISTOGRAM_PRECISION_MIN_ROWS => 20;

sub validate {
  my ($comparator, $executors, $results) = @_;

  return STATUS_OK if $#$results != 1;

  return STATUS_WONT_HANDLE if $results->[0]->status() == STATUS_SEMANTIC_ERROR || $results->[1]->status() == STATUS_SEMANTIC_ERROR;
  return STATUS_WONT_HANDLE if $results->[0]->status() == STATUS_SYNTAX_ERROR;
  return STATUS_ERROR_MISMATCH if $results->[1]->status() == STATUS_SYNTAX_ERROR;

  my $query = $results->[0]->query();
  return STATUS_WONT_HANDLE if $query !~ m{ANALYZE.*FORMAT.*JSON.*}sio;
  return STATUS_WONT_HANDLE if $query =~ m{skip\s+HistogramPrecision}sio;

#  print Dumper $results->[0];
#  return STATUS_OK;

  my $compare_outcome = GenTest::Comparator::compare($results->[0], $results->[1]);

  return STATUS_OK if $compare_outcome == STATUS_OK;

  my $json1= $results->[0]->data()->[0]->[0];
  my $json2= $results->[1]->data()->[0]->[0];

#  print "JSON 1:\n$json1\n";
#  print "JSON 2:\n$json2\n";

  my @vals;

  @vals= ($json1 =~ /(\"table\": \{)/gs);
  sayDebug("HistogramPrecisionSingleTable: For query [ $query ] plan 1 contains ".scalar(@vals)." tables");
  return STATUS_WONT_HANDLE if scalar(@vals) != 1;
  @vals= ($json2 =~ /(\"table\": \{)/g);
  sayDebug("HistogramPrecisionSingleTable: For query [ $query ] plan 2 contains ".scalar(@vals)." tables");
  return STATUS_WONT_HANDLE if scalar(@vals) != 1;

  @vals= ($json1 =~ /\"rows\": ([\d\.]+)/);
  sayDebug("HistogramPrecisionSingleTable: For query [ $query ] plan 1 contains ".scalar(@vals)." rows values (@vals)");
  return STATUS_WONT_HANDLE if scalar(@vals) != 1 or $vals[0] < HISTOGRAM_PRECISION_MIN_ROWS;
  @vals= ($json2 =~ /\"rows\": ([\d\.]+)/);
  sayDebug("HistogramPrecisionSingleTable: For query [ $query ] plan 2 contains ".scalar(@vals)." rows values (@vals)");
  return STATUS_WONT_HANDLE if scalar(@vals) != 1 or $vals[0] < HISTOGRAM_PRECISION_MIN_ROWS;

  @vals= ($json1 =~ /\"filtered\": ([\d\.]+)/);
  sayDebug("HistogramPrecisionSingleTable: For query [ $query ] plan 1 contains ".scalar(@vals)." filtered values (@vals)");
  return STATUS_WONT_HANDLE if scalar(@vals) != 1;
  my $filtered1= $vals[0];
  @vals= ($json2 =~ /\"filtered\": ([\d\.]+)/);
  sayDebug("HistogramPrecisionSingleTable: For query [ $query ] plan 2 contains ".scalar(@vals)." filtered values (@vals)");
  return STATUS_WONT_HANDLE if scalar(@vals) != 1;
  my $filtered2= $vals[0];

  @vals= ($json1 =~ /\"r_filtered\": ([\d\.]+)/);
  sayDebug("HistogramPrecisionSingleTable: For query [ $query ] plan 1 contains ".scalar(@vals)." r_filtered values (@vals)");
  return STATUS_WONT_HANDLE if scalar(@vals) != 1;
  my $r_filtered1= $vals[0];
  @vals= ($json2 =~ /\"r_filtered\": ([\d\.]+)/);
  sayDebug("HistogramPrecisionSingleTable: For query [ $query ] plan 2 contains ".scalar(@vals)." r_filtered values (@vals)");
  return STATUS_WONT_HANDLE if scalar(@vals) != 1;
  my $r_filtered2= $vals[0];

  # We'll consider it a critical failure if "deviation" of our target filtered1
  # is worse than the "deviation" of the baseline by more than
  # the configured amount of percent points and at the same time
  # the value is big enough for comparison

  my $known_bugs;
  my $precision_differs= '';
  if ($r_filtered1 ne $r_filtered2) {
    sayDebug("HistogramPrecisionSingleTable: For query [ $query ] r_filtered values differ: $r_filtered1 vs $r_filtered2");
    # We won't deal with it now -- maybe it's a wrong index, maybe a wrong result
    return STATUS_OK;
  }
  elsif ($filtered1 ne $filtered2)
  {
    sayDebug("HistogramPrecisionSingleTable: For query [ $query ] filtered values differ: $filtered1 vs $filtered2");
    if ($r_filtered1 == 0) {
      $known_bugs.= 'MDEV-26849 ';
    } else {
      my $dev_pct1= sprintf("%.2f",(abs($filtered1-$r_filtered1)/$r_filtered1)*100);
      my $dev_pct2= sprintf("%.2f",(abs($filtered2-$r_filtered1)/$r_filtered1)*100);
      if ($dev_pct1 > $dev_pct2) {
        if ($dev_pct1 - $dev_pct2 > HISTOGRAM_PRECISION_CRITICAL_DIFFERENCE_PCT and abs($filtered2 - $r_filtered1) <= HISTOGRAM_PRECISION_MAX_BASELINE_ERROR) {
          # For post-test filtering
          $precision_differs.= "CRITICAL DIFFERENCE:"
        } else {
          $compare_outcome = STATUS_OK;
        }
        $precision_differs.= "[filtered1=$filtered1 filtered2=$filtered2 r_filtered=$r_filtered1 ($dev_pct1% vs $dev_pct2%)] ";
        say("---------- HISTOGRAM PRECISION COMPARISON ISSUE ----------");
        sayError("For query [ $query ]: estimation precision differs between servers");
        say("HistogramPrecisionSingleTable difference: ".$precision_differs);
        if ($known_bugs) {
          say("HistogramPrecisionSingleTable: Possibly encountered $known_bugs");
        }
        say("Plan 1: $json1");
        say("Plan 2: $json2");
        say("----------------------------------------------------------");
        return $compare_outcome;
      }
    }
  } else {
    sayDebug("HistogramPrecisionSingleTable: For query [ $query ] filtered values are the same: $filtered1");
  }
  return STATUS_OK;
}

1;
