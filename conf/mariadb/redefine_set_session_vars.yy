query_init_add:
    set_variables ;
    
set_variables: 
    SET SESSION set_variables_list ;
    
set_variables_list:
    set_variable | set_variable , set_variables_list ;
    
set_variable:
      SQL_MODE = set_sql_mode
    | USE_STAT_TABLES = set_use_stat_tables_value
    | OPTIMIZER_USE_CONDITION_SELECTIVITY = set_selectivity
# Disabled due to MDEV-10397
#    | JOIN_CACHE_LEVEL = set_join_cache_level
    | HISTOGRAM_SIZE = set_histogram_size
    | HISTOGRAM_TYPE = set_histogram_type
;
    
set_sql_mode:
      CONCAT(@@sql_mode, ',ONLY_FULL_GROUP_BY')
    | ONLY_FULL_GROUP_BY
    | CONCAT(@@sql_mode, ',STRICT_ALL_TABLES')
    | ''
;

set_use_stat_tables_value:
    PREFERABLY | COMPLEMENTARY | NEVER ;

set_selectivity:
    1 | 2 | 3 | 4 | 5 ;

set_join_cache_level:
    0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 ;
    
set_histogram_size:
    0 | 128 | 255 ;
    
set_histogram_type:
    SINGLE_PREC_HB | DOUBLE_PREC_HB;
    
