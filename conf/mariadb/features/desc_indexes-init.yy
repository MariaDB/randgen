# MDEV-13756 Implement descending index

query_init:
  { $ind=1; '' } desc_indexes_init_add_8 ;

desc_indexes_init_add_8:
  desc_indexes_init_add_4 ; desc_indexes_init_add_4 ;

desc_indexes_init_add_4:
  desc_indexes_init_add ; desc_indexes_init_add ; desc_indexes_init_add ; desc_indexes_init_add ;

desc_indexes_init_add:
  ALTER __online(10) TABLE _basetable ADD key_or_unique IF NOT EXISTS { 'ord_index_'.($ind++).'_'.abs($$) } ( desc_indexes_init_field_list ) desc_indexes_init_algorithm_optional;

desc_indexes_init_algorithm_optional:
  | , ALGORITHM = __default_x_inplace_x_copy_x_nocopy_x_instant ;

key_or_unique:
  ==FACTOR:20== KEY |
  UNIQUE |
  PRIMARY KEY
;

desc_indexes_init_field_list:
  _field  __asc_x_desc(33,33) |
  _field_char (_tinyint_unsigned)  __asc_x_desc(33,33) |
  ==FACTOR:2== _field  __asc_x_desc(33,33), desc_indexes_init_field_list
;

