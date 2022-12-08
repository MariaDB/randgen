# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2022, MariaDB Corporation Ab.
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

package GenTest::Transform::ExecuteAsView;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenUtil;
use GenTest;
use GenTest::Transform;
use GenTest::Constants;

sub transform {
  my ($class, $orig_query, $executor) = @_;

  # We skip: - [OUTFILE | INFILE] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
  return STATUS_WONT_HANDLE if $orig_query =~ m{(OUTFILE|INFILE|PROCESSLIST)}is
    || $orig_query =~ m{(SYSDATE)\s*\(}is
    || $orig_query !~ m{^\s*(?:SELECT|VALUES)}is
    || $executor->execute("CREATE OR REPLACE VIEW transforms.view_".abs($$)."_probe AS $orig_query", 1)->err() > 0;

  $executor->execute("DROP VIEW transforms.view_".abs($$)."_probe");
  return [
    #Include database transforms creation DDL so that it appears in the simplified testcase.
    "CREATE DATABASE IF NOT EXISTS transforms",
    "DROP VIEW IF EXISTS transforms.view_".abs($$)."_merge , transforms.view_".abs($$)."_temptable",
    "CREATE OR REPLACE ALGORITHM=MERGE VIEW transforms.view_".abs($$)."_merge AS $orig_query",
    "SELECT * FROM transforms.view_".abs($$)."_merge /* TRANSFORM_OUTCOME_UNORDERED_MATCH */",
    "CREATE OR REPLACE ALGORITHM=TEMPTABLE VIEW transforms.view_".abs($$)."_temptable AS $orig_query",
    "SELECT * FROM transforms.view_".abs($$)."_temptable /* TRANSFORM_OUTCOME_UNORDERED_MATCH */",
    "DROP VIEW transforms.view_".abs($$)."_merge , transforms.view_".abs($$)."_temptable"
  ];
}

sub variate {
  my ($self, $query) = @_;
  return [ $query ] if $query =~ /INTO/i;
  return [ $query ] if $query !~ /^\s*(?:SELECT|VALUES)/i;
  my $alg= $self->random->arrayElement(['ALGORITHM=TEMPTABLE','ALGORITHM=MERGE','ALGORITHM=UNDEFINED','']);
  my $vname= 'v_ExecuteAsView_'.abs($$);
  return [ "CREATE OR REPLACE $alg VIEW $vname AS $query",
           "SELECT * FROM $vname ",
           "DROP VIEW IF EXISTS $vname" ];
}

1;
