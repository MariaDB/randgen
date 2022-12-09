# Copyright (c) 2020,2022 MariaDB Corporation
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

package GenTest::Transform::ExecuteAsInsertReturning;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenUtil;
use GenTest;
use GenTest::Transform;
use GenTest::Constants;

sub compatibility { return '100500' }

sub transform {
  my ($class, $query, $executor) = @_;
  # We skip [OUTFILE | INFILE] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
  return STATUS_WONT_HANDLE if $query =~ m{(OUTFILE|INFILE|PROCESSLIST|RETURNING)}is
    || $query !~ m{^[\(\s]*SELECT}is
    || $query =~ m{(AVG|STD|STDDEV_POP|STDDEV_SAMP|STDDEV|SUM|VAR_POP|VAR_SAMP|VARIANCE|SYSDATE)\s*\(}is
  ;
  return $class->modify($query, $executor,'TRANSFORM_OUTCOME_UNORDERED_MATCH')
}

sub variate {
  my ($self, $query, $executor)= @_;
  if ($query =~ /^\s*(?:INSERT|REPLACE)/is && $query !~ /RETURNING/is) {
    return [ "$query RETURNING *" ];
  } elsif ($query =~ /^[\(\s]*SELECT/is) {
    return $self->modify($query, $executor);
  } else {
    return [ $query ];
  }
}

sub modify {
  my ($self, $query, $executor,$transform_outcome)= @_;
  my $table_name = 'tmp_ExecuteAsInsertReturning_'.abs($$);
  return [
    [
      'SET @tx_read_only.save= @@session.tx_read_only',
      'SET SESSION tx_read_only= 0',
      "CREATE OR REPLACE TEMPORARY TABLE $table_name IGNORE AS $query",
      "REPLACE INTO $table_name $query RETURNING *".($transform_outcome ? " /* $transform_outcome */" : ""),
      'SET SESSION tx_read_only= @tx_read_only.save'
    ],[ '/* TRANSFORM_CLEANUP */ SET SESSION tx_read_only= @tx_read_only.save' ]
  ];
}

1;
