# Copyright (C) 2013 Monty Program Ab
# Copyright (C) 2022 MariaDB Corporation Ab
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


# Transformer for LIMIT ROWS EXAMINED feature introduced in MariaDB 5.5
# See https://mariadb.atlassian.net/browse/MDEV-28
# https://kb.askmonty.org/en/limit-rows-examined/

package GenTest::Transform::LimitRowsExamined;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenUtil;
use GenTest;
use GenTest::Transform;
use GenTest::Constants;

# LIMIT ROWS EXAMINED is not the exact science. The actual number of examined rows
# is allowed to be greater than the given limit, and the difference might vary
# depending on circumstances.
# By default, for ROWS EXAMINED <limit> we will allow the following:
# - if limit < OVERHEAD_FOR_LOW_LIMITS: actual number may be <= limit + OVERHEAD_FOR_LOW_LIMITS
# - else: actual number may be <= limit * OVERHEAD_MULTIPLIER.
# For example, with the default values:
# if the query contains ROWS EXAMINED 500,
# we will consider the actual number of examined rows 2499 valid, but 2501 will be an error.
# If the query contains ROWS EXAMINED 5000,
# the actual number of examined rows 9999 will be OK, but 10001 will be an error.

use constant MAX_LIMIT_ROWS_EXAMINED  => 10000;
use constant OVERHEAD_FOR_LOW_LIMITS  => 2000;
use constant OVERHEAD_MULTIPLIER  => 2;

my $show_status_query = "SELECT SUM(VARIABLE_VALUE) FROM INFORMATION_SCHEMA.SESSION_STATUS WHERE VARIABLE_NAME IN ('Handler_delete','Handler_read_first','Handler_read_key','Handler_read_next','Handler_read_prev','Handler_read_rnd','Handler_read_rnd_next','Handler_tmp_update','Handler_tmp_write','Handler_update','Handler_write')";
my $limit= MAX_LIMIT_ROWS_EXAMINED;

  # This transformation adds LIMIT ROWS EXAMINED clause if it's not there,
  # and then checks that a) the resultset is a subset of the original result,
  # and b) according to SHOW STATUS, not too many rows were examined.
  # If the query already contains ROWS EXAMINED, (a) will be skipped.
  # If the query contains LIMIT, we need to add ROWS EXAMINED, but preserve the original LIMIT.
  # It the query does not contain LIMIT, we need to add LIMIT ROWS EXAMINED.

sub transform {
  my ($self, $orig_query, $executor) = @_;
  return STATUS_WONT_HANDLE unless $self->is_applicable($orig_query);

  if ($orig_query =~ m{ROWS\s+EXAMINED\s+(\d+)}si) {
    return [
      "FLUSH STATUS",
      $orig_query,
      $show_status_query . " /* TRANSFORM_OUTCOME_EXAMINED_ROWS_LIMITED $1 */"
    ];
  }

  my $new_query= $self->modify($orig_query);

  $limit = ( $limit < OVERHEAD_FOR_LOW_LIMITS ? $limit + OVERHEAD_FOR_LOW_LIMITS : $limit * OVERHEAD_MULTIPLIER );

  if ($new_query =~ m{^\s*(?:CREATE|INSERT)}si) {
                return [
                        "FLUSH STATUS",
                        $new_query,
                        $show_status_query . " /* TRANSFORM_OUTCOME_EXAMINED_ROWS_LIMITED $limit */"
                ];
  }
  else {
    return [
      "FLUSH STATUS",
      $new_query . " /* TRANSFORM_OUTCOME_SUBSET */",
      $show_status_query . " /* TRANSFORM_OUTCOME_EXAMINED_ROWS_LIMITED $limit */"
    ];
  }
}

sub variate {
  my ($self, $query) = @_;
  return [ $query ] unless $self->is_applicable($query);
  return [ $self->modify($query) ];
}

sub is_applicable {
  my ($self, $query)= @_;
  return 0 unless $query =~ m{^\s*(?:CREATE|INSERT.*)?SELECT}si;
  return 0 if $query =~ m{FETCH\s+(?:FIRST|NEXT)}si;
  return 1;
}

sub modify {
  my ($self, $query)= @_;
  return $query if $query =~ m{ROWS\s+EXAMINED}si;

  if ($query =~ m{ROWS\s+EXAMINED\s+(\d+)}si) {
    $limit = $1;
  } else {
    $limit = $self->random->uint16(0,MAX_LIMIT_ROWS_EXAMINED);
    if    ($query =~ s{(SELECT.+LIMIT\s+\d+s*,\s*\d+)}{$1 ROWS EXAMINED $limit}isg) {}
    elsif ($query =~ s{(SELECT.+LIMIT\s+\d+\s+OFFSET\s+\d+)}{$1 ROWS EXAMINED $limit}isg) {}
    elsif ($query =~ s{(SELECT.+LIMIT\s+\d+)}{$1 ROWS EXAMINED $limit}isg) {}
    elsif ($query =~ s{(SELECT.+)(PROCEDURE\s+\w+|INTO\s+OUTFILE|INTO\s+DUMPFILE|FOR\s+UPDATE|LOCK\s+IN\s+SHARE\s+MODE)}{$1 LIMIT ROWS EXAMINED $limit $2}is) {}
    else {$query .= " LIMIT ROWS EXAMINED $limit"};
  }
  return $query;
}

1;
