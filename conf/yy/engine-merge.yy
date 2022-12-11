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

query_init:
  { $tblnum= 0; '' } ;

query:
  { _set_db('NON-SYSTEM') }
     CREATE /* _basetable[invariant] */ OR REPLACE TABLE { $tblname= $last_table; $tblname =~ s/(_MRG(?:_BASE)?_\d+)?$//; $tblname.'_MRG_BASE_'.(++$tblnum) } LIKE _basetable[invariant] 
  ;; ALTER TABLE { $tblname.'_MRG_BASE_'.$tblnum } ENGINE=MyISAM
  ;; CREATE OR REPLACE TABLE { $tblname.'_MRG_'.$tblnum } LIKE { $tblname.'_MRG_BASE_'.$tblnum }
  ;; ALTER TABLE { $tblname.'_MRG_'.$tblnum } ENGINE=MERGE, UNION({ $tblname.'_MRG_BASE_'.$tblnum })
;
