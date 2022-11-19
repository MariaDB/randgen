# Copyright (c) 2010, 2011, Oracle and/or its affiliates. All rights
# reserved.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2022, MariaDB
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

package DBServer;
use base 'Exporter';

@EXPORT = ('DBSTATUS_OK','DBSTATUS_FAILURE');

use Carp;
use GenUtil;

use strict;

use constant DBSTATUS_OK => 0;
use constant DBSTATUS_FAILURE => 1;

1;

sub new {
  my $class = shift;
  my $args = shift;

  my $obj = bless ([], $class);

  my $max_arg = (scalar(@_) / 2) - 1;

  foreach my $i (0..$max_arg) {
    if (exists $args->{$_[$i * 2]}) {
      if (defined $obj->[$args->{$_[$i * 2]}]) {
        carp("Argument '$_[$i * 2]' passed twice to ".$class.'->new()');
      } else {
        $obj->[$args->{$_[$i * 2]}] = $_[$i * 2 + 1];
      }
    } else {
      carp("Unkown argument '$_[$i * 2]' to ".$class.'->new()');
    }
  }
  return $obj;
}

1;
