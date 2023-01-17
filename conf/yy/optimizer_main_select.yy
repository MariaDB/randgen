# Copyright (c) 2022, MariaDB
# Use is subject to license terms.
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

thread1_init:
  CREATE DATABASE IF NOT EXISTS main_select_db ;; SET ROLE admin ;; { _set_db('main_select_db') } 
  ;; CREATE TABLE t1_MyISAM (
       Period SMALLINT(4) UNSIGNED ZEROFILL DEFAULT '0000' NOT NULL,
       Varor_period SMALLINT(4) UNSIGNED DEFAULT '0' NOT NULL
     )
  ;; INSERT INTO t1_MyISAM VALUES ({$prng->uint16(1,9999)},{$prng->uint16(1,9999)})
  ;; CREATE TABLE t2_MyISAM (
      auto int not null auto_increment,
      fld1 int(6) unsigned zerofill DEFAULT '000000' NOT NULL,
      companynr tinyint(2) unsigned zerofill DEFAULT '00' NOT NULL,
      fld3 char(30) DEFAULT '' NOT NULL,
      fld4 char(35) DEFAULT '' NOT NULL,
      fld5 char(35) DEFAULT '' NOT NULL,
      fld6 char(4) DEFAULT '' NOT NULL,
      UNIQUE fld1 (fld1),
      KEY fld3 (fld3),
      PRIMARY KEY (auto)
    )
  ;; START TRANSACTION ;; t2_insert_1200 ;; COMMIT
  ;; create table t3_MyISAM (
       period    int not null,
       name      char(32) not null,
       companynr int not null,
       price     double(11,0),
       price2     double(11,0),
       key (period),
       key (name)
      )
  ;; INSERT INTO t3_MyISAM (period,name,companynr,price,price2) VALUES (_smallint_unsigned,my_word,_tinyint_unsigned,_mediumint_unsigned,_mediumint_unsigned)
  ;; INSERT INTO t3_MyISAM (period,name,companynr,price,price2) VALUES (_smallint_unsigned,my_word,_tinyint_unsigned,_mediumint_unsigned,_mediumint_unsigned)
  ;; INSERT INTO t3_MyISAM (period,name,companynr,price,price2) VALUES (_smallint_unsigned,my_word,_tinyint_unsigned,_mediumint_unsigned,_mediumint_unsigned)
  ;; INSERT INTO t3_MyISAM (period,name,companynr,price,price2) VALUES (_smallint_unsigned,my_word,_tinyint_unsigned,_mediumint_unsigned,_mediumint_unsigned)
  ;; INSERT INTO t3_MyISAM (period,name,companynr,price,price2) VALUES (_smallint_unsigned,my_word,_tinyint_unsigned,_mediumint_unsigned,_mediumint_unsigned)
  ;; INSERT INTO t3_MyISAM (period,name,companynr,price,price2) VALUES (_smallint_unsigned,my_word,_tinyint_unsigned,_mediumint_unsigned,_mediumint_unsigned)
  ;; INSERT INTO t3_MyISAM (period,name,companynr,price,price2) VALUES (_smallint_unsigned,my_word,_tinyint_unsigned,_mediumint_unsigned,_mediumint_unsigned)
  ;; INSERT INTO t3_MyISAM (period,name,companynr,price,price2) VALUES (_smallint_unsigned,my_word,_tinyint_unsigned,_mediumint_unsigned,_mediumint_unsigned)
  ;; INSERT INTO t3_MyISAM (period,name,companynr,price,price2) VALUES (_smallint_unsigned,my_word,_tinyint_unsigned,_mediumint_unsigned,_mediumint_unsigned)
  ;; INSERT INTO t3_MyISAM (period,name,companynr,price,price2) VALUES (_smallint_unsigned,my_word,_tinyint_unsigned,_mediumint_unsigned,_mediumint_unsigned)
  ;; create temporary table tmp engine = myisam select * from t3_MyISAM
  ;; insert into t3_MyISAM select * from tmp
  ;; insert into tmp select * from t3_MyISAM
  ;; insert into t3_MyISAM select * from tmp
  ;; insert into tmp select * from t3_MyISAM
  ;; insert into t3_MyISAM select * from tmp
  ;; insert into tmp select * from t3_MyISAM
  ;; insert into t3_MyISAM select * from tmp
  ;; insert into tmp select * from t3_MyISAM
  ;; insert into t3_MyISAM select * from tmp
  ;; insert into tmp select * from t3_MyISAM
  ;; insert into t3_MyISAM select * from tmp
  ;; insert into tmp select * from t3_MyISAM
  ;; insert into t3_MyISAM select * from tmp
  ;; insert into tmp select * from t3_MyISAM
  ;; insert into t3_MyISAM select * from tmp
  ;; insert into tmp select * from t3_MyISAM
  ;; insert into t3_MyISAM select * from tmp
  ;; alter table t3_MyISAM add t2nr int not null auto_increment primary key first
  ;; drop table tmp
  ;; create table t4_MyISAM (
      companynr tinyint(2) unsigned zerofill NOT NULL default '00',
      companyname char(30) NOT NULL default '',
      PRIMARY KEY (companynr),
      UNIQUE KEY companyname(companyname)
    ) t4_extra_params COMMENT='companynames'
  ;; INSERT INTO t4_MyISAM (companynr, companyname) VALUES ({$prng->uint16(1,99)},my_word)
  ;; INSERT INTO t4_MyISAM (companynr, companyname) VALUES ({$prng->uint16(1,99)},my_word)
  ;; INSERT INTO t4_MyISAM (companynr, companyname) VALUES ({$prng->uint16(1,99)},my_word)
  ;; INSERT INTO t4_MyISAM (companynr, companyname) VALUES ({$prng->uint16(1,99)},my_word)
  ;; INSERT INTO t4_MyISAM (companynr, companyname) VALUES ({$prng->uint16(1,99)},my_word)
  ;; INSERT INTO t4_MyISAM (companynr, companyname) VALUES ({$prng->uint16(1,99)},my_word)
  ;; INSERT INTO t4_MyISAM (companynr, companyname) VALUES ({$prng->uint16(1,99)},my_word)
  ;; INSERT INTO t4_MyISAM (companynr, companyname) VALUES ({$prng->uint16(1,99)},my_word)
  ;; INSERT INTO t4_MyISAM (companynr, companyname) VALUES ({$prng->uint16(1,99)},my_word)
  ;; INSERT INTO t4_MyISAM (companynr, companyname) VALUES ({$prng->uint16(1,99)},my_word)
  ;; INSERT INTO t4_MyISAM (companynr, companyname) VALUES ({$prng->uint16(1,99)},my_word)
  ;; INSERT INTO t4_MyISAM (companynr, companyname) VALUES ({$prng->uint16(1,99)},my_word)
  ;; insert into t2_MyISAM (fld1, companynr) values ({$prng->uint16(1,9999999)},{$prng->uint16(1,99)})
  ;; CREATE TABLE t1_InnoDB LIKE t1_MyISAM
  ;; ALTER TABLE t1_InnoDB ENGINE=InnoDB
  ;; INSERT INTO t1_InnoDB SELECT * FROM t1_MyISAM
  ;; CREATE TABLE t2_InnoDB LIKE t2_MyISAM
  ;; ALTER TABLE t2_InnoDB ENGINE=InnoDB
  ;; INSERT INTO t2_InnoDB SELECT * FROM t2_MyISAM
  ;; CREATE TABLE t3_InnoDB LIKE t3_MyISAM
  ;; ALTER TABLE t3_InnoDB ENGINE=InnoDB
  ;; INSERT INTO t3_InnoDB SELECT * FROM t3_MyISAM
  ;; CREATE TABLE t4_InnoDB LIKE t4_MyISAM
  ;; ALTER TABLE t4_InnoDB ENGINE=InnoDB
  ;; INSERT INTO t4_InnoDB SELECT * FROM t4_MyISAM
  ;; CREATE TABLE t1_Aria LIKE t1_InnoDB
  ;; ALTER TABLE t1_Aria ENGINE=Aria
  ;; INSERT INTO t1_Aria SELECT * FROM t1_MyISAM
  ;; CREATE TABLE t2_Aria LIKE t2_MyISAM
  ;; ALTER TABLE t2_Aria ENGINE=Aria
  ;; INSERT INTO t2_Aria SELECT * FROM t2_MyISAM
  ;; CREATE TABLE t3_Aria LIKE t3_MyISAM
  ;; ALTER TABLE t3_Aria ENGINE=Aria
  ;; INSERT INTO t3_Aria SELECT * FROM t3_MyISAM
  ;; CREATE TABLE t4_Aria LIKE t4_MyISAM
  ;; ALTER TABLE t4_Aria ENGINE=Aria
  ;; INSERT INTO t4_Aria SELECT * FROM t4_MyISAM
  ;; SET ROLE none
