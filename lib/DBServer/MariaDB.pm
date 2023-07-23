# Copyright (c) 2010, 2012, Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, 2022, MariaDB
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

package DBServer::MariaDB;

@ISA = qw(DBServer);

use DBI;
use DBServer;
use GenUtil;
use if osWindows(), Win32::Process;
use Time::HiRes;
use POSIX ":sys_wait_h";
use Carp;
use Data::Dumper;
use File::Basename qw(dirname);
use File::Path qw(mkpath rmtree);
use File::Copy qw(move);

use strict;

use constant MYSQLD_BASEDIR => 0;
use constant MYSQLD_VARDIR => 1;
use constant MYSQLD_DATADIR => 2;
use constant MYSQLD_PORT => 3;
use constant MYSQLD_MYSQLD => 4;
use constant MYSQLD_LIBMYSQL => 5;
use constant MYSQLD_BOOT_SQL => 6;
use constant MYSQLD_STDOPTS => 7;
use constant MYSQLD_MESSAGES => 8;
use constant MYSQLD_CHARSETS => 9;
use constant MYSQLD_SERVER_OPTIONS => 10;
use constant MYSQLD_AUXPID => 11;
use constant MYSQLD_SERVERPID => 12;
use constant MYSQLD_DBH => 14;
use constant MYSQLD_START_DIRTY => 15;
use constant MYSQLD_VALGRIND => 16;
use constant MYSQLD_PERF => 17;
use constant MYSQLD_VERSION => 18;
use constant MYSQLD_DUMPER => 19;
use constant MYSQLD_SOURCEDIR => 20;
use constant MYSQLD_GENERAL_LOG => 21;
use constant MYSQLD_SERVER_TYPE => 23;
use constant MYSQLD_VALGRIND_SUPPRESSION_FILE => 24;
use constant MYSQLD_TMPDIR => 25;
use constant MYSQLD_CONFIG_FILE => 27;
use constant MYSQLD_USER => 28;
use constant MYSQLD_MAJOR_VERSION => 29;
use constant MYSQLD_CLIENT_BINDIR => 30;
use constant MYSLQD_SERVER_VARIABLES => 31;
use constant MYSQLD_RR => 32;
use constant MYSLQD_CONFIG_VARIABLES => 33;
use constant MYSQLD_CLIENT => 34;
use constant MARIABACKUP => 35;
use constant MYSQLD_MANUAL_GDB => 36;
use constant MYSQLD_HOST => 37;
use constant MYSQLD_ADMIN_DBH => 38;
use constant MYSQLD_METADATA_DBH => 39;
use constant MYSQLD_PS_PROTOCOL => 40;

use constant MYSQLD_PID_FILE => "mysql.pid";
use constant MYSQLD_ERRORLOG_FILE => "mysql.err";
use constant MYSQLD_LOG_FILE => "mysql.log";
use constant MYSQLD_DEFAULT_PORT =>  19300;
use constant MYSQLD_MAX_SERVER_DOWNTIME => 120;

my $default_shutdown_timeout= 300;

sub new {
    my $class = shift;

    my $self = $class->SUPER::new({'basedir' => MYSQLD_BASEDIR,
                                   'config' => MYSQLD_CONFIG_FILE,
                                   'general_log' => MYSQLD_GENERAL_LOG,
                                   'host' => MYSQLD_HOST,
                                   'manual_gdb' => MYSQLD_MANUAL_GDB,
                                   'perf' => MYSQLD_PERF,
                                   'port' => MYSQLD_PORT,
                                   'ps' => MYSQLD_PS_PROTOCOL,
                                   'rr' => MYSQLD_RR,
                                   'server_options' => MYSQLD_SERVER_OPTIONS,
                                   'sourcedir' => MYSQLD_SOURCEDIR,
                                   'start_dirty' => MYSQLD_START_DIRTY,
                                   'valgrind' => MYSQLD_VALGRIND,
                                   'vardir' => MYSQLD_VARDIR,
                                   'user' => MYSQLD_USER},@_,
                                   );

    croak "No valgrind support on windows" if osWindows() and defined $self->[MYSQLD_VALGRIND];
    croak "No rr support on windows" if osWindows() and $self->[MYSQLD_RR];
    croak "No perf support on windows" if osWindows() and $self->[MYSQLD_PERF];
    croak "Cannot use both rr and valgrind at once" if $self->[MYSQLD_RR] and defined $self->[MYSQLD_VALGRIND];
    croak "Cannot use both rr and perf at once" if $self->[MYSQLD_RR] and defined $self->[MYSQLD_PERF];
    croak "Cannot use both valgrind and perf at once" if $self->[MYSQLD_VALGRIND] and defined $self->[MYSQLD_PERF];
    croak "Vardir is not defined for the server" unless $self->[MYSQLD_VARDIR];

    if (osWindows()) {
        ## Use unix-style path's since that's what Perl expects...
        $self->[MYSQLD_BASEDIR] =~ s/\\/\//g;
        $self->[MYSQLD_VARDIR] =~ s/\\/\//g;
        $self->[MYSQLD_DATADIR] =~ s/\\/\//g;
    }

    if (not $self->_absPath($self->vardir)) {
        $self->[MYSQLD_VARDIR] = $self->basedir."/".$self->vardir;
    }

    # Default tmpdir for server.
    $self->[MYSQLD_TMPDIR] = $self->vardir."/tmp";

    $self->[MYSQLD_DATADIR] = $self->[MYSQLD_VARDIR]."/data";

    $self->[MYSQLD_MYSQLD] = $self->_find([$self->basedir],
                                          osWindows()?["sql/Debug","sql/RelWithDebInfo","sql/Release","bin"]:["sql","libexec","bin","sbin"],
                                          osWindows()?("mysqld.exe","mariadbd.exe"):("mysqld","mariadbd"));
    unless (defined $self->[MYSQLD_MYSQLD]) {
      croak("We could not find the server binary");
    }

    $self->serverType($self->[MYSQLD_MYSQLD]);

    $self->[MYSQLD_BOOT_SQL] = [];

    $self->[MYSQLD_DUMPER] = $self->_find([$self->basedir],
                                          osWindows()?["client/Debug","client/RelWithDebInfo","client/Release","bin"]:["client","bin"],
                                          osWindows()?("mysqldump.exe","mariadb-dump.exe"):("mysqldump","mariadb-dump"));

    $self->[MYSQLD_CLIENT] = $self->_find([$self->basedir],
                                          osWindows()?["client/Debug","client/RelWithDebInfo","client/Release","bin"]:["client","bin"],
                                          osWindows()?("mysql.exe","mariadb.exe"):("mysql","mariadb"));

    $self->[MARIABACKUP]= $self->_find([$self->basedir],
                            osWindows()?["client/Debug","client/RelWithDebInfo","client/Release","bin"]:["client","bin"],
                            osWindows()?"mariabackup.exe":"mariabackup"
                          );

    $self->[MYSQLD_CLIENT_BINDIR] = dirname($self->[MYSQLD_DUMPER]);

    $self->[MYSQLD_HOST] = '127.0.0.1' unless $self->[MYSQLD_HOST];

    ## Check for CMakestuff to get hold of source dir:

    if (not defined $self->sourcedir) {
        if (-e $self->basedir."/CMakeCache.txt") {
            open CACHE, $self->basedir."/CMakeCache.txt";
            while (<CACHE>){
                if (m/^MySQL_SOURCE_DIR:STATIC=(.*)$/) {
                    $self->[MYSQLD_SOURCEDIR] = $1;
                    say("Found source directory at ".$self->[MYSQLD_SOURCEDIR]);
                    last;
                }
            }
        }
    }

    ## Use valgrind suppression file if available in mysql-test path.
    if (defined $self->[MYSQLD_VALGRIND]) {
        $self->[MYSQLD_VALGRIND_SUPPRESSION_FILE] = $self->_find(defined $self->sourcedir?[$self->basedir,$self->sourcedir]:[$self->basedir],
                                                             ["share/mysql-test","mysql-test","mariadb-test"],
                                                             "valgrind.supp")
    };

    foreach my $fileref (['mysql_system_tables.sql', 'mariadb_system_tables.sql'],
                         ['mysql_performance_tables.sql', 'mariadb_performance_tables.sql'],
                         ['mysql_system_tables_data.sql', 'mariadb_system_tables_data.sql'],
                         ['fill_help_tables.sql'],
                         ['maria_add_gis_sp_bootstrap.sql'],
                         ['mysql_sys_schema.sql', 'mariadb_sys_schema.sql']
                        ) {
        my $script =
             eval { $self->_find(defined $self->sourcedir?[$self->basedir,$self->sourcedir]:[$self->basedir],
                          ["scripts","share/mysql","share"], @$fileref) };
        push(@{$self->[MYSQLD_BOOT_SQL]},$script) if $script;
    }

    $self->[MYSQLD_MESSAGES] =
       $self->_findDir(defined $self->sourcedir?[$self->basedir,$self->sourcedir]:[$self->basedir],
                       ["sql/share","share/mysql","share"], "english/errmsg.sys");

    $self->[MYSQLD_CHARSETS] =
        $self->_findDir(defined $self->sourcedir?[$self->basedir,$self->sourcedir]:[$self->basedir],
                        ["sql/share/charsets","share/mysql/charsets","share/charsets"], "Index.xml");


    $self->[MYSQLD_STDOPTS] = ["--basedir=".$self->basedir,
                               $self->_messages,
                               "--character-sets-dir=".$self->[MYSQLD_CHARSETS],
                               "--tmpdir=".$self->tmpdir];

    if ($self->[MYSQLD_START_DIRTY]) {
        say("Using existing data for server " .$self->version ." at ".$self->datadir);
    } else {
        say("Creating " . $self->version . " database at ".$self->datadir);
        if ($self->createMysqlBase != DBSTATUS_OK) {
            sayError("FATAL ERROR: Bootstrap failed, cannot proceed!");
            return undef;
        }
    }

    return $self;
}

sub basedir {
    return $_[0]->[MYSQLD_BASEDIR];
}

sub sourcedir {
    return $_[0]->[MYSQLD_SOURCEDIR];
}

sub datadir {
    return $_[0]->[MYSQLD_DATADIR];
}

sub vardir {
    return $_[0]->[MYSQLD_VARDIR];
}

sub tmpdir {
    return $_[0]->[MYSQLD_TMPDIR];
}

sub port {
    my ($self) = @_;

    if (defined $self->[MYSQLD_PORT]) {
        return $self->[MYSQLD_PORT];
    } else {
        return MYSQLD_DEFAULT_PORT;
    }
}

sub user {
    return $_[0]->[MYSQLD_USER];
}

sub serverpid {
    return $_[0]->[MYSQLD_SERVERPID];
}

sub server_options {
  return $_[0]->[MYSQLD_SERVER_OPTIONS];
}

