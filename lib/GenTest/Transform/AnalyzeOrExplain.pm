# Copyright (c) 2021, 2022 MariaDB Corporation Ab.
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

# Simple variator to convert SELECT or DML into ANALYZE or EXPLAIN

package GenTest::Transform::AnalyzeOrExplain;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenUtil;
use GenTest;
use GenTest::Transform;
use Constants;

sub variate {
  my ($self, $query) = @_;
  return [ $query ] unless $query =~ /^[\s\(]*(?:SELECT|UPDATE|DELETE|INSERT|REPLACE)/;
  # Should be
  # - 40% ANALYZE FORMAT=JSON,
  # - 30% EXPLAIN FORMAT=JSON,
  # - 10% ANALYZE,
  # - 10% EXPLAIN EXTENDED,
  # - 5% EXPLAIN,
  # - 5% EXPLAIN PARTITIONS
  my $dice= $self->random->uint16(1,100);
  my $cmd= '';
  if ($dice > 60) {
    $cmd= 'ANALYZE FORMAT=JSON';
  } elsif ($dice > 30) {
    $cmd= 'EXPLAIN FORMAT=JSON';
  } elsif ($dice > 20) {
    $cmd= 'ANALYZE';
  } elsif ($dice > 10) {
    $cmd= 'EXPLAIN EXTENDED';
  } elsif ($dice > 5) {
    $cmd= 'EXPLAIN PARTITIONS';
  } else {
    $cmd= 'EXPLAIN'
  }
  # but EXPLAIN is disabled for UPDATE with UNIONs due to MDEV-16694,
  # so the percentage is off
  if ($query =~ /UPDATE.*(?:UNION|INTERSECT|EXCEPT)/) {
    $cmd =~ s/EXPLAIN( EXTENDED| PARTITIONS)?/ANALYZE/;
  }
  # and ANALYZE is disabled for INSERT DELAYED due to MDEV-29160
  elsif ($query =~ /INSERT.*DELAYED/) {
    $cmd =~ s/ANALYZE/EXPLAIN/;
  }
  $query =~ s/^\s*?([\s\(]*(?:SELECT|UPDATE|DELETE|INSERT|REPLACE))/$cmd $1/;
  return [ $query ];
}

sub transform {
  return STATUS_WONT_HANDLE;
}

1;
