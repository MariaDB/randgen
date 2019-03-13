########################################################################
#
# MDEV-6111 Optimizer trace, MariaDB 10.4.3+
# https://mariadb.com/kb/en/library/optimizer-trace/
#
# Can be used as a redefined grammar.
# ATTENTION: presumes the use of basics.yy for primitives
#
########################################################################

query_add:
  opttrace_query |
  query | query | query | query | query | query | query | query | query
;

opttrace_query:
  opttrace_set_max_mem_size |
  opttrace_enable_disable_trace |
  opttrace_is_select | opttrace_is_select | opttrace_is_select | opttrace_is_select |
  opttrace_is_select | opttrace_is_select | opttrace_is_select | opttrace_is_select
;

opttrace_enable_disable_trace:
  SET _basics_global_or_session_optional optimizer_trace = opttrace_enabled_value ;

opttrace_enabled_value:
  'enabled=off' | 'enabled=on' | 'enabled=default' ;

opttrace_set_max_mem_size:
  SET _basics_global_or_session_optional optimizer_trace_max_mem_size = opttrace_max_mem_size ;

opttrace_max_mem_size:
  opttrace_big_size | opttrace_small_size | DEFAULT ;

opttrace_big_size:
  { $prng->int(1048576,134217728) } ;

opttrace_small_size:
  { $prng->int(1,1048576) } ;

opttrace_is_select:
  SELECT * FROM INFORMATION_SCHEMA.OPTIMIZER_TRACE _basics_order_by_limit_50pct_offset_10pct ;
