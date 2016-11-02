# Copyright (C) 2016 MariaDB Corporation Ab
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

# The module checks that after the test flow has finished, 
# the server is able to restart successfully without losing any data

# It is supposed to be used with the native server startup,
# i.e. with runall-new.pl rather than runall.pl which is MTR-based.



package GenTest::Reporter::RestartConsistency;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use DBI;
use GenTest;
use GenTest::Constants;
use GenTest::Reporter;
use GenTest::Comparator;
use Data::Dumper;
use IPC::Open2;
use File::Copy;
use POSIX;

use DBServer::MySQL::MySQLd;

my $first_reporter;
my $vardir;

sub report {
    my $reporter = shift;

    # In case of two servers, we will be called twice.
    # Only kill the first server and ignore the second call.
    
    $first_reporter = $reporter if not defined $first_reporter;
    return STATUS_OK if $reporter ne $first_reporter;

    my $dbh = DBI->connect($reporter->dsn());

    dump_database($reporter,$dbh,'before');

    my $pid = $reporter->serverInfo('pid');
    kill(15, $pid);

    foreach (1..60) {
        last if not kill(0, $pid);
        sleep 1;
    }
    if (kill(0, $pid)) {
        say("ERROR: could not shut down server with pid $pid");
        return STATUS_SERVER_DEADLOCKED;
    } else {
        say("Server with pid $pid has been shut down");
    }

    my $datadir = $reporter->serverVariable('datadir');
    $datadir =~ s{[\\/]$}{}sgio;
    my $orig_datadir = $datadir.'_orig';
    my $pid = $reporter->serverInfo('pid');

    my $engine = $reporter->serverVariable('storage_engine');

    my $server = $reporter->properties->servers->[0];
    say("Copying datadir... (interrupting the copy operation may cause investigation problems later)");
    if (osWindows()) {
        system("xcopy \"$datadir\" \"$orig_datadir\" /E /I /Q");
    } else { 
        system("cp -r $datadir $orig_datadir");
    }
    move($server->errorlog, $server->errorlog.'_orig');
    unlink("$datadir/core*");    # Remove cores from any previous crash

    say("Restarting server ...");

    $server->setStartDirty(1);
    my $recovery_status = $server->startServer();
    open(RECOVERY, $server->errorlog);

    while (<RECOVERY>) {
        $_ =~ s{[\r\n]}{}siog;
        say($_);
        if ($_ =~ m{registration as a STORAGE ENGINE failed.}sio) {
            say("Storage engine registration failed");
            $recovery_status = STATUS_DATABASE_CORRUPTION;
        } elsif ($_ =~ m{corrupt|crashed}) {
            say("Log message '$_' might indicate database corruption");
        } elsif ($_ =~ m{exception}sio) {
            $recovery_status = STATUS_DATABASE_CORRUPTION;
        } elsif ($_ =~ m{ready for connections}sio) {
            say("Server Recovery was apparently successfull.") if $recovery_status == STATUS_OK ;
            last;
        } elsif ($_ =~ m{device full error|no space left on device}sio) {
            $recovery_status = STATUS_ENVIRONMENT_FAILURE;
            last;
        } elsif (
            ($_ =~ m{got signal}sio) ||
            ($_ =~ m{segfault}sio) ||
            ($_ =~ m{segmentation fault}sio)
        ) {
            say("Recovery has apparently crashed.");
            $recovery_status = STATUS_DATABASE_CORRUPTION;
        }
    }

    close(RECOVERY);

    $dbh = DBI->connect($reporter->dsn());
    $recovery_status = STATUS_DATABASE_CORRUPTION if not defined $dbh && $recovery_status == STATUS_OK;

    if ($recovery_status > STATUS_OK) {
        say("Restart has failed.");
        return $recovery_status;
    }
    
    # 
    # Phase 2 - server is now running, so we execute various statements in order to verify table consistency
    #

    say("Testing database consistency");

    my $databases = $dbh->selectcol_arrayref("SHOW DATABASES");
    foreach my $database (@$databases) {
        next if $database =~ m{^(mysql|information_schema|pbxt|performance_schema)$}sio;
        $dbh->do("USE $database");
        my $tabl_ref = $dbh->selectcol_arrayref("SHOW FULL TABLES", { Columns=>[1,2] });
        my %tables = @$tabl_ref;
        foreach my $table (keys %tables) {
            # Should not do CHECK etc., and especially ALTER, on a view
            next if $tables{$table} eq 'VIEW';
            say("Verifying table: $table; database: $database");
            $dbh->do("CHECK TABLE `$database`.`$table` EXTENDED");
            # 1178 is ER_CHECK_NOT_IMPLEMENTED
            return STATUS_DATABASE_CORRUPTION if $dbh->err() > 0 && $dbh->err() != 1178;
        }
    }
    say("Schema does not look corrupt");

    # 
    # Phase 3 - dump the server again and compare dumps
    #
    dump_database($reporter,$dbh,'after');
    return compare_dumps();
}
    
    
sub dump_database {
    # Suffix is "before" or "after" (restart)
    my ($reporter, $dbh, $suffix) = @_;
    my $port = $reporter->serverVariable('port');
    $vardir = $reporter->properties->servers->[0]->vardir() unless defined $vardir;
    
	my @all_databases = @{$dbh->selectcol_arrayref("SHOW DATABASES")};
	my $databases_string = join(' ', grep { $_ !~ m{^(mysql|information_schema|performance_schema)$}sgio } @all_databases );
	
    say("Dumping the server $suffix restart");
    my $dump_file = "$vardir/server_$suffix.dump";
    my $dump_result = system('"'.$reporter->serverInfo('client_bindir')."/mysqldump\" --hex-blob --no-tablespaces --compact --order-by-primary --skip-extended-insert --host=127.0.0.1 --port=$port --user=root --password='' --databases $databases_string > $dump_file");
    return ($dump_result ? STATUS_ENVIRONMENT_FAILURE : STATUS_OK);
}

sub compare_dumps {
	say("Comparing SQL dumps between servers before and after restart...");
	my $diff_result = system("diff -u $vardir/server_before.dump $vardir/server_after.dump");
	$diff_result = $diff_result >> 8;

	if ($diff_result == 0) {
		say("No differences were found between server contents before and after restart.");
		return STATUS_OK;
	} else {
		say("Server contents has changed");
		return STATUS_DATABASE_CORRUPTION;
	}
}

sub type {
    return REPORTER_TYPE_ALWAYS;
}

1;
