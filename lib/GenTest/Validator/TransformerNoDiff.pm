# Copyright (c) 2008,2011 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, Monty Program Ab.
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


# Transformer without printing the actual diff into output,
# otherwise the same as TransformerLight.pm.
# To be used in the conditions where the volume of the output is critical
# (e.g. Travis)

package GenTest::Validator::TransformerNoDiff;

require Exporter;
@ISA = qw(GenTest::Validator GenTest);

use strict;

use Carp;
use GenTest;
use GenTest::Constants;
use GenTest::Comparator;
use GenTest::Translator;
use GenTest::Translator::Mysqldump2ANSI;
use GenTest::Translator::Mysqldump2javadb;
use GenTest::Translator::MysqlDML2ANSI;

my @transformer_names;
my @transformers;
my $database_created = 0;

sub configure {
    my ($self, $props) = @_;

    my $list = $props->transformers;

    if (defined $list and $#{$list} >= 0) {
        @transformer_names = @$list;
    } else {
        @transformer_names = (
            'DisableChosenPlan',
            'ConvertSubqueriesToViews',
            'ConvertLiteralsToSubqueries',
            'ConvertLiteralsToVariables',
            'ConvertTablesToDerived',
            'Count',
            'DisableIndexes',
            'Distinct',
            'ExecuteAsPreparedTwice',
            'ExecuteAsSPTwice',
            'ExecuteAsFunctionTwice',
            'ExecuteAsView',
            'ExecuteAsInsertSelect',
            'ExecuteAsSelectItem',
            'ExecuteAsUnion',
            'ExecuteAsUpdateDelete',
            'ExecuteAsWhereSubquery',
            'ExecuteAsTrigger',
            'ExecuteAsDerived',
            'Having',
            'InlineSubqueries',
            'InlineVirtualColumns',
            'LimitDecrease',
            'LimitIncrease',
            'OrderBy',
            'RemoveIndexHints',
            'StraightJoin',
            'SelectOption'
            );
    }

	say("Transformer Validator will use the following Transformers: ".join(', ', @transformer_names));

	foreach my $transformer_name (@transformer_names) {
		eval ("require GenTest::Transform::'".$transformer_name) or croak $@;
		my $transformer = ('GenTest::Transform::'.$transformer_name)->new();
		push @transformers, $transformer;
	}
}

sub validate {
	my ($validator, $executors, $results) = @_;

	my $executor = $executors->[0];
	my $original_result = $results->[0];
	my $original_query = $original_result->query();

	if ($database_created == 0) {
		$executor->dbh()->do("CREATE DATABASE IF NOT EXISTS transforms");
		$database_created = 1;
	}

	return STATUS_WONT_HANDLE if $original_query !~ m{^\s*(SELECT|HANDLER)}sio;
	return STATUS_WONT_HANDLE if defined $results->[0]->warnings();
    foreach my $r (@{$results}) {
        return STATUS_WONT_HANDLE if $r->status() != STATUS_OK;
    };

	my $max_transformer_status; 
	foreach my $transformer (@transformers) {
		my $transformer_status = $validator->transform($transformer, $executor, $results);
		if (($transformer_status == STATUS_CONTENT_MISMATCH) && ($original_query =~ m{LIMIT}sio)) {
			# We avoid reporting bugs on content mismatch with LIMIT queries
			say('WARNING: Got STATUS_CONTENT_MISMATCH from transformer. This is likely'.
				' a FALSE POSITIVE given that there is a LIMIT clause but possibly'.
				' no complete ORDER BY. Hence we return STATUS_OK. The previous transform issue can likely be ignored.');
			$transformer_status = STATUS_OK     
		}
		return $transformer_status if $transformer_status > STATUS_CRITICAL_FAILURE;
		$max_transformer_status = $transformer_status if $transformer_status > $max_transformer_status;
	}

	return $max_transformer_status > STATUS_SELECT_REDUCTION ? $max_transformer_status - STATUS_SELECT_REDUCTION : $max_transformer_status;
}

sub transform {
	my ($validator, $transformer, $executor, $results) = @_;

	my $original_result = $results->[0];
	my $original_query = $original_result->query();

	my ($transform_outcome, $transformed_queries, $transformed_results) = $transformer->transformExecuteValidate($original_query, $original_result, $executor);

	if (
		($transform_outcome > STATUS_CRITICAL_FAILURE) ||
		($transform_outcome == STATUS_OK) ||
		($transform_outcome == STATUS_SKIP) || 
		($transform_outcome == STATUS_WONT_HANDLE)
	) {
		return $transform_outcome;
	}

	say("---------- TRANSFORM ISSUE ----------");
	say("Original query: $original_query failed transformation with Transformer ".$transformer->name().
		"; RQG Status: ".status2text($transform_outcome)." ($transform_outcome)");
	if (not defined $transformed_queries) {
		say("WARNING: Transformer was unable to produce a transformed query.".
			" This is likely an issue with the test configuration or the ".
			$transformer->name()." transformer itself. See above for possible".
			" errors caused by the transformed query.");
		if ($transform_outcome == STATUS_UNKNOWN_ERROR) {
			# We want to know about unknown errors returned by transformed queries.
			say('ERROR: Unknown error from transformer, likely a test issue. '. 
				'Raising status to STATUS_ENVIRONMENT_FAILURE');
			return STATUS_ENVIRONMENT_FAILURE;
		}
		say("------- END OF TRANSFORM ISSUE -------");
		return $transform_outcome;
	}

	say("Transformed query: ".join('; ', @$transformed_queries));
	say("Size of the original result set: " . $original_result->rows());
	say("Size of the transformed result set: " . $transformed_results->[0]->rows());
	say("------- END OF TRANSFORM ISSUE -------");

	return $transform_outcome;
}

sub DESTROY {
	@transformers = ();
}

1;
