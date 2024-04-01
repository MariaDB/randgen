# Copyright (c) 2009,2010 Oracle and/or its affiliates. All rights reserved.
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

package GenTest::Executor::Postgres;

@ISA = qw(GenTest::Executor);

use strict;
use DBI;

use GenTest;
use GenTest::Constants;
use GenTest::Result;
use GenTest::Executor;
use GenTest::Translator;
use GenTest::Translator::MysqlDML2ANSI;
use GenTest::Translator::Mysqldump2ANSI;
use GenTest::Translator::MysqlDML2pgsql;
use GenTest::Translator::Mysqldump2pgsql;
use Time::HiRes;
use Data::Dumper;

sub init {
	my $self = shift;

	my $dbh =  DBI->connect($self->dsn(), undef, undef,
                            {
                                PrintError => 0,
                                RaiseError => 0,
                                AutoCommit => 1}
        );

    if (not defined $dbh) {
        say("connect() to dsn ".$self->dsn()." failed: ".$DBI::errstr);
        return STATUS_ENVIRONMENT_FAILURE;
    }
    
	$self->setDbh($dbh);	

    $self->defaultSchema($self->currentSchema());
    say "Default schema: ".$self->defaultSchema();

    return STATUS_OK;
}

my %caches;

my %acceptedErrors = (
    ## YB: 42P01 is also used for the missing/invalid FROM-clause entry errors, etc.
    ## We now take the "IF (NOT) EXISTS" option out of the comment block and stop
    ## masking these errors.
    # "42P01" => 1,# DROP TABLE on non-existing table is accepted since
                 # tests rely on non-standard MySQL DROP IF EXISTS;
    # "42P06" => 1 # Schema already exists
    );

sub execute {
    my ($self, $query, $silent) = @_;
    my $executor = $self;

    my $dbh = $self->dbh();

    return GenTest::Result->new( 
        query => $query, 
        status => STATUS_UNKNOWN_ERROR ) 
        if not defined $dbh;

    # Filter out any /*executor */ comments that do not pertain to this particular Executor/DBI
    my $executor_id = $self->id();
    $query =~ s{/\*executor$executor_id (.*?) \*/}{$1}sg;
    $query =~ s{/\*executor.*?\*/}{}sgo;

    $query =~ s{/\*!\s*IF\s+(|NOT\s+)EXISTS\s*\*/}{IF $1EXISTS}sgo;
    
    $query = $self->preprocess($query);
    
    ## This may be generalized into a translator which is a pipe

    my @pipe = (GenTest::Translator::Mysqldump2pgsql->new(),
                GenTest::Translator::MysqlDML2pgsql->new());

    foreach my $p (@pipe) {
        $query = $p->translate($query);
        return GenTest::Result->new( 
            query => $query, 
            status => STATUS_WONT_HANDLE ) 
            if not $query;
    }

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
            select()->flush();  # Avoid logging message gets in the middle
        }
    }

    if (!$dbh->ping()) {
        ## Reinit if connection is dead
        say("Postgres connection is dead. Reconnect");
        $self->disconnect();
        sleep(1);
        $self->init();
        $dbh=$self->dbh();
    }

    # Autocommit ?

    my $db = $self->getName()." ".$self->version();

    my $start_time = Time::HiRes::time();

    my $sth = $dbh->prepare($query);

    if (defined $dbh->err()) {
        my $errstr = $db.":".$dbh->state().":".$dbh->errstr();
        say("Query: $query failed: $errstr.") if !$silent;
        $self->[EXECUTOR_ERROR_COUNTS]->{$errstr}++ if rqg_debug() && !$silent;
        return GenTest::Result->new(
            query       => $query,
            status      => $self->findStatus($dbh->state()),
            err         => $dbh->err(),
            errstr      => $dbh->errstr(),
            sqlstate    => $dbh->state(),
            start_time  => $start_time,
            end_time    => Time::HiRes::time()
            );
    }


    my $affected_rows = $sth->execute();

    
    my $end_time = Time::HiRes::time();
    my $err = $sth->err();
    
    if ($trace_me eq 1) {
        if (defined $err) {
                # Mark invalid queries in the trace by prefixing each line.
                # We need to prefix all lines of multi-line statements also.
                $trace_query =~ s/\n/\n# [sqltrace]    /g;
                print '# [$$] [sqltrace] ERROR '.$err.": $trace_query;\n";
        } else {
            print "[$$] $trace_query;\n";
        }
    }

    my $result;
    
    if (defined $err) {         
        if (not defined $acceptedErrors{$dbh->state()}) {
            ## Error on EXECUTE
            my $errstr = $db.":".$dbh->state().":".$dbh->errstr();
	    say("Query: $query failed: $errstr.") if !$silent;
            $self->[EXECUTOR_ERROR_COUNTS]->{$errstr}++ if rqg_debug() && !$silent;
            return GenTest::Result->new(
                query       => $query,
                status      => $self->findStatus($dbh->state()),
                err         => $dbh->err(),
                errstr      => $dbh->errstr(),
                sqlstate    => $dbh->state(),
                start_time  => $start_time,
                end_time    => $end_time
                );
        } else {
            ## E.g. DROP on non-existing table
            return GenTest::Result->new(
                query       => $query,
                status      => STATUS_OK,
                affected_rows => 0,
                start_time  => $start_time,
                end_time    => Time::HiRes::time()
                );
        }

    } elsif ((not defined $sth->{NUM_OF_FIELDS}) || ($sth->{NUM_OF_FIELDS} == 0)) {
        ## DDL/UPDATE/INSERT/DROP/DELETE
        $result = GenTest::Result->new(
            query       => $query,
            status      => STATUS_OK,
            affected_rows   => $affected_rows,
            start_time  => $start_time,
            end_time    => $end_time
            );
        $self->[EXECUTOR_ERROR_COUNTS]->{'(no error)'}++ if rqg_debug() && !$silent;
    } else {
        ## Query
        
        # We do not use fetchall_arrayref() due to a memory leak
        # We also copy the row explicitly into a fresh array
        # otherwise the entire @data array ends up referencing row #1 only
        my @data;
        while (my $row = $sth->fetchrow_arrayref()) {
            my @row = @$row;
            push @data, \@row;
        }   
        
        $result = GenTest::Result->new(
            query       => $query,
            status      => STATUS_OK,
            affected_rows   => $affected_rows,
            data        => \@data,
            start_time  => $start_time,
            end_time    => $end_time
            );
        
        $self->[EXECUTOR_ERROR_COUNTS]->{'(no error)'}++ if rqg_debug() && !$silent;
    }

    $sth->finish();

    return $result;
}

