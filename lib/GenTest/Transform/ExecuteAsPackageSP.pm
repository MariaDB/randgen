# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2018 MariaDB Corporation Ab
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

package GenTest::Transform::ExecuteAsPackageSP;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenTest;
use GenTest::Transform;
use GenTest::Constants;

sub transform {
    my ($class, $orig_query, $executor) = @_;

    return STATUS_WONT_HANDLE unless $executor->versionNumeric() >= 100307;
    return STATUS_WONT_HANDLE if $orig_query =~ m{(?:OUTFILE|INFILE|PROCESSLIST|TRIGGER|PROCEDURE|FUNCTION)}sio;
    # Disabled due to MDEV-16783
    return STATUS_WONT_HANDLE if $orig_query =~ m{HISTORY}sio;

    return [
        [
            "SET \@sql_mode.save=\@\@sql_mode",
            "SET sql_mode=CONCAT(\@\@sql_mode,',ORACLE')",
            "CREATE OR REPLACE PACKAGE pkg_".abs($$)." IS PROCEDURE stored_proc_".abs($$)."; PROCEDURE stored_proc_2_".abs($$)."; END",
            "CREATE OR REPLACE PACKAGE BODY pkg_".abs($$)." IS PROCEDURE stored_proc_".abs($$)." AS BEGIN $orig_query; END; PROCEDURE stored_proc_2_".abs($$)." AS BEGIN stored_proc_".abs($$)."; END; END",
            "CALL pkg_".abs($$).".stored_proc_".abs($$)." /* TRANSFORM_OUTCOME_UNORDERED_MATCH */",
            "CALL pkg_".abs($$).".stored_proc_".abs($$)." /* TRANSFORM_OUTCOME_UNORDERED_MATCH */",
            "CALL pkg_".abs($$).".stored_proc_2_".abs($$)." /* TRANSFORM_OUTCOME_UNORDERED_MATCH */",
            "CALL pkg_".abs($$).".stored_proc_2_".abs($$)." /* TRANSFORM_OUTCOME_UNORDERED_MATCH */",
            "DROP PACKAGE BODY IF EXISTS pkg_".abs($$),
            "DROP PACKAGE IF EXISTS pkg".abs($$)
        ],
        [
            "/* TRANSFORM_CLEANUP */ SET \@\@sql_mode=\@sql_mode.save"
        ]
    ];
}

1;
