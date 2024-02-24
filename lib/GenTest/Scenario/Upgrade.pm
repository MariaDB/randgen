# Copyright (C) 2017, 2023 MariaDB
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


########################################################################
#
# The module implements the core functions for server upgrade scenarios
#
########################################################################

package GenTest::Scenario::Upgrade;

require Exporter;
@ISA = qw(GenTest::Scenario);

use strict;
use GenUtil;
use GenTest;
use GenTest::TestRunner;
use GenTest::Properties;
use Constants;
use GenTest::Scenario;
use Data::Dumper;
use File::Copy;
use File::Compare;

use DBServer::MariaDB;
use Connection::Perl;

use constant UPGRADE_ERROR_CODE => 101;

sub new {
  my $class= shift;
  my $self= $class->SUPER::new(@_);
  $self->numberOfServers(1,2);
  if ($self->new_server_options() and $self->old_server_options()->{basedir} ne $self->new_server_options()->{basedir}) {
    $self->printSubtitle('Upgrade/downgrade');
    $self->[UPGRADE_ERROR_CODE]= STATUS_UPGRADE_FAILURE;
  } else {
    unless ($self->new_server_options()) {
      $self->copyServerSpecific(1,2);
    }
    $self->printSubtitle('Same server');
    $self->[UPGRADE_ERROR_CODE]= STATUS_RECOVERY_FAILURE;
  }
  return $self;
}

sub old_server_options {
  return $_[0]->getProperty('server_specific')->{1};
}

sub new_server_options {
  return $_[0]->getProperty('server_specific')->{2};
}

sub upgrade_or_recovery_failure {
  return $_[0]->[UPGRADE_ERROR_CODE];
}

sub prepare_servers {
  my $self= shift;

  # We can initialize both servers right away, because the second one
  # runs with start_dirty, so it won't bootstrap

  my $old_server= $self->prepareServer(1, my $is_active=1);
  $self->setServerSpecific(2,'vardir',$old_server->vardir);
  $self->setServerSpecific(2,'port',$old_server->port);
  $self->setServerSpecific(2,'start_dirty',1);
  my $new_server= $self->prepareServer(2,my $is_active=0);

  say("-- Old server info: --");
  say($old_server->version());
  $old_server->printServerOptions();
  say("-- New server info: --");
  say($new_server->version());
  $new_server->printServerOptions();
  say("----------------------");

  $self->setServerSpecific(2,'dsn',$self->getServerSpecific(1,'dsn'));

  $self->backupProperties();

  return ($old_server, $new_server);
}

sub prepare_new_server {
  my ($self, $old_server)= @_;

  $self->setServerSpecific(2,'vardir',$old_server->vardir);
  $self->setServerSpecific(2,'port',$old_server->port);
  $self->setServerSpecific(2,'start_dirty',1);
  my $new_server= $self->prepareServer(2,my $is_active=1);

  say("-- New server info: --");
  say($new_server->version());
  $new_server->printServerOptions();
  say("----------------------");

  $self->setServerSpecific(2,'dsn',$self->getServerSpecific(1,'dsn'));

  $self->backupProperties();

  return $new_server;
}

sub switch_to_new_server {
  my $self= shift;
  my $srvspec= $self->getProperty('server_specific');
  $srvspec->{1}= $self->new_server_options();
  $self->setProperty('server_specific',$srvspec);
}

