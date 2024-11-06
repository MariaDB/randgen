# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2014 SkySQL Ab
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

package GenTest::Transform::OrderBy;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenUtil;
use GenTest;
use GenTest::Transform;
use Constants;

sub transform {
  my ($class, $original_query) = @_;

  return STATUS_WONT_HANDLE if $original_query !~ m{^\s*SELECT}is;
  return STATUS_WONT_HANDLE if $original_query =~ m{LIMIT\s+(?:\d+\s*,\s*)?0}is;
  # We skip: - [OUTFILE | INFILE] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
  #          - ORDER BY queries which are followed by brackets (either function calls or something else),
  #            as it requires more complex regexes for correct behavior
  #          - INTO, because there will be nothing to compare
  return STATUS_WONT_HANDLE if $original_query =~ m{(OUTFILE|INFILE|PROCESSLIST|INTO|GROUP\s+BY|ORDER\s+BY.*[()])}is;

  my $query= $class->modify($original_query);
  return STATUS_WONT_HANDLE unless defined $query;

  my $transform_outcome;

  if ($original_query =~ m{LIMIT[^()]*$}is) {
    $transform_outcome = "TRANSFORM_OUTCOME_SUPERSET";
  } else {
    $transform_outcome = "TRANSFORM_OUTCOME_UNORDERED_MATCH";
  }
  return $query." /* $transform_outcome */ ";
}

sub variate {
  my ($class, $original_query) = @_;
  return [ $original_query ] if $original_query !~ m{^\s*SELECT}is;
  return [ $original_query ] if $original_query =~ m{ORDER\s+BY.*[()]}is;
  return [ $class->modify($original_query) || $original_query ];
}

sub modify {
  my ($class, $original_query) = @_;

  if ($original_query =~ s{ORDER\s+BY.*$}{}is) {
    # Removing ORDER BY
  } elsif ($original_query !~ s{LIMIT[^()]*$}{ORDER BY 1}is) {
    # Won't handle
    return undef;
  }
  return $original_query;
}

1;
