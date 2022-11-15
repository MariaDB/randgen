query_add:
  crea_maybe_engine CREATE OR REPLACE TABLE crea_table_name LIKE _table |
  crea_maybe_engine CREATE OR REPLACE TABLE crea_table_name AS SELECT * FROM _table LIMIT crea_limit |
  crea_maybe_engine CREATE OR REPLACE TABLE crea_table_name crea_table_definition
;

crea_table_name:
    `CreateOrReplaceTable` | { 'CreateOrReplaceTable'.abs($$) } | _table ;

crea_limit:
  0 | _digit | _smallint_unsigned ;

crea_maybe_engine:
  |
  SELECT `engine` FROM INFORMATION_SCHEMA.ENGINES WHERE SUPPORT IN ('YES','DEFAULT') AND ENGINE NOT IN ('PERFORMANCE_SCHEMA','SEQUENCE') ORDER BY RAND({$prng->uint16(0,20)}) LIMIT 1 INTO @eng; SET STATEMENT default_storage_engine = @eng FOR
;

crea_table_definition:
  { $colnum=0; '' } ( crea_column_list ) _basics_table_options _basics_system_versioning_5pct _basics_table_partitioning ;

crea_column_list:
  crea_column |
  ==FACTOR:3== crea_column, crea_column_list ;

crea_column:
  { 'col'.(++$colnum) } _basics_column_type _basics_column_attributes;

