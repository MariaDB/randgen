# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
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

package GenTest::Transform::Count;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenUtil;
use GenTest;
use GenTest::Transform;
use GenTest::Constants;

# This Transform provides the following transformations
#
# SELECT COUNT(...) FROM -> SELECT ... FROM
# SELECT ... FROM -> SELECT COUNT(*) FROM
#
# (only for the first found SELECT, to minimize "the number of rows doesn't match"
# errors with subqueries

sub transform {
  my ($class, $orig_query) = @_;
  # We skip: - GROUP BY any other aggregate functions as those are difficult to validate with a simple check like TRANSFORM_OUTCOME_COUNT
  #          - [INTO] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
  #          - UNION since replacing all select lists is tricky with the current logic
  return STATUS_WONT_HANDLE if $orig_query =~ m{GROUP\s+BY|LIMIT|HAVING|UNION|INTERSECT|EXCEPT}is
    || $orig_query =~ m{(INTO|PROCESSLIST)}is
    || $orig_query !~ m{^[\(\s]*SELECT}is;
  my $query= $class->modify($orig_query, my $with_transform_outcome=1);
  return $query || STATUS_WONT_HANDLE;
}

sub variate {
  my ($class, $orig_query) = @_;
  return [ $orig_query ] if $orig_query !~ m{^[\(\s]*SELECT}is;
  return [ $class->modify($orig_query) || $orig_query ];
}

sub modify {
  my ($class, $orig_query, $with_transform_outcome) = @_;
  
  if ($orig_query =~ m{SELECT\s*(.*?)\s*FROM}is) {
    my $select_list= $1;
    if ($select_list =~ m{COUNT\(\s*\*\s*\)}is) {
      # Replacing COUNT(*) with *
      # If there is 'DISTINCT' before count, we remove it
      $orig_query =~ s{(?:DISTINCT\s+)?COUNT\(\s*\*\s*\)}{\*}is;
      return $orig_query.($with_transform_outcome ? ' /* TRANSFORM_OUTCOME_COUNT_REVERSE */' : '');
    } elsif ($select_list !~ /,/ && $select_list =~ m{COUNT\(\s*(.*?)\s*\)}is) {
      # Replacing (single) COUNT with its argument.
      # If there is 'DISTINCT' before count, we remove it
      my $arg= $1;
      $orig_query =~ s{(?:DISTINCT\s+)?COUNT\(\s*(.*?)\s*\)}{$arg}is;
      return $orig_query.($with_transform_outcome ? ' /* TRANSFORM_OUTCOME_COUNT_NOT_NULL_REVERSE */' : '');
    } elsif ($select_list =~ m{^(?:\/\*.*?\*\/)?\s+\*\s+$}is) {
      # Replacing * with COUNT(*)
      $orig_query =~ s{\s+\*\s+}{ COUNT(*) }is;
      return $orig_query.($with_transform_outcome ? ' /* TRANSFORM_OUTCOME_COUNT */' : '');
  # If the above didn't work, then just wrap the query in SELECT COUNT(*).
  # But for this the original query cannot be INTO (which was already
  # forbidden for transform, but not for INTO)
    } elsif ($orig_query !~ /\WINTO\W/) {
      return "SELECT COUNT(*) FROM ( $orig_query ) sq_count".($with_transform_outcome ? ' /* TRANSFORM_OUTCOME_COUNT */' : '');
    }
  }
  return undef;
}

1;
