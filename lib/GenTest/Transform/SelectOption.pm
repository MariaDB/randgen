# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2022, MariaDB
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

package GenTest::Transform::SelectOption;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenUtil;
use GenTest;
use GenTest::Transform;
use Constants;

my @select_options= qw(
  SQL_BIG_RESULT
  SQL_SMALL_RESULT
  SQL_BUFFER_RESULT
  STRAIGHT_JOIN
  HIGH_PRIORITY
  SQL_CACHE
  SQL_NO_CACHE
  SQL_CALC_FOUND_ROWS
);

sub transform {
  my ($class, $orig_query) = @_;

  # We skip: - [OUTFILE | INFILE] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
  return STATUS_WONT_HANDLE if $orig_query =~ m{(OUTFILE|INFILE|PROCESSLIST)}is
    || $orig_query !~ m{SELECT}io;

  my $modified_queries = $class->modify($orig_query);
  my @queries= ();
  foreach my $q (@$modified_queries) {
    push @queries, $q." /* TRANSFORM_OUTCOME_UNORDERED_MATCH */ ";
  }
  return \@queries;
}

sub variate {
  my ($class, $orig_query) = @_;
  return [ $orig_query ] if $orig_query !~ m{SELECT}io;
  my $modified_queries= $class->modify($orig_query);
  return [ $class->random->arrayElement($modified_queries) ];
}

sub modify {
  my ($class, $query) = @_;
  my $search= join /|/, @select_options;
  # Remove select options if there were any
  my $removed_options= ($query =~ s/$search//iog ? 1 : 0);
  my @new_options= ( @select_options );
  $class->random->shuffleArray(\@new_options);
  my $new_options = join ' ', @new_options[0..$class->random->uint16(0,$#new_options)];
  # Remove duplicate SQL_CACHE / SQL_NO_CACHE options
  while ($new_options =~ s/^(.*SQL_(?:NO_)?CACHE.*)SQL_(?:NO_)?CACHE/$1/) {};
  # If the original query contained any options, then removing them
  # produced the first modified query
  my @modified_queries= ( $removed_options ? ( $query ) : () );
  my $q= $query;
  $q =~ s/SELECT/SELECT $new_options/iog;
  push @modified_queries, $q;
  foreach my $o (@select_options) {
    my $q= $query;
    $q =~ s{SELECT}{SELECT $o}iog;
    push @modified_queries, $q;
  }
  return \@modified_queries;
}

1;
