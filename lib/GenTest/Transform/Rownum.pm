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

package GenTest::Transform::Rownum;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenUtil;
use GenTest;
use GenTest::Transform;
use GenTest::Constants;

sub transform {
  my ($self, $query) = @_;
  return STATUS_WONT_HANDLE if $query =~ m{(OUTFILE|INFILE|PROCESSLIST)}sio
    || $query !~ m{^\s*SELECT}io;
  return [ 
    "SELECT * FROM ( $query ) rownumquery WHERE ROWNUM() < 2147483648 /* TRANSFORM_OUTCOME_UNORDERED_MATCH */",
    "SELECT * FROM ( $query ) rownumquery WHERE ROWNUM() >= 0 /* TRANSFORM_OUTCOME_UNORDERED_MATCH */"
  ];
}

sub variate {
  my ($self, $query, $executor) = @_;
  return $query unless $executor->serverNumericVersion() >= 100601;

  my $limit= $self->random->uint16(0,100);
  my $op= $self->random->arrayElement(['<','>','<=','>=','=']);

  if ($query =~ /\WWHERE\W/) {
    $query =~ s/(\W)WHERE(\W)/${1}WHERE ROWNUM() ${op} ${limit} AND${2}/g;
  } elsif ($query =~ /^\s*SELECT/ && $query !~ /INTO\s+OUTFILE/) {
    $query = "SELECT * FROM ( $query ) rownumquery WHERE ROWNUM() ${op} ${limit}";
  }

  return $query;
}

1;
