# Copyright (c) 2010, 2012, Oracle and/or its affiliates. All rights reserved.
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

########################################################################

query:
  ==FACTOR:0.001== { _set_db('user') }
     CREATE OR REPLACE TABLE { $last_table = $prng->arrayElement($executors->[0]->metaTables($last_database)); $last_table.'_MRG_BASE' } LIKE { $last_table } 
  ;; ALTER TABLE { $last_table.'_MRG_BASE' } ENGINE=MyISAM
  ;; CREATE OR REPLACE TABLE { $last_table.'_MRG' } LIKE { $last_table.'_MRG_BASE' }
  ;; ALTER TABLE { $last_table.'_MRG' } ENGINE=MERGE, UNION({ $last_table })
;
