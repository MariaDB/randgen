# Copyright (C) 2017, 2018 MariaDB Corporation Ab
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
# The module implements a normal upgrade scenario with focus on ACL.
#
# The difference with the usual Upgrade test is that instead of
# comparing the raw database dumps before and after upgrade,
# we will compare the output of SHOW GRANT statements and such.
# There is no point comparing the structure and contents of system
# tables, we already know it will most likely differ; but the outcome
# should be generally the same
#
########################################################################

package GenTest::Scenario::AclUpgrade;

require Exporter;
@ISA = qw(GenTest::Scenario);

use strict;
use DBI;
use GenTest;
use GenTest::App::GenTest;
use GenTest::Properties;
use GenTest::Constants;
use GenTest::Scenario;
use Data::Dumper;
use File::Copy;
use File::Compare;

use DBServer::MySQL::MySQLd;

sub new {
  my $class= shift;
  my $self= $class->SUPER::new(@_);

  if (!defined ${$self->getProperty('basedir')}[2] or (${$self->getProperty('basedir')}[1] eq ${$self->getProperty('basedir')}[2])) {
    $self->printTitle('ACL - normal restart');
  }
  else {
    $self->printTitle('ACL - normal upgrade/downgrade');
  }

  if (not defined $self->getProperty('grammar')) {
    $self->setProperty('grammar', 'conf/mariadb/modules/acl.yy');
  }
  if (not defined $self->getProperty('threads')) {
    $self->setProperty('threads', 4);
  }

  return $self;
}

sub run {
  my $self= shift;
  my ($status, $old_server, $new_server, $gentest);
  my ($old_grants, $new_grants);

  $status= STATUS_OK;

  # We can initialize both servers right away, because the second one
  # runs with start_dirty, so it won't bootstrap

  $old_server= $self->prepareServer(1,
    {
      vardir => ${$self->getProperty('vardir')}[0],
      port => ${$self->getProperty('port')}[0],
      valgrind => 0,
    }
  );
  $new_server= $self->prepareServer(2,
    {
      vardir => ${$self->getProperty('vardir')}[0],
      port => ${$self->getProperty('port')}[0],
      start_dirty => 1
    }
  );

  say("-- Old server info: --");
  say($old_server->version());
  $old_server->printServerOptions();
  say("-- New server info: --");
  say($new_server->version());
  $new_server->printServerOptions();
  say("----------------------");

  #####
  $self->printStep("Starting the old server");

  $status= $old_server->startServer;

  if ($status != STATUS_OK) {
    sayError("Old server failed to start");
    return $self->finalize(STATUS_TEST_FAILURE,[]);
  }

  #####
  $self->printStep("Running test flow on the old server");

  $gentest= $self->prepareGentest(1,
    {
      duration => int($self->getTestDuration * 2 / 3),
      dsn => [$old_server->dsn($self->getProperty('database'))],
      servers => [$old_server],
    }
  );

  $status= $gentest->run();

  if ($status != STATUS_OK) {
    sayError("Test flow on the old server failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$old_server]);
  }

  #####
  $self->printStep("Getting ACL info from the old server");

  ($status, $old_grants)= $self->collectAclData($old_server);

  if ($status != STATUS_OK) {
    sayError("ACL info collection from the old server failed");
    $status= STATUS_TEST_FAILURE if $status < STATUS_TEST_FAILURE;
    return $self->finalize($status,[$old_server]);
  }

  #####
  $self->printStep("Stopping the old server");

  $status= $old_server->stopServer;

  if ($status != STATUS_OK) {
    sayError("Shutdown of the old server failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$old_server]);
  }

  #####
  $self->printStep("Checking the old server log for fatal errors after shutdown");

  $status= $self->checkErrorLog($old_server, {CrashOnly => 1});

  if ($status != STATUS_OK) {
    sayError("Found fatal errors in the log, old server shutdown has apparently failed");
    return $self->finalize(STATUS_TEST_FAILURE,[$old_server]);
  }

  #####
  $self->printStep("Backing up data directory from the old server");

  $old_server->backupDatadir($old_server->datadir."_orig");
  move($old_server->errorlog, $old_server->errorlog.'_orig');

  #####
  $self->printStep("Starting the new server");

  $status= $new_server->startServer;

  if ($status != STATUS_OK) {
    sayError("New server failed to start");
    # Error log might indicate known bugs which will affect the exit code
    $status= $self->checkErrorLog($new_server);
    # ... but even if it's a known error, we cannot proceed without the server
    return $self->finalize($status,[$new_server]);
  }

  #####
  $self->printStep("Checking the server error log for errors after upgrade");

  $status= $self->checkErrorLog($new_server);

  if ($status != STATUS_OK) {
    # Error log can show known errors. We want to update
    # the global status, but don't want to exit prematurely
    $self->setStatus($status);
    sayError("Found errors in the log after upgrade");
    if ($status > STATUS_CUSTOM_OUTCOME) {
      return $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]);
    }
  }

  #####
  if ($old_server->majorVersion ne $new_server->majorVersion) {
    $self->printStep("Running mysql_upgrade");
    $status= $new_server->upgradeDb;
    if ($status != STATUS_OK) {
      sayError("mysql_upgrade failed");
      return $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]);
    }
  }
  else {
    $self->printStep("mysql_upgrade is skipped, as servers have the same major version");
  }

  #####
  $self->printStep("Checking the database state after upgrade");

  $status= $new_server->checkDatabaseIntegrity;

  if ($status != STATUS_OK) {
    sayError("Database appears to be corrupt after upgrade");
    return $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]);
  }

  #####
  $self->printStep("Getting ACL info from the new server");

  ($status, $new_grants)= $self->collectAclData($new_server);

  if ($status != STATUS_OK) {
    sayError("ACL info collection from the new server failed");
    $status= STATUS_UPGRADE_FAILURE if $status < STATUS_UPGRADE_FAILURE;
    return $self->finalize($status,[$new_server]);
  }

  #####
  $self->printStep("Normalizing ACL data");
  $self->normalizeGrants($old_server, $new_server, $old_grants, $new_grants);

