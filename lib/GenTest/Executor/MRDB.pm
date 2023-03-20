# Copyright (c) 2008,2012 Oracle and/or its affiliates. All rights reserved.
# Use is subject to license terms.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2020,2022 MariaDB Corporation
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
use DBI;
use GenUtil;
use GenTest;
use Constants;
use Constants::MariaDBErrorCodes;
use GenTest::Result;
use GenTest::Executor;
use Time::HiRes;
use Digest::MD5;
use GenTest::Random;

#
# Column positions for SHOW SLAVES
#

use constant SLAVE_INFO_HOST => 1;
use constant SLAVE_INFO_PORT => 2;


sub admin {
  my $executor= shift;
  $executor->execute("SET ROLE admin");
}

sub init {
    my $executor = shift;
    my $dbh = DBI->connect($executor->dsn(), undef, undef, {
        PrintError => 0,
        RaiseError => 0,
        AutoCommit => 1,
        mysql_multi_statements => 1,
        mysql_auto_reconnect => 1
    } );

    if (not defined $dbh) {
        sayError("connect() to dsn ".$executor->dsn()." failed: ".$DBI::errstr);
        return STATUS_ENVIRONMENT_FAILURE;
    }

    $executor->setDbh($dbh);

    my $service_dbh = DBI->connect($executor->dsn(), undef, undef, {
        PrintError => 0,
        RaiseError => 0,
        AutoCommit => 1,
        mysql_multi_statements => 1,
        mysql_auto_reconnect => 1
    } );

    if (not defined $service_dbh) {
        sayError("connect() to dsn ".$executor->dsn()." (service connection) failed: ".$DBI::errstr);
        return STATUS_ENVIRONMENT_FAILURE;
    }

    $executor->setServiceDbh($service_dbh);

    #
    # Hack around bug 35676, optiimzer_switch must be set sesson-wide in order to have effect
    # So we read it from the GLOBAL_VARIABLE table and set it locally to the session
    # Please leave this statement on a single line, which allows easier correct parsing from general log.
    #

    $dbh->do("SET optimizer_switch=(SELECT variable_value FROM INFORMATION_SCHEMA.GLOBAL_VARIABLES WHERE VARIABLE_NAME='optimizer_switch')");
#    $dbh->do("SET TIMESTAMP=".Time::HiRes::time());

    $executor->defaultSchema($executor->currentSchema());

    my $cidref= $dbh->selectrow_arrayref("SELECT CONNECTION_ID()");
    if ($dbh->err) {
        sayError("Couldn't get connection ID: " . $dbh->err() . " (" . $dbh->errstr() .")");
    }

    $executor->setConnectionId($cidref->[0]);
    $executor->user($dbh->selectrow_arrayref("SELECT CURRENT_USER()")->[0]);
    $dbh->do('SELECT '.GenTest::Random::dataLocation().' AS DATA_LOCATION');

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
      if ($execution_flags & EXECUTOR_FLAG_NON_EXISTING_ALLOWED) {
        sayDebug("Discarding query [ $query ]");
        return GenTest::Result->new(
            query      => $query,
            status     => STATUS_SKIP,
            err        => undef,
            errstr     => "Internal error, required object not found",
            sqlstate   => undef,
            start_time => undef,
            end_time   => undef,
            execution_flags => $execution_flags
        );
      } else {
        sayError("Discarding query [ $query ] and setting STATUS_REQUIREMENT_UNMET");
        return GenTest::Result->new(
            query      => $query,
            status     => STATUS_REQUIREMENT_UNMET,
            err        => undef,
            errstr     => "Internal error, required object not found",
            sqlstate   => undef,
            start_time => undef,
            end_time   => undef,
            execution_flags => $execution_flags
        );
      }
    }

    if ($query =~ s/(TID \d+)(?:-\d+)? (QNO \d+-\d+)/$1-$executor->[EXECUTOR_QNO] $2/) {
      $executor->[EXECUTOR_QNO]++;
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

    my $dbh = $executor->dbh();

    return GenTest::Result->new( query => $query, status => STATUS_UNKNOWN_ERROR, execution_flags => $execution_flags ) if not defined $dbh;

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

    my $start_time = Time::HiRes::time();
    # Combination of mysql_server_prepare and mysql_multi_statements
    # still causes troubles (syntax errors), both with mysql and MariaDB drivers
    my $sth = (index($query,";") == -1) ? $dbh->prepare($query) : $dbh->prepare($query, { mysql_server_prepare => 0 });

    if (not defined $sth) {            # Error on PREPARE
        #my $errstr_prepare = normalizeError($dbh->errstr());
        return GenTest::Result->new(
            query        => $query,
            status        => errorType($dbh->err()),
            err        => $dbh->err(),
            errstr         => $dbh->errstr(),
            sqlstate    => $dbh->state(),
            start_time    => $start_time,
            end_time    => Time::HiRes::time(),
            execution_flags => $execution_flags
        );
    }

    my $affected_rows = $sth->execute();
    my $end_time = Time::HiRes::time();
    my $execution_time = $end_time - $start_time;

    my $err = $sth->err();
#    my $errstr = normalizeError($sth->errstr()) if defined $sth->errstr();
    my $errstr = $sth->errstr();
    my $err_type = STATUS_OK;
    if (defined $err) {
      $err_type= errorType($err);
      if ($err == ER_GET_ERRNO) {
          my ($se_err) = $sth->errstr() =~ m{^Got error\s+(\d+)\s+from storage engine}sgio;
      }
    }

    $executor->[EXECUTOR_STATUS_COUNTS]->{$err_type}++ unless ($execution_flags & EXECUTOR_FLAG_SKIP_STATS);

    my $mysql_info = $dbh->{'mysql_info'};
    $mysql_info= '' unless defined $mysql_info;
    my ($matched_rows, $changed_rows) = $mysql_info =~ m{^Rows matched:\s+(\d+)\s+Changed:\s+(\d+)}sgio;

    my $column_names = $sth->{NAME} if $sth and $sth->{NUM_OF_FIELDS};
    my $column_types = $sth->{mysql_type_name} if $sth and $sth->{NUM_OF_FIELDS};

    if ($trace_me eq 1) {
        if (defined $err) {
                # Mark invalid queries in the trace by prefixing each line.
                # We need to prefix all lines of multi-line statements also.
                $trace_query =~ s/\n/\n# [sqltrace]    /g;
                print "# [$$] [sqltrace] ERROR ".$err.": $trace_query;\n";
        } else {
            print "[$$] $trace_query;\n";
        }
    }

    my $result;
    if (defined $err)
    {  # Error on EXECUTE
        if (
            ($err_type == STATUS_SKIP) ||
            ($err_type == STATUS_UNSUPPORTED) ||
            ($err_type == STATUS_SEMANTIC_ERROR) ||
            ($err_type == STATUS_CONFIGURATION_ERROR) ||
            ($err_type == STATUS_ACL_ERROR) ||
            ($err_type == STATUS_IGNORED_ERROR) ||
            ($err_type == STATUS_RUNTIME_ERROR)
        ) {
            $executor->reportError($query, $err, $errstr, $execution_flags);
        } elsif (serverGone($err_type)) {
            $dbh = DBI->connect($executor->dsn(), undef, undef, {
                PrintError => 0,
                RaiseError => 0,
                AutoCommit => 1,
                mysql_multi_statements => 1,
                mysql_auto_reconnect => 1
            } );

            # If server is still connectable, it is not a real crash, but most likely a KILL query

            if (defined $dbh) {
                say("Executor::MariaDB::execute: Successfully reconnected after getting " . status2text($err_type));
                $err_type = STATUS_SEMANTIC_ERROR;
                $executor->setDbh($dbh);
            } else {
                sayError("Executor::MariaDB::execute: Failed to reconnect after getting " . status2text($err_type));
            }

            my $query_for_print= shorten_message($query);
            say("Executor::MariaDB::execute: Query: $query_for_print failed: $err ".$sth->errstr().($err_type?" (".status2text($err_type).")":""));
        } else {
            # Always print syntax and uncategorized errors, unless specifically asked not to
            my $query_for_print= shorten_message($query);
            say("Executor::MariaDB::execute: Query: $query_for_print failed: $err ".$sth->errstr().($err_type?" (".status2text($err_type).")":""));
        }
        $result = GenTest::Result->new(
            query        => $query,
            status        => $err_type || STATUS_UNKNOWN_ERROR,
            err        => $err,
            errstr        => $errstr,
            sqlstate    => $sth->state(),
            start_time    => $start_time,
            end_time    => $end_time,
            execution_flags => $execution_flags
        );
    } elsif ((not defined $sth->{NUM_OF_FIELDS}) || ($sth->{NUM_OF_FIELDS} == 0)) {
      # We add an empty data here because DELETE RETURNING and such
      # may return undefined NUM_OF_FIELDS, particularly when the resultset is empty,
      # but we still want it to be processed as something returning a resultset
      # (because it is). Hopefully it won't hurt
        $result = GenTest::Result->new(
            query        => $query,
            status        => STATUS_OK,
            data            => ( $query =~ /\WRETURNING\W/i ? [] : undef ),
            affected_rows    => $affected_rows,
            matched_rows    => $matched_rows,
            changed_rows    => $changed_rows,
            info        => $mysql_info,
            start_time    => $start_time,
            end_time    => $end_time,
            execution_flags => $execution_flags
        );
    } else {
        my @data;
        my %data_hash;
        my $row_count = 0;
        my $result_status = STATUS_OK;

        while (my @row = $sth->fetchrow_array()) {
            $row_count++;
            push @data, \@row;
            last if ($row_count > EXECUTOR_MAX_ROWS_THRESHOLD);
        }

        # Do one extra check to catch 'query execution was interrupted' error
        if (defined $sth->err()) {
            $result_status = errorType($sth->err());
            @data = ();
        } elsif ($row_count > EXECUTOR_MAX_ROWS_THRESHOLD) {
            my $query_for_print= shorten_message($query);
            say("Query: $query_for_print returned more than EXECUTOR_MAX_ROWS_THRESHOLD (".EXECUTOR_MAX_ROWS_THRESHOLD().") rows. Killing it ...");

            my $kill_dbh = DBI->connect($executor->dsn(), undef, undef, { PrintError => 1 });
            $kill_dbh->do("KILL QUERY ".$executor->connectionId());
            $kill_dbh->disconnect();
            $sth->finish();
            $dbh->do("SELECT 1 FROM DUAL /* Guard query so that the KILL QUERY we just issued does not affect future queries */;");
            @data = ();
            $result_status = STATUS_SKIP;
        }

        $result = GenTest::Result->new(
            query        => $query,
            status        => $result_status,
            affected_rows     => $affected_rows,
            data        => \@data,
            start_time    => $start_time,
            end_time    => $end_time,
            column_names    => $column_names,
            column_types    => $column_types,
            execution_flags => $execution_flags
        );

    }

    $sth->finish();

    if (defined $err or $sth->{mysql_warning_count} > 0) {
        eval {
            my $warnings = $dbh->selectall_arrayref("SHOW WARNINGS");
            $result->setWarnings($warnings);
        }
    }
    return $result;
}

