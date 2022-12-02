# Copyright (c) 2010, 2012, Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2022, MariaDB
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

########################################################################

query_init:
  { %handlers= (); '' } { _set_db('user') }
     handler_open_close ;; handler_open_close
  ;; handler_open_close ;; handler_open_close
  ;; handler_open_close ;; handler_open_close
;

query:
  { _set_db('user') } handler ;

set_db:
  ==FACTOR:50== { _set_db('user') } |
                { _set_db('mysql') } ;

handler:
  handler_sequence | handler_random ;

handler_random:
  handler_open_close |
  alias handler_read ;

handler_sequence:
  handler_open_close ;; alias handler_read_list ;

handler_read_list:
  handler_read ;; handler_read |
  handler_read ;; handler_read_list ;

handler_open_close:
  { $alias= 'alias'.$prng->uint16(1,10); if ($handlers{$alias}) { delete $handlers{$alias}; "HANDLER $alias CLOSE ;;" } else { '' } } HANDLER _table OPEN AS { $handlers{$alias}= [$last_database,$last_table]; $alias } ;

alias:
  { if (scalar(keys %handlers)) { $alias=$prng->arrayElement([ sort keys %handlers ]); ($last_database,$last_table)= @{$handlers{$alias}}; "USE $handlers{$alias}->[0] /* EXECUTOR_FLAG_SKIP_STATS */ ;;" } else { $alias= 'aliasX'; '' } } ;

handler_read:
  HANDLER { $alias } READ index_name comp_op ( value ) where limit |
  HANDLER { $alias } READ index_name index_op where limit |
  HANDLER { $alias } READ first_next where limit |
  HANDLER { $alias } READ index_name index_op WHERE _field comp_op value ;

comp_op:
  = | <= | >= | < | > ;

index_op:
  FIRST | NEXT | PREV | LAST ;

index_name:
  `PRIMARY` | _field_key ;

first_next:
  FIRST | NEXT ;

value:
  _digit | _tinyint_unsigned | _varchar(1) ;

limit:
  | | | | | LIMIT _digit ;

where:
  | WHERE _field comp_op value ;

