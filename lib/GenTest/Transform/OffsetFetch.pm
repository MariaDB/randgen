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

########################################################################
# Module for MDEV-23908 (Implement SELECT ... OFFSET ... FETCH ...)
########################################################################

package GenTest::Transform::OffsetFetch;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenUtil;
use GenTest;
use GenTest::Transform;
use GenTest::Constants;

sub variate {
  my ($self, $query, $executor) = @_;
  return [ $query ] unless $executor->server->versionNumeric() >= 100601;
  return [ $query ] if $query !~ /^\s*(?:\/\*.*?\*\/\s*)?SELECT/;

  my $offset_clause= ($self->random->uint16(0,1) ?
    'OFFSET '.$self->random->uint16(0,100).($self->random->uint16(0,1) ? ' ROW' : ' ROWS') : '');
  my $fetch_clause= 'FETCH '
    . ($self->random->uint16(0,1) ? 'FIRST ' : 'NEXT ')
    . $self->random->uint16(0,100)
    . ($self->random->uint16(0,1) ? ' ROW' : ' ROWS')
    . (($query =~ /ORDER\s+BY/ and $self->random->uint16(0,1)) ? ' WITH TIES' : ' ONLY')
  ;
  my $clause= "$offset_clause $fetch_clause";

  my $comment_end= qr/\*\//;
  my $suffix= '';
  while (
       $query =~ s/(INTO\s+OUTFILE\s+(?:\"[^"]*?\"|\'[^']*?\'))\s*$//
    or $query =~ s/(\/\*[^$comment_end]*\*\/)\s*$//
    or $query =~ s/(PROCEDURE\s+ANALYSE\s*\([^)]*?\))\s*$//
  )
  {
    $suffix="$1 $suffix";
  }

  # SELECT in (redundant) brackets
  my $n= 1;
  while ($query =~ /^(.*?)(?:\(\s*){$n}\s*SELECT.*\)\s*$/) {
    last if $1 =~ /SELECT/;
    $query=~ s/\)\s*$//;
    $suffix= ") $suffix";
    $n++
  }

  if ($query=~ s/LIMIT\s+\d+(?:\s+OFFSET\s+\d+|\s*,\s*\d+)?/$clause/) {}
  else {
    $query.= " $clause";
  }
  return [ $query.($suffix ? " $suffix" : '') ];
}

sub transform {
  my ($self, $orig_query, $executor) = @_;
  return STATUS_WONT_HANDLE unless $executor->server->versionNumeric() >= 100601;
  return STATUS_WONT_HANDLE if ($orig_query !~ /SELECT/ or
    $orig_query =~ /(?:OUTFILE|INFILE|PROCESSLIST|INTO|PREPARE)/);

  my @queries= ();
  my $query= $orig_query;
  $query =~ s/LIMIT\s+(\d+)\s+OFFSET\s+(\d+)/OFFSET $2 FETCH FIRST $1 ROWS ONLY/g;
  $query =~ s/LIMIT\s+(\d+)\s*,\s*(\d+)/OFFSET $2 FETCH FIRST $1 ROWS ONLY/g;
  if ($query ne $orig_query) {
    push @queries, $query.' /* TRANSFORM_OUTCOME_UNORDERED_MATCH */';
  }
  $query= $orig_query;
  $query =~ s/(ORDER\s+BY\s+.*?)LIMIT\s+(\d+)\s+OFFSET\s+(\d+)/$1OFFSET $3 FETCH FIRST $2 ROWS WITH TIES/g;
  $query =~ s/(ORDER\s+BY\s+.*?)LIMIT\s+(\d+)\s*,\s*(\d+)/$1OFFSET $3 FETCH FIRST $2 ROWS WITH TIES/g;
  if ($query ne $orig_query) {
    push @queries, $query.' /* TRANSFORM_OUTCOME_SUPERSET */';
  }
  return (scalar @queries ? [ @queries ] : STATUS_WONT_HANDLE);
}

1;
