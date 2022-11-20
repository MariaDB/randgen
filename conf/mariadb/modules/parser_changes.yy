#  Copyright (c) 2020, 2022 MariaDB
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
# 10.8.0 MDEV-13756 (DESC INDEXES)
#         The syntax was already allowed, but some logic added for
#         not ignoring it
#
########################################################################

query:
    ==FACTOR:0.005== parser_changes_query
;

parser_changes_query:
    ==FACTOR:0.01== parser_changes_create_index_invalid
  | parser_changes_functions
  | parser_changes_desc_keys
;

parser_changes_create_index_invalid:
    # Syntax error
    CREATE OR REPLACE UNIQUE INDEX _letter ON `` (x) /* EXECUTOR_FLAG_SILENT */
    # Semantic error (incorrect usage)
  | CREATE OR REPLACE UNIQUE INDEX IF NOT EXISTS _letter ON _basetable (_field) /* EXECUTOR_FLAG_SILENT */
;

parser_changes_desc_keys:
  | CREATE OR REPLACE __unique(5) INDEX { $my_index = 'prsind'.$prng->uint16(1,100) } ON _basetable (_field __asc_x_desc(50,50)) ;; DROP INDEX IF EXISTS { $my_index } ON { $last_table }
  | CREATE OR REPLACE TABLE parser_changes_table (pk INT, a INT, b CHAR(16), PRIMARY KEY(pk __asc_x_desc(50,50), a __asc_x_desc(50,50)), KEY(a __asc_x_desc(50,50)), UNIQUE(b(8) __asc_x_desc(50,50)))
  | ALTER TABLE IF EXISTS parser_changes_table DROP PRIMARY KEY ;; ALTER TABLE IF EXISTS parser_changes_table ADD PRIMARY KEY (pk __asc_x_desc(50,50)), ADD KEY(b __asc_x_desc(50,50))
;

parser_changes_functions:
    # OVERLAPS is also a GIS function
      SELECT OVERLAPS(NULL,NULL) FROM DUAL
      # Semantic error: Wrong parameter count
    | ==FACTOR:0.01== SELECT OVERLAPS() /* EXECUTOR_FLAG_SILENT */
    | SELECT * FROM (SELECT OVERLAPS(NULL,NULL)) sq
    | SELECT * FROM _table WHERE OVERLAPS(NULL,NULL) IS NOT NULL
;

parser_changes_overlaps:
 # TODO: Disabled due to MDEV-22546, replaced with two variants below
 #  | CREATE OR REPLACE TABLE overlaps (overlaps INT, KEY overlaps(overlaps), CONSTRAINT overlaps CHECK(overlaps>0)); SELECT overlaps FROM overlaps WHERE overlaps = overlaps GROUP BY overlaps HAVING overlaps > 0 ORDER BY overlaps limit 1 ;; WITH overlaps AS (SELECT overlaps FROM overlaps) SELECT * FROM overlaps
 # Workaround for MDEV-22546
    | CREATE OR REPLACE TABLE overlaps (overlaps INT, KEY overlaps(overlaps), CONSTRAINT overlaps CHECK(overlaps>0)); SELECT overlaps FROM overlaps WHERE overlaps = overlaps GROUP BY overlaps HAVING overlaps > 0 ORDER BY overlaps limit 1 ;; WITH cte_overlaps AS (SELECT overlaps FROM overlaps) SELECT * FROM cte_overlaps
    | CREATE OR REPLACE TABLE overlaps_t (overlaps INT, KEY overlaps(overlaps), CONSTRAINT overlaps CHECK(overlaps>0)); SELECT overlaps FROM overlaps_t WHERE overlaps = overlaps GROUP BY overlaps HAVING overlaps > 0 ORDER BY overlaps limit 1 ;; WITH overlaps AS (SELECT overlaps FROM overlaps_t) SELECT * FROM overlaps
 # End of workaround for MDEV-22546
    | CREATE OR REPLACE TABLE overlaps (pk INT, overlaps DATE, e DATE, PERIOD FOR p(overlaps,e), PRIMARY KEY(pk, p WITHOUT overlaps))
    | CREATE OR REPLACE TABLE overlaps (overlaps INT, s DATE, e DATE, PERIOD FOR p(s,e), PRIMARY KEY (overlaps, p WITHOUT overlaps))
    | CREATE OR REPLACE TABLE overlaps (a INT, s DATE, e DATE, PERIOD FOR overlaps(s,e), PRIMARY KEY (a, overlaps WITHOUT overlaps))
;