;

t4_extra_params:
  | MAX_ROWS={$prng->uint16(15,1000)} PACK_KEYS=__0_x_1 ;

t2_insert_1200:
  t2_insert_100 ;; t2_insert_100 ;; t2_insert_100 ;; t2_insert_100 ;; t2_insert_100 ;; t2_insert_100
  ;; t2_insert_100 ;; t2_insert_100 ;; t2_insert_100 ;; t2_insert_100 ;; t2_insert_100 ;; t2_insert_100 ;

t2_insert_100:
  t2_insert_10 ;; t2_insert_10 ;; t2_insert_10 ;; t2_insert_10 ;; t2_insert_10
   ;; t2_insert_10 ;; t2_insert_10 ;; t2_insert_10 ;; t2_insert_10 ;; t2_insert_10 ;; t2_insert_extra ;

t2_insert_10:
  t2_insert ;; t2_insert ;; t2_insert ;; t2_insert ;; t2_insert
  ;; t2_insert ;; t2_insert ;; t2_insert ;; t2_insert ;; t2_insert ;

t2_insert:
  INSERT IGNORE INTO t2_MyISAM VALUES (NULL,{$prng->uint16(0,999999)},{$prng->uint16(0,99)},my_word,my_word,my_word,t2_fld6_val) ;

