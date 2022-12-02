#  Copyright (c) 2019, 2022, MariaDB Corporation Ab
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; version 2 of the License.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA */

########################################################################
# The grammar should be used with
# --mysqld=--plugin-load-add=disks --mysqld=--loose-disks
#
# While the grammar tries to install the plugin at runtime, it wouldn't
# be sufficient for static builds, and besides some scenarios, such as
# replication for example, may well filter out INSTALL queries as they
# generall cause discrepancy between master and slave (although for
# a plugin read-only by nature, like disks, it shouldn't be a problem).
########################################################################

query_init:
  INSTALL SONAME 'disks';

query:
  ==FACTOR:0.001== disks_query ;

disks_query:
  SELECT SUM(Total) > SUM(Available), SUM(Total)>SUM(Used) FROM INFORMATION_SCHEMA.DISKS |
  SELECT * FROM INFORMATION_SCHEMA.DISKS |
  SHOW CREATE TABLE INFORMATION_SCHEMA.DISKS
;
