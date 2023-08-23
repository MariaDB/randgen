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

package GenTest::Transform::Count;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenUtil;
use GenTest;
use GenTest::Transform;
use Constants;

# This Transform provides the following transformations
#
# SELECT COUNT(...) FROM -> SELECT ... FROM
# SELECT ... FROM -> SELECT COUNT(*) FROM
#
# (only for the first found SELECT, to minimize "the number of rows doesn't match"
# errors with subqueries

sub transform {
  my ($class, $orig_query) = @_;
  # We skip: - GROUP BY any other aggregate functions as those are difficult to validate with a simple check like TRANSFORM_OUTCOME_COUNT
  #          - [INTO] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
  #          - UNION since replacing all select lists is tricky with the current logic
  #          - Other aggregate functions because we canot verify COUNT result then
  return STATUS_WONT_HANDLE if $orig_query =~ m{GROUP\s+BY|LIMIT|HAVING|UNION|INTERSECT|EXCEPT}is
    || $orig_query =~ m{(INTO|PROCESSLIST)}is
    || $orig_query =~ m{\W(AVG|BIT_AND|BIT_OR|BIT_XOR|GROUP_CONCAT|JSON_ARRAYAGG|JSON_OBJECTAGG|MAX|MIN|STD|STDDEV|STDDEV_POP|STDDEV_SAMP|SUM|VARIANCE|VAR_POP|VAR_SAMP)\W}is
    || $orig_query !~ m{^[\(\s]*SELECT}is;
  my $query= $class->modify($orig_query, my $with_transform_outcome=1);
  return $query || STATUS_WONT_HANDLE;
}

sub variate {
  my ($class, $orig_query) = @_;
  return [ $class->modify($orig_query) || $orig_query ];
}

sub modify {
  my ($class, $orig_query, $with_transform_outcome) = @_;

  return undef if $orig_query !~ m{^\s*(?:[\(\s]*SELECT|WITH\s|VALUES)}is
    || $orig_query =~ m{(INTO|PROCESSLIST)}is ;

  # A query "SELECT * FROM ..." (without UNION and GROUP BY and window functions) is converted into SELECT COUNT(*) FROM ..."
  # A query "SELECT COUNT(*) FROM ..." (without UNION and GROUP BY and window functions) is converted into SELECT * FROM ..."
  # A query "SELECT COUNT(<single field>) [AS smth] FROM..." (without UNION and GROUP BY and window functions) is converted into SELECT <single field> [AS smth] FROM..."
  # A query "SELECT DISTINCT <single field> [AS smth] FROM..." (without UNION and GROUP BY and window functions) is converted into SELECT COUNT(DISTINCT(<single field>)) [AS smth] FROM..."
  # A query "SELECT <single field> [AS smth] FROM..." (without UNION and GROUP BY and window functions) is converted into SELECT COUNT(<single field>) [AS smth] FROM..."
  # A query "SELECT COUNT(DISTINCT(<field>)) [AS smth] FROM..." (without UNION and GROUP BY and window functions) is converted into SELECT DISTINCT <field> [AS smth] FROM..."
  # Everything else is converted into "SELECT COUNT(*) FROM (<original query>) sq"
  
  my $query= undef;
  my $transform_outcome= '';
  if (($orig_query =~ m{^\s*SELECT\W}is) and ($orig_query !~ m{\W(?:UNION|EXCEPT|INTERSECT|GROUP\s+BY|OVER)\W}is)) {
    if ($orig_query =~ s{^\s*SELECT\s+\*\s+FROM}{SELECT COUNT(*) FROM}is) {
      $query= $orig_query;
      if ($with_transform_outcome) {
        $transform_outcome= ' /* TRANSFORM_OUTCOME_COUNT */';
      }
    }
    elsif ($orig_query =~ s{^\s*SELECT\s+COUNT\(\s*\*\s*\)(\s+AS\s+\w+)?\s+FROM}{SELECT * FROM}is) {
      $query= $orig_query;
      if ($with_transform_outcome) {
        $transform_outcome= ' /* TRANSFORM_OUTCOME_COUNT_REVERSE */';
      }
    }
    elsif ($orig_query =~ s{^\s*SELECT\s+COUNT\(\s*(\w+|`[^`]+`)\s*\)(\s+AS\s+\w+)?\s+FROM}{SELECT $1$2 FROM}is) {
      $query= $orig_query;
      if ($with_transform_outcome) {
        $transform_outcome= ' /* TRANSFORM_OUTCOME_COUNT_REVERSE */';
      }
    }
    elsif ($orig_query =~ s{^\s*SELECT\s+DISTINCT[\s+|\(\s*](\w+|`[^`]+`)\)?(\s+AS\s+\w+)?\s+FROM}{SELECT COUNT(DISTINCT($1))$2 FROM}is) {
      $query= $orig_query;
      if ($with_transform_outcome) {
        $transform_outcome= ' /* TRANSFORM_OUTCOME_COUNT_NOT_NULL */';
      }
    }
    elsif ($orig_query =~ s{^\s*SELECT\s+(\w+|`[^`]+`)(\s+AS\s+\w+)?\s+FROM}{SELECT COUNT($1)$2 FROM}is) {
      $query= $orig_query;
      if ($with_transform_outcome) {
        $transform_outcome= ' /* TRANSFORM_OUTCOME_COUNT */';
      }
    }
    elsif ($orig_query =~ s{^\s*SELECT\s+COUNT\(\s*DISTINCT[\s+|\(\s*](\w+|`[^`]+`)\)?\s*\)(\s+AS\s+\w+)?\s+FROM}{SELECT DISTINCT $1$2 FROM}is) {
      $query= $orig_query;
      if ($with_transform_outcome) {
        $transform_outcome= ' /* TRANSFORM_OUTCOME_COUNT_NOT_NULL_REVERSE */';
      }
    }
  }
  unless (defined $query) {
    $query= "SELECT COUNT(*) FROM ( $orig_query ) sq_count_transformer";
    if ($with_transform_outcome) {
      $transform_outcome= ' /* TRANSFORM_OUTCOME_COUNT */';
    }
  }
  $query.= $transform_outcome;
  return [ $query ];
}

1;
