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

# Simple variator to convert SELECT or EXPLAIN into ANALYZE SELECT
# or into ANALYZE FORMAT=JSON SELECT

package GenTest::Transform::AnalyzeSelect;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenTest;
use GenTest::Transform;
use GenTest::Constants;

sub variate {
  # Don't need executor or (for now) gendata_flag
  my ($self, $query) = @_;
  my $format= ($self->random->uint16(0,1) ? 'FORMAT=JSON' : '');
  if ($query =~ /^\s*SELECT/) {
    return "ANALYZE $format $query";
  } elsif ($query =~ /^\s*EXPLAIN/) {
    $query =~ s/^\s*EXPLAIN(?:.*EXTENDED)?/ANALYZE $format/;
    return $query;
  } else {
    return $query;
 }
}

sub transform {
  return STATUS_WONT_HANDLE;
}

1;
