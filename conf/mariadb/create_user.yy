#  Copyright (c) 2016, 2022, MariaDB
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; version 2 of the License.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA */

##########################################
# MDEV-7978 (CREATE/ALTER USER as in 5.7)
##########################################

query_init:
  { %created_users = (); '' };

query:
  mdev7978;

mdev7978:
                 mdev7978_drop_user
  | ==FACTOR:5== mdev7978_create_user
  | ==FACTOR:4== mdev7978_alter_user
;

mdev7978_drop_user:
    DROP USER mdev7978_if_exists mdev7978_existing_user_list;

mdev7978_existing_user_list:
    mdev7978_existing_user | mdev7978_existing_user, mdev7978_existing_user_list;

mdev7978_existing_user:
    { $user = $prng->arrayElement([ keys %created_users ]); $user = 'non_existing_user' if $user =~ /^\s*$/; delete $created_users{$user}; $user };

mdev7978_alter_user:
    ALTER USER mdev7978_existing_user_definition;

mdev7978_create_user:
    CREATE USER mdev7978_if_not_exists mdev7978_new_user_definition;

mdev7978_new_user_definition:
    mdev7978_new_user_specification_list
    mdev7978_require
    mdev7978_with
    mdev7978_password_or_lock_option
;

mdev7978_existing_user_definition:
    mdev7978_existing_user_specification_list
    mdev7978_require
    mdev7978_with
    mdev7978_password_or_lock_option
;

mdev7978_require:
    | REQUIRE mdev7978_tls_option;

mdev7978_tls_option:
    NONE | SSL | X509 | mdev7978_ssl_option_list;

mdev7978_ssl_option_list:
    mdev7978_ssl_option | mdev7978_ssl_option AND mdev7978_ssl_option_list;

# TODO: values for CIPHER, ISSUER, SUBJECT
mdev7978_ssl_option:
      CIPHER 'cipher'
    | ISSUER 'issuer'
    | SUBJECT 'subject'
;

mdev7978_with:
     | WITH mdev7978_resource_option_list;

mdev7978_resource_option_list:
    mdev7978_resource_option | mdev7978_resource_option mdev7978_resource_option_list;

mdev7978_resource_option:
      MAX_QUERIES_PER_HOUR _int_unsigned
    | MAX_UPDATES_PER_HOUR _int_unsigned
    | MAX_CONNECTIONS_PER_HOUR _int_unsigned
# MDEV-11181 - values greater than 2147483647 don't work
#    | MAX_USER_CONNECTIONS _int_unsigned
    | MAX_USER_CONNECTIONS _mediumint_unsigned
;

mdev7978_new_user_specification_list:
    mdev7978_new_user_specification | mdev7978_new_user_specification, mdev7978_new_user_specification_list;

mdev7978_existing_user_specification_list:
    mdev7978_existing_user_specification | mdev7978_existing_user_specification, mdev7978_existing_user_specification_list;

mdev7978_new_user_specification:
    mdev7978_new_user_name mdev7978_auth_option;

mdev7978_existing_user_specification:
    mdev7978_existing_user mdev7978_auth_option;

mdev7978_auth_option:
      IDENTIFIED BY mdev7978_password
    | IDENTIFIED BY PASSWORD mdev7978_password_hash
    | IDENTIFIED WITH mdev7978_auth_plugin
# Not supported (MDEV-11180 closed as "Won't fix")
#    | IDENTIFIED WITH mdev7978_auth_plugin BY mdev7978_password
    | IDENTIFIED WITH mdev7978_auth_plugin AS mdev7978_password_hash
;

mdev7978_auth_plugin:
    'auth_0x0100' | 'pam' | 'auth_socket' | 'auth_test_plugin' | 'test_plugin_server' | 'cleartext_plugin_server' | 'two_questions' | 'three_attempts' | 'qa_auth_interface' | 'qa_auth_server' | 'simple_password_check' | 'cracklib_password_check';

mdev7978_password:
    '' | _char(1) | _char(8) | _char(16) | _char(41);

mdev7978_password_hash:
    '' | { "'*". join('', map{ chr($prng->uint16(97, 122)) } (1..40) ) ."'" };

mdev7978_new_user_name:
      mdev7978_short_user_name { $created_users{$user} = 1; '' }
    | mdev7978_full_user_name { $created_users{$user.'@'.$host} = 1; '' }
;

mdev7978_short_user_name:
      { $user = "'%'" }
    | mdev7978_random_user
    | mdev7978_random_user
    | mdev7978_random_user
    | mdev7978_random_user
    | mdev7978_random_user
    | mdev7978_random_user
    | mdev7978_random_user
;

mdev7978_host_name:
      { $host = "'%'" }
    | mdev7978_random_host
    | mdev7978_random_host
    | mdev7978_random_host
    | mdev7978_random_host
    | mdev7978_random_host
    | mdev7978_random_host
    | mdev7978_random_host
;

mdev7978_full_user_name:
    mdev7978_short_user_name@mdev7978_host_name;

mdev7978_random_user:
    { $len=$prng->arrayElement([0,1,8,16,80]); $user = "'".join('', map{ chr($prng->uint16(97, 122)) } (1..$len))."'" };

mdev7978_random_host:
    { $len=$prng->arrayElement([0,1,8,16,60]); $host = "'".join('', map{ chr($prng->uint16(97, 122)) } (1..$len))."'" };

mdev7978_if_not_exists:
    | IF NOT EXISTS | IF NOT EXISTS | IF NOT EXISTS | IF NOT EXISTS;

mdev7978_if_exists:
    | IF EXISTS | IF EXISTS | IF EXISTS | IF EXISTS;

# Not implemented in 10.2
mdev7978_password_or_lock_option:
    |
#    mdev7978_password_option | mdev7978_lock_option
;

mdev7978_password_option:
      PASSWORD EXPIRE
    | PASSWORD EXPIRE DEFAULT
    | PASSWORD EXPIRE NEVER
    | PASSWORD EXPIRE INTERVAL N DAY
;

mdev7978_lock_option:
      ACCOUNT LOCK
    | ACCOUNT UNLOCK
;
