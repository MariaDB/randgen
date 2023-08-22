# Copyright (c) 2022, 2023 MariaDB
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
# Due to the legacy behavior described for example here
# https://jira.mariadb.org/browse/MDEV-24038?focusedCommentId=244262&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-244262
# it is easy to get a huge value of auto-increment on a table,
# and it causes further problems -- ER_AUTOINC_READ_FAILED, out of range, assertion failures.
# The validator will try to fix such tables. It is quite an overhead,
# so it should only be used with grammars which are prone to the problem
########################################################################

package GenTest::Validator::TableAutoIncrement;

require Exporter;
@ISA = qw(GenTest::Validator GenTest);

use strict;
use GenUtil;
use GenTest;
use Constants;
use GenTest::Validator;

use Data::Dumper;
use POSIX;

my ($broken_count, $fixed_count)= (0,0);

sub validate {
  my ($validator, $executors, $results) = @_;
  my $update= 0;
  foreach my $r (@$results) {
    if ($r->query =~ /INSERT|REPLACE|UPDATE/is) {
      $update=1;
      last;
    }
  }
  return STATUS_WONT_HANDLE unless $update;
  my $res= STATUS_OK;

  foreach my $e (@$executors) {
    my $tables= $e->connection->get_column("SELECT CONCAT(table_schema,'.',table_name) FROM INFORMATION_SCHEMA.TABLES WHERE AUTO_INCREMENT IN (18446744073709551615,2147483647,2147483648)");
    if ($tables) {
      foreach my $t (@$tables) {
        $broken_count++;
        $e->connection->execute("TRUNCATE TABLE $t");
        if ($e->connection->err) {
          sayWarning("TableAutoIncrement was trying to fix table $t but failed: ".$e->connection->print_error);
          $res= STATUS_RUNTIME_ERROR;
        } else {
          sayDebug("TableAutoIncrement truncated table $t due to a bad auto-increment value");
          $fixed_count++;
        }
      }
    }
  }
  return $res;
}

sub DESTROY {
  say("TableAutoIncrement reporter statistics: found $broken_count broken tables, fixed $fixed_count");
}

1;

