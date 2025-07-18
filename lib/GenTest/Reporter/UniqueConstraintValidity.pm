# Copyright (C) 2025, MariaDB. All rights reserved.
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

package GenTest::Reporter::UniqueConstraintValidity;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use GenUtil;
use GenTest;
use Constants;
use GenTest::Reporter;
use Data::Dumper;

# Check that unique keys don't contain duplicate records

sub report {
  my $reporter = shift;

  my $conn = $reporter->connection;
  unless ($conn) {
    sayWarning("UniqueConstraintValidity: could not connect to the server");
    return STATUS_SERVER_UNAVAILABLE;
  }
  my $indexes = $conn->query("select concat(table_schema,'.',table_name) as tbl, index_name, group_concat(column_name) cols from INFORMATION_SCHEMA.STATISTICS where non_unique=0 group by tbl, index_name order by tbl, index_name");
  if ($conn->err or not $indexes) {
    sayError("UniqueConstraintValidity: could not retrieve unique indexes: $conn->err ($conn->errstr)");
    return STATUS_DATABASE_CORRUPTION;
  }
  my $res=STATUS_OK;
  foreach my $tbl_ind (@$indexes) {
    my ($tbl, $ind, $cols)= @$tbl_ind;
    my $non_null = join ' AND ', (map { "$_ IS NOT NULL" } split /,/, $cols);
    my $multiple_results= $conn->query("select $cols, count(*) cnt from $tbl WHERE $non_null group by $cols having cnt > 1");
    if ($conn->err or not $multiple_results) {
      sayError("UniqueConstraintValidity: could not perform counts on unique indexes: $conn->err ($conn->errstr)");
      return STATUS_DATABASE_CORRUPTION;
    }
    if (scalar(@$multiple_results)) {
      sayError("UniqueConstraintValidity: unique constraint $ind ($cols) on table $tbl contains non-unique values");
      foreach my $vals (@$multiple_results) {
        my $cnt= pop @$vals;
        say('Values: "'.(join ',', (map { defined $_ ? $_ : '<null>' } @$vals) ).'" : count '.$cnt);
      }
      $res= STATUS_DATABASE_CORRUPTION;
    }
  }
  return $res;
}

sub monitor {
}

sub type {
  return REPORTER_TYPE_SUCCESS;
}


1;
