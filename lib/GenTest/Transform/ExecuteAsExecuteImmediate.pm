# Copyright (c) 2016, MariaDB Corporation
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


# MDEV-10585 - EXECUTE IMMEDIATE statement
#
# This is a shorthand for
# PREPARE stmt FROM "query";
# EXECUTE stmt;
# DEALLOCATE PREPARE stmt;

# Introduced in MariaDB 10.2.3

package GenTest::Transform::ExecuteAsExecuteImmediate;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenTest;
use GenTest::Transform;
use GenTest::Constants;

my $version_supported = undef;

sub transform {
    my ($class, $orig_query, $executor) = @_;

    $version_supported = ($executor->versionNumeric() >= 100203) 
        unless defined $version_supported;

    return STATUS_WONT_HANDLE unless $version_supported;
    return STATUS_WONT_HANDLE if $orig_query !~ m{SELECT|HANDLER}sio;

    return "EXECUTE IMMEDIATE ".$executor->dbh()->quote($orig_query) . " /* TRANSFORM_OUTCOME_UNORDERED_MATCH */";
}

1;