t2_insert_extra:
  INSERT IGNORE INTO t2_MyISAM VALUES ({$prng->uint16(5900,6000)},{$prng->uint16(1232600,1232700)},{$prng->uint16(0,99)},'appendixes',my_word,my_word,t2_fld6_val) ;

t2_fld6_val:
  ==FACTOR:5== '' | 'W' | 'FAS' | 'A' ;

my_word:
  ==FACTOR:40== _english |
  _word ;

my_pattern:
  { "'%".$prng->dictionaryWord('english')."%'" } |
  { "'%".$prng->dictionaryWord('english')."'" } |
  { "'".$prng->dictionaryWord('english')."%'" } |
  ==FACTOR:5== { "'".$prng->unquotedString(1)."%'" } |
  { "'_".$prng->unquotedString($prng->uint16(1,4))."_'" } |
  { "'_".$prng->unquotedString($prng->uint16(1,2)).'_'.$prng->unquotedString($prng->uint16(1,2))."_'" } |
  { "'".$prng->unquotedString($prng->uint16(1,2)).'%'.$prng->unquotedString($prng->uint16(1,2))."'" } |
  { "'".$prng->uint16(0,999999)."%'" } ;

quoted_number:
  { "'".$prng->uint16(0,999999)."'" } ;

query:
  { _set_db('main_select_db') } main_select_query 
;

