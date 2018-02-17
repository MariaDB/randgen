# Copyright (c) 2010, 2012, Oracle and/or its affiliates. All rights reserved. 
# Copyright (c) 2013, 2017, MariaDB
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

package DBServer::MySQL::MySQLd;

@ISA = qw(DBServer::DBServer);

use DBI;
use DBServer::DBServer;
use if osWindows(), Win32::Process;
use Time::HiRes;
use POSIX ":sys_wait_h";

use strict;

use Carp;
use Data::Dumper;
use File::Basename qw(dirname);
use File::Path qw(mkpath rmtree);
use File::Copy qw(move);

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
use constant MYSQLD_WINDOWS_PROCESS => 13;
use constant MYSQLD_DBH => 14;
use constant MYSQLD_START_DIRTY => 15;
use constant MYSQLD_VALGRIND => 16;
use constant MYSQLD_VALGRIND_OPTIONS => 17;
use constant MYSQLD_VERSION => 18;
use constant MYSQLD_DUMPER => 19;
use constant MYSQLD_SOURCEDIR => 20;
use constant MYSQLD_GENERAL_LOG => 21;
use constant MYSQLD_WINDOWS_PROCESS_EXITCODE => 22;
use constant MYSQLD_DEBUG_SERVER => 22;
use constant MYSQLD_SERVER_TYPE => 23;
use constant MYSQLD_VALGRIND_SUPPRESSION_FILE => 24;
use constant MYSQLD_TMPDIR => 25;
use constant MYSQLD_CONFIG_CONTENTS => 26;
use constant MYSQLD_CONFIG_FILE => 27;
use constant MYSQLD_USER => 28;
use constant MYSQLD_MAJOR_VERSION => 29;
use constant MYSQLD_CLIENT_BINDIR => 30;
use constant MYSLQD_SERVER_VARIABLES => 31;

use constant MYSQLD_PID_FILE => "mysql.pid";
use constant MYSQLD_ERRORLOG_FILE => "mysql.err";
use constant MYSQLD_LOG_FILE => "mysql.log";
use constant MYSQLD_DEFAULT_PORT =>  19300;
use constant MYSQLD_DEFAULT_DATABASE => "test";
use constant MYSQLD_WINDOWS_PROCESS_STILLALIVE => 259;


