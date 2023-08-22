# Copyright (c) 2011 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2022, 2023 MariaDB
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

package GenTest::Validator::OptimizerTraceParser;

require Exporter;
@ISA = qw(GenTest::Validator GenTest);

use strict;

use Data::Dumper;
use GenUtil;
use GenTest;
use GenTest::Comparator;
use Constants;
use GenTest::Result;
use GenTest::Validator;

use File::Basename;

################################################################################
# This validator retrieves the optimizer trace output for each query and
# checks it using the in-built JSON_VALID function.
# If it fails, the validation fails (with a non-fatal status).
#
# Traces that are truncated due to missing bytes beyond max mem threshold are
# not attempted parsed, and will not cause test failure.
#
# Prerequisites:
#   - optimzier tracing must be available and enabled
#
# More on JSON: http://www.ietf.org/rfc/rfc4627.txt
#
################################################################################


# Some counters
my $valid_traces_count = 0;     # traces that were parsed successfully
my $missing_bytes_count = 0;    # traces that were truncated due to missing bytes (out of memory)
my $invalid_traces_count = 0;   # traces that failed to parse for unknown reason
my $no_traces_count = 0;        # statements with no generated optimizer trace
my $skipped_count = 0;          # statements for which we did not attempt to get trace
# We'll be ignoring some known issues
# MDEV-30334 Optimizer trace produces invalid JSON with WHERE subquery
my $known_issues_count = 0;

# Helper variables
my $have_opt_trace; # a value of 1 means that optimizer_trace is available and enabled.
my $thisFile;       # the name of this validator

BEGIN {
    # Get the name of this validator (used for feedback to user).
    $thisFile = basename(__FILE__);
    $thisFile =~ s/\.pm//;  # remove .pm suffix from file name
}

sub compatibility { return '100500' };

sub validate {
    my ($validator, $executors, $results) = @_;
    my $executor = $executors->[0];
    my $orig_result = $results->[0];

    return STATUS_WONT_HANDLE if $orig_result->status() != STATUS_OK;

    my $orig_query = $orig_result->query();

    # Note that by default only the trace for the last executed statement will
    # be available. If we run any extra statements for some reason we need to
    # take this into account when asking the server for the trace.
    my $extra_statements = 0; # Number of statements executed after the original.

    # Check if optimizer_trace is enabled.
    # Save the result in a variable so we don't have to check it every time.
    if (not defined $have_opt_trace) {
        my $opt_trace_value = $executor->connection->get_value('SELECT @@optimizer_trace');
        $extra_statements++;
        if ($opt_trace_value !~ m{enabled=on}) {
            say('ERROR: Optimizer trace is disabled or not available. '.$thisFile.' validator cannot continue.');
            # Since tracing is per-session, we may want to just continue in this case (return STATUS_WONT_HANDLE).
            # However, we are returning a fatal error for now, to avoid accidentally thinking parsing was OK.
            #$have_opt_trace = 0;
            return STATUS_ENVIRONMENT_FAILURE;
        } else {
            $have_opt_trace = 1;
        }
    }

    # We need to retrieve the actual trace for the original query.
    #
    # We assume here that only the trace for the last executed query is
    # available.
    # JSON_COMPACT is retrieved because it produces helpful warnings
    # (unlike JSON_VALID)

    my $trace_query = 'SELECT `query`, `trace`, JSON_VALID(`trace`), JSON_COMPACT(`trace`), `missing_bytes_beyond_max_mem_size` FROM information_schema.OPTIMIZER_TRACE';
    my $trace_result = $executor->execute($trace_query);
    if (not defined $trace_result->data()) {
      $no_traces_count++;
      sayError("$thisFile was unable to obtain optimizer trace for query $orig_query");
      my $opt_trace_value = $executor->connection->value('SELECT @@optimizer_trace');
      if ($opt_trace_value !~ m{enabled=on}) {
          sayError("Optimizer trace is disabled or not available");
          return STATUS_CONFIGURATION_ERROR;
      } else {
        return STATUS_UNKNOWN_ERROR;
      }
    }

    if ($trace_result->rows() != 1) {
        say("ERROR: Unexpected result from optimizer trace query ($thisFile): ".
            "Number of returned rows was ".$trace_result->rows().", expected 1.");
        return STATUS_ENVIRONMENT_FAILURE;
    }

    # Get the trace from the query result.
    # The result set is expected to have the following columns by default:
    #  QUERY | TRACE | MISSING_BYTES_BEYOND_MAX_MEM_SIZE
    #
    # If missing bytes, trace will not be valid JSON, it will be truncated.

    my ($query, $trace, $trace_valid, $trace_compact, $missing_bytes) = @{$trace_result->data()->[0]};
    # HERE:
    # print Dumper $trace_result;

    # Filter out traces with missing bytes.
    if ($missing_bytes > 0) {
        $missing_bytes_count++;
        sayDebug("$thisFile skipping validation of query due to missing $missing_bytes bytes from trace: $query");
        return STATUS_WONT_HANDLE;
    }
    my $warnings_text= '';
    unless ($trace_valid) {
      my $warnings= $trace_result->warnings();
      if ($warnings and (ref $warnings eq 'ARRAY')) {
        foreach my $w (@$warnings) {
          $warnings_text.= $w->[1]." ".$w->[2]."\n";
          # Too many nested levels
          if ($w->[1] == 4040) {
            sayWarning("Optimizer trace produced invalid JSON, assuming MDEV-30343: ".$w->[1]." ".$w->[2]."\nQuery [ $orig_query ]");
            $known_issues_count++;
            return STATUS_IGNORED_ERROR;
          }
          # Character disallowed in JSON in argument
          elsif ($w->[1] == 4036 && $trace =~ /(?:select\s*\#|condition.*)[[:^print:]]/) {
            sayWarning("Optimizer trace produced invalid JSON, assuming MDEV-30334 or MDEV-30349: ".$w->[1]." ".$w->[2]."\nQuery [ $orig_query ]");
            $known_issues_count++;
            return STATUS_IGNORED_ERROR;
          }
          elsif ($w->[1] == 4038 && $trace =~ /: \"[^\"]*\`[^\`\\]*\"/) {
            sayWarning("Optimizer trace produced invalid JSON, assuming MDEV-30354: ".$w->[1]." ".$w->[2]."\nQuery [ $orig_query ]");
            $known_issues_count++;
            return STATUS_IGNORED_ERROR;
          }
          elsif ($w->[1] == 4037 && $query eq '') {
            sayWarning("Optimizer trace produced empty JSON, assuming MDEV-30356: ".$w->[1]." ".$w->[2]."\nQuery [ $orig_query ]");
            $known_issues_count++;
            return STATUS_IGNORED_ERROR;
          }
        }
      }
      $invalid_traces_count++;
      sayError("Optimizer trace produced invald JSON: $trace\n".($warnings_text ?  "\n$warnings_text" : "")."\nQuery [ $orig_query ]");
      return STATUS_DATABASE_CORRUPTION;
    }

    $valid_traces_count++;
    return STATUS_OK;
}


sub DESTROY {
  if ($have_opt_trace) {
    say("$thisFile statistics: ".
        "valid JSON trace: $valid_traces_count, ".
        "missing bytes: $missing_bytes_count, ".
        "known issues: $known_issues_count, ".
        "invalid JSON trace: $invalid_traces_count, ".
        "no JSON trace: $no_traces_count, ".
        "skipped: $skipped_count"
    );
  }
}

1;
