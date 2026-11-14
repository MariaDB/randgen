query:
    ==FACTOR:0.01== set_qcache_var |
    { _set_db('NON-SYSTEM') } ddl ;

set_qcache_var:
# global causes too much trouble, MDEV-41690
# __global_x_session
  SET __global(1) QUERY_CACHE_TYPE = qcache_type_value |
  SET GLOBAL QUERY_CACHE_USE_RW_LOCK = __on_x_off
;

qcache_type_value:
    OFF |
    ON |
    DEMAND |
    DEMAND_STRICT |
    TABLES |
    ==FACTOR:0.001== ALWAYS_OFF
;

ddl:
    ALTER TABLE _basetable SQL_CACHE = sql_cache_val |
    CREATE OR REPLACE __temporary(50) TABLE { 'tmp_qcache_'.$prng->uint16(1,9) } (a INT) ENGINE = _engine SQL_CACHE = sql_cache_val;

sql_cache_val:
    1 | 0 | DEFAULT ;
