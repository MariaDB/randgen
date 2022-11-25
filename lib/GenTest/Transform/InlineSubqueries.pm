# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (C) 2022, MariaDB
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
# Replaced IN subqueries with their result sets (when possible)
########################################################################

package GenTest::Transform::InlineSubqueries;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';
use GenUtil;
use GenTest;
use GenTest::Transform;
use GenTest::Constants;

# This is a regexp to match nested brackets, taken from
# here http://www.perlmonks.org/?node_id=547596

my $paren_rx;

$paren_rx = qr{
  (?:
    \((??{$paren_rx})\) # either match another paren-set
    | [^()]+            # or match non-parens (or escaped parens
  )*
}x;

sub transform {
  my ($class, $query, $executor) = @_;
  # We skip: - [OUTFILE | INFILE] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
  return STATUS_WONT_HANDLE if $query =~ m{(OUTFILE|INFILE|PROCESSLIST)}is;
  return STATUS_WONT_HANDLE if $query !~ m{SELECT.*\s+IN\s*\(\s*SELECT}is;
  $query= $class->modify($query, $executor);
  if (defined $query) {
    my $res= $executor->execute($query, 1);
    if ($res->status() == STATUS_OK) {
      return $query." /* TRANSFORM_OUTCOME_UNORDERED_MATCH */";
    }
  }
  return STATUS_WONT_HANDLE;
}

sub variate {
  my ($class, $query, $executor) = @_;
  return [ $query ] if $query !~ m{\s+IN\s*\(\s*SELECT}is;
  my $new_query= $class->modify($query, $executor);
  return [ $new_query || $query ];
}

sub modify {
  my ($class, $query, $executor) = @_;

  my $inline_successful = 0;
  $query =~ s{IN\s*(\(\s*SELECT\s+(??{$paren_rx})\))}{
    my $result = $executor->execute($1, 1);

    if (
      ($result->status() != STATUS_OK) ||
      ($result->rows() < 1)
    ) {
      $1;        # return original query
    } else {
      $inline_successful = 1;    # return inlined literals
      "IN ( ".join(', ', map {
        if (not defined $_->[0]) {
          "NULL";
        } elsif ($_->[0] =~ m{^\d+$}is){
          $_->[0];
        } else {
          "'".$_->[0]."'"
        }
      } @{$result->data()})." ) ";
    }
  }sgexi;

  return ($inline_successful ? $query : undef);
}

1;
