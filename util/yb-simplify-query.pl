#!/usr/bin/perl

# Copyright (C) 2008-2009 Sun Microsystems, Inc. All rights reserved.
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

use warnings;
use strict;
use DBI;
use lib 'lib';
use lib '../lib';

$| = 1;

use GenTest::Constants;
use GenTest::Executor::Postgres;
use GenTest::Simplifier::Test;
use GenTest::Simplifier::SQL;
use GenTest::Comparator;

#
# This script demonstrates the simplification of queries. More information is available at
#
# http://forge.mysql.com/wiki/RandomQueryGeneratorSimplification
#

my $query = "SELECT 1";

my @desired_outcomes = (
	STATUS_CONTENT_MISMATCH,
	STATUS_LENGTH_MISMATCH,
        STATUS_ERROR_MISMATCH,
);

# Optional error string pattern
my $desired_errstr = undef;

# Optional SQL commands to execute before running each simplified query
my $pre_sql_cmds = undef;
#$pre_sql_cmds = "SET enable_hashjoin=OFF; SET enable_mergejoin=OFF; SET enable_material=OFF";

my @dsns = (
	'dbi:Pg:host=127.0.0.1;port=5433;user=yugabyte;database=test', # YugabyteDB
	'dbi:Pg:host=127.0.0.1;port=5432;user=postgres;database=test', # Postgres
);

# End of user-editable part

my @executors;

foreach my $dsn (@dsns) {
	my $executor = GenTest::Executor::Postgres->new( dsn => $dsn );
	my $init_status = $executor->init();
	exit ($init_status) if $init_status != STATUS_OK;
	push @executors, $executor;
}

my $simplifier = GenTest::Simplifier::SQL->new(
	oracle => sub {
		my $oracle_query = shift;
		print ".";

		my $outcome;
		my @oracle_results;

		foreach my $executor (@executors) {
                        if (defined $pre_sql_cmds) {
                                $executor->dbh()->do($pre_sql_cmds);
                        }
			my $oracle_result = $executor->execute($oracle_query, 1);
			push @oracle_results, $oracle_result;
		}

		if ($#executors == 0) {
			$outcome = $oracle_results[0]->status();
		} else {
			$outcome = GenTest::Comparator::compare($oracle_results[0], $oracle_results[1]);
		}

		foreach my $desired_outcome (@desired_outcomes) {
			return ORACLE_ISSUE_STILL_REPEATABLE if $outcome == $desired_outcome;
		}

                if (defined $desired_errstr && $oracle_results[0]->status() != 0) {
                    my $errstr = $oracle_results[0]->errstr;
                    if (defined $errstr && $errstr =~ /$desired_errstr/) {
                        return ORACLE_ISSUE_STILL_REPEATABLE;
                    }
                }
		return ORACLE_ISSUE_NO_LONGER_REPEATABLE;
	}
);

my $simplified_query = $simplifier->simplify($query);

print "\nSimplified query:\n$simplified_query ;\n\n";

my @simplified_results;

foreach my $executor (@executors) {
        my $simplified_result = $executor->execute($simplified_query);
        push @simplified_results, $simplified_result;
}


my $simplifier_test = GenTest::Simplifier::Test->new(
        executors => \@executors,
        queries => [ $simplified_query, $query ],
        results => [ \@simplified_results ]
);

my $test = $simplifier_test->simplify();

print "Simplified test:\n\n";
print $test;
