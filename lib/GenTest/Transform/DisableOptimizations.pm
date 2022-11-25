# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2014 SkySQL Ab
# Copyright (c) 2022 MariaDB Corporation
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

#
# This Transformer simply disables all optimizer switches except for in_to_exists
#

package GenTest::Transform::DisableOptimizations;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';
use GenUtil;
use GenTest;
use GenTest::Transform;
use GenTest::Constants;

sub transform {
  my ($class, $original_query) = @_;
  return STATUS_WONT_HANDLE if
    ($original_query !~ /^[\s\(]*SELECT/is) or ($original_query =~ /\WINTO\W|INFORMATION_SCHEMA|PERFORMANCE_SCHEMA/is);
  return [
    $class->modify($original_query,'TRANSFORM_OUTCOME_UNORDERED_MATCH'),
    [ "/* TRANSFORM_CLEANUP */ SET SESSION optimizer_switch=\@switch_saved" ]
  ];
}

sub variate {
  my ($self, $original_query) = @_;
  return $self->modify($original_query);
}

sub modify {
  my ($self, $original_query, $transform_outcome)= @_;
  return [
    "SET \@switch_saved = \@\@optimizer_switch",
    "SET SESSION optimizer_switch = REPLACE(REPLACE( \@\@optimizer_switch, '=on', '=off' ), 'in_to_exists=off', 'in_to_exists=on')",
    $original_query.($transform_outcome ? " /* $transform_outcome */" : ""),
    "SET SESSION optimizer_switch=\@switch_saved"
  ];
}

1;

