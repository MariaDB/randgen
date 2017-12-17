# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2016, MariaDB Corporation Ab.
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

package GenTest::Transform::ExecuteAsCTE;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenTest;
use GenTest::Transform;
use GenTest::Constants;

# Expression in round brackets
my $single_quotes_template =
    qr{
        (
            \'
                (                       # group 1 - inside quotes
                    (?:
                        (?> [^']+ )    # non-quotes
                    )*
                )
            \'
        )
}xi;
my $double_quotes_template =
    qr{
        (
            \"
                (                       # group 1 - inside quotes
                    (?:
                        (?> [^"]+ )    # non-quotes
                    )*
                )
            \"
        )
}xi;
my $comment_boundaries = qr{\/\*|\*\/};
my $comment_template =
    qr{
        (
            \/\*
                (                       # group 1 - inside quotes
                    (?:
                        (?> [^$comment_boundaries]+ )    # non-quotes
                    )*
                )
            \*\/
        )
}xi;

my $parens_template =
    qr{
        (\s*
            \(
                (                       # group 1 - inside parens
                    (?:
                        (?> (?:$single_quotes_template|$double_quotes_template|$comment_template|[^()])+ )    # non-parens
                        |
                        (?1)            # recurse to group 1
                    )*
                )
            \)
        )
}xi;

# either a simple fragment without brackets
# or something in round brackets
#my $part_select_template = qr{[^()]+|$parens_template}xi;
my $part_select_template = qr{$parens_template|$comment_template|$single_quotes_template|$double_quotes_template|[^();'" ]+|;}xi;

sub convert_selects_to_cte 
{
    my ($tmp_query, $cte_count) = @_;

    my $new_query = '';
    my $in_select = 0;
    my $select;

    # Parse the query or query fragment
    while ($tmp_query =~ s/\s*($part_select_template)//xi)
    { 
        # Token here is either a part of the query without brackets, 
        # or something in round brackets
        my $token = $1;

        # If the fragment starts with SELECT, we'll start collecting the complete SELECT
        # (we assume there had been no CTEs before transformation, 
        #  or if there had, we ignore them).
        if ($token =~ /^SELECT$/is) {
            $in_select = 1;
            $select = $token;
        }

        # SELECT ends either by one of the words below, or by semicolon, 
        # or when the fragment ends
        elsif ($token =~ /^(?:UNION|INTO|RETURNING|;)/) {
          if ($in_select) {
            $new_query .= " WITH cte$cte_count AS ( $select ) SELECT * FROM cte$cte_count " . $token ;
          }
          $in_select = 0;
        }

        # Fragment in round brackets -- keep the brackets and process the contents
        elsif ($token =~ /^\s*\((.*)\)\s*$/is) {
            my $res = '(' . convert_selects_to_cte($1,$cte_count+1) . ')';
            # If we are in SELECT collection, we'll add the result to the SELECT;
            # otherwise to the new query directly
            if ($in_select) {
                $select .= $res;
            } else { 
                $new_query .= $res; 
            }
        }

        # No conversion needed, just add the next part to the select
        elsif ($in_select) {
            $select .= " $token";
        }

        # No conversion needed, just add the next part to the query
        else {
            $new_query .= " $token";
        }
    };

    # Final SELECT - if it ended by the query end
    if ($in_select) {
        $new_query .= " WITH cte$cte_count AS ( $select ) SELECT * FROM cte$cte_count ";
    }

    return $new_query;
}

sub transform {
    my ($class, $orig_query, $executor) = @_;

    return STATUS_WONT_HANDLE if $executor->versionNumeric() < 100201;
# TODO: Don't handle anything that looks like multi-statements for now
    return STATUS_WONT_HANDLE if $orig_query =~ m{;}sio;
# TODO: 2nd part of UNION does not work for now
    return STATUS_WONT_HANDLE if $orig_query =~ m{(?:GRANT\W|\sINTO\sOUTFILE|\sINTO\s\@|\WUNION\W)}sio;
    return STATUS_WONT_HANDLE if $orig_query !~ m{SELECT}sio;

    my $transformed_query = convert_selects_to_cte($orig_query, 1);
    return $transformed_query." /* TRANSFORM_OUTCOME_UNORDERED_MATCH */";
}


1;
