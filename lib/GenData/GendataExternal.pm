# Copyright (c) 2024, MariaDB
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

package GenData::GendataExternal;
@ISA = qw(GenData);

use strict;
use Carp;
use Data::Dumper;
use File::Basename;

use GenData;
use GenTest;
use Constants;
use GenTest::Executor;
use GenTest::Random;
use GenUtil;

# Currently implemented for MyISAM and InnoDB.
# The module is activated by --gendata=<full path to a directory>.
# It creates a schema named <basename(full path to a directory)>.
# Then the module checks for existing <name>.MYD files, and for each found <name>
# it copies all <name>.* files to the newly created schema directory.
# Then it checks for existing <name>.ibd files, for each found <name>
# it looks for <name>.sql (it is supposed to contain the InnoDB table definition),
# executes it, discards the empty tablespace,
# copies <name>.ibd file to the schema directory,and imports it.
# At the end, if flushes tables.
# Should not be used with replication.

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    return $self;
}

sub run {
    my $self= shift;

    my $executor = $self->executor();
    my $spec_dir = $self->spec_file();
    unless (-d $spec_dir) {
      sayError("The specified path $spec_dir does not exist or is not a directory");
      return STATUS_ENVIRONMENT_FAILURE;
    }
    my $schema_name= basename($spec_dir);
    my $datadir= $executor->server->serverVariable('datadir');

    $executor->connection->query("CREATE DATABASE IF NOT EXISTS $schema_name");
    $executor->connection->query("USE `$schema_name`");

    my @myisam= glob("$spec_dir/*.MYD");
    foreach my $f (@myisam) {
      my ($name,undef,$ext) = fileparse("$f", qr/\.[^.]*/);
      if (-e "$spec_dir/$name.frm" && -e "$spec_dir/$name.MYI") {
        say("Found MyISAM table $name, copying...");
        system("cp $spec_dir/$name.* $spec_dir/$name#* $datadir/$schema_name/");
      } else {
        sayWarning("Found $name.MYD file, but either $name.frm or $name.MAI does not exist, ignoring");
      }
    }

    my @innodb= glob("$spec_dir/*.ibd");
    foreach my $f (@innodb) {
      my ($name,undef,$ext) = fileparse("$f", qr/\.[^.]*/);
      my @vec= glob("$spec_dir/$name#i#*.ibd");
      if (scalar @vec) {
        sayWarning("Found InnoDB table $name with vector key, tablespace actions are not supported yet, ignoring");
        next;
      }
      if (-e "$spec_dir/$name.sql") {
        say("Found InnoDB table $name, trying to create...");
        open(CONF , "$spec_dir/$name.sql") or croak "unable to open file '$spec_dir/$name.sql': $!";
        read(CONF, my $spec_text, -s "$spec_dir/$name.sql");
        close(CONF);
        if ($spec_text) {
            $spec_text =~ s/\n/ /g;
            $executor->connection->query("$spec_text");
            if ($executor->connection->err) {
              sayError("Failed to create InnoDB table $name: $executor->connection->err");
              next;
            }
            $executor->connection->query("ALTER TABLE $name DISCARD TABLESPACE");
            system("cp $spec_dir/$name*.ibd $datadir/$schema_name/");
            $executor->connection->query("ALTER TABLE $name IMPORT TABLESPACE");
        }
      } else {
        sayWarning("Found $name.ibd file, but not the .sql definition of the table, ignoring");
      }
    }

    $executor->connection->query("FLUSH TABLES");
    $executor->connection->query("GRANT ALL ON $schema_name.* TO PUBLIC");
    return STATUS_OK;
}

1;
