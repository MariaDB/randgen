# Copyright (C) 2013 Monty Program Ab
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

$| = 1;
use strict;
use lib 'lib';
use lib "$ENV{RQG_HOME}/lib";
use Carp;
use GenTest;
use GenTest::Constants;
use GenTest::App::PopulateSchema;
use Getopt::Long;

my ($schema_file, $debug, $help, $dsn, $rows, $server_id, $seed, $basedir);

my $opt_result = GetOptions(
	'help'	=> \$help,
	'schema:s' => \$schema_file,
	'debug'	=> \$debug,
	'dsn:s'	=> \$dsn,
	'seed=s' => \$seed,
	'rows=s' => \$rows,
	'server-id=i' => \$server_id,
	'basedir=s' => \$basedir
);

if ($help) {
	help();
	exit;
} elsif (not defined $schema_file) {
	print("\nERROR: schema file is not defined\n\n");
	help();
	exit(1);
} elsif (!$opt_result) {
	say("ERROR: could not parse the command-line options\n");
	help();
	exit(1);
}

my $app = GenTest::App::PopulateSchema->new(schema_file => $schema_file,
                                     debug => $debug,
                                     dsn => $dsn,
                                     seed => $seed,
                                     rows => $rows,
                                     server_id => $server_id,
                                     basedir => $basedir
			);


my $status = $app->run();

exit $status;

sub help {

        print <<EOF
$0 - Random Population of a given schema. Options:

        --debug         : Turn on debugging for additional output
        --dsn           : DBI resource to connect to
  (req) --schema        : SQL file defining the schemata (normally mysqldump file without the data)
        --rows          : Number of rows to generate for each table
        --seed          : Seed to PRNG. if --seed=time the current time will be used. (default 1)
        --basedir       : basedir where MySQL client can be found
        --help          : This help message

EOF
        ;
        exit(1);
}
