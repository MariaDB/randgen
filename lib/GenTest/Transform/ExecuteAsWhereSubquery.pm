# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2022, MariaDB
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

package GenTest::Transform::ExecuteAsWhereSubquery;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenUtil;
use GenTest;
use GenTest::Transform;
use Constants;

sub transform {
  my ($class, $original_query, $executor, $original_result) = @_;

  # We skip: - [OUTFILE | INFILE] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
  return STATUS_WONT_HANDLE if $original_query =~ m{(OUTFILE|INFILE|PROCESSLIST)}is
          || $original_query !~ m{^\s*SELECT}is
          || $original_query =~ m{LIMIT}is
          || $original_query =~ m{(AVG|STD|STDDEV_POP|STDDEV_SAMP|STDDEV|SUM|VAR_POP|VAR_SAMP|VARIANCE)\s*\(}is
    || $original_result->rows() == 0;

  # This transformation can not work if the result set contains NULLs
  foreach my $orig_row (@{$original_result->data()}) {
    foreach my $orig_col (@$orig_row) {
      return STATUS_WONT_HANDLE if $orig_col eq '<NULL>';
    }
  }

  my $table_name = 'transforms.where_subselect_'.abs($$);
  my @column_names= @{$original_result->columnNames()};
  foreach my $i (0..$#column_names) {
    $column_names[$i] =~ s/\`/\`\`/g;
  }

  return [
    #Include database transforms creation DDL so that it appears in the simplified testcase.
    "CREATE OR REPLACE TABLE $table_name $original_query",
    "SELECT * FROM $table_name WHERE (".join(', ', map { "`$_`" } @column_names).") IN ( $original_query ) /* TRANSFORM_OUTCOME_UNORDERED_MATCH */",
    "SELECT * FROM $table_name WHERE (".join(', ', map { "`$_`" } @column_names).") NOT IN ( $original_query ) /* TRANSFORM_OUTCOME_EMPTY_RESULT */",
    "DROP TABLE $table_name",
  ];
}

sub variate {
  my ($class, $original_query, $executor) = @_;
  return [ $original_query ] if $original_query =~ m{INTO}is || $original_query !~ m{^[\s\(]*SELECT}is;
  # WITH TIES cannot be in EXISTS subquery due to MDEV-30320
  return [ $original_query ] if $original_query =~ m{WITH\s+TIES}is;
  my $tables= $executor->metaTables('NON-SYSTEM');
  unless ($tables && scalar(@$tables)) {
    sayWarning("ExecuteAsWhereSubquery: Could not find a table to use");
    return [ $original_query ];
  }
  my $table= $class->random->arrayElement($executor->metaTables('NON-SYSTEM'))->[1];
  my $not= ($class->random->uint16(0,1) ? 'NOT' : '');
  return [ "SELECT * FROM $table WHERE $not EXISTS ($original_query)" ];
}

1;
