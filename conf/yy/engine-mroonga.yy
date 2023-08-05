# Copyright (c) 2023, MariaDB
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
# This grammar assumes that Mroonga engine is installed
########################################################################

query_init:
     CREATE DATABASE IF NOT EXISTS mroonga_db
  ;; SET ROLE admin
  ;; EXECUTE IMMEDIATE CONCAT('GRANT ALL ON mroonga_db.* TO ',CURRENT_USER,' WITH GRANT OPTION')
  ;; FLUSH PRIVILEGES
  ;; SET ROLE NONE
  ;; { _set_db('mroonga_db') } create_like
  ;; create_one_field
;

query:
  create |
  ==FACTOR:3== insert |
  ==FACTOR:5== update |
  delete |
  ==FACTOR:10== select |
  alter |
;

create:
  create_like | create_one_field ;

create_like:
  { $mroonga_table= 'mroonga_db.t_mroonga_'.abs($$) ; _set_db('NON-SYSTEM') } CREATE OR REPLACE __temporary(20) TABLE { $mroonga_table } ENGINE=Mroonga AS SELECT * FROM _table ;; ALTER __ignore(5) TABLE { 'mroonga_db.t_mroonga_'.abs($$) } ADD IF NOT EXISTS mtext TEXT, ADD FULLTEXT(mtext) ;

create_one_field:
  { $mroonga_table= 'mroonga_db.t_mroonga_one_field_'.abs($$) ; _set_db('NON-SYSTEM') } CREATE OR REPLACE __temporary(20) TABLE { $mroonga_table } (mtext TEXT, FULLTEXT(mtext)) ENGINE=Mroonga ;; insert100 ;

insert100:
  insert10 ;; insert10 ;; insert10 ;; insert10 ;; insert10 ;; insert10 ;; insert10 ;; insert10 ;; insert10 ;; insert10 ;

insert10:
  insert1 ;; insert1 ;; insert1 ;; insert1 ;; insert1 ;; insert1 ;; insert1 ;; insert1 ;; insert1 ;; insert1 ;

insert1:
  INSERT INTO { $mroonga_table } (mtext) VALUES (_text) ;

insert:
  {  _set_db('mroonga_db') } INSERT INTO _table (mtext) VALUES (_text) ;

delete:
  {  _set_db('mroonga_db') } DELETE FROM _table ORDER BY mtext LIMIT _digit;

update:
  {  _set_db('mroonga_db') } UPDATE _table SET mtext = _text ORDER BY mtext LIMIT _digit;

select:
  {  _set_db('mroonga_db') } SELECT *, MATCH(mtext) AGAINST(_english[invariant]) AS score FROM _table WHERE MATCH(mtext) AGAINST(_english[invariant]) ORDER BY score __asc_x_desc;

alter:
  { _set_db('mroonga_db') } ALTER TABLE _table COMMENT mroonga_tokenizer optional_algorithm optional_lock |
  { _set_db('mroonga_db') } ALTER TABLE _table ENGINE=Mroonga optional_algorithm optional_lock ;

optional_algorithm:
  ==FACTOR:5== |
  ==FACTOR:3== , ALGORITHM=COPY |
               , ALGORITHM=NOCOPY |
               , ALGORITHM=INPLACE |
               , ALGORITHM=INSTANT
;

optional_lock:
  ==FACTOR:3== |
  , LOCK=NONE |
  , LOCK=SHARED |
  , LOCK=EXCLUSIVE
;
mroonga_tokenizer:
  'tokenizer "TokenBigram"' |
  'tokenizer "TokenBigramIgnoreBlank"' |
  'tokenizer "TokenBigramIgnoreBlankSplitSymbol"' |
  'tokenizer "TokenBigramIgnoreBlankSplitSymbolAlpha"' |
  'tokenizer "TokenBigramIgnoreBlankSplitSymbolAlphaDigit"' |
  'tokenizer "TokenBigramSplitSymbol"' |
  'tokenizer "TokenBigramSplitSymbolAlpha"' |
  'tokenizer "TokenDelimit"' |
  'tokenizer "TokenDelimitNull"' |
  'tokenizer "TokenMecab"' |
  'tokenizer "TokenTrigram"' |
  'tokenizer "TokenUnigram"'
;  
