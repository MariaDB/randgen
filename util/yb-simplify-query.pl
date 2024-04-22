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

my $query = "
SELECT 1
";

my @desired_outcomes = (
	STATUS_CONTENT_MISMATCH,
	STATUS_LENGTH_MISMATCH,
        STATUS_ERROR_MISMATCH,
);

# Increase the value for an intermittent issue
my $trials = 1;

# Optional error string pattern
my $desired_errstr = "";

# Optional warning message string pattern
my $desired_warningstr = "";

# Optional SQL commands to execute before running each simplified query
my $pre_sql_cmds = "";

# Optional prefix for hints/EXPLAIN, etc.
my $prefix = "";
## $prefix = "/*+ Set(enable_hashjoin off) Set(enable_mergejoin off) Set(enable_material off) */";
## $prefix = "EXPLAIN ";

my $add_nulls_first; # = 1;

my @dsns = (
	'dbi:Pg:host=127.0.0.1;port=5433;user=yugabyte;database=test', # YugabyteDB
	'dbi:Pg:host=127.0.0.1;port=5432;user=postgres;database=test', # Postgres
);

my $duration = 3600;

# End of user-editable part

my @executors;

foreach my $dsn (@dsns) {
	my $executor = GenTest::Executor::Postgres->new( dsn => $dsn, end_time => time() + $duration );
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
                my $warning;

                local $SIG{__WARN__} = sub { $warning = $_[0]; };
                if ($desired_warningstr) {
                    $executors[0]->dbh()->{PrintError} = 1;
                }

		foreach my $trial (1..$trials) {
                    foreach my $executor (@executors) {
                        if ($pre_sql_cmds) {
                            $executor->dbh()->do($pre_sql_cmds);
                        }

                        my $oracle_result;
                        if ($add_nulls_first) {
                            # Add NULLS FIRST to each ORDER BY key item (Workaround for
                            # NULLS FIRST not being supported by DBIx::MyParsePP)
                            # 
                            my $new_query = ($oracle_query =~ s{/\*.+\*/}{}sor);
                            $new_query =~ s{\s*\n\s*}{ }go;
                            my $order_by = ($new_query =~ s{.*\s+ORDER\s+BY\s+(\S.*)}{$1}ior);
                            $order_by =~ s{\s+LIMIT\s+\d+}{}io;
                            my $new_order_by = ($order_by =~ s{([^,]+)}{$1 NULLS FIRST}gior);
                            $new_query =~ s{ORDER\s+BY .*}{ORDER BY $new_order_by}io;
                            # print "oracle_query={$oracle_query}\norder_by={$order_by}\nnew_order_by={$new_order_by}\n\$new_query={$new_query}\n";
                            $oracle_result = $executor->execute($prefix.$new_query, 1);
                        } else {
                            $oracle_result = $executor->execute($prefix.$oracle_query, 1);
                        }
			push @oracle_results, $oracle_result;
                    }

                    if ($#executors == 0) {
			$outcome = $oracle_results[0]->status();
                    } else {
			$outcome = GenTest::Comparator::compare($oracle_results[0], $oracle_results[1]);
                    }

                    if (defined $warning && $warning =~ /$desired_warningstr/) {
                        return ORACLE_ISSUE_STILL_REPEATABLE;
                    }

                    foreach my $desired_outcome (@desired_outcomes) {
		        return ORACLE_ISSUE_STILL_REPEATABLE if $outcome == $desired_outcome;
                    }

                    if ($desired_errstr && $oracle_results[0]->status() != 0) {
                        my $errstr = $oracle_results[0]->errstr;
                        if (defined $errstr && $errstr =~ /$desired_errstr/) {
                            return ORACLE_ISSUE_STILL_REPEATABLE;
                        }
                    }

                    print "*";

                }
		return ORACLE_ISSUE_NO_LONGER_REPEATABLE;
	}
);

my $simplified_query = $simplifier->simplify($query);

if (!$simplified_query or ($prefix and $simplified_query =~ /$prefix/)) {
    print "\nFailed to simplify the query\n";
    exit;
}
print "\nSimplified query:\n$prefix$simplified_query;\n\n";


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
