query:
    SET GLOBAL SERVER_AUDIT_LOGGING = ON
  | SET GLOBAL SERVER_AUDIT_LOGGING = OFF
;

thread1:
#      ==FACTOR:4== query
      INSTALL SONAME 'server_audit'
    | UNINSTALL SONAME 'server_audit'
;
