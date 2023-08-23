# Copyright (c) 2023, MariaDB Corporation Ab.
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

#################################################################
# Optimizer-related variables
#################################################################

query:
  SET optimizer_var ;

optimizer_var:
  BIG_TABLES = __on_x_off |
  EQ_RANGE_INDEX_DIVE_LIMIT = eq_range_dive_val |
  EXPENSIVE_SUBQUERY_LIMIT = expensive_sq_val |
  HISTOGRAM_SIZE = histogram_size_val |
  HISTOGRAM_TYPE = histogram_type_val |
  IN_PREDICATE_CONVERSION_THRESHOLD = in_predicate_val |
  JOIN_BUFFER_SIZE = join_buffer_size_val |
  JOIN_BUFFER_SPACE_LIMIT = join_buffer_space_val |
  JOIN_CACHE_LEVEL = join_cache_level_val |
  OPTIMIZER_EXTRA_PRUNING_DEPTH = extra_pruning_val /* compatibility 10.10.1 */ |
  OPTIMIZER_MAX_SEL_ARG_WEIGHT = max_sel_weight_val /* compatibility 10.5.9 */ |
  OPTIMIZER_PRUNE_LEVEL = prune_level_val |
  OPTIMIZER_SEARCH_DEPTH = search_depth_val |
  OPTIMIZER_SELECTIVITY_SAMPLING_LIMIT = selectivity_sampling_val |
  OPTIMIZER_SWITCH = optimizer_switch_val |
  OPTIMIZER_USE_CONDITION_SELECTIVITY = { $prng->uint16(1,5) } |
  USE_STAT_TABLES = stat_tables_val
;

# Default 200, as of 11.0
eq_range_dive_val:
  DEFAULT |
  0 |
  { $prng->uint16(1,10) } |
  { $prng->uint16(11,50) } |
  { $prng->uint16(51,100) } |
  { $prng->uint16(101,200) } |
  { $prng->uint16(201,1000) } |
  4294967295 ;

# Default 100, as of 11.0
expensive_sq_val:
  DEFAULT |
  0 |
  { $prng->uint16(1,10) } |
  { $prng->uint16(11,50) } |
  { $prng->uint16(51,100) } |
  { $prng->uint16(101,200) } |
  { $prng->uint16(201,1000) } |
  18446744073709551615
;

# Default 254, as of 11.0
histogram_size_val:
  DEFAULT |
  0 |
  { $prng->uint16(1,128) } |
  { $prng->uint16(129,255) } |
  255
;

# Default JSON_HB as of 11.0, DOUBLE_PREC_HB before
histogram_type_val:
  DEFAULT |
  SINGLE_PREC_HB |
  DOUBLE_PREC_HB |
  JSON_HB /* compatibility 10.7.1 */
;

# Default 1000 as of 11.0
in_predicate_val:
  DEFAULT |
  0 |
  { $prng->uint16(1,10) } |
  { $prng->uint16(11,100) } |
  { $prng->uint16(101,1000) } |
  4294967295 ;

# Default 262144 as of 11.0
# Too small size disabled due to MDEV-30938 / MDEV-31348 ("Could not create a join buffer")
# Too big size disabled due to MDEV-31935 (cannot allocate)
join_buffer_size_val:
  DEFAULT |
#  128 |
#  18446744073709551615 |
  { $prng->uint16(8192,262144) } |
  { $prng->uint16(262144,1048576) }
;

# Default 2097152 as of 11.0
# Too small size disabled due to MDEV-30938 / MDEV-31348 ("Could not create a join buffer")
# Too big size disabled due to MDEV-31935 (cannot allocate)
join_buffer_space_val:
  DEFAULT |
#  2048 |
#  18446744073709551615 |
  { $prng->uint16(131072,2097152) } |
  { $prng->uint16(131072,8388608) }
;

# Default 2 as of 11.0
join_cache_level_val:
  DEFAULT |
  { $prng->uint16(0,8) };

# Default 8 as of 11.0
extra_pruning_val:
  DEFAULT |
  0 |
  { $prng->uint16(0,8) } |
  { $prng->uint16(9,20) } |
  { $prng->uint16(21,62) } ;

# Default 32000 as of 11.0
max_sel_weight_val:
  DEFAULT |
  0 |
  { $prng->uint16(1,100) } |
  { $prng->uint16(101,3200) } |
  { $prng->uint16(3200,10000) } |
  18446744073709551615 ;

