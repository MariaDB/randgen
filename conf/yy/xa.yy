#  Copyright (c) 2018, 2022 MariaDB Corporation
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
# While the grammar can be used alone, it mainly implies that there are
# queries from other grammars interleaved with its XA actions,
# otherwise it just produces empty XA transactions
########################################################################

#features XA transactions

query_init:
  { %active_xa = (); %idle_xa = (); %prepared_xa = (); $current_xid= ''; $current_stage= ''; '' }
;

query:
  { _set_db('user') } xa_query
;

xa_query:
  ==FACTOR:10== xa_valid_transition
#  | xa_random
;

xa_valid_transition:
  # If there is an ongoing "normal" transaction from other grammars,
  # then XA won't be able to start. So, we need to end it first
  { $current_stage eq '' ? $prng->uint16(0,2) ? 'COMMIT ;;' : 'ROLLBACK ;;' : '' }
  XA { $one_phase= ''; $xid= $current_xid
       ; if    ($current_stage eq '')         { $current_stage= 'active'; $current_xid= "'xid".$prng->uint16(1,50)."'"; $xid= $current_xid; ( $prng->uint16(0,1) ? 'BEGIN' : 'START' ) }
         elsif ($current_stage eq 'active')   { $current_stage= 'idle';   'END' }
         elsif ($current_stage eq 'idle')     { if ($prng->uint16(0,1)) { $current_stage= 'prepared'; 'PREPARE' }
                                                else                   { $current_stage= ''; $one_phase='ONE PHASE'; 'COMMIT' } }
         elsif ($current_stage eq 'prepared') { $current_stage= ''; $current_xid= ''; ($prng->uint16(0,1) ? 'COMMIT' : 'ROLLBACK') }
         else { 'RECOVER' }
     } { "$xid $one_phase" }
;

xa_random:
    xa_begin
  | xa_end
  | xa_prepare
  | xa_commit_one_phase
  | xa_commit
  | xa_rollback
  | XA RECOVER
;

xa_begin:
  XA __start_x_begin xa_xid { $active_xa{$last_xid}= 1 ; '' } ;

xa_end:
  XA END xa_xid_active { $idle_xa{$last_xid}= 1; delete $active_xa{$last_xid}; '' } ;

xa_prepare:
  XA PREPARE xa_xid_idle { $prepared_xa{$last_xid}= 1; delete $idle_xa{$last_xid}; '' } ;

xa_commit:
  XA COMMIT xa_xid_prepared { delete $idle_xa{$last_xid}; '' } ;

xa_commit_one_phase:
  XA COMMIT xa_xid_idle ONE PHASE { delete $idle_xa{$last_xid}; '' } ;

xa_rollback:
  XA ROLLBACK xa_xid_prepared { delete $prepared_xa{$last_xid}; '' } ;

xa_xid:
  { $last_xid= "'xid".$prng->uint16(1,200)."'" }
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
