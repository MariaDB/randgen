# Copyright (c) 2021, 2022, MariaDB Corporation Ab
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
use GenTest::Constants;


sub transform {
  my ($self, $original_query, $executor) = @_;
  my $transform_outcome= 'TRANSFORM_OUTCOME_UNORDERED_MATCH';
  if ($original_query =~ /LIMIT|FETCH/) {
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
  return undef if $original_query !~ m{^\s*SELECT}is;
  return undef if $original_query =~ m{(OUTFILE|PROCESSLIST|INTO|GROUP_CONCAT)}is;
  my $query= $original_query;
  $query =~ s/ORDER\s+BY\s+.*?(LIMIT|OFFSET|FETCH|FOR\s+UPDATE)/\1/;
  while ($query =~ s/(?:ORDER\s+BY|LIMIT|OFFSET|FETCH)\s+.*?[^\(\)]*$//) {};
  my $dbh= $executor->dbh();
  if (!$dbh) {
      sayError("FullOrderBy: couldn't establish connection");
      return undef;
  }
  my $sth= $dbh->prepare("SELECT /* FullOrderBy column fetch */ * FROM ( $query ) FOBsq LIMIT 0");
  if (!$sth) {
      sayError("FullOrderBy: Couldn't prepare stmt: ".$dbh->err().": ".$dbh->errstr().". Original query: [ $query ]");
      return undef;
  } elsif ($sth->err) {
    sayError("FullOrderBy: Prepare of column fetch for $query returned an error: ".$sth->err." (".$sth->errstr."), variation skipped");
    return undef;
  }
  $sth->execute();
  if ($sth->err) {
    sayDebug("FullOrderBy: Column fetch for $query returned an error: ".$sth->err." (".$sth->errstr."), variation skipped");
    return undef;
  }
  my $colnum= $sth->{NUM_OF_FIELDS};
  my @full_order_by= ();
  for (1..$colnum) {
    push @full_order_by, $_ . ($self->random->uint16(0,1) ? '' : ($self->random->uint16(0,1) ? ' DESC' : ' ASC' ));
  }
  $query.= ' ORDER BY '.( join ',', @{$self->random->shuffleArray(\@full_order_by)} );
  sayDebug("FullOrderBy: Original query [ $original_query ] ; Modified query [ $query ]");
  return $query;
}

1;