sub new {
    my $class = shift;
    
    my $self = $class->SUPER::new({'basedir' => MYSQLD_BASEDIR,
                                   'sourcedir' => MYSQLD_SOURCEDIR,
                                   'vardir' => MYSQLD_VARDIR,
                                   'debug_server' => MYSQLD_DEBUG_SERVER,
                                   'port' => MYSQLD_PORT,
                                   'server_options' => MYSQLD_SERVER_OPTIONS,
                                   'start_dirty' => MYSQLD_START_DIRTY,
                                   'general_log' => MYSQLD_GENERAL_LOG,
                                   'valgrind' => MYSQLD_VALGRIND,
                                   'valgrind_options' => MYSQLD_VALGRIND_OPTIONS,
                                   'config' => MYSQLD_CONFIG_CONTENTS,
                                   'user' => MYSQLD_USER},@_);
    
    croak "No valgrind support on windows" if osWindows() and $self->[MYSQLD_VALGRIND];
    
    if (not defined $self->[MYSQLD_VARDIR]) {
        $self->[MYSQLD_VARDIR] = "mysql-test/var";
    }
    
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
    
    # Use mysqld-debug server if --debug-server option used.
    if ($self->[MYSQLD_DEBUG_SERVER]) {
        # Catch excpetion, dont exit contine search for other mysqld if debug.
        eval{
            $self->[MYSQLD_MYSQLD] = $self->_find([$self->basedir],
                                                  osWindows()?["sql/Debug","sql/RelWithDebInfo","sql/Release","bin"]:["sql","libexec","bin","sbin"],
                                                  osWindows()?"mysqld-debug.exe":"mysqld-debug");
        };
        # If mysqld-debug server is not found, use mysqld server if built as debug.        
        if (!$self->[MYSQLD_MYSQLD]) {
            $self->[MYSQLD_MYSQLD] = $self->_find([$self->basedir],
                                                  osWindows()?["sql/Debug","sql/RelWithDebInfo","sql/Release","bin"]:["sql","libexec","bin","sbin"],
                                                  osWindows()?"mysqld.exe":"mysqld");     
            if ($self->[MYSQLD_MYSQLD] && $self->serverType($self->[MYSQLD_MYSQLD]) !~ /Debug/) {
                croak "--debug-server needs a mysqld debug server, the server found is $self->[MYSQLD_SERVER_TYPE]"; 
            }
        }
    }else {
        # If mysqld server is found use it.
        eval {
            $self->[MYSQLD_MYSQLD] = $self->_find([$self->basedir],
                                                  osWindows()?["sql/Debug","sql/RelWithDebInfo","sql/Release","bin"]:["sql","libexec","bin","sbin"],
                                                  osWindows()?"mysqld.exe":"mysqld");
        };
        # If mysqld server is not found, use mysqld-debug server.
        if (!$self->[MYSQLD_MYSQLD]) {
            $self->[MYSQLD_MYSQLD] = $self->_find([$self->basedir],
                                                  osWindows()?["sql/Debug","sql/RelWithDebInfo","sql/Release","bin"]:["sql","libexec","bin","sbin"],
                                                  osWindows()?"mysqld-debug.exe":"mysqld-debug");
        }
        
        $self->serverType($self->[MYSQLD_MYSQLD]);
    }

    $self->[MYSQLD_BOOT_SQL] = [];

    $self->[MYSQLD_DUMPER] = $self->_find([$self->basedir],
                                          osWindows()?["client/Debug","client/RelWithDebInfo","client/Release","bin"]:["client","bin"],
                                          osWindows()?"mysqldump.exe":"mysqldump");

    $self->[MYSQLD_CLIENT_BINDIR] = dirname($self->[MYSQLD_DUMPER]);

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
   
    ## Use valgrind suppression file available in mysql-test path. 
    if ($self->[MYSQLD_VALGRIND]) {
        $self->[MYSQLD_VALGRIND_SUPPRESSION_FILE] = $self->_find(defined $self->sourcedir?[$self->basedir,$self->sourcedir]:[$self->basedir],
                                                             osWindows()?["share/mysql-test","mysql-test"]:["share/mysql-test","mysql-test"],
                                                             "valgrind.supp")
    };
    
    foreach my $file ("mysql_system_tables.sql", 
                      "mysql_performance_tables.sql",
                      "mysql_system_tables_data.sql", 
                      "mysql_test_data_timezone.sql",
                      "fill_help_tables.sql") {
        my $script = 
             eval { $self->_find(defined $self->sourcedir?[$self->basedir,$self->sourcedir]:[$self->basedir],
                          ["scripts","share/mysql","share"], $file) };
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
        say("Using existing data for MySQL " .$self->version ." at ".$self->datadir);
    } else {
        say("Creating MySQL " . $self->version . " database at ".$self->datadir);
        if ($self->createMysqlBase != DBSTATUS_OK) {
            croak("FATAL ERROR: Bootstrap failed, cannot proceed!");
        }
    }

    return $self;
}

sub basedir {
    return $_[0]->[MYSQLD_BASEDIR];
}

sub clientBindir {
    return $_[0]->[MYSQLD_CLIENT_BINDIR];
}

sub sourcedir {
    return $_[0]->[MYSQLD_SOURCEDIR];
}

sub datadir {
    return $_[0]->[MYSQLD_DATADIR];
}

