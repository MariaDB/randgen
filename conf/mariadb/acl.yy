query_add:
  acl
;

acl:
    acl_create_user | acl_create_user | acl_create_user
  | acl_alter_user | acl_alter_user | acl_alter_user | acl_alter_user
  | acl_drop_user
  | acl_grant
  | acl_rename_user
  | acl_revoke
  | acl_set_password
  | acl_create_role | acl_create_role | acl_create_role
  | acl_drop_role
  | acl_set_role | acl_set_default_role
  | acl_show_grants
;

acl_create_user:
  CREATE USER acl_if_not_exists acl_user_specification_list acl_require acl_with
  | CREATE acl_or_replace USER acl_user_specification_list acl_require acl_with
;

# MDEV-17941 - ALTER USER IF EXISTS does not work
#   ALTER USER acl_if_exists acl_user_specification_list acl_require acl_with
acl_alter_user:
  ALTER USER acl_user_specification_list acl_require acl_with
;

acl_drop_user:
  DROP USER acl_if_exists acl_username_list
;

acl_rename_user:
  RENAME USER acl_rename_list
;

acl_set_password:
    SET PASSWORD FOR acl_username = PASSWORD(acl_password)
  | SET PASSWORD FOR acl_username = OLD_PASSWORD(acl_password)
  | SET PASSWORD FOR acl_username = acl_password_hash
  # Can't change password for the current user, it will cause troubles
  | SET PASSWORD = ''
;

acl_create_role:
    CREATE ROLE acl_if_not_exists acl_short_name acl_with_admin
  | CREATE acl_or_replace ROLE acl_short_name acl_with_admin
;

acl_drop_role:
  DROP ROLE acl_if_exists acl_role_list
;

acl_with_admin:
  | | | WITH ADMIN acl_role_admin
;

acl_role_admin:
  CURRENT_USER | CURRENT_ROLE | acl_full_name | acl_short_name | acl_short_name | acl_short_name
;

acl_set_role:
    SET ROLE acl_short_name | SET ROLE acl_short_name | SET ROLE acl_short_name | SET ROLE acl_short_name
  | SET ROLE NONE
;

acl_set_default_role:
    SET DEFAULT ROLE acl_short_name acl_target_user
  | SET DEFAULT ROLE acl_short_name acl_target_user
  | SET DEFAULT ROLE acl_short_name acl_target_user
  | SET DEFAULT ROLE acl_short_name acl_target_user
  | SET DEFAULT ROLE NONE acl_target_user
;

acl_show_grants:
  SHOW GRANTS acl_target_user
;

acl_grant:
  GRANT acl_grant_variation TO acl_username acl_authentication_option acl_require acl_with
;

acl_revoke:
  REVOKE acl_grant_variation FROM acl_username_list
;

acl_grant_variation:
    acl_all_privileges ON acl_opt_priv_level_any

  | acl_global_privilege_list ON acl_opt_priv_level_all
  
  | acl_database_privilege_list ON acl_opt_priv_level_all
  | acl_database_privilege_list ON acl_opt_priv_level_wildcard

  | acl_table_privilege_list ON acl_opt_table acl_opt_priv_level_any
  
  | acl_column_privilege_list ON acl_opt_table acl_opt_priv_level_exact
  
  | acl_routine_privilege_list ON acl_opt_priv_level_all
  | acl_routine_privilege_list ON acl_opt_priv_level_wildcard
  | acl_routine_privilege_list ON acl_opt_routine acl_opt_priv_level_exact
  
;

acl_opt_priv_level_any:
  acl_opt_priv_level_all | acl_opt_priv_level_wildcard | acl_opt_priv_level_exact
;

acl_opt_priv_level_all:
  * | *.*
;

acl_opt_priv_level_wildcard:
  test.* | _letter.*
;

acl_opt_priv_level_exact:
  test._table | _letter._letter | _table | _letter
;

acl_opt_table:
  | TABLE
;

acl_opt_routine:
  FUNCTION | PROCEDURE
;

acl_grant_target_user:
  acl_username acl_authentication_option acl_require acl_with
;

acl_priv_type:
  | acl_global_privilege
  | acl_database_privilege
  | acl_table_privilege
  | acl_column_privilege
  | acl_routine_privilege
;

acl_all_privileges:
  ALL | ALL PRIVILEGES
;

acl_global_privilege:
    CREATE USER
  | FILE
  | PROCESS
  | RELOAD
  | REPLICATION CLIENT
  | REPLICATION SLAVE
  | SHOW DATABASES
  | SHUTDOWN
  | SUPER
  | GRANT OPTION
;

acl_global_privilege_list:
  acl_global_privilege | acl_global_privilege, acl_global_privilege_list
;

acl_database_privilege:
    CREATE
  | CREATE ROUTINE
  | CREATE TEMPORARY TABLES
  | DROP
  | EVENT
  | LOCK TABLES
  | GRANT OPTION
