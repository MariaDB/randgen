# Copyright (c) 2008,2012 Oracle and/or its affiliates. All rights reserved.
# Use is subject to license terms.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2020, 2023 MariaDB
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

package GenTest::Executor::MRDB;

require Exporter;

@ISA = qw(GenTest::Executor);

use strict;
use Carp;
use Data::Dumper;
use GenUtil;
use GenTest;
use Constants;
use Constants::MariaDBErrorCodes;
use GenTest::Result;
use GenTest::Executor;
use Time::HiRes;
use Digest::MD5;
use GenTest::Random;

sub admin {
  my $executor= shift;
  $executor->execute("/*!100005 SET ROLE admin */");
  $executor->execute("/*!100001 SET SESSION tx_read_only= OFF */");
}

sub connection {
  return $_[0]->[EXECUTOR_CONNECTION];
}

sub connect {
  my ($executor,$user,$pass)= @_;
  my ($conn, $err) = Connection::Perl->new(
    server => $executor->server,
    name => 'WRK-'.$executor->threadId(),
    user => $user,
    password => $pass
  );
  unless ($conn) {
      sayDebug("Connection WRK-".$executor->threadId()." to port ".$executor->server->port()." failed with error $err");
  }
  return $conn;
}

sub init {
    my $executor = shift;

    my $conn= $executor->connect();
    unless (defined $conn) {
      return STATUS_ENVIRONMENT_FAILURE;
    }
    $executor->[EXECUTOR_CONNECTION]= $conn;
    $executor->defaultSchema($executor->currentSchema());

    my $cid= $conn->get_value("SELECT CONNECTION_ID()");
    if ($conn->err) {
        sayError("Couldn't get connection ID: " . $conn->print_error);
    }

    $executor->setConnectionId($cid);
    $executor->user($conn->get_value("SELECT CURRENT_USER()"));
    $conn->execute('SELECT '.GenTest::Random::dataLocation().' AS DATA_LOCATION');

    sayDebug("Executor initialized. id: ".$executor->id()."; default schema: ".$executor->defaultSchema()."; thread ID: ".$executor->threadId()."; connection ID: ".$executor->connectionId());

    return STATUS_OK;
}

