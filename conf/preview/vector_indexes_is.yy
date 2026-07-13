# Copyright (c) 2026, MariaDB
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA */

##############################################################################
# MDEV-34805 - INFORMATION_SCHEMA.VECTOR_INDEXES
#
# A redefine to be layered on top of conf/yy/vector.yy, e.g.
#   --grammar=conf/yy/vector.yy --redefine=conf/yy/vector_indexes_is.yy
#
# Goal: hammer I_S.VECTOR_INDEXES concurrently with vector DML/search so that
# the ctx acquire/release (refcount), cache_lock/commit_lock, and the
# OPTIMIZE_I_S_TABLE open-avoidance path are exercised under contention.
# Also applies cache-size pressure to provoke eviction / CACHE_OVERFLOWS.
##############################################################################

#features vector keys, vector columns, vector indexes IS

query:
  ==FACTOR:15== { _set_db('NON-SYSTEM') } vi_is_query |
  ==FACTOR:2==  { _set_db('NON-SYSTEM') } vi_cache_pressure
;

# --- I_S.VECTOR_INDEXES readers -------------------------------------------
# Mix of "definition-only" projections (schema/name/index_name -> should NOT
# open the storage engine handler thanks to OPTIMIZE_I_S_TABLE) and
# "full-open" projections (OPEN_FULL_TABLE columns -> force a real open).

vi_is_query:
  ==FACTOR:5==  vi_defn_only |
  ==FACTOR:5==  vi_full_open |
                vi_aggregate |
                vi_join
;

vi_defn_only:
  SELECT TABLE_SCHEMA, TABLE_NAME, INDEX_NAME, VECTOR_DIMENSIONS
    FROM INFORMATION_SCHEMA.VECTOR_INDEXES vi_where_clause |
  SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.VECTOR_INDEXES vi_where_clause
;

vi_full_open:
  SELECT TABLE_NAME, INDEX_SIZE, TOTAL_NODES, CACHED_NODES, DELETED_ROWS,
         SUBDIST_ENABLED, MEMORY_SIZE, CACHE_OVERFLOWS
    FROM INFORMATION_SCHEMA.VECTOR_INDEXES vi_where_clause |
  SELECT *
    FROM INFORMATION_SCHEMA.VECTOR_INDEXES vi_where_clause
;

vi_aggregate:
  SELECT SUBDIST_ENABLED, COUNT(*), SUM(TOTAL_NODES), MAX(CACHED_NODES),
         SUM(CACHE_OVERFLOWS)
    FROM INFORMATION_SCHEMA.VECTOR_INDEXES
   WHERE TABLE_SCHEMA = 'vector_db'
   GROUP BY SUBDIST_ENABLED
;

# Join against the base metadata to catch inconsistencies / open-order issues.
vi_join:
  SELECT vi.TABLE_NAME, vi.INDEX_NAME, vi.TOTAL_NODES, t.TABLE_ROWS
    FROM INFORMATION_SCHEMA.VECTOR_INDEXES vi
    JOIN INFORMATION_SCHEMA.TABLES t
      ON t.TABLE_SCHEMA = vi.TABLE_SCHEMA AND t.TABLE_NAME = vi.TABLE_NAME
   WHERE vi.TABLE_SCHEMA = 'vector_db'
;

vi_where_clause:
  ==FACTOR:10== WHERE TABLE_SCHEMA = 'vector_db' |
                WHERE TABLE_SCHEMA = 'vector_db' AND TABLE_NAME = _basetable |
                WHERE TABLE_NAME = _basetable |
                /* no where - full scan across all schemas */
;

# --- cache pressure --------------------------------------------------------
# Small cache sizes push root_size past mhnsw_max_cache_size in release(),
# incrementing CACHE_OVERFLOWS and forcing cache resets while other threads
# read the stats. DEFAULT/large sizes restore normal behaviour.

vi_cache_pressure:
  SET GLOBAL mhnsw_max_cache_size = vi_cache_size ;

vi_cache_size:
  ==FACTOR:5==  1024*1024 |
  ==FACTOR:5==  256*1024 |
                16*1048576 |
                1024*1048576 |
                DEFAULT
;
