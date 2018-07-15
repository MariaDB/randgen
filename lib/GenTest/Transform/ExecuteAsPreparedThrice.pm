# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2014 SkySQL Ab
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

package GenTest::Transform::ExecuteAsPreparedThrice;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenTest;
use GenTest::Transform;
use GenTest::Constants;

my $count = 0;

sub transform {
	my ($class, $orig_query, $executor) = @_;

	# We skip: - [OUTFILE | INFILE] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
	#          - Certain HANDLER statements: they can not be re-run as prepared because they advance a cursor
	return STATUS_WONT_HANDLE if $orig_query =~ m{(OUTFILE|INFILE|PROCESSLIST|PREPARE\s|OPEN\s|CLOSE\s|PREV\s|NEXT\s|INTO\s|FUNCTION|PROCEDURE)}sio
		|| $orig_query !~ m{SELECT|HANDLER}sio;
# TODO: Don't handle anything that looks like multi-statements for now
    return STATUS_WONT_HANDLE if $orig_query =~ m{;}sio;

	return [
		"PREPARE prep_stmt_".abs($$)."_".(++$count)." FROM ".$executor->dbh()->quote($orig_query),
		"EXECUTE prep_stmt_".abs($$)."_$count /* TRANSFORM_OUTCOME_UNORDERED_MATCH *//* 1st execution */",
		"EXECUTE prep_stmt_".abs($$)."_$count /* TRANSFORM_OUTCOME_UNORDERED_MATCH *//* 2nd execution */",
		"EXECUTE prep_stmt_".abs($$)."_$count /* TRANSFORM_OUTCOME_UNORDERED_MATCH *//* 3rd execution */",
		"DEALLOCATE PREPARE prep_stmt_".abs($$)."_$count"
	];
}

1;
