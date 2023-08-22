# Copyright (c) 2021, 2023, MariaDB
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

package GenTest::Transform::FullOrderBy;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenUtil;
use GenTest;
use GenTest::Transform;
use Constants;


sub transform {
  my ($self, $original_query, $executor) = @_;
  my $transform_outcome= 'TRANSFORM_OUTCOME_UNORDERED_MATCH';
  if ($original_query =~ /\WLIMIT\W|\WFETCH\W/is) {
    $transform_outcome= 'TRANSFORM_OUTCOME_SUPERSET';
  }
  $original_query= $self->modify($original_query,$executor);
  return (defined $original_query ? $original_query ." /* $transform_outcome */" : STATUS_WONT_HANDLE);
}

sub variate {
  my ($self, $original_query, $executor) = @_;
  my $query= $self->modify($original_query,$executor);
  return [ $query || $original_query ];
}

sub modify {
  my ($self, $original_query, $executor) = @_;
  return undef if $original_query !~ m{^\s*SELECT\W}is;
  return undef if $original_query =~ m{\W(?:OUTFILE|PROCESSLIST|INTO|GROUP_CONCAT)\W}is;
  my $query= $original_query;
  $query =~ s/ORDER\s+BY\s+.*?(LIMIT|OFFSET|FETCH|FOR\s+UPDATE)/\1/is;
  while ($query =~ s/(?:ORDER\s+BY|LIMIT|OFFSET|FETCH)\s+.*?[^\(\)]*$//is) {};
  my $conn= $executor->connection();
  if (!$conn) {
      sayError("FullOrderBy: couldn't establish connection");
      return undef;
  }
  $conn->query("SELECT /* FullOrderBy column fetch */ * FROM ( $query ) FOBsq LIMIT 0");
  if ($conn->err) {
    sayError("FullOrderBy: Couldn't execute stmt: ".$conn->print_error.". Original query: [ $query ]");
    return undef;
  }
  my $colnum= $conn->number_of_fields();
  my @full_order_by= ();
  for (1..$colnum) {
    push @full_order_by, $_ . ($self->random->uint16(0,1) ? '' : ($self->random->uint16(0,1) ? ' DESC' : ' ASC' ));
  }
  $query.= ' ORDER BY '.( join ',', @{$self->random->shuffleArray(\@full_order_by)} );
  sayDebug("FullOrderBy: Original query [ $original_query ] ; Modified query [ $query ]");
  return $query;
}

1;
