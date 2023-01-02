# Copyright (c) 2008,2011 Oracle and/or its affiliates. All rights reserved.
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

package GenTest::Validator;

@ISA = qw(GenTest);

use strict;
use GenTest::Result;
use GenUtil;

use constant VALIDATOR_DBH  => 0;

use constant ER_QUERY_EXCEEDED_ROWS_EXAMINED_LIMIT => 1931;

sub new {
  my $class = shift;
  return $class->SUPER::new({
    dbh => VALIDATOR_DBH
  }, @_);
}

sub init {
  return 1;
}

sub configure {
    return 1;
}

sub prerequsites {
  return undef;
}

sub dbh {
  return $_[0]->[VALIDATOR_DBH];
}

sub setDbh {
  $_[0]->[VALIDATOR_DBH] = $_[1];
}

sub compatibility {
  return '000000';
}

sub resultsetsNotComparable {
  my ($self, $results)= @_;
  if ($results->[0]->query() =~ /RESULTSETS_NOT_COMPARABLE/) {
    sayDebug("Results are not comparable according to the flag in the query");
    return 1;
  }
  if ($results->[0]->query() =~ /(?:FETCH|OFFSET|LIMIT)/i and $results->[0]->query() !~ /ORDER\s+BY/i) {
    sayDebug("Results are not comparable due to the use of LIMIT without ORDER BY\n".$results->[0]->query());
    return 1;
  }
  foreach my $i (0..$#$results) {
    if ($results->[$i]->warnings()) {
      foreach my $w (@{$results->[$i]->warnings()}) {
        if ($w->[1] == ER_QUERY_EXCEEDED_ROWS_EXAMINED_LIMIT) {
          sayDebug("Results are not comparable as the query has hit ER_QUERY_EXCEEDED_ROWS_EXAMINED_LIMIT (at least) on server ".($i+1));
          return 1;
        }
      }
    }
  }
  return 0;
}

1;
