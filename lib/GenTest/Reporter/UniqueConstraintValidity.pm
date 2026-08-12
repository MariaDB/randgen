# Copyright (C) 2025, 2026, MariaDB. All rights reserved.
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
  unless ($reporter->server->isRunning) {
    sayWarning("UniqueConstraintValidity: Server isn't running, skipping the check");
    return STATUS_OK;
  }
  my $conn = $reporter->connection;
  unless ($conn) {
    sayWarning("UniqueConstraintValidity: could not connect to the server");
    return STATUS_SERVER_UNAVAILABLE;
  }
  my $indexes = $conn->query(
    "set statement max_statement_time=0 for " .
    "select BINARY concat('`',istat.table_schema,'`.`',istat.table_name,'`') as tbl, " .
    "index_name, group_concat(concat('`',column_name,'`')) cols, " .
    "index_type from INFORMATION_SCHEMA.STATISTICS istat " .
    "join INFORMATION_SCHEMA.TABLES itbl on ".
    "(istat.table_schema = itbl.table_schema and istat.table_name = itbl.table_name) " .
    "where non_unique=0 and itbl.engine not in ('Spider','MRG_MyISAM', 'Federated') " .
    "and not (itbl.table_collation like '%nopad%' " .
    "or itbl.table_collation in ('tis620_thai_ci','latin2_czech_cs','latin2_czech_cs') ) " .
    "group by tbl, index_name, index_type order by tbl, index_name, index_type"
  );
  if (ignorable_error($conn->err)) {
    sayWarning("UniqueConstraintValidity: Got error ".$conn->print_error()." upong retrieving indexes, skipping the check");
    return STATUS_OK;
  }
  elsif ($conn->err or not $indexes) {
    sayError("UniqueConstraintValidity: could not retrieve unique indexes: ".$conn->print_error().", , returning STATUS_DATABASE_CORRUPTION");
    return STATUS_DATABASE_CORRUPTION;
  }
  my $res=STATUS_OK;
  foreach my $tbl_ind (@$indexes) {
    my ($tbl, $ind, $cols, $tp)= @$tbl_ind;
    my $non_null = join ' AND ', (map { "$_ IS NOT NULL" } split /,/, $cols);
    my $multiple_results= $conn->query("set statement max_statement_time=0 for select $cols, count(*) cnt from $tbl WHERE $non_null group by $cols having cnt > 1");
    if (ignorable_error($conn->err)) {
      sayWarning("UniqueConstraintValidity: Got error ".$conn->print_error()." for $tbl, ignoring");
    } elsif ($conn->err or not $multiple_results) {
      sayError("UniqueConstraintValidity: could not perform counts on unique indexes: ".$conn->print_error());
      return STATUS_DATABASE_CORRUPTION;
    } elsif (scalar(@$multiple_results)) {
      sayError("UniqueConstraintValidity: unique constraint $ind ($cols) of type $tp on table $tbl contains non-unique values, returning STATUS_DATABASE_CORRUPTION");
      foreach my $vals (@$multiple_results) {
        my $cnt= pop @$vals;
        say('Values: "'.(join ',', (map { defined $_ ? $_ : '<null>' } @$vals) ).'" : count '.$cnt);
      }
      $res= STATUS_DATABASE_CORRUPTION;
    }
  }
  return $res;
}

sub ignorable_error {
  my $err= shift;
  # Ignore certain errors related to engine specifics and alike, we are here not for this
  # 1047: WSREP has not yet prepared node for application use
  # 1159: Got timeout reading communication packets (Spider)
  # 1168: Unable to open underlying table (Merge)
  # 1296: Got error 122 'Open error 2 in mode rb on... (Connect)
  # 1429: Unable to connect to foreign data source (Spider)
  # 12702: Remote table ... is not found
  # 12719: An infinite loop is detected when opening table (Spider)
  return (
    ($err == 1047) ||
    ($err == 1159) ||
    ($err == 1168) ||
    ($err == 1296) ||
    ($err == 1429) ||
    ($err == 12702) ||
    ($err == 12719)
  );
}

sub monitor {
}

sub type {
  return REPORTER_TYPE_SUCCESS;
}


1;
