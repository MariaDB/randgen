#  Copyright (c) 2018,2021 MariaDB Corporation
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

query_init:
  { %active_xa = (); %idle_xa = (); %prepared_xa = (); '' }
;

query:
  { $current_xid= ''; $last_xa_stage= '' } xa_query
;

xa_query:
  ==FACTOR:10== xa_valid_sequence
#  | xa_random
;

xa_valid_sequence:
  xa_begin ; xa_opt_recover xa_query_sequence ; xa_opt_recover XA END { $last_xid } ; xa_opt_recover XA PREPARE { $last_xid } ; xa_opt_recover XA COMMIT { $last_xid } |
  xa_begin ; xa_opt_recover xa_query_sequence ; xa_opt_recover XA END { $last_xid } ; xa_opt_recover XA COMMIT { $last_xid } ONE PHASE |
  xa_begin ; xa_opt_recover xa_query_sequence ; xa_opt_recover XA END { $last_xid } ; xa_opt_recover XA PREPARE { $last_xid } ; xa_opt_recover XA ROLLBACK { $last_xid }
;

xa_opt_recover:
  { $prng->uint16(0,3) ? 'XA RECOVER ;' : '' };

xa_random:
    xa_begin
  | xa_end
  | xa_prepare
  | xa_commit_one_phase
  | xa_commit
  | xa_rollback
  | XA RECOVER
;

xa_query_sequence:
  ==FACTOR:2== query
  | xa_query_sequence ; query
;

xa_begin:
  XA xa_start_begin xa_xid xa_opt_join_resume { $active_xa{$last_xid}= 1 ; '' } ;

xa_end:
  XA END xa_xid_active xa_opt_suspend_opt_for_migrate { $idle_xa{$last_xid}= 1; delete $active_xa{$last_xid}; '' } ;

xa_prepare:
  XA PREPARE xa_xid_idle { $prepared_xa{$last_xid}= 1; delete $idle_xa{$last_xid}; '' } ;

xa_commit:
  XA COMMIT xa_xid_prepared { delete $idle_xa{$last_xid}; '' } ;

xa_commit_one_phase:
  XA COMMIT xa_xid_idle ONE PHASE { delete $idle_xa{$last_xid}; '' } ;

xa_rollback:
  XA ROLLBACK xa_xid_prepared { delete $prepared_xa{$last_xid}; '' } ;

# Not supported
xa_opt_suspend_opt_for_migrate:
#  | SUSPEND xa_opt_for_migrade
;

xa_opt_for_migrade:
  | FOR MIGRATE
;

xa_start_begin:
  START | BEGIN
;

# Not supported
xa_opt_join_resume:
#  | JOIN | RESUME
;

xa_xid:
  { $last_xid= "'xid".$prng->int(1,200)."'" }
;

xa_xid_active:
  { $last_xid= (scalar(keys %active_xa) ? $prng->arrayElement([keys %active_xa]) : "'inactive_xid'"); $last_xid }
;

xa_xid_idle:
  { $last_xid= (scalar(keys %idle_xa) ? $prng->arrayElement([keys %idle_xa]) : "'non_idle_xid'"); $last_xid }
;

xa_xid_prepared:
  { $last_xid= (scalar(keys %prepared_xa) ? $prng->arrayElement([keys %prepared_xa]) : "'non_prepared_xid'"); $last_xid }
;
