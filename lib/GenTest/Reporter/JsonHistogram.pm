# Copyright (c) 2021, 2023 MariaDB
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

########################################################################
# MDEV-21130, MDEV-26519 JSON histograms (10.8.1)
#
# The reporter checks the basic health of calculated JSON histograms
########################################################################

package GenTest::Reporter::JsonHistogram;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use GenUtil;
use GenTest;
use Constants;
use GenTest::Result;
use GenTest::Reporter;
use GenTest::Executor::MRDB;

use Data::Dumper;
use POSIX;
1;

sub new {
  my $class = shift;
  my $reporter = $class->SUPER::new(@_);
  $reporter->compatibility('100801');
  return $reporter;
}

my $conn;

# Default histogram size to compare with
my $histogram_size;

my %features_used = ();
my ($valid_count, $invalid_count, $null_count)= (0,0,0);

sub monitor {
  my $reporter = shift;
  unless ($conn) {
    $conn = $reporter->connection;
    unless ($conn) {
      sayError("JsonHistogram: reporter could not connect to the server");
      return undef;
    }
  }
  if (not defined $histogram_size or $histogram_size >= 0) {
    my $vals= $conn->get_row("SELECT GLOBAL_VALUE, GLOBAL_VALUE_ORIGIN FROM INFORMATION_SCHEMA.SYSTEM_VARIABLES WHERE VARIABLE_NAME = 'HISTOGRAM_SIZE'");
    if ($vals->[1] eq 'SQL') {
      sayWarning("JsonHistogram: Global value of HISTOGRAM_SIZE has changed since startup, the size check is no longer applicable");
      $histogram_size= -1;
    }
    elsif (not defined $histogram_size) {
      $histogram_size= $vals->[0];
    }
  }

  my $res= STATUS_OK;
  if ($histogram_size > 0) {
    my $json_check= $conn->query("SELECT db_name, table_name, column_name, histogram, json_valid(histogram) FROM mysql.column_stats WHERE hist_type = 'JSON_HB'");
    if ($json_check and scalar(@$json_check)) {
      foreach my $jc (@$json_check) {
        if ($jc->[4] == 1) {
          $valid_count++;
        } elsif ($jc->[4] eq 'NULL') {
          $null_count++;
        } elsif ($jc->[4] == 0) {
          sayError("JsonHistogram: Invalid JSON histogram for $jc->[0].$jc->[1].$jc->[2]: $jc->[3]" );
          $invalid_count++;
          $res= STATUS_DATABASE_CORRUPTION;
        } else {
          sayError("JsonHistogram: Got an unexpected result of JSON_VALID(histogram): $jc->[4]");
          $res= STATUS_DATABASE_CORRUPTION;
        }
      }
      sayDebug("JsonHistogram: Checked ".($valid_count + $invalid_count + $null_count)." histograms. Valid: $valid_count, NULLs: $null_count, invalid: $invalid_count");
    }
    my $wrong_hist_size= $conn->query("SELECT db_name, table_name, column_name, hist_size FROM mysql.column_stats WHERE hist_type = 'JSON_HB' AND hist_size > $histogram_size");
    if ($wrong_hist_size and scalar(@$wrong_hist_size)) {
      $res= STATUS_DATABASE_CORRUPTION;
      foreach my $wc (@$wrong_hist_size) {
        sayError("Wrong histogram size for $wc->[0].$wc->[1].$wc->[2]: expected <= $histogram_size, found $wc->[3]" );
      }
    }
    my $wrong_bucket_sizes= $conn->query("SELECT db_name, table_name, column_name, SUM(sizes) total_size, JSON_EXTRACT(histogram,'\$.histogram_hb_v2[*].size') AS all_sizes FROM mysql.column_stats, JSON_TABLE(histogram,'\$.histogram_hb_v2[*].size' COLUMNS (sizes DECIMAL(65,38) PATH '\$')) jt WHERE hist_type = 'JSON_HB' GROUP BY db_name, table_name, column_name, all_sizes HAVING ABS(total_size-1) > 0.01");
    if ($wrong_bucket_sizes and scalar(@$wrong_bucket_sizes)) {
      $res= STATUS_DATABASE_CORRUPTION;
      foreach my $wb (@$wrong_bucket_sizes) {
        sayError("JsonHistogram: Wrong total size for $wb->[0].$wb->[1].$wb->[2]: $wb->[4] (total size $wb->[3])");
      }
    }
  }
  return $res;
}

sub report {
  my $reporter = shift;
  say("JsonHistogram: Checked ".($valid_count + $invalid_count + $null_count)." histograms. Valid: $valid_count, NULLs: $null_count, invalid: $invalid_count");
  return STATUS_OK;
}

sub type {
  return REPORTER_TYPE_ALWAYS | REPORTER_TYPE_PERIODIC;
}

1;

