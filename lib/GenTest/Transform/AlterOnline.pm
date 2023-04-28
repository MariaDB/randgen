# Copyright (c) 2023, MariaDB
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

# Variator for "Online" ALTER (MDEV-16329)
# TODO: To be added to combinations when the feature is pushed into main

package GenTest::Transform::AlterOnline;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenUtil;
use GenTest;
use GenTest::Transform;
use Constants;

sub transform {
  return STATUS_WONT_HANDLE;
}

sub variate {
  my ($class, $orig_query) = @_;
  # PARTITION-related ALTER does not support ALGORITHM or LOCK
  return [ $orig_query ] if $orig_query !~ m{^\s*ALTER\s+(?:ONLINE|IGNORE\s+)?TABLE} or $orig_query =~ /PARTITION/;
  return [ $class->modify($orig_query) ];
}

sub modify {
  my ($class, $orig_query) = @_;
  my $order_by= '';
  # ORDER BY should be at the end
  if ($orig_query =~ s/(ORDER BY.*)//) {
    $order_by= $1;
    if ($orig_query =~ s/,\s*$//) {}
  }
  my $new_query;
  if ($orig_query =~ /ALTER\s+(?:ONLINE|IGNORE\s+)?TABLE\s+(?:\S+|`[^`]+`)\s*$/) {
    # If it's an empty ALTER TABLE x (now), then add the algorithm/lock without a preceding comma
    $new_query= $orig_query." ALGORITHM=COPY, LOCK=NONE";
  } else {
    $new_query= $orig_query.", ALGORITHM=COPY, LOCK=NONE";
  }
  if ($order_by) {
    $new_query.= ", $order_by";
  }
  return $new_query;
}

1;