#  foreach my $u (keys %$old_grants) {
#    say("$u: $old_grants->{$u}");
#  }

  #####
  $self->printStep("Comparing ACL data before and after upgrade");

  foreach my $u (sort keys %$old_grants) {
    if (not exists $new_grants->{$u}) {
      sayError("User/role $u disappeared from the user table after upgrade");
      $status= STATUS_UPGRADE_FAILURE;
    }
    elsif ($new_grants->{$u} ne $old_grants->{$u}) {
      sayError("Grants for user/role $u changed after upgrade:\nOld: $old_grants->{$u}\nNew: $new_grants->{$u}");
      $status= STATUS_UPGRADE_FAILURE;
    }
  }

  foreach my $u (sort keys %$new_grants) {
    if (not exists $old_grants->{$u}) {
      sayError("User/role $u appeared in the user table after upgrade");
      $status= STATUS_UPGRADE_FAILURE;
    }
  }

  if ($status == STATUS_OK) {
    say("Comparison didn't reveal any discrepancies");
  } else {
    return $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]);
  }

  #####
  $self->printStep("Running test flow on the new server");

  $gentest= $self->prepareGentest(2,
    {
      duration => int($self->getTestDuration / 3),
      dsn => [$new_server->dsn($self->getProperty('database'))],
      servers => [$new_server],
      'start-dirty' => 1,
    },
    my $skip_gendata=1
  );
  $status= $gentest->run();

  if ($status != STATUS_OK) {
    sayError("Test flow on the new server failed");
    #####
    $self->printStep("Checking the server error log for known errors");

    if ($self->checkErrorLog($new_server) == STATUS_CUSTOM_OUTCOME) {
      $status= STATUS_CUSTOM_OUTCOME;
    }

    $self->setStatus($status);
    return $self->finalize($status,[$new_server])
  }

  #####
  $self->printStep("Stopping the new server");

  $status= $new_server->stopServer;

  if ($status != STATUS_OK) {
    sayError("Shutdown of the new server failed");
    return $self->finalize(STATUS_UPGRADE_FAILURE,[$new_server]);
  }

  return $self->finalize($status,[]);
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

}

sub collectAclData {
  my ($self, $server)= @_;
  my $res= STATUS_OK;

  say("Collecting user names");
  my $dbh= $server->dbh;
  my $has_roles= ($server->versionNumeric ge '1000');

  $dbh->do("FLUSH PRIVILEGES");

  my $query= "SELECT CONCAT('`',user,'`','\@','`',host,'`') FROM mysql.user";

  if ($has_roles) {
    $query.= " WHERE is_role = 'N'";
  }
  my $users= $dbh->selectcol_arrayref($query);
  if ($dbh->err() > 0) {
    sayError("Couldn't fetch users, error: ".$dbh->err()." (".$dbh->errstr().")");
    $users= [];
    $res= STATUS_DATABASE_CORRUPTION;
  }
  else {
    say("Found ".scalar(@$users)." users");
  }

  my $roles= [];
  if ($has_roles) {
    $roles= $dbh->selectcol_arrayref("SELECT CONCAT('`',user,'`') FROM mysql.user WHERE is_role = 'Y'");
    if ($dbh->err() > 0) {
      sayError("Couldn't fetch roles, error: ".$dbh->err()." (".$dbh->errstr().")");
      $roles= [];
      $res= STATUS_DATABASE_CORRUPTION;
    }
    else {
      say("Found ".scalar(@$roles)." roles");
    }
  }
  else {
    say("Server doesn't know anything about roles");
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
    if ($server->versionNumeric ge '0507') {
      $query= "SELECT CONCAT('`',user,'`','\@','`',host,'`') FROM mysql.user WHERE plugin != '' AND authentication_string = ''";
    } else {
      $query= "SELECT CONCAT('`',user,'`','\@','`',host,'`'), password FROM mysql.user WHERE plugin != '' AND password != '' AND authentication_string = ''";
    }

    my $plugin_users_with_passwords= $dbh->selectall_arrayref($query);
    if ($dbh->err() > 0) {
      sayError("Couldn't fetch plugin users with passwords, error: ".$dbh->err()." (".$dbh->errstr().")");
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
    my $sth= $dbh->prepare("SHOW GRANTS FOR $u");
    $sth->execute;
    if ($sth->err() > 0) {
      sayError("Couldn't fetch grants for $u, error: ".$sth->err()." (".$sth->errstr().")");
      $res= STATUS_TEST_FAILURE if $res < STATUS_TEST_FAILURE;
    }
    else {
      my $def= $sth->fetchrow_arrayref;
      if (defined $plugin_users_with_passwords{$u} and $def->[0] !~ /USING /) {
        $def->[0] =~ s/IDENTIFIED VIA (\w+)/IDENTIFIED VIA $1 USING \'$plugin_users_with_passwords{$u}\'/;
        say("Adjusted old grants for $u to show the password along with the plugin: $def->[0]");
      }
      $grants{$u}= $def->[0];
    }
  }

  return ($res, \%grants);
}



1;
