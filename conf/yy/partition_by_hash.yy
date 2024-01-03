# Copyright (c) 2003, 2012, Oracle and/or its affiliates. All rights reserved.
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
#
##########################################################################
# This grammar contains ddl for partitions as well as partition extentions to dml.
# The grammar doesn't rely on the predefined tables, but uses instead
# tables defined in init.
# Rules common with other partitioning types are in the include file
##########################################################################

#include <conf/yy/include/partition_by.inc>


query_init:
     CREATE DATABASE IF NOT EXISTS partition_db
  ;; SET ROLE admin
     # PS is a workaround for MDEV-30190
  ;; EXECUTE IMMEDIATE CONCAT('GRANT ALL ON partition_db.* TO ',CURRENT_USER,' WITH GRANT OPTION')
  ;; SET ROLE NONE
  ;; { $tblnum=0 ; _set_db('partition_db') } init_db ;

create:
  CREATE TABLE if_not_exists { $new_table= 'thash_'.(++$tblnum).'_'.$generator->threadId() } (
                `col_int_nokey` INTEGER,
                `col_int_key` INTEGER NOT NULL,
                KEY (`col_int_key` __asc_x_desc(33,33))
  ) engine_clause partition ;

dml_table_name:
  _table PARTITION (partition_name_list) ;

some_partition_names:
  partition_name                      |
  partition_name                      |
  partition_name                      |
  partition_name                      |
  partition_name                      |
  partition_name, some_partition_names;

partition_name_list:
  partition_name_comb                 |
  partition_name_comb                 |
  partition_name_comb                 |
        some_partition_names                ;

partition_name_comb:
  p0,p1,p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21,p22,p23,p24,
p25,p26,p27,p28,p29,p30,p31,p32,p33,p34,p35,p36,p37,p38,p39,p40,p41,p42,p43,p44,p45,p46,
p47,p48,p49,p50,p51,p52,p53,p54,p55,p56,p57,p58,p59,p60,p61,p62,p63,p64,p65,p66,p67,p68,
p69,p70,p71,p72,p73,p74,p75,p76,p77,p78,p79,p80,p81,p82,p83,p84,p85,p86,p87,p88,p89,p90,
p91,p92,p93,p94,p95,p96,p97,p98,p99                                                       |
  p0,p1,p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21,p22,p23,p24,
p25,p26,p27,p28,p29,p30,p31,p32,p33,p34,p35,p36,p37,p38,p39,p40,p41,p42,p43,p44,p45,p46,
p47,p48,p49,p50,p51,p52,p53,p54,p55,p56,p57,p58,p59,p60,p61,p62,p63,p64,p65,p66,p67,p68,
p69,p70,p71,p72,p73,p74,p75,p76,p77,p78,p79,p80,p81,p82,p83,p84,p85,p86,p87,p88,p89,p90,
p91,p92,p93,p94,p95,p96,p97,p98                                                           |
  p0,p1,p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21,p22,p23,p24,
p25,p26,p27,p28,p29,p30,p31,p32,p33,p34,p35,p36,p37,p38,p39,p40,p41,p42,p43,p44,p45,p46,
p47,p48,p49,p50,p51,p52,p53,p54,p55,p56,p57,p58,p59,p60,p61,p62,p63,p64,p65,p66,p67,p68,
p69,p70,p71,p72,p73,p74,p75,p76,p77,p78,p79,p80,p81,p82,p83,p84,p85,p86,p87,p88,p89,p90,
p91,p92,p93,p94,p95,p96,p97                                                               |
  p0,p1,p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21,p22,p23,p24,
p25,p26,p27,p28,p29,p30,p31,p32,p33,p34,p35,p36,p37,p38,p39,p40,p41,p42,p43,p44,p45,p46,
p47,p48,p49,p50,p51,p52,p53,p54,p55,p56,p57,p58,p59,p60,p61,p62,p63,p64,p65,p66,p67,p68,
p69,p70,p71,p72,p73,p74,p75,p76,p77,p78,p79,p80,p81,p82,p83,p84,p85,p86,p87,p88,p89,p90,
p91,p92,p93,p94,p95,p96
  ;

partition_name:
  p0 | p1 | p2 | p3 | p4 | p5 | p6 | p7 | p8 | p9 | p10 | p11 | p12 | p13 | p14 | p15 | p16 | p17 | p18 | p19 | p20 | p21 | p22 | p23 | p24 | p25 | p26 | p27 | p28 | p29 | p30 | p31 | p32 | p33 | p34 | p35 | p36 | p37 | p38 | p39 | p40 | p41 | p42 | p43 | p44 | p45 | p46 | p47 | p48 | p49 | p50 | p51 | p52 | p53 | p54 | p55 | p56 | p57 | p58 | p59 | p60 | p61 | p62 | p63 | p64 | p65 | p66 | p67 | p68 | p69 | p70 | p71 | p72 | p73 | p74 | p75 | p76 | p77 | p78 | p79 | p80 | p81 | p82 | p83 | p84 | p85 | p86 | p87 | p88 | p89 | p90 | p91 | p92 | p93 | p94 | p95 | p96 | p97 | p98 | p99  ;

partition:
  partition_by_hash  |
  partition_by_key   ;

partition_by_hash:
  PARTITION BY linear HASH ( part_field ) PARTITIONS partition_count;

linear:
  | LINEAR;

partition_by_key:
  PARTITION BY KEY(`col_int_key`) PARTITIONS partition_count ;

partition_count:
  96 | 97 | 98 | 98 | 98 | 99 | 99 | 99 | 99 ;

alter_convert_table_to_part:
  # Not supported for hash partitioning
  alter_exchange
;
