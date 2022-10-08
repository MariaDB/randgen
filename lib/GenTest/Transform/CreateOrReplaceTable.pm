# Copyright (c) 2022, MariaDB Corporation
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

package GenTest::Transform::CreateOrReplaceTable;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenTest;
use GenTest::Transform;
use GenTest::Constants;


sub transform {
  # We will only do variation for now
  return STATUS_WONT_HANDLE;

}

sub variate {
  my ($self, $query)= @_;
  # Variate 10% queries
  return $query if $self->random->uint16(0,9);
  return $query unless $query =~ /^\s*(?:(\(\s*)*SELECT|CREATE.*TABLE)/i;
  return $query if $query =~ /(?:OUTFILE|INTO)/;
  # Make 10% tables temporary
  my $temptable= ($self->random->uint16(0,9) ? 'TABLE' : 'TEMPORARY TABLE');
  my $tablename= ($self->random->uint16(0,3) ? 'CreateOrReplaceTable'.abs($$) : 'CreateOrReplaceTable');
  if ($query =~ /^\s*CREATE/) {
    $query=~ s/CREATE.* TABLE/CREATE OR REPLACE $temptable /;
  } else {
    $query= "CREATE OR REPLACE $temptable $tablename ".$query;
  }
  return $query;
}

1;
