# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2014 SkySQL Ab
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

use GenTest;
use GenTest::Transform;
use GenTest::Constants;


sub transform {
	my ($class, $orig_query, $executor, $original_result) = @_;

	# We skip: - [OUTFILE | INFILE] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
	return STATUS_WONT_HANDLE if $orig_query =~ m{(OUTFILE|INFILE|PROCESSLIST)}sio
		|| $orig_query =~ m{RETURNING}sio
		|| $orig_query !~ m{^\s*(SELECT|DELETE)}sio
	        || $orig_query =~ m{LIMIT\s+\d+\s*,\s*\d+}sio
	        || $orig_query =~ m{(AVG|STD|STDDEV_POP|STDDEV_SAMP|STDDEV|SUM|VAR_POP|VAR_SAMP|VARIANCE)\s*\(}sio
	        || $orig_query =~ m{(SYSDATE)\s*\(}sio
	;

	# Two variants of transformations: for SELECT, we convert it into DELETE .. RETURNING
	# (and later compare the result sets if the validator is enabled).
	# For DELETE, we just add RETURNING *

	if ( $orig_query =~ m{^\s*SELECT}sio ) 
	{
		# The first transformation is simple, we create a table with the contents identical to the initial resultset,
		# and delete from it returning all columns

		return STATUS_WONT_HANDLE if "@{$original_result->columnNames()}" =~ m{`}sgio;

		my $table_name = 'transforms.delete_returning_'.abs($$);
		my $col_list = join ',', @{$original_result->columnNames()};

		return [
			#Include database transforms creation DDL so that it appears in the simplified testcase.
			"CREATE DATABASE IF NOT EXISTS transforms",
			"DROP TABLE IF EXISTS $table_name",
			"CREATE TABLE $table_name $orig_query",

			"DELETE FROM $table_name RETURNING $col_list /* TRANSFORM_OUTCOME_UNORDERED_MATCH */"
		];
	} 
	elsif ($orig_query =~ m{^\s*DELETE}sio )
	{
		return [ "$orig_query RETURNING *" ];
	}
}

1;
