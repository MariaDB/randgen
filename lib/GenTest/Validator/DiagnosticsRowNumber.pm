# Copyright (C) 2021, 2023, MariaDB
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

package GenTest::Validator::DiagnosticsRowNumber;

require Exporter;
@ISA = qw(GenTest::Validator GenTest);

use strict;

use GenUtil;
use GenTest;
use GenTest::Comparator;
use Constants;
use GenTest::Result;
use GenTest::Validator;
use Data::Dumper;

sub validate {
  my ($validator, $executors, $results) = @_;
  my $conn= $executors->[0]->connection;
  foreach my $result (@$results) {
    my $warnings= $result->warnings();
    next unless $warnings && scalar(@$warnings);
    my $query= $result->query();
    my $query_id= 'N/A';
    next if $query =~ /(?:GET.*DIAGNOSTICS|SHOW.*WARNINGS|SHOW.*ERRORS)/;
    if ($query =~ /(QNO \d+ CON_ID \d+)/) {
      $query_id= $1;
    }
    $query=~ s/^\s*(\w+).*/$1/;
    my $number_of_conditions= scalar(@$warnings);
    # <errno>-<zero|one|other> => count
    my %rnums_by_error= ();
    my %rmsgs_by_error= ();
    my %errors= ();
    # Text message example by error
    my %msg_examples= ();
    foreach my $w (0..$number_of_conditions-1) {
      my ($errno, $errtext)= ($warnings->[$w]->[1], $warnings->[$w]->[2]);
      $errors{$errno}= (defined $errors{$errno} ? $errors{$errno}+1 : 1);
      $msg_examples{$errno}= $errtext unless defined $msg_examples{$errno};
      my $cond= $w + 1;
      $conn->execute("GET DIAGNOSTICS CONDITION $cond \@rn = ROW_NUMBER");
      if ($conn->err) {
        say("ERROR: Couldn't retrieve ROW_NUMBER: ".$conn->print_error);
        exit STATUS_ENVIRONMENT_FAILURE;
      }
      my $rnum= $conn->get_value('SELECT @rn');
      if (not defined $rnum or $rnum eq '') {
        say("ERROR: Undefined rownum for query ".$result->query." Warning: @{$warnings->[$w]}");
        print Dumper $results;
        exit STATUS_CRITICAL_FAILURE;
      }
      if ($rnum == 0) {
        $rnums_by_error{$errno.'-zero'}= ($rnums_by_error{$errno.'-zero'} ? $rnums_by_error{$errno.'-zero'}+1 : 1);
      }
      elsif ($rnum == 1) {
        $rnums_by_error{$errno.'-one'}= ($rnums_by_error{$errno.'-one'} ? $rnums_by_error{$errno.'-one'}+1 : 1);
      }
      elsif ($rnum > 1) {
        $rnums_by_error{$errno.'-other'}= ($rnums_by_error{$errno.'-other'} ? $rnums_by_error{$errno.'-other'}+1 : 1);
      }
      else {
        sayError("Unexpected row number: $rnum");
        exit STATUS_CRITICAL_FAILURE;
      }
      say("For query [ ".$result->query." ], condition $cond, errno $errno, diagnostics row number $rnum text message $errtext");

      if ($errtext =~ /at row (\d+)$/ or $errtext =~ /Row (\d+)/) {
        my $textnum= $1;

        if ($textnum == 0) {
          $rmsgs_by_error{$errno.'-zero'}= ($rmsgs_by_error{$errno.'-zero'} ? $rmsgs_by_error{$errno.'-zero'}+1 : 1);
        }
        elsif ($textnum == 1) {
          $rmsgs_by_error{$errno.'-one'}= ($rmsgs_by_error{$errno.'-one'} ? $rmsgs_by_error{$errno.'-one'}+1 : 1);
        }
        elsif ($textnum > 1) {
          $rmsgs_by_error{$errno.'-other'}= ($rmsgs_by_error{$errno.'-other'} ? $rmsgs_by_error{$errno.'-other'}+1 : 1);
        }
        else {
          sayError("Unexpected row number: $textnum");
          exit STATUS_CRITICAL_FAILURE;
        }

        if ($rnum != $textnum) {
          if ($errno == 1260) {
            say("WARNING: MDEV-26848 On query [ ".$result->query." ], condition $cond, errno $errno, diagnostics row number $rnum is not the same as in the error message $errtext");
          } else {
            say("ERROR: For query [ ".$result->query." ], condition $cond, errno $errno, diagnostics row number $rnum is not the same as in the error message $errtext");
            exit STATUS_CRITICAL_FAILURE;
          }
        }
#        else {
#          say("For query $query ($query_id), condition $cond, errno $errno: diagnostics row number $rnum is the same as in the error message $errtext");
#        }
      }
#      else {
#        say("For query $query ($query_id), condition $cond, errno $errno: row number $rnum, text does not define any: $errtext");
#      }
#print Dumper $rnum;
    }
    say("DiagnosticsRowNumber: Statistics for query [ ".$result->query." ]");
    foreach my $e (sort {$a<=>$b} keys %errors) {
      say("DiagnosticsRowNumber: Query type: $query, error: $e, number of conditions: $errors{$e}, row number 0: ".($rnums_by_error{"$e-zero"} || 0).", row number 1: ".($rnums_by_error{"$e-one"} || 0).", row number x: ".($rnums_by_error{"$e-other"} || 0));
      if (defined $rmsgs_by_error{"$e-zero"} or defined $rmsgs_by_error{"$e-one"} or defined $rmsgs_by_error{"$e-other"}) {
        say("DiagnosticsRowNumber: Query type: $query, error: $e, row number appeared in text messages");
      } else {
        say("DiagnosticsRowNumber: Query type: $query, error: $e, row number did not appear in text messages");
      }
      say("DiagnosticsRowNumber: Query type: $query, error: $e, text message example: [ $msg_examples{$e} ]");
    }
  }
  return STATUS_OK;
  say("Result:");
  print Dumper $results;
  say("Warnings:");
  print Dumper $results->[0]->warnings();
  return STATUS_OK;
  $| = 1;
  my $executor = $executors->[0];
  my $result = $results->[0];
  my $query = $result->query();
  return STATUS_OK if $query !~ m{validate\s+(\d+)\s*(\S+)\s*(.+?)\s+for\s+row\s+(\d+|all)}io;
  my ($pos, $sign, $value, $row) = ($1, $2, $3, lc($4));

  my @rownums = ();
  unless ( $result and $result->data() ) {
    say("Warning: Query in CheckFieldValue didn't return a result: $query");
    return STATUS_OK;
  }
  if ( $row eq 'all' ) {
    foreach ( 0..$#{$result->data()} )
    {
      push @rownums, $_;
    }
  }
  else {
    @rownums = ( $row - 1 );
  }

  foreach my $r ( @rownums )
  {
    my $val = $result->data()->[$r]->[$pos-1];
    if ( ( ( $sign eq '=' or $sign eq '==' ) and not ( $val eq $value ) )
      or ( ( $sign eq '!=' or $sign eq '<>' ) and ( $val eq $value ) )
      or ( ( $sign eq '<' ) and not ( $val < $value ) )
      or ( ( $sign eq '>' ) and not ( $val > $value ) )
      or ( ( $sign eq '<=' ) and not ( $val <= $value ) )
      or ( ( $sign eq '>=' ) and not ( $val >= $value ) )
      or ( ( $sign eq '~' or ( $sign eq '=~') ) and not ( $val =~ /$value/ ) )
      or ( ( $sign eq '!~' ) and ( $val =~ /$value/ ) )
    )
    {
      say("ERROR: For query \'$query\' on row " . ( $r + 1 ) . " result " . $val . " does not meet the condition $sign $value");
      my $rowset = '';
      foreach my $i ( 0..$#{$result->data()->[$row-1]} )
      {
        $rowset .= " [" . ($i + 1 ) . "] : " . $result->data()->[$r]->[$i] . ";";
      }
      say("Full row:$rowset");
      return STATUS_REQUIREMENT_UNMET;
    }
  }
  return STATUS_OK;
}

1;
