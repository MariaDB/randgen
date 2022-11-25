# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2018, 2022 MariaDB Corporation.
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

package GenTest::Transform::ExecuteAsDerived;

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
  return STATUS_WONT_HANDLE if $orig_query !~ m{^\s*SELECT}sio || $orig_query =~ m{\WINTO\W|PROCESSLIST}sio;
  return $class->modify_query($orig_query) ." /* TRANSFORM_OUTCOME_UNORDERED_MATCH */";
}

sub variate {
  my ($self, $orig_query) = @_;
  return $orig_query if $orig_query !~ m{^\s*SELECT}sio || $orig_query =~ m{\WINTO\W}sio;
  return [ $self->modify_query($orig_query) ];
}

sub modify_query {
  my ($self, $orig_query)= @_;
  $orig_query =~ s{SELECT (.*?) FROM ([^;]*)}{SELECT * FROM ( SELECT $1 FROM $2 ) AS tbl_ExecuteAsDerived }sio;
  return $orig_query;
}

1;
