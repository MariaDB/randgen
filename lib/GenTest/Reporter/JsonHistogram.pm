# Copyright (c) 2021 MariaDB Corporation Ab
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

package GenTest::Reporter::JsonHistogram;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use GenTest;
use GenTest::Constants;
use GenTest::Result;
use GenTest::Reporter;
use GenTest::Executor::MySQL;

use DBI;
use Data::Dumper;
use POSIX;

my $dbh;

# Default histogram size to compare with
my $histogram_size;

my %features_used = ();

sub monitor {
  my $reporter = shift;
  unless ($dbh) {
    $dbh = DBI->connect($reporter->dsn(), undef, undef, { RaiseError => 1, PrintError => 0 });
    unless ($dbh) {
      sayError("JsonHistogram reporter could not connect to the server. Status will be set to STATUS_INTERNAL_ERROR");
      return undef;
    }
  }
  if (not defined $histogram_size or $histogram_size >= 0) {
    my $vals= $dbh->selectrow_arrayref("SELECT GLOBAL_VALUE, GLOBAL_VALUE_ORIGIN FROM INFORMATION_SCHEMA.SYSTEM_VARIABLES WHERE VARIABLE_NAME = 'HISTOGRAM_SIZE'");
    if ($vals->[1] eq 'SQL') {
      sayWarning("Global value of HISTOGRAM_SIZE has changed since startup, the size check is no longer applicable");
      $histogram_size= -1;
    }
    elsif (not defined $histogram_size) {
      $histogram_size= $vals->[0];
    }
  }

  my $res= STATUS_OK;
  if ($histogram_size > 0) {
    my $wrong_hist_size= $dbh->selectrow_arrayref("SELECT db_name, table_name, column_name, hist_size FROM mysql.column_stats WHERE hist_type = 'JSON_HB' AND hist_size > $histogram_size");
    if ($wrong_hist_size) {
      $res= STATUS_HISTOGRAM_CORRUPTION;
      foreach (@$wrong_hist_size) {
        sayError("Wrong histogram size for $wrong_hist_size->[0].$wrong_hist_size->[1].$wrong_hist_size->[2]: expected <= $histogram_size, found $wrong_hist_size->[3]" );
      }
    }
    my $wrong_bucket_sizes= $dbh->selectrow_arrayref("SELECT db_name, table_name, column_name, SUM(sizes) total_size, JSON_EXTRACT(histogram,'\$.histogram_hb_v2[*].size') AS all_sizes FROM mysql.column_stats, JSON_TABLE(histogram,'\$.histogram_hb_v2[*].size' COLUMNS (sizes DECIMAL(65,38) PATH '\$')) jt WHERE hist_type = 'JSON_HB' GROUP BY db_name, table_name, column_name, all_sizes HAVING ABS(total_size-1) > 0.01");
    if ($wrong_bucket_sizes) {
      $res= STATUS_HISTOGRAM_CORRUPTION;
      foreach (@$wrong_bucket_sizes) {
        sayError("Wrong total size for $wrong_bucket_sizes->[0].$wrong_bucket_sizes->[1].$wrong_bucket_sizes->[2]: $wrong_bucket_sizes->[4] (total size $wrong_bucket_sizes->[3])");
      }
    }
  }
  return $res;
}

sub report {

  my $reporter = shift;
  return STATUS_OK;
}

sub type {
  return REPORTER_TYPE_ALWAYS | REPORTER_TYPE_PERIODIC;
}

1;

