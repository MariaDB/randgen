# Copyright (C) 2016 MariaDB Corporation.
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

# Rough imitation of OLTP-read-write test (sysbench-like)

query_init:
    INSTALL SONAME 'file_key_management';

query:
    create_or_replace | create_or_replace | create_or_replace |
    drop_table | drop_table |
    alter | alter | alter | alter | alter | alter | alter |
    select |
    update | update | update | update | update | update | update |
    delete | delete |
    insert | insert | insert | insert | insert | insert | insert |
    flush |
    set_compression_algorithm
;

set_compression_algorithm:
    SET GLOBAL innodb_compression_algorithm=compression_algorithm;
    
compression_algorithm:
    zlib | lz4 | lzo | lzma | bzip2 | snappy |
    zlib | lz4 | lzo | lzma | bzip2 | snappy |
    none
;

flush:
    FLUSH TABLES;

runtime_table:
    A | B | C | D | E | F | G | H ;
    
create_or_replace:
    CREATE OR REPLACE TABLE runtime_table LIKE _table |
    CREATE OR REPLACE TABLE runtime_table AS SELECT * FROM _table
;

drop_table:
    DROP TABLE IF EXISTS runtime_table;
    
alter:
    ALTER TABLE _table alter_options;
    
alter_options:
    | FORCE | 
    table_option_list | table_option_list | table_option_list | table_option_list
;
    
table_option_list:
    table_option | table_option table_option_list;
    
table_option:
    encrypted | encryption_key | row_format | page_compressed ;
    
encrypted:
    ENCRYPTED=yes_no;
    
encryption_key:
    ENCRYPTION_KEY_ID=encryption_key_id;
    
# Only valid keys for now
encryption_key_id:
    1 | 2 | 33 | 4 | 5 | 6;
    
yes_no:
    YES | YES | YES | YES | NO ;
    
row_format:
    ROW_FORMAT=rformat;
    
rformat:
    COMPRESSED | COMPRESSED | COMPRESSED | COMPRESSED | COMPACT | DYNAMIC ;
    
page_compressed:
    PAGE_COMPRESSED=zero_one;
    
zero_one:
    0 | 1 | 1 | 1 | 1 | 1 ;

insert:
    INSERT IGNORE INTO _table ( _field_pk ) VALUES ( NULL ) |
    INSERT IGNORE INTO _table ( _field_int ) VALUES ( _smallint_unsigned ) |
    INSERT IGNORE INTO _table ( _field_char ) VALUES ( _string ) |
    INSERT IGNORE INTO _table ( _field_pk, _field_int)  VALUES ( NULL, _int ) |
    INSERT IGNORE INTO _table ( _field_pk, _field_char ) VALUES ( NULL, _string ) 
;

update:
    index_update |
    non_index_update
;

delete:
    DELETE FROM _table WHERE _field_pk = _smallint_unsigned ;

index_update:
    UPDATE IGNORE _table SET _field_int_indexed = _field_int_indexed + 1 WHERE _field_pk = _smallint_unsigned ;

# It relies on char fields being unindexed. 
# If char fields happen to be indexed in the table spec, then this update can be indexed as well. No big harm though. 
non_index_update:
    UPDATE _table SET _field_char = _string WHERE _field_pk = _smallint_unsigned ;

select:
    point_select |
    simple_range |
    sum_range |
    order_range |
    distinct_range 
;

point_select:
    SELECT _field FROM _table WHERE _field_pk = _smallint_unsigned ;

simple_range:
    SELECT _field FROM _table WHERE _field_pk BETWEEN _smallint_unsigned AND _smallint_unsigned ;

sum_range:
    SELECT SUM(_field) FROM _table WHERE _field_pk BETWEEN _smallint_unsigned AND _smallint_unsigned ;

order_range:
    SELECT _field FROM _table WHERE _field_pk BETWEEN _smallint_unsigned AND _smallint_unsigned ORDER BY _field ;

distinct_range:
    SELECT DISTINCT _field FROM _table WHERE _field_pk BETWEEN _smallint_unsigned AND _smallint_unsigned ORDER BY _field ;