sub execute {
    my ($executor, $query, $execution_flags) = @_;
    $execution_flags= 0 unless defined $execution_flags;

    # Check for execution flags in query comments. They can, for example,
    # indicate that a query is for service purposes and doesn't need
    # to be included into statistics
    # The format for it is /* EXECUTOR_FLAG_SKIP_STATS */

    # Add global flags if any are set
    $execution_flags = $execution_flags | $executor->flags();

    if ($query =~ s/EXECUTOR_FLAG_SKIP_STATS//g) {
        $execution_flags |= EXECUTOR_FLAG_SKIP_STATS;
    }
    if ($query =~ s/EXECUTOR_FLAG_NON_EXISTING_ALLOWED//g) {
        $execution_flags |= EXECUTOR_FLAG_NON_EXISTING_ALLOWED;
    }

    if ($query =~ /\!non_existing_(?:database|object|index)/) {
      my $errtype= STATUS_REQUIREMENT_UNMET;
      if ($execution_flags & EXECUTOR_FLAG_NON_EXISTING_ALLOWED) {
        sayDebug("Discarding query [ $query ]");
      } else {
        sayError("Discarding query [ $query ] and setting STATUS_REQUIREMENT_UNMET");
      }
      $executor->[EXECUTOR_STATUS_COUNTS]->{$errtype}++;
      return GenTest::Result->new(
            query      => $query,
            status     => $errtype,
            err        => undef,
            errstr     => "Internal error, required object not found",
            sqlstate   => undef,
            start_time => undef,
            end_time   => undef,
            execution_flags => $execution_flags
      );
    }

    if ($query =~ /^\s*(?:\/\*.*?\*\/\s*)?USE\s*(?:\/\*.*?\*\/\s*)?(\`[^\`]+\`|\w+)/) {
      $executor->currentSchema($1);
    }

    # Filter out any /*executor */ comments that do not pertain to this particular Executor/DBI
    if (index($query, 'executor') > -1) {
        my $executor_id = $executor->id();
        $query =~ s{/\*executor$executor_id (.*?) \*/}{$1}sg;
        $query =~ s{/\*executor.*?\*/}{}sgo;
    }

    # Due to use of empty rules in stored procedure bodies and alike,
    # the query can have a sequence of semicolons "; ;" or "BEGIN ; ..."
    # which will cause syntax error. We'll clean them up
    while ($query =~ s/^\s*;//gs) {}
    while ($query =~ s/;\s*;/;/gs) {}
    while ($query =~ s/(PROCEDURE.*)BEGIN\s*;/${1}BEGIN /g) {}
    # Or occasionaly "x AS alias1 AS alias2"
    while ($query =~ s/AS\s+\w+\s+(AS\s+\w+)/$1/g) {}

    my $conn = $executor->connection();
    return GenTest::Result->new( query => $query, status => STATUS_SERVER_UNAVAILABLE, execution_flags => $execution_flags ) if not defined $conn;

    my $trace_query;
    my $trace_me = 0;

    # Write query to log before execution so it's sure to get there
    if ($executor->sqltrace) {
        if ($query =~ m{(procedure|function)}sgio) {
            $trace_query = "DELIMITER |\n$query|\nDELIMITER ";
        } else {
            $trace_query = $query;
        }
        # MarkErrors logging can only be done post-execution
        if ($executor->sqltrace eq 'MarkErrors') {
            $trace_me = 1;   # Defer logging
        } else {
            print "$trace_query;\n";
        }
    }

    my $resultset= $conn->query($query);
    my $execution_time = $conn->execution_time();
    my $affected_rows= $conn->affected_rows();
    my ($err,$errstr) = $conn->last_error;
    my $err_type = errorType($err);

    $executor->[EXECUTOR_STATUS_COUNTS]->{$conn->err_type}++ unless ($execution_flags & EXECUTOR_FLAG_SKIP_STATS);

    my $mysql_info = $conn->mysql_info;
    my ($matched_rows, $changed_rows) = $mysql_info =~ m{^Rows matched:\s+(\d+)\s+Changed:\s+(\d+)}sgio;

    my ($column_names,$column_types);
    if ($conn && $conn->number_of_fields) {
      $column_names = $conn->column_names;
      $column_types = $conn->column_types;
    }

    if ($trace_me eq 1) {
      if ($err) {
        # Mark invalid queries in the trace by prefixing each line.
        # We need to prefix all lines of multi-line statements also.
        $trace_query =~ s/\n/\n# [sqltrace]    /g;
        print "# [$$] [sqltrace] ERROR ".$err.": $trace_query;\n";
      } else {
        print "[$$] $trace_query;\n";
      }
    }

    # We add an empty data here because DELETE RETURNING and such
    # may return undefined NUM_OF_FIELDS, particularly when the resultset is empty,
    # but we still want it to be processed as something returning a resultset
    # (because it is). Hopefully it won't hurt
    my $result = GenTest::Result->new(
        query           => $query,
        status          => $err_type,
        err             => $err,
        errstr          => $errstr,
        sqlstate        => $conn->sqlstate(),
        execution_flags => $execution_flags,
        data            => ( $query =~ /\WRETURNING\W/i ? [] : \@$resultset ),
        affected_rows   => $affected_rows,
        matched_rows    => $matched_rows,
        changed_rows    => $changed_rows,
        info            => $mysql_info,
        column_names    => $column_names,
        column_types    => $column_types,
    );

    if (($err or $conn->warning_count() > 0) and not serverGone($err_type)) {
      my $warnings = $conn->query("SHOW WARNINGS");
      $result->setWarnings($warnings);
    }
    return $result;
}

sub loadCollations {
    ## Return the result from a query with the following columns:
    ## 1. Collation name
    ## 2. Character set
    my ($self, $file) = @_;

    unless (open(COLL,$file)) {
      sayError("Couldn't open collations dump $file: $!");
      return undef;
    }
    my @collations=();
    while (<COLL>) {
      chomp;
      my ($coll, $cs)= split /;/, $_;
      # TODO: maybe better solution
      if (($cs eq '\N' or $cs eq '') and ($coll =~ /^uca1400/)) {
        $cs= 'utf8mb3';
      }
      push @collations, [$coll, $cs];
    }
    close(COLL);
    return \@collations;
}

sub loadTimezones {
    ## Return the result from a query with the following columns:
    ## 1. Timezone name
    my ($self, $file) = @_;

    unless (open(TZ,$file)) {
      sayError("Couldn't open timezone dump $file: $!");
      return undef;
    }
    my @timezones=();
    while (<TZ>) {
      chomp;
      push @timezones, [$_];
    }
    close(TZ);
    return \@timezones;
}

sub read_only {
    my $executor = shift;
    my ($grant_command) = $executor->connection->get_row("SHOW GRANTS FOR CURRENT_USER()");
    my ($grants) = $grant_command =~ m{^grant (.*?) on}is;
    if (uc($grants) eq 'SELECT') {
        return 1;
    } else {
        return 0;
    }
}

# Assuming for now that engines (interesting ones) are loaded at the beginning
sub engines {
  my $self= shift;
  unless ($self->[EXECUTOR_ENGINES]) {
    my $engines= $self->connection->get_column("select engine from information_schema.engines where support in ('YES','DEFAULT')");
    if ($engines) {
      $self->[EXECUTOR_ENGINES]= [ @$engines ];
    }
  }
  return $self->[EXECUTOR_ENGINES];
}

1;