sub findStatus {
    my ($self, $state) = @_;

    if ($state eq "22000") {
	return STATUS_SERVER_CRASHED;
    } elsif (($state eq '42000') || ($state eq '42601')) {
	return STATUS_SYNTAX_ERROR;
    } else {
	return $self->SUPER::findStatus(@_);
    }
}

## Override the base name for ourselves with YB-specific behaviour
sub getName {
    my $self = shift;
    return (defined $self->yb_version())? "Yugabyte": "Postgres";
}

sub version {
    my $self = shift;
    my $yb = $self->yb_version();
    if (defined $yb) {
        return $yb;
    }
    my $dbh = $self->dbh();
    return $dbh->get_info(18);
}

sub yb_version {
    my $self = shift;
    my $altname = \$_[0]->[GenTest::Executor::EXECUTOR_ALT_NAME];
    my $altver = \$_[0]->[GenTest::Executor::EXECUTOR_ALT_VERSION];
    if ((not defined $$altver) and (not defined $$altname)) {
        my $dbh = $self->dbh();
        my $ver = $dbh->selectrow_array("SELECT VERSION()");
        if ($ver =~ s/.*-YB-(\S+)\s+.*/$1/sgo) {
            $$altname = "Yugabyte";
            $$altver = $ver;
        } else {
            $$altname = "Postgres";
        }        
    }
    return $$altver;
}

sub currentSchema {
	my ($self,$schema) = @_;

	return undef if not defined $self->dbh();
    
    if (defined $schema) {
        $self->execute("SET search_path TO $schema");
    }
    
	return $self->dbh()->selectrow_array("SELECT current_schema()");
}

