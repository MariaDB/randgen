#  Copyright (c) 2020, 2025, MariaDB Corporation
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

#include <conf/yy/include/basics.inc>

query:
                   SET SESSION dynvar_session_variable
  | ==FACTOR:0.1== SET GLOBAL dynvar_global_variable
;

dynvar_session_variable:
    ARIA_REPAIR_THREADS= { $prng->int(1,10) }
  | ARIA_SORT_BUFFER_SIZE= { $prng->arrayElement([4096,16384,65536,1048576,134217728,268434432]) }
  | ARIA_STATS_METHOD= { $prng->arrayElement(['nulls_equal','nulls_unequal','nulls_ignored']) }
  | DEADLOCK_SEARCH_DEPTH_SHORT= { $prng->int(0,32) }
  | DEADLOCK_TIMEOUT_LONG= { $prng->arrayElement([0,1,10000,50000000,4294967295]) }
  | DEADLOCK_TIMEOUT_SHORT= { $prng->arrayElement([0,1,10000,50000000,4294967295]) }
;

dynvar_global_variable:
    ARIA_CHECKPOINT_INTERVAL= { $prng->int(0,300) }
  | ARIA_CHECKPOINT_LOG_ACTIVITY= { $prng->arrayElement([0,1024,8192,16384,65536,1048576,4194304,16777216]) }
# Disabled due to MDEV-24640
# | ARIA_ENCRYPT_TABLES= dynvar_boolean
  | ARIA_LOG_FILE_SIZE= { $prng->arrayElement([65536,1048576,134217728,1073741824]) }
  | ARIA_LOG_PURGE_TYPE= { $prng->arrayElement(['immediate','external','at_flush']) }
  | ARIA_MAX_SORT_FILE_SIZE= { $prng->arrayElement([65536,1048576,134217728,1073741824,9223372036854775807]) }
  | ARIA_PAGECACHE_AGE_THRESHOLD= { $prng->arrayElement([100,1000,10000,9999900]) }
  | ARIA_PAGECACHE_DIVISION_LIMIT= { $prng->int(1,100) }
  | ARIA_PAGE_CHECKSUM= dynvar_boolean
  | ARIA_RECOVER_OPTIONS= dynvar_recover_options_value
  | ARIA_REPAIR_THREADS= { $prng->int(1,10) }
  | ARIA_SORT_BUFFER_SIZE= { $prng->arrayElement([4096,16384,65536,1048576,134217728,268434432]) }
  | ARIA_STATS_METHOD= { $prng->arrayElement(['nulls_equal','nulls_unequal','nulls_ignored']) }
  | ARIA_SYNC_LOG_DIR= { $prng->arrayElement(['NEWFILE','NEVER','ALWAYS']) }
  | DEADLOCK_SEARCH_DEPTH_SHORT= { $prng->int(0,32) }
  | DEADLOCK_TIMEOUT_LONG= { $prng->arrayElement([0,1,10000,50000000,4294967295]) }
  | DEADLOCK_TIMEOUT_SHORT= { $prng->arrayElement([0,1,10000,50000000,4294967295]) }

;

# EXTENDED_MORE added in 10.5

dynvar_default_regex_flags_value:
    { @flags= qw(
          DOTALL
          DUPNAMES
          EXTENDED
          EXTENDED_MORE
          EXTRA
          MULTILINE
          UNGREEDY
        ); $length=$prng->int(0,scalar(@flags))
        ; $val= "'" . (join ',', @{$prng->shuffleArray(\@flags)}[0..$length-1]) . "'"
        ; if (index($val,'EXTENDED_MORE') > -1) { $val.= '/* compatibility 10.5 */' }
        ; $val
    }
;

dynvar_tz_value:
  { sprintf("'%s%02d:%02d'",$prng->arrayElement(['+','-']),$prng->int(0,12),$prng->int(0,59)) } |
  _timezone
;

# 10.2: admin,filesort,filesort_on_disk,full_join,full_scan,query_cache,query_cache_miss,tmp_table,tmp_table_on_disk
# 10.3: + filesort_priority_queue,not_using_index

