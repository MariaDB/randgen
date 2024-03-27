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

package GenTest::Simplifier::Tables;

require Exporter;
use DBI;
use GenTest;
use GenTest::Constants;
use Data::Dumper;

@ISA = qw(GenTest);

use strict;

use lib 'lib';

use constant SIMPLIFIER_DSN		=> 0;
use constant SIMPLIFIER_ORIG_DATABASE	=> 1;
use constant SIMPLIFIER_NEW_DATABASE	=> 2;
use constant SIMPLIFIER_END_TIME	=> 3;
use constant SIMPLIFIER_DB_TYPE 	=> 4;

1;

sub new {
        my $class = shift;

	my $simplifier = $class->SUPER::new({
		dsn		=> SIMPLIFIER_DSN,
		orig_database	=> SIMPLIFIER_ORIG_DATABASE,
		new_database	=> SIMPLIFIER_NEW_DATABASE,
		end_time	=> SIMPLIFIER_END_TIME,
                db_type         => SIMPLIFIER_DB_TYPE,
	}, @_);

	return $simplifier;
}

sub simplify {
	my ($simplifier, $initial_query) = @_;

	my $orig_database = $simplifier->[SIMPLIFIER_ORIG_DATABASE];
	my $new_database = $simplifier->[SIMPLIFIER_NEW_DATABASE];
        my $db_type = $simplifier->[SIMPLIFIER_DB_TYPE];
	my $new_query = $initial_query;

	my @tables_named = $initial_query =~ m{(table[a-z0-9_]+)}sgio;
	my @tables_quoted = $initial_query =~ m{`(.*?)`}sgio;
	my @tables_letters = $initial_query =~ m{[ `]([A-Z]|AA|BB|CC|DD|EE|FF|GG|HH|II|JJ|KK|LL|MM|NN|OO|PP|QQ|RR|SS|TT|UU|VV|WW|XX|YY|ZZ|AAA|BBB|CCC|DDD|EEE|FFF|GGG|HHH|III|JJJ|KKK|LLL|MMM|NNN|OOO|PPP|QQQ|RRR|SSS|TTT|UUU|VVV|WWW|XXX|YYY|ZZZ)[ `]}sgio;
	
	my @participating_tables = (@tables_named, @tables_quoted, @tables_letters);

	my %participating_tables;
	map {$participating_tables{$_} = 1 } @participating_tables;

	my @fields_quoted = $initial_query =~ m{`(.*?)`}sgio;
	my @fields_named = $initial_query =~ m{((?:char|varchar|int|set|enum|blob|date|time|datetime|pk)(?:`|\s|_key|_nokey))}sgo;

	my @participating_fields = (@fields_quoted, map {'col_'.$_} @fields_named);
	my %participating_fields;
	map { $participating_fields{$_} = 1 } @participating_fields;

	my $dbh = DBI->connect($simplifier->[SIMPLIFIER_DSN]);
        my $table_index = 0;

        if ($db_type == DB_POSTGRES) {
            $dbh->do("SET client_min_messages = warning");
            $dbh->do("DROP SCHEMA IF EXISTS $new_database CASCADE");
            $dbh->do("CREATE SCHEMA $new_database");

            my @existing_tables = $dbh->tables(undef, $orig_database, undef, 'TABLE') if $db_type == DB_POSTGRES;

            foreach my $participating_table (keys %participating_tables) {
                # bail out if this test is taking too long; otherwise all of 
                # this simplification might take hours
                if (time() > $simplifier->[SIMPLIFIER_END_TIME]) {
                    say ("Time specified by --duration=x exceeded; aborting simplification.");
                    last;
                }

                # Skip if a view is encountered.
                next if ( $participating_table =~ m{view_} );

                my $table_exists = grep{/^$orig_database.$participating_table$/} @existing_tables;
                next if !$table_exists;

                my $new_table_name = 't'.++$table_index;
                $dbh->do("CREATE TABLE $new_database . $new_table_name (LIKE $orig_database . $participating_table INCLUDING INDEXES)");
                $dbh->do("INSERT INTO $new_database . $new_table_name SELECT * FROM $orig_database . $participating_table");
                $new_query =~ s{`$participating_table`}{`$new_table_name`}sg;
                $new_query =~ s{ $participating_table }{ $new_table_name }sg;
                $new_query =~ s{ $participating_table$}{ $new_table_name}sg;

                ## Find all fields in table
                my $sth_colinfo = $dbh->column_info(undef, 'public', $participating_table, undef);
                my $actual_fields = $sth_colinfo->fetchall_arrayref;

                # ## Find indexed fields in table
                # my %indices;
                # map {$indices{$_->[4]}=$_->[2]} @{$dbh->selectall_arrayref("SHOW INDEX FROM `$new_table_name` IN $new_database")};

                ## Calculate which fields to keep
                my %keep;
                foreach my $field_info (@$actual_fields) {
                    my $actual_field = $field_info->[3];
                    if (not exists $participating_fields{$actual_field}) {
                        # ## Not used field, but may be part of multi-column index where other column is used
                        # if (exists $indices{$actual_field}) {
                        #     foreach my $x (keys %indices) {
                        #         $keep{$actual_field} = 1 
                        #             if (exists $participating_fields{$x}) and
                        #             ($indices{$x} eq $indices{$actual_field});
                        #     }
                        # }
                    } else {
                        ## Explicitely used field
                        $keep{$actual_field}=1;
                    }
                }

                ## Remove the fields we do not want to keep
                foreach my $field_info (@$actual_fields) {
                    my $actual_field = $field_info->[3];
                    $dbh->do("ALTER TABLE $new_database . $new_table_name DROP COLUMN $actual_field") if not $keep{$actual_field};
                    if (time() > $simplifier->[SIMPLIFIER_END_TIME]) {
                        say("Time specified by --duration=x exceeded.  Aborting simplification.");
                        last if 1;
                    }
                }
            }

        } else {
            $dbh->do("DROP DATABASE IF EXISTS $new_database");
            $dbh->do("CREATE DATABASE $new_database");

            foreach my $participating_table (keys %participating_tables) {
		# bail out if this test is taking too long; otherwise all of 
		# this simplification might take hours
		if (time() > $simplifier->[SIMPLIFIER_END_TIME]) {
                    say ("Time specified by --duration=x exceeded; aborting simplification.");
                    last;
		}

		# Skip if a view is encountered.
		next if ( $participating_table =~ m{view_} );
		my ($table_exists) = $dbh->selectrow_array("SHOW TABLES IN $orig_database LIKE '$participating_table'");
		next if not defined $table_exists;

		my $new_table_name = 't'.++$table_index;
		$dbh->do("CREATE TABLE $new_database . $new_table_name LIKE $orig_database . `$participating_table`");
		$dbh->do("INSERT INTO $new_database . $new_table_name SELECT * FROM $orig_database . `$participating_table`");
		$new_query =~ s{`$participating_table`}{`$new_table_name`}sg;
		$new_query =~ s{ $participating_table }{ $new_table_name }sg;
		$new_query =~ s{ $participating_table$}{ $new_table_name}sg;

	        ## Find all fields in table
                my $actual_fields = $dbh->selectcol_arrayref("SHOW FIELDS FROM `$new_table_name` IN $new_database");
	        ## Find indexed fields in table
	        my %indices;
	        map {$indices{$_->[4]}=$_->[2]} @{$dbh->selectall_arrayref("SHOW INDEX FROM `$new_table_name` IN $new_database")};

	        ## Calculate which fields to keep
	        my %keep;
		foreach my $actual_field (@$actual_fields) {
	            if (not exists $participating_fields{$actual_field}) {
	                ## Not used field, but may be part of multi-column index where other column is used
	                if (exists $indices{$actual_field}) {
	                    foreach my $x (keys %indices) {
	                        $keep{$actual_field} = 1 
	                            if (exists $participating_fields{$x}) and
	                            ($indices{$x} eq $indices{$actual_field});
	                    }
	                }
	            } else {
	                ## Explicitely used field
	                $keep{$actual_field}=1;
	            }
	        }

	        ## Remove the fields we do not want to keep
		foreach my $actual_field (@$actual_fields) {
                    $dbh->do("ALTER TABLE $new_database . `$new_table_name` DROP COLUMN `$actual_field`") if not $keep{$actual_field};
                    if (time() > $simplifier->[SIMPLIFIER_END_TIME]) {
                        say("Time specified by --duration=x exceeded.  Aborting simplification.");
                        last if 1;
                    }
	        }
            }
        }

	return [ map { 't'.$_ } (1..$table_index) ], $new_query;
}


1;
