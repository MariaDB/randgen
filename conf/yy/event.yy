# Copyright (C) 2020,2022 MariaDB Corporation.
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

query_init:
  { $ev = 0; '' } SET GLOBAL event_scheduler = ON
;

query:
  { _set_db('NON-SYSTEM') } event_query ;

event_query:
    ==FACTOR:4==   event_create
  |                DROP EVENT IF EXISTS existing_event_name
  | ==FACTOR:8==   event_alter
  | ==FACTOR:0.2== SHOW EVENTS
  | ==FACTOR:0.1== SELECT * FROM INFORMATION_SCHEMA.EVENTS
;

existing_event_name:
    { 'ev_'.abs($$).'_'.$prng->int(1,$ev) } ;

event_name:
  ==FACTOR:10== event_name_new |
  existing_event_name
;

event_name_new:
  { 'ev_'.abs($$).'_'.(++$ev) } ;

event_create:
  CREATE __or_replace(95) event_definer_optional EVENT event_name ON SCHEDULE event_schedule event_optional_attributes DO event_body |
  CREATE event_definer_optional EVENT __if_not_exists(95) event_name ON SCHEDULE event_schedule event_optional_attributes DO event_body
;

event_alter:
  { $event_action_count=0; '' } ALTER event_definer_optional EVENT existing_event_name event_alter_actions ;

event_definer_optional:
    ==FACTOR:5==
  | ==FACTOR:1== DEFINER=root@localhost
  | ==FACTOR:0.1== DEFINER=rqg@localhost
  | ==FACTOR:0.01== DEFINER=_letter@localhost
;

event_alter_actions:
    event_schedule_optional
    event_rename_optional
    event_optional_attributes
    event_body_optional
;

event_optional_attributes:
    event_enable_disable_optional
    event_comment_optional
    event_alter_filler
;

event_schedule_optional:
  | { $event_action_count++; '' } ON SCHEDULE event_schedule ;

event_on_completion_optional:
  | { $event_action_count++; '' } ON COMPLETION __not(30) PRESERVE ;

event_rename_optional:
  | { $event_action_count++; '' } RENAME TO event_name ;

event_enable_disable_optional:
  | { $event_action_count++; '' } event_enable_disable ;

event_comment_optional:
  | { $event_action_count++; '' } COMMENT _english ;

event_body_optional:
  | { $event_action_count++; '' } DO event_body ;

# ALTER list cannot be empty, so if all attributes opted out, we'll add a comment
event_alter_filler:
  { $event_action_count ? '' : "COMMENT 'filler'" } ;

event_enable_disable:
    ENABLE | DISABLE | DISABLE ON SLAVE ;

event_schedule:
    AT event_execution_time event_optional_interval_plus
  | EVERY event_interval event_optional_starts event_optional_ends
;

event_execution_time:
    # Almost always in the future
    ==FACTOR:499== { $ts= $prng->int(time(),2147483647); $prng->datetime($ts) }
  |                { $ts= $prng->int(0,2147483647); $prng->datetime($ts) }
;

event_optional_starts:
  | | | | | | | | | { $ts= $prng->int(0,2147483647); $start= $prng->datetime($ts); "STARTS $start" } event_optional_interval_plus ;

event_optional_ends:
  | | | | | | | | | { $end= $prng->datetime($prng->int($ts,2147483647)); "ENDS $end" } event_optional_interval_plus ;

event_optional_interval_plus:
  | | | | | | | | | + INTERVAL event_interval ;

event_interval:
    _tinyint_unsigned event_inteval_unit ;

event_inteval_unit:
    YEAR | QUARTER | MONTH | DAY | HOUR | MINUTE | WEEK |
    SECOND | YEAR_MONTH | DAY_HOUR | DAY_MINUTE | DAY_SECOND |
    HOUR_MINUTE | HOUR_SECOND | MINUTE_SECOND ;

event_body:
    ==FACTOR:4== event_body_element
  |              event_body_element ; event_body
;

event_body_element:
    ==FACTOR:3== UPDATE _table SET _field = NULL ORDER BY _field LIMIT 1
  | ALTER TABLE _table
  | ANALYZE TABLE _table
;
