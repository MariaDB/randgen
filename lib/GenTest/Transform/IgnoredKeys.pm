# Copyright (c) 2020, 2021, MariaDB Corporation Ab.
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

package GenTest::Transform::IgnoredKeys;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenTest;
use GenTest::Transform;
use GenTest::Constants;

sub variate {
  # gendata flag is not important here, we will variate either way
  # Don't need the executor, either
  my ($self, $orig_query) = @_;

  # We variate (by adding an optional [NOT] IGNORED):
  # - CREATE TABLE statements
  # - ALTER TABLE .. ADD INDEX
  # - CREATE INDEX

  my $query= '';
  if ($orig_query =~ /CREATE\s+(?:OR\s+REPLACE\s+)?TABLE/s and $orig_query !~ /SELECT|LIKE/) {
    while ($orig_query =~ s/^(.*?,\s*)((?:SPATIAL(?:\s+(?:KEY|INDEX))|UNIQUE(?:\s+(?:KEY|INDEX))|FULLTEXT(?:\s+(?:KEY|INDEX))|KEY|INDEX).*?\(.*?[^\d]\))//is) {
      my $ignore= (
        $self->random->uint16(0,1) ? ''
        : $self->random->uint16(0,1) ? ' IGNORE' : ' NOT IGNORE'
      );
      $query.= $1.$2.$ignore;
    }
  } elsif ($orig_query =~ /ALTER\s+TABLE/s) {
    while ($orig_query =~ s/^(.*?)(ADD\s+(?:SPATIAL(?:\s+(?:KEY|INDEX))|UNIQUE(?:\s+(?:KEY|INDEX))|FULLTEXT(?:\s+(?:KEY|INDEX))|KEY|INDEX).*?\(.*?[^\d]\))//is) {
      my $ignore= (
        $self->random->uint16(0,1) ? ''
        : $self->random->uint16(0,1) ? ' IGNORE' : ' NOT IGNORE'
      );
      $query.= $1.$2.$ignore;
    }
  } elsif ($orig_query =~ /CREATE\s+(?:OR\s+REPLACE\s+)?\w?\s*INDEX/s) {
    my $ignore= (
      $self->random->uint16(0,3) ? ''
      : $self->random->uint16(0,2) ? ' IGNORE' : ' NOT IGNORE'
    );
    if ($ignore and $orig_query =~ /^(.*)((?:ALGORITHM|LOCK).*)/is) {
      $orig_query.= $1.$ignore.' '.$2;
    } else {
      $orig_query.= $ignore;
    }
  }
  $query.= $orig_query;
  return $query;
}

1;
