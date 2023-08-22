# Copyright (c) 2022, 2023 MariaDB
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


# It doesn't really validate anything, just collects per-query notes
# from EXPLAIN's Extra field and affected rows, and summarizes them.
# The logic was moved from Executor.
# Based on this, actual validating validators can be developed, e.g.
# certain explain output may be required for certain workloads

package GenTest::Validator::QueryStats;

require Exporter;
@ISA = qw(GenTest::Validator GenTest);

use Data::Dumper;

use strict;

use GenUtil;
use GenTest;
use GenTest::Comparator;
use Constants;
use GenTest::Result;
use GenTest::Validator;

# A hash of hashes (explain fragment counts for each executor)
my %explain_fragments= ();
# A hash of hashes (row group counts for each executor)
my %affected_rows= ();
my %returned_rows= ();
my %error_counts= ();
my $executor_thread_id= 0;

sub validate {
  my ($self, $executors, $results) = @_;
  $executor_thread_id= $executors->[0]->threadId unless defined $executor_thread_id;
  foreach my $i (0..$#$executors) {
    my $query= $results->[$i]->query;
    my $executor= $executors->[$i];
    my $result= $results->[$i];

    $error_counts{$i}= {} unless defined $error_counts{$i};
    $error_counts{$i}->{$result->err || '(no error)'}++;

    if ($result->status() != STATUS_SKIP) {
      my $row_group = ((not defined $result->rows()) ? 'undef' : ($result->rows() > 100 ? '>100' : ($result->rows() > 10 ? ">10" : sprintf("%5d",$result->rows()))));
      $returned_rows{$i}= {} unless exists $returned_rows{$i};
      $returned_rows{$i}->{$row_group}++;
    }
    if ($query =~ m{^\s*(update|delete|insert|replace)}is) {
      my $row_group = ((not defined $result->affectedRows) ? 'undef' : ($result->affectedRows > 100 ? '>100' : ($result->affectedRows > 10 ? ">10" : sprintf("%5d",$result->affectedRows))));
      $affected_rows{$i}= {} unless exists $affected_rows{$i};
      $affected_rows{$i}->{$row_group}++;
    }

    next if $result->err;
    next unless $query =~ /^[\(\s]*(?:SELECT|UPDATE|DELETE|INSERT|REPLACE)/i;
    $explain_fragments{$i}= {} unless exists $explain_fragments{$i};
    my $explain_parts = $executor->connection()->get_columns_by_name("EXPLAIN PARTITIONS $query");
    if ($executor->connection->err) {
      sayWarning("EXPLAIN attempt for $query failed with ".$executor->connection->print_error);
      next;
    }
    my @explain_fragments;

    foreach my $explain_row (@{$explain_parts}) {

      push @explain_fragments, "select_type: ".($explain_row->{select_type} || '(empty)');
      push @explain_fragments, "type: ".($explain_row->{type} || '(empty)');
      push @explain_fragments, "partitions: ".$explain_row->{table}.":".$explain_row->{partitions} if defined $explain_row->{partitions};
      push @explain_fragments, "possible_keys: ".(defined $explain_row->{possible_keys} ? '<'.scalar(split ',', $explain_row->{possible_keys}).'>' : '');
      push @explain_fragments, "key: ".(defined $explain_row->{key} ? ($explain_row->{key} eq 'PRIMARY' ? 'PRIMARY' : '%s') : '');
      push @explain_fragments, "ref: ".(defined $explain_row->{ref} ? ($explain_row->{ref} eq 'PRIMARY' ? 'PRIMARY' : '%s') : '');

      foreach my $extra_item (split('; ', ($explain_row->{Extra} || '(empty)')) ) {
          $extra_item =~ s{0x.*?\)}{%d\)}sgio;
          $extra_item =~ s{union\(.*?\)}{union\(%s\)}sgio;
          push @explain_fragments, "extra: ".$extra_item;
      }
    }

    my $explain_extended= $executor->connection->get_row("EXPLAIN EXTENDED $query");
    if (defined $explain_extended) {
      push @explain_fragments, $explain_extended->[2] =~ m{<[a-z_0-9\-]*?>}sgo;
    }

    foreach my $explain_fragment (@explain_fragments) {
      $explain_fragments{$i}->{$explain_fragment}++;
    }
  }
  return STATUS_OK;
}

sub DESTROY {
  $Data::Dumper::Terse= 1;
  say("-----------------------");
  foreach my $i (sort keys %explain_fragments) {
    say("Query statistics for server ".($i+1).", executor ".$executor_thread_id.":");
    say("Errors:".(Dumper $error_counts{$i}));
    say("Returned rows:".(Dumper $returned_rows{$i}));
    say("Affected rows:".(Dumper $affected_rows{$i}));
    say("Explain fragments:".(Dumper $explain_fragments{$i}));
    say("-----------------------");
  }
}

1;