sub socketfile {
    my ($self) = @_;
    my $socketFileName = $_[0]->vardir."/mysql.sock";
    if (length($socketFileName) >= 100) {
  $socketFileName = "/tmp/RQGmysql.".$self->port.".sock";
    }
    return $socketFileName;
}

sub pidfile {
    return $_[0]->vardir."/".MYSQLD_PID_FILE;
}

sub logfile {
    return $_[0]->vardir."/".MYSQLD_LOG_FILE;
}

sub errorlog {
    return $_[0]->vardir."/".MYSQLD_ERRORLOG_FILE;
}

sub setStartDirty {
    $_[0]->[MYSQLD_START_DIRTY] = $_[1];
}

sub valgrind_suppressionfile {
    return $_[0]->[MYSQLD_VALGRIND_SUPPRESSION_FILE] ;
}

#sub libmysqldir {
#    return $_[0]->[MYSQLD_LIBMYSQL];
#}

# Check the type of mysqld server.
sub serverType {
    my ($self, $mysqld) = @_;
    $self->[MYSQLD_SERVER_TYPE] = "Release";

    my $command="$mysqld --version";
    my $result=`$command 2>&1`;

    $self->[MYSQLD_SERVER_TYPE] = "Debug" if ($result =~ /debug/sig);
    return $self->[MYSQLD_SERVER_TYPE];
}

sub generateCommand {
    my ($self, @opts) = @_;

    my $command = '"'.$self->binary.'"';
    foreach my $opt (@opts) {
        $command .= ' '.join(' ',map{'"'.$_.'"'} @$opt);
    }
    $command =~ s/\//\\/g if osWindows();
    return $command;
}

sub addServerOptions {
    my ($self,$opts) = @_;

    push(@{$self->[MYSQLD_SERVER_OPTIONS]}, @$opts);
}

sub printServerOptions {
    my $self = shift;
    foreach (@{$self->[MYSQLD_SERVER_OPTIONS]}) {
        say("    $_");
    }
}

sub systemSchemas {
  return ('mysql','performance_schema','information_schema','sys');
}

sub systemSchemaList {
  join ',', (map { "'$_'" } ($_[0]->systemSchemas()));
}

sub createMysqlBase  {
    my ($self) = @_;

    ## Clean old db if any
    if (-d $self->vardir) {
        rmtree($self->vardir);
    }
    ## Create database directory structure
    mkpath($self->vardir);
    mkpath($self->tmpdir);
    mkpath($self->datadir);

    my $defaults = ($self->[MYSQLD_CONFIG_FILE] ? "--defaults-file=$self->[MYSQLD_CONFIG_FILE]" : "--no-defaults");

    ## Create boot file

    my $boot = $self->vardir."/boot.sql";
    open BOOT,">$boot";

    ## Boot database

    my $boot_options = [$defaults];
    push @$boot_options, @{$self->[MYSQLD_STDOPTS]};
    push @$boot_options, "--datadir=".$self->datadir; # Could not add to STDOPTS, because datadir could have changed


    if ($self->_olderThan(5,6,3)) {
        push(@$boot_options,"--loose-skip-innodb", "--default-storage-engine=MyISAM") ;
    } else {
        push(@$boot_options, @{$self->[MYSQLD_SERVER_OPTIONS]});
    }
    push @$boot_options, "--skip-log-bin";
    push @$boot_options, "--loose-enforce-storage-engine=";
    #push @$boot_options, "--loose-innodb-encrypt-tables=OFF";
    #push @$boot_options, "--loose-innodb-encrypt-log=OFF";
    # Set max-prepared-stmt-count to a sufficient value to facilitate bootstrap
    # even if it's otherwse set to 0 for the server
    push @$boot_options, "--max-prepared-stmt-count=1024";
    # Spider tends to hang on bootstrap (MDEV-22979)
    push @$boot_options, "--loose-disable-spider";
    # Workaround for MENT-350
    if ($self->_notOlderThan(10,4,6)) {
        push @$boot_options, "--loose-server-audit-logging=OFF";
    }
    # Workaround for MDEV-29197
    push @$boot_options, "--loose-skip-s3";
    # Don't enforce password checks
    push @$boot_options, "--loose-skip-cracklib-password-check";
    push @$boot_options, "--loose-skip-simple-password-check";
    push @$boot_options, "--loose-skip-password-reuse-check";

    my $command;

    if (not $self->_isMySQL or $self->_olderThan(5,7,5)) {

       # Add the whole init db logic to the bootstrap script
       print BOOT "CREATE DATABASE mysql;\n";
       print BOOT "USE mysql;\n";
       foreach my $b (@{$self->[MYSQLD_BOOT_SQL]}) {
            open B,$b;
            while (<B>) { print BOOT $_;}
            close B;
        }

        push(@$boot_options,"--bootstrap") ;
        $command = $self->generateCommand($boot_options);
        $command = "$command < \"$boot\"";
    } else {
        push @$boot_options, "--initialize-insecure", "--init-file=$boot";
        $command = $self->generateCommand($boot_options);
    }

    my $usertable= ($self->versionNumeric() gt '100400' ? 'global_priv' : 'user');

    ## Add last strokes to the boot/init file: don't want empty users, but want the test user instead
    print BOOT "USE mysql;\n";
    print BOOT "DELETE FROM $usertable WHERE `User` = '';\n";
    print BOOT "FLUSH PRIVILEGES;\n";
    print BOOT "CREATE DATABASE IF NOT EXISTS transforms;\n";
    print BOOT "CREATE DATABASE IF NOT EXISTS test;\n";
    print BOOT "CREATE TABLE IF NOT EXISTS mysql.rqg_feature_registry (feature VARCHAR(64), PRIMARY KEY(feature)) ENGINE=Aria;\n";
    if ($self->user ne 'root') {
        my $user= $self->user.'@localhost';
        print BOOT "CREATE ROLE admin;\n";
        print BOOT "GRANT ALL ON *.* TO admin WITH GRANT OPTION;\n";
        print BOOT "CREATE USER $user;\n";
        print BOOT "GRANT /*!100502 BINLOG ADMIN, BINLOG MONITOR, BINLOG REPLAY, CONNECTION ADMIN, FEDERATED ADMIN, ".
                                   "READ_ONLY ADMIN, REPLICATION MASTER ADMIN, REPLICATION REPLICA, REPLICATION SLAVE ADMIN, SET USER, */ ".
                         "/*!100509 REPLICA MONITOR, */ ".
                   "CREATE USER, FILE, PROCESS, RELOAD, REPLICATION CLIENT, SHOW DATABASES, SHUTDOWN, SUPER ON *.* TO $user;\n";
        print BOOT "GRANT CREATE, SELECT ON *.* TO $user;\n";
        print BOOT "GRANT ALL ON test.* TO $user;\n";
        print BOOT "GRANT ALL ON transforms.* TO $user;\n";
        print BOOT "GRANT ALL ON mysql.rqg_feature_registry TO $user;\n";
        print BOOT "GRANT INSERT, UPDATE, DELETE ON performance_schema.* TO $user;\n";
        print BOOT "GRANT EXECUTE ON sys.* TO $user;\n";
        if ($self->_notOlderThan(10,4,0)) {
          print BOOT "UPDATE mysql.global_priv SET Priv = JSON_INSERT(Priv, '\$.password_lifetime', 0) WHERE user in('".$self->user."', 'root');\n";
        }
        print BOOT "DELETE FROM mysql.roles_mapping WHERE Role = 'admin';\n";
        print BOOT "INSERT INTO mysql.roles_mapping VALUES ('localhost','".$self->user."','admin','Y');\n";
    }
    close BOOT;

    say("Bootstrap command: $command");
    system("$command > \"".$self->vardir."/boot.log\" 2>&1");
    return $?;
}

