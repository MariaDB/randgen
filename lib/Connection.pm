# Copyright (c) 2023, MariaDB
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

package Connection;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
  CONNECTION_PORT
  CONNECTION_HOST
  CONNECTION_USER
  CONNECTION_PASSWORD
  CONNECTION_PROTOCOL
  CONNECTION_SOCKET
  CONNECTION_DBH
  CONNECTION_DSN
  CONNECTION_ERROR
  CONNECTION_ERROR_STRING
  CONNECTION_ERROR_TYPE
  CONNECTION_ROLE
  CONNECTION_SERVER
  CONNECTION_AFFECTED_ROWS
  CONNECTION_EXECUTION_TIME
  CONNECTION_MYSQL_INFO
  CONNECTION_COLUMN_NAMES
  CONNECTION_FIELD_NUMBER
  CONNECTION_COLUMN_TYPES
  CONNECTION_SQLSTATE
  CONNECTION_WARNING_COUNT
  CONNECTION_NAME
  CONNECTION_QNO
  CONNECTION_REPORTED_ERRORS
  CONNECTION_MESSAGE_FILTERING
  CONNECTION_ERROR_SUPPRESSIONS
);

use Carp;
use Data::Dumper;
Time::HiRes;

use GenUtil;
use Constants;
use Constants::MariaDBErrorCodes;


use strict;

use constant CONNECTION_PORT => 1;
use constant CONNECTION_HOST => 2;
use constant CONNECTION_USER => 3;
use constant CONNECTION_PASSWORD => 4;
use constant CONNECTION_SOCKET => 5;
use constant CONNECTION_PROTOCOL => 6;
use constant CONNECTION_DBH => 7;
use constant CONNECTION_DSN => 8;
use constant CONNECTION_ERROR => 9;
use constant CONNECTION_ERROR_STRING => 10;
use constant CONNECTION_SERVER => 11;
use constant CONNECTION_ROLE => 12; # super, worker
use constant CONNECTION_EXECUTION_TIME => 13;
use constant CONNECTION_AFFECTED_ROWS => 14;
use constant CONNECTION_MYSQL_INFO => 15;
use constant CONNECTION_COLUMN_NAMES => 16;
use constant CONNECTION_FIELD_NUMBER => 17;
use constant CONNECTION_COLUMN_TYPES => 18;
use constant CONNECTION_SQLSTATE => 19;
use constant CONNECTION_WARNING_COUNT => 20;
use constant CONNECTION_ERROR_TYPE => 21;
use constant CONNECTION_NAME => 22;
use constant CONNECTION_QNO => 23;
use constant CONNECTION_REPORTED_ERRORS => 24;
use constant CONNECTION_MESSAGE_FILTERING => 25;
use constant CONNECTION_ERROR_SUPPRESSIONS => 26;

use constant CONNECTION_SUPER_USER => 'root';
use constant CONNECTION_TEST_USER => 'rqg';
use constant CONNECTION_DEFAULT_PORT => 19300;
use constant CONNECTION_DEFAULT_HOST => '127.0.0.1';

1;

sub new {
  my $class = shift;
  my $args = shift;

  my $obj = bless ([], $class);

  my $max_arg = (scalar(@_) / 2) - 1;

  foreach my $i (0..$max_arg) {
    if (exists $args->{$_[$i * 2]}) {
      if (defined $obj->[$args->{$_[$i * 2]}]) {
        carp("Argument '$_[$i * 2]' passed twice to ".$class.'->new()');
      } else {
        $obj->[$args->{$_[$i * 2]}] = $_[$i * 2 + 1];
      }
    } else {
      carp("Unknown argument '$_[$i * 2]' to ".$class.'->new()');
    }
  }
  unless ((defined $obj->[CONNECTION_SERVER]) || (defined $obj->[CONNECTION_HOST] && defined $obj->[CONNECTION_PORT])) {
    carp("Neither host/port nor server defined in ".$class."->new()");
  }
  $obj->[CONNECTION_NAME]= 'PID-'.abs($$) unless defined $obj->[CONNECTION_NAME];
  $obj->[CONNECTION_HOST]= $obj->[CONNECTION_SERVER]->host unless defined $obj->[CONNECTION_HOST];
  $obj->[CONNECTION_PORT]= $obj->[CONNECTION_SERVER]->port unless defined $obj->[CONNECTION_PORT];
  unless ($obj->[CONNECTION_ROLE]) {
    $obj->[CONNECTION_ROLE]= 'worker';
  }
  unless ($obj->[CONNECTION_USER]) {
    if ($obj->[CONNECTION_ROLE] eq 'super' || not defined $obj->[CONNECTION_SERVER]) {
      $obj->[CONNECTION_USER]= 'root';
    } else {
      $obj->[CONNECTION_USER]= $obj->[CONNECTION_SERVER]->user;
    }
  }
  unless ($obj->[CONNECTION_PASSWORD]) {
    $obj->[CONNECTION_PASSWORD]= '';
  }
  $obj->[CONNECTION_QNO]= 0;
  $obj->[CONNECTION_REPORTED_ERRORS]= {};
  # ON by default, can be turned off
  $obj->[CONNECTION_MESSAGE_FILTERING]= 1 unless defined $obj->[CONNECTION_MESSAGE_FILTERING];
  # Error suppressions is the way to filter errors *before* they occur for the first time
  if ($obj->[CONNECTION_ERROR_SUPPRESSIONS]) {
    sayDebug($obj->[CONNECTION_NAME].": errors ".$obj->[CONNECTION_ERROR_SUPPRESSIONS]." will be suppressed from the start");
    my @errs= split /,/,$obj->[CONNECTION_ERROR_SUPPRESSIONS];
    map { $obj->[CONNECTION_REPORTED_ERRORS]->{$_}= 0 } @errs;
  }
  return $obj;
}