sub getSchemaMetaData {
    ## Return the result from a query with the following columns:
    ## 1. Schema (aka database) name
    ## 2. Table name
    ## 3. TABLE for tables VIEW for views and MISC for other stuff
    ## 4. Column name
    ## 5. PRIMARY for primary key, INDEXED for indexed column and "ORDINARY" for all other columns
    my ($self) = @_;
    my $query = 
        "SELECT DISTINCT ".
               "table_schema, ".
               "table_name, ".
               "CASE WHEN table_type = 'BASE TABLE' THEN 'table' ".
                    "WHEN table_type = 'VIEW' THEN 'view' ".
                    "WHEN table_type = 'SYSTEM VIEW' then 'view' ".
                    "ELSE 'misc' END AS table_type, ".
               "column_name, ".
               "CASE WHEN indisprimary THEN 'primary' ".
                    "WHEN indexrelid IS NOT NULL THEN 'indexed' ".
                    "ELSE 'ordinary' END as column_key, ".
               "CASE WHEN data_type IN ('integer','smallint','bigint') THEN 'int' ".
                    "WHEN data_type IN ('real','double precision') THEN 'float' ".
                    "WHEN data_type IN ('numeric') THEN 'decimal' ".
                    "WHEN data_type LIKE 'timestamp%' THEN 'timestamp' ".
                    "WHEN data_type IN ('character','character varying','bytea') THEN 'char' ".
                    "WHEN data_type IN ('blob','mediumblob','longblob') THEN 'blob' ".
                    "WHEN data_type IN ('text') THEN 'text' ".
                    "ELSE data_type END AS data_type_normalized, ".
               "CASE WHEN data_type IN ('real') THEN 'float' ".
                    "WHEN data_type IN ('double precision') THEN 'double' ".
                    "WHEN data_type IN ('numeric') THEN 'decimal' ".
                    "WHEN data_type IN ('integer') THEN 'int' ".
                    "WHEN data_type IN ('character') THEN 'char' ".
                    "WHEN data_type IN ('character varying') THEN 'varchar' ".
                    "WHEN data_type IN ('text','smallint','bigint') THEN data_type ".
                    "WHEN data_type IN ('bytea') THEN 'varbinary' ".
                    "WHEN data_type LIKE 'timestamp%' THEN 'timestamp' ".
                    "ELSE data_type END AS data_type, ".
               "character_maximum_length, ".
               "table_rows ".
         "FROM information_schema.tables INNER JOIN ".
              "information_schema.columns USING(table_schema, table_name) INNER JOIN ".
              "(SELECT ".
                    "nspname AS table_schema, ".
                    "relname AS table_name, ".
                    "reltuples AS table_rows ".
               "FROM pg_class c JOIN ".
                    "pg_namespace nc ON relnamespace = nc.oid ".
               ") AS vst USING (table_schema, table_name) ".
                 "LEFT JOIN LATERAL ".
                     "(SELECT indisprimary, indexrelid, indkey ".
                      "FROM pg_namespace si JOIN ".
                           "pg_class ct ON si.nspname = table_schema ".
                                          "AND ct.relname = table_name ".
                                          "AND ct.relnamespace = si.oid JOIN ".
                           "pg_index ix ON ix.indrelid = ct.oid".
                      ") AS vix ON ordinal_position = ANY(indkey) ".
         "WHERE table_name <> 'dummy'";

    my $res = $self->dbh()->selectall_arrayref($query);
    croak("FATAL ERROR: Failed to retrieve schema metadata") unless $res;

    # my %table_rows = ();
    # foreach my $i (0..$#$res) {
    #     my $tbl = $res->[$i]->[0].'.'.$res->[$i]->[1];
    #     if ((not defined $table_rows{$tbl}) or ($table_rows{$tbl} eq 'NULL') or ($table_rows{$tbl} eq '')) {
    #         my $count_row = $self->dbh()->selectrow_arrayref("SELECT COUNT(*) FROM $tbl");
    #         $table_rows{$tbl} = $count_row->[0];
    #     }
    #     $res=>[$i]->[8] = $table_rows{$tbl};
    # }
    return $res;
}

#### This query gives columns with keys (PK and unique constraint, but not indices)

#	"select column_name from information_schema.columns ".
#	"where table_schema = 'public' and ".
#	"table_name = '$table' and ".
#	"table_schema = '$dbname' and ".
#	"column_name not in ".
#	    "(select k.column_name from ".
#	     "information_schema.key_column_usage as k ".
#	     "inner join information_schema.columns ".
#	     "using(table_name, table_schema, column_name) ".
#	     "where table_name='$table' and table_schema='$dbname')";

sub getCollationMetaData {
    ## Return the result from a query with the following columns:
    ## 1. Collation name
    ## 2. Character set
    my ($self) = @_;
    my $query = 
        "SELECT collation_name,character_set_name FROM information_schema.collations";

    return [];
}

sub disconnect {
    my ($self) = @_;
    $self->dbh->disconnect;
    $self->setDbh(undef);
}



1;
