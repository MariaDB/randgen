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
  { %created_users = (); %full_user_names = (); '' } ;; create_user ;

query:
  user_ddl_query |
  set_session_auth_query /* compatibility 12.0 */
;

set_session_auth_query:
  ==FACTOR:20== full_stack |
  SET SESSION AUTHORIZATION username_for_set_session |
  grant_revoke_set_user;

full_stack:
  CREATE OR REPLACE USER full_user_name[invariant] ;; GRANT SET USER, CREATE USER ON *.* TO full_user_name[invariant] WITH GRANT OPTION ;; SET SESSION AUTHORIZATION full_user_name[invariant] ;

username_for_set_session:
  existing_full_name | root@localhost | rqg@localhost ;

grant_revoke_set_user:
  ==FACTOR:5== GRANT SET USER ON *.* TO username __with_grant_option(50) |
  REVOKE SET USER ON *.* FROM username ;
;

user_ddl_query:
                 drop_user
  | ==FACTOR:5== create_user
  | ==FACTOR:4== alter_user
;

drop_user:
    DROP USER __if_exists(90) existing_user_list;

existing_user_list:
    existing_user | existing_user, existing_user_list;

existing_user:
    { $user = $prng->arrayElement([ keys %created_users ]); $user = 'non_existing_user' if $user =~ /^\s*$/; delete $full_user_names{$user}; delete $created_users{$user}; $user };

existing_full_name:
    { $user = $prng->arrayElement([ keys %full_user_names ]); $user = 'non_existing_user@localhost' if $user =~ /^\s*$/; delete $full_user_names{$user}; delete $created_users{$user}; $user };

alter_user:
    ALTER USER __if_exists(90) existing_user_definition;

create_user:
    CREATE USER __if_not_exists(90) new_user_definition;

new_user_definition:
    new_user_specification_list
    require
    with
    password_or_lock_option
;

existing_user_definition:
    existing_user_specification_list
    require
    with
    password_or_lock_option
;

require:
    | REQUIRE tls_option;

tls_option:
    NONE | SSL | X509 | ssl_option_list;

ssl_option_list:
    ssl_option | ssl_option AND ssl_option_list;

# TODO: values for CIPHER, ISSUER, SUBJECT
ssl_option:
      CIPHER 'cipher'
    | ISSUER 'issuer'
    | SUBJECT 'subject'
;

with:
     | WITH resource_option_list;

resource_option_list:
    resource_option max_value_big_or_small | resource_option max_value_big_or_small resource_option_list;

resource_option:
      MAX_QUERIES_PER_HOUR
    | MAX_UPDATES_PER_HOUR
    | MAX_CONNECTIONS_PER_HOUR
    | MAX_USER_CONNECTIONS
    | MAX_STATEMENT_TIME
;

max_value_big_or_small:
# MDEV-11181 - values greater than 2147483647 don't work
#  _digit | _int_unsigned
  _digit | _mediumint_unsigned ;

new_user_specification_list:
    new_user_specification | new_user_specification, new_user_specification_list;

existing_user_specification_list:
    existing_user_specification | existing_user_specification, existing_user_specification_list;

new_user_specification:
    new_user_name auth_option;

existing_user_specification:
    existing_user auth_option;

auth_option:
      IDENTIFIED BY password
    | IDENTIFIED BY PASSWORD password_hash
    | IDENTIFIED WITH auth_plugin
# Not supported (MDEV-11180 closed as "Won't fix")
#    | IDENTIFIED WITH auth_plugin BY password
    | IDENTIFIED WITH auth_plugin AS password_hash
;

auth_plugin:
    'auth_0x0100' | 'pam' | 'auth_socket' | 'auth_test_plugin' | 'test_plugin_server' | 'cleartext_plugin_server' | 'two_questions' | 'three_attempts' | 'qa_auth_interface' | 'qa_auth_server';

password:
    '' | _char(1) | _char(8) | _char(16) | _char(41);

password_hash:
    '' | { "'*". join('', map{ chr($prng->uint16(97, 122)) } (1..40) ) ."'" };

new_user_name:
      short_user_name { $full_name= $user; $created_users{$full_name} = 1; '' }
    | full_user_name { $full_name= $user.'@'.$host; $full_user_names{$full_name}= 1; $created_users{$full_name} = 1; '' }
;

short_user_name:
      { $user = "'%'" }
    | ==FACTOR:9== random_user
;

host_name:
      { $host = "'%'" }
    | ==FACTOR:9== random_host
;

full_user_name:
    short_user_name@host_name;

random_user:
    { $len=$prng->arrayElement([0,1,8,16,80]); $user = "'".join('', map{ chr($prng->uint16(97, 122)) } (1..$len))."'" };

random_host:
    { $len=$prng->arrayElement([0,1,8,16,60]); $host = "'".join('', map{ chr($prng->uint16(97, 122)) } (1..$len))."'" };

# Not implemented in 10.2
password_or_lock_option:
    |
#    password_option | lock_option
;

password_option:
      PASSWORD EXPIRE
    | PASSWORD EXPIRE DEFAULT
    | PASSWORD EXPIRE NEVER
    | PASSWORD EXPIRE INTERVAL N DAY
;

lock_option:
      ACCOUNT LOCK
    | ACCOUNT UNLOCK
;