sub collectAclData {
  my ($self, $server)= @_;
  my $res= STATUS_OK;

  say("Collecting user names");
  my ($conn, $err)= Connection::Perl->new(server => $server, role => 'super', name => 'UPG');
  unless ($conn) {
    sayError("Connection UPG failed with error $err");
    return (STATUS_ENVIRONMENT_FAILURE, undef);
  }

  $conn->execute("FLUSH PRIVILEGES");
  # Needed due to MDEV-24657
  $conn->execute('SET character_set_connection= @@character_set_server, collation_connection= @@collation_server');
  my $query= "SELECT CONCAT('`',user,'`','\@','`',host,'`') FROM mysql.user /*!100000 WHERE is_role = 'N' */";
  my $users= $conn->get_column($query);
  if ($conn->err) {
    sayError("Couldn't fetch users, error: ".$conn->print_error);
    $users= [];
    $res= STATUS_DATABASE_CORRUPTION;
  }
  else {
    say("Found ".scalar(@$users)." users");
  }

  my $roles= [];
  $roles= $conn->get_column("SELECT CONCAT('`',user,'`') FROM mysql.user WHERE /*!100000 is_role = 'Y' OR */ 0");
  if ($conn->err) {
    sayError("Couldn't fetch roles, error: ".$conn->print_error);
    $roles= [];
    $res= STATUS_DATABASE_CORRUPTION;
  }
  else {
    say("Found ".scalar(@$roles)." roles");
  }

  # Before 10.4, there could be users identified via a plugin, but also having
  # non-empty password value in mysql.user. The password would be unused, but
  # such configuration was not prohibited.
  # 10.4 processes such users in a special way: if they have non-empty plugin
  # _and_ an empty authentication string _and_ a non-empty password, then
  # the password value is relocated to authentication string.
  # As a result of this exercise, the discrepancy in SHOW GRANTS
  # between pre-10.4 and 10.4+ can occur, such as
  # Old: GRANT USAGE ON *.* TO 'dccjm'@'%' IDENTIFIED VIA unix_socket
  # New: GRANT USAGE ON *.* TO 'dccjm'@'%' IDENTIFIED VIA unix_socket USING '*998833943E8FD8643750560AE3074C26C06F41EC'
  #
  # To avoid it, we'll take note of such users for old servers, and then
  # imitate the new form of SHOW GRANTS for them

  my %plugin_users_with_passwords= ();
  if ($server->versionNumeric lt '100403')
  {
    # MySQL 5.7+ doesn't have `password` field
    if ($server->versionNumeric ge '0507' and $server->versionNumeric lt '1000') {
      $query= "SELECT CONCAT('`',user,'`','\@','`',host,'`') FROM mysql.user WHERE plugin != '' AND authentication_string = ''";
    } else {
      $query= "SELECT CONCAT('`',user,'`','\@','`',host,'`'), password FROM mysql.user WHERE plugin != '' AND password != '' AND authentication_string = ''";
    }

    my $plugin_users_with_passwords= $conn->query($query);
    if ($conn->err) {
      sayError("Couldn't fetch plugin users with passwords, error: ".$conn->print_error);
      $res= STATUS_DATABASE_CORRUPTION;
    }
    else {
      say("Found ".scalar(@$plugin_users_with_passwords)." plugin users with passwords");
      foreach my $pu (@$plugin_users_with_passwords) {
        $plugin_users_with_passwords{$pu->[0]}= $pu->[1];
      }
    }
  }
  say("Collecting grants");

  my %grants= ();
  foreach my $u (@$users, @$roles) {
    my $def= $conn->get_value("SHOW GRANTS FOR $u");
    if ($conn->err) {
      sayError("Couldn't fetch grants for $u, error: ".$conn->print_error);
      $res= STATUS_UNKNOWN_ERROR if $res < STATUS_UNKNOWN_ERROR;
    }
    else {
      if (defined $plugin_users_with_passwords{$u} and $def !~ /USING /) {
        $def =~ s/IDENTIFIED VIA (\w+)/IDENTIFIED VIA $1 USING \'$plugin_users_with_passwords{$u}\'/;
        say("Adjusted grants for $u to show the password along with the plugin: $def");
      }
      $grants{$u}= $def;
    }
  }

  return ($res, \%grants);
}