sub slaveInfo {
    my $executor = shift;
    my $slave_info = $executor->dbh()->selectrow_arrayref("SHOW SLAVE HOSTS");
    return ($slave_info->[SLAVE_INFO_HOST], $slave_info->[SLAVE_INFO_PORT]);
}

sub masterStatus {
    my $executor = shift;
    return $executor->dbh()->selectrow_array("SHOW MASTER STATUS");
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

sub read_only {
    my $executor = shift;
    my $dbh = $executor->dbh();
    my ($grant_command) = $dbh->selectrow_array("SHOW GRANTS FOR CURRENT_USER()");
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
    my $engines= $self->dbh->selectcol_arrayref("select engine from information_schema.engines where support in ('YES','DEFAULT')");
    if ($engines) {
      $self->[EXECUTOR_ENGINES]= [ @$engines ];
    }
  }
  return $self->[EXECUTOR_ENGINES];
}

sub loadMetaData {
  # File points at table metadata (main). Other files, e.g. proc,
  # should be searched using the same TS
  my ($self, $file)= @_;

  unless (open(TBL,$file)) {
    sayError("Couldn't open table dump $file: $!");
    return undef;
  }
  sayDebug("Loading metadata from $file");
  my %tabletype;
  my $meta;

  while (<TBL>) {
    chomp;
    my ($schema, $table, $type, $column, $key, $realtype, $maxlength, $ind, $unique) = split /;/, $_;
#    print "HERE: $schema, $table, $type, $column, $key, $realtype, $maxlength, $ind, $unique\n";
    if    ($type eq 'BASE TABLE') { $type= 'table' }
    elsif ($type eq 'SYSTEM VERSIONED') { $type = 'versioned' }
    elsif ($type eq 'SEQUENCE') { $type = 'sequence' }
    elsif ($type eq 'VIEW' or $type eq 'SYSTEM VIEW') { $type= 'view' }
    else { $type= 'misc' };
    $meta->{$schema}={} if not exists $meta->{$schema};
    $meta->{$schema}->{$type}={} if not exists $meta->{$schema}->{$type};
    $meta->{$schema}->{$type}->{$table}={} if not exists $meta->{$schema}->{$type}->{$table};
    $meta->{$schema}->{$type}->{$table}->{COL}={} if not exists $meta->{$schema}->{$type}->{$table}->{COL};
    $meta->{$schema}->{$type}->{$table}->{IND}={} if not exists $meta->{$schema}->{$type}->{$table}->{IND};
    $tabletype{$schema.'.'.$table}= $type;
    $meta->{$schema}->{tables}->{$table}= $meta->{$schema}->{$type}->{$table};

    my $metatype= lc($realtype);
    if (
      $metatype eq 'bit' or
      $metatype eq 'tinyint' or
      $metatype eq 'smallint' or
      $metatype eq 'mediumint' or
      $metatype eq 'bigint'
    ) { $metatype= 'int' }
    elsif (
      $metatype eq 'double'
    ) { $metatype= 'float' }
    elsif (
      $metatype eq 'datetime'
    ) { $metatype= 'timestamp' }
    elsif (
      $metatype eq 'varchar' or
      $metatype eq 'binary' or
      $metatype eq 'varbinary'
    ) { $metatype= 'char' }
    elsif (
      $metatype eq 'tinyblob' or
      $metatype eq 'mediumblob' or
      $metatype eq 'longblob' or
      $metatype eq 'blob' or
      $metatype eq 'tinytext' or
      $metatype eq 'mediumtext' or
      $metatype eq 'longtext' or
      $metatype eq 'text'
    ) { $metatype= 'blob' };

    if ($key eq 'PRI') { $key= 'primary' }
    elsif ($key eq 'MUL' or $key eq 'UNI') { $key= 'indexed' }
    else { $key= 'ordinary' };
    my $type= $tabletype{$schema.'.'.$table};
    $meta->{$schema}->{$type}->{$table}->{COL}->{$column}= [$key,$metatype,$realtype,$maxlength];

    if ($ind ne 'NULL' and $ind ne '' and $ind ne '\N') {
      my $indtype= $tabletype{$schema.'.'.$table};
      $meta->{$schema}->{$indtype}->{$table}->{IND}->{$ind}= [$unique];
    }
  }
  close(TBL);

  $file =~ s/\/(system|nonsystem)-tables-([\d\.]+)$/\/$1-proc-$2/;
  my ($ft, $ts)= ($1, $2);
  if (open(PROC,$file)) {
    while (<PROC>) {
      chomp;
      my ($schema, $proc, $type) = split /;/, $_;
      # procedure or function
      $type= lc($type);
      # paramnum will be just a placeholder for now
      $meta->{$schema}={} if not exists $meta->{$schema};
      $meta->{$schema}->{$type}={} if not exists $meta->{$schema}->{$type};
      $meta->{$schema}->{$type}->{$proc}={} if not exists $meta->{$schema}->{$type}->{$proc};
      $meta->{$schema}->{$type}->{$proc}->{paramnum}= 0;
    }
    close(PROC);
  } else {
    sayWarning("Couldn't open procedure dump $file: $!");
  }
  say("Executor#".$self->threadId()." finished loading $ft metadata: ".scalar(keys %$meta)." schemas, ".scalar(keys %tabletype)." tables");
#  $Data::Dumper::Maxdepth= 0;
#  print Dumper $meta;
  return $meta;
}

1;
