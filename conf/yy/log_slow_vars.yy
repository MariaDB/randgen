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

########################################################################
# MDEV-7567 rename slow queries variables (10.11.1)
#
# But we also use legacy names to make the grammar partially applicable
# to earlier versions
########################################################################

query:
  SET slow_global_or_not slow_var_min_examined = slow_var_min_examined_val |
  SET slow_var_min_examined_var = slow_var_min_examined_val |
  SET slow_global_or_not slow_var_log          = slow_var_log_val          |
  SET slow_var_log_var          = slow_var_log_val          |
  SET slow_global_or_not slow_var_log_file     = slow_var_log_file_val     |
  SET slow_var_log_file_var     = slow_var_log_file_val     |
  SET slow_global_or_not slow_var_time         = slow_var_time_val         |
  SET slow_var_time_var         = slow_var_time_val         |
  SET slow_global_or_not slow_var_always_time = slow_var_time_val /* compatibility 11.6 */ |
  SET slow_var_always_time_var = slow_var_time_val /* compatibility 11.6 */
;

slow_global_or_not:
    | GLOBAL | SESSION | LOCAL ;

slow_var_min_examined:
  slow_var_min_examined_new /* compatibility 10.11.1 */ |
  slow_var_min_examined_legacy ;

slow_var_min_examined_new:
  log_slow_min_examined_row_limit | LOG_SLOW_MIN_EXAMINED_ROW_LIMIT ;

slow_var_min_examined_legacy:
  min_examined_row_limit | MIN_EXAMINED_ROW_LIMIT ;

slow_var_min_examined_var:
  slow_var_min_examined_var_new /* compatibility 10.11.1 */ |
  slow_var_min_examined_var_legacy ;

slow_var_min_examined_var_new:
  @@log_slow_min_examined_row_limit |
  @@global.log_slow_min_examined_row_limit |
  @@session.log_slow_min_examined_row_limit |
  @@local.log_slow_min_examined_row_limit |
  @@LOG_SLOW_MIN_EXAMINED_ROW_LIMIT |
  @@SESSION.LOG_SLOW_MIN_EXAMINED_ROW_LIMIT |
  @@GLOBAL.LOG_SLOW_MIN_EXAMINED_ROW_LIMIT |
  @@LOCAL.LOG_SLOW_MIN_EXAMINED_ROW_LIMIT ;

slow_var_min_examined_var_legacy:
  @@min_examined_row_limit |
  @@global.min_examined_row_limit |
  @@session.min_examined_row_limit |
  @@local.min_examined_row_limit |
  @@MIN_EXAMINED_ROW_LIMIT |
  @@SESSION.MIN_EXAMINED_ROW_LIMIT |
  @@GLOBAL.MIN_EXAMINED_ROW_LIMIT |
  @@LOCAL.MIN_EXAMINED_ROW_LIMIT ;

slow_var_min_examined_val:
    0 | 4294967295 | 1 | _tinyint_unsigned | _smallint_unsigned | -1 | 4294967296 | DEFAULT ;

slow_var_log:
  slow_var_log_new /* compatibility 10.11.1 */ |
  slow_var_log_legacy ;

slow_var_log_new:
  log_slow_query | LOG_SLOW_QUERY ;

slow_var_log_legacy:
  slow_query_log | SLOW_QUERY_LOG ;

slow_var_log_var:
  slow_var_log_var_new /* compatibility 10.11.1 */ |
  slow_var_log_var_legacy ;

slow_var_log_var_new:
  @@log_slow_query |
  @@global.log_slow_query |
  @@session.log_slow_query |
  @@local.log_slow_query |
  @@LOG_SLOW_QUERY |
  @@SESSION.LOG_SLOW_QUERY |
  @@GLOBAL.LOG_SLOW_QUERY |
  @@LOCAL.LOG_SLOW_QUERY ;

slow_var_log_var_legacy:
  @@slow_query_log |
  @@global.slow_query_log |
  @@session.slow_query_log |
  @@local.slow_query_log |
  @@SLOW_QUERY_LOG |
  @@SESSION.SLOW_QUERY_LOG |
  @@GLOBAL.SLOW_QUERY_LOG |
  @@LOCAL.SLOW_QUERY_LOG ;

slow_var_log_val:
  ON | OFF | 1 | 0 | YES | NO | '' | -1 | 'definitely' ;

slow_var_log_file:
  slow_var_log_file_new /* compatibility 10.11.1 */ |
  slow_var_log_file_legacy ;