sub normalizeGrants {
  my ($self, $old_server, $new_server, $old_grants, $new_grants)= @_;

  # 10.3+ adds 'DELETE VERSIONING ROWS' to superuser grants
  # if the old version was versioning-unaware

  if ($old_server->versionNumeric lt '1003' and $new_server->versionNumeric ge '1003') {
    foreach my $u (keys %$old_grants) {
      if ($old_grants->{$u} =~ s/(SUPER[ ,\w]*?) ON \*\.\*/$1, DELETE HISTORY ON \*\.\*/) {
        say("Adjusted old grants for $u to have DELETE HISTORY: $old_grants->{$u}");
      }
    }
  }

  # MDEV-19650: In 10.4.13+ and 10.5.3+ new user mariadb.sys@localhost was added

  if ($old_server->versionNumeric lt '100413' and $new_server->versionNumeric ge '100413') {
    foreach my $u (keys %$new_grants) {
      if ($u eq '`mariadb.sys`@`localhost`') {
          delete $new_grants->{$u};
      }
    }
  }

  # 5.7 doesn't show IDENTIFIED BY PASSWORD in SHOW GRANTS

  if ($old_server->versionNumeric gt '0507' and $old_server->versionNumeric lt '1000' and $new_server->versionNumeric gt '1000') {
    foreach my $u (keys %$new_grants) {
      if ($new_grants->{$u} =~ s/ IDENTIFIED\sBY\sPASSWORD\s\'\*[0-9A-Z]+\'//) {
        say("Adjusted new grants for $u to remove the password");
      }
    }
  }

  # MDEV-17655: In 10.3.15+ and 10.4.5+ DELETE VERSIONING ROWS has become DELETE HISTORY.
  # It's not enough to adjust super accounts above, as non-super ones could have it as well.
  # We will just blindly rename it everywhere

  foreach my $u (keys %$old_grants) {
    if ($old_grants->{$u} =~ s/DELETE VERSIONING ROWS/DELETE HISTORY/g) {
      say("Adjusted old grants for $u to have DELETE HISTORY instead of DELETE VERSIONING ROWS: $old_grants->{$u}");
    }
  }
  foreach my $u (keys %$new_grants) {
    if ($new_grants->{$u} =~ s/DELETE VERSIONING ROWS/DELETE HISTORY/g) {
      say("Adjusted new grants for $u to have DELETE HISTORY instead of DELETE VERSIONING ROWS: $new_grants->{$u}");
    }
  }

  # MDEV-20076: In 10.3.23 / 10.4.13 / 10.5.2 single quotes in SHOW GRANTS
  # were changed to backticks:
  # Old: GRANT USAGE ON *.* TO 'zxa'
  # New: GRANT USAGE ON *.* TO `zxa`
  # And ORACLE mode uses double quotes.
  # We will replace single and double quotes with backticks
  # where it is surrounding identifiers, e.g. 'foo' => `foo` and 'foo'@'%' => `foo`@`%`,
  # and will remove all quotes elsewhere, e.g. in GRANT `rolename` TO ..

  foreach my $u (keys %$old_grants) {
    my ($username, $host);
    if ($u =~ /^`(.*)`@`(.*)`$/) {
      ($username, $host)= ($1, $2);
      $old_grants->{$u} =~ s/['"]$username['"]\@['"]$host['"]/`$username`@`$host`/;
      $new_grants->{$u} =~ s/['"]$username['"]\@['"]$host['"]/`$username`@`$host`/;
    } elsif ($u =~ /^`(.*)`$/) {
      ($username, $host)= ($1, '');
      $old_grants->{$u} =~ s/['"]$username['"]/`$username`/;
      $new_grants->{$u} =~ s/['"]$username['"]/`$username`/;
    }
    $old_grants->{$u} =~ s/GRANT [`'"](.*?)[`'"] TO/GRANT $1 TO/;
    $new_grants->{$u} =~ s/GRANT [`'"](.*?)[`'"] TO/GRANT $1 TO/;
  }

  foreach my $u (keys %$new_grants) {
    # MDEV-21743: In 10.5.2+ new grants were introduced, SUPER was prepared for further splitting up,
    # and some other reshuffling was done
    if ($old_server->versionNumeric lt '100502' and $new_server->versionNumeric ge '100502') {
      # MDEV-22152: As of 10.5.2, REPLICATION MASTER ADMIN is only given to users which have both SUPER and REPLICATION SLAVE
      if ($old_grants->{$u} =~ / SUPER(?:,| ON)/ and $old_grants->{$u} =~ / REPLICATION SLAVE(?:,| ON)/) {
        $old_grants->{$u} =~ s/ ON \*\.\*/, SET USER, FEDERATED ADMIN, CONNECTION ADMIN, READ_ONLY ADMIN, REPLICATION SLAVE ADMIN, REPLICATION MASTER ADMIN, BINLOG ADMIN, BINLOG REPLAY ON \*\.\*/;
      } elsif ($old_grants->{$u} =~ / SUPER(?:,| ON)/) {
        $old_grants->{$u} =~ s/ ON \*\.\*/, SET USER, FEDERATED ADMIN, CONNECTION ADMIN, READ_ONLY ADMIN, REPLICATION SLAVE ADMIN, BINLOG ADMIN, BINLOG REPLAY ON \*\.\*/;
      }
      # REPLICATION CLIENT renamed to BINLOG MONITOR
      $old_grants->{$u} =~ s/REPLICATION CLIENT/BINLOG MONITOR/;
    }
    if ($old_server->versionNumeric lt '100509' and $new_server->versionNumeric ge '100509' and $old_grants->{$u} !~ /SLAVE MONITOR/) {
      # Workaround for MDEV-23610 fix: SLAVE MONITOR is added
      #   for upgrade from 10.5.2-10.5.8 to REPLICATION SLAVE ADMIN grantees
      #   for upgrade from before 10.5.2 to REPLICATION CLIENT (a.k.a BINLOG MONITOR) and REPLICATION SLAVE grantees
      #     (but don't give it to REPLICATION SLAVE ADMIN which cannot come from the older version but which we previously added to SUPER users;
      #      due to MDEV-29650, simple pre-10.5.2 SUPER users don't get SLAVE MONITOR)
      if ( ($old_server->versionNumeric ge '100502' and $old_grants->{$u} =~ /REPLICATION SLAVE ADMIN/)
         or ($old_server->versionNumeric lt '100502' and $old_grants->{$u} =~ /(?:REPLICATION CLIENT|BINLOG MONITOR|REPLICATION SLAVE ON|REPLICATION SLAVE,)/)
      ) {
        $old_grants->{$u} =~ s/ ON \*\.\*/, SLAVE MONITOR ON \*\.\*/;
      }
    }

    # Until 10.3.28, 10.4.18 and 10.5.9 GRANT OPTION was missing for roles (MDEV-24289)
    if ($u !~ /.`@`./ and (($old_server->versionNumeric lt '100328') or ($old_server->versionNumeric ge '100400' and $old_server->versionNumeric lt '100418') or ($old_server->versionNumeric ge '100500' and $old_server->versionNumeric lt '100509'))) {
      $new_grants->{$u} =~ s/ WITH GRANT OPTION//;
    }
    # In 10.11.1 SUPER and READ_ONLY ADMIN were separated (MDEV-29596)
    if ($old_server->versionNumeric lt '101101' and $new_server->versionNumeric ge '101101' and $old_grants->{$u} =~ /SUPER/ and $old_grants->{$u} !~ /READ_ONLY ADMIN/) {
      $new_grants->{$u} =~ s/, READ_ONLY ADMIN//;
    }
    # In 11.0 SUPER and small privileges it included were separated (MDEV-29668)
#    if ($old_server->versionNumeric lt '110001' and $new_server->versionNumeric ge '110001' and $old_grants->{$u} =~ /SUPER/) {
#      foreach my $p ('SET USER','BINLOG ADMIN','BINLOG REPLAY','CONNECTION ADMIN','FEDERATED ADMIN','REPLICATION SLAVE ADMIN','SLAVE MONITOR','REPLICATION MASTER ADMIN') {
#        if($old_grants->{$u} !~ /$p/) {
#          $new_grants->{$u} =~ s/, $p//;
#        }
#      }
#    }
  }
}

sub compareAclData {
  my ($self, $old_grants, $new_grants)= @_;

  my $compare_status= STATUS_OK;
  foreach my $u (sort keys %$old_grants) {
    if (not exists $new_grants->{$u}) {
      sayError("User/role $u disappeared from the user table after upgrade");
      $compare_status= STATUS_UPGRADE_FAILURE;
    }
    elsif ($new_grants->{$u} ne $old_grants->{$u}) {
      sayError("Grants for user/role $u changed after upgrade:\nOld: $old_grants->{$u}\nNew: $new_grants->{$u}");
      $compare_status= STATUS_UPGRADE_FAILURE;
    }
  }

  foreach my $u (sort keys %$new_grants) {
    if (not exists $old_grants->{$u}) {
      sayError("User/role $u appeared in the user table after upgrade");
      $compare_status= STATUS_UPGRADE_FAILURE;
    }
  }

  if ($compare_status == STATUS_OK) {
    say("ACL comparison didn't reveal any discrepancies");
  } else {
    sayError("ACL comparison revealed discrepancies");
  }
  return $compare_status;
}


1;
