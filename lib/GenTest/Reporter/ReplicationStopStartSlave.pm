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

package GenTest::Reporter::ReplicationStopStartSlave;

#
# Every monitoring cycle, stops the slave with STOP SLAVE, leaves it stopped for
# 0, 1 and 5 seconds in turn while the workload keeps running on the master,
# and then starts it again with START SLAVE.
#
# Unlike ReplicationThreadRestarter, which alternates STOP and START between
# cycles on a random subset of the slave threads, this reporter always acts on
# both slave threads and always does the STOP SLAVE / START SLAVE pair within
# one cycle.
#
# Usage:
#
#   --reporters=ErrorLog,Backtrace,ReplicationStopStartSlave
#
# Passing --reporters replaces the default reporters, so ErrorLog and Backtrace
# have to be listed as well. With --rpl_mode, ReplicationConsistency and
# ReplicationSlaveStatus are added automatically.
#
# The first cycle runs shortly after the workload starts and the next ones every
# 10 seconds (plus the time the slave is left stopped), so the test has to run
# long enough to get several cycles, e.g. --queries=25000 instead of 2000.
#
# The slave is located with SHOW SLAVE HOSTS, falling back to 127.0.0.1 on the
# master's port + 2, and is accessed as root without a password.
#
# Do not use it together with the ReplicationWaitForSlave validator: while the
# SQL thread is stopped, MASTER_POS_WAIT returns NULL and the validator reports
# a replication failure.
#

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use DBI;
use GenTest;
use GenTest::Reporter;
use GenTest::Constants;

# Seconds the slave is left stopped, one value per monitoring cycle in turn;
# 0 means START SLAVE immediately after STOP SLAVE
my @stop_seconds = (0, 1, 5);
my $cycle = 0;

sub monitor {

	my $reporter = shift;

	my $slave_dbh = connectToSlave($reporter);
	return STATUS_SERVER_CRASHED if not defined $slave_dbh;

	my $stop_seconds = $stop_seconds[$cycle++ % scalar(@stop_seconds)];

	$slave_dbh->do("STOP SLAVE");
	if ($slave_dbh->err()) {
		say("Query STOP SLAVE failed: ".$slave_dbh->errstr());
		return STATUS_REPLICATION_FAILURE;
	}

	sleep($stop_seconds) if $stop_seconds > 0;

	$slave_dbh->do("START SLAVE");
	if ($slave_dbh->err()) {
		say("Query START SLAVE failed: ".$slave_dbh->errstr());
		return STATUS_REPLICATION_FAILURE;
	}

	say("ReplicationStopStartSlave: STOP SLAVE, START SLAVE after $stop_seconds seconds.");
	return STATUS_OK;
}

sub report {

	my $reporter = shift;

	# Make sure the slave is running before the end-of-test checks
	my $slave_dbh = connectToSlave($reporter);
	return STATUS_SERVER_CRASHED if not defined $slave_dbh;

	$slave_dbh->do("START SLAVE");
	if ($slave_dbh->err()) {
		say("Query START SLAVE failed: ".$slave_dbh->errstr());
		return STATUS_REPLICATION_FAILURE;
	}

	return STATUS_OK;
}

sub connectToSlave {

	my $reporter = shift;

	my $slave_host = $reporter->serverInfo('slave_host');
	my $slave_port = $reporter->serverInfo('slave_port');

	# Same fallback as in ReplicationConsistency, for when SHOW SLAVE HOSTS had no data
	$slave_host = '127.0.0.1' if not defined $slave_host or $slave_host eq '';
	$slave_port = $reporter->serverVariable('port') + 2 if not defined $slave_port or $slave_port eq '';

	my $slave_dsn = 'dbi:mysql:host='.$slave_host.':port='.$slave_port.':user=root';
	my $slave_dbh = DBI->connect($slave_dsn, undef, undef, { PrintError => 0 });
	say("Could not connect to the slave on port $slave_port: ".$DBI::errstr) if not defined $slave_dbh;

	return $slave_dbh;
}

sub type {

	return REPORTER_TYPE_PERIODIC | REPORTER_TYPE_SUCCESS;
}

1;