sub setDatadir {
    $_[0]->[MYSQLD_DATADIR] = $_[1];
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

sub setPort {
    my ($self, $port) = @_;
    $self->[MYSQLD_PORT]= $port;
}

sub user {
    return $_[0]->[MYSQLD_USER];
}

sub serverpid {
    return $_[0]->[MYSQLD_SERVERPID];
}

sub forkpid {
    return $_[0]->[MYSQLD_AUXPID];
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

sub pid {
    return $_[0]->[MYSQLD_SERVERPID];
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

sub getServerOptions {
  my $self= shift;
  return $self->[MYSQLD_SERVER_OPTIONS];
}

sub printServerOptions {
    my $self = shift;
    foreach (@{$self->[MYSQLD_SERVER_OPTIONS]}) {
        say("    $_");
    }
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

    ## Prepare config file if needed
    if ($self->[MYSQLD_CONFIG_CONTENTS] and ref $self->[MYSQLD_CONFIG_CONTENTS] eq 'ARRAY' and scalar(@{$self->[MYSQLD_CONFIG_CONTENTS]})) {
        $self->[MYSQLD_CONFIG_FILE] = $self->vardir."/my.cnf";
        open(CONFIG,">$self->[MYSQLD_CONFIG_FILE]") || die "Could not open $self->[MYSQLD_CONFIG_FILE] for writing: $!\n";
        print CONFIG @{$self->[MYSQLD_CONFIG_CONTENTS]};
        close CONFIG;
    }

    my $defaults = ($self->[MYSQLD_CONFIG_FILE] ? "--defaults-file=$self->[MYSQLD_CONFIG_FILE]" : "--no-defaults");

    ## Create boot file

    my $boot = $self->vardir."/boot.sql";
    open BOOT,">$boot";
    print BOOT "CREATE DATABASE test;\n";

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
    push @$boot_options, "--loose-innodb-encrypt-tables=OFF";
    push @$boot_options, "--loose-innodb-encrypt-log=OFF";

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

    ## Add last strokes to the boot/init file: don't want empty users, but want the test user instead
    print BOOT "USE mysql;\n";
    print BOOT "DELETE FROM user WHERE `User` = '';\n";
    if ($self->user ne 'root') {
        print BOOT "CREATE TABLE tmp_user AS SELECT * FROM user WHERE `User`='root' AND `Host`='localhost';\n";
        print BOOT "UPDATE tmp_user SET `User` = '". $self->user ."';\n";
        print BOOT "INSERT INTO user SELECT * FROM tmp_user;\n";
        print BOOT "DROP TABLE tmp_user;\n";
        print BOOT "CREATE TABLE tmp_proxies AS SELECT * FROM proxies_priv WHERE `User`='root' AND `Host`='localhost';\n";
        print BOOT "UPDATE tmp_proxies SET `User` = '". $self->user . "';\n";
        print BOOT "INSERT INTO proxies_priv SELECT * FROM tmp_proxies;\n";
        print BOOT "DROP TABLE tmp_proxies;\n";
    }
    close BOOT;

    say("Bootstrap command: $command");
    system("$command > \"".$self->vardir."/boot.log\" 2>&1");
    return $?;
}

sub _reportError {
    say(Win32::FormatMessage(Win32::GetLastError()));
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
                                          "--max-allowed-packet=128Mb",	# Allow loading bigger blobs
                                          "--port=".$self->port,
                                          "--socket=".$self->socketfile,
                                          "--pid-file=".$self->pidfile],
                                         $self->_logOptions);
    if (defined $self->[MYSQLD_SERVER_OPTIONS]) {
        $command = $command." ".join(' ',@{$self->[MYSQLD_SERVER_OPTIONS]});
    }
    # If we don't remove the existing pidfile, 
    # the server will be considered started too early, and further flow can fail
    unlink($self->pidfile);
    
    my $errorlog = $self->vardir."/".MYSQLD_ERRORLOG_FILE;
    
    # In seconds, timeout for the server to start updating error log
    # after the server startup command has been launched
    my $start_wait_timeout= 30;

    # In seconds, timeout for the server to create pid file
    # after it has started updating the error log
    # (before the server is considered hanging)
    my $startup_timeout= 600;
    
    if ($self->[MYSQLD_VALGRIND]) {
        my $val_opt ="";
        $start_wait_timeout= 60;
        $startup_timeout= 1200;
        if (defined $self->[MYSQLD_VALGRIND_OPTIONS]) {
            $val_opt = join(' ',@{$self->[MYSQLD_VALGRIND_OPTIONS]});
        }
        $command = "valgrind --time-stamp=yes --leak-check=yes --suppressions=".$self->valgrind_suppressionfile." ".$val_opt." ".$command;
    }
    $self->printInfo;

    my $errlog_fh;
    my $errlog_last_update_time= (stat($errorlog))[9] || 0;
    if ($errlog_last_update_time) {
        open($errlog_fh,$errorlog) || ( sayError("Could not open the error log " . $errorlog . " for initial read: $!") && return DBSTATUS_FAILURE );
        while (!eof($errlog_fh)) { readline $errlog_fh };
        seek $errlog_fh, 0, 1;
    }

    say("Starting MySQL ".$self->version.": $command");

    $self->[MYSQLD_AUXPID] = fork();
    if ($self->[MYSQLD_AUXPID]) {

        ## Wait for the pid file to have been created
        my $wait_time = 0.2;
        my $waits= 0;
        my $errlog_update= 0;
        my $pid;
        my $wait_end= time() + $start_wait_timeout;

        # After we've launched server startup, we'll wait for max $start_wait_timeout seconds
        # for the server to start updating the error log
        while (!-f $self->pidfile and time() < $wait_end ) {
            Time::HiRes::sleep($wait_time);
            $errlog_update= ( (stat($errorlog))[9] > $errlog_last_update_time);
            last if $errlog_update;
        }

        if (-f $self->pidfile) {
            $pid= get_pid_from_file($self->pidfile);
            say("Server created pid file with pid $pid");
        } elsif (!$errlog_update) {
            sayError("Server has not started updating the error log withing $start_wait_timeout sec. timeout, and has not created pid file");
            sayFile($errorlog);
            return DBSTATUS_FAILURE;
        }

        if (!$pid)
        {
            # If we are here, server has started updating the error log.
            # It can be doing some lengthy startup before creating the pid file,
            # but we might be able to get the pid from the error log record
            # [Note] <path>/mysqld (mysqld <version>) starting as process <pid> ...
            # (if the server is new enough to produce it).
            # We need the latest line of this kind
            
            unless ($errlog_fh) {
                unless (open($errlog_fh, $errorlog)) {
                    sayError("Could not open the error log  " . $errorlog . ": $!");
                    return DBSTATUS_FAILURE;
                }
            }
            # In case the file is being slowly updated (e.g. with valgrind),
            # and pid is not the first line which was printed (again, as with valgrind),
            # we don't want to reach the EOF and exit too quickly.
            # So, first we read the whole file till EOF, and if the last line was a valgrind-produced line
            # (starts with '== ', we'll keep waiting for more updates, until we get the first normal line,
            # which is supposed to be the PID. If it's not, there is nothing more to wait for.
            # TODO:
            # - if it's not the first start in this error log, so our protection against
            #   quitting too quickly won't work -- we'll read a wrong (old) PID and will leave.
            # And of course it won't work on Windows, but the new-style server start is generally
            # not reliable there and needs to be fixed.

            TAIL:
            for (;;) {
                do {
                    $_= readline $errlog_fh;
                    if (/\[Note\]\s+\S+?[\/\\]mysqld(?:\.exe)\s+\(mysqld.*?\)\s+starting as process (\d+)\s+\.\./) {
                        $pid= $1;
                        last TAIL;
                    }
                    elsif (! /^== /) {
                        last TAIL;
                    }
                } until (eof($errlog_fh));
                sleep 1;
                seek ERRLOG, 0, 1;    # this clears the EOF flag
            }
        }
        close($errlog_fh) if $errlog_fh;

        unless (defined $pid) {
            say("WARNING: could not find the pid in the error log, might be an old version");
        }

        # Now we know the pid and can monitor it along with the pid file,
        # to avoid unnecessary waiting if the server goes down
        $wait_end= time() + $startup_timeout;

        while (!-f $self->pidfile and time() < $wait_end) {
            Time::HiRes::sleep($wait_time);
            last if $pid and not kill(0, $pid);
        }

        if (!-f $self->pidfile) {
            sayFile($errorlog);
            if ($pid and not kill(0, $pid)) {
                sayError("Server disappeared after having started with pid $pid");
            } elsif ($pid) {
                sayError("Timeout $startup_timeout has passed and the server still has not created the pid file, assuming it has hung, sending final SIGABRT to pid $pid...");
                kill 'ABRT', $pid;
            } else {
                sayError("Timeout $startup_timeout has passed and the server still has not created the pid file, assuming it has hung, but cannot kill because we don't know the pid");
            }
            return DBSTATUS_FAILURE;
        }

        # We should only get here if the pid file was created
        my $pidfile = $self->pidfile;
        my $pid_from_file= get_pid_from_file($self->pidfile);

        $pid_from_file =~ s/.*?([0-9]+).*/$1/;
        if ($pid and $pid != $pid_from_file) {
            say("WARNING: pid extracted from the error log ($pid) is different from the pid in the pidfile ($pid_from_file). Assuming the latter is correct");
        }
        $self->[MYSQLD_SERVERPID] = int($pid_from_file);
        say("Server started with PID ".$self->[MYSQLD_SERVERPID]);
    } else {
        exec("$command >> \"$errorlog\"  2>&1") || croak("Could not start mysql server");
    }

    return ($self->waitForServerToStart && $self->dbh) ? DBSTATUS_OK : DBSTATUS_FAILURE;
}

sub kill {
    my ($self) = @_;

    my $pidfile= $self->pidfile;

    if (not defined $self->serverpid and -f $pidfile) {
        $self->[MYSQLD_SERVERPID]= get_pid_from_file($self->pidfile);
    }

    if (defined $self->serverpid and $self->serverpid =~ /^\d+$/) {
        kill KILL => $self->serverpid;
        my $waits = 0;
        while ($self->running && $waits < 100) {
            Time::HiRes::sleep(0.2);
            $waits++;
        }
        if ($waits >= 100) {
            sayError("Unable to kill process ".$self->serverpid);
        } else {
            say("Killed process ".$self->serverpid);
        }
    }

    # clean up when the server is not alive.
    unlink $self->socketfile if -e $self->socketfile;
    unlink $self->pidfile if -e $self->pidfile;
    return ($self->running ? DBSTATUS_FAILURE : DBSTATUS_OK);
}

sub term {
    my ($self) = @_;

    my $res;
    if (defined $self->serverpid) {
        kill TERM => $self->serverpid;
        my $waits = 0;
        while ($self->running && $waits < 100) {
            Time::HiRes::sleep(0.2);
            $waits++;
        }
        if ($waits >= 100) {
            say("Unable to terminate process ".$self->serverpid.". Trying SIGABRT");
            kill ABRT => $self->serverpid;
            $res= DBSTATUS_FAILURE;
            $waits= 0;
            while ($self->running && $waits < 20) {
              Time::HiRes::sleep(0.2);
              $waits++;
            }
            if ($waits >= 20) {
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
 
}

sub corefile {
    my ($self) = @_;

    ## Unix variant
    return $self->datadir."/core.".$self->serverpid;
}

sub upgradeDb {
  my $self= shift;

  my $mysql_upgrade= $self->_find([$self->basedir],
                                        osWindows()?["client/Debug","client/RelWithDebInfo","client/Release","bin"]:["client","bin"],
                                        osWindows()?"mysql_upgrade.exe":"mysql_upgrade");
  my $upgrade_command=
    '"'.$mysql_upgrade.'" --host=127.0.0.1 --port='.$self->port.' -uroot';
  my $upgrade_log= $self->datadir.'/mysql_upgrade.log';
  say("Running mysql_upgrade:\n  $upgrade_command");
  my $res= system("$upgrade_command > $upgrade_log");
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
  }
  return $res;
}

sub dumper {
    return $_[0]->[MYSQLD_DUMPER];
}

sub dumpdb {
    my ($self,$database, $file) = @_;
    say("Dumping MySQL server ".$self->version." data on port ".$self->port);
    my $dump_command = '"'.$self->dumper.
                             "\" --hex-blob --skip-triggers --compact ".
                             "--order-by-primary --skip-extended-insert ".
                             "--no-create-info --host=127.0.0.1 ".
                             "--port=".$self->port.
                             " -uroot $database";
    # --no-tablespaces option was introduced in version 5.1.14.
    if ($self->_notOlderThan(5,1,14)) {
        $dump_command = $dump_command . " --no-tablespaces";
    }
    my $dump_result = system("$dump_command | sort > $file");
    return $dump_result;
}

sub dumpSchema {
    my ($self,$database, $file) = @_;
    say("Dumping MySQL server ".$self->version." schema on port ".$self->port);
    my $dump_command = '"'.$self->dumper.
                             "\" --hex-blob --compact ".
                             "--order-by-primary --skip-extended-insert ".
                             "--no-data --host=127.0.0.1 ".
                             "--port=".$self->port.
                             " -uroot $database";
    # --no-tablespaces option was introduced in version 5.1.14.
    if ($self->_notOlderThan(5,1,14)) {
        $dump_command = $dump_command . " --no-tablespaces";
    }
    my $dump_result = system("$dump_command > $file");
    return $dump_result;
}

# There are some known expected differences in dump structure between
# pre-10.2 and 10.2+ versions.
# We need to normalize the dumps to avoid false positives while comparing them.
# For now, we'll re-format to 10.1 style.
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
      if (s/AUTO_INCREMENT=\d+//) {};
      print DUMP2 $_;
    }
    close(DUMP1);
    close(DUMP2);
  }
  if ($self->versionNumeric() ge '100201') {
    say("normalizeDump patches DEFAULT clauses for version ".$self->versionNumeric);
    move($file, $file.'.tmp2');
    open(DUMP1,$file.'.tmp2');
    open(DUMP2,">$file");
    while (<DUMP1>) {
      # In 10.2 blobs can have a default clause
      # `col_blob` blob NOT NULL DEFAULT ... => `col_blob` blob NOT NULL.
      s/(\s+(?:blob|text|mediumblob|mediumtext|longblob|longtext|tinyblob|tinytext)(?:\s*NOT\sNULL)?)\s*DEFAULT\s*(?:\d+|NULL|\'[^\']*\')\s*(.*)$/${1}${2}/;
      # `k` int(10) unsigned NOT NULL DEFAULT '0' => `k` int(10) unsigned NOT NULL DEFAULT 0
      s/(DEFAULT\s+)(\d+)(.*)$/${1}\'${2}\'${3}/;
      print DUMP2 $_;
    }
    close(DUMP1);
    close(DUMP2);
  }
  if (-e $file.'.tmp1') {
    move($file.'.tmp1',$file.'.orig');
#    unlink($file.'.tmp2') if -e $file.'.tmp2';
  } elsif (-e $file.'.tmp2') {
    move($file.'.tmp2',$file.'.orig');
  }
}

sub nonSystemDatabases {
  my $self= shift;
  return @{$self->dbh->selectcol_arrayref(
      "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA ".
      "WHERE LOWER(SCHEMA_NAME) NOT IN ('mysql','information_schema','performance_schema','sys')"
    )
  };
}

sub collectAutoincrements {
  my $self= shift;
	my $autoinc_tables= $self->dbh->selectall_arrayref(
      "SELECT CONCAT(ist.TABLE_SCHEMA,'.',ist.TABLE_NAME), ist.AUTO_INCREMENT, isc.COLUMN_NAME, '' ".
      "FROM INFORMATION_SCHEMA.TABLES ist JOIN INFORMATION_SCHEMA.COLUMNS isc ON (ist.TABLE_SCHEMA = isc.TABLE_SCHEMA AND ist.TABLE_NAME = isc.TABLE_NAME) ".
      "WHERE ist.TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys') ".
      "AND ist.AUTO_INCREMENT IS NOT NULL ".
      "AND isc.EXTRA LIKE '%auto_increment%' ".
      "ORDER BY ist.TABLE_SCHEMA, ist.TABLE_NAME, isc.COLUMN_NAME"
    );
  foreach my $t (@$autoinc_tables) {
      $t->[3] = $self->dbh->selectrow_arrayref("SELECT IFNULL(MAX($t->[2]),0) FROM $t->[0]")->[0];
  }
  return $autoinc_tables;
}

sub binary {
    return $_[0]->[MYSQLD_MYSQLD];
}

sub stopServer {
    my ($self, $shutdown_timeout) = @_;
    $shutdown_timeout = 60 unless defined $shutdown_timeout;
    my $res;

    if ($shutdown_timeout and defined $self->[MYSQLD_DBH]) {
        say("Stopping server on port ".$self->port);
        ## Use dbh routine to ensure reconnect in case connection is
        ## stale (happens i.e. with mdl_stability/valgrind runs)
        my $dbh = $self->dbh();
        # Need to check if $dbh is defined, in case the server has crashed
        if (defined $dbh) {
            $res = $dbh->func('shutdown','127.0.0.1','root','admin');
            if (!$res) {
                ## If shutdown fails, we want to know why:
                say("Shutdown failed due to ".$dbh->err.":".$dbh->errstr);
                $res= DBSTATUS_FAILURE;
            }
        }
        if (!$self->waitForServerToStop($shutdown_timeout)) {
            # Terminate process
            say("Server would not shut down properly. Terminate it");
            $res= $self->term;
        } else {
            # clean up when server is not alive.
            unlink $self->socketfile if -e $self->socketfile;
            unlink $self->pidfile if -e $self->pidfile;
            $res= DBSTATUS_OK;
            say("Server has been stopped");
        }
    } else {
        say("Shutdown timeout or dbh is not defined, killing the server");
        $res= $self->kill;
    }
    return $res;
}

sub checkDatabaseIntegrity {
  my $self= shift;

  say("Testing database integrity");
  my $dbh= $self->dbh;
  my $status= DBSTATUS_OK;

  my $databases = $dbh->selectcol_arrayref("SHOW DATABASES");
  foreach my $database (@$databases) {
      next if $database =~ m{^(mysql|information_schema|pbxt|performance_schema)$}sio;
      $dbh->do("USE $database");
      my $tabl_ref = $dbh->selectcol_arrayref("SHOW FULL TABLES", { Columns=>[1,2] });
      # 1178 is ER_CHECK_NOT_IMPLEMENTED
      my %tables = @$tabl_ref;
      foreach my $table (sort keys %tables) {
        # Should not do CHECK etc., and especially ALTER, on a view
        next if $tables{$table} eq 'VIEW';
#        say("Verifying table: $database.$table:");
        my $check = $dbh->selectcol_arrayref("CHECK TABLE `$database`.`$table` EXTENDED", { Columns=>[3,4] });
        if ($dbh->err() > 0 && $dbh->err() != 1178) {
          sayError("Table $database.$table appears to be corrupted, error: ".$dbh->err());
          $status= DBSTATUS_FAILURE;
        }
        else {
          my %msg = @$check;
          foreach my $m (keys %msg) {
            say("For table `$database`.`$table` : $m $msg{$m}");
            if ($m ne 'status' and $m ne 'note') {
              $status= DBSTATUS_FAILURE;
            }
          }
        }
      }
  }
  if ($status > DBSTATUS_OK) {
    sayError("Database integrity check failed");
  }
  return $status;
}

sub addErrorLogMarker {
  my $self= shift;
  my $marker= shift;

    say("Adding marker $marker to the error log ".$self->errorlog);
  if (open(ERRLOG,">>".$self->errorlog)) {
    print ERRLOG "$marker\n";
    close (ERRLOG);
  } else {
    say("Could not add marker $marker to the error log ".$self->errorlog);
  }
}

sub waitForServerToStop {
  my $self= shift;
  my $timeout= shift;
  $timeout = (defined $timeout ? $timeout*2 : 120);
  my $waits= 0;
  while ($self->running && $waits < $timeout) {
    Time::HiRes::sleep(0.5);
    $waits++;
  }
  return !$self->running;
}

sub waitForServerToStart {
  my $self= shift;
  my $waits= 0;
  while (!$self->running && $waits < 120) {
    Time::HiRes::sleep(0.5);
    $waits++;
  }
  return $self->running;
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

  say("Checking server log for important errors starting from " . ($marker ? "marker $marker" : 'the beginning'));

  my $count= 0;
  while (<ERRLOG>)
  {
    next unless !$marker or $found_marker or /^$marker$/;
    $found_marker= 1;
		$_ =~ s{[\r\n]}{}siog;

    # Ignore certain errors
    next if
         $_ =~ /innodb_table_stats/so
      or $_ =~ /InnoDB: Cannot save table statistics for table/so
      or $_ =~ /InnoDB: Deleting persistent statistics for table/so
      or $_ =~ /InnoDB: Unable to rename statistics from/so
      or $_ =~ /ib_buffer_pool' for reading: No such file or directory/so
    ;

    # Crashes
    if (
           $_ =~ /Assertion\W/sio
        or $_ =~ /got signal/sio
        or $_ =~ /segmentation fault/sio
        or $_ =~ /segfault/sio
        or $_ =~ /exception/sio
    ) {
      say("------") unless $count++;
      say($_);
      push @crashes, $_;
    }
    # Other errors
    elsif (
           $_ =~ /\[ERROR\]\s+InnoDB/sio
        or $_ =~ /InnoDB:\s+Error:/sio
        or $_ =~ /registration as a STORAGE ENGINE failed./sio
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
    if ($self->serverpid and $self->serverpid =~ /^\d+$/) {
        ## Check if the child process is active.
        return kill(0,$self->serverpid);
    } elsif (-f $self->pidfile) {
        my $pid= get_pid_from_file($self->pidfile);
        if ($pid and $pid =~ /^\d+$/) {
          return kill(0,$pid);
        }
    } else {
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
    my $paths = "";
    foreach my $base (@$bases) {
        $paths .= join(",",map {"'".$base."/".$_."'"} @$subdir).",";
    }
    my $names = join(" or ", @names );
    croak "Cannot find '$names' in $paths"; 
}

sub dsn {
    my ($self,$database) = @_;
    $database = "test" if not defined MYSQLD_DEFAULT_DATABASE;
    return "dbi:mysql:host=127.0.0.1:port=".
        $self->[MYSQLD_PORT].
        ":user=".
        $self->[MYSQLD_USER].
        ":database=".$database.
        ":mysql_local_infile=1";
}

sub dbh {
    my ($self) = @_;
    if (defined $self->[MYSQLD_DBH]) {
        if (!$self->[MYSQLD_DBH]->ping) {
            say("Stale connection to ".$self->[MYSQLD_PORT].". Reconnecting");
            $self->[MYSQLD_DBH] = DBI->connect($self->dsn("mysql"),
                                               undef,
                                               undef,
                                               {PrintError => 0,
                                                RaiseError => 0,
                                                AutoCommit => 1,
                                                mysql_auto_reconnect => 1});
        }
    } else {
        say("Connecting to ".$self->[MYSQLD_PORT]);
        $self->[MYSQLD_DBH] = DBI->connect($self->dsn("mysql"),
                                           undef,
                                           undef,
                                           {PrintError => 0,
                                            RaiseError => 0,
                                            AutoCommit => 1,
                                            mysql_auto_reconnect => 1});
    }
    if(!defined $self->[MYSQLD_DBH]) {
        sayError("(Re)connect to ".$self->[MYSQLD_PORT]." failed due to ".$DBI::err.": ".$DBI::errstr);
    }
    return $self->[MYSQLD_DBH];
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

    say("MySQL Version: ". $self->version);
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
    my $self = shift;
    $self->version =~ /([0-9]+)\.([0-9]+)\.([0-9]+)/;
    return sprintf("%02d%02d%02d",int($1),int($2),int($3));
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

    if    ($v1 == 10 and $b1 == 5 and ($v2 == 0 or $v2 == 1 or $v2 == 2)) { $v1 = 5; $v2 = 6 }
    elsif ($v1 == 10 and $b1 == 5 and $v2 == 3) { $v1 = 5; $v2 = 7 }
    elsif ($v1 == 5 and $b1 == 10 and ($b2 == 0 or $b2 == 1 or $b2 == 2)) { $b1 = 5; $b2 = 6 }
    elsif ($v1 == 5 and $b1 == 10 and $b2 == 3) { $b1 = 5; $b2 = 7 }

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
	return $p;
}

