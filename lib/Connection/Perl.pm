# Copyright (c) 2023, MariaDB
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

package Connection::Perl;

require Exporter;

@ISA = qw(Connection);

use Carp;

use strict;
use DBI;
use Constants;
use Connection;
use GenUtil;
use Constants::MariaDBErrorCodes;

sub new {
  my $class = shift;
  my $self= $class->SUPER::new( {
    server => CONNECTION_SERVER,
    host => CONNECTION_HOST,
    port => CONNECTION_PORT,
    protocol => CONNECTION_PROTOCOL,
    role => CONNECTION_ROLE,
    user => CONNECTION_USER,
    password => CONNECTION_PASSWORD,
    name => CONNECTION_NAME,
    filter => CONNECTION_MESSAGE_FILTERING
  },@_ );
  $self->[CONNECTION_DSN]=
    "dbi:mysql".
    ":host=".$self->[CONNECTION_HOST].
    ":port=".$self->[CONNECTION_PORT].
    ":user=".$self->[CONNECTION_USER].
    ":mysql_local_infile=1".
    ":max_allowed_packet=1G".
    ($self->[CONNECTION_PROTOCOL] eq 'ps' ? ":mysql_server_prepare=1" : "");
  $self->[CONNECTION_DBH]= $self->connect();
  sayDebug("Connected: ".$self->[CONNECTION_NAME]." as ".$self->[CONNECTION_ROLE]." (".$self->[CONNECTION_USER].")");
  return $self;
}

sub connect {
  my $self= shift;
  $self->[CONNECTION_ERROR]= undef;
  $self->[CONNECTION_ERROR_STRING]= undef;
  $self->[CONNECTION_ERROR_TYPE]= undef;
  my $dbh= DBI->connect($self->[CONNECTION_DSN],
    undef,
    undef,
    # , mysql_server_prepare => 1
    {PrintError => 0, RaiseError => 0, AutoCommit => 1, mysql_auto_reconnect => 1}
  );
  ($self->[CONNECTION_ERROR], $self->[CONNECTION_ERROR_STRING])= ($DBI::err||0,$DBI::errstr||'');
  $self->[CONNECTION_ERROR_TYPE]= errorType($self->[CONNECTION_ERROR]);

  if ($self->[CONNECTION_ERROR]) {
    my $downtime= (serverGone($self->[CONNECTION_ERROR_TYPE]) && $self->[CONNECTION_SERVER] && $self->[CONNECTION_SERVER]->isPlannedDowntime());
    $self->[CONNECTION_ERROR_TYPE]= STATUS_SERVER_STOPPED if $downtime;
    $self->report_error("Connect") if $self->err;

    if ($downtime) {
      sayDebug($self->name().": Upon connecting: server is down, the downtime is planned");
      my $status= $self->[CONNECTION_SERVER]->waitPlannedDowntime();
      if ($status == STATUS_OK) {
        sayDebug($self->name().": Server returned in time, trying to connect again");
        return $self->connect();
      } elsif ($status == STATUS_SERVER_STOPPED) {
        sayDebug($self->name().": Upon connecting: instructed not to wait");
      } else {
        sayError($self->name().": Upon connecting: Server has gone away");
      }
    }
  }
  return $dbh;
}

sub dbh {
  return $_[0]->[CONNECTION_DBH];
}

sub disconnect {
  my $self= shift;
  $self->[CONNECTION_DBH]->disconnect() if $self->[CONNECTION_DBH];
  ($self->[CONNECTION_ERROR], $self->[CONNECTION_ERROR_STRING])= ($DBI::err||0,$DBI::errstr||'');
}

sub refresh {
  my $self= shift;
  if ($self->[CONNECTION_DBH] && $self->[CONNECTION_DBH]->ping) {
    return STATUS_OK;
  } else {
    sayDebug($self->name().": Stale connection, reconnecting");
    $self->[CONNECTION_DBH]= $self->connect();
    ($self->[CONNECTION_ERROR], $self->[CONNECTION_ERROR_STRING])= ($DBI::err||0,$DBI::errstr||'');
    if ((! $self->[CONNECTION_ERROR]) && $self->[CONNECTION_DBH] && $self->[CONNECTION_DBH]->ping) {
      return STATUS_OK;
    } else {
      sayDebug($self->name().": (Re)connect to ".$self->[CONNECTION_PORT]." failed due to ".$self->[CONNECTION_ERROR].": ".$self->[CONNECTION_ERROR_STRING]);
      return $self->[CONNECTION_ERROR];
    }
  }
}

sub quote {
  my ($self, $query)= @_;
  return $self->dbh->quote($query);
}

# Executes the query without returning a result set.
# Returns error or STATUS_OK
sub execute {
  my ($self, $query)= @_;
  $self->query($query,0);
  return $self->[CONNECTION_ERROR];
}

