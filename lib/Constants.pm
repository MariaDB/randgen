# Copyright (c) 2008,2011 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013 Monty Program Ab.
# Copyright (c) 2021, 2022 MariaDB Corporation Ab
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

package Constants;

use Carp;

require Exporter;

@ISA = qw(Exporter);

@EXPORT = qw(
  STATUS_OK
  STATUS_INTERNAL_ERROR
  STATUS_UNKNOWN_ERROR
  STATUS_SERVER_STOPPED
  STATUS_TEST_STOPPED
  STATUS_ENVIRONMENT_FAILURE
  STATUS_PERL_FAILURE
  STATUS_CUSTOM_OUTCOME
  STATUS_WONT_HANDLE
  STATUS_SKIP
  STATUS_IGNORED_ERROR
  STATUS_UNSUPPORTED
  STATUS_SYNTAX_ERROR
  STATUS_SEMANTIC_ERROR
  STATUS_RUNTIME_ERROR
  STATUS_CONTEXT_ERROR
  STATUS_ACL_ERROR
  STATUS_CONFIGURATION_ERROR
  STATUS_TEST_FAILURE
  STATUS_REQUIREMENT_UNMET
  STATUS_ERROR_MISMATCH
  STATUS_LENGTH_MISMATCH
  STATUS_CONTENT_MISMATCH
  STATUS_POSSIBLE_FAILURE
  STATUS_ERRORS_IN_LOG
  STATUS_CRITICAL_FAILURE
  STATUS_SERVER_UNAVAILABLE
  STATUS_SERVER_CRASHED
  STATUS_REPLICATION_FAILURE
  STATUS_BACKUP_FAILURE
  STATUS_RECOVERY_FAILURE
  STATUS_UPGRADE_FAILURE
  STATUS_OUT_OF_MEMORY
  STATUS_DATABASE_CORRUPTION
  STATUS_SERVER_DEADLOCKED
  STATUS_SERVER_SHUTDOWN_FAILURE
  STATUS_VALGRIND_FAILURE
  STATUS_MEMORY_LEAK
  STATUS_SERVER_STARTUP_FAILURE
  STATUS_ALARM

  constant2text
  status2text
  serverGone
);

use strict;

use constant STATUS_OK                       =>  0; ## Suitable for exit code

use constant STATUS_INTERNAL_ERROR           =>  1;   # Apparently seen with certain Perl coding errors; check RQG log carefully for exact error
use constant STATUS_UNKNOWN_ERROR            =>  2;

use constant STATUS_SERVER_STOPPED            => 3; # Willfull killing of the server, will not be reported as a crash
use constant STATUS_TEST_STOPPED             =>  4; # A module requested that the test is terminated without failure

use constant STATUS_WONT_HANDLE              =>  5; # A module, e.g. a Validator refuses to handle certain query
use constant STATUS_SKIP                     =>  6; # A Filter specifies that the query should not be processed further
use constant STATUS_IGNORED_ERROR            => 19; # Most likely a real error (maybe even important), but due to amount of known bugs or false positives it is untreatable

use constant STATUS_REQUIREMENT_UNMET        => 20; # Errors which the executor produces itself without sending a query to the server, when a required object not found

use constant STATUS_UNSUPPORTED              => 21; # Error codes caused by certain functionality recognized as unsupported (NOT syntax errors)
# Distinction between "semantic" and "runtime" errors is quite arbitrary.
# In most general terms, "semantic" errors are those which happen due
# to inaccuracies of random data/query generation and should be
# preferably avoided, while "runtime" errors are those which will
# inevitably happen in random testing and have to be tolerated.
# However, there is a big overlap between the two
use constant STATUS_SEMANTIC_ERROR           => 22; # Errors caused by the randomness of the test, e.g. dropping a non-existing table
use constant STATUS_CONFIGURATION_ERROR      => 23; # Missing engines, wrong startup options, etc, a special kind of semantic errors
use constant STATUS_RUNTIME_ERROR            => 24; # Lock wait timeouts, deadlocks, duplicate keys, etc.
use constant STATUS_ACL_ERROR                => 25; # Access denied etc., a special kind of runtime errors
use constant STATUS_SYNTAX_ERROR             => 26; # General parsing errors and specific errors indicating wrong syntax

use constant STATUS_TEST_FAILURE             => 30; # Boundary between genuine errors and false positives due to randomness

use constant STATUS_POSSIBLE_FAILURE         => 35;

use constant STATUS_ERROR_MISMATCH           => 41; # A DML statement caused those errors, and the test can not continue
use constant STATUS_LENGTH_MISMATCH          => 42; # because the databases are in an unknown inconsistent state
use constant STATUS_CONTENT_MISMATCH         => 43;

use constant STATUS_CUSTOM_OUTCOME           => 50; # Used for things such as signaling an EXPLAIN hit from the ExplainMatch Validator
use constant STATUS_ERRORS_IN_LOG            => 70; # Set errors are found in the error log (other than ignorable ones)

use constant STATUS_SERVER_SHUTDOWN_FAILURE  => 90;
use constant STATUS_OUT_OF_MEMORY            => 95; # Various non-fatal out-of-memory errors
use constant STATUS_DATABASE_CORRUPTION      => 96; # Database corruption errors are often bogus, but still important to look at

# Critical errors cause premature test termination

use constant STATUS_CRITICAL_FAILURE         => 100; # Boundary between critical and non-critical errors

use constant STATUS_SERVER_UNAVAILABLE       => 102; # Cannot connect to the server without a known reason
use constant STATUS_SERVER_DEADLOCKED        => 103;
use constant STATUS_REPLICATION_FAILURE      => 104;
use constant STATUS_UPGRADE_FAILURE          => 105;
use constant STATUS_RECOVERY_FAILURE         => 106;
use constant STATUS_BACKUP_FAILURE           => 107;
use constant STATUS_VALGRIND_FAILURE         => 108;
use constant STATUS_MEMORY_LEAK              => 109;
use constant STATUS_SERVER_CRASHED           => 110;
use constant STATUS_SERVER_STARTUP_FAILURE   => 111;
use constant STATUS_ENVIRONMENT_FAILURE      => 112; # A failure in the environment or the grammar file
use constant STATUS_ALARM                    => 113; # A module, e.g. a Reporter, raises an alarm with critical severity

use constant STATUS_PERL_FAILURE             => 255; # Perl died for some reason

#
# The part below deals with constant value to constant name conversions
#


my %text2value;

sub BEGIN {

  # What we do here is open the Constants.pm file and parse the 'use constant' lines from it
  # The regexp is faily hairy in order to be more permissive.

  open (CONSTFILE, __FILE__) or croak "Unable to read constants from ".__FILE__;
  read(CONSTFILE, my $constants_text, -s __FILE__);
  %text2value = $constants_text =~ m{^\s*use\s+constant\s+([A-Z_0-9]*?)\s*=>\s*(\d+)\s*;}mgio;
}

sub constant2text {
  my ($constant_value, $prefix) = @_;

  foreach my $constant_text (keys %text2value) {
    return $constant_text if $text2value{$constant_text} == $constant_value && $constant_text =~ m{^$prefix}si;
  }
  carp "Unable to obtain constant text for constant_value = $constant_value; prefix = $prefix";
  return undef;
}

sub status2text {
  return constant2text($_[0], 'STATUS_');
}

# Collection of status values meaning that the server disappeared
sub serverGone {
  my $status= shift;
  return $status == STATUS_SERVER_CRASHED
      || $status == STATUS_SERVER_STOPPED
      || $status == STATUS_SERVER_UNAVAILABLE;
}

1;