main_select_query:
  select period from t1 |
  select * from t1 |
  select t1.* from t1 |
  select t2.fld3 from t2 where companynr = _tinyint_unsigned and fld3 like my_pattern |
  select fld3 from t2 where fld3 like my_pattern |
  select t2.fld3,companynr from t2 where companynr = _tinyint_unsigned+_digit order by fld3 |
  select fld3,companynr from t2 where companynr = _tinyint_unsigned order by fld3 |
  select fld3 from t2 order by fld3 desc limit _tinyint_unsigned |
  select fld3 from t2 order by fld3 desc limit _tinyint_unsigned,_tinyint_unsigned |
  select t2.fld3 from t2 where fld3 = my_word |
  select t2.fld3 from t2 where fld3 LIKE my_pattern |
  select t2.fld3 from t2 where fld3 >= my_word and fld3 <= my_word order by fld3 |
  select fld1,fld3 from t2 where fld3=my_word or fld3 = my_word order by fld3 |
  select fld1,fld3 from t2 where companynr = _tinyint_unsigned and fld3 = 'appendixes' |
  select fld1 from t2 where fld1=_mediumint_unsigned or fld1=quoted_number |
  select fld1 from t2 where fld1=_mediumint_unsigned or fld1=_mediumint_unsigned or fld1 >= _mediumint_unsigned and fld1 <= _mediumint_unsigned or fld1 between _mediumint_unsigned and _mediumint_unsigned |
  select fld1,fld3 from t2 where companynr = _tinyint_unsigned and fld3 like my_pattern |
  select fld3 from t2 where fld3 like my_pattern and fld3 = my_word |
  select fld3 from t2 where (fld3 like my_pattern and fld3 = my_word) |
  select fld1,fld3 from t2 where fld1 like my_pattern |
  select distinct companynr from t2 |
  select distinct companynr from t2 order by companynr |
  select distinct companynr from t2 order by companynr desc |
  select distinct t2.fld3,period from t2,t1 where companynr=_tinyint_unsigned and fld3 like my_pattern |
  select distinct fld3 from t2 where companynr = _tinyint_unsigned order by fld3 |
  select /* RESULTSETS_NOT_COMPARABLE */ distinct fld3 from t2 limit _tinyint_unsigned |
  select /* RESULTSETS_NOT_COMPARABLE */ distinct fld3 from t2 having fld3 like my_pattern limit _tinyint_unsigned |
  select distinct substring(fld3,_digit,_digit) from t2 where fld3 like my_pattern |
  select distinct substring(fld3,_digit,_digit) as a from t2 having a like my_pattern order by a limit _tinyint_unsigned |
  select /* RESULTSETS_NOT_COMPARABLE */ distinct substring(fld3,_digit,_digit) from t2 where fld3 like my_pattern limit _tinyint_unsigned |
  select /* RESULTSETS_NOT_COMPARABLE */ distinct substring(fld3,_digit,_digit) as a from t2 having a like my_pattern limit _tinyint_unsigned |
  set tmp_memory_table_size=0 ;; select distinct concat(fld3," ",fld3) as namn from t2,t3 where t2.fld1=t3.t2nr order by namn limit _tinyint_unsigned ;; set tmp_memory_table_size=default |
  select distinct concat(fld3," ",fld3) from t2,t3 where t2.fld1=t3.t2nr order by fld3 limit _tinyint_unsigned |
  select /* RESULTSETS_NOT_COMPARABLE */ distinct fld5 from t2 limit _tinyint_unsigned |
  select distinct fld3,count(*) from t2 group by companynr,fld3 limit _tinyint_unsigned |
  set tmp_memory_table_size=0 ;; select distinct fld3,count(*) from t2 group by companynr,fld3 limit _tinyint_unsigned ;; set tmp_memory_table_size=default |
  select distinct fld3,repeat("a",length(fld3)),count(*) from t2 group by companynr,fld3 limit _tinyint_unsigned,_tinyint_unsigned |
  select distinct companynr,rtrim(space(_smallint_unsigned+companynr)) from t3 order by 1,2 |
  select distinct fld3 from t2,t3 where t2.companynr = _tinyint_unsigned and t2.fld1=t3.t2nr order by fld3 |
  select period from t1 |
  select period from t1 where period=_smallint_unsigned |
  select fld3,period from t1,t2 where fld1 = _mediumint_unsigned order by period |
  select fld3,period from t2,t3 where t2.fld1 = _mediumint_unsigned and t2.fld1=t3.t2nr and t3.period=_smallint_unsigned |
  select fld3,period from t2,t1 where companynr*_tinyint_unsigned = _tinyint_unsigned*_tinyint_unsigned |
  select fld3,period,price,price2 from t2,t3 where t2.fld1=t3.t2nr and period >= _smallint_unsigned and period <= _smallint_unsigned and t2.companynr = _tinyint_unsigned order by fld3,period, price |
  select t2.fld1,fld3,period,price,price2 from t2,t3 where t2.fld1>= _smallint_unsigned and t2.fld1 <= _smallint_unsigned and t2.fld1=t3.t2nr and period = _smallint_unsigned and t2.companynr = _tinyint_unsigned |
  select STRAIGHT_JOIN t2.companynr,companyname from t4,t2 where t2.companynr=t4.companynr group by t2.companynr |
  select SQL_SMALL_RESULT t2.companynr,companyname from t4,t2 where t2.companynr=t4.companynr group by t2.companynr |
  select * from t1,t1 t12 |
  select t2.fld1,t22.fld1 from t2,t2 t22 where t2.fld1 >= _mediumint_unsigned and t2.fld1 <= _mediumint_unsigned and t22.fld1 >= _mediumint_unsigned and t22.fld1 <= _mediumint_unsigned |
  select t2.companynr,companyname from t2 left join t4 using (companynr) where t4.companynr is null |
  select count(*) from t2 left join t4 using (companynr) where t4.companynr is not null |
  select companynr,companyname from t2 left join t4 using (companynr) where companynr is null |
  select count(*) from t2 left join t4 using (companynr) where companynr is not null |
  select distinct t2.companynr,t4.companynr from t2,t4 where t2.companynr=t4.companynr+_digit |
  select t2.fld1,t2.companynr,fld3,period from t3,t2 where t2.fld1 = _mediumint_unsigned and t2.fld1=t3.t2nr and period = _smallint_unsigned or t2.fld1 = _smallint_unsigned and t2.fld1 =t3.t2nr and period = _smallint_unsigned |
  select t2.fld1,t2.companynr,fld3,period from t3,t2 where (t2.fld1 = _mediumint_unsigned or t2.fld1 = _smallint_unsigned) and t2.fld1=t3.t2nr and period>=_smallint_unsigned and period<=_smallint_unsigned |
  select t2.fld1,t2.companynr,fld3,period from t3,t2 where (t3.t2nr = _mediumint_unsigned or t3.t2nr = _smallint_unsigned) and t2.fld1=t3.t2nr and period>=_smallint_unsigned and period<=_smallint_unsigned |
  select period from t1 where (((period > _digit) or period < _smallint_unsigned or (period = _smallint_unsigned)) and (period=_smallint_unsigned and period <= _smallint_unsigned) or (period=_smallint_unsigned and (period=_smallint_unsigned)) and period>=_smallint_unsigned) or ((period=_smallint_unsigned or period=_smallint_unsigned) or (period=_smallint_unsigned or period>_smallint_unsigned)) or (period=_smallint_unsigned and period = _smallint_unsigned) |
  select period from t1 where ((period > _tinyint_unsigned and period < _digit) or (((period > _tinyint_unsigned and period < _tinyint_unsigned) and (period > _tinyint_unsigned)) or (period > _tinyint_unsigned)) or (period > _digit and (period > _tinyint_unsigned or period > _tinyint_unsigned))) |
  select a.fld1 from t2 as a,t2 b where ((a.fld1 = _mediumint_unsigned and a.fld1=b.fld1) or a.fld1=_mediumint_unsigned or a.fld1=_mediumint_unsigned or (a.fld1=_mediumint_unsigned and a.fld1<=b.fld1 and b.fld1>=a.fld1)) and a.fld1=b.fld1 |
  select fld1 from t2 where fld1 in (_mediumint_unsigned,_mediumint_unsigned,_mediumint_unsigned,_mediumint_unsigned,_mediumint_unsigned,_mediumint_unsigned) and fld1 >=_mediumint_unsigned and fld1 not in (_mediumint_unsigned,_mediumint_unsigned) |
  select fld1 from t2 where fld1 between _mediumint_unsigned and _mediumint_unsigned |
  select fld3 from t2 where (((fld3 like my_pattern ) or (fld3 like my_pattern)) and ( fld3 like my_pattern or fld3 like my_pattern)) and fld3 like my_pattern |
  select count(*) from t1 |
  select companynr,count(*),sum(fld1) from t2 group by companynr |
  select companynr,count(*) from t2 group by companynr order by companynr desc limit _tinyint_unsigned |
  select count(*),min(fld4),max(fld4),sum(fld1),avg(fld1),std(fld1),variance(fld1) from t2 where companynr = _tinyint_unsigned and fld4<>"" |
  select companynr,count(*),min(fld4),max(fld4),sum(fld1),avg(fld1),std(fld1),variance(fld1) from t2 group by companynr limit _digit |
  select companynr,t2nr,count(price),sum(price),min(price),max(price),avg(price) from t3 where companynr = _tinyint_unsigned group by companynr,t2nr limit _tinyint_unsigned |
  select /*! SQL_SMALL_RESULT */ companynr,t2nr,count(price),sum(price),min(price),max(price),avg(price) from t3 where companynr = _tinyint_unsigned group by companynr,t2nr limit _tinyint_unsigned |
  select companynr,count(price),sum(price),min(price),max(price),avg(price) from t3 group by companynr |
  select distinct mod(companynr,_tinyint_unsigned) from t4 group by companynr |
  select distinct _tinyint_unsigned from t4 group by companynr |
  select count(distinct fld1) from t2 |
  select companynr,count(distinct fld1) from t2 group by companynr |
  select companynr,count(*) from t2 group by companynr |
  select companynr,count(distinct concat(fld1,repeat(_tinyint_unsigned,_smallint_unsigned))) from t2 group by companynr |
  select companynr,count(distinct concat(fld1,repeat(_tinyint_unsigned,_tinyint_unsigned))) from t2 group by companynr |
  select companynr,count(distinct floor(fld1/_tinyint_unsigned)) from t2 group by companynr |
  select companynr,count(distinct concat(repeat(_tinyint_unsigned,_smallint_unsigned),floor(fld1/_tinyint_unsigned))) from t2 group by companynr |
  select sum(fld1),fld3 from t2 where fld3=my_word group by fld1 limit _tinyint_unsigned |
  select name,count(*) from t3 where name='cloakroom' group by name |
  select name,count(*) from t3 where name='cloakroom' and price>_tinyint_unsigned group by name |
  select count(*) from t3 where name='cloakroom' and price2=_mediumint_unsigned |
  select name,count(*) from t3 where name='cloakroom' and price2=_mediumint_unsigned group by name |
  select name,count(*) from t3 where name >= my_word and price <= _mediumint_unsigned group by name |
  select t2.fld3,count(*) from t2,t3 where t2.fld1=_mediumint_unsigned and t3.name=t2.fld3 group by t3.name |
  select t2.companynr,companyname,count(*) from t2,t4 where t2.companynr=t4.companynr group by t2.companynr order by companyname |
  select t2.fld1,count(*) from t2,t3 where t2.fld1=_mediumint_unsigned and t3.name=t2.fld3 group by t3.name |
  select sum(Period)/count(*) from t1 |
  select companynr,count(price) as "count",sum(price) as "sum" ,abs(sum(price)/count(price)-avg(price)) as "diff",(_digit+count(price))*companynr as func from t3 group by companynr |
  select companynr,sum(price)/count(price) as avg from t3 group by companynr having avg > _mediumint_unsigned order by avg |
  select companynr,count(*) from t2 group by companynr order by 2 desc |
  select companynr,count(*) from t2 where companynr > _tinyint_unsigned group by companynr order by 2 desc |
  select t2.fld4,t2.fld1,count(price),sum(price),min(price),max(price),avg(price) from t3,t2 where t3.companynr = _tinyint_unsigned and t2.fld1 = t3.t2nr group by fld1,t2.fld4 |
  select t3.companynr,fld3,sum(price) from t3,t2 where t2.fld1 = t3.t2nr and t3.companynr = _smallint_unsigned group by companynr,fld3 |
  select t2.companynr,count(*),min(fld3),max(fld3),sum(price),avg(price) from t2,t3 where t3.companynr >= _tinyint_unsigned and t3.companynr <= _tinyint_unsigned and t3.t2nr = t2.fld1 and _digit+_digit=_digit group by t2.companynr |
  select t3.companynr+_digit,t3.t2nr,fld3,sum(price) from t3,t2 where t2.fld1 = t3.t2nr and t3.companynr = _tinyint_unsigned group by 1,t3.t2nr,fld3,fld3,fld3,fld3,fld3 order by fld1 |
  select sum(price) from t3,t2 where t2.fld1 = t3.t2nr and t3.companynr = _smallint_unsigned and t3.t2nr = _smallint_unsigned and t2.fld1 = _smallint_unsigned or t2.fld1= t3.t2nr and t3.t2nr = _smallint_unsigned and t2.fld1 = _smallint_unsigned |
  select t2.fld1,sum(price) from t3,t2 where t2.fld1 = t3.t2nr and t3.companynr = _smallint_unsigned and t3.t2nr = _smallint_unsigned and t2.fld1 = _smallint_unsigned or t2.fld1 = t3.t2nr and t3.t2nr = _smallint_unsigned and t2.fld1 = _smallint_unsigned or t3.t2nr = t2.fld1 and t2.fld1 = _smallint_unsigned group by t2.fld1 |
  select companynr,fld1 from t2 HAVING fld1=_mediumint_unsigned or fld1=_mediumint_unsigned |
  select companynr,fld1 from t2 WHERE fld1>=_mediumint_unsigned HAVING fld1<=_mediumint_unsigned |
  select companynr,count(*) as count,sum(fld1) as sum from t2 group by companynr having count > _tinyint_unsigned and sum/count >= _smallint_unsigned |
  select companynr from t2 group by companynr having count(*) > _tinyint_unsigned and sum(fld1)/count(*) >= _smallint_unsigned |
  select t2.companynr,companyname,count(*) from t2,t4 where t2.companynr=t4.companynr group by companyname having t2.companynr >= _tinyint_unsigned |
  select count(*) from t2 |
  select count(*) from t2 where fld1 < _mediumint_unsigned |
  select min(fld1) from t2 where fld1>= _mediumint_unsigned |
  select max(fld1) from t2 where fld1>= _mediumint_unsigned |
  select count(*) from t3 where price2=_mediumint_unsigned |
  select count(*) from t3 where companynr=_smallint_unsigned and price2=_mediumint_unsigned |
  select min(fld1),max(fld1),count(*) from t2 |
  select min(t2nr),max(t2nr) from t3 where t2nr=_smallint_unsigned and price2=_mediumint_unsigned |
  select count(*),min(t2nr),max(t2nr) from t3 where name='spates' and companynr=_tinyint_unsigned |
  select t2nr,count(*) from t3 where name='gems' group by t2nr limit _tinyint_unsigned |
  select max(t2nr) from t3 where price=_mediumint_unsigned |
  select /* RESULTSETS_NOT_COMPARABLE */ t1.period from t3 = t1 limit _digit |
  select /* RESULTSETS_NOT_COMPARABLE */ t1.period from t1 as t1 limit _digit |
  select /* RESULTSETS_NOT_COMPARABLE */ t1.period as "Nuvarande period" from t1 as t1 limit _digit |
  select /* RESULTSETS_NOT_COMPARABLE */ period as ok_period from t1 limit _digit |
  select period as ok_period from t1 group by ok_period limit _digit |
  select _digit+_digit as summa from t1 group by summa limit _digit |
  select period as "Nuvarande period" from t1 group by "Nuvarande period" limit _digit |
  show tables |
  show full columns from t2 |
  show full columns from t2 from main_select_db like my_pattern |
  show full columns from t2 from main_select_db like my_pattern |
  show keys from t2 ;

t1:
  t1_InnoDB | t1_MyISAM | t1_Aria ;

t2:
  t2_InnoDB | t2_MyISAM | t2_Aria ;

t3:
  t3_InnoDB | t3_MyISAM | t3_Aria ;

t4:
  t4_InnoDB | t4_MyISAM | t4_Aria ;

