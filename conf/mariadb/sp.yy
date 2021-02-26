#  Copyright (c) 2021, MariaDB Corporation Ab
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

##################
# It cannot be meaningfully used as a standalone grammar,
# because it lacks actual queries which can be put inside the procedure;
# it requires other grammars with query clauses


# Change max number of procedures here if needed
query_init_add:
  CREATE PROCEDURE IF NOT EXISTS { $maxspnum= 9; 'sp'.($spnum= 0) } () BEGIN END ;

query_add:
  ==FACTOR:0.1== sp_create_and_or_execute ;

sp_create_and_or_execute:
    sp_drop ; sp_recreate
  | ==FACTOR:4== sp_create
  | ==FACTOR:8== sp_call
;

sp_drop:
  DROP PROCEDURE _basics_if_exists_80pct sp_existing_name ;

sp_recreate:
  CREATE PROCEDURE { $last_sp } () sp_body ;

sp_create:
  CREATE _basics_or_replace_80pct PROCEDURE sp_new_or_existing_name () sp_body ;

sp_call:
  CALL sp_existing_name ;

sp_new_or_existing_name:
  { $spnum < $maxspnum ? 'sp'.(++$spnum) : 'sp'.$prng->int(0,$spnum) };

sp_existing_name:
  { $last_sp= 'sp'.$prng->int(0,$spnum) } ;

sp_body:
  ==FACTOR:3== query |
  BEGIN sp_contents ; END
;

sp_contents:
  ==FACTOR:3== query
  | query ; sp_contents
;
