# Copyright (c) 2019 MariaDB Corporation AB. All rights reserved.
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

# Periodically reloads metadata.
# Recommended if the test performs DDL and uses standard grammar entries
# such as _table, _field, etc., rather than custom ones specified
# in the grammar itself

package GenTest::Validator::MetadataReload;

require Exporter;
@ISA = qw(GenTest::Validator GenTest);

use strict;

use DBI;
use GenTest;
use GenTest::Constants;
use GenTest::Validator;

use constant METADATA_RELOAD_INTERVAL => 30;

my $last_reload= time();
my $reloaded_before= 0;

my $dbh;

sub validate {
  
  return STATUS_OK 
    if $reloaded_before and time() < $last_reload + METADATA_RELOAD_INTERVAL
      # First time we reload sooner in case something was created
      # in query_init / threadX_init steps
      or time() < $last_reload + METADATA_RELOAD_INTERVAL / 2;

  $last_reload= time();
	my ($validator, $executors) = @_;

	foreach my $e (@$executors) {
    say("Validator::MetadataReload: Reloading metadata...");
    # 1 stands for "redo"
    my $r= $e->cacheMetaData(1);
	}
  $reloaded_before= 1;
  # If metadata fails to reload, it croaked anyway
	return STATUS_OK;
}

1;
