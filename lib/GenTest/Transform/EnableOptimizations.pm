# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2014 SkySQL Ab
# Copyright (c) 2021 MariaDB Corporation Ab.
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
# This Transformer simply enables ALL optimizer switches
#

package GenTest::Transform::EnableOptimizations;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';
use GenTest;
use GenTest::Transform;
use GenTest::Constants;

sub transform {
	my ($class, $original_query, $executor, $original_result, $skip_result_validations) = @_;

  return STATUS_WONT_HANDLE if
    ($original_query !~ /SELECT/)
      or ($original_query =~ /(?:INTO|CREATE|INSERT.+SELECT)/is)
      or (! $skip_result_validations and $original_query =~ /INFORMATION_SCHEMA|PERFORMANCE_SCHEMA/is);

  return [
    [ "SET \@switch_saved = \@\@optimizer_switch",
      "SET SESSION optimizer_switch = REPLACE( \@\@optimizer_switch, '=off', '=on' )",
      "$original_query /* TRANSFORM_OUTCOME_UNORDERED_MATCH */" ],
    [ "/* TRANSFORM_CLEANUP */ SET SESSION optimizer_switch=\@switch_saved" ]
  ];
}

1;

