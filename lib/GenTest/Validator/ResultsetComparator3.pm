# Copyright (C) 2008-2009 Sun Microsystems, Inc. All rights reserved.
# Copyright (c) 2021, 2022 MariaDB Corporation Ab.
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

# 2-way and 3-way result set comparartor with minority report in the
# case of 3-way comparision. Does also the same job as
# ResultsetComparator and may replace it for 2-ay comparision.

package GenTest::Validator::ResultsetComparator3;

require Exporter;
@ISA = qw(GenTest GenTest::Validator);

use strict;

use GenTest;
use GenTest::Constants;
use GenTest::Comparator;
use GenTest::Result;
use GenTest::Validator;


sub compareTwo {
    my ($self, $q, $s1, $s2, $res1, $res2) = @_;

    my $outcome = ($res1->query() =~ /OUTCOME_ORDERED_MATCH/ ? GenTest::Comparator::compare_as_ordered($res1, $res2) : GenTest::Comparator::compare_as_unordered($res1, $res2));

    if ($outcome == STATUS_LENGTH_MISMATCH) {
        if ($q =~ m{^\s*select}io) {
            say("-----------");
            say("Result length mismatch between $s1 and $s2 (".$res1->rows()." vs. ".$res2->rows().")");
            say("Query1: " . $res1->query());
            say("Query2: " . $res2->query());
            say(GenTest::Comparator::dumpDiff($res1,$res2));
        } else {
            say("-----------");
            say("Affected_rows mismatch between $s1 and $s2 (".$res1->affectedRows()." vs. ".$res2->affectedRows().")");
            say("Query1: " . $res1->query());
            say("Query2: " . $res2->query());
        }
    } elsif ($outcome == STATUS_CONTENT_MISMATCH) {
        say("-----------");
        say("Result content mismatch between $s1 and $s2.");
        say("Query1: " . $res1->query());
        say("Query2: " . $res2->query());
        say(GenTest::Comparator::dumpDiff($res1, $res2));
    }

    return $outcome;
    
}

sub validate {
    my ($self, $executors, $results) = @_;

    # Skip the whole stuff if only one resultset.

    return STATUS_OK if $#$results < 1;

    return STATUS_WONT_HANDLE if $results->[0]->status() != STATUS_OK || $results->[1]->status() != STATUS_OK;
    return STATUS_WONT_HANDLE if $results->[0]->query() =~ m{EXPLAIN}sio;

    ## Compare the two first resultsets

    my $query = $results->[0]->query();

    my $server1 = $executors->[0]->getName()." ".$executors->[0]->version();
    my $server2 = $executors->[1]->getName()." ".$executors->[1]->version();
    
    my $compare_1_2 = $self->compareTwo($query, $server1, $server2, $results->[0], $results->[1]);
    my $compare_result = $compare_1_2;

    # If 3 of them, do some more comparisions

    if ($#$results > 1) {
        my $server3 = $executors->[2]->getName()." ".$executors->[2]->version();

        return STATUS_WONT_HANDLE if $results->[2]->status() != STATUS_OK;

        my $compare_1_3 = $self->compareTwo($query, $server1, $server3, $results->[0], $results->[2]);

        ## If some of the above were different, we need compare 2 and
        ## 3 too to see if there exists a minority
        if ($compare_1_2 > STATUS_OK or $compare_1_3 > STATUS_OK) {

            return STATUS_WONT_HANDLE if $results->[2]->status() != STATUS_OK;
            
            my $compare_2_3 = $self->compareTwo($query, $server2, $server3, $results->[1], $results->[2]);

            if ($compare_1_2 > STATUS_OK and $compare_1_3 > STATUS_OK and $compare_2_3 > STATUS_OK) {
                say("Minority report: no minority");
                say("-----------");
            } elsif ($compare_1_2 > STATUS_OK and $compare_1_3 > STATUS_OK and $compare_2_3 == STATUS_OK) {
                say("Minority report: $server1(dsn1) differs from the two others");
                say("-----------");
            } elsif ($compare_1_2 > STATUS_OK and $compare_1_3 == STATUS_OK and $compare_2_3 > STATUS_OK) {
                say("Minority report: $server2(dsn2) differs from the two others");
                say("-----------");
            } elsif ($compare_1_2 == STATUS_OK and $compare_1_3 > STATUS_OK and $compare_2_3 > STATUS_OK) {
                say("Minority report: $server3(dsn3) differs from the two others");
                say("-----------");
            }
            $compare_result = $compare_2_3 if $compare_2_3 > $compare_result;
        }
        
        $compare_result = $compare_1_3 if $compare_1_3 > $compare_result;
    }

    return $compare_result;
}

1;
