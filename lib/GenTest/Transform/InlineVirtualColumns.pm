# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2022, 2023 MariaDB
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
# Replaces virtual columns with their definitions
########################################################################


package GenTest::Transform::InlineVirtualColumns;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';
use GenUtil;
use GenTest;
use GenTest::Transform;
use Constants;

sub transform {
  my ($class, $query, $executor) = @_;
  # We skip: - [OUTFILE | INFILE] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
  return STATUS_WONT_HANDLE if $query =~ m{(OUTFILE|INFILE|PROCESSLIST)}is
    || $query !~ m{\s*SELECT}is;
  my $new_query= $class->modify($query,$executor);
  return (defined $new_query ? $new_query." /* TRANSFORM_OUTCOME_UNORDERED_MATCH */" : STATUS_WONT_HANDLE);
}

sub variate {
  my ($class, $query, $executor) = @_;
  return [ $query ] if $query !~ m{\s*FROM}is;
  my $new_query= $class->modify($query,$executor);
  return [ $new_query || $query ];
}

sub modify {
  my ($class, $query, $executor) = @_;

  my %virtual_columns;
  my ($table_name) = $query =~ m{FROM (`.*?`|\w+)[ ^]}is;
  return undef unless $table_name;

  my $table_create= $executor->connection->get_value("SHOW CREATE TABLE $table_name",1,2);

  foreach my $create_row (split("\n", $table_create)) {
    next if $create_row !~ m{ VIRTUAL}is;
    my ($column_name, $column_def) = $create_row =~ m{`(.*)`\s+[^ ]*?\s+(?:GENERATED\s+ALWAYS\s+)?AS\s*\((.+)\)\s*VIRTUAL}is;
    $virtual_columns{$column_name} = $column_def;
  }

  foreach my $virtual_column (keys %virtual_columns) {
    $query =~ s{\`?$virtual_column\`?}{$virtual_columns{$virtual_column}}sgi;
  }

  return $query;
}

1;
