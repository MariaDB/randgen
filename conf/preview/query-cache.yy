query:
    set_qcache_type |
    { _set_db('NON-SYSTEM') } ddl ;

set_qcache_type:
# global causes too much trouble, MDEV-41690
# __global_x_session
  SET SESSION QUERY_CACHE_TYPE = qcache_type_value ;

qcache_type_value:
    OFF |
    ON |
    DEMAND |
    DEMAND_STRICT |
    TABLES |
    ==FACTOR:0.001== ALWAYS_OFF
;

ddl:
    ALTER TABLE _basetable QUERY_CACHE = __yes_x_no_x_default ;
