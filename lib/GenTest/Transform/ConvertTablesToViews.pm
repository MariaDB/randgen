#
# Copyright (c) 2021 MariaDB Corporation Ab.
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

package GenTest::Transform::ConvertTablesToViews;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';
use GenTest;
use GenTest::Transform;
use GenTest::Constants;

sub transform {
  my ($class, $orig_query, $executor) = @_;

# Workaround for MDEV-25009
  return STATUS_WONT_HANDLE
   if $orig_query =~ m{(?:INSERT|REPLACE).+VALUES\s*\(\s*\)}s;

  # We replace AA with view_xxx_AA, keeping the exact quotes (or lack thereof) from the original query

  my $new_query = $orig_query;
  my $prefix= 'view_'.abs($$).'_';
  my %tables= ();
  while ($new_query =~ s{([ `])([A-Z])[ `]}{$1$prefix$2$1}s) {
    $tables{$2}= 1;
  }
  while ($new_query =~ s{([ `])(([A-Z])\3)[ `]}{$1$prefix$2$1}s) {
    $tables{$2}= 1;
  }
  while ($new_query =~ s{([ `])(([A-Z])\3\3)[ `]}{$1$prefix$2$1}sg) {
    $tables{$2}= 1;
  }
  return STATUS_WONT_HANDLE if $new_query eq $orig_query;
  my @queries= ( $new_query." /* TRANSFORM_OUTCOME_UNORDERED_MATCH */" );
  foreach my $t (sort keys %tables) {
    @queries = (
      "CREATE OR REPLACE VIEW $prefix$t AS SELECT * FROM $t",
      @queries,
      "DROP VIEW IF EXISTS $prefix$t"
    );
  }

  return \@queries;
}

1;
