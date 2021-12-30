# Copyright (c) 2021 MariaDB Corporation Ab
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

package GenTest::Transform::NaturalSort;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenTest;
use GenTest::Transform;
use GenTest::Constants;

sub transform {
  my ($self, $original_query) = @_;

  # Only transform SELECTs
  return STATUS_WONT_HANDLE if $original_query !~ m{^\s*SELECT}sio;

  # SELECTs from INFORMATION_SCHEMA can be non-deterministic even with read-only
  # TODO: maybe filter by table name?
  return STATUS_WONT_HANDLE if $original_query =~ m{INFORMATION_SCHEMA|PERFORMANCE_SCHEMA|\`?sys\`?\s*\.}sio;
  # SELECTs with OFFSET won't return the same results after re-ordering
  return STATUS_WONT_HANDLE if $original_query =~ m{OFFSET|FETCH}sio;
  # LIMIT x,y means OFFSET too
  return STATUS_WONT_HANDLE if $original_query =~ m{LIMIT\s+\d+\s*,\s*\d+}sio;
  # INTO file, INTO variable -- no result set to compare
  return STATUS_WONT_HANDLE if $original_query =~ m{INTO}sio;

  my $transform_outcome= 'TRANSFORM_OUTCOME_UNORDERED_MATCH';
  my $sql_select_limit= '';
  if ($original_query =~ m{LIMIT}sio) {
    $transform_outcome= "TRANSFORM_OUTCOME_SUPERSET";
    # If the original query had LIMIT clause, it had precedence over
    # sql_select_limit value, so after we remove the clause, the result set
    # can become smaller than it was with LIMIT. To avoid it, we will
    # set the variable to unlimited for the transformed query
    $sql_select_limit= 'SET STATEMENT SQL_SELECT_LIMIT=DEFAULT FOR ';
  }

  my $new_query= modify_query($original_query);
  if (defined $new_query) {
    $new_query =~ s/LIMIT\s+\d+//g;
    return $sql_select_limit .$new_query." /* $transform_outcome */ ";
  } else {
    return STATUS_WONT_HANDLE;
  }
}

sub variate {
  my ($self, $original_query, $executor, $gendata_flag) = @_;
  return $original_query if $self->random->uint16(0,1);
  return $original_query if $original_query !~ m{^\s*SELECT}sio;
  return modify_query($original_query) || $original_query;
}

sub modify_query {
  my $query= shift;
  my @new_order_by_list;

  my $query_suffix= '';
  if ($query =~ s/(LIMIT.*|OFFSET.*|FETCH.*|\s*FOR\s+UPDATE.*)?$//) {
    $query_suffix= $1;
  }
  if ($query =~ s/^(.*)ORDER\s+BY\s+(.*?)$/$1/g) {
    my @order_by_list= split /,/, $2;
    @new_order_by_list= ();
    foreach my $o (@order_by_list) {
      if ($o =~ /NATURAL_SORT_KEY\s*\((.*)\)\s*/) {
        push @new_order_by_list, $o;
      } else {
        my $mod= '';
        if ($o =~ s/(ASC|DESC)\s*$//) {
          $mod= $1;
        }
        push @new_order_by_list, "NATURAL_SORT_KEY($o) $mod ";
      }
    }
  }
  else {
    # Query doesn't have ORDER BY
    if ($query =~ /SELECT\s+(.*?)\s*FROM/) {
      my @select_list= split /,/, $1;
      @new_order_by_list= ();
      foreach my $s (@select_list) {
        if ($s =~ /(\`[^\`]*\`|\w+)\s*$/) {
          push @new_order_by_list, "NATURAL_SORT_KEY($1)";
        }
      }
    }
  }

  if (scalar(@new_order_by_list)) {
    $query .= ' ORDER BY ' . (join ', ' , @new_order_by_list) . ' '. $query_suffix;
    return $query;
  } else {
    return undef;
  }
}

1;
