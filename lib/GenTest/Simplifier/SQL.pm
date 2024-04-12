# Copyright (C) 2008-2009 Sun Microsystems, Inc. All rights reserved.
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

package GenTest::Simplifier::SQL;

require Exporter;
use GenTest;
@ISA = qw(GenTest);

use strict;
use Carp;
use lib 'lib';
use DBIx::MyParsePP;
use DBIx::MyParsePP::Rule;
use GenTest::Constants;

my $empty_child = DBIx::MyParsePP::Rule->new();
my $myparse = DBIx::MyParsePP->new();

use constant SIMPLIFIER_ORACLE		=> 0;
use constant SIMPLIFIER_CACHE		=> 1;
use constant SIMPLIFIER_QUERY_ROOT	=> 2;
use constant SIMPLIFIER_PASSING_QUERIES	=> 3;
use constant SIMPLIFIER_FAILING_QUERIES	=> 4;

1;

sub new {
        my $class = shift;

	my $simplifier = $class->SUPER::new({
		'oracle'	=> SIMPLIFIER_ORACLE,
		'cache'		=> SIMPLIFIER_CACHE
	}, @_);

	$simplifier->[SIMPLIFIER_CACHE] = {} if not defined $simplifier->[SIMPLIFIER_CACHE];

	return $simplifier;
}

sub simplify {
	my ($simplifier, $initial_query) = @_;

	return $initial_query if $initial_query =~ m{^\s*$}sio;

	if ($simplifier->oracle($initial_query) != ORACLE_ISSUE_STILL_REPEATABLE) {
		carp("Initial query $initial_query failed to reproduce the same issue.");
		return undef;
	}

	my $query_obj = $myparse->parse($initial_query);

	$simplifier->[SIMPLIFIER_CACHE] = {};

	my $root = $query_obj->root();
	
	if (not defined $root) {
		carp("Unable to parse query");
		return undef;
	}

	my $root_shrunk = $root->shrink(MYPARSEPP_SHRINK_SINGLES | MYPARSEPP_SHRINK_CHILDREN);

	$simplifier->[SIMPLIFIER_QUERY_ROOT] = $root_shrunk;
	$simplifier->descend($root_shrunk, undef, 0);

	$simplifier->[SIMPLIFIER_CACHE] = {};

	my $final_query = $root_shrunk->toString();

	if ($simplifier->oracle($final_query) != ORACLE_ISSUE_STILL_REPEATABLE) {
		warn("Final query $final_query failed to reproduce the same issue.");
		return undef;
	} else {
		return $final_query;
	} 
}

