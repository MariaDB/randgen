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

query:
    ==FACTOR:0.01== SELECT CONCAT("SET NAMES '",IFNULL(CHARACTER_SET_NAME,'utf8mb4'),"' COLLATE '",{ $coll= "'".$prng->arrayElement($executors->[0]->metaCollations())."'" },"'") INTO @setnames FROM INFORMATION_SCHEMA.COLLATIONS WHERE COLLATION_NAME = { $coll }
    ; EXECUTE IMMEDIATE @setnames |
    collation_strings collation_comparison ;

collation_comparison:
    SELECT STRCMP({ $w1 }, { $w2 }) |
    SELECT { $w1 } < { $w2 } |
    SELECT { $w1 } > { $w2 } |
    SELECT { $w1 } = { $w2 } |
    SELECT CONCAT({ $w1 },collation_zero_or_empty) >= CONCAT({ $w2 },collation_zero_or_empty) |
    collation_select_union |
    ==FACTOR:0.1== { _set_db('user') } CREATE OR REPLACE VIEW { 'v_'.abs($$) } AS collation_select_union ; SELECT * FROM { 'v_'.abs($$) }
;

collation_zero_or_empty:
    '' | '\0' ;

collation_strings:
 { $w1= $prng->word(); $w2= $prng->word(); '' } |
 { $w1= $prng->word(); $w2= $w1; '' } |
 { $w1= $prng->string($prng->uint16(1,64)); $w2= $w1; '' } |
 /* { $w= $prng->word() } */ { $w=~ s/^'(.*)'$/$1/; $w1= "'".substr($w,$prng->uint16(0,length($w)),$prng->uint16(1,length($w)))."'"; $w2= "'".substr($w,$prng->uint16(0,length($w)),$prng->uint16(1,length($w)))."'"; '' } |
 /* { $w= $prng->word() } */ { $w=~ s/^'(.*)'$/$1/; $w1= "'".substr($w,$prng->uint16(0,length($w)),$prng->uint16(1,length($w)))."\0'"; $w2= "'".substr($w,$prng->uint16(0,length($w)),$prng->uint16(1,length($w)))."\0'"; '' } |
 { $w1= $prng->word(); $w2= substr($w1,0,length($w1)-1).substr($w1,1,length($w1)-1); '' } |
 { $w2= $prng->word(); $w1= substr($w2,0,length($w2)-1).substr($w2,1,length($w2)-1); '' }
;

collation_select_union:
    SELECT { $w1 } AS a UNION SELECT { $w2 } AS a UNION SELECT { $w1 } AS a ORDER BY a __desc(50) /* OUTCOME_ORDERED_MATCH */
;