sub myQuery {
  croak "Must be defined in the connector";
}

sub connect {
  croak "Must be defined in the connector";
}

sub port {
  return $_[0]->[CONNECTION_PORT];
}

sub host {
  return $_[0]->[CONNECTION_HOST];
}

sub user {
  return $_[0]->[CONNECTION_USER];
}

sub socket {
  return $_[0]->[CONNECTION_SOCKET];
}

sub dsn {
  return $_[0]->[CONNECTION_DSN];
}

sub dbh {
  return $_[0]->[CONNECTION_DBH];
}

sub name {
  return $_[0]->[CONNECTION_NAME];
}

sub last_error {
  return ($_[0]->[CONNECTION_ERROR],$_[0]->[CONNECTION_ERROR_STRING]);
}

sub print_error {
  return $_[0]->[CONNECTION_ERROR].' "'.$_[0]->[CONNECTION_ERROR_STRING].'"';
}

sub err {
  return $_[0]->[CONNECTION_ERROR];
}

sub err_type {
  return $_[0]->[CONNECTION_ERROR_TYPE];
}

sub sqlstate {
  return $_[0]->[CONNECTION_SQLSTATE];
}

sub affected_rows {
  return $_[0]->[CONNECTION_AFFECTED_ROWS];
}

sub execution_time {
  return $_[0]->[CONNECTION_EXECUTION_TIME];
}

sub mysql_info {
  return $_[0]->[CONNECTION_MYSQL_INFO] || '';
}

sub column_names {
  return $_[0]->[CONNECTION_COLUMN_NAMES];
}

sub column_types {
  return $_[0]->[CONNECTION_COLUMN_TYPES];
}

sub number_of_fields {
  return $_[0]->[CONNECTION_FIELD_NUMBER];
}

sub warning_count {
  return $_[0]->[CONNECTION_WARNING_COUNT];
}

sub report_error {
  my ($self, $query) = @_;
  my $err_type= $self->[CONNECTION_ERROR_TYPE];
  my $filtering_allowed= (
    # These are types which we filter
    $self->[CONNECTION_MESSAGE_FILTERING] && (
      ($err_type == STATUS_SKIP) ||
      ($err_type == STATUS_UNSUPPORTED) ||
      ($err_type == STATUS_SEMANTIC_ERROR) ||
      ($err_type == STATUS_CONFIGURATION_ERROR) ||
      ($err_type == STATUS_ACL_ERROR) ||
      ($err_type == STATUS_IGNORED_ERROR) ||
      ($err_type == STATUS_RUNTIME_ERROR)
    )
  );

  if ($filtering_allowed and defined $self->[CONNECTION_REPORTED_ERRORS]->{$self->err}) {
    # The error is suppressed, don't print it
  } else {
    my $status= status2text($err_type);
    my $query_for_print= shorten_message($query);
    if ($filtering_allowed) {
      say($self->name.': '.$status.': '.$self->print_error.'. Further errors '.$self->err.' will be suppressed. ['.$query_for_print .']');
    } else {
      say($self->name.': '.$status.': '.$self->print_error.' ['.$query_for_print .']');
    }
  }
  $self->[CONNECTION_REPORTED_ERRORS]->{$self->err}++;
}


1;
