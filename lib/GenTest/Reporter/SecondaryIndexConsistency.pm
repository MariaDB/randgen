# Copyright (C) 2018, 2023, MariaDB. All rights reserved.
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

package GenTest::Reporter::SecondaryIndexConsistency;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use GenUtil;
use GenTest;
use Constants;
use GenTest::Reporter;
use GenTest::Comparator;
use Data::Dumper;
use IPC::Open2;
use IPC::Open3;

my $interval= 90;
my $first_reporter;
my $last_run= 0;

# Check that secondary indexes on InnoDB tables don't have orphan or missing records
# comparing to the PRIMARY key

sub monitor {
    my $reporter = shift;

    $first_reporter = $reporter if not defined $first_reporter;
    return STATUS_OK if $reporter ne $first_reporter;

    # Don't run the monitor too often, it's expensive
    return STATUS_OK if (time() - $last_run) < $interval;

    my $conn = $reporter->connection;

    say("Testing consistency of secondary indexes");

    my $tables = $conn->get_column("SELECT CONCAT('`',table_schema,'`.`',table_name,'`') FROM information_schema.tables WHERE engine='InnoDB'");

    $conn->execute("SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED");
    foreach my $table (@$tables) {
        my $sth_keys = $conn->get_columns_by_name("SHOW KEYS FROM $table",'Key_name','Index_type','Column_name');

        # collect all columns included into the primary key and all names of secondary keys

        my @pk_columns;
        my %secondary_keys;

        foreach my $key_hashref (@$sth_keys) {
            my $key_name = $key_hashref->{Key_name};
            my $key_type = $key_hashref->{Index_type};
            # MDEV-31885 -- forcing fulltext indexes does not end well
            if ($key_type eq 'FULLTEXT') {
              sayDebug("SecondaryIndexConsistency: Index $key_name on table $table is fulltext, skipping due to MDEV-31885");
              next;
            }
            if ($key_name eq 'PRIMARY') {
                push @pk_columns, '`'.$key_hashref->{Column_name}.'`';
            } else {
                $secondary_keys{'`'.$key_name.'`'}= 1;
            }
        }
        unless (scalar(@pk_columns)) {
          sayDebug("SecondaryIndexConsistency: Table $table doesn't have a PRIMARY KEY, skipping");
          next;
        }
        my $pk_columns= join ',', @pk_columns;

        sayDebug("SecondaryIndexConsistency: Verifying table: $table, PK columns: $pk_columns, indexes: ".join ',', keys %secondary_keys);

        unless ($conn->execute("LOCK TABLE $table READ") == STATUS_OK) {
          sayWarning("SecondaryIndexConsistency: Failed to lock table $table, skipping the check");
          next;
        }
        my $pk_data= $conn->get_column("SELECT $pk_columns FROM $table FORCE INDEX(PRIMARY) ORDER BY $pk_columns");
        next unless defined $pk_data;

        KEY:
        foreach my $ind (keys %secondary_keys) {
            my $ind_data= $conn->get_column("SELECT $pk_columns FROM $table FORCE INDEX($ind) ORDER BY $pk_columns");
            next unless defined $ind_data;

            my $diff= GenTest::Comparator::dumpDiff($pk_data, $ind_data);
            if ($diff) {
                sayError("$diff");
                sayError("Found above difference for indexes PRIMARY and $ind for table $table");
                return STATUS_DATABASE_CORRUPTION;
            } else {
                sayDebug("Indexes PRIMARY and $ind produced identical data");
            }
        }
        $conn->execute("UNLOCK TABLES");
    }
    return STATUS_OK;
}

sub type {
    return REPORTER_TYPE_PERIODIC;
}

1;
