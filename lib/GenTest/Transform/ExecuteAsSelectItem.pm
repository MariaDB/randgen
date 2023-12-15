# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2022 MariaDB Corporation Ab.
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

package GenTest::Transform::ExecuteAsSelectItem;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenUtil;
use GenTest;
use GenTest::Transform;
use Constants;

sub transform {
  my ($class, $orig_query, $executor, $orig_result) = @_;
  #We skip: - [OUTFILE | INFILE] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
  return STATUS_WONT_HANDLE if $orig_query =~ m{(OUTFILE|INFILE|PROCESSLIST)}is
    || $orig_query !~ m{^\s*SELECT}is
    || $orig_result->rows() != 1
    || $#{$orig_result->data->[0]} != 0;

  return modify_query($orig_query). " /* TRANSFORM_OUTCOME_UNORDERED_MATCH */";
}

sub variate {
  my ($class, $orig_query) = @_;
  return [ $orig_query ] if $orig_query !~ m{^\s*SELECT}is;
  return [ $orig_query ] if $orig_query =~ m{^\s*OUTFILE}is;
  return [ modify_query($orig_query) ];
}

sub modify_query {
  my $orig_query= shift;
  return "SELECT (".$orig_query.") AS s1";
}

1;