dynvar_log_slow_filter_value:
    DEFAULT
    | { @filters= qw(
          admin
          filesort
          filesort_on_disk
          filesort_priority_queue
          full_join
          full_scan
          not_using_index
          query_cache
          query_cache_miss
          tmp_table
          tmp_table_on_disk
        ); $length=$prng->int(0,scalar(@filters))
        ; $val= "'" . (join ',', @{$prng->shuffleArray(\@filters)}[0..$length-1]) . "'"
        ; if ((index($val,'filesort_priority_queue') > -1) or (index($val,'not_using_index') > -1)) { $val.= ' /* compatibility 10.3.1 */' }
        ; $val
      }
;

dynvar_log_slow_disabled_statements_value:
    { @values= qw(admin call slave sp) ; $length= $prng->int(0,scalar(@values)); "'" . (join ',', @{$prng->shuffleArray(\@values)}[0..$length-1]) . "'" }
;

dynvar_log_slow_verbosity_value:
    { @vals= qw(
          query_plan
          innodb
          explain
        ); $length=$prng->int(0,scalar(@vals)); "'" . (join ',', @{$prng->shuffleArray(\@vals)}[0..$length-1]) . "'"
    }
;

dynvar_old_mode_value:
    { @modes= qw(
          NO_DUP_KEY_WARNINGS_WITH_IGNORE
          NO_PROGRESS_INFO
          ZERO_DATE_TIME_CAST
        ); $length=$prng->int(0,scalar(@modes)); "'" . (join ',', @{$prng->shuffleArray(\@modes)}[0..$length-1]) . "'"
    } |
    { @modes= qw(
          NO_DUP_KEY_WARNINGS_WITH_IGNORE
          NO_PROGRESS_INFO
          ZERO_DATE_TIME_CAST
          UTF8_IS_UTF8MB3
        ); $length=$prng->int(0,scalar(@modes)); "'" . (join ',', @{$prng->shuffleArray(\@modes)}[0..$length-1]) . "'"
    } /* compatibility 10.6.1 */ |
    { @modes= qw(
          NO_DUP_KEY_WARNINGS_WITH_IGNORE
          NO_PROGRESS_INFO
          ZERO_DATE_TIME_CAST
          UTF8_IS_UTF8MB3
          IGNORE_INDEX_ONLY_FOR_JOIN
          COMPAT_5_1_CHECKSUM
        ); $length=$prng->int(0,scalar(@modes)); "'" . (join ',', @{$prng->shuffleArray(\@modes)}[0..$length-1]) . "'"
    } /* compatibility 10.9.1 */ |
    { @modes= qw(
          NO_DUP_KEY_WARNINGS_WITH_IGNORE
          NO_PROGRESS_INFO
          ZERO_DATE_TIME_CAST
          UTF8_IS_UTF8MB3
          IGNORE_INDEX_ONLY_FOR_JOIN
          COMPAT_5_1_CHECKSUM
          NO_NULL_COLLATION_IDS
        ); $length=$prng->int(0,scalar(@modes)); "'" . (join ',', @{$prng->shuffleArray(\@modes)}[0..$length-1]) . "'"
    } /* compatibility 10.11.7 */ |
    { @modes= qw(
          NO_DUP_KEY_WARNINGS_WITH_IGNORE
          NO_PROGRESS_INFO
          ZERO_DATE_TIME_CAST
          LOCK_ALTER_TABLE_COPY
          UTF8_IS_UTF8MB3
          IGNORE_INDEX_ONLY_FOR_JOIN
          COMPAT_5_1_CHECKSUM
          NO_NULL_COLLATION_IDS
        ); $length=$prng->int(0,scalar(@modes)); "'" . (join ',', @{$prng->shuffleArray(\@modes)}[0..$length-1]) . "'"
    } /* compatibility 11.2.1 */
;

# 10.2:  index_merge,index_merge_union,index_merge_sort_union,index_merge_intersection,index_merge_sort_intersection,engine_condition_pushdown,index_condition_pushdown,derived_merge,derived_with_keys,firstmatch,loosescan,materialization,in_to_exists,semijoin,partial_match_rowid_merge,partial_match_table_scan,subquery_cache,mrr,mrr_cost_based,mrr_sort_keys,outer_join_with_cache,semijoin_with_cache,join_cache_incremental,join_cache_hashed,join_cache_bka,optimize_join_buffer_size,table_elimination,extended_keys,exists_to_in,orderby_uses_equalities,condition_pushdown_for_derived
# 10.3: + split_materialized
# 10.4: + condition_pushdown_for_subquery,rowid_filter,condition_pushdown_from_having
# 10.5: + not_null_range_scan

