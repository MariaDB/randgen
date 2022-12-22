# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2021, 2022, MariaDB Corporation Ab.
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

package GenTest::Transform::ExecuteAsPSWithParams;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';
use GenUtil;
use GenTest;
use GenTest::Transform;
use GenTest::Constants;

sub transform {
  my ($class, $orig_query, $executor) = @_;

  # We skip: - [OUTFILE | INFILE] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
  return STATUS_WONT_HANDLE if $orig_query !~ m{^[\(\s]*(?:SELECT|WITH)}sgio
           || $orig_query =~ m{(INTO|PROCESSLIST)}is;
  return $class->modify($orig_query, my $with_transform_outcome=1, $executor) || STATUS_WONT_HANDLE;
}

sub variate {
  my ($class, $orig_query, $executor) = @_;
  return $class->modify($orig_query, undef, $executor) || [ $orig_query ];
}

sub modify {
  my ($class, $orig_query, $with_transform_outcome, $executor) = @_;
  return [ $orig_query ] if $orig_query =~ /^\s*(?:CREATE|ALTER)/;

  my $new_query = $orig_query;
  # Remove comments, we don't want to do substitution there
  $new_query =~ s/\/\*[^!].*?\*\///g;

  # Mask IS NULL, IS NOT NULL, SEPARATOR ...
  $new_query =~ s/IS\s+NULL/IS##NULL/g;
  $new_query =~ s/IS\s+NOT\s+NULL/IS##NOT##NULL/g;
  $new_query =~ s/SEPARATOR\s+(['"].*?['"])/SEPARATOR##$1/g;

  my $var_counter = 0;
  my @var_variables;

  # Do not match partial dates, timestamps, etc.
  if ($new_query =~ m{[,\(\s;]+(\d+|NULL|'.*?')[,\(\s;]+} || $new_query =~ m{[,\(\s;]+(\d+|NULL|'.*?')$}) {
    $new_query =~ s{([,\(\s;]+)(\d+|NULL|'.*?')([,\(\s;]+)}{
        $var_counter++;
        push @var_variables, '@var'.$var_counter." = $2";
        $1.'?'.$3;
    }sgexi;
    $new_query =~ s{([,\(\s;]+)(\d+|NULL|'.*?')$}{
        $var_counter++;
        push @var_variables, '@var'.$var_counter." = $2";
        $1.'?';
    }sgexi;
  }

  # Unmask IS NULL, IS NOT NULL, SEPARATOR ...
  $new_query =~ s/IS##NULL/IS NULL/g;
  $new_query =~ s/IS##NOT##NULL/IS NOT NULL/g;
  $new_query =~ s/SEPARATOR##(['"].*?['"])/SEPARATOR $1/g;

  if ($var_counter > 0) {
    my $stmt= 'stmt_ExecuteAsPS_'.abs($$);
    return [
      "SET ".join(", ", @var_variables),
      "PREPARE $stmt FROM ".$executor->dbh()->quote($new_query),
      "EXECUTE $stmt USING ". (join ',', map { '@var'.$_ } (1..$var_counter)).($with_transform_outcome ? " /* TRANSFORM_OUTCOME_UNORDERED_MATCH */" : ""),
      "EXECUTE $stmt USING ". (join ',', map { '@var'.$_ } (1..$var_counter)).($with_transform_outcome ? " /* TRANSFORM_OUTCOME_UNORDERED_MATCH */" : ""),
    ];
  } else {
    return undef;
  }
}

1;
