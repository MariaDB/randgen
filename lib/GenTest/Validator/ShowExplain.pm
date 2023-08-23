# Copyright (C) 2013 Monty Program Ab
# Copyright (c) 2022, 2023 MariaDB
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


# Validator for SHOW EXPLAIN feature introduced in MariaDB 10.0.
# See MDEV-165 / MWL#182 Explain running statements
# http://askmonty.org/worklog/Server-RawIdeaBin/?tid=182
# https://kb.askmonty.org/en/show-explain/

package GenTest::Validator::ShowExplain;

require Exporter;
@ISA = qw(GenTest::Validator GenTest);

use strict;

use GenUtil;
use GenTest;
use GenTest::Comparator;
use Constants;
use GenTest::Result;
use GenTest::Validator;
use GenTest::Executor;
use Connection::Perl;
use Time::HiRes;
use POSIX;
use Data::Dumper;

my $child_conn;
my $child_con_id;

# On the first validate call, we open a spare connection and keep it open.
#
# On each validate call, we pick up a SELECT which has already been executed,
# run EXPLAIN on it in the spare connection and store the result.
# Then we fork a separate child process and run the SELECT in it using
# the same spare connection, while the parent runs SHOW EXPLAIN FOR that connection
# repeatedly in parallel in the normal executor connection, collecting results.
# When SELECT finishes, the child process exits, the parent notices it
# and stops running SHOW EXPLAIN. After that the parent compares results
# of SHOW EXPLAIN with the normal EXPLAIN output. Certain expected mismatches
# are ignored, otherwise STATUS_CONTENT_MISMATCH or STATUS_LENGTH_MISMATCH
# is returned if there are differences.
#

sub validate {
  my ($validator, $executors, $results) = @_;
  return STATUS_WONT_HANDLE if $results->[0]->status() != STATUS_OK;
  my $executor = $executors->[0];
  my $query = $results->[0]->query();

  return STATUS_OK if $query !~ m{^\s*select}io;

  my $db= $executor->connection->get_value("SELECT DATABASE()");

  unless ($child_conn)
  {
    $child_conn = Connection::Perl->new(server => $executor->server, role => 'super', name => 'SHX' );
    unless ($child_conn)
    {
      say("ERROR: Could not create child connection in ShowExplain");
      return STATUS_ENVIRONMENT_FAILURE;
    }
  }
  if ($db ne 'NULL') {
    $child_conn->execute("USE $db");
  } 
  my $native_explain = $child_conn->query("EXPLAIN $query");
  if ($child_conn->err)
  {
    say("Warning: EXPLAIN did not return anything for $query: " . $child_conn->print_error);
    return STATUS_WONT_HANDLE;
  }
  unless ($child_con_id)
  {
    $child_con_id = $child_conn->get_value("SELECT CONNECTION_ID()");
    if ($child_conn->err)
    {
      say("ERROR: Could not find out child connection ID in ShowExplain: " . $child_conn->print_error);
      return STATUS_ENVIRONMENT_FAILURE;
    }
  }

  my $pid = fork();
  unless (defined $pid)
  {
    say("Could not fork for ShowExplain");
    return STATUS_ENVIRONMENT_FAILURE;
  }
  if ($pid)
  {
    # Parent
    my @show_explains = ();
    do
    {
      my $res = $executor->connection->query("SHOW EXPLAIN FOR $child_con_id");
      push @show_explains, $res unless $executor->connection()->err;
      waitpid($pid, WNOHANG);
    }
    while ( $? < 0 and Time::HiRes::sleep(0.1) );

    my @native_explain_rows = ();
    foreach (@$native_explain)
    {
      push @native_explain_rows, "@$_";
    }
    my $e = 0;
    sayDebug("Got ".scalar(@show_explains)." SHOW EXPLAIN results for query [ $query ]");
    foreach (@show_explains)
    {
      $e++;
      my $expl = $_;
      my $length_differs = ( scalar(@$expl) != scalar(@native_explain_rows) );
      foreach my $i (0..$#$expl)
      {
        my @show_row = @{$expl->[$i]};
        my @native_row = @{$native_explain->[$i]};
        remove_expected_diffs(\@show_row);
        remove_expected_diffs(\@native_row);
        if ("@show_row" ne "@native_row")
        {
          if ( $show_row[9] =~ /Query plan already deleted/ )
          {
            sayDebug("SHOW EXPLAIN output contains row 'Query plan already deleted'");
            ( $length_differs ? last : next );
          }
          my $err_description = '';
          if ($native_row[0] ne $show_row[0]) {
            $err_description .= "; Level differs ('$native_row[0]' vs '$show_row[0]')";
          }
          if ($native_row[1] ne $show_row[1]) {
            $err_description .= "; select_type differs ('$native_row[1]' vs '$show_row[1]')";
          }
          if ($native_row[2] ne $show_row[2]) {
            $err_description .= "; table name differs";
          }
          if ($native_row[3] ne $show_row[3]) {
            $err_description .= "; join type differs ('$native_row[3]' vs '$show_row[3]')";
          }
          if ($native_row[4] ne $show_row[4]) {
            $err_description .= "; possible keys differ";
          }
          if ($native_row[5] ne $show_row[5]) {
            $err_description .= "; key differs";
          }
          if ($native_row[6] ne $show_row[6]) {
            $err_description .= "; key length differs";
          }
          if ($native_row[7] ne $show_row[7]) {
            $err_description .= "; ref differs";
          }
          if ($native_row[8] ne $show_row[8]) {
            $err_description .= "; row counts differ";
          }
          if ($native_row[9] ne $show_row[9]) {
            $err_description .= "; extra field differs ('$native_row[9]' vs '$show_row[9]')";
          }
          my $exit_code = ( $length_differs ? STATUS_LENGTH_MISMATCH : STATUS_CONTENT_MISMATCH );
          say("Query: $query failed with " . constant2text($exit_code) . ", output of EXPLAIN and SHOW EXPLAIN #$e do not match in row " . ($i+1) . "$err_description:");
          say("Native EXPLAIN:");
          print_explain($native_explain);
          say("SHOW EXPLAIN:");
          print_explain($expl);
          return $exit_code;
        }
      }
    }
  }
  else
  {
    $child_conn->execute($query);
    $child_conn->disconnect();
    # To avoid executor printing information
    kill('KILL',$$);
  }
  return STATUS_OK;
}

sub print_explain {
  my $explain_ref = shift;
  my $i = 0;
  foreach ( @$explain_ref )
  {
    $i++;
    say("  #$i# @$_");
  }
}

# There are some documented differences in SHOW EXPLAIN and EXPLAIN output,
# they should be ignored to avoid false positives.

sub remove_expected_diffs {
  my $rowref = shift;
  if ( $rowref->[1] eq 'SIMPLE' or $rowref->[1] eq 'PRIMARY' )
  {
    $rowref->[1] = '<SIMPLE/PRIMARY>'
  }

  if ( ( ( $rowref->[1] eq 'SUBQUERY' or $rowref->[1] eq 'DEPENDENT SUBQUERY' )
        and $rowref->[9] =~ /Impossible WHERE noticed after reading const tables/ )
      or ( ( $rowref->[1] eq 'DEPENDENT SUBQUERY' and $rowref->[9] =~ /no matching row in const table/ ) ) )
  {
    $rowref->[1] = '<[DEPENDENT] SUBQUERY>'
  }
  $rowref->[9] =~ s/Impossible WHERE noticed after reading const tables/<Impossible WHERE in const tables>/;
  $rowref->[9] =~ s/no matching row in const table/<Impossible WHERE in const tables>/;
}

1;