sub startServer {
    my ($self) = @_;

  my @defaults = ($self->[MYSQLD_CONFIG_FILE] ? ("--defaults-group-suffix=.runtime", "--defaults-file=$self->[MYSQLD_CONFIG_FILE]") : ("--no-defaults"));

    my ($v1,$v2,@rest) = $self->versionNumbers;
    my $v = $v1*1000+$v2;
    my $command = $self->generateCommand([@defaults],
                                         $self->[MYSQLD_STDOPTS],
                                         ["--core-file",
                                          "--datadir=".$self->datadir,  # Could not add to STDOPTS, because datadir could have changed
                                          "--port=".$self->port,
                                          "--socket=".$self->socketfile,
                                          "--pid-file=".$self->pidfile],
                                         $self->_logOptions);
    my @extra_opts= ( '--max-allowed-packet=1G', # Allow loading bigger blobs
                      '--loose-innodb-ft-min-token-size=10', # Workaround for MDEV-25324
                      '--secure-file-priv=', # Make sure that LOAD_FILE and such works
                      (defined $self->[MYSQLD_SERVER_OPTIONS] ? @{$self->[MYSQLD_SERVER_OPTIONS]} : ())
                    );

    say("Final startup options for server on port ".$self->port.":\n".
      join(' ', @extra_opts));
    say("Final options for server on port ".$self->port.", MTR style:\n".
      join(' ', map {'--mysqld='.$_} @extra_opts));

    $command = $command." ".join(' ',@extra_opts);

    # If we don't remove the existing pidfile,
    # the server will be considered started too early, and further flow can fail
    unlink($self->pidfile);
    $self->[MYSQLD_SERVERPID]= undef;

    my $errorlog = $self->vardir."/".MYSQLD_ERRORLOG_FILE;

    # In seconds, timeout for the server to start updating error log
    # (to write "Starting MariaDB..." or "starting as process" record)
    # after the server startup command has been launched
    my $start_wait_timeout= 30;

    # In seconds, timeout for the server to create pid file
    # after it has started updating the error log
    # (before the server is considered hanging)
    my $startup_timeout= 600;

    if ($self->[MYSQLD_RR]) {
        $command = "rr record -h --output-trace-dir=".$self->vardir."/rr_profile_".time()." ".$command;
    }
    elsif ($self->[MYSQLD_PERF]) {
        $command= "perf record -o ".$self->vardir."/perf_data_".time()." ".$command;
    }
    elsif (defined $self->[MYSQLD_VALGRIND]) {
        my $val_opt ="";
        $start_wait_timeout= 60;
        $startup_timeout= MYSQLD_MAX_SERVER_DOWNTIME * 10;
        if ($self->[MYSQLD_VALGRIND]) {
            $val_opt = $self->[MYSQLD_VALGRIND];
        }
        $command = "valgrind --time-stamp=yes --leak-check=yes --suppressions=".$self->valgrind_suppressionfile." ".$val_opt." ".$command;
    }
    $self->printInfo;

    my $errlog_last_update_time= (stat($errorlog))[9] || 0;
    my $number_of_previous_starts= 0;
    if (-f $errorlog) {
      $number_of_previous_starts= `grep -Ec 'Starting MariaDB .* as process [0-9][0-9]*|starting as process [0-9][0-9]*' $errorlog`;
    }
    chomp $number_of_previous_starts;
    say("Starting server ".$self->version.": $command");

    $self->[MYSQLD_AUXPID] = fork();
    if ($self->[MYSQLD_AUXPID]) {

        my $wait_time = 0.5;
        my $waits= 0;
        my $pid= undef;
        my $wait_end= time() + $start_wait_timeout;

        # After we've launched server startup, we'll wait for max $start_wait_timeout seconds
        # for the server to start updating the error log or to create a pid file
        while (time() < $wait_end) {
          Time::HiRes::sleep($wait_time);
          sayDebug("Waiting for PID file or PID in the log file");
          if (-f $self->pidfile) {
            $pid= get_pid_from_file($self->pidfile);
            say("PID file has been created and contains $pid");
            last;
          }
          my $update_time= (stat($errorlog))[9] || 0;
          if ($update_time > $errlog_last_update_time) {
            $errlog_last_update_time= $update_time;
            my $number_of_starts= `grep -Ec 'Starting MariaDB .* as process [0-9][0-9]*|starting as process [0-9][0-9]*' $errorlog`;
            chomp $number_of_starts;
            if ($number_of_starts > $number_of_previous_starts) {
              $pid= `grep -E 'Starting MariaDB .* as process [0-9][0-9]*|starting as process [0-9][0-9]*' $errorlog | tail -n 1 | sed -e 's/.*as process \\([0-9]*\\).*/\\1/'`;
              chomp $pid;
              if ($pid and $pid =~ /^\d+$/) {
                say("Pid file " . $self->pidfile . " does not exist and timeout hasn't passed yet, but the error log has already been updated and contains pid $pid");
                last;
              } elsif ($pid) {
                sayWarning("Pid was detected wrongly: '$pid', discarding");
                $pid= undef;
              }
            }
          }
        }

        # We can be here because either
        # - the server has created PID file,
        # - or the server has written PID in the error log or in the pid file and we have detected it;
        # - or the server hasn't written the "Starting" line in the error log and timeout for doing it has exceeded

        # Undefined pid means the latter case, which is probably hopeless --
        # either it died before writing "Starting", or it didn't even attempt to start, or it's a wrong log
        if (!$pid) {
            sayError("Server has not started written a starting line into the error log $errorlog within $start_wait_timeout sec. timeout, and has not created pid file");
            sayFile($errorlog);
            return DBSTATUS_FAILURE;
        }

        # If the server has written a starting line in the log, we should see whether that process is still alive
        unless (kill(0,$pid)) {
          sayError("Server attempted to start with pid $pid, but the process no longer exists");
          sayFile($errorlog);
          return DBSTATUS_FAILURE;
        }

        # If the process is still alive, but the pid file is not created yet,
        # the server is probably undergoing a lengthy startup, e.g. doing recovery.
        # We need to wait for PID file to be created

        $wait_end= time() + $startup_timeout;
        while ((! -f $self->pidfile()) and kill(0,$pid) and time() < $wait_end) {
          sayDebug("Waiting for PID file ".$self->pidfile()." to be created");
          sleep 1;
        }

        if (! kill(0,$pid)) {
          sayError("Server with pid $pid died before it finished startup");
          sayFile($errorlog);
          return DBSTATUS_FAILURE;
        }

        if (! -f $self->pidfile()) {
          sayError("Server with pid $pid hasn't created PID file ".$self->pidfile()." and the timeout has exceeded, it is probably hanging");
          sayFile($errorlog);
          # Try to generate a coredump
          $self->kill('SEGV');
          return DBSTATUS_FAILURE;
        }

        # If we are here, the server has created a PID file and is still alive

        $self->[MYSQLD_SERVERPID] = int($pid);
        say("Server started with PID ".$self->[MYSQLD_SERVERPID]);
    } else {
        exec("$command >> \"$errorlog\"  2>&1") || croak("Could not start mysql server");
    }

    if ($self->waitForServerToStart && $self->dbh) {
        $self->serverVariables();
        if ($self->[MYSQLD_MANUAL_GDB]) {
          say("Pausing test to allow attaching debuggers etc. to the server process ".$self->[MYSQLD_SERVERPID].".");
          say("Press ENTER to continue the test run...");
          my $keypress = <STDIN>;
        }
        return DBSTATUS_OK;
    } else {
        return DBSTATUS_FAILURE;
    }
}

sub kill {
    my ($self, $signal) = @_;
    $signal= 'KILL' unless defined $signal;

    my $pidfile= $self->pidfile;

    if (not defined $self->serverpid and -f $pidfile) {
        $self->[MYSQLD_SERVERPID]= get_pid_from_file($self->pidfile);
    }

    if (defined $self->serverpid and $self->serverpid =~ /^\d+$/) {
        kill $signal => $self->serverpid;
        my $sleep_time= 0.2;
        my $waits = int($default_shutdown_timeout / $sleep_time);
        while ($self->running && $waits) {
            Time::HiRes::sleep($sleep_time);
            $waits--;
        }
        unless ($waits) {
            sayError("Unable to kill process ".$self->serverpid);
        } else {
            say("Killed process ".$self->serverpid." with $signal");
        }
    }

    # clean up when the server is not alive.
    unlink $self->socketfile if -e $self->socketfile;
    unlink $self->pidfile if -e $self->pidfile;
    $self->[MYSQLD_SERVERPID]= undef;
    return ($self->running ? DBSTATUS_FAILURE : DBSTATUS_OK);
}

sub term {
    my ($self) = @_;

    my $res;
    if (defined $self->serverpid) {
        kill TERM => $self->serverpid;
        my $sleep_time= 0.2;
        my $waits = int($default_shutdown_timeout / $sleep_time);
        while ($self->running && $waits) {
            Time::HiRes::sleep($sleep_time);
            $waits--;
        }
        unless ($waits) {
            say("Unable to terminate process ".$self->serverpid.". Trying SIGABRT");
            kill ABRT => $self->serverpid;
            $res= DBSTATUS_FAILURE;
            $waits= int($default_shutdown_timeout / $sleep_time);
            while ($self->running && $waits) {
              Time::HiRes::sleep($sleep_time);
              $waits--;
            }
            unless ($waits) {
              say("SIGABRT didn't work for process ".$self->serverpid.". Trying KILL");
              $self->kill;
            }
        } else {
            say("Terminated process ".$self->serverpid);
            $res= DBSTATUS_OK;
        }
    }
    if (-e $self->socketfile) {
        unlink $self->socketfile;
    }
    $self->[MYSQLD_SERVERPID]= undef;
    return $res;
}

sub crash {
    my ($self) = @_;

    if (defined $self->serverpid) {
        kill SEGV => $self->serverpid;
        say("Crashed process ".$self->serverpid);
    }

    # clean up when the server is not alive.
    unlink $self->socketfile if -e $self->socketfile;
    unlink $self->pidfile if -e $self->pidfile;
    $self->[MYSQLD_SERVERPID]= undef;
}

sub corefile {
    my ($self) = @_;
    # It can end up being named differently, depending on system settings,
    # it's just the best guess
    return $self->datadir."/core";
}

sub upgradeDb {
  my $self= shift;

  my $mysql_upgrade= $self->_find([$self->basedir],
                                        osWindows()?["client/Debug","client/RelWithDebInfo","client/Release","bin"]:["client","bin"],
                                        osWindows()?"mysql_upgrade.exe":"mysql_upgrade");
  my $upgrade_command=
    '"'.$mysql_upgrade.'" --host='.$self->host.' --port='.$self->port.' -uroot';
  my $upgrade_log= $self->datadir.'/mysql_upgrade.log';
  say("Running mysql_upgrade:\n  $upgrade_command");
  my $res= system("$upgrade_command > $upgrade_log 2>&1");
  if ($res == DBSTATUS_OK) {
    # mysql_upgrade can return exit code 0 even if user tables are corrupt,
    # so we don't trust the exit code, we should also check the actual output
    if (open(UPGRADE_LOG, "$upgrade_log")) {
     OUTER_READ:
      while (<UPGRADE_LOG>) {
        # For now we will only check 'Repairing tables' section,
        # and if there are any errors, we'll consider it a failure
        next unless /Repairing tables/;
        while (<UPGRADE_LOG>) {
          if (/^\s*Error/) {
            $res= DBSTATUS_FAILURE;
            sayError("Found errors in mysql_upgrade output");
            sayFile("$upgrade_log");
            last OUTER_READ;
          }
        }
      }
      close (UPGRADE_LOG);
    } else {
      sayError("Could not find $upgrade_log");
      $res= DBSTATUS_FAILURE;
    }
  } else {
    sayError("mysql_upgrade returned non-okay status");
    sayFile($upgrade_log) if (-e $upgrade_log);
  }
  return $res;
}

sub dumper {
    return $_[0]->[MYSQLD_DUMPER];
}

sub client {
  return $_[0]->[MYSQLD_CLIENT];
}

sub mariabackup {
  return $_[0]->[MARIABACKUP];
}

sub drop_broken {
  my $self= shift;
  my $dbh= $self->dbh;
  say("Checking view and merge table consistency");
  # In case it was set to READ ONLY before
  $dbh->do("SET SESSION TRANSACTION READ WRITE");
  while (1) {
    my $broken= $dbh->selectall_arrayref("select * from information_schema.tables where table_comment like 'Unable to open underlying table which is differently defined or of non-MyISAM type or%' or table_comment like '%references invalid table(s) or column(s) or function(s) or definer/invoker of view lack rights to use them' or table_comment like 'Table % is differently defined or of non-MyISAM type or%'");
    last unless ($broken && scalar(@$broken));
    # If we don't succeed to drop anything in a round, we'll give up
    my $count= 0;
    foreach my $vt (@$broken) {
      my $fullname= '`'.$vt->[1].'`.`'.$vt->[2].'`';
      my $type= ($vt->[3] eq 'VIEW' ? 'view' : 'table');
      my $err= $vt->[20];
      sayWarning("Error $err for $type $fullname, dropping");
      $dbh->do("DROP $type $fullname");
      if ($dbh->err) {
        sayWarning("Failed to drop $type $fullname: ".$dbh->err."(".$dbh->errstr.")");
      } else {
        $count++;
      }
    }
    if ($count == 0) {
      sayError("Couldn't drop any of ".scalar(@$broken)." broken objects, giving up");
      return DBSTATUS_FAILURE;
    }
  }
  return DBSTATUS_OK;
}

# dumpdb is performed in two modes.
# One is for comparison. In this case certain objects are disabled,
# data and schema are dumped separately, and data is sorted.
# Another one is for restoring the dump. In this case a "normal"
# dump is perfomed, all together and without suppressions