slow_var_log_file_new:
  log_slow_query_file | LOG_SLOW_QUERY_FILE ;

slow_var_log_file_legacy:
  slow_query_log_file | SLOW_QUERY_LOG_FILE ;

slow_var_log_file_var:
  slow_var_log_file_var_new /* compatibility 10.11.1 */ |
  slow_var_log_file_var_legacy ;

slow_var_log_file_var_new:
  @@global.log_slow_query_file |
  ==FACTOR:0.01== @@log_slow_query_file |
  ==FACTOR:0.01== @@session.log_slow_query_file |
  ==FACTOR:0.01== @@local.log_slow_query_file |
  @@GLOBAL.LOG_SLOW_QUERY_FILE |
  ==FACTOR:0.01== @@LOG_SLOW_QUERY_FILE |
  ==FACTOR:0.01== @@SESSION.LOG_SLOW_QUERY_FILE |
  ==FACTOR:0.01== @@LOCAL.LOG_SLOW_QUERY_FILE ;

slow_var_log_file_var_legacy:
  @@global.slow_query_log_file |
  ==FACTOR:0.01== @@slow_query_log_file |
  ==FACTOR:0.01== @@session.slow_query_log_file |
  ==FACTOR:0.01== @@local.slow_query_log_file |
  @@GLOBAL.SLOW_QUERY_LOG_FILE |
  ==FACTOR:0.01== @@SLOW_QUERY_LOG_FILE |
  ==FACTOR:0.01== @@SESSION.SLOW_QUERY_LOG_FILE |
  ==FACTOR:0.01== @@LOCAL.SLOW_QUERY_LOG_FILE ;

slow_var_log_file_val:
  'slow.log' |
  { "'".$executors->[0]->vardir."/slow.log'" } |
  '' |
  { "'".$executors->[0]->vardir . "/really_long_name_for_slow_log_which_will_never_happen_in_real_life_but_we_still_need_to_try_it_just_to_make_sure_we_dont_look_like_fools_when_some_tester_wants_to_do_it_because_testing_guides_recommend_extreme_values.log'" } |
  { "'".$executors->[0]->vardir."/name with space.log'" } |
  ==FACTOR:0.01== { "'".$executors->[0]->vardir."/non_existing_dir/slow.log'" } |
  DEFAULT
;

slow_var_time:
  slow_var_time_new /* compatibility 10.11.1 */ |
  slow_var_time_legacy ;

slow_var_always_time:
  LOG_SLOW_ALWAYS_QUERY_TIME /* compatibility 11.6 */ |
  slow_var_time_legacy ;

slow_var_time_new:
  log_slow_query_time | LOG_SLOW_QUERY_TIME ;

slow_var_time_legacy:
  long_query_time | LONG_QUERY_TIME ;

slow_var_time_var:
  slow_var_time_var_new /* compatibility 10.11.1 */ |
  slow_var_time_var_legacy ;

slow_var_always_time_var:
  @@log_slow_always_query_time |
  @@global.log_slow_always_query_time |
  @@session.log_slow_always_query_time |
  @@local.log_slow_always_query_time |
  @@LOG_SLOW_ALWAYS_QUERY_TIME |
  @@SESSION.LOG_SLOW_ALWAYS_QUERY_TIME |
  @@GLOBAL.LOG_SLOW_ALWAYS_QUERY_TIME |
  @@LOCAL.LOG_SLOW_ALWAYS_QUERY_TIME ;

slow_var_time_var_new:
  @@log_slow_query_time |
  @@global.log_slow_query_time |
  @@session.log_slow_query_time |
  @@local.log_slow_query_time |
  @@LOG_SLOW_QUERY_TIME |
  @@SESSION.LOG_SLOW_QUERY_TIME |
  @@GLOBAL.LOG_SLOW_QUERY_TIME |
  @@LOCAL.LOG_SLOW_QUERY_TIME ;

slow_var_time_var_legacy:
  @@long_query_time |
  @@global.long_query_time |
  @@session.long_query_time |
  @@local.long_query_time |
  @@LONG_QUERY_TIME |
  @@SESSION.LONG_QUERY_TIME |
  @@GLOBAL.LONG_QUERY_TIME |
  @@LOCAL.LONG_QUERY_TIME ;

slow_var_time_val:
    0 | 31536000 | 0.1 | _tinyint_unsigned | _smallint_unsigned | _float | -1 | 31536001 | DEFAULT ;
