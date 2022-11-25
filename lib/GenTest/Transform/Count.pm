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
# SELECT ... FROM -> SELECT ..., COUNT(*) FROM ...
#
# (only for the first found SELECT, to minimize "the number of rows doesn't match"
# errors with subqueries

sub transform {
  my ($class, $orig_query) = @_;
  # We skip: - GROUP BY any other aggregate functions as those are difficult to validate with a simple check like TRANSFORM_OUTCOME_COUNT
  #          - [INTO] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
  #          - UNION since replacing all select lists is tricky with the current logic
  return STATUS_WONT_HANDLE if $orig_query =~ m{GROUP\s+BY|LIMIT|HAVING|UNION}is
    || $orig_query =~ m{(OUTFILE|INFILE|PROCESSLIST)}is;
  return $class->modify($orig_query)." /* TRANSFORM_OUTCOME_COUNT */";
}

sub variate {
  my ($class, $orig_query) = @_;
  return [ $orig_query ] if $orig_query !~ m{SELECT.*FROM}is;
  return [ $class->modify($orig_query) || $orig_query ];
}

sub modify {
  my ($class, $orig_query) = @_;
  my ($select_list) = $orig_query =~ m{SELECT\s+(.*?)\s+FROM}is;
  say("HERE: Found select list $select_list");
  return undef if not $select_list;
  my $select_list_orig= $select_list;

  # There is *, COUNT(..) in the select list, removing COUNT
  # or
  # there is COUNT(..) in the select list, replacing COUNT by its argument
  if (
    $select_list =~ s{(\*\s*,.*),\s*COUNT\(\s*(.*?)\s*\)}{$1}is ||
    $select_list =~ s{COUNT\(\s*(.*?)\s*\)}{$1}is
  ) {
    $orig_query =~ s{$select_list_orig}{$select_list}is;
  }
  # There is no COUNT yet, so adding one
  else {
    $select_list= "$select_list_orig, COUNT(*)";
    say("HERE: replacing [ $select_list_orig ] with [ $select_list ] in query [ $orig_query ]");
    $orig_query =~ s{$select_list_orig}{$select_list}is;
    say("HERE: now: $orig_query");  }
  return $orig_query;
}

1;