sub dumpdb {
    my ($self,$database,$file,$for_restoring,$options) = @_;
    my $dbh= $self->dbh;
    $dbh->do('SET GLOBAL max_statement_time=0');
    if ($self->drop_broken() != DBSTATUS_OK) {
      return DBSTATUS_FAILURE;
    }
    if ($for_restoring) {
      # Workaround for MDEV-29936 (unique ENUM/SET with invalid values cause problems)
      my $enums= $self->dbh->selectall_arrayref(
        "select cols.table_schema, cols.table_name, cols.column_name from information_schema.columns cols ".
        "join information_schema.table_constraints constr on (cols.table_schema = constr.constraint_schema and cols.table_name = constr.table_name) ".
        "join information_schema.statistics stat on (constr.constraint_name = stat.index_name and cols.table_schema = stat.table_schema and cols.table_name = stat.table_name and cols.column_name = stat.column_name) ".
        "where (column_type like 'enum%' or column_type like 'set%') and constraint_type in ('UNIQUE','PRIMARY KEY')"
      );
      foreach my $e (@$enums) {
        $self->dbh->do("delete ignore from $e->[0].$e->[1] where $e->[2] = 0 /* dropping enums with invalid values */");
      }
      # Workaround for MDEV-29941 (spatial columns in primary keys cause problems)
      # We can't just drop PK because it may also contain auto-increment columns.
      # And we can't just drop the spatial column because it's not allowed when it participates in PK.
      # So we will first find out if there are other columns in PK. If not, we'll just drop the PK.
      # Otherwise, we'll try to re-create it but without the spatial column.
      # POINT is not affected
      my $spatial_pk= $self->dbh->selectall_arrayref(
        "select table_schema, table_name, column_name from information_schema.columns ".
        "where column_type in ('linestring','polygon','multipoint','multilinestring','multipolygon','geometrycollection','geometry') and column_key = 'PRI'"
      );
      foreach my $c (@$spatial_pk) {
        my @pk= $self->dbh->selectrow_array(
          "select group_concat(if(sub_part is not null,concat(column_name,'(',sub_part,')'),column_name)) from information_schema.statistics ".
          "where table_schema = '$c->[0]' and table_name = '$c->[1]' and index_name = 'PRIMARY' and column_name != '$c->[2]' order by seq_in_index"
        );
        if (@pk and $pk[0] ne '') {
          $self->dbh->do("alter ignore table $c->[0].$c->[1] drop primary key, add primary key ($pk[0]) /* re-creating primary key containing spatial columns */");
        } else {
          $self->dbh->do("alter ignore table $c->[0].$c->[1] drop primary key /* dropping primary key containing spatial columns */");
        }
      }
      # Workaround for MDEV-30296 (triggers on MERGE tables may cause problems);
      my $merge_triggers= $self->dbh->selectcol_arrayref(
        "select concat(trigger_schema,'.',trigger_name) from information_schema.triggers tr join information_schema.tables tb ".
        "on (trigger_schema = table_schema and event_object_table = table_name) ".
        "where engine='MRG_MyISAM'"
      );
      foreach my $t (@$merge_triggers) {
        $self->dbh->do("drop trigger $t");
      }
    } # End of $for_restoring

    my $databases= '--all-databases';
    if ($database && scalar(@$database) > 1) {
      $databases= "--databases @$database";
    } elsif ($database) {
      $databases= "$database->[0]";
    }
    # --skip-disable-keys due to MDEV-26253
    my $dump_command= '"'.$self->dumper.'" --skip-disable-keys --skip-dump-date -uroot --host='.$self->host.' --port='.$self->port.' --hex-blob '.$databases;
    unless ($for_restoring) {
      my @heap_tables= @{$self->dbh->selectcol_arrayref(
          "select concat(table_schema,'.',table_name) from ".
          "information_schema.tables where engine='MEMORY' and table_schema not in (".$self->systemSchemaList().")"
        )
      };
      my $skip_heap_tables= join ' ', map {'--ignore-table-data='.$_} @heap_tables;
      $dump_command.= " --compact --order-by-primary --skip-extended-insert --no-create-info --skip-triggers $skip_heap_tables";
    }
    $dump_command.= " $options";

    say("Dumping server ".$self->version.($for_restoring ? " for restoring":" data for comparison")." on port ".$self->port);
    say($dump_command);
    my $dump_result = ($for_restoring ?
      system("$dump_command 2>&1 1>$file") :
      system("$dump_command | sort 2>&1 1>$file")
    );
    return $dump_result;
}

# dumpSchema is only performed for comparison

sub dumpSchema {
    my ($self,$database, $file) = @_;

    if ($self->drop_broken() != DBSTATUS_OK) {
      return DBSTATUS_FAILURE;
    }

    my $databases= '--all-databases --add-drop-database';
    if ($database && scalar(@$database) > 1) {
      $databases= "--databases @$database";
    } elsif ($database) {
      $databases= "$database->[0]";
    }

    my $dump_command = '"'.$self->dumper.'"'.
                             "  --skip-dump-date --compact --no-tablespaces".
                             " --no-data --host=".$self->host.
                             " -uroot".
                             " --port=".$self->port.
                             " $databases";
    say($dump_command);
    my $dump_result = system("$dump_command 2>&1 1>$file");
    if ($dump_result != 0) {
      # MDEV-28577: There can be Federated tables with virtual columns, they make mysqldump fail

      my $vcol_tables= $self->dbh->selectall_arrayref(
          "SELECT DISTINCT CONCAT(ist.TABLE_SCHEMA,'.',ist.TABLE_NAME), ist.ENGINE ".
          "FROM INFORMATION_SCHEMA.TABLES ist JOIN INFORMATION_SCHEMA.COLUMNS isc ON (ist.TABLE_SCHEMA = isc.TABLE_SCHEMA AND ist.TABLE_NAME = isc.TABLE_NAME) ".
          "WHERE IS_GENERATED = 'ALWAYS'"
        );

      my $retry= 0;
      foreach my $t (@$vcol_tables) {
        if ($t->[1] eq 'FEDERATED') {
          say("Dropping Federated table $t->[0] as it has virtual columns");
          if ($self->dbh->do("DROP TABLE $t->[0]")) {
            $retry= 1;
          } else {
            $retry= 0;
            sayError("Failed to drop Federated table $t->[0] which contains virtual columns, mysqldump won't succeed: ".$self->dbh->err.": ".$self->dbh->errstr());
            last;
          }
        }
      }

      if ($retry) {
        say("Retrying mysqldump after dropping broken Federated tables");
        return $self->dumpSchema($database, $file);
      }

      sayError("Dump failed, trying to collect some information");
      system($self->[MYSQLD_CLIENT_BINDIR]."/mysql -uroot --protocol=tcp --port=".$self->port." -e 'SHOW FULL PROCESSLIST'");
      system($self->[MYSQLD_CLIENT_BINDIR]."/mysql -uroot --protocol=tcp --port=".$self->port." -e 'SELECT * FROM INFORMATION_SCHEMA.METADATA_LOCK_INFO'");
    }
    return $dump_result;
}

