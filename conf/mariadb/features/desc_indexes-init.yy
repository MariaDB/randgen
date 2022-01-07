# MDEV-13756 Implement descending index

query_init_add:
  { $ind=1; '' } desc_indexes_init_add_8 ;

desc_indexes_init_add_8:
  desc_indexes_init_add_4 ; desc_indexes_init_add_4 ;

desc_indexes_init_add_4:
  desc_indexes_init_add ; desc_indexes_init_add ; desc_indexes_init_add ; desc_indexes_init_add ;

desc_indexes_init_add:
  ALTER _basics_online_10pct TABLE _basetable ADD key_or_unique IF NOT EXISTS { 'ord_index_'.($ind++).'_'.abs($$) } ( desc_indexes_init_field_list ) desc_indexes_init_algorithm_optional;

desc_indexes_init_algorithm_optional:
  | , _basics_alter_table_algorithm ;

key_or_unique:
  ==FACTOR:20== KEY |
  UNIQUE |
  PRIMARY KEY
;

desc_indexes_init_field_list:
  _field desc_indexes_init_asc_desc |
  _field_char (_tinyint_unsigned) desc_indexes_init_asc_desc |
  ==FACTOR:2== _field desc_indexes_init_asc_desc, desc_indexes_init_field_list
;

desc_indexes_init_asc_desc:
  | DESC | ASC
;
