#  Copyright (c) 2020, MariaDB
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
# 
# This grammar is meant to be a temporary (but possibly long-term)
# solution until we have a complete working grammar for parser testing
#
# Until then, this grammar will mainly cover changes happened in parser
# during recent development, unless they are already covered by
# functionality-specific grammars
#
# Changes:
# 
# 10.5.3: MDEV-16978 (WITHOUT OVERLAPS)
#         Some logic added/modified in CREATE UNIQUE and other places
#
########################################################################

query_add:
    ==FACTOR:0.005== parser_changes_query
;

parser_changes_query:
    parser_changes_create_index
  | parser_changes_functions
;

parser_changes_create_index:
    CREATE OR REPLACE UNIQUE INDEX _letter ON `` (x) /* EXECUTOR_FLAG_SILENT */
  | CREATE OR REPLACE UNIQUE INDEX IF NOT EXISTS _letter ON _table (_field) /* EXECUTOR_FLAG_SILENT */
;

parser_changes_functions:
    # OVERLAPS is also a GIS function
      SELECT OVERLAPS(NULL,NULL) FROM DUAL
    | SELECT OVERLAPS() /* EXECUTOR_FLAG_SILENT */ 
    | SELECT * FROM (SELECT OVERLAPS(NULL,NULL)) sq
    | SELECT * FROM _table WHERE OVERLAPS(NULL,NULL) IS NOT NULL
;

parser_changes_overlaps:
 # TODO: Disabled due to MDEV-22546, replaced with two variants below
 #  | CREATE OR REPLACE TABLE overlaps (overlaps INT, KEY overlaps(overlaps), CONSTRAINT overlaps CHECK(overlaps>0)); SELECT overlaps FROM overlaps WHERE overlaps = overlaps GROUP BY overlaps HAVING overlaps > 0 ORDER BY overlaps limit 1; WITH overlaps AS (SELECT overlaps FROM overlaps) SELECT * FROM overlaps
 # Workaround for MDEV-22546
    | CREATE OR REPLACE TABLE overlaps (overlaps INT, KEY overlaps(overlaps), CONSTRAINT overlaps CHECK(overlaps>0)); SELECT overlaps FROM overlaps WHERE overlaps = overlaps GROUP BY overlaps HAVING overlaps > 0 ORDER BY overlaps limit 1; WITH cte_overlaps AS (SELECT overlaps FROM overlaps) SELECT * FROM cte_overlaps
    | CREATE OR REPLACE TABLE overlaps_t (overlaps INT, KEY overlaps(overlaps), CONSTRAINT overlaps CHECK(overlaps>0)); SELECT overlaps FROM overlaps_t WHERE overlaps = overlaps GROUP BY overlaps HAVING overlaps > 0 ORDER BY overlaps limit 1; WITH overlaps AS (SELECT overlaps FROM overlaps_t) SELECT * FROM overlaps
 # End of workaround for MDEV-22546
    | CREATE OR REPLACE TABLE overlaps (pk INT, overlaps DATE, e DATE, PERIOD FOR p(overlaps,e), PRIMARY KEY(pk, p WITHOUT overlaps))
    | CREATE OR REPLACE TABLE overlaps (overlaps INT, s DATE, e DATE, PERIOD FOR p(s,e), PRIMARY KEY (overlaps, p WITHOUT overlaps))
    | CREATE OR REPLACE TABLE overlaps (a INT, s DATE, e DATE, PERIOD FOR overlaps(s,e), PRIMARY KEY (a, overlaps WITHOUT overlaps))
;

