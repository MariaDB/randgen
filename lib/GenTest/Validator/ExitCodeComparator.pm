# Copyright (c) 2019, MariaDB Corporation Ab.
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

# Simple comparator to check that the baseline and the server under test
# produce the same error code / status upon query.
# Using it only makes sense with either single-threaded or read-only test flow

package GenTest::Validator::ExitCodeComparator;

require Exporter;
@ISA = qw(GenTest GenTest::Validator);

use strict;

use GenUtil;
use GenTest;
use GenTest::Constants;
use GenTest::Comparator;
use GenTest::Result;
use GenTest::Validator;
use GenTest::Executor::MariaDB;

my $garbage_in= 0;

sub validate {
    my ($comparator, $executors, $results) = @_;

    # Insufficient or excessive data
    return STATUS_OK if $#$results != 1;

    # If result codes are the same, return success right away
    return STATUS_OK if ($results->[0]->err || 0) == ($results->[1]->err || 0);

    # Ignore the difference if one of the queries was interrupted
    return STATUS_WONT_HANDLE if $results->[0]->status == STATUS_SKIP or $results->[1]->status == STATUS_SKIP;

    # We ignore certain differences, especially for major versions.
    # When it happens upon DDL and DML, and one server executes a statement
    # while another one does not, the data or structures will diverge.
    # After that, things can go differently on the servers, so it is basically
    # the "garbage in, garbage out" situation. We will skip most of the check
    # after that (the syntax check can still be performed)

    return STATUS_WONT_HANDLE if $garbage_in and $results->[0]->status != STATUS_SYNTAX_ERROR and $results->[1]->status != STATUS_SYNTAX_ERROR;

    # Other misc exceptions

    # SELECT .. INTO OUTFILE will inevitably fail on the 2nd executor,
    # regardless versions, with ER_FILE_EXISTS_ERROR

    return STATUS_WONT_HANDLE if $results->[0]->query =~ /INTO OUTFILE/ and $results->[1]->err == 1086;

    # 10.4x differs from previous versions upon
    # CREATE TABLE IF NOT EXISTS t AS SELECT .. FROM x
    # when t exists and x doesn't. Older versions would return ER_NO_SUCH_TABLE for x,
    # but 10.4+ succeeds with a warning that t already exists

    return STATUS_OK if ( ( $results->[0]->err == 1146
                            and $executors->[0]->versionNumeric lt '1004'
                            and $results->[1]->status == STATUS_OK
                            and $executors->[1]->versionNumeric ge '1004'
                          ) or
                          ( $results->[1]->err == 1146
                            and $executors->[1]->versionNumeric lt '1004'
                            and $results->[0]->status == STATUS_OK
                            and $executors->[0]->versionNumeric ge '1004'
                          )
                        ) and $results->[0]->query =~ /CREATE.*IF\s+NOT\s+EXISTS/ ;

    # If one of the servers returns syntax error and another one doesn't,
    # it might be because the server with syntax error is of an older version,
    # and something was implemented later.
    # It's not considered to be a failure,
    # as long as the version numbers correlate with this theory
    # Same if one of the servers returns an error of "unsupported" kind, and
    # another one doesn't. But in this case it is also important
    # that the newer server doesn't return syntax error!

    if ( ( $results->[0]->status() == STATUS_SYNTAX_ERROR
            and $results->[1]->status() != STATUS_SYNTAX_ERROR
            and $executors->[0]->versionNumeric lt $executors->[1]->versionNumeric
         ) or
         ( $results->[1]->status() == STATUS_SYNTAX_ERROR
            and $results->[0]->status() != STATUS_SYNTAX_ERROR
            and $executors->[0]->versionNumeric gt $executors->[1]->versionNumeric
         ) or
         ( $results->[0]->status() == STATUS_UNSUPPORTED
            and $results->[1]->status() != STATUS_UNSUPPORTED
            and $results->[1]->status() != STATUS_SYNTAX_ERROR
            and $executors->[0]->versionNumeric lt $executors->[1]->versionNumeric
         ) or
         ( $results->[1]->status() == STATUS_UNSUPPORTED
            and $results->[0]->status() != STATUS_UNSUPPORTED
            and $results->[0]->status() != STATUS_SYNTAX_ERROR
            and $executors->[0]->versionNumeric gt $executors->[1]->versionNumeric
         )
       )
    {

        # If one of the servers succeeded executing the statement, and the statement modifies the data,
        # the servers will diverge, we will have to ignore most of failures after that
        if ( ($results->[0]->status == STATUS_OK or $results->[1]->status == STATUS_OK)
              and ($results->[0]->query =~ /(?:INSERT|UPDATE|DELETE|REPLACE|ALTER|CREATE|DROP|RENAME|TRUNCATE|LOAD|CALL)/i)
           )
        {
            logResult($executors, $results, "WARNING", "Most of the validation will further be skipped");
            $garbage_in= 1;
        }
        return STATUS_WONT_HANDLE;
    }

    # On different major versions, error code may be different.
    # We can only check that they fall into the same category
    # (and even then there likely to be false positives)
    if ( $executors->[0]->serverMajorVersion != $executors->[1]->serverMajorVersion ) {
        if ($results->[0]->status() != $results->[1]->status) {
          logResult($executors, $results);
          return STATUS_ERROR_MISMATCH;
        } else {
#            say(logLine($executors,$results) . ". Ignoring the difference, since the status is the same, and major versions are different");
            return STATUS_WONT_HANDLE;
        }

    }
    # For the same major version, we'll try for now return an error on any error code mismatch
    # and see how it goes. Probably there will be way too many false positives
    else {
      logResult($executors, $results);
      return STATUS_ERROR_MISMATCH;
    }
}

sub logResult {
    my ($executors, $results, $level, $more_text)= @_;
    my $line=
      "---------- EXIT CODE COMPARISON ISSUE START ------------\n".
      "For query " . $results->[0]->query . ":\n".
      "    " . $executors->[0]->version . ": " . ( $results->[0]->err ? status2text($results->[0]->status) . ": " . $results->[0]->err . " (" . $results->[0]->errstr . ")" : "OK" )."\n".
      "    " . $executors->[1]->version . ": " . ( $results->[1]->err ? status2text($results->[1]->status) . ": " . $results->[1]->err . " (" . $results->[1]->errstr . ")" : "OK" )."\n"
    ;
    $line.= "\n".$more_text if $more_text;
    $line.= "\n"."----------- EXIT CODE COMPARISON ISSUE END -------------";
    if ($level eq 'WARNING') {
      sayWarning($line);
    } else {
      sayError($line);
    }
}

1;
