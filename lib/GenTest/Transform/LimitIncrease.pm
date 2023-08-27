# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2021, 2022, MariaDB Corporation Ab.
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

package GenTest::Transform::LimitIncrease;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenUtil;
use GenTest;
use GenTest::Transform;
use Constants;

sub transform {
  my ($class, $orig_query) = @_;
  # We skip: - [OUTFILE | INFILE] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
  return STATUS_WONT_HANDLE
    if $orig_query !~ m{^\s*SELECT}
      || $orig_query =~ m{(?:OUTFILE|INFILE|PROCESSLIST|INSERT|REPLACE|CREATE)}is
      || $orig_query =~ m{OFFSET}is;
  my $transform_outcome= '/* TRANSFORM_OUTCOME_UNORDERED_MATCH */';
  if ($orig_query =~ m{LIMIT\s+\d+}is) {
    $transform_outcome= '/* TRANSFORM_OUTCOME_SUPERSET */';
  }
  return $class->modify($orig_query)." $transform_outcome";
}

sub variate {
  my ($class, $orig_query) = @_;
  return [ $orig_query ] if $orig_query !~ m{^\s*SELECT}is && $orig_query !~  m{LIMIT\s+\d+}is;
  return [ $class->modify($orig_query) ];
}

sub modify {
  my ($class, $orig_query) = @_;
  my $suffix= '';
  # Store trailing INTO or FOR UPDATE
  if ($orig_query =~ s{(INTO\s+OUTFILE\s+(?:['"].*?[."]|\@\w+)|FOR\s+UPDATE)\s*$}{}is) {};
  if ($orig_query =~ s{LIMIT\s+\d+}{LIMIT 4294836225}isg) {}
  elsif ($orig_query =~ s{FETCH\s+(NEXT|FIRST)\s+\d+\s+(ROWS?)\s+(ONLY|WITH\s+TIES)}{FETCH $1 4294836225 $2 $3}isg) {}
  elsif ($orig_query =~ s{LIMIT\s+ROWS\s+EXAMINED}{LIMIT 4294836225 ROWS EXAMINED}isg) {}
  else { $orig_query.= " LIMIT 4294836225" };
  return $orig_query.($suffix ? " $suffix" : '');
}

1;
