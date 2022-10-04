#
# Regression test for LP:1008293
#   SET key_cache_segments leads to crashes 
#   in get_partitioned_key_cache_statistics, or safe_mutex_lock, 
#   or partitioned_key_cache_statistics
#

query_init_add:
  SET GLOBAL keycache1.key_buffer_size = 1024*1024;

thread1:
  SET GLOBAL key_cache_segments = _digit;

query_add:
  CACHE INDEX _table IN keycache1;