# Default 2 as of 11.0
prune_level_val:
  DEFAULT |
  0 |
  1 |
  2 ;

# Default 62 as of 11.0
search_depth_val:
  DEFAULT |
  0 |
  { $prng->uint16(1,61) } |
  62 ;

# Default 100 as of 11.0
selectivity_sampling_val:
  DEFAULT |
  { $prng->uint16(10,100) } |
  { $prng->uint16(101,1000) } |
  4294967295 ;

# Default as of 11.0:
# index_merge=on,index_merge_union=on,index_merge_sort_union=on,index_merge_intersection=on,index_merge_sort_intersection=off,engine_condition_pushdown=off,index_condition_pushdown=on,derived_merge=on,derived_with_keys=on,firstmatch=on,loosescan=on,materialization=on,in_to_exists=on,semijoin=on,partial_match_rowid_merge=on,partial_match_table_scan=on,subquery_cache=on,mrr=off,mrr_cost_based=off,mrr_sort_keys=off,outer_join_with_cache=on,semijoin_with_cache=on,join_cache_incremental=on,join_cache_hashed=on,join_cache_bka=on,optimize_join_buffer_size=on,table_elimination=on,extended_keys=on,exists_to_in=on,orderby_uses_equalities=on,condition_pushdown_for_derived=on,split_materialized=on,condition_pushdown_for_subquery=on,rowid_filter=on,condition_pushdown_from_having=on,not_null_range_scan=off

optimizer_switch_val:
  DEFAULT |
  'index_merge=on' | 'index_merge=off' |
  'index_merge_union=on' | 'index_merge_union=off' |
  'index_merge_sort_union=on' | 'index_merge_sort_union=off' |
  'index_merge_intersection=on' | 'index_merge_intersection=off' |
  'index_merge_sort_intersection=on' | 'index_merge_sort_intersection=off' |
  'engine_condition_pushdown=on' | 'engine_condition_pushdown=off' |
  'index_condition_pushdown=on' | 'index_condition_pushdown=off' |
  'derived_merge=on' | 'derived_merge=off' |
  'derived_with_keys=on' | 'derived_with_keys=off' |
  'firstmatch=on' | 'firstmatch=off' |
  'loosescan=on' | 'loosescan=off' |
  'materialization=on' | 'materialization=off' |
  'in_to_exists=on' | 'in_to_exists=off' |
  'semijoin=on' | 'semijoin=off' |
  'partial_match_rowid_merge=on' | 'partial_match_rowid_merge=off' |
  'partial_match_table_scan=on' | 'partial_match_table_scan=off' |
  'subquery_cache=on' | 'subquery_cache=off' |
  'mrr=on' | 'mrr=off' |
  'mrr_cost_based=on' | 'mrr_cost_based=off' |
  'mrr_sort_keys=on' | 'mrr_sort_keys=off' |
  'outer_join_with_cache=on' | 'outer_join_with_cache=off' |
  'semijoin_with_cache=on' | 'semijoin_with_cache=off' |
  'join_cache_incremental=on' | 'join_cache_incremental=off' |
  'join_cache_hashed=on' | 'join_cache_hashed=off' |
  'join_cache_bka=on' | 'join_cache_bka=off' |
  'optimize_join_buffer_size=on' | 'optimize_join_buffer_size=off' |
  'table_elimination=on' | 'table_elimination=off' |
  'extended_keys=on' | 'extended_keys=off' |
  'exists_to_in=on' | 'exists_to_in=off' |
  'orderby_uses_equalities=on' | 'orderby_uses_equalities=off' |
  'condition_pushdown_for_derived=on' | 'condition_pushdown_for_derived=off' |
  'split_materialized=on' | 'split_materialized=off' |
  'condition_pushdown_for_subquery=on' | 'condition_pushdown_for_subquery=off' |
  'rowid_filter=on' | 'rowid_filter=off' |
  'condition_pushdown_from_having=on' | 'condition_pushdown_from_having=off' |
  'not_null_range_scan=on' | 'not_null_range_scan=off'
;

# Default PREFERABLY_FOR_QUERIES as of 11.0
stat_tables_val:
  NEVER |
  COMPLEMENTARY |
  PREFERABLY |
  COMPLEMENTARY_FOR_QUERIES |
  PREFERABLY_FOR_QUERIES ;