# Returns the whole result set as an array ref of array refs.
# Undef if the query failed.
# $cols is an optional hashref with column names. If empty, all columns are returned.
# if $cols == 0, it is coming from $self->execute and there is no need for resultset
sub query {
  my ($self, $query, $cols)= @_;
  my $name= $self->name();

  # Unset values before executing the query
  $self->[CONNECTION_AFFECTED_ROWS]= undef;
  $self->[CONNECTION_ERROR]= undef;
  $self->[CONNECTION_ERROR_STRING]= undef;
  $self->[CONNECTION_ERROR_TYPE]= undef;
  $self->[CONNECTION_MYSQL_INFO]= undef;
  $self->[CONNECTION_COLUMN_NAMES]= undef;
  $self->[CONNECTION_FIELD_NUMBER]= undef;
  $self->[CONNECTION_COLUMN_TYPES]= undef;
  $self->[CONNECTION_SQLSTATE]= undef;
  $self->[CONNECTION_WARNING_COUNT]= undef;

  return undef unless $self->alive();
    
  my $sth;
  # Combination of mysql_server_prepare and mysql_multi_statements
  # allegedly causes troubles (syntax errors), both with mysql and MariaDB drivers
  $self->[CONNECTION_QNO]++;
  my $send_query= '/* '.$self->name().' QNO '.$self->[CONNECTION_QNO].' */ '.$query;
  sayDebug("Preparing query $send_query");
  if (index($query,";") == -1) {
    $sth= $self->dbh()->prepare($send_query);
  } else {
    $sth= $self->dbh()->prepare($send_query, { mysql_server_prepare => 0 });
  }
  sayDebug("Prepared query $send_query");
  if ($DBI::err) {
    ($self->[CONNECTION_ERROR], $self->[CONNECTION_ERROR_STRING])= ($DBI::err||0,$DBI::errstr||'');
    $self->report_error($send_query);
    return undef;
  }
  my $start_time = Time::HiRes::time();
  sayDebug("Executing query $send_query");
  $self->[CONNECTION_AFFECTED_ROWS]= $sth->execute();
  $self->[CONNECTION_EXECUTION_TIME] = Time::HiRes::time() - $start_time;
  sayDebug("Executed query $send_query");

  ($self->[CONNECTION_ERROR], $self->[CONNECTION_ERROR_STRING])= ($DBI::err||0,$DBI::errstr||'');
  $self->[CONNECTION_ERROR_TYPE]= errorType($self->[CONNECTION_ERROR]);
  my $downtime= (serverGone($self->[CONNECTION_ERROR_TYPE]) && $self->[CONNECTION_SERVER] && $self->[CONNECTION_SERVER]->isPlannedDowntime());
  $self->[CONNECTION_ERROR_TYPE]= STATUS_SERVER_STOPPED if $downtime;
  $self->report_error($send_query) if $self->err;

  if ($downtime) {
    sayDebug($self->name().": Server is down, the downtime is planned");
    my $status= $self->[CONNECTION_SERVER]->waitPlannedDowntime();
    if ($status == STATUS_OK) {
      sayDebug($self->name().": Server returned in time, re-running the last query");
      return $self->query($query, $cols);
    } elsif ($status == STATUS_SERVER_STOPPED) {
      sayDebug($self->name().": instructed not to wait");
    } else {
      sayError($self->name().": Server has gone away");
    }
  }
  $self->[CONNECTION_MYSQL_INFO]= $self->dbh->{mysql_info};
  if ($sth->{NUM_OF_FIELDS}) {
    $self->[CONNECTION_COLUMN_NAMES]= $sth->{NAME};
    $self->[CONNECTION_COLUMN_TYPES]= $sth->{mysql_type_name};
  }
  $self->[CONNECTION_FIELD_NUMBER]= $sth->{NUM_OF_FIELDS};
  $self->[CONNECTION_SQLSTATE]= $sth->state;
  $self->[CONNECTION_WARNING_COUNT]= $sth->{mysql_warning_count};
  my $res;
  if ((not defined $cols) || (ref $cols eq 'HASH') and (not $self->[CONNECTION_ERROR])) {
    $res= $sth->fetchall_arrayref($cols);
  }
  $sth->finish();
  return $res;
}

# Returns the row of a given number (numbering starts from 1) in an array ref.
# If the argument isn't given or is 0 returns the first row.
# Undef if the query failed
sub get_row {
  my ($self, $query, $rownum)= @_;
  $rownum= 1 unless $rownum;
  my $resultset= $self->query($query);
  return undef unless defined $resultset;
  return [] unless scalar(@$resultset);
  return $resultset->[$rownum-1];
}

# Returns the column of a given number (numbering starts from 1) in an array ref
# If the argument isn't given or is 0 returns the first column.
# Undef if the query failed.
# The difference with fetchall_arrayref([n]) is that here we are returning
# a plain arrayref, not an array ref of array refs.
sub get_column {
  my ($self, $query, $colnum)= @_;
  $colnum= 1 unless $colnum;
  my $resultset= $self->query($query);
  return undef unless defined $resultset;
  my @col= ();
  foreach my $r (@$resultset) {
    push @col, $r->[$colnum-1];
  }
  return \@col;
}

# Returns the column(s) with the given names as an array ref of hash refs
# If the argument isn't given, returns the whole result set in the same form.
# Undef if the query failed.

sub get_columns_by_name {
  my ($self, $query, @cols)= @_;
  my %cols= ();
  map { $cols{$_} = 1 } @cols;
  return $self->query($query,\%cols);
}

# Returns a single value with the given row number and column number, starting from 1
# If an argument isn't given or is 0, returns the first column/row.
# Undef if the query failed.
sub get_value {
  my ($self, $query, $rownum, $colnum)= @_;
  $colnum= 1 unless $colnum;
  $rownum= 1 unless $rownum;
  my $resultset= $self->query($query);
  return undef unless defined $resultset;
  return $resultset->[$rownum-1]->[$colnum-1];
}

sub alive {
  my $self= shift;
  return 1 if $self->dbh && $self->dbh->ping;
  if ($self->[CONNECTION_SERVER]->isPlannedDowntime()) {
    if ($self->[CONNECTION_SERVER]->waitPlannedDowntime() != STATUS_OK) {
      return 0;
    }
  }
  return $self->dbh && $self->dbh->ping;
}
