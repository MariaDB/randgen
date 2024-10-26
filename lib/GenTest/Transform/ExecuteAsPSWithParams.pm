# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2021, 2023, MariaDB
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
use Constants;

sub transform {
  my ($class, $orig_query, $executor) = @_;

  # We skip: - [OUTFILE | INFILE] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
  return STATUS_WONT_HANDLE if $orig_query !~ m{^[\(\s]*(?:SELECT|WITH)}sgio
           || $orig_query =~ m{(INTO|PROCESSLIST)}is;
  # SET STATEMENT disabled due to MDEV-29217
  return STATUS_WONT_HANDLE if $orig_query =~ m{SET\s*STATEMENT}sgio;
  return $class->modify($orig_query, my $with_transform_outcome=1, $executor) || STATUS_WONT_HANDLE;
}

sub variate {
  my ($class, $orig_query, $executor) = @_;
  # SET STATEMENT disabled due to MDEV-29217
  return [ $orig_query ] if $orig_query =~ m{SET\s*STATEMENT}sgio;
  return $class->modify($orig_query, undef, $executor) || [ $orig_query ];
}

sub modify {
  my ($class, $orig_query, $with_transform_outcome, $executor) = @_;
  return [ $orig_query ] if $orig_query =~ /^\s*(?:CREATE|ALTER)/i;

  my $new_query = $orig_query;
  # Remove comments, we don't want to do substitution there
  $new_query =~ s/\/\*[^!].*?\*\///g;

  # Mask IS NULL, IS NOT NULL, SEPARATOR ...
  $new_query =~ s/IS\s+NULL/IS##NULL/gi;
  $new_query =~ s/IS\s+NOT\s+NULL/IS##NOT##NULL/gi;
  #$new_query =~ s/SEPARATOR\s+(['"].*?['"])/SEPARATOR##$1##/gi;
  my @separators= ();
  while ($new_query =~ s/SEPARATOR\s+('[^']+'|"[^"]+")/SEPARATOR#####/) { push @separators, $1 };

  my $var_counter = 0;
  my @var_variables;

  while (
    $new_query =~ s{([^\w\#'])('[^']*'|-?\.?\d+\.?\d*(?:[eE]\d+)?|NULL)([^\w\#']|$)}{
        my ($prefix, $val, $suffix)= ($1,$2,$3);
        $var_counter++;
        push @var_variables, '@var'.$var_counter." = $val";
        $prefix.'?'.$suffix;
    }sexi
  ) {};

  # Unmask IS NULL, IS NOT NULL, SEPARATOR ...
  $new_query =~ s/IS##NULL/IS NULL/gi;
  $new_query =~ s/IS##NOT##NULL/IS NOT NULL/gi;
  #$new_query =~ s/SEPARATOR##(['"].*?['"])##/SEPARATOR $1/gi;
  while ($new_query =~ s{SEPARATOR#####}{'SEPARATOR '.(shift @separators)}sei) {}

  if ($var_counter > 0) {
    my $stmt= 'stmt_ExecuteAsPS_'.abs($$);
    my $flags= ($new_query !~ /^[\s\(]*SELECT/i or $new_query =~ /RESULTSETS_NOT_COMPARABLE/) ? '/* RESULTSETS_NOT_COMPARABLE */' : '';
    return [
      "SET  /* TRANSFORM_SETUP */ ".join(", ", @var_variables),
      "PREPARE /* TRANSFORM_SETUP */ $stmt FROM ".$executor->connection()->quote($new_query),
      "EXECUTE $flags $stmt USING ". (join ',', map { '@var'.$_ } (1..$var_counter)).($with_transform_outcome ? " /* TRANSFORM_OUTCOME_UNORDERED_MATCH */" : ""),
      "EXECUTE $flags $stmt USING ". (join ',', map { '@var'.$_ } (1..$var_counter)).($with_transform_outcome ? " /* TRANSFORM_OUTCOME_UNORDERED_MATCH */" : ""),
    ];
  } else {
    return undef;
  }
}

1;
