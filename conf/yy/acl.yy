# Copyright (C) 2018, 2022 MariaDB Corporation Ab
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
# USA

########################################################################
#
# ACL actions
#
########################################################################

query:
  { _set_db('ANY') } acl
;

acl:
    ==FACTOR:4== acl_create_user
  | ==FACTOR:4== acl_alter_user
  | ==FACTOR:0.5== acl_drop_user
  | ==FACTOR:8== acl_grant
  | acl_rename_user
  | ==FACTOR:5== acl_revoke
  | ==FACTOR:0.5== acl_set_password
  | ==FACTOR:4== acl_create_role
  | ==FACTOR:0.5== acl_drop_role
  | ==FACTOR:3== acl_set_role
  | ==FACTOR:2== acl_set_default_role
  | acl_show_grants
  # MDEV-7597 - Expiration of user passwords (10.4.3)
  | /*!100403 acl_password_expiration_variables */
;

acl_create_user:
  CREATE USER __if_not_exists(80) acl_user_specification_list acl_require acl_with /*!100403 acl_password_expire */
  | CREATE __or_replace(90) USER acl_user_specification_list acl_require acl_with /*!100403 acl_password_expire */
;

# IF EXISTS was broken until 10.3.23 / 10.4.13
acl_alter_user:
  ALTER USER /*!100413 __if_exists(80) */ acl_user_specification_list acl_require acl_with /*!100403 acl_password_expire */
;

acl_drop_user:
  DROP USER __if_exists(80) acl_username_list
;

acl_rename_user:
  RENAME USER acl_rename_list
;

acl_set_password:
    SET PASSWORD FOR acl_username = PASSWORD(acl_password)
  | SET PASSWORD FOR acl_username = /*!!050706 OLD_PASSWORD(acl_password) */ OLD_PASSWORD(acl_password) /*!50706 PASSWORD(acl_password) */
  | SET PASSWORD FOR acl_username = acl_password_hash
  # Can't change password for the current user, it will cause troubles
  | SET PASSWORD = ''
;

acl_create_role:
    CREATE ROLE __if_not_exists(80) acl_short_name acl_with_admin
  | CREATE __or_replace(90) ROLE acl_short_name acl_with_admin
;

acl_drop_role:
  DROP ROLE __if_exists(80) acl_role_list
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
    ALL __privileges(50) ON acl_opt_priv_level_any

  | acl_global_privilege_list ON acl_opt_priv_level_all

  | acl_database_privilege_list ON acl_opt_priv_level_all
  | acl_database_privilege_list ON acl_opt_priv_level_wildcard

  | acl_table_privilege_list ON __table(50) acl_opt_priv_level_any

  | /* _table[invariant] */ acl_column_privilege_list ON __table(50) acl_priv_table_level_exact

  | acl_routine_privilege_list ON acl_opt_priv_level_all
  | acl_routine_privilege_list ON acl_opt_priv_level_wildcard
  | acl_routine_privilege_list ON __function_x_procedure acl_opt_priv_level_exact

;

acl_opt_priv_level_any:
  acl_opt_priv_level_all | acl_opt_priv_level_wildcard | acl_opt_priv_level_exact
;

acl_opt_priv_level_all:
  * | *.*
;

acl_opt_priv_level_wildcard:
    ==FACTOR:10== test.*
  | _letter.*
;

acl_opt_priv_level_exact:
    _database._letter
  | _letter
;

acl_priv_table_level_exact:
    ==FACTOR:20== _table[invariant]
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
  | /*!!100304 DELETE */ /*!100304 DELETE HISTORY */
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
    ==FACTOR:8== _letter
  | ==FACTOR:0.1== '%'
  # Prevent damaging the current user
  | { $shortname= $prng->unquotedString(8); ${shortname}.'@localhost' ne $executors->[0]->user() and ${shortname} ne 'root' ? '`'.$shortname.'`' : '`'.$shortname.'_`' }
  | ==FACTOR:0.1== PUBLIC
  | ==FACTOR:0.1== NONE
;

acl_full_name:
  ==FACTOR:3== acl_short_name@localhost |
  ==FACTOR:3== acl_short_name@'%' |
  ''@localhost |
  acl_short_name@acl_host
;

acl_host:
  _tinyint_unsigned._tinyint_unsigned._tinyint_unsigned._tinyint_unsigned | _letter._letter._letter | localhost | '%' | ''
;

acl_authentication_option:
  | | | | | |
  | IDENTIFIED BY acl_password
  | IDENTIFIED BY PASSWORD acl_password_hash
  | IDENTIFIED __via_x_with acl_authentication_plugin
  | IDENTIFIED __via_x_with acl_authentication_plugin __using_x_as acl_authentication_string
  # MDEV-12321 - authentication plugin: SET PASSWORD support (10.4.0)
  # TODO: wrap it up in /*!100400 ... */ after comparative testing with 10.3 is finished
  | IDENTIFIED __via_x_with acl_authentication_plugin acl_optional_password_for_plugin
;

acl_optional_password_for_plugin:
   |
   | /*!100402 USING PASSWORD(acl_password) */
   | /*!100402 AS PASSWORD(acl_password) */
;

acl_password_expire:
  | | | PASSWORD EXPIRE acl_password_expiration_option ;

# MDEV-7597 - Expiration of user passwords (10.4.3)
acl_password_expiration_option:
  | DEFAULT | NEVER | INTERVAL _smallint_unsigned DAY ;

acl_password_expiration_variables:
  SET GLOBAL default_password_lifetime = _smallint_unsigned |
  SET GLOBAL disconnect_on_expired_password = ON |
  SET GLOBAL disconnect_on_expired_password = OFF
;

acl_password:
  '' | _char(8) | _char(16) | _char(32) | _char(40)
;

acl_password_hash:
  { "'*" . join ('', map { (0..9,'A'..'F')[$prng->int(0,15)] } (1..40) ) . "'" }
;

acl_authentication_plugin:
  ed25519 | gssapi | pam | unix_socket | named_pipe
;

acl_authentication_string:
  acl_password | _char(16)
;

acl_require:
  | | | REQUIRE __none_x_ssl_x_x509 | REQUIRE acl_tls_option_list
;

acl_tls_option_list:
  acl_tls_option | acl_tls_option AND acl_tls_option_list
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
