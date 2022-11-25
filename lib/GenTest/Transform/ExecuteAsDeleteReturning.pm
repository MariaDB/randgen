# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2014 SkySQL Ab
# Copyright (c) 2021, 2022, MariaDB Corporation Ab.
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

package GenTest::Transform::ExecuteAsDeleteReturning;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenUtil;
use GenTest;
use GenTest::Transform;
use GenTest::Constants;


sub transform {
  my ($class, $orig_query, $executor, $original_result) = @_;

  # We skip [OUTFILE | INFILE] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
  return STATUS_WONT_HANDLE if $orig_query =~ m{(OUTFILE|INFILE|PROCESSLIST|RETURNING)}is
    || $orig_query !~ m{^\s*(SELECT)}is;
  return STATUS_WONT_HANDLE if not $original_result or not $original_result->columnNames() or "@{$original_result->columnNames()}" =~ m{`}sgio;
  my $col_list= '*';
  # INSERT/DELETE ... RETURNING <column list> doesn't work with aggregate functions
  if ($col_list !~ m{AVG|COUNT|MAX|MIN|GROUP_CONCAT|BIT_AND|BIT_OR|BIT_XOR|STD|SUM|VAR_POP|VAR_SAMP|VARIANCE}sgio) {
    my @cols= map { '`'.$_.'`' unless $_ =~ /`/ } @{$original_result->columnNames()};
    $col_list = join ',', @cols;
  }
  return [
    $class->modify($orig_query,$col_list,'TRANSFORM_OUTCOME_UNORDERED_MATCH'),
    [ '/* TRANSFORM_CLEANUP */ SET SESSION tx_read_only= @tx_read_only.save' ]
  ];
}

sub variate {
  my ($self, $query)= @_;
  if ($query =~ /^\s*DELETE/i && $query !~ /RETURNING/i) {
    return [ "$query RETURNING *" ]
  } elsif ($query =~ /^[\s\(]*SELECT/ && $query !~ /\WINTO\W/) {
    return $self->modify($query);
  } else {
    return [ $query ];
  }
}

sub modify {
  my ($self, $query, $column_list, $transform_outcome)= @_;
  my $table_name = 'tmp_ExecuteAsDeleteReturning_'.abs($$);
  $column_list= '*' unless $column_list;
  return [
    'SET @tx_read_only.save= @@session.tx_read_only',
    'SET SESSION tx_read_only= 0',
    "CREATE OR REPLACE TEMPORARY TABLE $table_name IGNORE AS $query",
    "DELETE FROM $table_name RETURNING $column_list".($transform_outcome ? " /* $transform_outcome */" : ""),
    'SET SESSION tx_read_only= @tx_read_only.save'
  ];
}

1;
