#  Copyright (c) 2022, MariaDB Corporation
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

#
# MDEV-7567 rename slow queries variables
#

query_add:
    SET slow_global_or_not slow_var_min_examined = slow_var_min_examined_val |
    SET slow_var_min_examined_var = slow_var_min_examined_val |
    SET slow_global_or_not slow_var_log          = slow_var_log_val          |
    SET slow_var_log_var          = slow_var_log_val          |
    SET slow_global_or_not slow_var_log_file     = slow_var_log_file_val     |
    SET slow_var_log_file_var     = slow_var_log_file_val     |
    SET slow_global_or_not slow_var_time         = slow_var_time_val         |
    SET slow_var_time_var         = slow_var_time_val         ;

slow_global_or_not:
    | GLOBAL | SESSION | LOCAL ;

slow_var_min_examined:
    log_slow_min_examined_row_limit | min_examined_row_limit | LOG_SLOW_MIN_EXAMINED_ROW_LIMIT ;

slow_var_min_examined_var:
  @@log_slow_min_examined_row_limit |
  @@global.log_slow_min_examined_row_limit |
  @@session.log_slow_min_examined_row_limit |
  @@local.log_slow_min_examined_row_limit |
  @@LOG_SLOW_MIN_EXAMINED_ROW_LIMIT |
  @@SESSION.LOG_SLOW_MIN_EXAMINED_ROW_LIMIT |
  @@GLOBAL.LOG_SLOW_MIN_EXAMINED_ROW_LIMIT |
  @@LOCAL.LOG_SLOW_MIN_EXAMINED_ROW_LIMIT ;

slow_var_min_examined_val:
    0 | 4294967295 | 1 | _tinyint_unsigned | _smallint_unsigned | -1 | 4294967296 | DEFAULT ;

slow_var_log:
  log_slow_query | slow_query_log | LOG_SLOW_QUERY ;

slow_var_log_var:
  @@log_slow_query |
  @@global.log_slow_query |
  @@session.log_slow_query |
  @@local.log_slow_query |
  @@LOG_SLOW_QUERY |
  @@SESSION.LOG_SLOW_QUERY |
  @@GLOBAL.LOG_SLOW_QUERY |
  @@LOCAL.LOG_SLOW_QUERY ;

slow_var_log_val:
  ON | OFF | 1 | 0 | YES | NO | '' | -1 | 'definitely' ;

slow_var_log_file:
  log_slow_query_file | slow_query_log_file | LOG_SLOW_QUERY_FILE ;

slow_var_log_file_var:
  @@log_slow_query_file |
  @@global.log_slow_query_file |
  @@session.log_slow_query_file |
  @@local.log_slow_query_file |
  @@LOG_SLOW_QUERY_FILE |
  @@SESSION.LOG_SLOW_QUERY_FILE |
  @@GLOBAL.LOG_SLOW_QUERY_FILE |
  @@LOCAL.LOG_SLOW_QUERY_FILE ;

slow_var_log_file_val:
    'slow.log' | '/data/tmp/slow.log' | '' | '/data/tmp/really_long_name_for_slow_log_which_will_never_happen_in_real_life_but_we_still_need_to_try_it_just_to_make_sure_we_dont_look_like_fools_when_some_tester_wants_to_do_it_because_testing_guides_recommend_extreme_values.log' | '/data/tmp/name with space.log' | '/data/tmp/prohibited/slow.log' | DEFAULT ;

slow_var_time:
  log_slow_query_time | long_query_time | LOG_SLOW_QUERY_TIME ;

slow_var_time_var:
  @@log_slow_query_time |
  @@global.log_slow_query_time |
  @@session.log_slow_query_time |
  @@local.log_slow_query_time |
  @@LOG_SLOW_QUERY_TIME |
  @@SESSION.LOG_SLOW_QUERY_TIME |
  @@GLOBAL.LOG_SLOW_QUERY_TIME |
  @@LOCAL.LOG_SLOW_QUERY_TIME ;

slow_var_time_val:
    0 | 31536000 | 0.1 | _tinyint_unsigned | _smallint_unsigned | _float | -1 | 31536001 | DEFAULT ;
