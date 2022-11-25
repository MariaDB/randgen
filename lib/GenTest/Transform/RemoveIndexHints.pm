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

package GenTest::Transform::RemoveIndexHints;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenUtil;
use GenTest;
use GenTest::Transform;
use GenTest::Constants;

sub transform {
  my ($class, $orig_query) = @_;
  # We skip: - [OUTFILE | INFILE] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
  return STATUS_WONT_HANDLE if $orig_query =~ m{(?:OUTFILE|INFILE|PROCESSLIST)}sio
    || $orig_query !~ m{(?:FORCE|IGNORE|USE)\s+(?:KEY|INDEX)}sio;
  return $class->modify($orig_query)." /* TRANSFORM_OUTCOME_UNORDERED_MATCH */";
}

sub variate {
  my ($class, $orig_query) = @_;
  return $orig_query if $orig_query !~ m{(FORCE|IGNORE|USE)\s+(KEY|INDEX)};
  return [ $class->modify($orig_query) ];
}

sub modify {
  my ($class, $orig_query) = @_;
  $orig_query =~ s{(FORCE|IGNORE|USE)\s+(INDEX|KEY)\s*\(.*?\)}{}siog;
  return $orig_query;
}

1;
