# Copyright (C) 2008-2009 Sun Microsystems, Inc. All rights reserved.
# Copyright (c) 2021,2022 MariaDB Corporation
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

package GenTest::ReporterManager;

@ISA = qw(GenTest);

use strict;
use GenUtil;
use GenTest;
use Constants;
use GenTest::Reporter;

use constant MANAGER_REPORTERS    => 0;
1;

sub new {
  my $class = shift;
  my $manager = $class->SUPER::new({
    reporters => MANAGER_REPORTERS
  }, @_);

  $manager->[MANAGER_REPORTERS] = [];

  return $manager;
}

sub monitor {
  my ($manager, $desired_type) = @_;

  my $max_result = STATUS_OK;

  REPORTER:
  foreach my $reporter (@{$manager->reporters()}) {
    next if isOlderVersion($reporter->server->version(),$reporter->compatibility);
    if ($reporter->type() & $desired_type) {
      my $reporter_result = STATUS_OK;
      sayDebug("ReporterManager: calling monitor for ".(ref $reporter));
      eval {
        $reporter_result = $reporter->monitor();
        1;
      };
      sayWarning("Reporter ".(ref $reporter)." returned ".status2text($reporter_result)) if $reporter_result != STATUS_OK;
      $reporter_result= STATUS_OK if $reporter_result == STATUS_SKIP;
      if (serverGone($reporter_result))
      {
        my $status= $reporter->server->waitPlannedDowntime();
        if ($status == STATUS_OK) {
          say("ReporterManager: Server returned in time, continuing monitoring");
          redo REPORTER;
        } elsif ($status == STATUS_SERVER_STOPPED) {
          sayError("ReporterManager: instructed not to wait");
          $max_result= STATUS_TEST_STOPPED if $max_result < STATUS_TEST_STOPPED;
          return $max_result;
        } else {
          sayError("ReporterManager: Server has gone away");
          return STATUS_SERVER_UNAVAILABLE;
        }
      } elsif ($reporter_result <= STATUS_TEST_FAILURE) {
        $reporter_result= STATUS_OK;
      }
      $max_result = $reporter_result if $reporter_result > $max_result;
    }
  }
  return $max_result;
}

sub report {
  my ($manager, $desired_type) = @_;

  my $max_result = STATUS_OK;

  foreach my $reporter (@{$manager->reporters()}) {
    next if isOlderVersion($reporter->server->version(),$reporter->compatibility);
    if ($reporter->type() & $desired_type) {
      my @reporter_results = $reporter->report();
      my $reporter_result = shift @reporter_results;
      $max_result = $reporter_result if $reporter_result > $max_result;
    }
  }
  return $max_result;
}

sub addReporter {
  my ($manager, $reporter, $params) = @_;

  if (ref($reporter) eq '') {
    my $module = "GenTest::Reporter::".$reporter;
    eval "use $module" or print $@;
    $reporter = $module->new(%$params);
    if (not defined $reporter) {
        sayError("Reporter could not be added. Status will be set to ENVIRONMENT_FAILURE");
        return STATUS_ENVIRONMENT_FAILURE;
    }
    if (not $reporter->init() == STATUS_OK) {
      return STATUS_ENVIRONMENT_FAILURE;
    }
  }

  push @{$manager->[MANAGER_REPORTERS]}, $reporter;
  return STATUS_OK;
}

sub reporters {
  return $_[0]->[MANAGER_REPORTERS];
}

1;