;

acl_database_privilege_list_with_grant:
  GRANT_OPTION | acl_database_privilege | acl_database_privilege, acl_database_privilege_list_with_grant
;

acl_database_privilege_list:
  acl_database_privilege | acl_database_privilege, acl_database_privilege_list
;

acl_table_privilege:
    ALTER
  | CREATE
  | CREATE VIEW
  | DELETE
  | DELETE HISTORY
  | DROP
  | INDEX
  | INSERT
  | REFERENCES
  | SELECT
  | SHOW VIEW
  | TRIGGER
  | UPDATE
  | GRANT OPTION
;

acl_table_privilege_list:
  acl_table_privilege | acl_table_privilege, acl_table_privilege_list
;

acl_column_privilege:
    INSERT (acl_column_list)
  | REFERENCES (acl_column_list)
  | SELECT (acl_column_list)
  | UPDATE (acl_column_list)
;

acl_column_privilege_list:
  acl_column_privilege | acl_column_privilege, acl_column_privilege_list
;

acl_column_list:
  _field | _field, acl_column_list
;

acl_column_privilege_list:
  acl_column_privilege | acl_column_privilege, acl_column_privilege_list
;

acl_routine_privilege:
    ALTER ROUTINE
  | EXECUTE
  | GRANT OPTION
;

acl_routine_privilege_list:
  acl_routine_privilege | acl_routine_privilege, acl_routine_privilege_list
;

acl_target_user:
  | | | FOR acl_username
;

acl_or_replace:
# MDEV-17942 - Assertion failure after failed CREATE OR REPLACE
#  | | OR REPLACE
;

acl_if_not_exists:
  | | | IF NOT EXISTS
;

acl_if_exists:
  | | | IF EXISTS
;

acl_user_specification_list:
  acl_user_specification | acl_user_specification, acl_user_specification_list
;

acl_user_specification:
  acl_username acl_authentication_option
;

acl_username_list:
  acl_username | acl_username, acl_username
;

acl_rename_list:
  acl_username TO acl_username | acl_username TO acl_username, acl_rename_list
;

acl_role_list:
  acl_short_name | acl_short_name, acl_role_list
;

acl_username:
    acl_short_name | acl_short_name | acl_short_name | acl_short_name
  | acl_full_name | acl_full_name | acl_full_name | acl_full_name
  | ''
;

acl_short_name:
    _letter | _letter | _letter | _letter | _letter | _letter | _letter
  | _char(8) | '%'
;

acl_full_name:
  acl_short_name@localhost | acl_short_name@localhost | acl_short_name@localhost | acl_short_name@localhost | acl_short_name@localhost | 
  ''@localhost
;

acl_host:
  _tinyint_unsigned._tinyint_unsigned._tinyint_unsigned._tinyint_unsigned | _letter._letter._letter | localhost | '%' | ''
;

acl_authentication_option:
  | | | | | |
  | IDENTIFIED BY acl_password 
  | IDENTIFIED BY PASSWORD acl_password_hash
  | IDENTIFIED acl_via_with acl_authentication_plugin
  | IDENTIFIED acl_via_with acl_authentication_plugin acl_using_as acl_authentication_string
  # MDEV-12321 - authentication plugin: SET PASSWORD support (10.4.0)
  # TODO: wrap it up in /*!100400 ... */ after comparative testing with 10.3 is finished
  | IDENTIFIED acl_via_with acl_authentication_plugin acl_using_as PASSWORD(acl_password)
;

acl_password:
  '' | _char(8) | _char(16) | _char(32) | _char(40)
;

acl_password_hash:
  { "'*" . join ('', map { (0..9,'A'..'F')[$prng->int(0,15)] } (1..40) ) . "'" }
;

acl_via_with:
  VIA | WITH
;

acl_authentication_plugin:
  ed25519 | gssapi | pam | unix_socket | named_pipe
;

acl_using_as:
  USING | AS
;

acl_authentication_string:
  acl_password | _char(16)
;

acl_require:
  | | | REQUIRE acl_require_exclusive_option | REQUIRE acl_tls_option_list
;

acl_tls_option_list:
  acl_tls_option | acl_tls_option AND acl_tls_option_list
;

acl_require_exclusive_option:
  NONE | SSL | X509
;

acl_tls_option:
    CIPHER _char(8)
  | ISSUER _char(8)
  | SUBJECT _char(8)
;

acl_with:
  | | | WITH acl_resource_option_list
;

acl_resource_option_list:
  acl_resource_option | acl_resource_option acl_resource_option_list
;

acl_resource_option:
    MAX_QUERIES_PER_HOUR _int_unsigned
  | MAX_UPDATES_PER_HOUR _int_unsigned
  | MAX_CONNECTIONS_PER_HOUR _tinyint_unsigned
  | MAX_USER_CONNECTIONS _tinyint_unsigned
;
