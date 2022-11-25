# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (C) 2017, 2022 MariaDB Corporation Ab
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

package GenTest::Transform::ExecuteAsIntersect;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenUtil;
use GenTest;
use GenTest::Transform;
use GenTest::Constants;

sub transform {
  my ($class, $orig_query, $executor) = @_;

  # We skip: - [OUTFILE | INFILE] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
  return STATUS_WONT_HANDLE if $orig_query =~ m{(OUTFILE|INFILE|PROCESSLIST|INTO)}is
    # CTE do not work due to MDEV-15177 (closed as "won't fix")
    || $orig_query =~ m{^\s*WITH}is
    || $orig_query !~ m{^\s*SELECT}is;

  my $orig_query_zero_limit = $orig_query;
  # We remove LIMIT/OFFSET if present in the (outer) query, because we are
  # using LIMIT 0 instead
  $orig_query_zero_limit =~ s{LIMIT\s+\d+(?:\s+OFFSET\s+\d+|\s*,\s*\d+)?}{}is;
  $orig_query_zero_limit =~ s{(?:OFFSET\s+\d+\s+ROWS?\s+)?FETCH\s+(?:FIRST|NEXT)\s+\d+\s+(?:ROW|ROWS)\s+(?:ONLY|WITH\s+TIES)}{}is;
  $orig_query_zero_limit =~ s{(FOR\s+UPDATE|LOCK\s+IN\s+(?:SHARE|EXCLUSIVE)\sMODE)}{LIMIT 0 $1}is;
    unless ($orig_query_zero_limit =~ /LIMIT\s+0/is) {
        $orig_query_zero_limit.= ' LIMIT 0';
    }

  return [
    "( $orig_query ) INTERSECT ( $orig_query ) /* TRANSFORM_OUTCOME_DISTINCT */",
    "( $orig_query ) INTERSECT ( $orig_query_zero_limit ) /* TRANSFORM_OUTCOME_EMPTY_RESULT */",
    "/* compatibility 10.5.2 */ ( $orig_query ) INTERSECT ALL ( $orig_query ) /* TRANSFORM_OUTCOME_UNORDERED_MATCH */",
    "/* compatibility 10.5.2 */ ( $orig_query ) INTERSECT ALL ( $orig_query_zero_limit ) /* TRANSFORM_OUTCOME_EMPTY_RESULT */"
  ];
}

sub variate {
  my ($self, $query, $executor) = @_;
  # CTE do not work due to MDEV-15177 (closed as "won't fix")
  return $query if $query =~ m{(OUTFILE|INFILE|INTO)}is || $query !~ m{^\s*SELECT}is || $query =~ m{^\s*WITH}is;

  my @intersect_modes= ('');
  if ($executor->versionNumeric() >= 100500) {
    push @intersect_modes, 'DISTINCT';
  }
  if ($executor->versionNumeric() >= 100502) {
    push @intersect_modes, 'ALL';
  }
  my $intersect_mode= $self->random->arrayElement(\@intersect_modes);
  return "( $query ) INTERSECT $intersect_mode ( $query )";
}
1;
