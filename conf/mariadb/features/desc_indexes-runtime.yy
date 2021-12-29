# MDEV-13756 Implement descending index

query_add:
    desc_indexes_add
  | ==FACTOR:2== ALTER _basics_online_10pct TABLE _basetable DROP KEY IF EXISTS { 'ord_index_'.$prng->uint16(1,$ind).'_'.abs($$) } desc_indexes_algorithm_optional
  | ==FACTOR:0.05== ALTER TABLE _basetable DROP PRIMARY KEY desc_indexes_algorithm_optional
  | ==FACTOR:0.2== ANALYZE TABLE _basetable PERSISTENT FOR ALL
  | ==FACTOR:0.05== ALTER _basics_online_10pct TABLE _basetable FORCE desc_indexes_algorithm_optional
  | /* _table */ SELECT _field FROM { $last_table } WHERE { $last_field } LIKE { "'" . $prng->unquotedString($prng->uint16(0,8)) ."%'" }
;

desc_indexes_add:
  ALTER TABLE _basetable ADD key_or_unique IF NOT EXISTS { 'ord_index_'.(++$ind).'_'.abs($$) } ( desc_indexes_field_list ) desc_indexes_algorithm_optional;

desc_indexes_algorithm_optional:
  | , _basics_alter_table_algorithm ;

key_or_unique:
  ==FACTOR:20== KEY |
  UNIQUE |
  PRIMARY KEY
;

desc_indexes_field_list:
  _field desc_indexes_asc_desc |
  _field_char (_tinyint_unsigned) desc_indexes_asc_desc |
  ==FACTOR:2== _field desc_indexes_asc_desc, desc_indexes_field_list
;

desc_indexes_asc_desc:
  |
  ==FACTOR:5== DESC
;
