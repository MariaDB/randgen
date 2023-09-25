# Copyright (C) 2008-2009 Sun Microsystems, Inc. All rights reserved.
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

package GenTest::Filter::Regexp;

require Exporter;
@ISA = qw(GenTest);

use strict;

use GenUtil;
use GenTest;
use Constants;

use constant FILTER_REGEXP_FILE    => 0;
use constant FILTER_REGEXP_RULES  => 1;

my $total_queries;
my $filtered_queries;

sub new {
        my $class = shift;

  my $filter = $class->SUPER::new({
    file  => FILTER_REGEXP_FILE,
    rules  => FILTER_REGEXP_RULES
  }, @_);

  $filter->readFromFile($filter->[FILTER_REGEXP_FILE]) if defined $filter->[FILTER_REGEXP_FILE];

  return $filter;
}

sub readFromFile {
  my ($filter, $file) = @_;

  my $rules;
        open(CONF , $file) or die "unable to open Filter::Regexp file '$file': $!";
        read(CONF, my $regexp_text, -s $file);
        eval ($regexp_text);
        die "Unable to load Filter::Regexp file '$file': $@" if $@;
  $filter->[FILTER_REGEXP_RULES] = $rules;

  say("Loaded ".(keys %$rules)." filtering rules from '$file'");

  return STATUS_OK;
}

sub filter {
  my ($filter, $query) = @_;
  $total_queries++;

  foreach my $rule_name (keys %{$filter->[FILTER_REGEXP_RULES]}) {
    my $rule = $filter->[FILTER_REGEXP_RULES]->{$rule_name};

    if (
      (ref($rule) eq 'Regexp') &&
      ($query =~ m{$rule}si)
    ) {
      $filtered_queries++;
      sayDebug("Query: $query filtered out by regexp rule $rule_name.");
      return undef;
    } elsif (
      (ref($rule) eq '') &&
      (lc($query) eq lc($rule))
    ) {
      $filtered_queries++;
      sayDebug("Query: $query filtered out by literal rule $rule_name.");
      return undef;
    } elsif (ref($rule) eq 'CODE') {
      # Code may filter out a query or modify it.
      # For now we assume that m{...} rules are meant to filter out,
      # while s{...}{...} rules are meant to modify the query.
      # So, if there was a match but the resulting query ($_) is the same
      # as the original one we assume that it was the matching rule,
      # while if the query changed we assume it was a modification
      local $_ = $query;
      if ($rule->($query)) {
        $filtered_queries++;
        if ($query eq $_) {
          sayDebug("Query: $query filtered out by code rule $rule_name");
          return undef;
        } else {
          sayDebug("Query $query modified by code rule $rule_name to $_");
          return $_;
        }
      }
    }
  }
  return $query;
}

sub DESTROY {
  sayDebug("Filter::Regexp: total_queries: $total_queries; filtered_queries: $filtered_queries") if defined $total_queries;
}

1;