# There are some known expected differences in dump structure between
# older and newer versions.
# We need to "normalize" the dumps to avoid false positives while comparing them.
# Optionally, we can also remove AUTOINCREMENT=N clauses.
# The old file is stored in <filename_orig>.
sub normalizeDump {
  my ($self, $file, $remove_autoincs)= @_;
  if ($remove_autoincs) {
    say("normalizeDump removes AUTO_INCREMENT clauses from table definitions");
    move($file, $file.'.tmp1');
    open(DUMP1,$file.'.tmp1');
    open(DUMP2,">$file");
    while (<DUMP1>) {
      if (s/ AUTO_INCREMENT=\d+//) {};
      print DUMP2 $_;
    }
    close(DUMP1);
    close(DUMP2);
  }
  # MDEV-29001
  say("normalizeDump patches absent DEFAULT NULL clauses (workaround for MDEV-29001)");
  move($file, $file.'.tmp2');
  open(DUMP1,$file.'.tmp2');
  open(DUMP2,">$file");
  while (<DUMP1>) {
    # -  `col_date_nokey` date,
    # +  `col_date_nokey` date DEFAULT NULL,
    # etc.
    if (/^(\s+\`.*?\`\s+\w+(?:\(\d+\))?.*?)(,?)$/) {
      my $def= $1;
      my $last= $2 || '';
      if ($def !~ /(?:DEFAULT NULL|NOT NULL|GENERATED ALWAYS)/) {
        $def= $def." DEFAULT NULL";
      }
      print DUMP2 "$def$last";
    } else {
      print DUMP2 $_;
    }
  }
  close(DUMP1);
  close(DUMP2);

  # When a table is altered e.g. to a new engine and some options are not
  # supported, the unsupported options are wrapped into a comment
  say("normalizeDump removes non-executable comments");
  move($file, $file.'.tmp3');
  open(DUMP1,$file.'.tmp3');
  open(DUMP2,">$file");
  while (<DUMP1>) {
    s/ \/\* .*?\*\///g;
    print DUMP2 $_;
  }
  close(DUMP1);
  close(DUMP2);

  if ($self->versionNumeric() gt '050701') {
    say("normalizeDump removes _binary for version ".$self->versionNumeric);
    move($file, $file.'.tmp4');
    open(DUMP1,$file.'.tmp4');
    open(DUMP2,">$file");
    while (<DUMP1>) {
      # In 5.7 mysqldump writes _binary before corresponding fields
      #   INSERT INTO `t4` VALUES (0x0000000000,'',_binary ''
      if (/INSERT INTO/) {
        s/([\(,])_binary '/$1'/g;
      }
      print DUMP2 $_;
    }
    close(DUMP1);
    close(DUMP2);
  }

  if ($self->versionNumeric() gt '100501') {
    say("normalizeDump removes /* mariadb-5.3 */ comments for version ".$self->versionNumeric);
    move($file, $file.'.tmp5');
    open(DUMP1,$file.'.tmp5');
    open(DUMP2,">$file");
    while (<DUMP1>) {
      # MDEV-19906 started writing /* mariadb-5.3 */ comment
      #   for old temporal data types
      if (s/ \/\* mariadb-5.3 \*\///g) {}
      print DUMP2 $_;
    }
    close(DUMP1);
    close(DUMP2);
  }

  # MDEV-29446 added default COLLATE clause to SHOW CREATE.
  # in 10.3.37, 10.4.27, 10.5.18, 10.6.11, 10.7.7, 10.8.6, 10.9.4, 10.10.2.
  # We can't know whether it was a part of the original definition or not,
  # so we have to remove it unconditionally.
  say("normalizeDump removes COLLATE clause from table and other object definitions");
  move($file, $file.'.tmp6');
  open(DUMP1,$file.'.tmp6');
  open(DUMP2,">$file");
  while (<DUMP1>) {
    if (s/ COLLATE[= ]\w+//g) {}
    print DUMP2 $_;
  }
  close(DUMP1);
  close(DUMP2);


  if (-e $file.'.tmp1') {
    move($file.'.tmp1',$file.'.orig');
#    unlink($file.'.tmp2') if -e $file.'.tmp2';
  } elsif (-e $file.'.tmp2') {
    move($file.'.tmp2',$file.'.orig');
  } elsif (-e $file.'.tmp3') {
    move($file.'.tmp3',$file.'.orig');
  } elsif (-e $file.'.tmp4') {
    move($file.'.tmp4',$file.'.orig');
  } elsif (-e $file.'.tmp5') {
    move($file.'.tmp5',$file.'.orig');
  } elsif (-e $file.'.tmp6') {
    move($file.'.tmp6',$file.'.orig');
  }
}

sub nonSystemDatabases {
  my $self= shift;
  return sort @{$self->dbh->selectcol_arrayref(
      "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA ".
      "WHERE LOWER(SCHEMA_NAME) NOT IN (".$self->systemSchemaList.")"
    )
  };
}

# XA transactions which haven't been either committed or rolled back
# can further cause locking issues, so different scenarios may want to
# rollback them before doing, for example, DROP TABLE

sub rollbackXA {
  my $self= shift;
  my $xa_transactions= $self->dbh->selectcol_arrayref("XA RECOVER", { Columns => [4] });
  if ($xa_transactions) {
    foreach my $xa (@$xa_transactions) {
      say("Rolling back XA transaction $xa");
      $self->dbh->do("XA ROLLBACK '$xa'");
    }
  }
}

sub binary {
    return $_[0]->[MYSQLD_MYSQLD];
}

sub stopServer {
    my ($self, $shutdown_timeout) = @_;
    $shutdown_timeout = $default_shutdown_timeout unless defined $shutdown_timeout;
    my $res;

    my $shutdown_marker= 'SHUTDOWN_'.time();
    $self->addErrorLogMarker($shutdown_marker);
    if ($shutdown_timeout and defined $self->[MYSQLD_DBH]) {
        sayDebug("Stopping server at port ".$self->port);
        $SIG{'ALRM'} = sub { sayWarning("Could not execute shutdown command in time"); };
        ## Use dbh routine to ensure reconnect in case connection is
        ## stale (happens i.e. with mdl_stability/valgrind runs)
        alarm($shutdown_timeout);
        my $dbh = $self->dbh(my $admin=1);
        # Need to check if $dbh is defined, in case the server has crashed
        if (defined $dbh) {
            $res = $dbh->func('shutdown',$self->host,'root','admin');
            alarm(0);
            if (!$res) {
                ## If shutdown fails, we want to know why:
                if ($dbh->err == 1064) {
                    say("Shutdown command is not supported, sending SIGTERM instead");
                    $res= $self->term;
                }
                if (!$res) {
                    sayError("Shutdown failed due to ".$dbh->err.":".$dbh->errstr);
                    $res= DBSTATUS_FAILURE;
                }
            }
        }
        if (!$self->waitForServerToStop($shutdown_timeout)) {
            # Terminate process
            sayWarning("Server would not shut down properly. Terminating it");
            $res= $self->term;
        } else {
            # clean up when server is not alive.
            unlink $self->socketfile if -e $self->socketfile;
            unlink $self->pidfile if -e $self->pidfile;
            $self->[MYSQLD_SERVERPID]= undef;
            $res= DBSTATUS_OK;
            say("Server at port ".$self->port." has been stopped");
        }
    } else {
        say("Shutdown timeout or dbh is not defined, killing the server");
        $res= $self->kill;
    }
    my ($crashes, undef)= $self->checkErrorLogForErrors($shutdown_marker);
    if ($crashes and scalar(@$crashes)) {
      $res= DBSTATUS_FAILURE;
    }
    return $res;
}

sub checkDatabaseIntegrity {
  my $self= shift;

  say("Testing database integrity");
  my $dbh= $self->dbh;
  my $status= DBSTATUS_OK;
  my $foreign_key_check_workaround= 0;

  $dbh->do("SET max_statement_time= 0");
  my $databases = $dbh->selectcol_arrayref("SHOW DATABASES");
  ALLDBCHECK:
  foreach my $database (sort @$databases) {
      my $db_status= DBSTATUS_OK;
#      next if $database =~ m{^(information_schema|performance_schema|sys)$}is;
      my $tabl_ref = $dbh->selectall_arrayref("SELECT TABLE_NAME, TABLE_TYPE, ENGINE FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='$database'");
      # 1178 is ER_CHECK_NOT_IMPLEMENTED
      my %tables=();
      foreach (@$tabl_ref) {
        my @tr= @$_;
        $tables{$tr[0]} = [ $tr[1], $tr[2] ];
      }
      # table => true
      my %repair_done= ();
      # Mysterious loss of connection upon checks, will retry (once)
      my $retried_lost_connection= 0;
      CHECKTABLE:
      foreach my $table (sort keys %tables) {
        # Should not do CHECK etc., and especially ALTER, on a view
        next CHECKTABLE if $tables{$table}->[0] eq 'VIEW';
        # S3 tables are ignored due to MDEV-29136
        if ($tables{$table}->[1] eq 'S3') {
          say("Check on S3 table $database.$table is skipped due to MDEV-29136");
          next CHECKTABLE;
        }
        #say("Verifying table: $database.$table ($tables{$table}->[1]):");
        my $check = $dbh->selectcol_arrayref("CHECK TABLE `$database`.`$table` EXTENDED", { Columns=>[3,4] });
        if ($dbh->err() > 0) {
          sayError("Got an error for table ${database}.${table}: ".$dbh->err()." (".$dbh->errstr().")");
          # 1178 is ER_CHECK_NOT_IMPLEMENTED. It's not an error
          $db_status= DBSTATUS_FAILURE unless ($dbh->err() == 1178);
          # Mysterious loss of connection upon checks
          if ($dbh->err() == 2013 || $dbh->err() == 2002) {
            if ($retried_lost_connection) {
              last ALLDBCHECK;
            } else {
              say("Trying again as sometimes the connection gets lost...");
              $retried_lost_connection= 1;
              redo CHECKTABLE;
            }
          }
        }
        # CHECK as such doesn't return errors, even on corrupt tables, only prints them
        else {
          my @msg = @$check;
          # table_schema.table_name => [table_type, engine, row_format, table_options]
          my %table_attributes= ();
          CHECKOUTPUT:
          for (my $i = 0; $i < $#msg; $i= $i+2)  {
            my ($msg_type, $msg_text)= ($msg[$i], $msg[$i+1]);
            if ($msg_type eq 'status' and $msg_text ne 'OK' or $msg_type =~ /^error$/i) {
              if (not exists $table_attributes{"$database.$table"}) {
                $table_attributes{"$database.$table"}= $dbh->selectrow_arrayref("SELECT TABLE_TYPE, ENGINE, ROW_FORMAT, CREATE_OPTIONS FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='$database' AND TABLE_NAME='$table'");
              }
              my $tname="$database.$table";
              my $engine= $table_attributes{$tname}->[1];
              unless ($engine) {
                  # Something is wrong, table's info was not retrieved from I_S
                  # Try to find out from the file system first (glob because the table can be partitioned)
                  say("Checking ".$self->datadir."/$database for the presence of $table data files");
                  system("ls ".$self->datadir."/$database/$table.*");
                  if (glob $self->datadir."/$database/$table*.MAD") {
                      # Could happen as a part of
                      # MDEV-17913: Encrypted transactional Aria tables remain corrupt after crash recovery
                      $engine= 'Aria';
                      if (not $repair_done{$table}
                            and defined $self->serverVariable('aria_encrypt_tables')
                            and $self->serverVariable('aria_encrypt_tables') eq 'ON'
                          ) {
                        sayWarning("Aria table `$database`.`$table` was not loaded, : $msg_type : $msg_text");
                        sayWarning("... ignoring due to known bug MDEV-20313, trying to repair");
                        $dbh->do("REPAIR TABLE $tname");
                        $repair_done{$table}= 1;
                        redo CHECKTABLE;
                      }
                  } elsif (glob "$self->datadir/$database/$table*.MYD") {
                      $engine= 'MyISAM';
                  } elsif (glob "$self->datadir/$database/$table*.ibd") {
                      $engine= 'InnoDB';
                  } elsif (glob "$self->datadir/$database/$table*.CSV") {
                      $engine= 'CSV';
                  } else {
                      $engine= 'N/A';
                  }
                  sayError("Table $tname wasn't loaded properly by engine $engine");
                  last CHECKOUTPUT;
              }
              my $attrs= $table_attributes{$tname}->[1]." ".$table_attributes{$tname}->[0]." ROW_FORMAT=".$table_attributes{$tname}->[2];
              if ($table_attributes{$tname}->[1] eq 'Aria') {
                $attrs= ($table_attributes{$tname}->[3] =~ /transactional=1/ ? "transactional $attrs" : "non-transactional $attrs");
              }
              if ($msg_text =~ /Unable to open underlying table which is differently defined or of non-MyISAM type or doesn't exist/) {
                sayWarning("For $attrs `$database`.`$table` : $msg_type : $msg_text");
                sayWarning("... ignoring inconsistency for the MERGE table");
                last CHECKOUTPUT;
              }
              # MDEV-20313: Transactional Aria table stays corrupt after crash-recovery
              elsif ( not $repair_done{$table}
                        and $table_attributes{$tname}->[1] eq 'Aria'
                        and $table_attributes{$tname}->[3] =~ /transactional=1/
                        and $table_attributes{$tname}->[2] eq 'Page'
                        and $msg_text =~ /Found \d+ keys of \d+/ ) {
                sayWarning("For $attrs `$database`.`$table` : $msg_type : $msg_text");
                sayWarning("... ignoring due to known bug MDEV-20313, trying to repair");
                $dbh->do("REPAIR TABLE $tname");
                $repair_done{$table}= 1;
                redo CHECKTABLE;
              }
              # MDEV-17913: Encrypted transactional Aria tables remain corrupt after crash recovery
              elsif ( not $repair_done{$table}
                        and defined $self->serverVariable('aria_encrypt_tables')
                        and $self->serverVariable('aria_encrypt_tables') eq 'ON'
                        and $table_attributes{$tname}->[1] eq 'Aria'
                        and $table_attributes{$tname}->[3] =~ /transactional=1/
                        and $table_attributes{$tname}->[2] eq 'Page'
                        and $msg_text =~ /Checksum for key:  \d+ doesn't match checksum for records|Record at: \d+:\d+  Can\'t find key for index:  \d+|Record-count is not ok; found \d+  Should be: \d+|Key \d+ doesn\'t point at same records as key \d+|Page at \d+ is not delete marked|Key in wrong position at page|Page at \d+ is not marked for index \d+/ ) {
                sayWarning("For $attrs `$database`.`$table` : $msg_type : $msg_text");
                sayWarning("... ignoring due to known bug MDEV-17913, trying to repair");
                $dbh->do("REPAIR TABLE $tname");
                $repair_done{$table}= 1;
                redo CHECKTABLE;
              } elsif (! $foreign_key_check_workaround and $msg_text =~ /Table .* doesn't exist in engine/) {
                sayWarning("For $attrs `$database`.`$table` : $msg_type : $msg_text");
                sayWarning("... possible foreign key check problem. Trying to turn off FOREIGN_KEY_CHECKS and retry");
                $dbh->do("SET FOREIGN_KEY_CHECKS= 0");
                $foreign_key_check_workaround= 1;
                redo CHECKTABLE;
              } elsif (not $repair_done{$table} and ($table_attributes{$tname}->[1] eq 'Aria' and $table_attributes{$tname}->[3] !~ /transactional=1/ or $table_attributes{$tname}->[1] eq 'MyISAM')) {
                sayWarning("For $attrs `$database`.`$table` : $msg_type : $msg_text");
                sayWarning("... non-transactional table may be corrupt after crash recovery, trying to repair");
                $dbh->do("REPAIR TABLE $tname");
                $repair_done{$table}= 1;
                redo CHECKTABLE;
              } else {
                sayError("For $attrs `$database`.`$table` : $msg_type : $msg_text");
                $db_status= DBSTATUS_FAILURE;
              }
            } else {
              sayDebug("For table `$database`.`$table` : $msg_type : $msg_text");
            }
          }
        }
      }
      $status= $db_status if $db_status > $status;
      if ($db_status == DBSTATUS_OK) {
        say("Check for database $database OK");
      } else {
        sayError("Check for database $database failed");
      }
  }
  if ($status > DBSTATUS_OK) {
    sayError("Database integrity check failed");
  }
  if ($foreign_key_check_workaround) {
    $dbh->do("SET FOREIGN_KEY_CHECKS= DEFAULT");
  }
  return $status;
}

sub addErrorLogMarker {
  my $self= shift;
  my $marker= shift;

    sayDebug("Adding marker $marker to the error log ".$self->errorlog);
  if (open(ERRLOG,">>".$self->errorlog)) {
    print ERRLOG "$marker\n";
    close (ERRLOG);
  } else {
    sayWarning("Could not add marker $marker to the error log ".$self->errorlog);
  }
}

sub waitForServerToStop {
  my $self= shift;
  my $timeout= shift;
  $timeout = (defined $timeout ? $timeout*2 : MYSQLD_MAX_SERVER_DOWNTIME);
  my $waits= 0;
  while ($self->running && $waits < $timeout) {
    Time::HiRes::sleep(0.5);
    $waits++;
  }
  return !$self->running;
}

sub getMasterPos {
  my $self= shift;
  my ($file, $pos) = $self->dbh->selectrow_array("SHOW MASTER STATUS");
  unless ($file && $pos) {
    sayError("Could not retrieve master status");
  }
  return ($file, $pos);
}

sub syncWithMaster {
  my ($self, $file, $pos, $rpl_timeout)= @_;
  say("Waiting for the slave to synchronize with master ($file, $pos)");
  $rpl_timeout ||= 0;
  if ($self->dbh) {
    $self->dbh->do("SET max_statement_time=0");
    my $wait_result = $self->dbh->selectrow_array("SELECT MASTER_POS_WAIT('$file',$pos,$rpl_timeout)");
    # Cannot do selectrow_array, as fields have different positions in different versions
    my $sth= $self->dbh->prepare("SHOW SLAVE STATUS");
    my $slave_status= $sth->fetchrow_hashref;
    $slave_status->{Last_SQL_Errno}, $slave_status->{Last_IO_Errno};
    if (not defined $wait_result) {
      sayError("Slave failed to synchronize with master");
      foreach my $f ('Last_SQL','Last_IO') {
        if ($slave_status->{$f.'_Errno'}) {
          sayError("${f}_Errno: ".$slave_status->{$f.'_Errno'}." (".$slave_status->{$f.'_Error'}.")");
        }
      }
      return DBSTATUS_FAILURE;
    } else {
      say("Slave SQL thread apparently synchronized successfully");
      return DBSTATUS_OK;
    }
  } else {
    sayError("Lost connection to the slave");
    return DBSTATUS_FAILURE;
  }
}

sub waitForServerToStart {
  my $self= shift;
  my $waits= 0;
  while (!$self->running && $waits < MYSQLD_MAX_SERVER_DOWNTIME) {
    Time::HiRes::sleep(0.5);
    $waits++;
  }
  return $self->running;
}

sub plannedDowntime {
  my $self= shift;
  my $downtime= 0;
  if (-e $self->vardir.'/expect') {
    if (open(DOWNTIME,$self->vardir.'/expect')) {
      $downtime= <DOWNTIME>;
      chomp $downtime;
      close(DOWNTIME);
    } else {
      sayError("Could not check for the expect flag: $!");
    }
  }
  if ($downtime > 0) {
    say("Server says: planned downtime, wait for $downtime seconds");
    # We are unsetting PID in case it became stale,
    # it should be re-read from the server pidfile
    $self->[MYSQLD_SERVERPID]= undef;
  } elsif ($downtime < 0) {
    say("Server says: planned downtime, don't wait");
  } else {
    sayWarning("Server says: the downtime isn't planned");
  }
  return $downtime;
}

sub backupDatadir {
  my $self= shift;
  my $backup_name= shift;

  say("Copying datadir... (interrupting the copy operation may cause investigation problems later)");
  if (osWindows()) {
      system('xcopy "'.$self->datadir.'" "'.$backup_name.' /E /I /Q');
  } else {
      system('cp -r '.$self->datadir.' '.$backup_name);
  }
}

# Extract important messages from the error log.
# The check starts from the provided marker or from the beginning of the log

sub checkErrorLogForErrors {
  my ($self, $marker)= @_;

  my @crashes= ();
  my @errors= ();

  open(ERRLOG, $self->errorlog);
  my $found_marker= 0;

  sayDebug("Checking server log for important errors starting from " . ($marker ? "marker $marker" : 'the beginning'));

  my $count= 0;
  while (<ERRLOG>)
  {
    next unless !$marker or $found_marker or /^$marker$/;
    $found_marker= 1;
    $_ =~ s{[\r\n]}{}isg;

    # Ignore certain errors
    next if
         $_ =~ /innodb_table_stats/s
      or $_ =~ /InnoDB: Cannot save table statistics for table/s
      or $_ =~ /InnoDB: Deleting persistent statistics for table/s
      or $_ =~ /InnoDB: Unable to rename statistics from/s
      or $_ =~ /ib_buffer_pool' for reading: No such file or directory/s
      or $_ =~ /has or is referenced in foreign key constraints which are not compatible with the new table definition/s
    ;

    # MDEV-20320
    if ($_ =~ /Failed to find tablespace for table .* in the cache\. Attempting to load the tablespace with space id/) {
        say("Encountered symptoms of MDEV-20320, variant 1");
        next;
    }
    # MDEV-20320 2nd part
    if ($_ =~ /InnoDB: Refusing to load .* \(id=\d+, flags=0x\d+\); dictionary contains id=\d+, flags=0x\d+/) {
        $_=<ERRLOG>;
        if (/InnoDB: Operating system error number 2 in a file operation/) {
            $_=<ERRLOG>;
            if (/InnoDB: The error means the system cannot find the path specified/) {
                $_=<ERRLOG>;
                if (/InnoDB: If you are installing InnoDB, remember that you must create directories yourself, InnoDB does not create them/) {
                    $_=<ERRLOG>;
                    if (/InnoDB: Could not find a valid tablespace file for .*/) {
                        say("Encountered symptoms of MDEV-20320, variant 2");
                        next;
                    }
                }
            }
        }
    }

    # Crashes
    if (
           $_ =~ /Assertion\W/is
        or $_ =~ /got\s+signal/is
        or $_ =~ /segmentation fault/is
        or $_ =~ /segfault/is
        or $_ =~ /got\s+exception/is
        or $_ =~ /AddressSanitizer|LeakSanitizer/is
    ) {
      say("------") unless $count++;
      say($_);
      push @crashes, $_;
    }
    # Other errors
    elsif (
           $_ =~ /\[ERROR\]\s+InnoDB/is
        or $_ =~ /InnoDB:\s+Error:/is
        or $_ =~ /registration as a STORAGE ENGINE failed./is
    ) {
      say("------") unless $count++;
      say($_);
      push @errors, $_;
    }
  }
  say("------") if $count;
  close(ERRLOG);
  return (\@crashes, \@errors);
}

sub serverVariables {
    my $self = shift;
    if (not keys %{$self->[MYSLQD_SERVER_VARIABLES]}) {
        my $dbh = $self->dbh;
        return undef if not defined $dbh;
        my $sth = $dbh->prepare("SHOW VARIABLES");
        $sth->execute();
        my %vars = ();
        while (my $array_ref = $sth->fetchrow_arrayref()) {
            $vars{$array_ref->[0]} = $array_ref->[1];
        }
        $sth->finish();
        $self->[MYSLQD_SERVER_VARIABLES] = \%vars;
    }
    return $self->[MYSLQD_SERVER_VARIABLES];
}

sub serverVariable {
    my ($self, $var) = @_;
    return $self->serverVariables()->{$var};
}

sub running {
    my($self) = @_;
    my $pid= $self->serverpid;
    unless ($pid and $pid =~ /^\d+$/) {
      if (-f $self->pidfile) {
        $pid= get_pid_from_file($self->pidfile);
      }
    }
    if ($pid and $pid =~ /^\d+$/) {
      if (osWindows()) {
        return kill(0,$pid)
      } else {
        # It looks like in some cases the process may be not responding
        # to ping but is still not quite dead
        return ! system("[ -e /proc/$pid ]")
      }
    } else {
      sayWarning("PID not found");
      return 0;
    }
}

sub _find {
    my($self, $bases, $subdir, @names) = @_;

    foreach my $base (@$bases) {
        foreach my $s (@$subdir) {
          foreach my $n (@names) {
                my $path  = $base."/".$s."/".$n;
                return $path if -f $path;
          }
        }
    }
    # If we are here, we haven't found what we were looking for
    my $paths = "";
    foreach my $base (@$bases) {
        $paths .= join(",",map {"'".$base."/".$_."'"} @$subdir).",";
    }
    my $names = join(" or ", @names );
    sayWarning("Cannot find '$names' in $paths");
    return undef;
}

sub host {
  return $_[0]->[MYSQLD_HOST];
}

sub dsn {
    my ($self,$user) = @_;
    $user= $self->[MYSQLD_USER] unless $user;
    return "dbi:mysql".
      ":host=".$self->[MYSQLD_HOST].
      ":port=".$self->[MYSQLD_PORT].
      ":user=".$user.
      ":mysql_local_infile=1".
      ":max_allowed_packet=1G".
      ($self->[MYSQLD_PS_PROTOCOL] ? ":mysql_server_prepare=1" : "")
;
}

sub connect {
  return DBI->connect($_[0]->dsn(),
                 undef,
                 undef,
                 {PrintError => 0,
                  RaiseError => 0,
                  AutoCommit => 1,
                  mysql_auto_reconnect => 1});
}

sub dbh {
  my ($self, $admin, $new) = @_;
  my $dbh_type= ($admin ? MYSQLD_ADMIN_DBH : MYSQLD_DBH);
  my $dbh;
  if (! $new && defined $self->[$dbh_type]) {
      if ($self->[$dbh_type]->ping) {
        $dbh= $self->[$dbh_type];
      } else {
        say("Stale connection to ".$self->[MYSQLD_PORT].". Reconnecting");
      }
  } else {
      sayDebug("Connecting to ".$self->[MYSQLD_PORT]);
  }
  if (! $dbh) {
    $dbh = $self->connect;
    if (defined $dbh) {
      if ($admin) {
        $dbh->do("SET ROLE admin");
      }
      if (! $new) {
        $self->[$dbh_type]= $dbh;
      }
    } else {
      sayError("(Re)connect to ".$self->[MYSQLD_PORT]." failed due to ".$DBI::err.": ".$DBI::errstr);
    }
  }
  return $dbh;
}

sub _findDir {
    my($self, $bases, $subdir, $name) = @_;

    foreach my $base (@$bases) {
        foreach my $s (@$subdir) {
            my $path  = $base."/".$s."/".$name;
            return $base."/".$s if -f $path;
        }
    }
    my $paths = "";
    foreach my $base (@$bases) {
        $paths .= join(",",map {"'".$base."/".$_."'"} @$subdir).",";
    }
    croak "Cannot find '$name' in $paths";
}

sub _absPath {
    my ($self, $path) = @_;

    if (osWindows()) {
        return
            $path =~ m/^[A-Z]:[\/\\]/i;
    } else {
        return $path =~ m/^\//;
    }
}

sub version {
    my($self) = @_;

    if (not defined $self->[MYSQLD_VERSION]) {
        my $conf = $self->_find([$self->basedir],
                                ['scripts',
                                 'bin',
                                 'sbin'],
                                'mysql_config.pl', 'mysql_config');
        ## This will not work if there is no perl installation,
        ## but without perl, RQG won't work either :-)
        my $ver = `perl $conf --version`;
        chop($ver);
        $self->[MYSQLD_VERSION] = $ver;
    }
    return $self->[MYSQLD_VERSION];
}

sub majorVersion {
    my($self) = @_;

    if (not defined $self->[MYSQLD_MAJOR_VERSION]) {
        my $ver= $self->version;
        if ($ver =~ /(\d+\.\d+)/) {
            $self->[MYSQLD_MAJOR_VERSION]= $1;
        }
    }
    return $self->[MYSQLD_MAJOR_VERSION];
}

sub printInfo {
    my($self) = @_;

    say("Server version: ". $self->version);
    say("Binary: ". $self->binary);
    say("Type: ". $self->serverType($self->binary));
    say("Datadir: ". $self->datadir);
    say("Tmpdir: ". $self->tmpdir);
    say("Corefile: " . $self->corefile);
}

sub versionNumbers {
    my($self) = @_;

    $self->version =~ m/([0-9]+)\.([0-9]+)\.([0-9]+)/;

    return (int($1),int($2),int($3));
}

sub versionNumeric {
    return versionN6($_[0]->version);
}

#############  Version specific stuff

sub _messages {
    my ($self) = @_;

    if ($self->_olderThan(5,5,0)) {
        return "--language=".$self->[MYSQLD_MESSAGES]."/english";
    } else {
        return "--lc-messages-dir=".$self->[MYSQLD_MESSAGES];
    }
}

sub _logOptions {
    my ($self) = @_;

    if ($self->_olderThan(5,1,29)) {
        return ["--log=".$self->logfile];
    } else {
        if ($self->[MYSQLD_GENERAL_LOG]) {
            return ["--general-log", "--general-log-file=".$self->logfile];
        } else {
            return ["--general-log-file=".$self->logfile];
        }
    }
}

# For _olderThan and _notOlderThan we will match according to InnoDB versions
# 10.0 to 5.6
# 10.1 to 5.6
# 10.2 to 5.6
# 10.2 to 5.7

sub _olderThan {
    my ($self,$b1,$b2,$b3) = @_;

    my ($v1, $v2, $v3) = $self->versionNumbers;

    if    ($v1 == 10 and $b1 == 5 and $v2 >= 0 and $v2 < 3) { $v1 = 5; $v2 = 6 }
    elsif ($v1 == 10 and $b1 == 5 and $v2 >= 3) { $v1 = 5; $v2 = 7 }
    elsif ($v1 == 5 and $b1 == 10 and $b2 >= 0 and $b2 < 3) { $b1 = 5; $b2 = 6 }
    elsif ($v1 == 5 and $b1 == 10 and $b2 >= 3) { $b1 = 5; $b2 = 7 }

    my $b = $b1*1000 + $b2 * 100 + $b3;
    my $v = $v1*1000 + $v2 * 100 + $v3;

    return $v < $b;
}

sub _isMySQL {
    my $self = shift;
    my ($v1, $v2, $v3) = $self->versionNumbers;
    return ($v1 == 8 or $v1 == 5 and ($v2 == 6 or $v2 == 7));
}

sub _notOlderThan {
    return not _olderThan(@_);
}

sub get_pid_from_file {
  my $fname= shift;
  my $separ= $/;
  $/= undef;
  open(PID,$fname) || croak("Could not open pid file $fname for reading");
  my $p = <PID>;
  close(PID);
  $p =~ s/.*?([0-9]+).*/$1/;
  $/= $separ;
  chomp $p;
  return $p;
}

sub storeMetaData {
# metadata_type:
# - collations
# - system (system schemata)
# - nonsystem (non-system schemata)
# - schemata (all schemata except for exempt)
# - all (all schemata except for exempt, + collations, + whatever else we later start dumping)
# wait_for_threads (optional) means that before dumping the files,
# we will be waiting for the given number of executor_NNN_ready flags
# (indicating that the executors have done everything they wanted before
#  the data reload)
#  
# Created files:
# collations.<timestamp>
# system-tables.<timestamp>
# system-proc.<timestamp>
# nonsystem-tables.<timestamp>
# nonsystem-proc.<timestamp>

  my ($self, $metadata_type, $maxtime, $wait_for_threads)= @_;

  my $vardir= $self->vardir;
  my $dumpdir= $vardir."/metadata";
  mkpath($dumpdir);
  
  my @waiters= ();
  my $status= DBSTATUS_OK;

  unless ($maxtime) {
    sayError("Max time for metadata dump must be defined, cannot wait forever");
    $status= DBSTATUS_FAILURE;
    goto METAERR;
  }
  my $end_time= time()+$maxtime;

  while (time() < $end_time && scalar(@waiters) < $wait_for_threads) {
    sayDebug("Waiting for $wait_for_threads executors to get ready for new metadata dump, so far found ".scalar(@waiters).", ".($end_time-time())." sec left");
    sleep 1;
    @waiters= glob("$vardir/executor_*_ready");
  };

  if (time() >= $end_time) {
    sayError("Not enough time to do the metadata dump");
    $status= DBSTATUS_FAILURE;
    goto METAERR;
  }

  unless (defined $self->[MYSQLD_METADATA_DBH] && $self->[MYSQLD_METADATA_DBH]->ping) {
    $self->[MYSQLD_METADATA_DBH]= $self->dbh(my $admin=1, my $new= 1);
  }
  my $dbh= $self->[MYSQLD_METADATA_DBH];
  unless ($dbh) {
    sayError("Metadata dumper could not establish connection");
    $status= DBSTATUS_FAILURE;
    goto METAERR;
  }

  my @files= ();

  my $timeout= $end_time - time();
  sayDebug("Starting dumping $metadata_type metadata with $timeout sec timeout".($wait_for_threads ? ", for $wait_for_threads waiters" : ""));

  # If executors are waiting, we should produce the result regardless the timeout
  my $statement_time= "SET STATEMENT max_statement_time=$timeout FOR";

  if ($metadata_type eq 'all' or $metadata_type eq 'collations') {
    push @files, "$dumpdir/collations";
    unlink $files[$#files];
    if ($dbh) {
      $dbh->do("$statement_time SELECT collation_name,character_set_name ".
              "INTO OUTFILE '$files[$#files]' FIELDS TERMINATED BY ';' ".
              "FROM information_schema.collations");
      if ($dbh->err) {
        sayError("Collations dump failed: ".$dbh->err.": ".$dbh->errstr);
        $status= DBSTATUS_FAILURE;
        goto METAERR;
      }
    } else {
      sayError("Metadata dumper lost connection to the server");
      $status= DBSTATUS_FAILURE;
      goto METAERR;
    }
  }

  if ($metadata_type ne 'collations')
  {
    my $tbl_query_p1= "$statement_time SELECT table_schema, table_name, table_type";
    my $tbl_query_p2= "FROM information_schema.tables";
    my $col_query_p1= "$statement_time SELECT table_schema, table_name, column_name, column_key, data_type, character_maximum_length";
    my $col_query_p2= "FROM information_schema.columns";
    my $ind_query_p1= "$statement_time SELECT table_schema, table_name, column_name, index_name, non_unique XOR 1";
    my $ind_query_p2= "FROM information_schema.statistics";
    my $proc_query_p1= "$statement_time SELECT db, name, type";
    my $proc_query_p2= "FROM mysql.proc";
    my $db_query_p1= "$statement_time SELECT schema_name";
    my $db_query_p2= "FROM information_schema.schemata";

    my $system_schemata= $self->systemSchemaList();
    my $exempt_schemata= "'transforms'";

    if ($dbh) {
      if ($metadata_type ne 'nonsystem')
      {
        # System db
        push @files, "$dumpdir/system-db";
        unlink $files[$#files];
        $dbh->do(
          $db_query_p1." INTO OUTFILE '$files[$#files]' FIELDS TERMINATED BY ';' ".
          $db_query_p2." WHERE schema_name IN ($system_schemata)"
        );
        if ($dbh->err) {
          sayError("System schemata dump failed: ".$dbh->err.": ".$dbh->errstr);
          $status= DBSTATUS_FAILURE;
          goto METAERR;
        }
        # System tables
        push @files, "$dumpdir/system-tables";
        unlink $files[$#files];
        $dbh->do(
          $tbl_query_p1." INTO OUTFILE '$files[$#files]' FIELDS TERMINATED BY ';' ".
          $tbl_query_p2." WHERE table_schema IN ($system_schemata)"
        );
        if ($dbh->err) {
          sayError("System table dump failed: ".$dbh->err.": ".$dbh->errstr);
          $status= DBSTATUS_FAILURE;
          goto METAERR;
        }
        # System table columns
        push @files, "$dumpdir/system-columns";
        unlink $files[$#files];
        $dbh->do(
          $col_query_p1." INTO OUTFILE '$files[$#files]' FIELDS TERMINATED BY ';' ".
          $col_query_p2." WHERE table_schema IN ($system_schemata)"
        );
        if ($dbh->err) {
          sayError("System table column dump failed: ".$dbh->err.": ".$dbh->errstr);
          $status= DBSTATUS_FAILURE;
          goto METAERR;
        }
        # System table columns
        push @files, "$dumpdir/system-indexes";
        unlink $files[$#files];
        $dbh->do(
          $ind_query_p1." INTO OUTFILE '$files[$#files]' FIELDS TERMINATED BY ';' ".
          $ind_query_p2." WHERE table_schema IN ($system_schemata)"
        );
        if ($dbh->err) {
          sayError("System table index dump failed: ".$dbh->err.": ".$dbh->errstr);
          $status= DBSTATUS_FAILURE;
          goto METAERR;
        }
        # System stored proc
        push @files, "$dumpdir/system-proc";
        unlink $files[$#files];
        $dbh->do(
          $proc_query_p1." INTO OUTFILE '$files[$#files]' FIELDS TERMINATED BY ';' ".
          $proc_query_p2." WHERE db IN ($system_schemata)"
        );
        if ($dbh->err) {
          sayError("System proc dump failed: ".$dbh->err.": ".$dbh->errstr);
          $status= DBSTATUS_FAILURE;
          goto METAERR;
        }
      }
      if ($metadata_type ne 'system')
      {
        # Non-system db
        push @files, "$dumpdir/nonsystem-db";
        unlink $files[$#files];
        $dbh->do(
          $db_query_p1." INTO OUTFILE '$files[$#files]' FIELDS TERMINATED BY ';' ".
          $db_query_p2." WHERE schema_name NOT IN ($system_schemata,$exempt_schemata)"
        );
        if ($dbh->err) {
          sayError("Non-system schemata dump failed: ".$dbh->err.": ".$dbh->errstr);
          $status= DBSTATUS_FAILURE;
          goto METAERR;
        }
        # Non-system tables
        push @files, "$dumpdir/nonsystem-tables";
        unlink $files[$#files];
        $dbh->do(
          $tbl_query_p1." INTO OUTFILE '$files[$#files]' FIELDS TERMINATED BY ';' ".
          $tbl_query_p2." WHERE table_schema NOT IN ($system_schemata,$exempt_schemata)"
        );
        if ($dbh->err) {
          sayError("Non-system table dump failed: ".$dbh->err.": ".$dbh->errstr);
          $status= DBSTATUS_FAILURE;
          goto METAERR;
        }
        # Non-system table columns
        push @files, "$dumpdir/nonsystem-columns";
        unlink $files[$#files];
        $dbh->do(
          $col_query_p1." INTO OUTFILE '$files[$#files]' FIELDS TERMINATED BY ';' ".
          $col_query_p2." WHERE table_schema NOT IN ($system_schemata,$exempt_schemata)"
        );
        if ($dbh->err) {
          sayError("Non-system table column dump failed: ".$dbh->err.": ".$dbh->errstr);
          $status= DBSTATUS_FAILURE;
          goto METAERR;
        }
        # Non-system table indexes
        push @files, "$dumpdir/nonsystem-indexes";
        unlink $files[$#files];
        $dbh->do(
          $ind_query_p1." INTO OUTFILE '$files[$#files]' FIELDS TERMINATED BY ';' ".
          $ind_query_p2." WHERE table_schema NOT IN ($system_schemata,$exempt_schemata)"
        );
        if ($dbh->err) {
          sayError("Non-system table index dump failed: ".$dbh->err.": ".$dbh->errstr);
          $status= DBSTATUS_FAILURE;
          goto METAERR;
        }
        # Non-system stored procedures
        push @files, "$dumpdir/nonsystem-proc";
        unlink $files[$#files];
        $dbh->do(
          $proc_query_p1." INTO OUTFILE '$files[$#files]' FIELDS TERMINATED BY ';' ".
          $proc_query_p2." WHERE db NOT IN ($system_schemata,$exempt_schemata)"
        );
        if ($dbh->err) {
          sayError("Non-system proc dump failed: ".$dbh->err.": ".$dbh->errstr);
          $status= DBSTATUS_FAILURE;
          goto METAERR;
        }
      }
    } else {
      sayError("Metadata dumper lost connection to the server");
      $status= DBSTATUS_FAILURE;
      goto METAERR;
    }
  }

  my $ts= Time::HiRes::time();
  local $Data::Dumper::Maxdepth= 0;
  local $Data::Dumper::Deepcopy= 1;
  my %files= ();
  foreach my $f (@files) {
    $files{$f}= 1;
    my @prev= glob("$f-*");
    foreach my $p (@prev) { move($p,$p.'.bak') unless $p =~ /\.bak$/ };
  }

  my $coll_count;
  if ($files{"$dumpdir/collations"}) {
    unless (open(COLL,"$dumpdir/collations")) {
      sayError("Couldn't open collations dump $dumpdir/collations: $!");
      $status= DBSTATUS_FAILURE;
      goto METAERR;
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
    unless (open(COLL,">$vardir/collations-$ts")) {
      sayError("Couldn't open collations file for writing: $!");
      $status= DBSTATUS_FAILURE;
      goto METAERR;
    }
    print COLL Dumper \@collations;
    close(COLL);
    $coll_count= scalar(@collations);
  }

  my ($db_count, $tbl_count, $col_count, $ind_count, $proc_count)= (0, 0, 0, 0, 0);
  foreach my $sys ('system','nonsystem') {
    # Columns, tables and index lists may be diverged, since they weren't
    # taken at exactly the same time or transactionally. We'll neeed to
    # reconcile them -- only records for tables present in col and tbl files
    # will be used
    next unless $files{"$dumpdir/$sys-db"} && $files{"$dumpdir/$sys-tables"} && $files{"$dumpdir/$sys-columns"} && $files{"$dumpdir/$sys-indexes"};
    my $meta;
    my %tabletype;
    unless (open(TBL, "$dumpdir/$sys-tables")) {
      sayError("Couldn't open $dumpdir/$sys-tables for reading: $!");
      $status= DBSTATUS_FAILURE;
      goto METAERR;
    }
    while (<TBL>) {
      chomp;
      my ($schema, $table, $type) = split /;/, $_;
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
      $tbl_count++;
    }
    close(TBL);

    unless (open(COL, "$dumpdir/$sys-columns")) {
      sayError("Couldn't open $dumpdir/$sys-columns for reading: $!");
      $status= DBSTATUS_FAILURE;
      goto METAERR;
    }
    while (<COL>) {
      chomp;
      my ($schema, $table, $column, $key, $realtype, $maxlength) = split /;/, $_;
      my $type= $tabletype{$schema.'.'.$table};
      next unless $type;
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
      $meta->{$schema}->{$type}->{$table}->{COL}->{$column}= [$key,$metatype,$realtype,$maxlength];
      $col_count++;
    }
    close(COL);
    unless (open(IND, "$dumpdir/$sys-indexes")) {
      sayError("Couldn't open $dumpdir/$sys-indexes for reading: $!");
      $status= DBSTATUS_FAILURE;
      goto METAERR;
    }
    while (<IND>) {
      chomp;
      my ($schema, $table, $column, $ind, $unique) = split /;/, $_;
      my $type= $tabletype{$schema.'.'.$table};
      next unless $type && $meta->{$schema}->{$type}->{$table}->{COL}->{$column};
      my $indtype= $tabletype{$schema.'.'.$table};
      $meta->{$schema}->{$indtype}->{$table}->{IND}->{$ind}= [$unique];
      $ind_count++;
    }
    close(IND);
    unless (open(PROC, "$dumpdir/$sys-proc")) {
      sayError("Couldn't open $dumpdir/$sys-proc for reading: $!");
      $status= DBSTATUS_FAILURE;
      goto METAERR;
    }
    while (<PROC>) {
      chomp;
      my ($schema, $proc, $type) = split /;/, $_;
      $type= lc($type);
      # paramnum will be just a placeholder for now
      $meta->{$schema}={} if not exists $meta->{$schema};
      $meta->{$schema}->{$type}={} if not exists $meta->{$schema}->{$type};
      $meta->{$schema}->{$type}->{$proc}={} if not exists $meta->{$schema}->{$type}->{$proc};
      $meta->{$schema}->{$type}->{$proc}->{paramnum}= 0;
      $proc_count++;
    }
    close(PROC);

    # Make sure that even empty databases (which wouldn't appear in table/index/column dumps)
    # are accounted for
    unless (open(DB, "$dumpdir/$sys-db")) {
      sayError("Couldn't open $dumpdir/$sys-db for reading: $!");
      $status= DBSTATUS_FAILURE;
      goto METAERR;
    }
    while (<DB>) {
      chomp;
      my $schema = $_;
      $meta->{$schema}={} if not exists $meta->{$schema};
    }
    close(DB);

    # Finally, remove tables which have no columns
    foreach my $s (keys %$meta) {
      foreach my $tp (keys %{$meta->{$s}}) {
        foreach my $t (keys %{$meta->{$s}->{$tp}}) {
          if (scalar keys %{$meta->{$s}->{$tp}->{$t}->{COL}}) {
            my %tbl= %{$meta->{$s}->{$tp}->{$t}};
            $meta->{$s}->{tables}->{$t}= \%tbl;
          } else {
            delete $meta->{$s}->{$tp}->{$t};
            $tbl_count--;
          }
        }
      }
    }
    unless (open(META,">$vardir/$sys-metadata-$ts")) {
      sayError("Couldn't open metadata file for writing: $!");
      $status= DBSTATUS_FAILURE;
      goto METAERR;
    }
    print META Dumper $meta;
    close(META);
    $db_count+= scalar(keys %$meta);
  }

  METAERR:
  if ($status != DBSTATUS_OK) {
    unlink @files, @waiters;
    return $status;
  }

  
#    move($f,$f."-$ts");
  unlink @waiters;
  say("Finished dumping $metadata_type metadata".($wait_for_threads ? " for $wait_for_threads waiters:" : ":").
    (defined $coll_count ? " $coll_count collations;" : "").
    ($db_count ? " $db_count databases, $tbl_count tables, $col_count columns, $ind_count indexes, $proc_count stored procedures" : "")
  );
  return DBSTATUS_OK;
}
