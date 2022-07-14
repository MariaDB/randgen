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

# The validator for 2-way comparison checks the precison of 'filtered'
# estimation against the baseline server. It was created for JSON
# histograms testing, but is not specific to them.
#
# The check limitations are (only queries which meet all the criteria are validated):
# - the query is ANALYZE FORMAT=JSON ... (a variator needs to be added if the grammar doesn't produce them);
# - the query is single-table;
# - "rows" value in the ANALYZE output is greater or equal than HISTOGRAM_PRECISION_MIN_ROWS are validated (for both servers);
# - for the baseline server, the 'filtered' estimation is no further than HISTOGRAM_PRECISION_MAX_BASELINE_INACCURACY_PCT from r_filtered;
# The error is only reported if the 'filtered' estimation on the tested server is worse than the baseline server by more than HISTOGRAM_PRECISION_MIN_ERROR_PCT.

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

use constant HISTOGRAM_PRECISION_MIN_ROWS => 20;
use constant HISTOGRAM_PRECISION_MAX_BASELINE_INACCURACY_PCT => 5;
use constant HISTOGRAM_PRECISION_MIN_ERROR_PCT => 20;

sub validate {
  my ($comparator, $executors, $results) = @_;

  return STATUS_OK if $#$results != 1;
  return STATUS_WONT_HANDLE if $results->[0]->status() != STATUS_OK || $results->[1]->status() != STATUS_OK;

  my $query = $results->[0]->query();
  return STATUS_WONT_HANDLE if $query !~ m{ANALYZE.*FORMAT.*JSON.*}sio;
  return STATUS_WONT_HANDLE if $query =~ m{skip\s+HistogramPrecision}sio;

  my $compare_outcome = GenTest::Comparator::compare($results->[0], $results->[1]);

  return STATUS_OK if $compare_outcome == STATUS_OK;

  my $json1= $results->[0]->data()->[0]->[0];
  my $json2= $results->[1]->data()->[0]->[0];

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

  @vals= ($json1 =~ /\"r_filtered\": ([\d\.]+)/);
  sayDebug("HistogramPrecisionSingleTable: For query [ $query ] plan 1 contains ".scalar(@vals)." r_filtered values (@vals)");
  return STATUS_WONT_HANDLE if scalar(@vals) != 1;
  my $r_filtered1= $vals[0];
  @vals= ($json2 =~ /\"r_filtered\": ([\d\.]+)/);
  sayDebug("HistogramPrecisionSingleTable: For query [ $query ] plan 2 contains ".scalar(@vals)." r_filtered values (@vals)");
  return STATUS_WONT_HANDLE if scalar(@vals) != 1;
  my $r_filtered2= $vals[0];

  if ($r_filtered1 ne $r_filtered2) {
    sayDebug("HistogramPrecisionSingleTable: For query [ $query ] r_filtered values differ: $r_filtered1 vs $r_filtered2");
    # We won't deal with it now -- maybe it's a wrong index, maybe a wrong result
    return STATUS_OK;
  }

  @vals= ($json1 =~ /\"filtered\": ([\d\.]+)/);
  sayDebug("HistogramPrecisionSingleTable: For query [ $query ] plan 1 contains ".scalar(@vals)." filtered values (@vals)");
  return STATUS_WONT_HANDLE if scalar(@vals) != 1;
  my $filtered1= $vals[0];
  @vals= ($json2 =~ /\"filtered\": ([\d\.]+)/);
  sayDebug("HistogramPrecisionSingleTable: For query [ $query ] plan 2 contains ".scalar(@vals)." filtered values (@vals)");
  return STATUS_WONT_HANDLE if scalar(@vals) != 1;
  my $filtered2= $vals[0];

  if ($filtered1 eq $filtered2) {
    sayDebug("HistogramPrecisionSingleTable: Estimation on the test server is the same as on the baseline server");
    return STATUS_OK;
  } elsif (abs($filtered1 - $r_filtered1) < abs($filtered2 - $r_filtered1)) {
    sayDebug("HistogramPrecisionSingleTable: Estimation on the test server is better than on the baseline server");
    return STATUS_OK;
  } elsif (abs($filtered2 - $r_filtered1) > HISTOGRAM_PRECISION_MAX_BASELINE_INACCURACY_PCT) {
    sayDebug("HistogramPrecisionSingleTable: For query [ $query ] filtered values differ: $filtered1 vs $filtered2, r_filtered is $r_filtered1, but estimation on the baseline server is not good enough, skipping the check");
    return STATUS_OK;
  } elsif (abs($filtered1 - $r_filtered1) - abs($filtered2 - $r_filtered1) < HISTOGRAM_PRECISION_MIN_ERROR_PCT) {
    sayDebug("HistogramPrecisionSingleTable: For query [ $query ] filtered values differ: $filtered1 vs $filtered2, r_filtered is $r_filtered1, but the test server is not far enough from the baseline server, skipping the check");
    return STATUS_OK;
  }

  # If we are here, we've got a big enough difference, and the test server is worse

  say("---------- HISTOGRAM PRECISION COMPARISON ISSUE ----------");
  sayError("For query [ $query ]: estimation precision differs between servers");
  say("HistogramPrecisionSingleTable difference: [filtered1=$filtered1 filtered2=$filtered2 r_filtered=$r_filtered1 (deviation ".sprintf("%.2f",abs($filtered1-$r_filtered1))."% vs ".sprintf("%.2f",abs($filtered2-$r_filtered1))."%]");
  say("Plan 1: $json1");
  say("Plan 2: $json2");
  say("----------------------------------------------------------");
  return STATUS_REQUIREMENT_UNMET;

}

1;
