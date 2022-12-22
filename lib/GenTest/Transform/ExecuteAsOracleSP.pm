# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2018, 2022, MariaDB Corporation Ab
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

package GenTest::Transform::ExecuteAsOracleSP;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenUtil;
use GenTest;
use GenTest::Transform;
use Constants;

sub transform {
    my ($class, $orig_query) = @_;
    return STATUS_WONT_HANDLE if $orig_query =~ m{(?:OUTFILE|INFILE|PROCESSLIST|TRIGGER|PROCEDURE|FUNCTION)}is;
    return $class->modify($orig_query,'TRANSFORM_OUTCOME_UNORDERED_MATCH');
}

sub variate {
  my ($class, $orig_query) = @_;
  return [ $orig_query ] if $orig_query =~ m{(?:TRIGGER|PROCEDURE|FUNCTION)}is;
  return $class->modify($orig_query);
}

sub modify {
    my ($class, $orig_query, $transform_outcome) = @_;
    return [
      [
        "SET \@sql_mode.save=\@\@sql_mode",
        "SET sql_mode=CONCAT(\@\@sql_mode,',ORACLE')",
        "CREATE OR REPLACE PROCEDURE sp1_ExecuteAsOracleSP_".abs($$)." AS BEGIN $orig_query; END",
        "CALL sp1_ExecuteAsOracleSP_".abs($$).($transform_outcome ? " /* $transform_outcome */" : ""),
        "CALL sp1_ExecuteAsOracleSP_".abs($$).($transform_outcome ? " /* $transform_outcome */" : ""),
        "CREATE OR REPLACE PROCEDURE sp2_ExecuteAsOracleSP_".abs($$)." AS BEGIN sp1_ExecuteAsOracleSP_".abs($$)."; END",
        "CALL sp2_ExecuteAsOracleSP_".abs($$).($transform_outcome ? " /* $transform_outcome */" : ""),
        "CALL sp2_ExecuteAsOracleSP_".abs($$).($transform_outcome ? " /* $transform_outcome */" : ""),
        "DROP PROCEDURE IF EXISTS sp2_ExecuteAsOracleSP_".abs($$),
        "DROP PROCEDURE IF EXISTS sp1_ExecuteAsOracleSP_".abs($$),
      ],[
        '/* TRANSFORM_CLEANUP */ SET @@sql_mode=@sql_mode.save'
      ]
    ]
}

1;
