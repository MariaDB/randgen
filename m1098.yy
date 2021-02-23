query_init:
  INSTALL SONAME 'server_audit'; SET GLOBAL server_audit_logging=ON, server_audit_file_rotate_size=100;

query:
  SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'test' AND TABLE_NAME = { "'" . $prng->arrayElement($executors->[0]->tables('test'))."'" } |
  UPDATE _table SET _field = _value
;