dynvar_all_optimizer_switches:
  { @modes= qw(
            index_merge
            index_merge_union
            index_merge_sort_union
            index_merge_intersection
            index_merge_sort_intersection
            engine_condition_pushdown
            index_condition_pushdown
            derived_merge
            derived_with_keys
            firstmatch
            loosescan
            materialization
            in_to_exists
            semijoin
            partial_match_rowid_merge
            partial_match_table_scan
            subquery_cache
            mrr
            mrr_cost_based
            mrr_sort_keys
            outer_join_with_cache
            semijoin_with_cache
            join_cache_incremental
            join_cache_hashed
            join_cache_bka
            optimize_join_buffer_size
            table_elimination
            extended_keys
            exists_to_in
            orderby_uses_equalities
            condition_pushdown_for_derived
            split_materialized
            condition_pushdown_for_subquery
            rowid_filter
            condition_pushdown_from_having
            not_null_range_scan
    ); ''
  };

dynvar_optimizer_switch_compatibility_markers:
  { if (index($val,'not_null_range_scan') > -1) { $val.= ' /* compatibility 10.5 */' }
    elsif ((index($val,'condition_pushdown_for_subquery') > -1) or (index($val,'rowid_filter') > -1) or (index($val,'condition_pushdown_from_having') > -1)) { $val.= ' /* compatibility 10.4 */' }
    elsif (index($val,'split_materialized') > -1) { $val.= ' /* compatibility 10.3.4 */' }
    ; $val }
  ;

dynvar_optimizer_switch_value:
    DEFAULT
    | dynvar_all_optimizer_switches
    { $length=$prng->int(0,scalar(@modes))
        ; $switch= (join ',', map {$_.'='.$prng->arrayElement(['on','off'])} @{$prng->shuffleArray(\@modes)}[0..$length-1])
        ; if ($switch =~ /materialization=off/) {
            if ($switch =~ /in_to_exists=off/) { $switch =~ s/in_to_exists=off/in_to_exists=on/ }
            elsif ($switch !~ /in_to_exists/) { $switch .= ',in_to_exists=on' }
          } elsif ($switch =~ /in_to_exists=off/) {
            if ($switch =~ /materialization=off/) { $switch =~ s/materialization=off/materialization=on/ }
            elsif ($switch !~ /materialization/) { $switch .= ',materialization=on' }
          }
        ; $val= "'" . $switch . "'"
        ; ''
    } dynvar_optimizer_switch_compatibility_markers
;

dynvar_session_track_system_variables_value:
    { @vars= keys %{$executors->[0]->server->serverVariables()}
      ; $length=$prng->int(0,scalar(@vars)/2)
      ; "'" . (join ',', @{$prng->shuffleArray(\@vars)}[0..$length-1]) . "'"
    }
  | '*'
  | DEFAULT
;

dynvar_recover_options_value:
    DEFAULT
    | { @filters= qw(
          BACKUP
          QUICK
          NORMAL
          FORCE
          OFF
        ); $length=$prng->int(0,scalar(@filters)); "'" . (join ',', @{$prng->shuffleArray(\@filters)}[0..$length-1]) . "'"
    }
;

dynvar_engines_list_value:
    DEFAULT
    | { @filters= qw(
          InnoDB
          MyISAM
          Aria
          MEMORY
          CSV
        ); $length=$prng->int(0,scalar(@filters)); "'" . (join ',', @{$prng->shuffleArray(\@filters)}[0..$length-1]) . "'"
    }
;

dynvar_boolean:
    0 | 1 ;

space_usage_val:
  DEFAULT |
  64*1024 |
  1024*1024 |
  4*1024*1024 |
  1024*1024*1024 |
  ==FACTOR:0.1== space_usage_val_invalid_value
;

space_usage_val_invalid_value:
  -2 | -1 | 0 | 1 | 2 | NULL;
