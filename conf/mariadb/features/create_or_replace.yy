query_add:
  CREATE OR REPLACE __temporary(5) TABLE crea_table_name LIKE _table |
  CREATE OR REPLACE __temporary(5) TABLE crea_table_name crea_maybe_engine AS SELECT * FROM _table LIMIT crea_limit |
  CREATE OR REPLACE __temporary(5) TABLE crea_table_name crea_table_definition |
  ==FACTOR:0.05== DROP __temporary(50) TABLE IF EXISTS crea_table_name |
;

crea_table_name:
    `CreateOrReplaceTable` | { 'CreateOrReplaceTable'.abs($$) } | _table ;

crea_limit:
  0 | _digit | _smallint_unsigned ;

crea_maybe_engine:
  | ENGINE = _engine
;

crea_table_definition:
  { $colnum=0; '' } ( crea_column_list ) crea_maybe_engine _basics_table_options _basics_system_versioning_5pct _basics_table_partitioning ;

crea_column_list:
  crea_column |
  ==FACTOR:3== crea_column, crea_column_list ;

crea_column:
  { 'col'.(++$colnum) } _basics_column_type _basics_column_attributes;

