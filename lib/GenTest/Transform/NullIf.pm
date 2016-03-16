# Copyright (C) 2016 MariaDB Corporation.
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

package GenTest::Transform::NullIf;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenTest;
use GenTest::Transform;
use GenTest::Constants;

# Expression in round brackets
my $parens_template = 
    qr{ 
        (\s*
            \(
                (                       # group 1 - inside parens
                    (?:
                        (?> [^()]+ )    # non-parens
                        |
                        (?1)            # recurse to group 1
                    )*
                )
            \)
        )
}xi;

# A part of an argument - 
# either a simple expression without brackets or commas,
# or something in round brackets
my $part_arg_template = qr{ [^(),]+ | $parens_template }xi;

# Two-argument list:
# each argument consist of one or more argument parts as above
my $args_template = qr{ $part_arg_template+ }xi;

sub transform {
    my ($class, $orig_query) = @_;

    # We skip: - [OUTFILE | INFILE] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
    return STATUS_WONT_HANDLE if $orig_query =~ m{(OUTFILE|INFILE|PROCESSLIST)}sio
#        || $orig_query !~ m{^\s*(?:\/\*\s*[\w ]+\s*\*\/)*\s*SELECT}sio
        || $orig_query !~ m{NULLIF}sio
    ;
    my $transformed_query = $orig_query;
    my $func_call;
    while ($transformed_query =~ /(nullif\s*$parens_template)/i) {
        my $func_call = $1;
        my $args = $3;
        my ($arg1, $arg2);
        if ($args =~ s/($args_template)//xi) {
            $arg1 = $1;
        }
        if ($args =~ s/($args_template)//xi) {
            $arg2 = $1;
        }
        my $replacement = 'IF( ('.$arg1.') = ('.$arg2.'), NULL, '.$arg1.')';
        $transformed_query =~ s/\Q$func_call/$replacement\E/i;
    }

    return $transformed_query." /* TRANSFORM_OUTCOME_UNORDERED_MATCH */";
}

1;
