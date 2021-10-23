# Copyright (c) 2020,2021 MariaDB Corporation
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

package GenTest::Transform::ExecuteAsInsertReturning;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenTest;
use GenTest::Transform;
use GenTest::Constants;


sub transform {
  my ($class, $orig_query, $executor, $original_result, $skip_result_validations) = @_;

  # We skip [OUTFILE | INFILE] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
  # SELECT HISTORY .. (versioning) does not work with RETURNING
  return STATUS_WONT_HANDLE if $orig_query =~ m{(OUTFILE|INFILE|PROCESSLIST|RETURNING|HISTORY)}sio
    || $orig_query !~ m{^\s*(?:SELECT|INSERT|REPLACE)}sio
    || $orig_query =~ m{^\s*(?:INSERT|REPLACE)}sio && ! $skip_result_validations
      || $orig_query =~ m{LIMIT\s+\d+\s*,\s*\d+}sio
    || $orig_query =~ m{(AVG|STD|STDDEV_POP|STDDEV_SAMP|STDDEV|SUM|VAR_POP|VAR_SAMP|VARIANCE|SYSDATE)\s*\(}sio
  ;

  # Two variants of transformations: for SELECT, we convert it into INSERT .. RETURNING
  # (and later compare the result sets if the validator is enabled).
  # For INSERT, we just add RETURNING *

  if ( $orig_query =~ m{^\s*SELECT}sio )
  {
    return STATUS_WONT_HANDLE if not $original_result or not $original_result->columnNames() or "@{$original_result->columnNames()}" =~ m{`}sgio;

    my @cols= map { '`'.$_.'`' unless $_ =~ /`/ } @{$original_result->columnNames()};

    my $col_list = join ',', @cols;
    # INSERT/DELETE ... RETURNING does not work with aggregate functions
    return STATUS_WONT_HANDLE if $col_list =~ m{AVG|COUNT|MAX|MIN|GROUP_CONCAT|BIT_AND|BIT_OR|BIT_XOR|STD|SUM|VAR_POP|VAR_SAMP|VARIANCE}sgio;

    my $table_name = 'transforms.insert_returning_'.abs($$);

    return [
      # Unlock tables prevents conflicting locks and should also take care
      # of open transactions by performing implicit COMMIT
      'UNLOCK TABLES',
      'SET @tx_read_only.save= @@session.tx_read_only',
      'SET SESSION tx_read_only= 0',
      #Include database transforms creation DDL so that it appears in the simplified testcase.
      "CREATE DATABASE IF NOT EXISTS transforms",
      "DROP TABLE IF EXISTS $table_name",
      "CREATE TABLE $table_name $orig_query",
      "TRUNCATE TABLE $table_name",
      "REPLACE INTO $table_name $orig_query RETURNING $col_list /* TRANSFORM_OUTCOME_UNORDERED_MATCH */",
      "DROP TABLE IF EXISTS $table_name",
    '/* TRANSFORM_CLEANUP */ SET SESSION tx_read_only= @tx_read_only.save'
    ];
  }
  elsif ($orig_query =~ m{^\s*(?:INSERT|REPLACE)}sio )
  {
    return [ "$orig_query RETURNING * /* TRANSFORM_OUTCOME_ANY */" ];
  }
}

1;
