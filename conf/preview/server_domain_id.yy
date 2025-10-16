query:
  SET server_id = { $prng->uint16(1,100) } |
  SET server_id = @@global.server_id |
  SET gtid_domain_id = { $prng->uint16(1,100) } |
  SET gtid_domain_id = @@global.gtid_domain_id
;