sub descend {
	my ($simplifier, $parent, $grandparent, $parent_id) = @_;

	my $query_root = $simplifier->[SIMPLIFIER_QUERY_ROOT];

	my @children = $parent->children();
	return if $#children == -1;

        my $debug = 0;

        if ($debug) {
                my $parent_str = $parent->print();
                my $orig_parent_str;
                my $grandparent_str;
		if (defined $grandparent) {
                        $orig_parent_str = $grandparent->[$parent_id + 1]->print();
                        if (ref($grandparent) eq 'DBIx::MyParsePP::Rule') {
                                $grandparent_str = $grandparent->print();
                        } elsif (ref($grandparent) eq 'ARRAY') {
                                $grandparent_str = "[{".join("} , {", map { $_->print() } grep { defined $_ } @{$grandparent})."}]";
                        } else {
                                $grandparent_str = ref($grandparent);
                        }
                }
                say("descend: parent:{$parent_str}  grandparent:{$grandparent_str}  parent_id:$parent_id");
                say("*** \$parent ne \$grandparent->[\$parent_id + 1] ({$orig_parent_str}) *** ") if $parent_str ne $orig_parent_str;
        }

	
	# We start chopping from the end in order to remove GROUP BY/HAVING, etc., before we 
	# start chewing on the SELECT list and the list of joined tables
 
	foreach my $child_id (reverse (0..$#children)) {
		my $orig_child = $children[$child_id];
                next if $orig_child->print() =~ m{^\s*$}so;
                say("child$child_id={".$orig_child->print()."}") if $debug;
		
		# Do not remove the AS from "table1 AS alias1"
		next if $orig_child->print() =~ m{^\s*AS}so;

		# Do not further simplify WHERE or ON expressions that are already simple equalities/inequalities
		# This avoids generating unrealistic expressions containing only a single field, such as t1 JOIN t2 ON (t1.f1)
		next if $orig_child->print() =~ m{^\s*[A-Z0-9_`' .]*\s*(=|>|<|!=|<>|<=>|<=|>=)\s*[A-Z0-9_`' .]*\s*$}sgio;
		
		# No not remove FORCE KEY. This is sometimes useful when simplifying optimizer bugs 
		# that use InnoDB tables and have unstable query plans due to unstable InnoDB row estimates
#		next if $orig_child->print() =~ m{^\s*FORCE}so; 

		if (defined $grandparent and scalar(@{$grandparent}) > 0) {
			# replace parent with child
			my $child_str = $orig_child->toString();
                        my $orig_parent = $grandparent->[$parent_id + 1];
			$grandparent->[$parent_id + 1] = $orig_child;
			my $new_query1 = $query_root->toString();
			$grandparent->[$parent_id + 1] = $orig_parent;

                        say("Evaluating new_query1={$new_query1}") if $debug;
                        if ($new_query1 =~ m{^\s*(?:SELECT)*\s*$}sio) {
                                say("  Removed too much. Take a step back and continue with child_id=".($child_id - 1)) if $debug;
                                next;
                        }

                        my $outcome = $simplifier->oracle($new_query1);
			if ($outcome == ORACLE_ISSUE_STILL_REPEATABLE) {
				# Problem is still present, make tree modification permanent
				$grandparent->[$parent_id + 1] = $orig_child;
                                say("  Problem is still present(1). Descend and continue with parent_id as the child_id=$parent_id") if $debug;
				$simplifier->descend($orig_child, $grandparent, $parent_id);
                        } else {
                                if ($debug) {
                                        if ($outcome == ORACLE_ISSUE_STATUS_UNKNOWN) {
                                            say("  Status unknown(1) (syntax error, etc.)");
                                        } else {
                                            say("  Problem is no longer present(1)");
                                        }
                                }
                        }
		}

		# remove the child altogether

		$parent->[$child_id + 1] = $empty_child;
		my $new_query2 = $query_root->toString();
		$parent->[$child_id + 1] = $orig_child;
		my $removed_fragment2 = $orig_child->toString();

		next if $removed_fragment2 =~ m{^\s*$}sio;	# Empty fragment, skip

                say("Evaluating new_query2={$new_query2}") if $debug;
		if ($new_query2 =~ m{^\s*$}sio) {		# New query is empty, we amputated too much
                        say("  Removed too much. Take a step back and continue with child_id=$child_id") if $debug;
			$simplifier->descend($orig_child, $parent, $child_id);
		}

		if ($simplifier->oracle($new_query2) == ORACLE_ISSUE_STILL_REPEATABLE) {
                        say("  Problem is still present(2)") if $debug;
			# Problem is still present, make tree modification permanent
			$parent->[$child_id + 1] = $empty_child;
		} else {
                        say("  Problem is no longer present(2). Continue with child_id=$child_id") if $debug;
			$simplifier->descend($orig_child, $parent, $child_id);
		}
	}
}

sub oracle {
	my ($simplifier, $query) = @_;

	my $cache = $simplifier->[SIMPLIFIER_CACHE];
	my $oracle = $simplifier->[SIMPLIFIER_ORACLE];

	if (not exists $cache->{$query}) {
		my $outcome = $oracle->($query);

		if ($outcome == ORACLE_ISSUE_STILL_REPEATABLE) {
			push @{$simplifier->[SIMPLIFIER_FAILING_QUERIES]}, $query;
		} elsif ($outcome == ORACLE_ISSUE_NO_LONGER_REPEATABLE) {
			push @{$simplifier->[SIMPLIFIER_PASSING_QUERIES]}, $query;
		} elsif ($outcome != ORACLE_ISSUE_STATUS_UNKNOWN) {
			die "Bad oracle() outcome; outcome = $outcome"; 
		}

		$cache->{$query} = $outcome;
	}
		
	return $cache->{$query};
}

sub DESTROY {
	my $simplifier = shift;
	
	my $tmpfile = tmpdir().abs($$).'-'.time();

	open (PASSING, ">$tmpfile-passing.txt");
	print PASSING join (";\n", @{$simplifier->[SIMPLIFIER_PASSING_QUERIES]}).";\n" if defined $simplifier->[SIMPLIFIER_PASSING_QUERIES];
	close PASSING;

	open (FAILING, ">$tmpfile-failing.txt");
	print FAILING join (";\n", @{$simplifier->[SIMPLIFIER_FAILING_QUERIES]}).";\n" if defined $simplifier->[SIMPLIFIER_FAILING_QUERIES];
	close FAILING;

	say("Passing queries: ".$tmpfile."-passing.txt; failing queries: ".$tmpfile."-failing.txt");
}

1;
