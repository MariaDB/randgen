# Copyright (c) 2019, 2023, MariaDB
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

use Data::Dumper;

use strict;

use GenUtil;
use GenTest;
use Constants;
use GenTest::Comparator;
use GenTest::Result;
use GenTest::Validator;
use GenTest::Executor::MRDB;

my $garbage_in= 0;

sub validate {
    my ($comparator, $executors, $results) = @_;

#    say("Result 1");
#    print Dumper $results->[0];
#    say("Result 2");
#    print Dumper $results->[1];

    # Insufficient or excessive data
    return STATUS_OK if $#$results != 1;

    my $query= $results->[0]->query;
    my $qno= '[qno N/A]';
    if ($query =~ /(TID \d+-\d+ QNO \d+-\d+)/) {
      $qno= '['.$1.']';
    }
    # Remove comments for easier parsing
    while ($query =~ s/\/\*[^!].*?\*\///g) {}
    # Executable comments should have been already converted into either normal comments or no-comments, but still
    while ($query =~ s/\/\*\!\d*(.*?)\*\//$1/g) {}
    # We don't care much whether it's EXECUTE IMMEDIATE or just a query
    # (maybe for logging later, but then we can use the original query from the result)
    $query=~ s/^\s*EXECUTE\s+IMMEDIATE\s*["'](.*)["']\s*$/$1/;

    # Even if the exit codes are the same, before exiting we need to do some checks.
    #
    # If DDL on a table ended with different results, then regardless of whether
    # it is an expected change or not, the table can no longer participate in comparison,
    # as the instances diverge. So, we'll try to keep track of such tables.
    # We may not always succeed as tables can come as fully-qualified or not,
    # and some other difficulties may occur, so it's just the best effort.
    #
    # But a table can also be vindicated if CREATE TABLE or CREATE OR REPLACE TABLE on both servers succeeded
    # (not CREATE TABLE IF NOT EXISTS!). That's why the check is done even for same results

    if ((! $results->[0]->err) && (! $results->[1]->err)) {
      if (($query !=~ /IF\s+NOT\s+EXISTS/) && ($query =~ /^\s*CREATE\s+(?:OR\s+REPLACE\s+)?(?:TEMPORARY\s+)?TABLE\s+(\s+|`.*?`(?:\s*\.\s*(?:\s+|`.*?`))?)/is)) {
        say("ExitCodeComparator: Table $1 was (re)created successfully after query $qno, removing from invalidated (if it was there)");
        $comparator->vindicate_table($1);
      }
      return STATUS_OK;
    } elsif (($results->[0]->err || 0) == ($results->[1]->err || 0)) {
      # Now we can just exit if the error codes are the same
      return STATUS_OK;
    } else {
      # That's the case when exit codes are different
      # TODO: EXECUTE <stmt> can be added too, but then we'll need to read from performance_schema.prepared_statements_instances
      if (  ($query =~ /^\s*(ALTER)\s+(?:ONLINE\s+)?(?:IGNORE\s+)?TABLE\s+(?:IF\s+EXISTS\s+)?(\w+|`.*?`(?:\s*\.\s*(?:\s+|`.*?`))?)/is)
         || ($query =~ /^\s*(DROP)\s+(?:TEMPORARY\s+)?TABLE\s+(?:IF\s+EXISTS\s+)?(\w+|`.*?`(?:\s*\.\s*(?:\s+|`.*?`))?)/is)
         || ($query =~ /^\s*(CREATE)\s+(?:OR\s+REPLACE\s+)?(?:TEMPORARY\s+)?TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(\w+|`.*?`(?:\s*\.\s*(?:\s+|`.*?`))?)/is)
         || ($query =~ /^\s*(UPDATE)\s+(?:IGNORE\s+)?(\w+|`.*?`(?:\s*\.\s*(?:\s+|`.*?`))?)/is)
         || ($query =~ /^\s*(DELETE)\s+(?:IGNORE\s+)?FROM\s+(\w+|`.*?`(?:\s*\.\s*(?:\s+|`.*?`))?)/is)
         || ($query =~ /^\s*(INSERT)\s+(?:IGNORE\s+)?INTO\s+(\w+|`.*?`(?:\s*\.\s*(?:\s+|`.*?`))?)/is)
         || ($query =~ /^\s*(REPLACE)\s+INTO\s+(\w+|`.*?`(?:\s*\.\s*(?:\s+|`.*?`))?)/is)
         || ($query =~ /^\s*(LOAD)\s+DATA\s+.*INTO\s+TABLE\s+(\w+|`.*?`(?:\s*\.\s*(?:\s+|`.*?`))?)/is)
      ) {
        my ($op, $tbl_name)= ($1, $2);
        $tbl_name =~ s/\s*\.\s*/\./;
        if ($comparator->is_table_invalidated($tbl_name)) {
          sayDebug("ExitCodeComparator: $op on invalidated table $tbl_name is ignored for query $qno");
          return STATUS_WONT_HANDLE;
        } elsif (($op eq 'ALTER') or ($op eq 'CREATE') or ($op eq 'DROP')) {
          if ($comparator->reconcile_table($tbl_name, $executors) == STATUS_OK) {
            say("ExitCodeComparator: $op on table $tbl_name $qno returned different results (".($results->[0]->err || 0)." vs ".($results->[1]->err || 0)."), the table has been reconciled");
          } else {
            say("ExitCodeComparator: $op on table $tbl_name $qno returned different results (".($results->[0]->err || 0)." vs ".($results->[1]->err || 0)."), could not reconcile, invalidating");
            $comparator->invalidate_table($tbl_name);
          }
        }
      }
    }

# For online alter, REMOVE afterwards!!!
    return STATUS_WONT_HANDLE unless $query =~ /ALTER.*TABLE/i;

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

    return STATUS_WONT_HANDLE if $results->[0]->query =~ /INTO OUTFILE/i and $results->[1]->err == 1086;

    # LIMIT ROWS EXAMINED may or may not end with Sort aborted depending on the execution plan
    return STATUS_WONT_HANDLE if $results->[0]->query =~ /ROWS\s+EXAMINED/i and ($results->[0]->err == 1028 or $results->[1]->err == 1028);

    # PS/IS tables in different major versions may be different
    return STATUS_WONT_HANDLE if (
      $results->[0]->err == 1109 and $results->[1]->err != 1109 and isOlderVersion($executors->[0]->server->version,$executors->[1]->server->version)
      or
      $results->[0]->err != 1109 and $results->[1]->err == 1109 and isNewerVersion($executors->[0]->server->version,$executors->[1]->server->version)
    );

    # That's what all non-locking ALTER is about
    if (( $results->[0]->err == 0 ) and (( $results->[1]->err == 1846 ) || ( $results->[1]->err == 1845 )) ) {
      say("Encountered query $qno which became allowed with online alter: ".$results->[0]->query);
      return STATUS_OK;
    } elsif (( $results->[1]->err == 1846 ) || ( $results->[1]->err == 1845 )) {
      # Less exciting, but same idea -- if the query was failing with "online not supported" before, it can fail any other way now
      return STATUS_WONT_HANDLE;
    }

    # 10.4x differs from previous versions upon
    # CREATE TABLE IF NOT EXISTS t AS SELECT .. FROM x
    # when t exists and x doesn't. Older versions would return ER_NO_SUCH_TABLE for x,
    # but 10.4+ succeeds with a warning that t already exists

    return STATUS_OK if ( ( $results->[0]->err == 1146
                            and $executors->[0]->server->versionNumeric lt '1004'
                            and $results->[1]->status == STATUS_OK
                            and $executors->[1]->server->versionNumeric ge '1004'
                          ) or
                          ( $results->[1]->err == 1146
                            and $executors->[1]->server->versionNumeric lt '1004'
                            and $results->[0]->status == STATUS_OK
                            and $executors->[0]->server->versionNumeric ge '1004'
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
            and $executors->[0]->server->versionNumeric lt $executors->[1]->server->versionNumeric
         ) or
         ( $results->[1]->status() == STATUS_SYNTAX_ERROR
            and $results->[0]->status() != STATUS_SYNTAX_ERROR
            and $executors->[0]->server->versionNumeric gt $executors->[1]->server->versionNumeric
         ) or
         ( $results->[0]->status() == STATUS_UNSUPPORTED
            and $results->[1]->status() != STATUS_UNSUPPORTED
            and $results->[1]->status() != STATUS_SYNTAX_ERROR
            and $executors->[0]->server->versionNumeric lt $executors->[1]->server->versionNumeric
         ) or
         ( $results->[1]->status() == STATUS_UNSUPPORTED
            and $results->[0]->status() != STATUS_UNSUPPORTED
            and $results->[0]->status() != STATUS_SYNTAX_ERROR
            and $executors->[0]->server->versionNumeric gt $executors->[1]->server->versionNumeric
         )
       )
    {

#        # If one of the servers succeeded executing the statement, and the statement modifies the data,
#        # the servers will diverge, we will have to ignore most of failures after that
#        if ( ($results->[0]->status == STATUS_OK or $results->[1]->status == STATUS_OK)
#              and ($results->[0]->query =~ /(?:INSERT|UPDATE|DELETE|REPLACE|ALTER|CREATE|DROP|RENAME|TRUNCATE|LOAD|CALL)/i)
#           )
#        {
#            logResult($executors, $results, "WARNING", "Most of the validation will further be skipped");
#            $garbage_in= 1;
#        }
        return STATUS_WONT_HANDLE;
    }

    ################
    # Workarounds for existing bugs

    # MDEV-19303 - DELETE from sequence with ORDER BY can cause non-deterministic results
    if ($query =~ /(?:(?:UPDATE|DELETE)\W.*\WORDER\s+BY|^\s*EXECUTE)/
        and (($results->[0]->err == 0 or $results->[0]->err == 1030 or $results->[0]->err == 1031)
          and ($results->[1]->err == 0 or $results->[1]->err == 1030 or $results->[1]->err == 1031))
        and (($results->[0]->errstr =~ /(?:Storage engine SEQUENCE of the table|Expected more data in file)/)
          or ($results->[1]->errstr =~ /(?:Storage engine SEQUENCE of the table|Expected more data in file)/))
    ) {
      say("Possible MDEV-19303 upon $qno, ignoring the difference");
      return STATUS_WONT_HANDLE;
    }

    # MDEV-31601 - ALTER .. ORDER BY started failing (currently only in online alter development branch)
    if (($query =~ /ALTER\W.*(?:ALGORITHM\s*\=?\s*(?:NOCOPY|INSTANT))/i)
      and (($executors->[0]->server->versionNumeric >= 110200 && $results->[0]->err == 1845 && $results->[0]->errstr =~ /ALGORITHM=INPLACE is not supported/)
          or ($executors->[1]->server->versionNumeric >= 110200 && $results->[1]->err == 1845 && $results->[1]->errstr =~ /ALGORITHM=INPLACE is not supported/)
          )
    ) {
      say("Possible MDEV-31601 upon $qno, ignoring the difference");
      return STATUS_WONT_HANDLE;
    }

    # end of workarounds
    ################

    # On different major versions, error code may be different.
    # We can only check that they fall into the same category
    # (and even then there likely to be false positives)
    if ( $executors->[0]->server->majorVersion != $executors->[1]->server->majorVersion ) {
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
      "    " . $executors->[0]->server->version . ": " . ( $results->[0]->err ? status2text($results->[0]->status) . ": " . $results->[0]->err . " (" . $results->[0]->errstr . ")" : "OK" )."\n".
      "    " . $executors->[1]->server->version . ": " . ( $results->[1]->err ? status2text($results->[1]->status) . ": " . $results->[1]->err . " (" . $results->[1]->errstr . ")" : "OK" )."\n"
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
