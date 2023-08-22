# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2022, 2023 MariaDB
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

package GenTest::Transform::ExecuteAsPreparedTwice;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenUtil;
use GenTest;
use GenTest::Transform;
use Constants;

sub transform {
  my ($class, $orig_query, $executor) = @_;
  # We skip: - [OUTFILE | INFILE] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
  #          - Certain HANDLER statements: they can not be re-run as prepared because they advance a cursor
  return STATUS_WONT_HANDLE if $orig_query =~ m{(OUTFILE|INFILE|PROCESSLIST|PREPARE\s|OPEN\s|CLOSE\s|PREV\s|NEXT\s|INTO\s|FUNCTION|PROCEDURE)}is
    || $orig_query !~ m{SELECT|HANDLER}is;
# TODO: Don't handle anything that looks like multi-statements for now
  return STATUS_WONT_HANDLE if $orig_query =~ m{;}is;
  return $class->modify($orig_query, $executor, 'TRANSFORM_OUTCOME_UNORDERED_MATCH');
}

sub variate {
  my ($class, $orig_query, $executor) = @_;
  return [ $orig_query ] if $orig_query =~ m{(PREPARE\s|EXECUTE\s)}is;
# TODO: Don't handle anything that looks like multi-statements for now
  return [ $orig_query ] if $orig_query =~ m{;}is;
  return $class->modify($orig_query, $executor);
}

sub modify {
  my ($class, $orig_query, $executor, $transform_outcome) = @_;
  my $flags= ($orig_query !~ /^[\s\(]*SELECT/i or $orig_query =~ /RESULTSETS_NOT_COMPARABLE/) ? '/* RESULTSETS_NOT_COMPARABLE */' : '';
  return [
    "PREPARE /* TRANSFORM_SETUP */ stmt_ExecuteAsPreparedTwice_".abs($$)." FROM ".$executor->connection->quote($orig_query),
    "EXECUTE $flags stmt_ExecuteAsPreparedTwice_".abs($$).($transform_outcome ? " /* $transform_outcome */" : ''),
    "EXECUTE $flags stmt_ExecuteAsPreparedTwice_".abs($$).($transform_outcome ? " /* $transform_outcome */" : ''),
  ];
}

1;
