# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2022 MariaDB Corporation Ab
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

package GenTest::Transform::ExecuteAsUnion;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenTest;
use GenTest::Transform;
use GenTest::Constants;

sub transform {
  my ($class, $orig_query, $executor) = @_;

  # We skip: - [OUTFILE | INFILE] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
  return STATUS_WONT_HANDLE if $orig_query =~ m{(OUTFILE|INFILE|PROCESSLIST|INTO)}sio
    || $orig_query !~ m{^\s*SELECT}sio;

  # We remove LIMIT/OFFSET if present in the (outer) query, because we are
  # using LIMIT 0 in some of the transformed queries.
  my $orig_query_zero_limit = $orig_query;
  $orig_query_zero_limit =~ s{(?:LIMIT\s+)?ROWS\s+EXAMINED\s+\d+}{}sio;
  $orig_query_zero_limit =~ s{LIMIT\s+\d+(?:\s+OFFSET\s+\d+|\s*,\s*\d+)?}{}sio;
  $orig_query_zero_limit =~ s{(?:OFFSET\s+\d+\s+ROWS?\s+)?FETCH\s+(?:FIRST|NEXT)\s+\d+\s+(?:ROW|ROWS)\s+(?:ONLY|WITH\s+TIES)}{}sio;
  $orig_query_zero_limit =~ s{(FOR\s+UPDATE|LOCK\s+IN\s+(?:SHARE|EXCLUSIVE)\sMODE)}{LIMIT 0 $1}sio;
  if (not $orig_query_zero_limit =~ /LIMIT 0/) {
    $orig_query_zero_limit.= ' LIMIT 0';
  }

  return [
    "( $orig_query ) UNION ALL ( $orig_query_zero_limit ) /* TRANSFORM_OUTCOME_UNORDERED_MATCH */",
    "( $orig_query_zero_limit ) UNION ALL ( $orig_query ) /* TRANSFORM_OUTCOME_UNORDERED_MATCH */",
    "( $orig_query ) UNION DISTINCT ( $orig_query ) /* TRANSFORM_OUTCOME_DISTINCT */",
    "( $orig_query ) UNION ALL ( $orig_query ) /* TRANSFORM_OUTCOME_SUPERSET */"
  ];
}

sub variate {
  my ($self, $query) = @_;
  # Variate 10% queries
  return $query if $self->random->uint16(0,9);
  my $union_type= $self->random->arrayElement(['','ALL','DISTINCT']);
  return $query if $query =~ m{(OUTFILE|INFILE|INTO)}sio || $query !~ m{^\s*SELECT}sio;
  return "( $query ) UNION $union_type ( $query )";
}

1;
