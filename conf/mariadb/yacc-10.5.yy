# Always limit the duration of queries, who knows what we'll generate
query_init:
    SET @@global.max_statement_time= 20, @@session.max_statement_time= 20
;

# 10.5 bb24fa31fa28d68ed4e38ecbd8d49773d22c96df

query:
        directly_executable_statement
          opt_end_of_input
        | directly_executable_statement
        ;

opt_end_of_input:
        ;

directly_executable_statement:
          statement
        | statement | statement | statement | statement | statement
        | statement | statement | statement | statement | statement
        | statement | statement | statement | statement | statement
        | statement | statement | statement | statement | statement
        | statement | statement | statement | statement | statement
        | statement | statement | statement | statement | statement
        | statement | statement | statement | statement | statement
        | begin_stmt_mariadb
        | compound_statement
        ;

verb_clause:
          alter
        | analyze
        | analyze_stmt_command
        | backup
        | binlog_base64_event
        | call
        | change
        | check
        | checksum
        | commit
        | create
        | deallocate
        | delete
        | describe
        | do
        | drop
        | execute
        | flush
        | get_diagnostics
        | grant
        | handler
        | help
        | insert
        | install
# This is something for the compiler only
#        | keep_gcc_happy
        | keycache
        | kill
        | load
        | lock
        | optimize
# TODO ES: "Prevent the end user from invoking this command" ?
#        | parse_vcol_expr
        | partition_entry
        | preload
        | prepare
        | purge
        | raise_stmt_oracle
        | release
        | rename
        | repair
        | replace
        | reset
        | resignal_stmt
        | revoke
        | rollback
        | savepoint
        | select
        | select_into
        | set
        | signal_stmt
        | show
        | shutdown
        | slave
        | start
        | truncate
        | uninstall
        | unlock
        | update
        | use
        | xa
        ;

deallocate:
          deallocate_or_drop PREPARE ident
        ;

deallocate_or_drop:
          DEALLOCATE
        | DROP
        ;

prepare:
          PREPARE ident FROM
          expr
        ;

execute:
          EXECUTE ident execute_using
        | EXECUTE IMMEDIATE
          expr
          execute_using
        ;

execute_using:
          
        | USING
          execute_params
        ;

execute_params:
          expr_or_default
        | execute_params , expr_or_default
        ;


help:
          HELP
          ident_or_text
        ;

change:
          CHANGE MASTER optional_connection_name TO
          master_defs
        ;

master_defs:
          master_def
        | master_def | master_def | master_def | master_def | master_def
        | master_def | master_def | master_def | master_def | master_def
        | master_def | master_def | master_def | master_def | master_def
        | master_defs , master_def
        ;

master_def:
          MASTER_HOST = TEXT_STRING_sys
        | MASTER_USER = TEXT_STRING_sys
        | MASTER_PASSWORD = TEXT_STRING_sys
        | MASTER_PORT = ulong_num
        | MASTER_CONNECT_RETRY = ulong_num
        | MASTER_DELAY = ulong_num
        | MASTER_SSL = ulong_num
        | MASTER_SSL_CA = TEXT_STRING_sys
        | MASTER_SSL_CAPATH = TEXT_STRING_sys
        | MASTER_SSL_CERT = TEXT_STRING_sys
        | MASTER_SSL_CIPHER = TEXT_STRING_sys
        | MASTER_SSL_KEY = TEXT_STRING_sys
        | MASTER_SSL_VERIFY_SERVER_CERT = ulong_num
        | MASTER_SSL_CRL = TEXT_STRING_sys
        | MASTER_SSL_CRLPATH = TEXT_STRING_sys
        | MASTER_HEARTBEAT_PERIOD = NUM_literal
        | IGNORE_SERVER_IDS = ( ignore_server_id_list )
        | DO_DOMAIN_IDS = ( do_domain_id_list )
        | IGNORE_DOMAIN_IDS = ( ignore_domain_id_list )
        |
        master_file_def
        ;

ignore_server_id_list:
          
          | ignore_server_id
          | ignore_server_id | ignore_server_id | ignore_server_id
          | ignore_server_id | ignore_server_id | ignore_server_id
          | ignore_server_id_list , ignore_server_id
        ;

ignore_server_id:
          ulong_num
          ;

do_domain_id_list:
          
          | do_domain_id
          | do_domain_id | do_domain_id | do_domain_id | do_domain_id
          | do_domain_id | do_domain_id | do_domain_id | do_domain_id
          | do_domain_id_list , do_domain_id
        ;

do_domain_id:
          ulong_num
          ;

ignore_domain_id_list:
          
          | ignore_domain_id
          | ignore_domain_id_list , ignore_domain_id
        ;

ignore_domain_id:
          ulong_num
          ;

master_file_def:
          MASTER_LOG_FILE = TEXT_STRING_sys
        | MASTER_LOG_POS = ulonglong_num
        | RELAY_LOG_FILE = TEXT_STRING_sys
        | RELAY_LOG_POS = ulong_num
        | MASTER_USE_GTID = CURRENT_POS
        | MASTER_USE_GTID = SLAVE_POS
        | MASTER_USE_GTID = NO
        ;

optional_connection_name:
          
        | connection_name
        ;

connection_name:
        TEXT_STRING_sys
         ;

# create a table

create:
          create_or_replace opt_temporary TABLE opt_if_not_exists
          table_ident
          create_body
        | create_or_replace opt_temporary SEQUENCE opt_if_not_exists table_ident
         opt_sequence opt_create_table_options
        | create_or_replace opt_unique INDEX_sym opt_if_not_exists
          ident
          opt_key_algorithm_clause
          ON table_ident
          ( key_list ) opt_lock_wait_timeout normal_key_options
          opt_index_lock_algorithm
        | create_or_replace fulltext INDEX_sym
          opt_if_not_exists ident
          ON table_ident
          ( key_list ) opt_lock_wait_timeout fulltext_key_options
          opt_index_lock_algorithm
        | create_or_replace spatial INDEX_sym
          opt_if_not_exists ident
          ON table_ident
          ( key_list ) opt_lock_wait_timeout spatial_key_options
          opt_index_lock_algorithm
        | create_or_replace DATABASE opt_if_not_exists ident
          opt_create_database_options
        | create_or_replace definer_opt opt_view_suid VIEW_sym
          opt_if_not_exists table_ident
          view_list_opt AS view_select
        | create_or_replace view_algorithm definer_opt opt_view_suid VIEW_sym
          opt_if_not_exists table_ident
          view_list_opt AS view_select
        | create_or_replace definer_opt TRIGGER_sym
          trigger_tail
        | create_or_replace definer_opt EVENT_sym
          event_tail
        | create_or_replace USER_sym opt_if_not_exists clear_privileges
          grant_list opt_require_clause opt_resource_options opt_account_locking opt_password_expiration
        | create_or_replace ROLE_sym opt_if_not_exists
          clear_privileges role_list opt_with_admin
        | CREATE LOGFILE_sym GROUP_sym logfile_group_info 
        | CREATE TABLESPACE tablespace_info
        | create_or_replace
          server_def
        | create_routine
        ;

opt_sequence:
         
        | sequence_defs
        ;

sequence_defs:
          sequence_def
        | sequence_defs sequence_def
        ;

sequence_def:
        MINVALUE_sym opt_equal longlong_num
        | NO_sym MINVALUE_sym
        | NOMINVALUE_sym
        | MAXVALUE_sym opt_equal longlong_num
        | NO_sym MAXVALUE_sym
        | NOMAXVALUE_sym
        | START_sym opt_with longlong_num
        | INCREMENT_sym opt_by longlong_num
        | CACHE_sym opt_equal longlong_num
        | NOCACHE_sym
        | CYCLE_sym
        | NOCYCLE_sym
        | RESTART_sym
        | RESTART_sym opt_with longlong_num
        ;

server_def:
          SERVER_sym opt_if_not_exists ident_or_text
          FOREIGN DATA_sym WRAPPER_sym ident_or_text
          OPTIONS_sym ( server_options_list )
        ;

server_options_list:
          server_option
        | server_options_list , server_option
        ;

server_option:
          USER_sym TEXT_STRING_sys
        | HOST_sym TEXT_STRING_sys
        | DATABASE TEXT_STRING_sys
        | OWNER_sym TEXT_STRING_sys
        | PASSWORD_sym TEXT_STRING_sys
        | SOCKET_sym TEXT_STRING_sys
        | PORT_sym ulong_num
        ;

event_tail:
          remember_name opt_if_not_exists sp_name
          ON SCHEDULE_sym ev_schedule_time
          opt_ev_on_completion
          opt_ev_status
          opt_ev_comment
          DO_sym ev_sql_stmt
        ;

ev_schedule_time:
          EVERY_sym expr interval
          ev_starts
          ev_ends
        | AT_sym expr
        ;

opt_ev_status:
         
        | ENABLE_sym
        | DISABLE_sym ON SLAVE
        | DISABLE_sym
        ;

ev_starts:
          
        | STARTS_sym expr
        ;

ev_ends:
        
        | ENDS_sym expr
        ;

opt_ev_on_completion:
        
        | ev_on_completion
        ;

ev_on_completion:
          ON COMPLETION_sym opt_not PRESERVE_sym
        ;

opt_ev_comment:
        
        | COMMENT_sym TEXT_STRING_sys
        ;

ev_sql_stmt:
          sp_proc_stmt
        ;

clear_privileges:

        ;

opt_aggregate:
        
        | AGGREGATE_sym
        ;

# Redefined in *-redefine-oracle.yy
sp_handler:
          FUNCTION_sym
        | PROCEDURE_sym
#        | PACKAGE_ORACLE_sym
#        | PACKAGE_ORACLE_sym BODY_ORACLE_sym
        ;

sp_name:
          ident . ident
        | ident
        ;

sp_a_chistics:
        
        | sp_a_chistics sp_chistic
        ;

sp_c_chistics:
        
        | sp_c_chistics sp_c_chistic
        ;

sp_chistic:
          COMMENT_sym TEXT_STRING_sys
        | LANGUAGE_sym SQL_sym
        | NO_sym SQL_sym
        | CONTAINS_sym SQL_sym
        | READS_sym SQL_sym DATA_sym
        | MODIFIES_sym SQL_sym DATA_sym
        | sp_suid
        ;

# Create characteristics
sp_c_chistic:
          sp_chistic
        | opt_not DETERMINISTIC_sym
        ;

sp_suid:
          SQL_sym SECURITY_sym DEFINER_sym
        | SQL_sym SECURITY_sym INVOKER_sym
        ;

call:
          CALL_sym sp_name
          opt_sp_cparam_list
        ;

# CALL parameters
opt_sp_cparam_list:
        
        | ( opt_sp_cparams )
        ;

opt_sp_cparams:
        
        | sp_cparams
        ;

sp_cparams:
          sp_cparams , expr
        | expr
        ;

# Stored FUNCTION parameter declaration list
sp_fdparam_list:
          
        |
          sp_fdparams
        ;

sp_fdparams:
          sp_fdparams , sp_param_name_and_type
        | sp_param_name_and_type
        ;

sp_param_name:
          ident
        ;

sp_param_name_and_type:
          sp_param_name type_with_opt_collate
        | sp_param_name ROW_sym row_type_body
        | sp_param_name_and_type_anchored
        ;

# Stored PROCEDURE parameter declaration list
sp_pdparam_list:
        
        | sp_pdparams
        ;

sp_pdparams:
          sp_pdparams , sp_pdparam
        | sp_pdparam
        ;

sp_parameter_type:
          IN_sym
        | OUT_sym
        | INOUT_sym
        ;

sp_parenthesized_pdparam_list:
          (
          sp_pdparam_list
          )
        ;

sp_parenthesized_fdparam_list:
        ( sp_fdparam_list )
        ;

sp_proc_stmts:
        
        | sp_proc_stmts  sp_proc_stmt { ';' }
        ;

sp_proc_stmts1:
          sp_proc_stmt { ';' }
        | sp_proc_stmts1  sp_proc_stmt { ';' }
        ;


optionally_qualified_column_ident:
          sp_decl_ident
        | sp_decl_ident . ident
        | sp_decl_ident . ident . ident
        ;


row_field_definition:
          row_field_name type_with_opt_collate
        ;

row_field_definition_list:
          row_field_definition
        | row_field_definition_list , row_field_definition
        ;

row_type_body:
          ( row_field_definition_list )
        ;

sp_decl_idents_init_vars:
          sp_decl_idents
        ;

sp_decl_variable_list:
          sp_decl_idents_init_vars
          type_with_opt_collate
          sp_opt_default
        | sp_decl_idents_init_vars
          ROW_sym row_type_body
          sp_opt_default
        | sp_decl_variable_list_anchored
        ;

sp_decl_handler:
          sp_handler_type HANDLER_sym FOR_sym
          sp_hcond_list sp_proc_stmt
        ;

opt_parenthesized_cursor_formal_parameters:
         
        | ( sp_fdparams )
        ;


sp_cursor_stmt_lex:
        ;

sp_cursor_stmt:
          sp_cursor_stmt_lex
          select
        ;

sp_handler_type:
          EXIT_MARIADB_sym
        | CONTINUE_MARIADB_sym
        | EXIT_ORACLE_sym
        | CONTINUE_ORACLE_sym
        ;

sp_hcond_list:
          sp_hcond_element
        | sp_hcond_list , sp_hcond_element
        ;

sp_hcond_element:
          sp_hcond
        ;

sp_cond:
          ulong_num
        | sqlstate
        ;

sqlstate:
          SQLSTATE_sym opt_value TEXT_STRING_literal
        ;

opt_value:
        
        | VALUE_sym
        ;

sp_hcond:
          sp_cond
        | ident
        | SQLWARNING_sym
        | not FOUND_sym
        | SQLEXCEPTION_sym
        | OTHERS_ORACLE_sym
        ;


raise_stmt_oracle:
          RAISE_ORACLE_sym opt_set_signal_information
        | RAISE_ORACLE_sym signal_value opt_set_signal_information
        ;

signal_stmt:
          SIGNAL_sym signal_value opt_set_signal_information
        ;

signal_value:
          ident
        | sqlstate
        ;

opt_signal_value:
        
        | signal_value
        ;

opt_set_signal_information:

        | SET signal_information_item_list
        ;

signal_information_item_list:
          signal_condition_information_item_name = signal_allowed_expr
        | signal_information_item_list ,
          signal_condition_information_item_name = signal_allowed_expr
        ;

#  Only a limited subset of <expr> are allowed in SIGNAL/RESIGNAL.

signal_allowed_expr:
          literal
        | variable
        | simple_ident
        ;

# conditions that can be set in signal / resignal
signal_condition_information_item_name:
          CLASS_ORIGIN_sym
        | SUBCLASS_ORIGIN_sym
        | CONSTRAINT_CATALOG_sym
        | CONSTRAINT_SCHEMA_sym
        | CONSTRAINT_NAME_sym
        | CATALOG_NAME_sym
        | SCHEMA_NAME_sym
        | TABLE_NAME_sym
        | COLUMN_NAME_sym
        | CURSOR_NAME_sym
        | MESSAGE_TEXT_sym
        | MYSQL_ERRNO_sym
        ;

resignal_stmt:
          RESIGNAL_sym opt_signal_value opt_set_signal_information
        ;

get_diagnostics:
          GET_sym which_area DIAGNOSTICS_sym diagnostics_information
        ;

which_area:

        | CURRENT_sym
        ;

diagnostics_information:
          statement_information
        | CONDITION_sym condition_number condition_information
        ;

statement_information:
          statement_information_item
        | statement_information , statement_information_item
        ;

statement_information_item:
          simple_target_specification = statement_information_item_name
        ;

simple_target_specification:
          ident_cli
        | @ident_or_text
        ;

statement_information_item_name:
          NUMBER_MARIADB_sym
        | NUMBER_ORACLE_sym
        | ROW_COUNT_sym
        ;

#   Only a limited subset of <expr> are allowed in GET DIAGNOSTICS
#   <condition number>, same subset as for SIGNAL/RESIGNAL.

condition_number:
          signal_allowed_expr
        ;

condition_information:
          condition_information_item
        | condition_information , condition_information_item
        ;

condition_information_item:
          simple_target_specification = condition_information_item_name
        ;

condition_information_item_name:
          CLASS_ORIGIN_sym
        | SUBCLASS_ORIGIN_sym
        | CONSTRAINT_CATALOG_sym
        | CONSTRAINT_SCHEMA_sym
        | CONSTRAINT_NAME_sym
        | CATALOG_NAME_sym
        | SCHEMA_NAME_sym
        | TABLE_NAME_sym
        | COLUMN_NAME_sym
        | CURSOR_NAME_sym
        | MESSAGE_TEXT_sym
        | MYSQL_ERRNO_sym
        | RETURNED_SQLSTATE_sym
        ;

sp_decl_ident:
          IDENT_sys
        | keyword_sp_decl
        ;

sp_decl_idents:
          sp_decl_ident
        | sp_decl_idents , ident
        ;

sp_proc_stmt_if:
          IF_sym
          sp_if END IF_sym
        ;

sp_proc_stmt_statement:
          sp_statement
        ;


RETURN_ALLMODES_sym:
          RETURN_MARIADB_sym
        | RETURN_ORACLE_sym
        ;

sp_proc_stmt_return:
          RETURN_ALLMODES_sym expr_lex
        | RETURN_ORACLE_sym
        ;

sp_proc_stmt_exit_oracle:
          EXIT_ORACLE_sym
        | EXIT_ORACLE_sym label_ident
        | EXIT_ORACLE_sym WHEN_sym expr_lex
        | EXIT_ORACLE_sym label_ident WHEN_sym expr_lex
        ;

sp_proc_stmt_continue_oracle:
          CONTINUE_ORACLE_sym
        | CONTINUE_ORACLE_sym label_ident
        | CONTINUE_ORACLE_sym WHEN_sym expr_lex
        | CONTINUE_ORACLE_sym label_ident WHEN_sym expr_lex
        ;


sp_proc_stmt_leave:
          LEAVE_sym label_ident
        ;

sp_proc_stmt_iterate:
          ITERATE_sym label_ident
        ;

sp_proc_stmt_goto_oracle:
          GOTO_ORACLE_sym label_ident
        ;


expr_lex:
          expr
        ;


assignment_source_lex:
        ;

assignment_source_expr:
          assignment_source_lex
          expr
        ;

for_loop_bound_expr:
          assignment_source_lex
          expr
        ;

cursor_actual_parameters:
          assignment_source_expr
        | cursor_actual_parameters , assignment_source_expr
        ;

opt_parenthesized_cursor_actual_parameters:

        | ( cursor_actual_parameters )
        ;

sp_proc_stmt_with_cursor:
         sp_proc_stmt_open
       | sp_proc_stmt_fetch
       | sp_proc_stmt_close
       ;

sp_proc_stmt_open:
          OPEN_sym ident opt_parenthesized_cursor_actual_parameters
        ;

sp_proc_stmt_fetch_head:
          FETCH_sym ident INTO
       | FETCH_sym FROM ident INTO
       | FETCH_sym NEXT_sym FROM ident INTO
        ;

sp_proc_stmt_fetch:
         sp_proc_stmt_fetch_head sp_fetch_list
       | FETCH_sym GROUP_sym NEXT_sym ROW_sym
        ;

sp_proc_stmt_close:
          CLOSE_sym ident
        ;

sp_fetch_list:
          ident
        | sp_fetch_list , ident
        ;

sp_if:
          expr_lex THEN_sym
          sp_if_then_statements
          sp_elseifs
        ;

sp_elseifs:

        | ELSEIF_MARIADB_sym sp_if
        | ELSIF_ORACLE_sym sp_if
        | ELSE sp_if_then_statements
        ;

case_stmt_specification:
          CASE_sym
          case_stmt_body
          else_clause_opt
          END
          CASE_sym
        ;

case_stmt_body:
          expr_lex
          simple_when_clause_list
        | searched_when_clause_list
        ;

simple_when_clause_list:
          simple_when_clause
        | simple_when_clause_list simple_when_clause
        ;

searched_when_clause_list:
          searched_when_clause
        | searched_when_clause_list searched_when_clause
        ;

simple_when_clause:
          WHEN_sym expr_lex
          THEN_sym
          sp_case_then_statements
        ;

searched_when_clause:
          WHEN_sym expr_lex
          THEN_sym
          sp_case_then_statements
        ;

else_clause_opt:

        | ELSE sp_case_then_statements
        ;

sp_opt_label:

        | label_ident
        ;

# This adds one shift/reduce conflict
opt_sp_for_loop_direction:

          | REVERSE_sym
        ;

sp_for_loop_index_and_bounds:
          ident_for_loop_index sp_for_loop_bounds
        ;

sp_for_loop_bounds:
          IN_sym opt_sp_for_loop_direction for_loop_bound_expr
          DOT_DOT_sym for_loop_bound_expr
        | IN_sym opt_sp_for_loop_direction for_loop_bound_expr
        | IN_sym opt_sp_for_loop_direction ( sp_cursor_stmt )
        ;

loop_body:
          sp_proc_stmts1 END LOOP_sym
        ;

repeat_body:
          sp_proc_stmts1 UNTIL_sym expr_lex END REPEAT_sym
        ;

pop_sp_loop_label:
          sp_opt_label
        ;

sp_labeled_control:
          sp_control_label LOOP_sym
          loop_body pop_sp_loop_label
        | sp_control_label WHILE_sym
          while_body pop_sp_loop_label
        | sp_control_label FOR_sym
          sp_for_loop_index_and_bounds
          for_loop_statements
          pop_sp_loop_label
        | sp_control_label REPEAT_sym
          repeat_body pop_sp_loop_label
        ;

sp_unlabeled_control:
          LOOP_sym
          loop_body
        | WHILE_sym
          while_body
        | FOR_sym
          sp_for_loop_index_and_bounds
          for_loop_statements
        | REPEAT_sym
          repeat_body
        ;

trg_action_time:
            BEFORE_sym
          | AFTER_sym
          ;

trg_event:
            INSERT
          | UPDATE_sym
          | DELETE_sym
          ;

#  This part of the parser contains common code for all TABLESPACE
#  commands.
#  CREATE TABLESPACE name ...
#  ALTER TABLESPACE name CHANGE DATAFILE ...
#  ALTER TABLESPACE name ADD DATAFILE ...
#  ALTER TABLESPACE name access_mode
#  CREATE LOGFILE GROUP_sym name ...
#  ALTER LOGFILE GROUP_sym name ADD UNDOFILE ..
#  ALTER LOGFILE GROUP_sym name ADD REDOFILE ..
#  DROP TABLESPACE name
#  DROP LOGFILE GROUP_sym name

change_tablespace_access:
          tablespace_name
          ts_access_mode
        ;

change_tablespace_info:
          tablespace_name
          CHANGE ts_datafile
          change_ts_option_list
        ;

tablespace_info:
          tablespace_name
          ADD ts_datafile
          opt_logfile_group_name
          tablespace_option_list
        ;

opt_logfile_group_name:

        | USE_sym LOGFILE_sym GROUP_sym ident
        ;

alter_tablespace_info:
          tablespace_name
          ADD ts_datafile
          alter_tablespace_option_list
        | tablespace_name
          DROP ts_datafile
          alter_tablespace_option_list
        ;

logfile_group_info:
          logfile_group_name
          add_log_file
          logfile_group_option_list
        ;

alter_logfile_group_info:
          logfile_group_name
          add_log_file
          alter_logfile_group_option_list
        ;

add_log_file:
          ADD lg_undofile
        | ADD lg_redofile
        ;

change_ts_option_list:
          change_ts_options
        ;

change_ts_options:
          change_ts_option
        | change_ts_options change_ts_option
        | change_ts_options , change_ts_option
        ;

change_ts_option:
          opt_ts_initial_size
        | opt_ts_autoextend_size
        | opt_ts_max_size
        ;

tablespace_option_list:
        tablespace_options
        ;

tablespace_options:
          tablespace_option
        | tablespace_options tablespace_option
        | tablespace_options , tablespace_option
        ;

tablespace_option:
          opt_ts_initial_size
        | opt_ts_autoextend_size
        | opt_ts_max_size
        | opt_ts_extent_size
        | opt_ts_nodegroup
        | opt_ts_engine
        | ts_wait
        | opt_ts_comment
        ;

alter_tablespace_option_list:
        alter_tablespace_options
        ;

alter_tablespace_options:
          alter_tablespace_option
        | alter_tablespace_options alter_tablespace_option
        | alter_tablespace_options , alter_tablespace_option
        ;

alter_tablespace_option:
          opt_ts_initial_size
        | opt_ts_autoextend_size
        | opt_ts_max_size
        | opt_ts_engine
        | ts_wait
        ;

logfile_group_option_list:
        logfile_group_options
        ;

logfile_group_options:
          logfile_group_option
        | logfile_group_options logfile_group_option
        | logfile_group_options , logfile_group_option
        ;

logfile_group_option:
          opt_ts_initial_size
        | opt_ts_undo_buffer_size
        | opt_ts_redo_buffer_size
        | opt_ts_nodegroup
        | opt_ts_engine
        | ts_wait
        | opt_ts_comment
        ;

alter_logfile_group_option_list:
          alter_logfile_group_options
        ;

alter_logfile_group_options:
          alter_logfile_group_option
        | alter_logfile_group_options alter_logfile_group_option
        | alter_logfile_group_options , alter_logfile_group_option
        ;

alter_logfile_group_option:
          opt_ts_initial_size
        | opt_ts_engine
        | ts_wait
        ;


ts_datafile:
          DATAFILE_sym TEXT_STRING_sys
        ;

lg_undofile:
          UNDOFILE_sym TEXT_STRING_sys
        ;

lg_redofile:
          REDOFILE_sym TEXT_STRING_sys
        ;

tablespace_name:
          ident
        ;

logfile_group_name:
          ident
        ;

ts_access_mode:
          READ_ONLY_sym
        | READ_WRITE_sym
        | NOT_sym ACCESSIBLE_sym
        ;

opt_ts_initial_size:
          INITIAL_SIZE_sym opt_equal size_number
        ;

opt_ts_autoextend_size:
          AUTOEXTEND_SIZE_sym opt_equal size_number
        ;

opt_ts_max_size:
          MAX_SIZE_sym opt_equal size_number
        ;

opt_ts_extent_size:
          EXTENT_SIZE_sym opt_equal size_number
        ;

opt_ts_undo_buffer_size:
          UNDO_BUFFER_SIZE_sym opt_equal size_number
        ;

opt_ts_redo_buffer_size:
          REDO_BUFFER_SIZE_sym opt_equal size_number
        ;

opt_ts_nodegroup:
          NODEGROUP_sym opt_equal real_ulong_num
        ;

opt_ts_comment:
          COMMENT_sym opt_equal TEXT_STRING_sys
        ;

opt_ts_engine:
          opt_storage ENGINE_sym opt_equal storage_engines
        ;

opt_ts_wait:

        | ts_wait
        ;

ts_wait:
          WAIT_sym
        | NO_WAIT_sym
        ;

size_number:
          real_ulonglong_num
        | IDENT_sys
        ;


#  End tablespace part

create_body:
          create_field_list_parens
          opt_create_table_options opt_create_partitioning opt_create_select
        | opt_create_table_options opt_create_partitioning opt_create_select
        | create_like
        ;

create_like:
          LIKE table_ident
        | LEFT_PAREN_LIKE LIKE table_ident )
        ;

opt_create_select:

        | opt_duplicate opt_as create_select_query_expression opt_versioning_option
        ;

create_select_query_expression:
          query_expression
        | LEFT_PAREN_WITH with_clause query_expression_no_with_clause )
        ;

opt_create_partitioning:
          opt_partitioning
        ;


# This part of the parser is about handling of the partition information.
#
# Its first version was written by Mikael Ronström with lots of answers to
# questions provided by Antony Curtis.
#
# The partition grammar can be called from three places.
# 1) CREATE TABLE ... PARTITION ..
# 2) ALTER TABLE table_name PARTITION ...
# 3) PARTITION ...
#
# The first place is called when a new table is created from a MySQL client.
# The second place is called when a table is altered with the ALTER TABLE
# command from a MySQL client.
# The third place is called when opening an frm file and finding partition
# info in the .frm file. It is necessary to avoid allowing PARTITION to be
# an allowed entry point for SQL client queries. This is arranged by setting
# some state variables before arriving here.
#
# To be able to handle errors we will only set error code in this code
# and handle the error condition in the function calling the parser. This
# is necessary to ensure we can also handle errors when calling the parser
# from the openfrm function.

opt_partitioning:

        | partitioning
        ;

partitioning:
          PARTITION_sym have_partitioning
          partition
        ;

have_partitioning:

        ;

partition_entry:
          PARTITION_sym
          partition
        ;

partition:
          BY
          part_type_def opt_num_parts opt_sub_part part_defs
        ;

part_type_def:
          opt_linear KEY_sym opt_key_algo ( part_field_list )
        | opt_linear HASH_sym
          part_func
        | RANGE_sym part_func
        | RANGE_sym part_column_list
        | LIST_sym 
          part_func
        | LIST_sym part_column_list
        | SYSTEM_TIME_sym
          opt_versioning_rotation
        ;

opt_linear:

        | LINEAR_sym
        ;

opt_key_algo:

        | ALGORITHM_sym = real_ulong_num
        ;

part_field_list:

        | part_field_item_list
        ;

part_field_item_list:
          part_field_item
        | part_field_item_list , part_field_item
        ;

part_field_item:
          ident
        ;

part_column_list:
          COLUMNS ( part_field_list )
        ;


part_func:
          ( part_func_expr )
        ;

sub_part_func:
          ( part_func_expr )
        ;


opt_num_parts:

        | PARTITIONS_sym real_ulong_num
        ;

opt_sub_part:

        | SUBPARTITION_sym BY opt_linear HASH_sym sub_part_func
          opt_num_subparts
        | SUBPARTITION_sym BY opt_linear KEY_sym opt_key_algo
          ( sub_part_field_list )
          opt_num_subparts
        ;

sub_part_field_list:
          sub_part_field_item
        | sub_part_field_list , sub_part_field_item
        ;

sub_part_field_item:
          ident
        ;

part_func_expr:
          bit_expr
        ;

opt_num_subparts:

        | SUBPARTITIONS_sym real_ulong_num
        ;

part_defs:

        | ( part_def_list )
        ;

part_def_list:
          part_definition
        | part_def_list , part_definition
        ;

part_definition:
          PARTITION_sym
          part_name
          opt_part_values
          opt_part_options
          opt_sub_partition
         
        ;

part_name:
          ident
        ;

opt_part_values:

        | VALUES_LESS_sym THAN_sym
          part_func_max
        | VALUES_IN_sym
          part_values_in
        | CURRENT_sym
        | HISTORY_sym
        | DEFAULT
        ;

part_func_max:
          MAXVALUE_sym
        | part_value_item
        ;

part_values_in:
          part_value_item
        | ( part_value_list )
        ;

part_value_list:
          part_value_item
        | part_value_list , part_value_item
        ;

part_value_item:
          (
          part_value_item_list
          )
        ;

part_value_item_list:
          part_value_expr_item
        | part_value_item_list , part_value_expr_item
        ;

part_value_expr_item:
          MAXVALUE_sym
        | bit_expr
        ;


opt_sub_partition:

        | ( sub_part_list )
        ;

sub_part_list:
          sub_part_definition
        | sub_part_list , sub_part_definition
        ;

sub_part_definition:
          SUBPARTITION_sym
          sub_name opt_part_options
        ;

sub_name:
          ident_or_text
        ;

opt_part_options:

       | opt_part_option_list
       ;

opt_part_option_list:
         opt_part_option_list opt_part_option
       | opt_part_option
       ;

opt_part_option:
          TABLESPACE opt_equal ident_or_text
        | opt_storage ENGINE_sym opt_equal storage_engines
        | CONNECTION_sym opt_equal TEXT_STRING_sys
        | NODEGROUP_sym opt_equal real_ulong_num
        | MAX_ROWS opt_equal real_ulonglong_num
        | MIN_ROWS opt_equal real_ulonglong_num
        | DATA_sym DIRECTORY_sym opt_equal TEXT_STRING_sys
        | INDEX_sym DIRECTORY_sym opt_equal TEXT_STRING_sys
        | COMMENT_sym opt_equal TEXT_STRING_sys
        ;

opt_versioning_rotation:

       | INTERVAL_sym expr interval opt_versioning_interval_start
       | LIMIT ulonglong_num
       ;


opt_versioning_interval_start:

       | STARTS_sym literal
       ;


# End of partition parser part

opt_as:

        | AS
        ;

opt_create_database_options:

        | create_database_options
        ;

create_database_options:
          create_database_option
        | create_database_options create_database_option
        ;

create_database_option:
          default_collation
        | default_charset
        | COMMENT_sym opt_equal TEXT_STRING_sys
        ;

opt_if_not_exists_table_element:

        | IF_sym not EXISTS
         ;

opt_if_not_exists:

        | IF_sym not EXISTS
         ;

create_or_replace:
          CREATE
        | CREATE OR_sym REPLACE
         ;

opt_create_table_options:

        | create_table_options
        ;

create_table_options_space_separated:
          create_table_option
        | create_table_option create_table_options_space_separated
        ;

create_table_options:
          create_table_option
        | create_table_option     create_table_options
        | create_table_option , create_table_options
        ;

create_table_option:
          ENGINE_sym opt_equal ident_or_text
        | MAX_ROWS opt_equal ulonglong_num
        | MIN_ROWS opt_equal ulonglong_num
        | AVG_ROW_LENGTH opt_equal ulong_num
        | PASSWORD_sym opt_equal TEXT_STRING_sys
        | COMMENT_sym opt_equal TEXT_STRING_sys
        | AUTO_INC opt_equal ulonglong_num
        | PACK_KEYS_sym opt_equal ulong_num
        | PACK_KEYS_sym opt_equal DEFAULT
        | STATS_AUTO_RECALC_sym opt_equal ulong_num
        | STATS_AUTO_RECALC_sym opt_equal DEFAULT
        | STATS_PERSISTENT_sym opt_equal ulong_num
        | STATS_PERSISTENT_sym opt_equal DEFAULT
        | STATS_SAMPLE_PAGES_sym opt_equal ulong_num
        | STATS_SAMPLE_PAGES_sym opt_equal DEFAULT
        | CHECKSUM_sym opt_equal ulong_num
        | TABLE_CHECKSUM_sym opt_equal ulong_num
        | PAGE_CHECKSUM_sym opt_equal choice
        | DELAY_KEY_WRITE_sym opt_equal ulong_num
        | ROW_FORMAT_sym opt_equal row_types
        | UNION_sym opt_equal
          ( opt_table_list )
        | default_charset
        | default_collation
        | INSERT_METHOD opt_equal merge_insert_types
        | DATA_sym DIRECTORY_sym opt_equal TEXT_STRING_sys
        | INDEX_sym DIRECTORY_sym opt_equal TEXT_STRING_sys
        | TABLESPACE ident
        | STORAGE_sym DISK_sym
        | STORAGE_sym MEMORY_sym
        | CONNECTION_sym opt_equal TEXT_STRING_sys
        | KEY_BLOCK_SIZE opt_equal ulong_num
        | TRANSACTIONAL_sym opt_equal choice
        | IDENT_sys equal TEXT_STRING_sys
        | IDENT_sys equal ident
        | IDENT_sys equal real_ulonglong_num
        | IDENT_sys equal DEFAULT
        | SEQUENCE_sym opt_equal choice
        | versioning_option
        ;

opt_versioning_option:

        | versioning_option
        ;

versioning_option:
        WITH_SYSTEM_sym VERSIONING_sym
        ;

default_charset:
          opt_default charset opt_equal charset_name_or_default
        ;

default_collation:
          opt_default COLLATE_sym opt_equal collation_name_or_default
        ;

storage_engines:
          ident_or_text
        ;

known_storage_engines:
          ident_or_text
        ;

row_types:
          DEFAULT
        | FIXED_sym
        | DYNAMIC_sym
        | COMPRESSED_sym
        | REDUNDANT_sym
        | COMPACT_sym
        | PAGE_sym
        ;

merge_insert_types:
         NO_sym
       | FIRST_sym
       | LAST_sym
       ;

udf_type:
          STRING_sym
        | REAL
        | DECIMAL_sym
        | INT_sym
        ;


create_field_list:
        field_list
        ;

create_field_list_parens:
        LEFT_PAREN_ALT field_list )
        ;

field_list:
          field_list_item
        | field_list , field_list_item
        ;

field_list_item:
          column_def
        | key_def
        | constraint_def
        | period_for_system_time
        | PERIOD_sym period_for_application_time
        ;

column_def:
          field_spec
        | field_spec opt_constraint references
        ;

key_def:
          key_or_index opt_if_not_exists opt_ident opt_USING_key_algorithm
          ( key_list ) normal_key_options
        | key_or_index opt_if_not_exists ident TYPE_sym btree_or_rtree
          ( key_list ) normal_key_options
        | fulltext opt_key_or_index opt_if_not_exists opt_ident
          ( key_list ) fulltext_key_options
        | spatial opt_key_or_index opt_if_not_exists opt_ident
          ( key_list ) spatial_key_options
        | opt_constraint constraint_key_type
          opt_if_not_exists opt_ident
          opt_USING_key_algorithm
          ( key_list ) normal_key_options
        | opt_constraint constraint_key_type opt_if_not_exists ident
          TYPE_sym btree_or_rtree
          ( key_list ) normal_key_options
        | opt_constraint FOREIGN KEY_sym opt_if_not_exists opt_ident
          ( key_list ) references
        ;

constraint_def:
         opt_constraint check_constraint
       ;

period_for_system_time:
          PERIOD_sym FOR_SYSTEM_TIME_sym ( ident , ident )
        ;

period_for_application_time:
          FOR_sym ident ( ident , ident )
        ;

opt_check_constraint:

        | check_constraint
        ;

check_constraint:
          CHECK_sym ( expr )
        ;

opt_constraint_no_id:

        | CONSTRAINT  
        ;

opt_constraint:

        | constraint
        ;

constraint:
          CONSTRAINT opt_ident
        ;

field_spec:
          field_ident
          field_type_or_serial opt_check_constraint
        ;

field_type_or_serial:
          field_type
          field_def
        | SERIAL_sym
          opt_serial_attribute
        ;

opt_serial_attribute:

        | opt_serial_attribute_list
        ;

opt_serial_attribute_list:
          opt_serial_attribute_list serial_attribute
        | serial_attribute
        ;

opt_asrow_attribute:

        | opt_asrow_attribute_list
        ;

opt_asrow_attribute_list:
          opt_asrow_attribute_list asrow_attribute
        | asrow_attribute
        ;

field_def:

        | attribute_list
        | attribute_list compressed_deprecated_column_attribute
        | attribute_list compressed_deprecated_column_attribute attribute_list
        | opt_generated_always AS virtual_column_func
          vcol_opt_specifier vcol_opt_attribute
        | opt_generated_always AS ROW_sym START_sym opt_asrow_attribute
        | opt_generated_always AS ROW_sym END opt_asrow_attribute
        ;

opt_generated_always:

        | GENERATED_sym ALWAYS_sym
        ;

vcol_opt_specifier:

        | VIRTUAL_sym
        | PERSISTENT_sym
        | STORED_sym
        ;

vcol_opt_attribute:

        | vcol_opt_attribute_list
        ;

vcol_opt_attribute_list:
          vcol_opt_attribute_list vcol_attribute
        | vcol_attribute
        ;

vcol_attribute:
          UNIQUE_sym
        | UNIQUE_sym KEY_sym
        | COMMENT_sym TEXT_STRING_sys
        | INVISIBLE_sym
        ;

parse_vcol_expr:
          PARSE_VCOL_EXPR_sym
          expr
        ;

parenthesized_expr:
          expr
        | expr , expr_list
        ;

virtual_column_func:
          ( parenthesized_expr )
        | subquery
        ;

expr_or_literal:
          column_default_non_parenthesized_expr
        | signed_literal
        ;

column_default_expr:
          virtual_column_func
        | expr_or_literal
        ;

field_type:
          field_type_numeric
        | field_type_temporal
        | field_type_string
        | field_type_lob
        | field_type_misc
        | IDENT_sys float_options srid_option
        | reserved_keyword_udt float_options srid_option
        | non_reserved_keyword_udt float_options srid_option
        ;

field_type_numeric:
          int_type opt_field_length last_field_options
        | real_type opt_precision last_field_options
        | FLOAT_sym float_options last_field_options
        | BIT_sym opt_field_length
        | BOOL_sym
        | BOOLEAN_sym
        | DECIMAL_sym float_options last_field_options
        | NUMBER_ORACLE_sym float_options last_field_options
        | NUMERIC_sym float_options last_field_options
        | FIXED_sym float_options last_field_options
        ;


opt_binary_and_compression:

        | binary
        | binary compressed_deprecated_data_type_attribute
        | compressed opt_binary
        ;

field_type_string:
          char opt_field_length opt_binary
        | nchar opt_field_length opt_bin_mod
        | BINARY opt_field_length
        | varchar opt_field_length opt_binary_and_compression
        | VARCHAR2_ORACLE_sym opt_field_length opt_binary_and_compression
        | nvarchar opt_field_length opt_compressed opt_bin_mod
        | VARBINARY opt_field_length opt_compressed
        | RAW_ORACLE_sym opt_field_length opt_compressed
        ;

field_type_temporal:
          YEAR_sym opt_field_length last_field_options
        | DATE_sym
        | TIME_sym opt_field_length
        | TIMESTAMP opt_field_length
        | DATETIME opt_field_length
        ;


field_type_lob:
          TINYBLOB opt_compressed
        | BLOB_MARIADB_sym opt_field_length opt_compressed
        | BLOB_ORACLE_sym field_length opt_compressed
        | BLOB_ORACLE_sym opt_compressed
        | MEDIUMBLOB opt_compressed
        | LONGBLOB opt_compressed
        | LONG_sym VARBINARY opt_compressed
        | LONG_sym varchar opt_binary_and_compression
        | TINYTEXT opt_binary_and_compression
        | TEXT_sym opt_field_length opt_binary_and_compression
        | MEDIUMTEXT opt_binary_and_compression
        | LONGTEXT opt_binary_and_compression
        | CLOB_ORACLE_sym opt_binary_and_compression
        | LONG_sym opt_binary_and_compression
        | JSON_sym opt_compressed
        ;

field_type_misc:
          ENUM ( string_list ) opt_binary
        | SET ( string_list ) opt_binary
        ;

char:
          CHAR_sym
        ;

nchar:
          NCHAR_sym
        | NATIONAL_sym CHAR_sym
        ;

varchar:
          char VARYING
        | VARCHAR
        ;

nvarchar:
          NATIONAL_sym VARCHAR
        | NVARCHAR_sym
        | NCHAR_sym VARCHAR
        | NATIONAL_sym CHAR_sym VARYING
        | NCHAR_sym VARYING
        ;

int_type:
          INT_sym
        | TINYINT
        | SMALLINT
        | MEDIUMINT
        | BIGINT
        ;

real_type:
          REAL
        | DOUBLE_sym
        | DOUBLE_sym PRECISION
        ;

srid_option:

        |
          REF_SYSTEM_ID_sym = NUM
        ;

float_options:

        | field_length
        | precision
        ;

# It should really be unsigned, there must be some magic in it
precision:
#          ( NUM , NUM )
          ( NUM_unsigned , NUM_unsigned )
        ;

field_options:

        | SIGNED_sym
        | UNSIGNED
        | ZEROFILL
        | UNSIGNED ZEROFILL
        | ZEROFILL UNSIGNED
        ;

last_field_options:
          field_options
        ;

field_length:
          ( LONG_NUM )
        | ( ULONGLONG_NUM )
        | ( DECIMAL_NUM )
        | ( NUM )
        ;

opt_field_length:

        | field_length
        ;

opt_precision:

        | precision
        ;


attribute_list:
          attribute_list attribute
        | attribute
        ;

attribute:
          NULL_sym
        | DEFAULT column_default_expr
        | ON UPDATE_sym NOW_sym opt_default_time_precision
        | AUTO_INC
        | SERIAL_sym DEFAULT VALUE_sym
        | COLLATE_sym collation_name
        | serial_attribute
        ;

opt_compression_method:

        | equal ident
        ;

opt_compressed:

        | compressed
        ;

compressed:
          COMPRESSED_sym opt_compression_method
        ;

compressed_deprecated_data_type_attribute:
          COMPRESSED_sym opt_compression_method
        ;

compressed_deprecated_column_attribute:
          COMPRESSED_sym opt_compression_method
        ;

asrow_attribute:
          not NULL_sym
        | opt_primary KEY_sym
        | vcol_attribute
        ;

serial_attribute:
          asrow_attribute
        | IDENT_sys equal TEXT_STRING_sys
        | IDENT_sys equal ident
        | IDENT_sys equal real_ulonglong_num
        | IDENT_sys equal DEFAULT
        | with_or_without_system VERSIONING_sym
        ;

with_or_without_system:
        WITH_SYSTEM_sym
        | WITHOUT SYSTEM
        ;


type_with_opt_collate:
        field_type opt_collate
        ;

charset:
          CHAR_sym SET
        | CHARSET
        ;

charset_name:
          ident_or_text
        | BINARY
        ;

charset_name_or_default:
          charset_name
        | DEFAULT
        ;

opt_load_data_charset:

        | charset charset_name_or_default
        ;

old_or_new_charset_name:
          ident_or_text
        | BINARY
        ;

old_or_new_charset_name_or_default:
          old_or_new_charset_name
        | DEFAULT
        ;

collation_name:
          ident_or_text
        ;

opt_collate:

        | COLLATE_sym collation_name_or_default
        ;

collation_name_or_default:
          collation_name
        | DEFAULT
        ;

opt_default:

        | DEFAULT
        ;

charset_or_alias:
          charset charset_name
        | ASCII_sym
        | UNICODE_sym
        ;

opt_binary:

        | binary
        ;

binary:
          BYTE_sym
        | charset_or_alias opt_bin_mod
        | BINARY
        | BINARY charset_or_alias
        ;

opt_bin_mod:

        | BINARY
        ;

ws_nweights:
        ( real_ulong_num
        )
        ;

ws_level_flag_desc:
        ASC
        | DESC
        ;

ws_level_flag_reverse:
        REVERSE_sym
        ;

ws_level_flags:

        | ws_level_flag_desc
        | ws_level_flag_desc ws_level_flag_reverse
        | ws_level_flag_reverse
        ;

ws_level_number:
        real_ulong_num
        ;

ws_level_list_item:
        ws_level_number ws_level_flags
        ;

ws_level_list:
        ws_level_list_item
        | ws_level_list , ws_level_list_item
        ;

ws_level_range:
        ws_level_number - ws_level_number
        ;

ws_level_list_or_range:
        ws_level_list
        | ws_level_range
        ;

opt_ws_levels:

        | LEVEL_sym ws_level_list_or_range
        ;

opt_primary:

        | PRIMARY_sym
        ;

references:
          REFERENCES
          table_ident
          opt_ref_list
          opt_match_clause
          opt_on_update_delete
        ;

opt_ref_list:

        | ( ref_list )
        ;

ref_list:
          ref_list , ident
        | ident
        ;

opt_match_clause:

        | MATCH FULL
        | MATCH PARTIAL
        | MATCH SIMPLE_sym
        ;

opt_on_update_delete:

        | ON UPDATE_sym delete_option
        | ON DELETE_sym delete_option
        | ON UPDATE_sym delete_option
          ON DELETE_sym delete_option
        | ON DELETE_sym delete_option
          ON UPDATE_sym delete_option
        ;

delete_option:
          RESTRICT
        | CASCADE
        | SET NULL_sym
        | NO_sym ACTION
        | SET DEFAULT
        ;

constraint_key_type:
          PRIMARY_sym KEY_sym
        | UNIQUE_sym opt_key_or_index
        ;

key_or_index:
          KEY_sym
        | INDEX_sym
        ;

opt_key_or_index:

        | key_or_index
        ;

keys_or_index:
          KEYS
        | INDEX_sym
        | INDEXES
        ;

opt_unique:

        | UNIQUE_sym
        ;

fulltext:
          FULLTEXT_sym
        ;

spatial:
          SPATIAL_sym
        ;

normal_key_options:

        | normal_key_opts
        ;

fulltext_key_options:

        | fulltext_key_opts
        ;

spatial_key_options:

        | spatial_key_opts
        ;

normal_key_opts:
          normal_key_opt
        | normal_key_opts normal_key_opt
        ;

spatial_key_opts:
          spatial_key_opt
        | spatial_key_opts spatial_key_opt
        ;

fulltext_key_opts:
          fulltext_key_opt
        | fulltext_key_opts fulltext_key_opt
        ;

opt_USING_key_algorithm:

        | USING    btree_or_rtree
        ;

# TYPE is a valid identifier, so it's handled differently than USING
opt_key_algorithm_clause:

        | USING    btree_or_rtree
        | TYPE_sym btree_or_rtree
        ;

key_using_alg:
          USING btree_or_rtree
        | TYPE_sym btree_or_rtree
        ;

all_key_opt:
          KEY_BLOCK_SIZE opt_equal ulong_num
        | COMMENT_sym TEXT_STRING_sys
        | IDENT_sys equal TEXT_STRING_sys
        | IDENT_sys equal ident
        | IDENT_sys equal real_ulonglong_num
        | IDENT_sys equal DEFAULT
        ;

normal_key_opt:
          all_key_opt
        | key_using_alg
        ;

spatial_key_opt:
          all_key_opt
        ;

fulltext_key_opt:
          all_key_opt
        | WITH PARSER_sym IDENT_sys
        ;

btree_or_rtree:
          BTREE_sym
        | RTREE_sym
        | HASH_sym
        ;

key_list:
          key_list , key_part order_dir
        | key_part order_dir
        | key_part order_dir | key_part order_dir | key_part order_dir
        | key_part order_dir | key_part order_dir | key_part order_dir
        | key_part order_dir | key_part order_dir | key_part order_dir
        ;

key_part:
          ident
# It is made uint by internal magic
#        | ident ( NUM )
        | ident ( _int_unsigned )
        ;

opt_ident:

        | field_ident
        ;

string_list:
          text_string
        | string_list , text_string
        ;

# Alter table

alter:
          ALTER
          alter_options TABLE_sym table_ident opt_lock_wait_timeout
          alter_commands
        | ALTER DATABASE ident_or_empty
          create_database_options
        | ALTER DATABASE COMMENT_sym opt_equal TEXT_STRING_sys
          opt_create_database_options
        | ALTER DATABASE ident UPGRADE_sym DATA_sym DIRECTORY_sym NAME_sym
        | ALTER PROCEDURE_sym sp_name
          sp_a_chistics
          stmt_end
        | ALTER FUNCTION_sym sp_name
          sp_a_chistics
          stmt_end
        | ALTER view_algorithm definer_opt opt_view_suid VIEW_sym table_ident
          view_list_opt AS view_select stmt_end
        | ALTER definer_opt opt_view_suid VIEW_sym table_ident
          view_list_opt AS view_select stmt_end
        | ALTER definer_opt remember_name EVENT_sym sp_name
          ev_alter_on_schedule_completion
          opt_ev_rename_to
          opt_ev_status
          opt_ev_comment
          opt_ev_sql_stmt
        | ALTER TABLESPACE alter_tablespace_info
        | ALTER LOGFILE_sym GROUP_sym alter_logfile_group_info
        | ALTER TABLESPACE change_tablespace_info
        | ALTER TABLESPACE change_tablespace_access
        | ALTER SERVER_sym ident_or_text
          OPTIONS_sym ( server_options_list )
        | ALTER USER_sym opt_if_exists clear_privileges grant_list
          opt_require_clause opt_resource_options opt_account_locking opt_password_expiration
        | ALTER SEQUENCE_sym opt_if_exists
          table_ident
          sequence_defs
          stmt_end
        ;

opt_account_locking:

        | ACCOUNT_sym LOCK_sym
        | ACCOUNT_sym UNLOCK_sym
        ;

opt_password_expiration:

        | PASSWORD_sym EXPIRE_sym
        | PASSWORD_sym EXPIRE_sym NEVER_sym
        | PASSWORD_sym EXPIRE_sym DEFAULT
        | PASSWORD_sym EXPIRE_sym INTERVAL_sym NUM DAY_sym
        ;

ev_alter_on_schedule_completion:

        | ON SCHEDULE_sym ev_schedule_time
        | ev_on_completion
        | ON SCHEDULE_sym ev_schedule_time ev_on_completion
        ;

opt_ev_rename_to:

        | RENAME TO_sym sp_name
        ;

opt_ev_sql_stmt:

        | DO_sym ev_sql_stmt
        ;

ident_or_empty:

        | ident
        ;

alter_commands:

        | DISCARD TABLESPACE
        | IMPORT TABLESPACE
        | alter_list
          opt_partitioning
        | alter_list
          remove_partitioning
        | remove_partitioning
        | partitioning

#  This part was added for release 5.1 by Mikael Ronstrm.
#  From here we insert a number of commands to manage the partitions of a
#  partitioned table such as adding partitions, dropping partitions,
#  reorganising partitions in various manners. In future releases the list
#  will be longer.

        | add_partition_rule
        | DROP PARTITION_sym opt_if_exists alt_part_name_list
        | REBUILD_sym PARTITION_sym opt_no_write_to_binlog
          all_or_alt_part_name_list
        | OPTIMIZE PARTITION_sym opt_no_write_to_binlog
          all_or_alt_part_name_list
          opt_no_write_to_binlog
        | ANALYZE_sym PARTITION_sym opt_no_write_to_binlog
          all_or_alt_part_name_list
        | CHECK_sym PARTITION_sym all_or_alt_part_name_list
          opt_mi_check_type
        | REPAIR PARTITION_sym opt_no_write_to_binlog
          all_or_alt_part_name_list
          opt_mi_repair_type
        | COALESCE PARTITION_sym opt_no_write_to_binlog real_ulong_num
        | TRUNCATE_sym PARTITION_sym all_or_alt_part_name_list
        | reorg_partition_rule
        | EXCHANGE_sym PARTITION_sym alt_part_name_item
          WITH TABLE_sym table_ident have_partitioning
        ;

remove_partitioning:
          REMOVE_sym PARTITIONING_sym
        ;

all_or_alt_part_name_list:
          ALL
        | alt_part_name_list
        ;

add_partition_rule:
          ADD PARTITION_sym opt_if_not_exists
          opt_no_write_to_binlog
          add_part_extra
        ;

add_part_extra:

        | ( part_def_list )
        | PARTITIONS_sym real_ulong_num
        ;

reorg_partition_rule:
          REORGANIZE_sym PARTITION_sym opt_no_write_to_binlog
          reorg_parts_rule
        ;

reorg_parts_rule:

        | alt_part_name_list
          INTO ( part_def_list )
        ;

alt_part_name_list:
          alt_part_name_item
        | alt_part_name_list , alt_part_name_item
        ;

alt_part_name_item:
          ident
        ;


#  End of management of partition commands

alter_list:
          alter_list_item
        | alter_list , alter_list_item
        ;

add_column:
          ADD opt_column opt_if_not_exists_table_element
        ;

alter_list_item:
          add_column column_def opt_place
        | ADD key_def
        | ADD period_for_system_time
        | ADD
          PERIOD_sym opt_if_not_exists_table_element period_for_application_time
        | add_column ( create_field_list )
        | ADD constraint_def
        | ADD CONSTRAINT IF_sym not EXISTS field_ident check_constraint
        | CHANGE opt_column opt_if_exists_table_element field_ident
          field_spec opt_place
        | MODIFY_sym opt_column opt_if_exists_table_element
          field_spec opt_place
        | DROP opt_column opt_if_exists_table_element field_ident opt_restrict
        | DROP CONSTRAINT opt_if_exists_table_element field_ident
        | DROP FOREIGN KEY_sym opt_if_exists_table_element field_ident
        | DROP opt_constraint_no_id PRIMARY_sym KEY_sym
        | DROP key_or_index opt_if_exists_table_element field_ident
        | DISABLE_sym KEYS
        | ENABLE_sym KEYS
        | ALTER opt_column opt_if_exists_table_element field_ident SET DEFAULT column_default_expr
        | ALTER opt_column opt_if_exists_table_element field_ident DROP DEFAULT
        | RENAME opt_to table_ident
        | RENAME COLUMN_sym ident TO_sym ident
        | RENAME key_or_index field_ident TO_sym field_ident
        | CONVERT_sym TO_sym charset charset_name_or_default opt_collate
        | create_table_options_space_separated
        | FORCE_sym
        | alter_order_clause
        | alter_algorithm_option
        | alter_lock_option
        | ADD SYSTEM VERSIONING_sym
        | DROP SYSTEM VERSIONING_sym
        | DROP PERIOD_sym FOR_SYSTEM_TIME_sym
        | DROP PERIOD_sym opt_if_exists_table_element FOR_sym ident
        ;

opt_index_lock_algorithm:

        | alter_lock_option
        | alter_algorithm_option
        | alter_lock_option alter_algorithm_option
        | alter_algorithm_option alter_lock_option
        ;

alter_algorithm_option:
          ALGORITHM_sym opt_equal DEFAULT
        | ALGORITHM_sym opt_equal ident
        ;

alter_lock_option:
          LOCK_sym opt_equal DEFAULT
        | LOCK_sym opt_equal ident
        ;

opt_column:

        | COLUMN_sym
        ;

opt_ignore:

        | IGNORE_sym
        ;

alter_options:
          alter_options_part2
        ;

alter_options_part2:

        | alter_option_list
        ;

alter_option_list:
          alter_option_list alter_option
        | alter_option
        ;

alter_option:
          IGNORE_sym
        | ONLINE_sym
        ;

opt_restrict:

        | RESTRICT
        | CASCADE
        ;

opt_place:

        | AFTER_sym ident
        | FIRST_sym
        ;

opt_to:

        | TO_sym
        | =
        | AS
        ;

slave:
          START_sym SLAVE optional_connection_name slave_thread_opts
          slave_until
        | START_sym ALL SLAVES slave_thread_opts
        | STOP_sym SLAVE optional_connection_name slave_thread_opts
        | STOP_sym ALL SLAVES slave_thread_opts
        ;

start:
          START_sym TRANSACTION_sym opt_start_transaction_option_list
        ;

opt_start_transaction_option_list:

        | start_transaction_option_list
        ;

start_transaction_option_list:
          start_transaction_option
        | start_transaction_option_list , start_transaction_option
        ;

start_transaction_option:
          WITH CONSISTENT_sym SNAPSHOT_sym
        | READ_sym ONLY_sym
        | READ_sym WRITE_sym
        ;

slave_thread_opts:
          slave_thread_opt_list
        ;

slave_thread_opt_list:
          slave_thread_opt
        | slave_thread_opt_list , slave_thread_opt
        ;

slave_thread_opt:

        | SQL_THREAD
        | RELAY_THREAD
        ;

slave_until:

        | UNTIL_sym slave_until_opts
        | UNTIL_sym MASTER_GTID_POS_sym = TEXT_STRING_sys
        ;

slave_until_opts:
          master_file_def
        | slave_until_opts , master_file_def
        ;

checksum:
          CHECKSUM_sym table_or_tables
          table_list opt_checksum_type
        ;

opt_checksum_type:

        | QUICK
        | EXTENDED_sym
        ;

repair_table_or_view:
          table_or_tables table_list opt_mi_repair_type
        | VIEW_sym
          table_list opt_view_repair_type
        ;

repair:
          REPAIR opt_no_write_to_binlog
          repair_table_or_view
        ;

opt_mi_repair_type:

        | mi_repair_types
        ;

mi_repair_types:
          mi_repair_type
        | mi_repair_type mi_repair_types
        ;

mi_repair_type:
          QUICK
        | EXTENDED_sym
        | USE_FRM
        ;

opt_view_repair_type:

        | FROM MYSQL_sym
        ;

analyze:
          ANALYZE_sym opt_no_write_to_binlog table_or_tables
          analyze_table_list
        ;

analyze_table_list:
          analyze_table_elem_spec
        | analyze_table_list , analyze_table_elem_spec
        ;

analyze_table_elem_spec:
          table_name opt_persistent_stat_clause
        ;

opt_persistent_stat_clause:

        | PERSISTENT_sym FOR_sym persistent_stat_spec  
        ;

persistent_stat_spec:
          ALL
        | COLUMNS persistent_column_stat_spec INDEXES persistent_index_stat_spec
        ;

persistent_column_stat_spec:
          ALL
        | (
          table_column_list
          ) 
        ;
 
persistent_index_stat_spec:
          ALL
        | (
          table_index_list
          ) 
        ;

table_column_list:

        | ident 
        | table_column_list , ident
        ;

table_index_list:

        | table_index_name 
        | table_index_list , table_index_name
        ;

table_index_name:
          ident
        |
          PRIMARY_sym
        ;  

binlog_base64_event:
          BINLOG_sym TEXT_STRING_sys
          |
          BINLOG_sym@ident_or_text , @ident_or_text
          ;

check_view_or_table:
          table_or_tables table_list opt_mi_check_type
        | VIEW_sym
          table_list opt_view_check_type
        ;

check:
          CHECK_sym
          check_view_or_table
        ;

opt_mi_check_type:

        | mi_check_types
        ;

mi_check_types:
          mi_check_type
        | mi_check_type mi_check_types
        ;

mi_check_type:
          QUICK
        | FAST_sym
        | MEDIUM_sym
        | EXTENDED_sym
        | CHANGED
        | FOR_sym UPGRADE_sym
        ;

opt_view_check_type:

        | FOR_sym UPGRADE_sym
        ;

optimize:
          OPTIMIZE opt_no_write_to_binlog table_or_tables
          table_list opt_lock_wait_timeout
        ;

opt_no_write_to_binlog:

        | NO_WRITE_TO_BINLOG
        | LOCAL_sym
        ;

rename:
          RENAME table_or_tables
          table_to_table_list
        | RENAME USER_sym clear_privileges rename_list
        ;

rename_list:
          user TO_sym user
        | rename_list , user TO_sym user
        ;

table_to_table_list:
          table_to_table
        | table_to_table_list , table_to_table
        ;

table_to_table:
          table_ident opt_lock_wait_timeout TO_sym table_ident
        ;

keycache:
          CACHE_sym INDEX_sym
          keycache_list_or_parts IN_sym key_cache_name
        ;

keycache_list_or_parts:
          keycache_list
        | assign_to_keycache_parts
        ;

keycache_list:
          assign_to_keycache
        | keycache_list , assign_to_keycache
        ;

assign_to_keycache:
          table_ident cache_keys_spec
        ;

assign_to_keycache_parts:
          table_ident adm_partition cache_keys_spec
        ;

key_cache_name:
          ident
        | DEFAULT
        ;

preload:
          LOAD INDEX_sym INTO CACHE_sym
          preload_list_or_parts
        ;

preload_list_or_parts:
          preload_keys_parts
        | preload_list
        ;

preload_list:
          preload_keys
        | preload_list , preload_keys
        ;

preload_keys:
          table_ident cache_keys_spec opt_ignore_leaves
        ;

preload_keys_parts:
          table_ident adm_partition cache_keys_spec opt_ignore_leaves
        ;

adm_partition:
          PARTITION_sym have_partitioning
          ( all_or_alt_part_name_list )
        ;

cache_keys_spec:
          cache_key_list_or_empty
        ;

cache_key_list_or_empty:

        | key_or_index ( opt_key_usage_list )
        ;

opt_ignore_leaves:

        | IGNORE_sym LEAVES
        ;


#  Select : retrieve data from table

select:
          query_expression_no_with_clause
          opt_procedure_or_into
        | with_clause query_expression_no_with_clause
          opt_procedure_or_into
        ;

select_into:
          select_into_query_specification
          opt_order_limit_lock
        | with_clause
          select_into_query_specification
          opt_order_limit_lock
        ;

simple_table:
          query_specification
        | table_value_constructor
        ;

table_value_constructor:
          VALUES
        values_list
        ;

query_specification_start:
          SELECT_sym
          select_options
          select_item_list
          ;

query_specification:
          query_specification_start
          opt_from_clause
          opt_where_clause
          opt_group_clause
          opt_having_clause
          opt_window_clause
        ;

select_into_query_specification:
          query_specification_start
          into
          opt_from_clause
          opt_where_clause
          opt_group_clause
          opt_having_clause
          opt_window_clause
        ;


#  The following grammar for query expressions conformant to
#  the latest SQL Standard is supported:
#
#    <query expression> ::=
#     [ <with clause> ] <query expression body>
#       [ <order by clause> ] [ <result offset clause> ] [ <fetch first clause> ]
#
#   <with clause> ::=
#     WITH [ RECURSIVE ] <with_list
#
#   <with list> ::=
#     <with list element> [ { <comma> <with list element> }... ]
#
#   <with list element> ::=
#     <query name> [ ( <with column list> ) ]
#         AS <table subquery>
#
#   <with column list> ::=
#     <column name list>
#
#   <query expression body> ::
#       <query term>
#     | <query expression body> UNION [ ALL | DISTINCT ] <query term>
#     | <query expression body> EXCEPT [ DISTINCT ] <query term>
#
#   <query term> ::=
#       <query primary>
#     | <query term> INTERSECT [ DISTINCT ] <query primary>
#
#   <query primary> ::=
#       <simple table>
#     | ( <query expression body>
#       [ <order by clause> ] [ <result offset clause> ] [ <fetch first clause> ]
#       )
#
#   <simple table>
#       <query specification>
#     | <table value constructor>
#
#  <subquery>
#       ( <query_expression> )

#  query_expression produces the same expressions as
#      <query expression>

query_expression:
          query_expression_no_with_clause
        | with_clause
          query_expression_no_with_clause
        ;

#   query_expression_no_with_clause produces the same expressions as
#       <query expression> without [ <with clause> ]

# ES: increased the number of query_expression_body_ext
#     to avoid semi-endless recursion

query_expression_no_with_clause:
          query_expression_body_ext
        | query_expression_body_ext | query_expression_body_ext
        | query_expression_body_ext | query_expression_body_ext
        | query_expression_body_ext | query_expression_body_ext
        | query_expression_body_ext | query_expression_body_ext
        | query_expression_body_ext | query_expression_body_ext
        | query_expression_body_ext | query_expression_body_ext
        | query_expression_body_ext | query_expression_body_ext
        | query_expression_body_ext | query_expression_body_ext
        | query_expression_body_ext | query_expression_body_ext
        | query_expression_body_ext | query_expression_body_ext
        | query_expression_body_ext_parens
        ;


#  query_expression_body_ext produces the same expressions as
#      <query expression body>
#       [ <order by clause> ] [ <result offset clause> ] [ <fetch first clause> ]
#    | (... <query expression body>
#       [ <order by clause> ] [ <result offset clause> ] [ <fetch first clause> ]
#      )...
#  Note: number of ) must be equal to the number of ( in the rule above

# ES: increased the number of query_expression_body
#     to avoid semi-endless recursion

query_expression_body_ext:
          query_expression_body opt_query_expression_tail
        | query_expression_body opt_query_expression_tail
        | query_expression_body opt_query_expression_tail
        | query_expression_body opt_query_expression_tail
        | query_expression_body opt_query_expression_tail
        | query_expression_body opt_query_expression_tail
        | query_expression_body opt_query_expression_tail
        | query_expression_body opt_query_expression_tail
        | query_expression_body opt_query_expression_tail
        | query_expression_body opt_query_expression_tail
        | query_expression_body_ext_parens query_expression_tail
        ;

# ES: increased the number of query_expression_body_ext
#     to avoid semi-endless recursion

query_expression_body_ext_parens:
          ( query_expression_body_ext_parens )
        | ( query_expression_body_ext )
        | ( query_expression_body_ext )
        | ( query_expression_body_ext )
        | ( query_expression_body_ext )
        | ( query_expression_body_ext )
        | ( query_expression_body_ext )
        | ( query_expression_body_ext )
        | ( query_expression_body_ext )
        | ( query_expression_body_ext )
        | ( query_expression_body_ext )
        ;


#  query_expression_body produces the same expressions as
#      <query expression body>

# ES: increased the number of query_simple
#     to avoid semi-endless recursion

query_expression_body:
          query_simple
        | query_simple | query_simple | query_simple | query_simple
        | query_simple | query_simple | query_simple | query_simple
        | query_simple | query_simple | query_simple | query_simple
        | query_simple | query_simple | query_simple | query_simple
        | query_simple | query_simple | query_simple | query_simple
        | query_simple | query_simple | query_simple | query_simple
        | query_simple | query_simple | query_simple | query_simple
        | query_simple | query_simple | query_simple | query_simple
        | query_simple | query_simple | query_simple | query_simple
        | query_simple | query_simple | query_simple | query_simple
        | query_simple | query_simple | query_simple | query_simple
        | query_simple | query_simple | query_simple | query_simple
        | query_simple | query_simple | query_simple | query_simple
        | query_simple | query_simple | query_simple | query_simple
        | query_simple | query_simple | query_simple | query_simple
        | query_simple | query_simple | query_simple | query_simple
        | query_simple | query_simple | query_simple | query_simple
        | query_simple | query_simple | query_simple | query_simple
        | query_simple | query_simple | query_simple | query_simple
        | query_expression_body
          unit_type_decl
          query_primary
        | query_expression_body_ext_parens
          unit_type_decl
          query_primary
        ;


#  query_primary produces the same expressions as
#      <query primary>

query_primary:
          query_simple
        | query_expression_body_ext_parens
        ;

#  query_simple produces the same expressions as
#      <simple table>

query_simple:
          simple_table
        ;

subselect:
          query_expression
        ;

#  subquery produces the same expressions as
#     <subquery>
#
#  Consider the production rule of the SQL Standard
#     subquery:
#        ( query_expression )
#
#  This rule is equivalent to the rule
#     subquery:
#          ( query_expression_no_with_clause )
#        | ( with_clause query_expression_no_with_clause )
#  that in its turn is equivalent to
#     subquery:
#          ( query_expression_body_ext )
#        | query_expression_body_ext_parens
#        | ( with_clause query_expression_no_with_clause )
#
#  The latter can be re-written into
#     subquery:
#          query_expression_body_ext_parens
#        | ( with_clause query_expression_no_with_clause )
#
#  The last rule allows us to resolve properly the shift/reduce conflict
#  when subquery is used in expressions such as in the following queries
#     select (select * from t1 limit 1) + t2.a from t2
#     select * from t1 where t1.a [not] in (select t2.a from t2)
#
#  In the rule below { '%prec'; '' } SUBQUERY_AS_EXPR forces the parser to perform a shift
#  operation rather then a reduce operation when ) is encountered and can be
#  considered as the last symbol a query expression.

subquery:
          query_expression_body_ext_parens
        | ( with_clause query_expression_no_with_clause )
        ;

opt_from_clause:

        | from_clause
        ;

from_clause:
          FROM table_reference_list
        ;

table_reference_list:
          join_table_list
        | DUAL_sym
        ;

select_options:

        | select_option_list
        ;

opt_history_unit:

        | TRANSACTION_sym
        | TIMESTAMP
        ;

history_point:
          TIMESTAMP TEXT_STRING
        | TIMESTAMP TEXT_STRING | TIMESTAMP TEXT_STRING
        | TIMESTAMP TEXT_STRING | TIMESTAMP TEXT_STRING
        | TIMESTAMP TEXT_STRING | TIMESTAMP TEXT_STRING
        | TIMESTAMP TEXT_STRING | TIMESTAMP TEXT_STRING
        | TIMESTAMP TEXT_STRING | TIMESTAMP TEXT_STRING
        | TIMESTAMP TEXT_STRING | TIMESTAMP TEXT_STRING
        | TIMESTAMP TEXT_STRING | TIMESTAMP TEXT_STRING
        | function_call_keyword_timestamp
        | opt_history_unit bit_expr
        ;

for_portion_of_time_clause:
          FOR_sym PORTION_sym OF_sym remember_tok_start ident FROM
          bit_expr TO_sym bit_expr
        ;

opt_for_portion_of_time_clause:

        | for_portion_of_time_clause
        ;

opt_for_system_time_clause:

        | FOR_SYSTEM_TIME_sym system_time_expr
        ;

system_time_expr:
          AS OF_sym history_point
        | ALL
        | FROM history_point TO_sym history_point
        | BETWEEN_sym history_point AND_sym history_point
        ;

select_option_list:
          select_option_list select_option
        | select_option
        | select_option | select_option | select_option | select_option
        | select_option | select_option | select_option | select_option
        | select_option | select_option | select_option | select_option
        | select_option | select_option | select_option | select_option
        ;

select_option:
          query_expression_option
        | SQL_NO_CACHE_sym
        | SQL_CACHE_sym
        ;


select_lock_type:
          FOR_sym UPDATE_sym opt_lock_wait_timeout_new
        | LOCK_sym IN_sym SHARE_sym MODE_sym opt_lock_wait_timeout_new
        ;


opt_select_lock_type:

        | select_lock_type
        ;


opt_lock_wait_timeout_new:

        | WAIT_sym ulong_num
        | NOWAIT_sym
      ;

select_item_list:
          select_item_list , select_item
        | select_item
        | select_item | select_item | select_item | select_item
        | select_item | select_item | select_item | select_item
        | select_item | select_item | select_item | select_item
        | select_item | select_item | select_item | select_item
        | select_item | select_item | select_item | select_item
        | *
        | * | * | * | * | * | * | * | * | * | * | * | * | * | * | * | *
        ;

select_item:
          remember_name select_sublist_qualified_asterisk remember_end
        | remember_name expr remember_end select_alias
        ;

remember_tok_start:
        ;

remember_name:
        ;

remember_end:
        ;

select_alias:

        | AS ident
        | AS TEXT_STRING_sys
        | ident
        | TEXT_STRING_sys
        ;

opt_default_time_precision:

        | ( )
        | ( real_ulong_num )
        ;

opt_time_precision:

        | ( )
        | ( real_ulong_num )
        ;

optional_braces:
        | ( )
        ;

# all possible expressions

expr:
          expr OR expr
        | expr XOR expr
        | expr AND expr
        | NOT_sym expr
        | bool_pri IS TRUE_sym
        | bool_pri IS not TRUE_sym
        | bool_pri IS FALSE_sym
        | bool_pri IS not FALSE_sym
        | bool_pri IS UNKNOWN_sym
        | bool_pri IS not UNKNOWN_sym
        | bool_pri | bool_pri | bool_pri | bool_pri | bool_pri | bool_pri
        | bool_pri | bool_pri | bool_pri | bool_pri | bool_pri | bool_pri
        | bool_pri | bool_pri | bool_pri | bool_pri | bool_pri | bool_pri
        | bool_pri | bool_pri | bool_pri | bool_pri | bool_pri | bool_pri
        ;

# ES: increased the number of predicates to avoid semi-endless recursion
bool_pri:
          bool_pri IS NULL_sym
        | bool_pri IS not NULL_sym
        | bool_pri EQUAL_sym predicate
        | bool_pri comp_op predicate
        | bool_pri comp_op all_or_any ( subselect )
        | predicate
        | predicate | predicate | predicate | predicate | predicate
        | predicate | predicate | predicate | predicate | predicate
        | predicate | predicate | predicate | predicate | predicate
        | predicate | predicate | predicate | predicate | predicate
        | predicate | predicate | predicate | predicate | predicate
        | predicate | predicate | predicate | predicate | predicate
        | predicate | predicate | predicate | predicate | predicate
        | predicate | predicate | predicate | predicate | predicate
        | predicate | predicate | predicate | predicate | predicate
        | predicate | predicate | predicate | predicate | predicate
        | predicate | predicate | predicate | predicate | predicate
        | predicate | predicate | predicate | predicate | predicate
        | predicate | predicate | predicate | predicate | predicate
        | predicate | predicate | predicate | predicate | predicate
        | predicate | predicate | predicate | predicate | predicate
        ;

predicate:
          bit_expr IN_sym subquery
        | bit_expr not IN_sym subquery
        | bit_expr IN_sym ( expr )
        | bit_expr IN_sym ( expr , expr_list )
        | bit_expr not IN_sym ( expr )
        | bit_expr not IN_sym ( expr , expr_list )
        | bit_expr BETWEEN_sym bit_expr AND_sym predicate
        | bit_expr not BETWEEN_sym bit_expr AND_sym predicate
        | bit_expr SOUNDS_sym LIKE bit_expr
        | bit_expr LIKE bit_expr opt_escape
        | bit_expr not LIKE bit_expr opt_escape
        | bit_expr REGEXP bit_expr
        | bit_expr not REGEXP bit_expr
        | bit_expr | bit_expr | bit_expr | bit_expr | bit_expr | bit_expr
        | bit_expr | bit_expr | bit_expr | bit_expr | bit_expr | bit_expr
        | bit_expr | bit_expr | bit_expr | bit_expr | bit_expr | bit_expr
        | bit_expr | bit_expr | bit_expr | bit_expr | bit_expr | bit_expr
        | bit_expr | bit_expr | bit_expr | bit_expr | bit_expr | bit_expr
        | bit_expr | bit_expr | bit_expr | bit_expr | bit_expr | bit_expr
        | bit_expr | bit_expr | bit_expr | bit_expr | bit_expr | bit_expr
        ;

bit_expr:
          # pipe symbol
          bit_expr { chr(124) } bit_expr
        | bit_expr & bit_expr
        | bit_expr SHIFT_LEFT bit_expr
        | bit_expr SHIFT_RIGHT bit_expr
        | bit_expr ORACLE_CONCAT_sym bit_expr
        | bit_expr + bit_expr
        | bit_expr - bit_expr
        | bit_expr + INTERVAL_sym expr interval
        | bit_expr - INTERVAL_sym expr interval
        | INTERVAL_sym expr interval + expr
        | + INTERVAL_sym expr interval + expr
        | - INTERVAL_sym expr interval + expr
        | bit_expr * bit_expr
        | bit_expr / bit_expr
        | bit_expr % bit_expr
        | bit_expr DIV_sym bit_expr
        | bit_expr MOD_sym bit_expr
        | bit_expr ^ bit_expr
        | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        | mysql_concatenation_expr | mysql_concatenation_expr
        ;

or:
          OR_sym
       | OR2_sym
       ;

and:
          AND_sym
       | AND_AND_sym
       ;

not:
          NOT_sym
        | NOT2_sym
        ;

not2:
          !
        | NOT2_sym
        ;

comp_op:
          =
        | GE
        | >
        | LE
        | <
        | NE
        ;

all_or_any:
          ALL
        | ANY_sym
        ;

opt_dyncol_type:

        | AS dyncol_type
        ;

dyncol_type:
          numeric_dyncol_type
        | temporal_dyncol_type
        | string_dyncol_type
        ;

numeric_dyncol_type:
          INT_sym
        | UNSIGNED INT_sym
        | DOUBLE_sym
        | REAL
        | FLOAT_sym
        | DECIMAL_sym float_options
        ;

temporal_dyncol_type:
          DATE_sym
        | TIME_sym opt_field_length
        | DATETIME opt_field_length
        ;

string_dyncol_type:
          char
          opt_binary
        | nchar
        ;

dyncall_create_element:
   expr , expr opt_dyncol_type
   ;

dyncall_create_list:
     dyncall_create_element
   | dyncall_create_list , dyncall_create_element
   ;


plsql_cursor_attr:
          ISOPEN_sym
        | FOUND_sym
        | NOTFOUND_sym
        | ROWCOUNT_sym
        ;

explicit_cursor_attr:
          ident PERCENT_ORACLE_sym plsql_cursor_attr
        ;


trim_operands:
          expr
        | LEADING  expr FROM expr
        | TRAILING expr FROM expr
        | BOTH     expr FROM expr
        | LEADING       FROM expr
        | TRAILING      FROM expr
        | BOTH          FROM expr
        | expr          FROM expr
        ;

#  Expressions that the parser allows in a column DEFAULT clause
#  without parentheses. These expressions cannot end with a COLLATE clause.
#
#  If we allowed any "expr" in DEFAULT clause, there would be a confusion
#  in queries like this:
#    CREATE TABLE t1 (a TEXT DEFAULT 'a' COLLATE latin1_bin);
#  It would be not clear what COLLATE stands for:
#  - the collation of the column `a`, or
#  - the collation of the string literal 'a'
#
#  This restriction allows to parse the above query unambiguiusly:
#  COLLATE belongs to the column rather than the literal.
#  If one needs COLLATE to belong to the literal, parentheses must be used:
#    CREATE TABLE t1 (a TEXT DEFAULT ('a' COLLATE latin1_bin));
#  Note: the COLLATE clause is rather meaningless here, but the query
#  is syntactically correct.
#
#  Note, some of the expressions are not actually allowed in DEFAULT,
#  e.g. sum_expr, window_func_expr, ROW(...), VALUES().
#  We could move them to simple_expr, but that would make
#  these two queries return a different error messages:
#    CREATE TABLE t1 (a INT DEFAULT AVG(1));
#    CREATE TABLE t1 (a INT DEFAULT (AVG(1)));
#  The first query would return "syntax error".
#  Currenly both return:
#   Function or expression 'avg(' is not allowed for 'DEFAULT' ...

# ES TODO: fix brackets

column_default_non_parenthesized_expr:
          simple_ident
        | simple_ident | simple_ident | simple_ident | simple_ident
        | simple_ident | simple_ident | simple_ident | simple_ident
        | simple_ident | simple_ident | simple_ident | simple_ident
        | simple_ident | simple_ident | simple_ident | simple_ident
        | simple_ident | simple_ident | simple_ident | simple_ident
        | simple_ident | simple_ident | simple_ident | simple_ident
        | simple_ident | simple_ident | simple_ident | simple_ident
        | simple_ident | simple_ident | simple_ident | simple_ident
        | simple_ident | simple_ident | simple_ident | simple_ident
        | simple_ident | simple_ident | simple_ident | simple_ident
        | simple_ident | simple_ident | simple_ident | simple_ident
        | simple_ident | simple_ident | simple_ident | simple_ident
        | simple_ident | simple_ident | simple_ident | simple_ident
        | simple_ident | simple_ident | simple_ident | simple_ident
        | simple_ident | simple_ident | simple_ident | simple_ident
        | simple_ident | simple_ident | simple_ident | simple_ident
        | simple_ident | simple_ident | simple_ident | simple_ident
        | simple_ident | simple_ident | simple_ident | simple_ident
        | simple_ident | simple_ident | simple_ident | simple_ident
        | simple_ident | simple_ident | simple_ident | simple_ident
        | function_call_keyword
        | function_call_nonkeyword
        | function_call_generic
        | function_call_conflict
        | literal
        | literal | literal | literal | literal | literal | literal
        | literal | literal | literal | literal | literal | literal
        | literal | literal | literal | literal | literal | literal
        | literal | literal | literal | literal | literal | literal
        | literal | literal | literal | literal | literal | literal
        | literal | literal | literal | literal | literal | literal
        | literal | literal | literal | literal | literal | literal
        | literal | literal | literal | literal | literal | literal
        | literal | literal | literal | literal | literal | literal
        | literal | literal | literal | literal | literal | literal
        | param_marker
        | variable | variable | variable | variable | variable
        | variable | variable | variable | variable | variable
        | variable | variable | variable | variable | variable
        | variable | variable | variable | variable | variable
        | variable | variable | variable | variable | variable
        | variable | variable | variable | variable | variable
        | variable | variable | variable | variable | variable
        | variable | variable | variable | variable | variable
        | variable | variable | variable | variable | variable
        | variable | variable | variable | variable | variable
        | sum_expr
        | window_func_expr
        | inverse_distribution_function
        | ROW_sym ( expr , expr_list )
        | EXISTS ( subselect )
#        | { '{' } ident expr { '}' }
        | MATCH ident_list_arg AGAINST ( bit_expr fulltext_options )
        | CAST_sym ( expr AS cast_type )
        | CASE_sym when_list_opt_else END
        | CASE_sym expr when_list_opt_else END
        | CONVERT_sym ( expr , cast_type )
        | CONVERT_sym ( expr USING charset_name )
        | DEFAULT ( simple_ident )
        | VALUE_sym ( simple_ident_nospvar )
        | NEXT_sym VALUE_sym FOR_sym table_ident
        | NEXTVAL_sym ( table_ident )
        | PREVIOUS_sym VALUE_sym FOR_sym table_ident
        | LASTVAL_sym ( table_ident )
        | SETVAL_sym ( table_ident , longlong_num )
        | SETVAL_sym ( table_ident , longlong_num , bool )
        | SETVAL_sym ( table_ident , longlong_num , bool , ulonglong_num )
        ;

primary_expr:
          column_default_non_parenthesized_expr
        | column_default_non_parenthesized_expr
        | column_default_non_parenthesized_expr
        | column_default_non_parenthesized_expr
        | column_default_non_parenthesized_expr
        | column_default_non_parenthesized_expr
        | column_default_non_parenthesized_expr
        | column_default_non_parenthesized_expr
        | column_default_non_parenthesized_expr
        | column_default_non_parenthesized_expr
        | column_default_non_parenthesized_expr
        | column_default_non_parenthesized_expr
        | column_default_non_parenthesized_expr
        | column_default_non_parenthesized_expr
        | column_default_non_parenthesized_expr
        | column_default_non_parenthesized_expr
        | column_default_non_parenthesized_expr
        | column_default_non_parenthesized_expr
        | column_default_non_parenthesized_expr
        | explicit_cursor_attr | explicit_cursor_attr
        | explicit_cursor_attr | explicit_cursor_attr
        | explicit_cursor_attr | explicit_cursor_attr
        | explicit_cursor_attr | explicit_cursor_attr
        | explicit_cursor_attr | explicit_cursor_attr
        | ( parenthesized_expr )
        | subquery
        ;

string_factor_expr:
          primary_expr
        | primary_expr | primary_expr | primary_expr | primary_expr 
        | primary_expr | primary_expr | primary_expr | primary_expr 
        | primary_expr | primary_expr | primary_expr | primary_expr 
        | primary_expr | primary_expr | primary_expr | primary_expr 
        | primary_expr | primary_expr | primary_expr | primary_expr 
        | primary_expr | primary_expr | primary_expr | primary_expr 
        | primary_expr | primary_expr | primary_expr | primary_expr 
        | primary_expr | primary_expr | primary_expr | primary_expr 
        | primary_expr | primary_expr | primary_expr | primary_expr 
        | string_factor_expr COLLATE_sym collation_name
        ;

# ES: increased the number of strict_factor_expr
#     to avoid semi-endless recursion

simple_expr:
          string_factor_expr
        | string_factor_expr | string_factor_expr | string_factor_expr
        | string_factor_expr | string_factor_expr | string_factor_expr
        | string_factor_expr | string_factor_expr | string_factor_expr
        | string_factor_expr | string_factor_expr | string_factor_expr
        | string_factor_expr | string_factor_expr | string_factor_expr
        | string_factor_expr | string_factor_expr | string_factor_expr
        | string_factor_expr | string_factor_expr | string_factor_expr
        | string_factor_expr | string_factor_expr | string_factor_expr
        | string_factor_expr | string_factor_expr | string_factor_expr
        | string_factor_expr | string_factor_expr | string_factor_expr
        | string_factor_expr | string_factor_expr | string_factor_expr
        | BINARY simple_expr
        | + simple_expr
        | - simple_expr
        | ~ simple_expr
        | not2 simple_expr
        ;

mysql_concatenation_expr:
          simple_expr
        | simple_expr | simple_expr | simple_expr | simple_expr
        | simple_expr | simple_expr | simple_expr | simple_expr
        | simple_expr | simple_expr | simple_expr | simple_expr
        | simple_expr | simple_expr | simple_expr | simple_expr
        | simple_expr | simple_expr | simple_expr | simple_expr
        | simple_expr | simple_expr | simple_expr | simple_expr
        | simple_expr | simple_expr | simple_expr | simple_expr
        | simple_expr | simple_expr | simple_expr | simple_expr
        | simple_expr | simple_expr | simple_expr | simple_expr
        | simple_expr | simple_expr | simple_expr | simple_expr
        | simple_expr | simple_expr | simple_expr | simple_expr
        | simple_expr | simple_expr | simple_expr | simple_expr
        | mysql_concatenation_expr MYSQL_CONCAT_sym simple_expr
        ;

function_call_keyword_timestamp:
          TIMESTAMP ( expr )
        | TIMESTAMP ( expr ) | TIMESTAMP ( expr ) | TIMESTAMP ( expr )
        | TIMESTAMP ( expr ) | TIMESTAMP ( expr ) | TIMESTAMP ( expr )
        | TIMESTAMP ( expr , expr )
        ;

#  Function call syntax using official SQL 2003 keywords.
#  Because the function name is an official token,
#  a dedicated grammar rule is needed in the parser.
#  There is no potential for conflicts

function_call_keyword:
          CHAR_sym ( expr_list )
        | CHAR_sym ( expr_list USING charset_name )
        | CURRENT_USER optional_braces
        | CURRENT_ROLE optional_braces
        | DATE_sym ( expr )
        | DAY_sym ( expr )
        | HOUR_sym ( expr )
        | INSERT ( expr , expr , expr , expr )
        | INTERVAL_sym ( expr , expr )
        | INTERVAL_sym ( expr , expr , expr_list )
        | LEFT ( expr , expr )
        | MINUTE_sym ( expr )
        | MONTH_sym ( expr )
        | RIGHT ( expr , expr )
        | SECOND_sym ( expr )
        | SQL_sym PERCENT_ORACLE_sym ROWCOUNT_sym
        | TIME_sym ( expr )
        | function_call_keyword_timestamp
        | TRIM ( trim_operands )
        | USER_sym ( )
        | YEAR_sym ( expr )
        ;

#  Function calls using non reserved keywords, with special syntaxic forms.
#  Dedicated grammar rules are needed because of the syntax,
#  but also have the potential to cause incompatibilities with other
#  parts of the language.
#  MAINTAINER:
#  The only reasons a function should be added here are:
#  - for compatibility reasons with another SQL syntax (CURDATE),
#  - for typing reasons (GET_FORMAT)
#  Any other 'Syntaxic sugar' enhancements should be *STRONGLY*
#  discouraged.

function_call_nonkeyword:
          ADDDATE_sym ( expr , expr )
        | ADDDATE_sym ( expr , INTERVAL_sym expr interval )
        | CURDATE optional_braces
        | CURTIME opt_time_precision
        | DATE_ADD_INTERVAL ( expr , INTERVAL_sym expr interval )
        | DATE_SUB_INTERVAL ( expr , INTERVAL_sym expr interval )
        | DATE_FORMAT_sym ( expr , expr )
        | DATE_FORMAT_sym ( expr , expr , expr )
        | DECODE_MARIADB_sym ( expr , expr )
        | DECODE_ORACLE_sym ( expr , decode_when_list_oracle )
        | EXTRACT_sym ( interval FROM expr )
        | GET_FORMAT ( date_time_type  , expr )
        | NOW_sym opt_time_precision
        | POSITION_sym ( bit_expr IN_sym expr )
        | SUBDATE_sym ( expr , expr )
        | SUBDATE_sym ( expr , INTERVAL_sym expr interval )
        | SUBSTRING ( expr , expr , expr )
        | SUBSTRING ( expr , expr )
        | SUBSTRING ( expr FROM expr FOR_sym expr )
        | SUBSTRING ( expr FROM expr )
        | SYSDATE opt_time_precision
        | TIMESTAMP_ADD ( interval_time_stamp , expr , expr )
        | TIMESTAMP_DIFF ( interval_time_stamp , expr , expr )
        | TRIM_ORACLE ( trim_operands )
        | UTC_DATE_sym optional_braces
        | UTC_TIME_sym opt_time_precision
        | UTC_TIMESTAMP_sym opt_time_precision
        |
          COLUMN_ADD_sym ( expr , dyncall_create_list )
        |
          COLUMN_DELETE_sym ( expr , expr_list )
        |
          COLUMN_CHECK_sym ( expr )
        |
          COLUMN_CREATE_sym ( dyncall_create_list )
        |
          COLUMN_GET_sym ( expr , expr AS cast_type )
        ;

#  Functions calls using a non reserved keyword, and using a regular syntax.
#  Because the non reserved keyword is used in another part of the grammar,
#  a dedicated rule is needed here.

function_call_conflict:
          ASCII_sym ( expr )
        | CHARSET ( expr )
        | COALESCE ( expr_list )
        | COLLATION_sym ( expr )
        | DATABASE ( )
        | IF_sym ( expr , expr , expr )
        | FORMAT_sym ( expr , expr )
        | FORMAT_sym ( expr , expr , expr )
        | LAST_VALUE ( expr )
        | LAST_VALUE ( expr_list , expr )
        | MICROSECOND_sym ( expr )
        | MOD_sym ( expr , expr )
        | OLD_PASSWORD_sym ( expr )
        | PASSWORD_sym ( expr )
        | QUARTER_sym ( expr )
        | REPEAT_sym ( expr , expr )
        | REPLACE ( expr , expr , expr )
        | REVERSE_sym ( expr )
        | ROW_COUNT_sym ( )
        | TRUNCATE_sym ( expr , expr )
        | WEEK_sym ( expr )
        | WEEK_sym ( expr , expr )
        | WEIGHT_STRING_sym ( expr opt_ws_levels )
        | WEIGHT_STRING_sym ( expr AS CHAR_sym ws_nweights opt_ws_levels )
        | WEIGHT_STRING_sym ( expr AS BINARY ws_nweights )
        | WEIGHT_STRING_sym ( expr , ulong_num , ulong_num , ulong_num )
        ;

#  Regular function calls.
#  The function name is *not* a token, and therefore is guaranteed to not
#  introduce side effects to the language in general.
#  MAINTAINER:
#  All the new functions implemented for new features should fit into
#  this category. The place to implement the function itself is
#  in sql/item_create.cc

function_call_generic:
          IDENT_sys (
          opt_udf_expr_list )
        | CONTAINS_sym ( opt_expr_list )
        | WITHIN ( opt_expr_list )
        | ident_cli . ident_cli ( opt_expr_list )
        ;

fulltext_options:
          opt_natural_language_mode opt_query_expansion
        | IN_sym BOOLEAN_sym MODE_sym
        ;

opt_natural_language_mode:

        | IN_sym NATURAL LANGUAGE_sym MODE_sym
        ;

opt_query_expansion:

        | WITH QUERY_sym EXPANSION_sym
        ;

opt_udf_expr_list:

        | udf_expr_list
        ;

udf_expr_list:
          udf_expr
        | udf_expr_list , udf_expr
        ;

udf_expr:
          remember_name expr remember_end select_alias
        ;

sum_expr:
          AVG_sym ( in_sum_expr )
        | AVG_sym ( DISTINCT in_sum_expr )
        | BIT_AND  ( in_sum_expr )
        | BIT_OR  ( in_sum_expr )
        | BIT_XOR  ( in_sum_expr )
        | COUNT_sym ( opt_all * )
        | COUNT_sym ( in_sum_expr )
        | COUNT_sym ( DISTINCT
          expr_list
          )
        | MIN_sym ( in_sum_expr )
        | MIN_sym ( DISTINCT in_sum_expr )
        | MAX_sym ( in_sum_expr )
        | MAX_sym ( DISTINCT in_sum_expr )
        | STD_sym ( in_sum_expr )
        | VARIANCE_sym ( in_sum_expr )
        | STDDEV_SAMP_sym ( in_sum_expr )
        | VAR_SAMP_sym ( in_sum_expr )
        | SUM_sym ( in_sum_expr )
        | SUM_sym ( DISTINCT in_sum_expr )
        | GROUP_CONCAT_sym ( opt_distinct
          expr_list opt_gorder_clause
          opt_gconcat_separator opt_glimit_clause
          )
        | JSON_ARRAYAGG_sym ( opt_distinct
          expr_list opt_gorder_clause opt_glimit_clause
          )
        | JSON_OBJECTAGG_sym (
          expr , expr )
        ;

window_func_expr:
          window_func OVER_sym window_name
        |
          window_func OVER_sym window_spec
        ;

window_func:
          simple_window_func
        |
          sum_expr
        |
          function_call_generic
        ;

simple_window_func:
          ROW_NUMBER_sym ( )
        |
          RANK_sym ( )
        |
          DENSE_RANK_sym ( )
        |
          PERCENT_RANK_sym ( )
        |
          CUME_DIST_sym ( )
        |
          NTILE_sym ( expr )
        |
          FIRST_VALUE_sym ( expr )
        |
          LAST_VALUE ( expr )
        |
          NTH_VALUE_sym ( expr , expr )
        |
          LEAD_sym ( expr )
        |
          LEAD_sym ( expr , expr )
        |
          LAG_sym ( expr )
        |
          LAG_sym ( expr , expr )
        ;



inverse_distribution_function:
          percentile_function OVER_sym
          ( opt_window_partition_clause )
        ;

percentile_function:
          inverse_distribution_function_def  WITHIN GROUP_sym (
           order_by_single_element_list )
        | MEDIAN_sym ( expr )
        ;

inverse_distribution_function_def:
          PERCENTILE_CONT_sym ( expr )
        |  PERCENTILE_DISC_sym ( expr )
        ;

order_by_single_element_list:
          ORDER_sym BY order_ident order_dir
        ;


window_name:
          ident
        ;

variable:
          @variable_aux
        ;

variable_aux:
          ident_or_text SET_VAR expr
        | ident_or_text
        | @opt_var_ident_type ident_sysvar_name
        | @opt_var_ident_type ident_sysvar_name . ident
        ;

opt_distinct:

        | DISTINCT
        ;

opt_gconcat_separator:

        | SEPARATOR_sym text_string
        ;

opt_gorder_clause:

        | ORDER_sym BY gorder_list
        ;

gorder_list:
          gorder_list , order_ident order_dir
        | order_ident order_dir
        ;

opt_glimit_clause:

        | glimit_clause
        ;

glimit_clause_init:
          LIMIT
        ;

glimit_clause:
          glimit_clause_init glimit_options
        ;

glimit_options:
          limit_option
        | limit_option , limit_option
        | limit_option OFFSET_sym limit_option
        ;

in_sum_expr:
          opt_all
          expr
        ;

cast_type:
          BINARY opt_field_length
        | CHAR_sym opt_field_length
          opt_binary
        | VARCHAR field_length
          opt_binary
        | VARCHAR2_ORACLE_sym field_length
          opt_binary
        | NCHAR_sym opt_field_length
        | cast_type_numeric
        | cast_type_temporal
        | IDENT_sys
        | reserved_keyword_udt
        | non_reserved_keyword_udt
        ;

cast_type_numeric:
          INT_sym
        | SIGNED_sym
        | SIGNED_sym INT_sym
        | UNSIGNED
        | UNSIGNED INT_sym
        | DECIMAL_sym float_options
        | FLOAT_sym
        | DOUBLE_sym opt_precision
        ;

cast_type_temporal:
          DATE_sym
        | TIME_sym opt_field_length
        | DATETIME opt_field_length
        | INTERVAL_sym DAY_SECOND_sym field_length
        ;

opt_expr_list:

        | expr_list
        ;

expr_list:
          expr
        | expr | expr | expr | expr | expr | expr | expr | expr | expr
        | expr | expr | expr | expr | expr | expr | expr | expr | expr
        | expr | expr | expr | expr | expr | expr | expr | expr | expr
        | expr | expr | expr | expr | expr | expr | expr | expr | expr
        | expr | expr | expr | expr | expr | expr | expr | expr | expr
        | expr | expr | expr | expr | expr | expr | expr | expr | expr
        | expr_list , expr
        ;

ident_list_arg:
          ident_list
        | ( ident_list )
        ;

ident_list:
          simple_ident
        | ident_list , simple_ident
        ;

when_list:
          WHEN_sym expr THEN_sym expr
        | when_list WHEN_sym expr THEN_sym expr
        ;

when_list_opt_else:
          when_list
        | when_list ELSE expr
        ;

decode_when_list_oracle:
          expr , expr
        | decode_when_list_oracle , expr
        ;


# Equivalent to <table reference> in the SQL:2003 standard.
# Warning - may return NULL in case of incomplete SELECT

table_ref:
          table_factor
        | table_factor | table_factor | table_factor | table_factor
        | table_factor | table_factor | table_factor | table_factor
        | table_factor | table_factor | table_factor | table_factor
        | join_table
        ;

join_table_list:
          derived_table_list
        ;

#  The ODBC escape syntax for Outer Join is: '{' OJ join_table '}'
#  The parser does not define OJ as a token, any ident is accepted
#  instead in $2 (ident). Also, all productions from table_ref can
#  be escaped, not only join_table. Both syntax extensions are safe
#  and are ignored.

#
# ES TODO: fix brackets
#
esc_table_ref:
          table_ref
#        | { "{" } ident table_ref { "}" }
        ;

# Equivalent to <table reference list> in the SQL:2003 standard.
# Warning - may return NULL in case of incomplete SELECT

derived_table_list:
          esc_table_ref
        | esc_table_ref | esc_table_ref | esc_table_ref | esc_table_ref
        | esc_table_ref | esc_table_ref | esc_table_ref | esc_table_ref
        | esc_table_ref | esc_table_ref | esc_table_ref | esc_table_ref
        | esc_table_ref | esc_table_ref | esc_table_ref | esc_table_ref
        | esc_table_ref | esc_table_ref | esc_table_ref | esc_table_ref
        | derived_table_list , esc_table_ref
        ;

#  Notice that JOIN can be a left-associative operator in one context and
#  a right-associative operator in another context (see the comment for
#  st_select_lex::add_cross_joined_table).

join_table:
          table_ref normal_join table_ref
        | table_ref normal_join table_ref
          ON
          expr
        | table_ref normal_join table_ref
          USING
          ( using_list )
        | table_ref NATURAL inner_join table_factor
        | table_ref LEFT opt_outer JOIN_sym table_ref
          ON
          expr
        | table_ref LEFT opt_outer JOIN_sym table_factor
          USING ( using_list )
        | table_ref NATURAL LEFT opt_outer JOIN_sym table_factor
        | table_ref RIGHT opt_outer JOIN_sym table_ref
          ON
          expr
        | table_ref RIGHT opt_outer JOIN_sym table_factor
          USING ( using_list )
        | table_ref NATURAL RIGHT opt_outer JOIN_sym table_factor
        ;


inner_join:
          JOIN_sym
        | INNER_sym JOIN_sym
        | STRAIGHT_JOIN
        ;

normal_join:
          inner_join
        | CROSS JOIN_sym
        ;


#  table PARTITION (list of partitions), reusing using_list instead of creating
#  a new rule for partition_list.

opt_use_partition:

        | use_partition
        ;
        
use_partition:
          PARTITION_sym ( using_list ) have_partitioning
        ;

table_factor:
          table_primary_ident_opt_parens
        | table_primary_ident_opt_parens | table_primary_ident_opt_parens
        | table_primary_ident_opt_parens | table_primary_ident_opt_parens
        | table_primary_ident_opt_parens | table_primary_ident_opt_parens
        | table_primary_ident_opt_parens | table_primary_ident_opt_parens
        | table_primary_ident_opt_parens | table_primary_ident_opt_parens
        | table_primary_ident_opt_parens | table_primary_ident_opt_parens
        | table_primary_ident_opt_parens | table_primary_ident_opt_parens
        | table_primary_derived_opt_parens
        | join_table_parens
        | table_reference_list_parens
        ;

table_primary_ident_opt_parens:
          table_primary_ident
        | ( table_primary_ident_opt_parens )
        ;

table_primary_derived_opt_parens:
          table_primary_derived
        | ( table_primary_derived_opt_parens )
        ;

table_reference_list_parens:
          ( table_reference_list_parens )
        | ( nested_table_reference_list )
        | ( nested_table_reference_list )
        | ( nested_table_reference_list )
        | ( nested_table_reference_list )
        | ( nested_table_reference_list )
        | ( nested_table_reference_list )
        ;

nested_table_reference_list:
          table_ref , table_ref
        | table_ref , table_ref | table_ref , table_ref
        | table_ref , table_ref | table_ref , table_ref
        | table_ref , table_ref | table_ref , table_ref
        | table_ref , table_ref | table_ref , table_ref
        | table_ref , table_ref | table_ref , table_ref
        | nested_table_reference_list , table_ref
        ;

join_table_parens:
          ( join_table_parens )
        | ( join_table )
        | ( join_table ) | ( join_table ) | ( join_table )
        | ( join_table ) | ( join_table ) | ( join_table )
        | ( join_table ) | ( join_table ) | ( join_table )
        ;


table_primary_ident:
          table_ident opt_use_partition opt_for_system_time_clause
          opt_table_alias_clause opt_key_definition
        ;

table_primary_derived:
          subquery
          opt_for_system_time_clause table_alias_clause
        ;

opt_outer:

        | OUTER
        ;

index_hint_clause:

        | FOR_sym JOIN_sym
        | FOR_sym ORDER_sym BY
        | FOR_sym GROUP_sym BY
        ;

index_hint_type:
          FORCE_sym
        | IGNORE_sym
        ;

index_hint_definition:
          index_hint_type key_or_index index_hint_clause
          ( key_usage_list )
        | USE_sym key_or_index index_hint_clause
          ( opt_key_usage_list )
       ;

index_hints_list:
          index_hint_definition
        | index_hint_definition | index_hint_definition
        | index_hint_definition | index_hint_definition
        | index_hint_definition | index_hint_definition
        | index_hint_definition | index_hint_definition
        | index_hints_list index_hint_definition
        ;

opt_index_hints_list:

        | index_hints_list
        ;

opt_key_definition:
          opt_index_hints_list
        ;

opt_key_usage_list:

        | key_usage_list
        ;

key_usage_element:
          ident
        | PRIMARY_sym
        ;

key_usage_list:
          key_usage_element
        | key_usage_element | key_usage_element | key_usage_element
        | key_usage_element | key_usage_element | key_usage_element
        | key_usage_element | key_usage_element | key_usage_element
        | key_usage_element | key_usage_element | key_usage_element
        | key_usage_list , key_usage_element
        ;

using_list:
          ident
        | ident | ident | ident | ident | ident | ident | ident | ident
        | ident | ident | ident | ident | ident | ident | ident | ident
        | using_list , ident
        ;

interval:
          interval_time_stamp   
        | DAY_HOUR_sym
        | DAY_MICROSECOND_sym
        | DAY_MINUTE_sym
        | DAY_SECOND_sym
        | HOUR_MICROSECOND_sym
        | HOUR_MINUTE_sym
        | HOUR_SECOND_sym
        | MINUTE_MICROSECOND_sym
        | MINUTE_SECOND_sym
        | SECOND_MICROSECOND_sym
        | YEAR_MONTH_sym
        ;

interval_time_stamp:
          DAY_sym
        | WEEK_sym
        | HOUR_sym
        | MINUTE_sym
        | MONTH_sym
        | QUARTER_sym
        | SECOND_sym
        | MICROSECOND_sym
        | YEAR_sym
        ;

date_time_type:
          DATE_sym
        | TIME_sym
        | DATETIME
        | TIMESTAMP
        ;

table_alias:

        | AS
        | =
        ;

opt_table_alias_clause:

        | table_alias_clause
        ;

table_alias_clause:
          table_alias ident_table_alias
        ;

opt_all:

        | ALL
        ;

opt_where_clause:

        | | | | | | | | | | |
        | WHERE
          expr
        ;

opt_having_clause:

        | HAVING
          expr
        ;

opt_escape:
          ESCAPE_sym simple_expr 
        |
        ;


#   group by statement in select

opt_group_clause:

        | GROUP_sym BY group_list olap_opt
        ;

group_list:
          group_list , order_ident order_dir
        | order_ident order_dir
        | order_ident order_dir | order_ident order_dir
        | order_ident order_dir | order_ident order_dir
        | order_ident order_dir | order_ident order_dir
        | order_ident order_dir | order_ident order_dir
        | order_ident order_dir | order_ident order_dir
        | order_ident order_dir | order_ident order_dir
        | order_ident order_dir | order_ident order_dir
        | order_ident order_dir | order_ident order_dir
        | order_ident order_dir | order_ident order_dir
        ;

olap_opt:

        | WITH_CUBE_sym
        | WITH_ROLLUP_sym
        ;

#  optional window clause in select

opt_window_clause:

        | WINDOW_sym
          window_def_list
        ;

window_def_list:
          window_def_list , window_def
        | window_def
        | window_def | window_def | window_def | window_def | window_def
        | window_def | window_def | window_def | window_def | window_def
        | window_def | window_def | window_def | window_def | window_def
        ;

window_def:
          window_name AS window_spec
        ;

window_spec:
          ( 
          opt_window_ref opt_window_partition_clause
          opt_window_order_clause opt_window_frame_clause
          )
        ;

opt_window_ref:

        | ident
        ;

opt_window_partition_clause:

        | PARTITION_sym BY group_list
        ;

opt_window_order_clause:

        | ORDER_sym BY order_list
        ;

opt_window_frame_clause:

        | window_frame_units window_frame_extent opt_window_frame_exclusion
        ;

window_frame_units:
          ROWS_sym
        | RANGE_sym
        ;
         
window_frame_extent:
          window_frame_start
        | BETWEEN_sym window_frame_bound AND_sym window_frame_bound
        ;

window_frame_start:
          UNBOUNDED_sym PRECEDING_sym
        | CURRENT_sym ROW_sym
        | literal PRECEDING_sym
        ;

window_frame_bound:
          window_frame_start
        | UNBOUNDED_sym FOLLOWING_sym        
        | literal FOLLOWING_sym
        ;

opt_window_frame_exclusion:

        | EXCLUDE_sym CURRENT_sym ROW_sym
        | EXCLUDE_sym GROUP_sym
        | EXCLUDE_sym TIES_sym
        | EXCLUDE_sym NO_sym OTHERS_MARIADB_sym
        | EXCLUDE_sym NO_sym OTHERS_ORACLE_sym
        ;      
       
#  Order by statement in ALTER TABLE

alter_order_clause:
          ORDER_sym BY alter_order_list
        ;

alter_order_list:
          alter_order_list , alter_order_item
        | alter_order_item
        ;

alter_order_item:
          simple_ident_nospvar order_dir
        ;

#   Order by statement in select

opt_order_clause:

        | order_clause
        ;

order_clause:
          ORDER_sym BY
          order_list
         ;

order_list:
          order_list , order_ident order_dir
        | order_ident order_dir
        | order_ident order_dir | order_ident order_dir
        | order_ident order_dir | order_ident order_dir
        | order_ident order_dir | order_ident order_dir
        | order_ident order_dir | order_ident order_dir
        | order_ident order_dir | order_ident order_dir
        | order_ident order_dir | order_ident order_dir
        | order_ident order_dir | order_ident order_dir
        | order_ident order_dir | order_ident order_dir
        | order_ident order_dir | order_ident order_dir
        | order_ident order_dir | order_ident order_dir
        ;

order_dir:

        | ASC
        | DESC
        ;

opt_limit_clause:

        | limit_clause
        ;

limit_clause:
          LIMIT limit_options
        | LIMIT limit_options
          ROWS_sym EXAMINED_sym limit_rows_option
        | LIMIT ROWS_sym EXAMINED_sym limit_rows_option
        ;

opt_global_limit_clause:
          opt_limit_clause
        ;

limit_options:
          limit_option
        | limit_option , limit_option
        | limit_option OFFSET_sym limit_option
        ;

limit_option:
          ident_cli
        | ident_cli . ident_cli
        | param_marker
        | ULONGLONG_NUM
# Should really be unsigned INTs
#        | LONG_NUM
        | _int_unsigned
#        | NUM
        | _smallint_unsigned
        ;

limit_rows_option:
          limit_option
        ;

delete_limit_clause:

        | LIMIT limit_option
# ROWS_EXAMINED causes unconditional parsing error
#       | LIMIT ROWS_sym EXAMINED_sym
#       | LIMIT limit_option ROWS_sym EXAMINED_sym
        ;

order_limit_lock:
          order_or_limit
        | order_or_limit select_lock_type
        | select_lock_type
        ;

opt_order_limit_lock:

        | | | | | | | | |
        | order_limit_lock
        ;

query_expression_tail:
          order_limit_lock
        ;

opt_query_expression_tail:
          opt_order_limit_lock
        ;

opt_procedure_or_into:

        | procedure_clause opt_select_lock_type
        | into opt_select_lock_type
        ;

order_or_limit:
          order_clause opt_limit_clause
        | limit_clause
        ;

opt_plus:

        | +
        ;

int_num:
          opt_plus NUM
        | - NUM
        ;

# Should be unsigned
ulong_num:
#          opt_plus NUM
          opt_plus NUM_unsigned
        | HEX_NUM
#        | opt_plus LONG_NUM
        | opt_plus LONG_NUM_unsigned
        | opt_plus ULONGLONG_NUM
#        | opt_plus DECIMAL_NUM
        | opt_plus DECIMAL_NUM_unsigned
#        | opt_plus FLOAT_NUM
        | opt_plus FLOAT_NUM_unsigned
        ;

real_ulong_num:
          NUM
        | HEX_NUM
        | LONG_NUM
        | ULONGLONG_NUM
        | dec_num_error
        ;

longlong_num:
          opt_plus NUM
        | LONG_NUM
# Negative values are smartly converted to avoid double-minus
#        | - NUM
        | - NUM_unsigned
#        | - LONG_NUM
        | - LONG_NUM_unsigned
        ;

ulonglong_num:
          opt_plus NUM
        | opt_plus ULONGLONG_NUM
        | opt_plus LONG_NUM
        | opt_plus DECIMAL_NUM
        | opt_plus FLOAT_NUM
        ;

real_ulonglong_num:
          NUM
        | ULONGLONG_NUM
        | HEX_NUM
        | LONG_NUM
        | dec_num_error
        ;

dec_num_error:
          dec_num
        ;

dec_num:
          DECIMAL_NUM
        | FLOAT_NUM
        ;

choice:
          ulong_num
        | DEFAULT
        ;

bool:
        ulong_num
        | TRUE_sym
        | FALSE_sym
        ;

procedure_clause:
          PROCEDURE_sym ident
          ( procedure_list )
        ;

procedure_list:

        | procedure_list2
        ;

procedure_list2:
          procedure_list2 , procedure_item
        | procedure_item
        ;

procedure_item:
          remember_name expr remember_end
        ;

select_var_list_init:
          select_var_list
        ;

select_var_list:
          select_var_list , select_var_ident
        | select_var_ident
        ;

select_var_ident: select_outvar
        ;

select_outvar:
          @ident_or_text
        | ident_or_text
        | ident . ident
        ;

into:
          INTO into_destination
         
        ;

into_destination:
          OUTFILE TEXT_STRING_filesystem
          opt_load_data_charset
          opt_field_term opt_line_term
        | DUMPFILE TEXT_STRING_filesystem
        | select_var_list_init
        ;


#  DO statement

do:
          DO_sym
          expr_list
        ;

#  Drop : delete tables or index or user

drop:
          DROP opt_temporary table_or_tables opt_if_exists
          table_list opt_lock_wait_timeout opt_restrict
         
        | DROP INDEX_sym
          opt_if_exists_table_element ident ON table_ident opt_lock_wait_timeout
        | DROP DATABASE opt_if_exists ident
        | DROP USER_sym opt_if_exists clear_privileges user_list
        | DROP ROLE_sym opt_if_exists clear_privileges role_list
        | DROP VIEW_sym opt_if_exists
          table_list opt_restrict
        | DROP EVENT_sym opt_if_exists sp_name
        | DROP TRIGGER_sym opt_if_exists sp_name
        | DROP TABLESPACE tablespace_name opt_ts_engine opt_ts_wait
        | DROP LOGFILE_sym GROUP_sym logfile_group_name opt_ts_engine opt_ts_wait
        | DROP SERVER_sym opt_if_exists ident_or_text
        | DROP opt_temporary SEQUENCE_sym opt_if_exists
          table_list
        | drop_routine
        ;

table_list:
          table_name
        | table_list , table_name
        ;

table_name:
          table_ident
        ;

table_name_with_opt_use_partition:
          table_ident opt_use_partition
        ;

table_alias_ref_list:
          table_alias_ref
        | table_alias_ref | table_alias_ref | table_alias_ref
        | table_alias_ref | table_alias_ref | table_alias_ref
        | table_alias_ref | table_alias_ref | table_alias_ref
        | table_alias_ref | table_alias_ref | table_alias_ref
        | table_alias_ref | table_alias_ref | table_alias_ref
        | table_alias_ref_list , table_alias_ref
        ;

table_alias_ref:
          table_ident_opt_wild
        ;

opt_if_exists_table_element:

        | IF_sym EXISTS
        ;

opt_if_exists:

        | IF_sym EXISTS
        ;

opt_temporary:

        | TEMPORARY
        ;

# Insert : add new data to table

insert:
          INSERT
          insert_start insert_lock_option opt_ignore opt_into insert_table
          insert_field_spec opt_insert_update opt_returning
          stmt_end
          ;

replace:
          REPLACE
          insert_start replace_lock_option opt_into insert_table
          insert_field_spec opt_returning
          stmt_end
          ;

insert_start:
          ;

stmt_end:
          ;

insert_lock_option:

        | insert_replace_option
        | HIGH_PRIORITY
        ;

replace_lock_option:

        | insert_replace_option
        ;

insert_replace_option:
          LOW_PRIORITY
        | DELAYED_sym
        ;

opt_into:

        | INTO
        ;

insert_table:
          table_name_with_opt_use_partition
        ;

insert_field_spec:
          insert_values
        | insert_field_list insert_values
        | SET
          ident_eq_list
        ;

insert_field_list:
          LEFT_PAREN_ALT opt_fields )
        ;

opt_fields:

        | fields
        ;

fields:
          fields , insert_ident
        | insert_ident
        ;


insert_values:
         create_select_query_expression
        ;

values_list:
          values_list ,  no_braces
        | no_braces_with_names
        | no_braces_with_names | no_braces_with_names
        | no_braces_with_names | no_braces_with_names
        | no_braces_with_names | no_braces_with_names
        | no_braces_with_names | no_braces_with_names
        | no_braces_with_names | no_braces_with_names
        | no_braces_with_names | no_braces_with_names
        | no_braces_with_names | no_braces_with_names
        | no_braces_with_names | no_braces_with_names
        ;

ident_eq_list:
          ident_eq_list , ident_eq_value
        | ident_eq_value
        ;

ident_eq_value:
          simple_ident_nospvar equal expr_or_default
        ;

equal:
          =
        | SET_VAR
        ;

opt_equal:

        | equal
        ;

opt_with:
          opt_equal
        | WITH
        ;

opt_by:
          opt_equal
        | BY
        ;

no_braces:
          (
          opt_values )
        ;

no_braces_with_names:
          (
          opt_values_with_names )
        ;

opt_values:

        | values
        ;

opt_values_with_names:

        | | | | | |
        | values_with_names
        ;

values:
          values ,  expr_or_default
        | expr_or_default
        ;

values_with_names:
          values_with_names ,  remember_name expr_or_default remember_end
        | remember_name expr_or_default remember_end
        | remember_name expr_or_default remember_end
        | remember_name expr_or_default remember_end
        | remember_name expr_or_default remember_end
        | remember_name expr_or_default remember_end
        | remember_name expr_or_default remember_end
        | remember_name expr_or_default remember_end
        | remember_name expr_or_default remember_end
        | remember_name expr_or_default remember_end
        | remember_name expr_or_default remember_end
        ;

expr_or_default:
          expr
        | DEFAULT
        | DEFAULT | DEFAULT | DEFAULT | DEFAULT | DEFAULT
        | IGNORE_sym
        | IGNORE_sym | IGNORE_sym | IGNORE_sym | IGNORE_sym | IGNORE_sym
        ;

opt_insert_update:

        | ON DUPLICATE_sym
          KEY_sym UPDATE_sym 
          insert_update_list
        ;

update_table_list:
          table_ident opt_use_partition for_portion_of_time_clause
          opt_table_alias_clause opt_key_definition
        | join_table_list
        ;

# Update rows in a table

update:
          UPDATE_sym
          opt_low_priority opt_ignore update_table_list
          SET update_list
          opt_where_clause opt_order_clause delete_limit_clause
          stmt_end
        ;

update_list:
          update_list , update_elem
        | update_elem
        ;

update_elem:
          simple_ident_nospvar equal expr_or_default
        ;

insert_update_list:
          insert_update_list , insert_update_elem
        | insert_update_elem
        ;

insert_update_elem:
          simple_ident_nospvar equal expr_or_default
        ;

opt_low_priority:

        | LOW_PRIORITY
        ;

# Delete rows from a table

delete:
          DELETE_sym
          delete_part2
         
          ;

opt_delete_system_time:

          | BEFORE_sym SYSTEM_TIME_sym history_point
          ;

delete_part2:
          opt_delete_options single_multi
        | HISTORY_sym delete_single_table opt_delete_system_time
        ;

delete_single_table:
          FROM table_ident opt_use_partition
        ;

delete_single_table_for_period:
          delete_single_table opt_for_portion_of_time_clause
        ;

single_multi:
          delete_single_table_for_period
          opt_where_clause
          opt_order_clause
          delete_limit_clause
          opt_returning
        | table_wild_list
          FROM join_table_list opt_where_clause
        | FROM table_alias_ref_list
          USING join_table_list opt_where_clause
          stmt_end
        ;

opt_returning:

        | RETURNING_sym
          select_item_list
        ;

table_wild_list:
          table_wild_one
        | table_wild_list , table_wild_one
        ;

table_wild_one:
          ident opt_wild
        | ident . ident opt_wild
        ;

opt_wild:

        | . *
        ;

opt_delete_options:

        | opt_delete_option opt_delete_options
        ;

opt_delete_option:
          QUICK
        | LOW_PRIORITY
        | IGNORE_sym
        ;

truncate:
          TRUNCATE_sym
          opt_table_sym table_name opt_lock_wait_timeout
          opt_truncate_table_storage_clause
        ;

opt_table_sym:

        | TABLE_sym
        ;

opt_profile_defs:

  | profile_defs
  ;

profile_defs:
  profile_def
  | profile_defs , profile_def
  ;

profile_def:
  CPU_sym
  | MEMORY_sym
  | BLOCK_sym IO_sym
  | CONTEXT_sym SWITCHES_sym
  | PAGE_sym FAULTS_sym
  | IPC_sym
  | SWAPS_sym
  | SOURCE_sym
  | ALL
  ;

opt_profile_args:

  | FOR_sym QUERY_sym NUM
  ;

# Show things

show:
          SHOW
          show_param
        ;

show_param:
          DATABASES wild_and_where
        | opt_full TABLES opt_db wild_and_where
        | opt_full TRIGGERS_sym opt_db wild_and_where
        | EVENTS_sym opt_db wild_and_where
        | TABLE_sym STATUS_sym opt_db wild_and_where
        | OPEN_sym TABLES opt_db wild_and_where
        | PLUGINS_sym
        | PLUGINS_sym SONAME_sym TEXT_STRING_sys
        | PLUGINS_sym SONAME_sym wild_and_where
        | ENGINE_sym known_storage_engines show_engine_param
        | ENGINE_sym ALL show_engine_param
        | opt_full COLUMNS from_or_in table_ident opt_db wild_and_where
        | master_or_binary LOGS_sym
        | SLAVE HOSTS_sym
        | BINLOG_sym EVENTS_sym binlog_in binlog_from
          opt_global_limit_clause
        | RELAYLOG_sym optional_connection_name EVENTS_sym binlog_in binlog_from
          opt_global_limit_clause
        | keys_or_index from_or_in table_ident opt_db opt_where_clause
        | opt_storage ENGINES_sym
        | AUTHORS_sym
        | CONTRIBUTORS_sym
        | PRIVILEGES
        | COUNT_sym ( * ) WARNINGS
        | COUNT_sym ( * ) ERRORS
        | WARNINGS opt_global_limit_clause
        | ERRORS opt_global_limit_clause
        | PROFILES_sym
        | PROFILE_sym opt_profile_defs opt_profile_args opt_global_limit_clause
        | opt_var_type STATUS_sym wild_and_where
        | opt_full PROCESSLIST_sym
        | opt_var_type  VARIABLES wild_and_where
        | charset wild_and_where
        | COLLATION_sym wild_and_where
        | GRANTS
        | GRANTS FOR_sym user_or_role clear_privileges
        | CREATE DATABASE opt_if_not_exists ident
        | CREATE TABLE_sym table_ident
        | CREATE VIEW_sym table_ident
        | CREATE SEQUENCE_sym table_ident
        | BINLOG_sym STATUS_sym
        | MASTER_sym STATUS_sym
        | ALL SLAVES STATUS_sym
        | SLAVE STATUS_sym
        | SLAVE connection_name STATUS_sym
        | CREATE PROCEDURE_sym sp_name
        | CREATE FUNCTION_sym sp_name
        | CREATE PACKAGE_MARIADB_sym sp_name
        | CREATE PACKAGE_ORACLE_sym sp_name
        | CREATE PACKAGE_MARIADB_sym BODY_MARIADB_sym sp_name
        | CREATE PACKAGE_ORACLE_sym BODY_ORACLE_sym sp_name
        | CREATE TRIGGER_sym sp_name
        | CREATE USER_sym
        | CREATE USER_sym user
        | PROCEDURE_sym STATUS_sym wild_and_where
        | FUNCTION_sym STATUS_sym wild_and_where
        | PACKAGE_MARIADB_sym STATUS_sym wild_and_where
        | PACKAGE_ORACLE_sym STATUS_sym wild_and_where
        | PACKAGE_MARIADB_sym BODY_MARIADB_sym STATUS_sym wild_and_where
        | PACKAGE_ORACLE_sym BODY_ORACLE_sym STATUS_sym wild_and_where
        | PROCEDURE_sym CODE_sym sp_name
        | FUNCTION_sym CODE_sym sp_name
        | PACKAGE_MARIADB_sym BODY_MARIADB_sym CODE_sym sp_name
        | PACKAGE_ORACLE_sym BODY_ORACLE_sym CODE_sym sp_name
        | CREATE EVENT_sym sp_name
        | describe_command FOR_sym expr
# TODO ES: This is apparently for plugins, not yet sure how to deal with it
#        | IDENT_sys remember_tok_start wild_and_where
        ;

show_engine_param:
          STATUS_sym
        | MUTEX_sym
        | LOGS_sym
        ;

master_or_binary:
          MASTER_sym
        | BINARY
        ;

opt_storage:

        | STORAGE_sym
        ;

opt_db:

        | from_or_in ident
        ;

opt_full:

        | FULL
        ;

from_or_in:
          FROM
        | IN_sym
        ;

binlog_in:

        | IN_sym TEXT_STRING_sys
        ;

binlog_from:

        | FROM ulonglong_num
        ;

wild_and_where:

        | LIKE remember_tok_start TEXT_STRING_sys
        | WHERE remember_tok_start expr
        ;

# A Oracle compatible synonym for show
describe:
          describe_command table_ident
          opt_describe_column
        | describe_command opt_extended_describe
          explainable_command
        ;

explainable_command:
          select
        | select_into
        | insert
        | replace
        | update
        | delete
        ;

describe_command:
          DESC
        | DESCRIBE
        ;

analyze_stmt_command:
          ANALYZE_sym opt_format_json explainable_command
        ;

opt_extended_describe:
          EXTENDED_sym
        | EXTENDED_sym ALL
        | PARTITIONS_sym
        | opt_format_json
        ;

opt_format_json:

        | FORMAT_sym = ident_or_text
        ;

opt_describe_column:

        | text_string
        | ident
        ;


# flush things

flush:
          FLUSH_sym opt_no_write_to_binlog
          flush_options
        ;

flush_options:
          table_or_tables
          opt_table_list opt_flush_lock
        | flush_options_list
        ;

opt_flush_lock:

        | flush_lock
        ;

flush_lock:
          WITH READ_sym LOCK_sym optional_flush_tables_arguments
        | FOR_sym
          EXPORT_SYM
        ;

flush_options_list:
          flush_options_list , flush_option
        | flush_option
        | flush_option | flush_option | flush_option | flush_option
        | flush_option | flush_option | flush_option | flush_option
        ;

flush_option:
          ERROR_sym LOGS_sym
        | ENGINE_sym LOGS_sym
        | GENERAL LOGS_sym
        | SLOW LOGS_sym
        | BINARY LOGS_sym opt_delete_gtid_domain
        | RELAY LOGS_sym optional_connection_name
        | QUERY_sym CACHE_sym
        | HOSTS_sym
        | PRIVILEGES
        | LOGS_sym
        | STATUS_sym
        | SLAVE optional_connection_name 
        | MASTER_sym
        | DES_KEY_FILE
        | RESOURCES
        | SSL_sym
# TODO ES: It is probably something plugin-specific
#        | IDENT_sys remember_tok_start
        ;

opt_table_list:

        | table_list
        ;

backup:
        BACKUP_sym backup_statements
        ;

backup_statements:
          STAGE_sym ident
        | LOCK_sym
          table_ident
        | UNLOCK_sym
        ;

opt_delete_gtid_domain:

        | DELETE_DOMAIN_ID_sym = ( delete_domain_id_list )
        ;

delete_domain_id_list:

        | delete_domain_id
        | delete_domain_id_list , delete_domain_id
        ;

delete_domain_id:
          ulonglong_num
        ;

optional_flush_tables_arguments:

        | AND_sym DISABLE_sym CHECKPOINT_sym
        ;

reset:
          RESET_sym
          reset_options
        ;

reset_options:
          reset_options , reset_option
        | reset_option
        ;

reset_option:
          SLAVE
          optional_connection_name
          slave_reset_options
        | MASTER_sym
          master_reset_options
        | QUERY_sym CACHE_sym
        ;

slave_reset_options:

        | ALL
        ;

master_reset_options:

        | TO_sym ulong_num
        ;

purge:
          PURGE master_or_binary LOGS_sym TO_sym TEXT_STRING_sys
        | PURGE master_or_binary LOGS_sym BEFORE_sym expr
        ;


# kill threads

kill:
          KILL_sym
          kill_type kill_option kill_expr
        ;

kill_type:

        | HARD_sym
        | SOFT_sym
        ;

kill_option:

        | CONNECTION_sym
        | QUERY_sym
        | QUERY_sym ID_sym
        ;

kill_expr:
        expr
        | USER_sym user
        ;


shutdown:
        SHUTDOWN
        shutdown_option
        ;

shutdown_option:

        | WAIT_sym FOR_sym ALL SLAVES
        ;

# change database

use:
          USE_sym ident
        ;

# import, export of files

load:
          LOAD data_or_xml
          load_data_lock opt_local INFILE TEXT_STRING_filesystem
          opt_duplicate INTO TABLE_sym table_ident opt_use_partition
          opt_load_data_charset
          opt_xml_rows_identified_by
          opt_field_term opt_line_term opt_ignore_lines opt_field_or_var_spec
          opt_load_data_set_spec
          stmt_end
          ;

data_or_xml:
        DATA_sym
        | XML_sym
        ;

opt_local:

        | LOCAL_sym
        ;

load_data_lock:

        | CONCURRENT
        | LOW_PRIORITY
        ;

opt_duplicate:

        | REPLACE
        | IGNORE_sym
        ;

opt_field_term:

        | COLUMNS field_term_list
        ;

field_term_list:
          field_term_list field_term
        | field_term
        ;

field_term:
          TERMINATED BY text_string
        | OPTIONALLY ENCLOSED BY text_string
        | ENCLOSED BY text_string
        | ESCAPED BY text_string
        ;

opt_line_term:

        | LINES line_term_list
        ;

line_term_list:
          line_term_list line_term
        | line_term
        ;

line_term:
          TERMINATED BY text_string
        | STARTING BY text_string
        ;

opt_xml_rows_identified_by:

        | ROWS_sym IDENTIFIED_sym BY text_string
        ;

opt_ignore_lines:

# Should really be unsigned int
#        | IGNORE_sym NUM lines_or_rows
        | IGNORE_sym _int_unsigned lines_or_rows
        ;

lines_or_rows:
          LINES
        | ROWS_sym
        ;

opt_field_or_var_spec:

        | ( fields_or_vars )
        | ( )
        ;

fields_or_vars:
          fields_or_vars , field_or_var
        | field_or_var
        ;

field_or_var:
          simple_ident_nospvar
        | @ident_or_text
        ;

opt_load_data_set_spec:

        | SET load_data_set_list
        ;

load_data_set_list:
          load_data_set_list , load_data_set_elem
        | load_data_set_elem
        ;

load_data_set_elem:
          simple_ident_nospvar equal remember_name expr_or_default remember_end
        ;

# Common definitions

text_literal:
          TEXT_STRING
        | NCHAR_STRING
        | UNDERSCORE_CHARSET TEXT_STRING
        | text_literal TEXT_STRING_literal
        ;

text_string:
          TEXT_STRING_literal
          | hex_or_bin_String
          ;


hex_or_bin_String:
          HEX_NUM
        | HEX_STRING
        | BIN_NUM
        ;

param_marker:
          PARAM_MARKER
        | COLON_ORACLE_sym ident_cli
        | COLON_ORACLE_sym NUM
        ;

signed_literal:
        + NUM_literal
        | - NUM_literal
        ;

literal:
          text_literal
        | NUM_literal
        | temporal_literal
        | NULL_sym
        | FALSE_sym
        | TRUE_sym
        | HEX_NUM
        | HEX_STRING
        | BIN_NUM
        | UNDERSCORE_CHARSET hex_or_bin_String
        ;

NUM_literal:
          NUM
        | LONG_NUM
        | ULONGLONG_NUM
        | DECIMAL_NUM
        | FLOAT_NUM
        ;

temporal_literal:
        DATE_sym TEXT_STRING
        | TIME_sym TEXT_STRING
        | TIMESTAMP TEXT_STRING
        ;

with_clause:
          WITH opt_recursive
          with_list
        ;


opt_recursive:

        | RECURSIVE_sym
        ;

with_list:
          with_list_element
        | with_list_element | with_list_element | with_list_element 
        | with_list_element | with_list_element | with_list_element 
        | with_list_element | with_list_element | with_list_element 
        | with_list_element | with_list_element | with_list_element 
        | with_list_element | with_list_element | with_list_element 
        | with_list , with_list_element
        ;


with_list_element:
        query_name
        opt_with_column_list 
          AS ( query_expression ) opt_cycle
        ;

opt_cycle:

         |
         CYCLE_sym
         comma_separated_ident_list RESTRICT
         ;


opt_with_column_list:

        | ( with_column_list )
        ;

with_column_list:
          comma_separated_ident_list
        ;

ident_sys_alloc:
          ident_cli
        ;

comma_separated_ident_list:
          ident_sys_alloc
        | ident_sys_alloc | ident_sys_alloc | ident_sys_alloc
        | ident_sys_alloc | ident_sys_alloc | ident_sys_alloc
        | ident_sys_alloc | ident_sys_alloc | ident_sys_alloc
        | ident_sys_alloc | ident_sys_alloc | ident_sys_alloc
        | ident_sys_alloc | ident_sys_alloc | ident_sys_alloc
        | comma_separated_ident_list , ident_sys_alloc
        ;


query_name: 
          ident
        ;


#**********************************************************************
#** Creating different items.
#**********************************************************************

insert_ident:
          simple_ident_nospvar
        | table_wild
        ;

table_wild:
          ident . *
        | ident . ident . *
        ;

select_sublist_qualified_asterisk:
          ident_cli . *
        | ident_cli . ident_cli . *
        ;

order_ident:
          expr
        ;


simple_ident:
          ident_cli
        | ident_cli . ident_cli
        | . ident_cli . ident_cli
        | ident_cli . ident_cli . ident_cli
        | COLON_ORACLE_sym ident_cli . ident_cli
        ;

simple_ident_nospvar:
          ident
        | ident . ident
        | COLON_ORACLE_sym ident_cli . ident_cli
        | . ident . ident
        | ident . ident . ident
        ;

field_ident:
          ident
        | ident . ident . ident
        | ident . ident
# For Delphi
        | . ident
        ;

table_ident:
          ident
        | ident . ident
        | . ident
        ;

table_ident_opt_wild:
          ident opt_wild
        | ident . ident opt_wild
        ;

table_ident_nodb:
          ident
        ;

IDENT_cli:
          IDENT
        | IDENT_QUOTED
        ;

ident_cli:
          IDENT
        | IDENT | IDENT | IDENT | IDENT | IDENT | IDENT | IDENT | IDENT
        | IDENT | IDENT | IDENT | IDENT | IDENT | IDENT | IDENT | IDENT
        | IDENT | IDENT | IDENT | IDENT | IDENT | IDENT | IDENT | IDENT
        | IDENT | IDENT | IDENT | IDENT | IDENT | IDENT | IDENT | IDENT
        | IDENT | IDENT | IDENT | IDENT | IDENT | IDENT | IDENT | IDENT
        | IDENT | IDENT | IDENT | IDENT | IDENT | IDENT | IDENT | IDENT
        | IDENT_QUOTED
        | IDENT_QUOTED | IDENT_QUOTED | IDENT_QUOTED | IDENT_QUOTED
        | IDENT_QUOTED | IDENT_QUOTED | IDENT_QUOTED | IDENT_QUOTED
        | IDENT_QUOTED | IDENT_QUOTED | IDENT_QUOTED | IDENT_QUOTED
        | IDENT_QUOTED | IDENT_QUOTED | IDENT_QUOTED | IDENT_QUOTED
        | IDENT_QUOTED | IDENT_QUOTED | IDENT_QUOTED | IDENT_QUOTED
        | IDENT_QUOTED | IDENT_QUOTED | IDENT_QUOTED | IDENT_QUOTED
        | keyword_ident
        ;

IDENT_sys:
          IDENT_cli
        ;

TEXT_STRING_sys:
          TEXT_STRING
        ;

TEXT_STRING_literal:
          TEXT_STRING
        ;

TEXT_STRING_filesystem:
          TEXT_STRING
        ;

ident_table_alias:
          IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | keyword_table_alias
        ;

ident_cli_set_usual_case:
          IDENT_cli
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | keyword_set_usual_case
        ;

ident_sysvar_name:
          IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | keyword_sysvar_name
        | TEXT_STRING_sys
        ;


ident:
          IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | keyword_ident
        ;

label_ident:
          IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys | IDENT_sys
        | keyword_label
        ;

ident_or_text:
          ident
#        | TEXT_STRING_sys
        | LEX_HOSTNAME
        ;

user_maybe_role:
          ident_or_text
        | ident_or_text@ident_or_text
        | CURRENT_USER optional_braces
        ;

user_or_role:
          user_maybe_role
        | current_role
        ;

user: user_maybe_role
         ;

# Keywords which we allow as table aliases.
keyword_table_alias:
          keyword_data_type
        | keyword_cast_type
        | keyword_set_special_case
        | keyword_sp_block_section
        | keyword_sp_head
        | keyword_sp_var_and_label
        | keyword_sp_var_not_label
        | keyword_sysvar_type
        | keyword_verb_clause
        | FUNCTION_sym
        | EXCEPTION_ORACLE_sym
        ;

# Keyword that we allow for identifiers (except SP labels)
keyword_ident:
          keyword_data_type
        | keyword_cast_type
        | keyword_set_special_case
        | keyword_sp_block_section
        | keyword_sp_head
        | keyword_sp_var_and_label
        | keyword_sp_var_not_label
        | keyword_sysvar_type
        | keyword_verb_clause
        | FUNCTION_sym
        | WINDOW_sym
        | EXCEPTION_ORACLE_sym
        ;

keyword_sysvar_name:
          keyword_data_type
        | keyword_cast_type
        | keyword_set_special_case
        | keyword_sp_block_section
        | keyword_sp_head
        | keyword_sp_var_and_label
        | keyword_sp_var_not_label
        | keyword_verb_clause
        | FUNCTION_sym
        | WINDOW_sym
        | EXCEPTION_ORACLE_sym
        ;

keyword_set_usual_case:
          keyword_data_type
        | keyword_cast_type
        | keyword_sp_block_section
        | keyword_sp_head
        | keyword_sp_var_and_label
        | keyword_sp_var_not_label
        | keyword_sysvar_type
        | keyword_verb_clause
        | FUNCTION_sym
        | WINDOW_sym
        | EXCEPTION_ORACLE_sym
        ;

non_reserved_keyword_udt:
          keyword_sp_var_not_label
        | keyword_sp_head
        | keyword_verb_clause
        | keyword_set_special_case
        | keyword_sp_block_section
        | keyword_sysvar_type
        | keyword_sp_var_and_label
        ;


#  Keywords that we allow in Oracle-style direct assignments:
#    xxx := 10;
#  but do not allow in labels in the default sql_mode:
#    label:
#      stmt1;
#      stmt2;
#  TODO: check if some of them can migrate to keyword_sp_var_and_label.

keyword_sp_var_not_label:
          ASCII_sym
        | BACKUP_sym
        | BINLOG_sym
        | BYTE_sym
        | CACHE_sym
        | CHECKSUM_sym
        | CHECKPOINT_sym
        | COLUMN_ADD_sym
        | COLUMN_CHECK_sym
        | COLUMN_CREATE_sym
        | COLUMN_DELETE_sym
        | COLUMN_GET_sym
        | COMMENT_sym
        | COMPRESSED_sym
        | DEALLOCATE_sym
        | EXAMINED_sym
        | EXCLUDE_sym
        | EXECUTE_sym
        | FLUSH_sym
        | FOLLOWING_sym
        | FORMAT_sym
        | GET_sym
        | HELP_sym
        | HOST_sym
        | INSTALL_sym
        | OPTION
        | OPTIONS_sym
        | OTHERS_MARIADB_sym
        | OWNER_sym
        | PARSER_sym
        | PERIOD_sym
        | PORT_sym
        | PRECEDING_sym
        | PREPARE_sym
        | REMOVE_sym
        | RESET_sym
        | RESTORE_sym
        | SECURITY_sym
        | SERVER_sym
        | SOCKET_sym
        | SLAVE
        | SLAVES
        | SONAME_sym
        | START_sym
        | STOP_sym
        | STORED_sym
        | TIES_sym
        | UNICODE_sym
        | UNINSTALL_sym
        | UNBOUNDED_sym
        | WITHIN
        | WRAPPER_sym
        | XA_sym
        | UPGRADE_sym
        ;


#  Keywords that can start optional clauses in SP or trigger declarations
#  Allowed as identifiers (e.g. table, column names),
#  but:
#  - not allowed as SP label names
#  - not allowed as variable names in Oracle-style assignments:
#    xxx := 10;
#
#  If we allowed these variables in assignments, there would be conflicts
#  with SP characteristics, or verb clauses, or compound statements, e.g.:
#    CREATE PROCEDURE p1 LANGUAGE ...
#  would be either:
#    CREATE PROCEDURE p1 LANGUAGE SQL BEGIN END;
#  or
#    CREATE PROCEDURE p1 LANGUAGE:=10;
#
#  Note, these variables can still be assigned using quoted identifiers:
#    `do`:= 10;
#    "do":= 10; (when ANSI_QUOTES)
#  or using a SET statement:
#    SET do= 10;
#
#  Note, some of these keywords are reserved keywords in Oracle.
#  In case if heavy grammar conflicts are found in the future,
#  we'll possibly need to make them reserved for sql_mode=ORACLE.
#
#  TODO: Allow these variables as SP lables when sql_mode=ORACLE.
#  TODO: Allow assigning of "SP characteristics" marked variables
#        inside compound blocks.
#  TODO: Allow "follows" and "precedes" as variables in compound blocks:
#        BEGIN
#          follows := 10;
#        END;
#        as they conflict only with non-block FOR EACH ROW statement:
#          CREATE TRIGGER .. FOR EACH ROW follows:= 10;
#          CREATE TRIGGER .. FOR EACH ROW FOLLOWS tr1 a:= 10;

keyword_sp_head:
          CONTAINS_sym
        | LANGUAGE_sym
        | NO_sym
        | CHARSET
        | FOLLOWS_sym
        | PRECEDES_sym
        ;

#  Keywords that start a statement.
#  Generally allowed as identifiers (e.g. table, column names)
#  - not allowed as SP label names
#  - not allowed as variable names in Oracle-style assignments:
#    xxx:=10

keyword_verb_clause:
          CLOSE_sym
        | COMMIT_sym
        | DO_sym
        | HANDLER_sym
        | OPEN_sym
        | REPAIR
        | ROLLBACK_sym
        | SAVEPOINT_sym
        | SHUTDOWN
        | TRUNCATE_sym
        ;

keyword_set_special_case:
          NAMES_sym
        | ROLE_sym
        | PASSWORD_sym
        ;

keyword_sysvar_type:
          GLOBAL_sym
        | LOCAL_sym
        | SESSION_sym
        ;


#  These keywords are generally allowed as identifiers,
#  but not allowed as non-delimited SP variable names in sql_mode=ORACLE.

keyword_data_type:
          BIT_sym
        | BOOLEAN_sym
        | BOOL_sym
        | CLOB_MARIADB_sym
        | CLOB_ORACLE_sym
        | DATE_sym
        | DATETIME
        | ENUM
        | FIXED_sym
        | JSON_sym
        | MEDIUM_sym
        | NATIONAL_sym
        | NCHAR_sym
        | NUMBER_MARIADB_sym
        | NUMBER_ORACLE_sym
        | NVARCHAR_sym
        | RAW_MARIADB_sym
        | RAW_ORACLE_sym
        | ROW_sym
        | SERIAL_sym
        | TEXT_sym
        | TIMESTAMP
        | TIME_sym
        | VARCHAR2_MARIADB_sym
        | VARCHAR2_ORACLE_sym
        | YEAR_sym
        ;


keyword_cast_type:
          SIGNED_sym
        ;



#  These keywords are fine for both SP variable names and SP labels.

keyword_sp_var_and_label:
          ACTION
        | ACCOUNT_sym
        | ADDDATE_sym
        | ADMIN_sym
        | AFTER_sym
        | AGAINST
        | AGGREGATE_sym
        | ALGORITHM_sym
        | ALWAYS_sym
        | ANY_sym
        | AT_sym
        | ATOMIC_sym
        | AUTHORS_sym
        | AUTO_INC
        | AUTOEXTEND_SIZE_sym
        | AUTO_sym
        | AVG_ROW_LENGTH
        | AVG_sym
        | BLOCK_sym
        | BODY_MARIADB_sym
        | BTREE_sym
        | CASCADED
        | CATALOG_NAME_sym
        | CHAIN_sym
        | CHANGED
        | CIPHER_sym
        | CLIENT_sym
        | CLASS_ORIGIN_sym
        | COALESCE
        | CODE_sym
        | COLLATION_sym
        | COLUMN_NAME_sym
        | COLUMNS
        | COMMITTED_sym
        | COMPACT_sym
        | COMPLETION_sym
        | CONCURRENT
        | CONNECTION_sym
        | CONSISTENT_sym
        | CONSTRAINT_CATALOG_sym
        | CONSTRAINT_SCHEMA_sym
        | CONSTRAINT_NAME_sym
        | CONTEXT_sym
        | CONTRIBUTORS_sym
        | CURRENT_POS_sym
        | CPU_sym
        | CUBE_sym
#          Although a reserved keyword in SQL:2003 (and :2008),
#          not reserved in MySQL per WL#2111 specification.
        | CURRENT_sym
        | CURSOR_NAME_sym
        | CYCLE_sym
        | DATA_sym
        | DATAFILE_sym
        | DATE_FORMAT_sym
        | DAY_sym
        | DECODE_MARIADB_sym
        | DECODE_ORACLE_sym
        | DEFINER_sym
        | DELAY_KEY_WRITE_sym
        | DES_KEY_FILE
        | DIAGNOSTICS_sym
        | DIRECTORY_sym
        | DISABLE_sym
        | DISCARD
        | DISK_sym
        | DUMPFILE
        | DUPLICATE_sym
        | DYNAMIC_sym
        | ELSEIF_ORACLE_sym
        | ELSIF_MARIADB_sym
        | ENDS_sym
        | ENGINE_sym
        | ENGINES_sym
        | ERROR_sym
        | ERRORS
        | ESCAPE_sym
        | EVENT_sym
        | EVENTS_sym
        | EVERY_sym
        | EXCEPTION_MARIADB_sym
        | EXCHANGE_sym
        | EXPANSION_sym
        | EXPIRE_sym
        | EXPORT_sym
        | EXTENDED_sym
        | EXTENT_SIZE_sym
        | FAULTS_sym
        | FAST_sym
        | FOUND_sym
        | ENABLE_sym
        | FEDERATED_sym
        | FULL
        | FILE_sym
        | FIRST_sym
        | GENERAL
        | GENERATED_sym
        | GET_FORMAT
        | GRANTS
        | GOTO_MARIADB_sym
        | HASH_sym
        | HARD_sym
        | HISTORY_sym
        | HOSTS_sym
        | HOUR_sym
        | ID_sym
        | IDENTIFIED_sym
        | IGNORE_SERVER_IDS_sym
        | INCREMENT_sym
        | IMMEDIATE_sym
        | INVOKER_sym
        | IMPORT
        | INDEXES
        | INITIAL_SIZE_sym
        | IO_sym
        | IPC_sym
        | ISOLATION
        | ISOPEN_sym
        | ISSUER_sym
        | INSERT_METHOD
        | INVISIBLE_sym
        | KEY_BLOCK_SIZE
        | LAST_VALUE
        | LAST_sym
        | LASTVAL_sym
        | LEAVES
        | LESS_sym
        | LEVEL_sym
        | LIST_sym
        | LOCKS_sym
        | LOGFILE_sym
        | LOGS_sym
        | MAX_ROWS
        | MASTER_sym
        | MASTER_HEARTBEAT_PERIOD_sym
        | MASTER_GTID_POS_sym
        | MASTER_HOST_sym
        | MASTER_PORT_sym
        | MASTER_LOG_FILE_sym
        | MASTER_LOG_POS_sym
        | MASTER_USER_sym
        | MASTER_USE_GTID_sym
        | MASTER_PASSWORD_sym
        | MASTER_SERVER_ID_sym
        | MASTER_CONNECT_RETRY_sym
        | MASTER_DELAY_sym
        | MASTER_SSL_sym
        | MASTER_SSL_CA_sym
        | MASTER_SSL_CAPATH_sym
        | MASTER_SSL_CERT_sym
        | MASTER_SSL_CIPHER_sym
        | MASTER_SSL_CRL_sym
        | MASTER_SSL_CRLPATH_sym
        | MASTER_SSL_KEY_sym
        | MAX_CONNECTIONS_PER_HOUR
        | MAX_QUERIES_PER_HOUR
        | MAX_SIZE_sym
        | MAX_STATEMENT_TIME_sym
        | MAX_UPDATES_PER_HOUR
        | MAX_USER_CONNECTIONS_sym
        | MEMORY_sym
        | MERGE_sym
        | MESSAGE_TEXT_sym
        | MICROSECOND_sym
        | MIGRATE_sym
        | MINUTE_sym
        | MINVALUE_sym
        | MIN_ROWS
        | MODIFY_sym
        | MODE_sym
        | MONITOR_sym
        | MONTH_sym
        | MUTEX_sym
        | MYSQL_sym
        | MYSQL_ERRNO_sym
        | NAME_sym
        | NEVER_sym
        | NEXT_sym
        | NEXTVAL_sym
        | NEW_sym
        | NOCACHE_sym
        | NOCYCLE_sym
        | NOMINVALUE_sym
        | NOMAXVALUE_sym
        | NO_WAIT_sym
        | NOWAIT_sym
        | NODEGROUP_sym
        | NONE_sym
        | NOTFOUND_sym
        | OF_sym
        | OFFSET_sym
        | OLD_PASSWORD_sym
        | ONE_sym
        | ONLINE_sym
        | ONLY_sym
        | PACKAGE_MARIADB_sym
        | PACK_KEYS_sym
        | PAGE_sym
        | PARTIAL
        | PARTITIONING_sym
        | PARTITIONS_sym
        | PERSISTENT_sym
        | PHASE_sym
        | PLUGIN_sym
        | PLUGINS_sym
        | PRESERVE_sym
        | PREV_sym
        | PREVIOUS_sym
        | PRIVILEGES
        | PROCESS
        | PROCESSLIST_sym
        | PROFILE_sym
        | PROFILES_sym
        | PROXY_sym
        | QUARTER_sym
        | QUERY_sym
        | QUICK
        | RAISE_MARIADB_sym
        | READ_ONLY_sym
        | REBUILD_sym
        | RECOVER_sym
        | REDO_BUFFER_SIZE_sym
        | REDOFILE_sym
        | REDUNDANT_sym
        | RELAY
        | RELAYLOG_sym
        | RELAY_LOG_FILE_sym
        | RELAY_LOG_POS_sym
        | RELAY_THREAD
        | RELOAD
        | REORGANIZE_sym
        | REPEATABLE_sym
        | REPLAY_sym
        | REPLICATION
        | RESOURCES
        | RESTART_sym
        | RESUME_sym
        | RETURNED_SQLSTATE_sym
        | RETURNS_sym
        | REUSE_sym
        | REVERSE_sym
        | ROLLUP_sym
        | ROUTINE_sym
        | ROWCOUNT_sym
        | ROWTYPE_MARIADB_sym
        | ROW_COUNT_sym
        | ROW_FORMAT_sym
        | RTREE_sym
        | SCHEDULE_sym
        | SCHEMA_NAME_sym
        | SECOND_sym
        | SEQUENCE_sym
        | SERIALIZABLE_sym
        | SETVAL_sym
        | SIMPLE_sym
        | SHARE_sym
        | SLAVE_POS_sym
        | SLOW
        | SNAPSHOT_sym
        | SOFT_sym
        | SOUNDS_sym
        | SOURCE_sym
        | SQL_CACHE_sym
        | SQL_BUFFER_RESULT
        | SQL_NO_CACHE_sym
        | SQL_THREAD
        | STAGE_sym
        | STARTS_sym
        | STATEMENT_sym
        | STATUS_sym
        | STORAGE_sym
        | STRING_sym
        | SUBCLASS_ORIGIN_sym
        | SUBDATE_sym
        | SUBJECT_sym
        | SUBPARTITION_sym
        | SUBPARTITIONS_sym
        | SUPER_sym
        | SUSPEND_sym
        | SWAPS_sym
        | SWITCHES_sym
        | SYSTEM
        | SYSTEM_TIME_sym
        | TABLE_NAME_sym
        | TABLES
        | TABLE_CHECKSUM_sym
        | TABLESPACE
        | TEMPORARY
        | TEMPTABLE_sym
        | THAN_sym
        | TRANSACTION_sym
        | TRANSACTIONAL_sym
        | TRIGGERS_sym
        | TRIM_ORACLE
        | TIMESTAMP_ADD
        | TIMESTAMP_DIFF
        | TYPES_sym
        | TYPE_sym
        | UDF_RETURNS_sym
        | UNCOMMITTED_sym
        | UNDEFINED_sym
        | UNDO_BUFFER_SIZE_sym
        | UNDOFILE_sym
        | UNKNOWN_sym
        | UNTIL_sym
        | USER_sym
        | USE_FRM
        | VARIABLES
        | VERSIONING_sym
        | VIEW_sym
        | VIRTUAL_sym
        | VALUE_sym
        | WARNINGS
        | WAIT_sym
        | WEEK_sym
        | WEIGHT_STRING_sym
        | WITHOUT
        | WORK_sym
        | X509_sym
        | XML_sym
        | VIA_sym
        ;


reserved_keyword_udt_not_param_type:
          ACCESSIBLE_sym
        | ADD
        | ALL
        | ALTER
        | ANALYZE_sym
        | AND_sym
        | AS
        | ASC
        | ASENSITIVE_sym
        | BEFORE_sym
        | BETWEEN_sym
        | BIT_AND
        | BIT_OR
        | BIT_XOR
        | BODY_ORACLE_sym
        | BOTH
        | BY
        | CALL_sym
        | CASCADE
        | CASE_sym
        | CAST_sym
        | CHANGE
        | CHECK_sym
        | COLLATE_sym
        | CONSTRAINT
        | CONTINUE_MARIADB_sym
        | CONTINUE_ORACLE_sym
        | CONVERT_sym
        | COUNT_sym
        | CREATE
        | CROSS
        | CUME_DIST_sym
        | CURDATE
        | CURRENT_USER
        | CURRENT_ROLE
        | CURTIME
        | DATABASE
        | DATABASES
        | DATE_ADD_INTERVAL
        | DATE_SUB_INTERVAL
        | DAY_HOUR_sym
        | DAY_MICROSECOND_sym
        | DAY_MINUTE_sym
        | DAY_SECOND_sym
        | DECLARE_MARIADB_sym
        | DECLARE_ORACLE_sym
        | DEFAULT
        | DELETE_DOMAIN_ID_sym
        | DELETE_sym
        | DENSE_RANK_sym
        | DESC
        | DESCRIBE
        | DETERMINISTIC_sym
        | DISTINCT
        | DIV_sym
        | DO_DOMAIN_IDS_sym
        | DROP
        | DUAL_sym
        | EACH_sym
        | ELSE
        | ELSEIF_MARIADB_sym
        | ELSIF_ORACLE_sym
        | ENCLOSED
        | ESCAPED
        | EXCEPT_sym
        | EXISTS
        | EXTRACT_sym
        | FALSE_sym
        | FETCH_sym
        | FIRST_VALUE_sym
        | FOREIGN
        | FROM
        | FULLTEXT_sym
        | GOTO_ORACLE_sym
        | GRANT
        | GROUP_sym
        | GROUP_CONCAT_sym
        | LAG_sym
        | LEAD_sym
        | HAVING
        | HOUR_MICROSECOND_sym
        | HOUR_MINUTE_sym
        | HOUR_SECOND_sym
        | IF_sym
        | IGNORE_DOMAIN_IDS_sym
        | IGNORE_sym
        | INDEX_sym
        | INFILE
        | INNER_sym
        | INSENSITIVE_sym
        | INSERT
        | INTERSECT_sym
        | INTERVAL_sym
        | INTO
        | IS
        | ITERATE_sym
        | JOIN_sym
        | KEYS
        | KEY_sym
        | KILL_sym
        | LEADING
        | LEAVE_sym
        | LEFT
        | LIKE
        | LIMIT
        | LINEAR_sym
        | LINES
        | LOAD
        | LOCATOR_sym
        | LOCK_sym
        | LOOP_sym
        | LOW_PRIORITY
        | MASTER_SSL_VERIFY_SERVER_CERT_sym
        | MATCH
        | MAX_sym
        | MAXVALUE_sym
        | MEDIAN_sym
        | MINUTE_MICROSECOND_sym
        | MINUTE_SECOND_sym
        | MIN_sym
        | MODIFIES_sym
        | MOD_sym
        | NATURAL
        | NEG
        | NOT_sym
        | NOW_sym
        | NO_WRITE_TO_BINLOG
        | NTILE_sym
        | NULL_sym
        | NTH_VALUE_sym
        | ON
        | OPTIMIZE
        | OPTIONALLY
        | ORDER_sym
        | OR_sym
        | OTHERS_ORACLE_sym
        | OUTER
        | OUTFILE
        | OVER_sym
        | PACKAGE_ORACLE_sym
        | PAGE_CHECKSUM_sym
        | PARSE_VCOL_EXPR_sym
        | PARTITION_sym
        | PERCENT_RANK_sym
        | PERCENTILE_CONT_sym
        | PERCENTILE_DISC_sym
        | PORTION_sym
        | POSITION_sym
        | PRECISION
        | PRIMARY_sym
        | PROCEDURE_sym
        | PURGE
        | RAISE_ORACLE_sym
        | RANGE_sym
        | RANK_sym
        | READS_sym
        | READ_sym
        | READ_WRITE_sym
        | RECURSIVE_sym
        | REF_SYSTEM_ID_sym
        | REFERENCES
        | REGEXP
        | RELEASE_sym
        | RENAME
        | REPEAT_sym
        | REPLACE
        | REQUIRE_sym
        | RESIGNAL_sym
        | RESTRICT
        | RETURNING_sym
        | RETURN_MARIADB_sym
        | RETURN_ORACLE_sym
        | REVOKE
        | RIGHT
        | ROWS_sym
        | ROWTYPE_ORACLE_sym
        | ROW_NUMBER_sym
        | SECOND_MICROSECOND_sym
        | SELECT_sym
        | SENSITIVE_sym
        | SEPARATOR_sym
        | SERVER_OPTIONS
        | SHOW
        | SIGNAL_sym
        | SPATIAL_sym
        | SPECIFIC_sym
        | SQLEXCEPTION_sym
        | SQLSTATE_sym
        | SQLWARNING_sym
        | SQL_BIG_RESULT
        | SQL_SMALL_RESULT
        | SQL_sym
        | SSL_sym
        | STARTING
        | STATS_AUTO_RECALC_sym
        | STATS_PERSISTENT_sym
        | STATS_SAMPLE_PAGES_sym
        | STDDEV_SAMP_sym
        | STD_sym
        | STRAIGHT_JOIN
        | SUBSTRING
        | SUM_sym
        | SYSDATE
        | TABLE_REF_PRIORITY
        | TABLE_sym
        | TERMINATED
        | THEN_sym
        | TO_sym
        | TRAILING
        | TRIGGER_sym
        | TRIM
        | TRUE_sym
        | UNDO_sym
        | UNION_sym
        | UNIQUE_sym
        | UNLOCK_sym
        | UPDATE_sym
        | USAGE
        | USE_sym
        | USING
        | UTC_DATE_sym
        | UTC_TIMESTAMP_sym
        | UTC_TIME_sym
        | VALUES
        | VALUES_IN_sym
        | VALUES_LESS_sym
        | VARIANCE_sym
        | VARYING
        | VAR_SAMP_sym
        | WHEN_sym
        | WHERE
        | WHILE_sym
        | WITH
        | XOR
        | YEAR_MONTH_sym
        | ZEROFILL
        ;


#  SQLCOM_SET_OPTION statement.
#
#  Note that to avoid shift/reduce conflicts, we have separate rules for the
#  first option listed in the statement.

set:
          SET
          set_param
          stmt_end
        ;

set_param:
          option_value_no_option_type
        | option_value_no_option_type , option_value_list
        | TRANSACTION_sym
          transaction_characteristics
        | option_type
          start_option_value_list_following_option_type
        | STATEMENT_sym
          set_stmt_option_list
          FOR_sym directly_executable_statement
        ;

set_stmt_option_list:
          set_stmt_option
        | set_stmt_option | set_stmt_option | set_stmt_option
        | set_stmt_option | set_stmt_option | set_stmt_option
        | set_stmt_option | set_stmt_option | set_stmt_option
        | set_stmt_option | set_stmt_option | set_stmt_option
        | set_stmt_option | set_stmt_option | set_stmt_option
        | set_stmt_option_list , set_stmt_option
        ;

# Start of option value list, option_type was given
start_option_value_list_following_option_type:
          option_value_following_option_type
        | option_value_following_option_type , option_value_list
        | TRANSACTION_sym
          transaction_characteristics
        ;

# Repeating list of option values after first option value.
option_value_list:
          option_value
        | option_value | option_value | option_value | option_value
        | option_value | option_value | option_value | option_value
        | option_value | option_value | option_value | option_value
        | option_value | option_value | option_value | option_value
        | option_value | option_value | option_value | option_value
        | option_value_list , option_value
        ;

# Wrapper around option values following the first option value in the stmt.
option_value:
          option_type
          option_value_following_option_type
        | option_value_no_option_type
        ;

option_type:
          GLOBAL_sym
        | LOCAL_sym
        | SESSION_sym
        ;

opt_var_type:

        | GLOBAL_sym
        | LOCAL_sym
        | SESSION_sym
        ;

opt_var_ident_type:

        | GLOBAL_sym .
        | LOCAL_sym .
        | SESSION_sym .
        ;


#  SET STATEMENT options do not need their own LEX or Query_arena.
#  Let's put them to the main ones.

set_stmt_option:
          ident_cli equal set_expr_or_default
        | ident_cli . ident equal set_expr_or_default
        | DEFAULT . ident equal set_expr_or_default
        ;

# Option values with preceding option_type.
option_value_following_option_type:
          ident_cli equal
          set_expr_or_default
        | ident_cli . ident equal
          set_expr_or_default
        | DEFAULT . ident equal
          set_expr_or_default
        ;

# Option values without preceding option_type.
option_value_no_option_type:
          ident_cli_set_usual_case equal
          set_expr_or_default
        | ident_cli_set_usual_case . ident equal
          set_expr_or_default
        | DEFAULT . ident equal
          set_expr_or_default
        | @ident_or_text equal
          expr
        | @@opt_var_ident_type ident_sysvar_name equal
          set_expr_or_default
        | @@opt_var_ident_type ident_sysvar_name . ident equal
          set_expr_or_default
        | @@opt_var_ident_type DEFAULT . ident equal
          set_expr_or_default
        | charset old_or_new_charset_name_or_default
        | NAMES_sym equal expr
        | NAMES_sym charset_name_or_default opt_collate
        | DEFAULT ROLE_sym grant_role
        | DEFAULT ROLE_sym grant_role FOR_sym user
        | ROLE_sym ident_or_text
        | ROLE_sym equal
          set_expr_or_default
        | PASSWORD_sym opt_for_user text_or_password
        ;

transaction_characteristics:
          transaction_access_mode
        | isolation_level
        | transaction_access_mode , isolation_level
        | isolation_level , transaction_access_mode
        ;

transaction_access_mode:
          transaction_access_mode_types
        ;

isolation_level:
          ISOLATION LEVEL_sym isolation_types
        ;

transaction_access_mode_types:
          READ_sym ONLY_sym
        | READ_sym WRITE_sym
        ;

isolation_types:
          READ_sym UNCOMMITTED_sym
        | READ_sym COMMITTED_sym
        | REPEATABLE_sym READ_sym
        | SERIALIZABLE_sym
        ;

opt_for_user:
        equal
        | FOR_sym user equal
        ;

text_or_password:
          TEXT_STRING
        | PASSWORD_sym ( TEXT_STRING )
        | OLD_PASSWORD_sym ( TEXT_STRING )
        ;

set_expr_or_default:
          expr
        | DEFAULT
        | ON
        | ALL
        | BINARY
        ;

lock:
          LOCK_sym table_or_tables
          table_lock_list opt_lock_wait_timeout
        ;

opt_lock_wait_timeout:

        | WAIT_sym ulong_num
        | NOWAIT_sym
      ;

table_or_tables:
          TABLE_sym       
        | TABLES          
        ;

table_lock_list:
          table_lock
        | table_lock | table_lock | table_lock | table_lock | table_lock
        | table_lock | table_lock | table_lock | table_lock | table_lock
        | table_lock | table_lock | table_lock | table_lock | table_lock
        | table_lock | table_lock | table_lock | table_lock | table_lock
        | table_lock_list , table_lock
        ;

table_lock:
          table_ident opt_table_alias_clause lock_option
        ;

lock_option:
          READ_sym
        | WRITE_sym
        | WRITE_sym CONCURRENT
        | LOW_PRIORITY WRITE_sym
        | READ_sym LOCAL_sym
        ;

unlock:
          UNLOCK_sym
          table_or_tables
        ;

# Handler: direct access to ISAM functions

handler:
          HANDLER_sym
          handler_tail
        ;

handler_tail:
          table_ident OPEN_sym opt_table_alias_clause
        | table_ident_nodb CLOSE_sym
        | table_ident_nodb READ_sym
          handler_read_or_scan opt_where_clause opt_global_limit_clause
        ;

handler_read_or_scan:
          handler_scan_function
        | ident handler_rkey_function
        ;

handler_scan_function:
          FIRST_sym
        | NEXT_sym
        ;

handler_rkey_function:
          FIRST_sym
        | NEXT_sym
        | PREV_sym
        | LAST_sym
        | handler_rkey_mode
          ( values )
         
        ;

handler_rkey_mode:
          =
        | GE
        | LE
        | >
        | <
        ;

# GRANT / REVOKE

revoke:
          REVOKE clear_privileges revoke_command
        ;

revoke_command:
          grant_privileges ON opt_table grant_ident FROM user_and_role_list
        | grant_privileges ON sp_handler grant_ident FROM user_and_role_list
        | ALL opt_privileges , GRANT OPTION FROM user_and_role_list
        | PROXY_sym ON user FROM user_list
        | admin_option_for_role FROM user_and_role_list
        ;

admin_option_for_role:
        ADMIN_sym OPTION FOR_sym grant_role
      | grant_role
      ;

grant:
          GRANT clear_privileges grant_command
        ;

grant_command:
          grant_privileges ON opt_table grant_ident TO_sym grant_list
          opt_require_clause opt_grant_options
        | grant_privileges ON sp_handler grant_ident TO_sym grant_list
          opt_require_clause opt_grant_options
        | PROXY_sym ON user TO_sym grant_list opt_grant_option
        | grant_role TO_sym grant_list opt_with_admin_option
        ;

opt_with_admin:

        | WITH ADMIN_sym user_or_role
        ;

opt_with_admin_option:

        | WITH ADMIN_sym OPTION
        ;

role_list:
          grant_role
        | grant_role | grant_role | grant_role | grant_role | grant_role 
        | grant_role | grant_role | grant_role | grant_role | grant_role 
        | grant_role | grant_role | grant_role | grant_role | grant_role 
        | grant_role | grant_role | grant_role | grant_role | grant_role 
        | grant_role | grant_role | grant_role | grant_role | grant_role 
        | role_list , grant_role
        ;

current_role:
          CURRENT_ROLE optional_braces
          ;

grant_role:
          ident_or_text
        | current_role
        ;

opt_table:

        | TABLE_sym
        ;

grant_privileges:
          object_privilege_list
        | ALL opt_privileges
        ;

opt_privileges:

        | PRIVILEGES
        ;

object_privilege_list:
          object_privilege
        | object_privilege | object_privilege | object_privilege
        | object_privilege | object_privilege | object_privilege
        | object_privilege | object_privilege | object_privilege
        | column_list_privilege
        | column_list_privilege | column_list_privilege
        | column_list_privilege | column_list_privilege
        | column_list_privilege | column_list_privilege
        | column_list_privilege | column_list_privilege
        | object_privilege_list , object_privilege
        | object_privilege_list , column_list_privilege
        ;

column_list_privilege:
          column_privilege ( comma_separated_ident_list )
        ;

column_privilege:
          SELECT_sym
        | INSERT
        | UPDATE_sym
        | REFERENCES
        ;

object_privilege:
          SELECT_sym
        | INSERT
        | UPDATE_sym
        | REFERENCES
        | DELETE_sym
        | USAGE
        | INDEX_sym
        | ALTER
        | CREATE
        | DROP
        | EXECUTE_sym
        | RELOAD
        | SHUTDOWN
        | PROCESS
        | FILE_sym
        | GRANT OPTION
        | SHOW DATABASES
        | SUPER_sym
        | CREATE TEMPORARY TABLES
        | LOCK_sym TABLES
        | REPLICATION SLAVE
        | REPLICATION CLIENT_sym
        | CREATE VIEW_sym
        | SHOW VIEW_sym
        | CREATE ROUTINE_sym
        | ALTER ROUTINE_sym
        | CREATE USER_sym
        | EVENT_sym
        | TRIGGER_sym
        | CREATE TABLESPACE
        | DELETE_sym HISTORY_sym
        | SET USER_sym
        | FEDERATED_sym ADMIN_sym
        | CONNECTION_sym ADMIN_sym
        | READ_sym ONLY_sym ADMIN_sym
        | READ_ONLY_sym ADMIN_sym
        | BINLOG_sym MONITOR_sym
        | BINLOG_sym ADMIN_sym
        | BINLOG_sym REPLAY_sym
        | REPLICATION MASTER_sym ADMIN_sym
        | REPLICATION SLAVE ADMIN_sym
        ;

opt_and:

        | AND_sym
        ;

require_list:
          require_list_element opt_and require_list
        | require_list_element
        | require_list_element | require_list_element
        | require_list_element | require_list_element
        | require_list_element | require_list_element
        | require_list_element | require_list_element
        | require_list_element | require_list_element
        ;

require_list_element:
          SUBJECT_sym TEXT_STRING
        | ISSUER_sym TEXT_STRING
        | CIPHER_sym TEXT_STRING
        ;

grant_ident:
          *
        | ident . *
        | * . *
        | table_ident
        ;

user_list:
          user
        | user | user | user | user | user | user | user | user | user
        | user_list , user
        ;

grant_list:
          grant_user
        | grant_user | grant_user | grant_user | grant_user | grant_user 
        | grant_list , grant_user
        ;

user_and_role_list:
          user_or_role
        | user_or_role | user_or_role | user_or_role | user_or_role
        | user_or_role | user_or_role | user_or_role | user_or_role
        | user_and_role_list , user_or_role
        ;

via_or_with:
          VIA_sym
        | WITH
        ;

using_or_as:
          USING
        | AS
        ;

grant_user:
          user IDENTIFIED_sym BY TEXT_STRING
        | user IDENTIFIED_sym BY PASSWORD_sym TEXT_STRING
        | user IDENTIFIED_sym via_or_with auth_expression
        | user_or_role
        ;

auth_expression:
          auth_token OR_sym auth_expression
        | auth_token
        ;

auth_token:
          ident_or_text opt_auth_str
        ;

opt_auth_str:

      | using_or_as TEXT_STRING_sys
      | using_or_as PASSWORD_sym ( TEXT_STRING )
      ;

opt_require_clause:

        | REQUIRE_sym require_list
        | REQUIRE_sym SSL_sym
        | REQUIRE_sym X509_sym
        | REQUIRE_sym NONE_sym
        ;

resource_option:
        MAX_QUERIES_PER_HOUR ulong_num
        | MAX_UPDATES_PER_HOUR ulong_num
        | MAX_CONNECTIONS_PER_HOUR ulong_num
        | MAX_USER_CONNECTIONS_sym int_num
        | MAX_STATEMENT_TIME_sym NUM_literal
        ;

resource_option_list:
        resource_option_list resource_option
        | resource_option
        | resource_option | resource_option | resource_option
        | resource_option | resource_option | resource_option
        | resource_option | resource_option | resource_option
        | resource_option | resource_option | resource_option
        ;

opt_resource_options:

        | WITH resource_option_list
        ;

opt_grant_options:

        | WITH grant_option_list
        ;

opt_grant_option:

        | WITH GRANT OPTION
        ;

grant_option_list:
          grant_option_list grant_option
        | grant_option
        | grant_option | grant_option | grant_option | grant_option
        | grant_option | grant_option | grant_option | grant_option
        | grant_option | grant_option | grant_option | grant_option
        ;

grant_option:
          GRANT OPTION
        | resource_option
        ;

begin_stmt_mariadb:
          BEGIN_MARIADB_sym
          opt_work
          ;

compound_statement:
          sp_proc_stmt_compound_ok
        ;

opt_not:

        | not
        ;

opt_work:
        | WORK_sym
        ;

opt_chain:

        | AND_sym NO_sym CHAIN_sym
        | AND_sym CHAIN_sym
        ;

opt_release:

        | RELEASE_sym
        | NO_sym RELEASE_sym
        ;

commit:
          COMMIT_sym opt_work opt_chain opt_release
        ;

# ES TODO: AND CHAIN RELEASE is disallowed by hack
rollback:
          ROLLBACK_sym opt_work opt_chain opt_release
        | ROLLBACK_sym opt_work TO_sym SAVEPOINT_sym ident
        | ROLLBACK_sym opt_work TO_sym ident
        ;

savepoint:
          SAVEPOINT_sym ident
        ;

release:
          RELEASE_sym SAVEPOINT_sym ident
        ;

#   UNIONS : glue selects together

unit_type_decl:
          UNION_sym union_option
        | INTERSECT_sym union_option
        | EXCEPT_sym union_option
        ;

#  Start a UNION, for non-top level query expressions.

union_option:

        | DISTINCT
        | ALL
        ;

query_expression_option:
          STRAIGHT_JOIN
        | HIGH_PRIORITY
        | DISTINCT
        | UNIQUE_sym
        | SQL_SMALL_RESULT
        | SQL_BIG_RESULT
        | SQL_BUFFER_RESULT
        | SQL_CALC_FOUND_ROWS
        | ALL
        ;

#
#
# DEFINER clause support.
#
#

definer_opt:
          no_definer
        | definer
        ;

no_definer:

        ;

definer:
          DEFINER_sym = user_or_role
        ;

#
#
# CREATE VIEW statement parts.
#
#

view_algorithm:
          ALGORITHM_sym = UNDEFINED_sym
        | ALGORITHM_sym = MERGE_sym
        | ALGORITHM_sym = TEMPTABLE_sym
        ;

opt_view_suid:

        | view_suid
        ;

view_suid:
          SQL_sym SECURITY_sym DEFINER_sym
        | SQL_sym SECURITY_sym INVOKER_sym
        ;

view_list_opt:

        | ( view_list )
        ;

view_list:
          ident
        | ident | ident | ident | ident | ident | ident | ident | ident
        | view_list , ident
        ;

view_select:
          query_expression
          view_check_option
        ;

view_check_option:

        | WITH CHECK_sym OPTION
        | WITH CASCADED CHECK_sym OPTION
        | WITH LOCAL_sym CHECK_sym OPTION
        ;

#
#
# CREATE TRIGGER statement parts.
#
#

trigger_action_order:
            FOLLOWS_sym
          | PRECEDES_sym
          ;

trigger_follows_precedes_clause:

          |
            trigger_action_order ident_or_text
          ;

trigger_tail:
          remember_name
          opt_if_not_exists
          sp_name
          trg_action_time
          trg_event
          ON
          remember_name
          table_ident
          FOR_sym
          remember_name
          EACH_sym
          ROW_sym
          trigger_follows_precedes_clause
          sp_proc_stmt
        ;

#
#
# CREATE FUNCTION | PROCEDURE statements parts.
#
#

sf_return_type:
          type_with_opt_collate
        ;


xa:
          XA_sym begin_or_start xid opt_join_or_resume
        | XA_sym END xid opt_suspend
        | XA_sym PREPARE_sym xid
        | XA_sym COMMIT_sym xid opt_one_phase
        | XA_sym ROLLBACK_sym xid
        | XA_sym RECOVER_sym opt_format_xid
        ;

opt_format_xid:

        | FORMAT_sym = ident_or_text
        ;

xid:
          text_string
          | text_string , text_string
          | text_string , text_string , ulong_num
        ;

begin_or_start:
          BEGIN_MARIADB_sym
        | BEGIN_ORACLE_sym
        | START_sym
        ;

opt_join_or_resume:

        | JOIN_sym
        | RESUME_sym
        ;

opt_one_phase:

        | ONE_sym PHASE_sym
        ;

opt_suspend:

        | SUSPEND_sym
          opt_migrate
        ;

opt_migrate:

        | FOR_sym MIGRATE_sym
        ;

install:
          INSTALL_sym PLUGIN_sym opt_if_not_exists ident SONAME_sym TEXT_STRING_sys
        | INSTALL_sym SONAME_sym TEXT_STRING_sys
        ;

uninstall:
          UNINSTALL_sym PLUGIN_sym opt_if_exists ident
        | UNINSTALL_sym SONAME_sym opt_if_exists TEXT_STRING_sys
        ;

#
keep_gcc_happy:
          IMPOSSIBLE_ACTION
        ;

_empty:

        ;

###############################################
# Start SQL_MODE_DEFAULT_SPECIFIC
#
### SQL_MODE_ORACLE_SPECIFIC rules
### are defined in a separate redefine grammar
###############################################

statement:
          verb_clause
        ;

sp_statement:
          statement
        ;

sp_if_then_statements:
          sp_proc_stmts1
        ;

sp_case_then_statements:
          sp_proc_stmts1
        ;

reserved_keyword_udt_param_type:
          INOUT_sym
        | IN_sym
        | OUT_sym
        ;

reserved_keyword_udt:
          reserved_keyword_udt_not_param_type
        | reserved_keyword_udt_param_type
        ;

# Keywords that start an SP block section
keyword_sp_block_section:
          BEGIN_MARIADB_sym
        | END
        ;

# Keywords that we allow for labels in SPs.
# Should not include keywords that start a statement or SP characteristics.
keyword_label:
          keyword_data_type
        | keyword_set_special_case
        | keyword_sp_var_and_label
        | keyword_sysvar_type
        | FUNCTION_sym
        | EXCEPTION_ORACLE_sym
        ;

keyword_sp_decl:
          keyword_data_type
        | keyword_cast_type
        | keyword_set_special_case
        | keyword_sp_block_section
        | keyword_sp_head
        | keyword_sp_var_and_label
        | keyword_sp_var_not_label
        | keyword_sysvar_type
        | keyword_verb_clause
        | FUNCTION_sym
        | WINDOW_sym
        ;

opt_truncate_table_storage_clause:
          _empty
        ;


ident_for_loop_index:
          ident
        ;

row_field_name:
          ident
        ;

while_body:
          expr_lex DO_sym
          sp_proc_stmts1 END WHILE_sym
        ;

for_loop_statements:
          DO_sym sp_proc_stmts1 END FOR_sym
        ;

sp_label:
          label_ident :
        ;

sp_control_label:
          sp_label
        ;

sp_block_label:
          sp_label
        ;

sp_opt_default:
          _empty
        | DEFAULT expr
        ;

sp_pdparam:
          sp_parameter_type sp_param_name_and_type
        | sp_param_name_and_type
        ;

sp_decl_variable_list_anchored:
          sp_decl_idents_init_vars
          TYPE_sym OF_sym optionally_qualified_column_ident
          sp_opt_default
        | sp_decl_idents_init_vars
          ROW_sym TYPE_sym OF_sym optionally_qualified_column_ident
          sp_opt_default
        ;

sp_param_name_and_type_anchored:
          sp_param_name TYPE_sym OF_sym ident . ident
        | sp_param_name TYPE_sym OF_sym ident . ident . ident
        | sp_param_name ROW_sym TYPE_sym OF_sym ident
        | sp_param_name ROW_sym TYPE_sym OF_sym ident . ident
        ;


sf_c_chistics_and_body_standalone:
          sp_c_chistics
          sp_proc_stmt_in_returns_clause
        ;

sp_tail_standalone:
          sp_name
          sp_parenthesized_pdparam_list
          sp_c_chistics
          sp_proc_stmt
        ;

drop_routine:
          DROP FUNCTION_sym opt_if_exists ident . ident
        | DROP FUNCTION_sym opt_if_exists ident
        | DROP PROCEDURE_sym opt_if_exists sp_name
        ;


create_routine:
          create_or_replace definer_opt PROCEDURE_sym opt_if_not_exists
          sp_tail_standalone
        | create_or_replace definer opt_aggregate FUNCTION_sym opt_if_not_exists
        | create_or_replace no_definer opt_aggregate FUNCTION_sym opt_if_not_exists
          sp_name
          sp_parenthesized_fdparam_list
          RETURNS_sym sf_return_type
          sf_c_chistics_and_body_standalone
        | create_or_replace no_definer opt_aggregate FUNCTION_sym opt_if_not_exists
          ident RETURNS_sym udf_type SONAME_sym TEXT_STRING_sys
        ;


sp_decls:
          _empty
        | sp_decls sp_decl { ';' }
        ;

sp_decl:
          DECLARE_MARIADB_sym sp_decl_body
        ;


sp_decl_body:
          sp_decl_variable_list
        | sp_decl_ident CONDITION_sym FOR_sym sp_cond
        | sp_decl_handler
        | sp_decl_ident CURSOR_sym
          opt_parenthesized_cursor_formal_parameters
          FOR_sym sp_cursor_stmt
        ;



#  ps_proc_stmt_in_returns_clause is a statement that is allowed
#  in the RETURNS clause of a stored function definition directly,
#  without the BEGIN..END  block.
#  It should not include any syntax structures starting with (, to avoid
#  shift/reduce conflicts with the rule "field_type" and its sub-rules
#  that scan an optional length, like CHAR(1) or YEAR(4).
#  See MDEV-9166.

sp_proc_stmt_in_returns_clause:
          sp_proc_stmt_return
        | sp_labeled_block
        | sp_unlabeled_block
        | sp_labeled_control
        | sp_proc_stmt_compound_ok
        ;

# Redefined in *-redefine-oracle.yy
# TODO ES: Is it even right?
sp_proc_stmt:
          sp_proc_stmt_in_returns_clause
        | sp_proc_stmt_statement
#        | sp_proc_stmt_continue_oracle
#        | sp_proc_stmt_exit_oracle
        | sp_proc_stmt_leave
        | sp_proc_stmt_iterate
#        | sp_proc_stmt_goto_oracle
        | sp_proc_stmt_with_cursor
        ;

sp_proc_stmt_compound_ok:
          sp_proc_stmt_if
        | case_stmt_specification
        | sp_unlabeled_block_not_atomic
        | sp_unlabeled_control
        ;


sp_labeled_block:
          sp_block_label
          BEGIN_MARIADB_sym
          sp_decls
          sp_proc_stmts
          END
          sp_opt_label
        ;

sp_unlabeled_block:
          BEGIN_MARIADB_sym
          sp_decls
          sp_proc_stmts
          END
        ;

sp_unlabeled_block_not_atomic:
          BEGIN_MARIADB_sym not ATOMIC_sym
          sp_decls
          sp_proc_stmts
          END
        ;


######################################
# End of sql_yacc.yy
######################################

######################################
# Additions
######################################

#
# From sql_lex.cc (rephrased)
#

BEGIN_ORACLE_sym:
    BEGIN_MARIADB_sym ;

BLOB_ORACLE_sym:
    BLOB_MARIADB_sym ;

BODY_ORACLE_sym:
    BODY_MARIADB_sym ;

CLOB_ORACLE_sym:
    CLOB_MARIADB_sym ;

# TODO ES: Redefined in *-redefine-oracle.yy. I hope it is right
COLON_ORACLE_sym:
    ;

CONTINUE_ORACLE_sym:
    CONTINUE_MARIADB_sym ;

DECLARE_ORACLE_sym:
    DECLARE_MARIADB_sym ;

DECODE_ORACLE_sym:
    DECODE_MARIADB_sym ;

ELSEIF_ORACLE_sym:
    ELSEIF_MARIADB_sym ;

ELSIF_ORACLE_sym:
    ELSIF_MARIADB_sym ;

EXCEPTION_ORACLE_sym:
    EXCEPTION_MARIADB_sym ;

EXIT_ORACLE_sym:
    EXIT_MARIADB_sym ;

GOTO_ORACLE_sym:
    GOTO_MARIADB_sym ;

LEFT_PAREN_WITH:
    ( ;

NUMBER_ORACLE_sym:
    NUMBER_MARIADB_sym ;

ORACLE_CONCAT_sym:
    MYSQL_CONCAT_sym ;

OTHERS_ORACLE_sym:
    OTHERS_MARIADB_sym ;

PACKAGE_ORACLE_sym:
    PACKAGE_MARIADB_sym ;

PERCENT_ORACLE_sym:
    % ;

RAISE_ORACLE_sym:
    RAISE_MARIADB_sym ;

RAW_ORACLE_sym:
    RAW_MARIADB_sym ;

RETURN_ORACLE_sym:
    RETURN_MARIADB_sym ;

ROWTYPE_ORACLE_sym:
    ROWTYPE_MARIADB_sym ;

VARCHAR2_ORACLE_sym:
    VARCHAR2_MARIADB_sym ;

#
# From lex.h
#

AND_AND_sym:
    && ;

LE:
    <= ;

NE:
    <>
    | != ;

GE:
    >= ;

SHIFT_LEFT:
    << ;

SHIFT_RIGHT:
    >> ;

EQUAL_sym:
    <=> ;

ACCESSIBLE_sym:
    ACCESSIBLE ;

ACCOUNT_sym:
    ACCOUNT ;

ADMIN_sym:
    ADMIN ;

AFTER_sym:
    AFTER ;

AGGREGATE_sym:
    AGGREGATE ;

ALGORITHM_sym:
    ALGORITHM ;

ALWAYS_sym:
    ALWAYS ;

ANALYZE_sym:
    ANALYZE ;

AND_sym:
    AND ;

ANY_sym:
    ANY
    | SOME
    ;

ASCII_sym:
    ASCII ;

ASENSITIVE_sym:
    ASENSITIVE ;

AT_sym:
    AT ;

ATOMIC_sym:
    ATOMIC ;

AUTHORS_sym:
    AUTHORS ;

AUTO_INC:
    AUTO_INCREMENT ;

AUTOEXTEND_SIZE_sym:
    AUTOEXTEND_SIZE ;

AUTO_sym:
    AUTO ;

AVG_sym:
    AVG ;

BACKUP_sym:
    BACKUP ;

BEFORE_sym:
    BEFORE ;

BEGIN_MARIADB_sym:
    BEGIN ;

BETWEEN_sym:
    BETWEEN ;

BINLOG_sym:
    BINLOG ;

BIT_sym:
    BIT ;

BLOB_MARIADB_sym:
    BLOB ;

BLOCK_sym:
    BLOCK ;

BODY_MARIADB_sym:
    BODY ;

BOOL_sym:
    BOOL ;

BOOLEAN_sym:
    BOOLEAN ;

BTREE_sym:
    BTREE ;

BYTE_sym:
    BYTE ;

CACHE_sym:
    CACHE ;

CALL_sym:
    CALL ;

CASE_sym:
    CASE ;

CATALOG_NAME_sym:
    CATALOG_NAME ;

CHAIN_sym:
    CHAIN ;

CHAR_sym:
    CHAR
    | CHARACTER
    ;

CHECK_sym:
    CHECK ;

CHECKPOINT_sym:
    CHECKPOINT ;

CHECKSUM_sym:
    CHECKSUM ;

CIPHER_sym:
    CIPHER ;

CLASS_ORIGIN_sym:
    CLASS_ORIGIN ;

CLIENT_sym:
    CLIENT ;

CLOB_MARIADB_sym:
    CLOB ;

CLOSE_sym:
    CLOSE ;

CODE_sym:
    CODE ;

COLLATE_sym:
    COLLATE ;

COLLATION_sym:
    COLLATION ;

COLUMN_sym:
    COLUMN ;

COLUMN_NAME_sym:
    COLUMN_NAME ;

COLUMN_ADD_sym:
    COLUMN_ADD ;

COLUMN_CHECK_sym:
    COLUMN_CHECK ;

COLUMN_CREATE_sym:
    COLUMN_CREATE ;

COLUMN_DELETE_sym:
    COLUMN_DELETE ;

COLUMN_GET_sym:
    COLUMN_GET ;

COMMENT_sym:
    COMMENT ;

COMMIT_sym:
    COMMIT ;

COMMITTED_sym:
    COMMITTED ;

COMPACT_sym:
    COMPACT ;

COMPLETION_sym:
    COMPLETION ;

COMPRESSED_sym:
    COMPRESSED ;

CONDITION_sym:
    CONDITION ;

CONNECTION_sym:
    CONNECTION ;

CONSISTENT_sym:
    CONSISTENT ;

CONSTRAINT_CATALOG_sym:
    CONSTRAINT_CATALOG ;

CONSTRAINT_NAME_sym:
    CONSTRAINT_NAME ;

CONSTRAINT_SCHEMA_sym:
    CONSTRAINT_SCHEMA ;

CONTAINS_sym:
    CONTAINS ;

CONTEXT_sym:
    CONTEXT ;

CONTINUE_MARIADB_sym:
    CONTINUE ;

CONTRIBUTORS_sym:
    CONTRIBUTORS ;

CONVERT_sym:
    CONVERT ;

CPU_sym:
    CPU ;

CUBE_sym:
    CUBE ;

CURRENT_sym:
    CURRENT ;

CURDATE:
    CURRENT_DATE ;

CURRENT_POS_sym:
    CURRENT_POS ;

CURTIME:
    CURRENT_TIME ;

CURSOR_sym:
    CURSOR ;

CURSOR_NAME_sym:
    CURSOR_NAME ;

CYCLE_sym:
    CYCLE ;

DATA_sym:
    DATA ;

DATAFILE_sym:
    DATAFILE ;

DATE_sym:
    DATE ;

DAY_sym:
    DAY
    | SQL_TSI_DAY
    ;

DAY_HOUR_sym:
    DAY_HOUR ;

DAY_MICROSECOND_sym:
    DAY_MICROSECOND ;

DAY_MINUTE_sym:
    DAY_MINUTE ;

DAY_SECOND_sym:
    DAY_SECOND ;

DEALLOCATE_sym:
    DEALLOCATE ;

DECIMAL_sym:
    DEC
    | DECIMAL
    ;

DECLARE_MARIADB_sym:
    DECLARE ;

DEFINER_sym:
    DEFINER ;

DELAYED_sym:
    DELAYED ;

DELAY_KEY_WRITE_sym:
    DELAY_KEY_WRITE ;

DELETE_sym:
    DELETE ;

DELETE_DOMAIN_ID_sym:
    DELETE_DOMAIN_ID ;

DETERMINISTIC_sym:
    DETERMINISTIC ;

DIAGNOSTICS_sym:
    DIAGNOSTICS ;

DIRECTORY_sym:
    DIRECTORY ;

DISABLE_sym:
    DISABLE ;

DISK_sym:
    DISK ;

DISTINCT:
    DISTINCTROW ;

DIV_sym:
    DIV ;

DO_sym:
    DO ;

DOUBLE_sym:
    DOUBLE
    | FLOAT8
    ;

DO_DOMAIN_IDS_sym:
    DO_DOMAIN_IDS ;

DUAL_sym:
    DUAL ;

DUPLICATE_sym:
    DUPLICATE ;

DYNAMIC_sym:
    DYNAMIC ;

EACH_sym:
    EACH ;

ELSEIF_MARIADB_sym:
    ELSEIF
    | ELSIF
    ;

ENABLE_sym:
    ENABLE ;

ENDS_sym:
    ENDS ;

ENGINE_sym:
    ENGINE ;

ENGINES_sym:
    ENGINES ;

ERROR_sym:
    ERROR ;

ESCAPE_sym:
    ESCAPE ;

EVENT_sym:
    EVENT ;

EVENTS_sym:
    EVENTS ;

EVERY_sym:
    EVERY ;

EXAMINED_sym:
    EXAMINED ;

EXCEPT_sym:
    EXCEPT ;

EXCHANGE_sym:
    EXCHANGE ;

EXCLUDE_sym:
    EXCLUDE ;

EXECUTE_sym:
    EXECUTE ;

EXCEPTION_MARIADB_sym:
    EXCEPTION ;

EXIT_MARIADB_sym:
    EXIT ;

EXPANSION_sym:
    EXPANSION ;

EXPIRE_sym:
    EXPIRE ;

EXPORT_sym:
    EXPORT ;

DESCRIBE:
    EXPLAIN ;

EXTENDED_sym:
    EXTENDED ;

EXTENT_SIZE_sym:
    EXTENT_SIZE ;

FALSE_sym:
    FALSE ;

FAST_sym:
    FAST ;

FAULTS_sym:
    FAULTS ;

FEDERATED_sym:
    FEDERATED ;

FETCH_sym:
    FETCH ;

COLUMNS:
    FIELDS ;

FILE_sym:
    FILE ;

FIRST_sym:
    FIRST ;

FIXED_sym:
    FIXED ;

FLOAT_sym:
    FLOAT
    | FLOAT4
    ;

FLUSH_sym:
    FLUSH ;

FOLLOWING_sym:
    FOLLOWING ;

FOLLOWS_sym:
    FOLLOWS ;

FOR_sym:
    FOR ;

FORCE_sym:
    FORCE ;

FORMAT_sym:
    FORMAT ;

FOUND_sym:
    FOUND ;

FULLTEXT_sym:
    FULLTEXT ;

FUNCTION_sym:
    FUNCTION ;

GENERATED_sym:
    GENERATED ;

GET_sym:
    GET ;

GLOBAL_sym:
    GLOBAL ;

GOTO_MARIADB_sym:
    GOTO ;

GROUP_sym:
    GROUP ;

HANDLER_sym:
    HANDLER ;

HARD_sym:
    HARD ;

HASH_sym:
    HASH ;

HELP_sym:
    HELP ;

HISTORY_sym:
    HISTORY ;

HOST_sym:
    HOST ;

HOSTS_sym:
    HOSTS ;

HOUR_sym:
    HOUR
    | SQL_TSI_HOUR ;

HOUR_MICROSECOND_sym:
    HOUR_MICROSECOND ;

HOUR_MINUTE_sym:
    HOUR_MINUTE ;

HOUR_SECOND_sym:
    HOUR_SECOND ;

ID_sym:
    ID ;

IDENTIFIED_sym:
    IDENTIFIED ;

IF_sym:
    IF ;

IGNORE_sym:
    IGNORE ;

IGNORE_DOMAIN_IDS_sym:
    IGNORE_DOMAIN_IDS ;

IGNORE_SERVER_IDS_sym:
    IGNORE_SERVER_IDS ;

IMMEDIATE_sym:
    IMMEDIATE ;

INTERSECT_sym:
    INTERSECT ;

IN_sym:
    IN ;

INCREMENT_sym:
    INCREMENT ;

INDEX_sym:
    INDEX ;

INITIAL_SIZE_sym:
    INITIAL_SIZE ;

INNER_sym:
    INNER ;

INOUT_sym:
    INOUT ;

INSENSITIVE_sym:
    INSENSITIVE ;

INSTALL_sym:
    INSTALL ;

INT_sym:
    INT
    | INT4
    | INTEGER
    ;


TINYINT:
    INT1 ;

SMALLINT:
    INT2 ;

BIGINT:
    INT8 ;

INTERVAL_sym:
    INTERVAL ;

INVISIBLE_sym:
    INVISIBLE ;

IO_sym:
    IO ;

RELAY_THREAD:
    IO_THREAD ;

IPC_sym:
    IPC ;

ISOPEN_sym:
    ISOPEN ;

ISSUER_sym:
    ISSUER ;

ITERATE_sym:
    ITERATE ;

INVOKER_sym:
    INVOKER ;

JOIN_sym:
    JOIN ;

JSON_sym:
    JSON ;

KEY_sym:
    KEY ;

KILL_sym:
    KILL ;

LANGUAGE_sym:
    LANGUAGE ;

LAST_sym:
    LAST ;

LASTVAL_sym:
    LASTVAL ;

LEAVE_sym:
    LEAVE ;

LESS_sym:
    LESS ;

LEVEL_sym:
    LEVEL ;

LINEAR_sym:
    LINEAR ;

LIST_sym:
    LIST ;

LOCAL_sym:
    LOCAL ;

LOCK_sym:
    LOCK ;

LOCKS_sym:
    LOCKS ;

LOGFILE_sym:
    LOGFILE ;

LOGS_sym:
    LOGS ;

LONG_sym:
    LONG ;

LOOP_sym:
    LOOP ;

MASTER_sym:
    MASTER ;

MASTER_CONNECT_RETRY_sym:
    MASTER_CONNECT_RETRY ;

MASTER_DELAY_sym:
    MASTER_DELAY ;

MASTER_GTID_POS_sym:
    MASTER_GTID_POS ;

MASTER_HOST_sym:
    MASTER_HOST ;

MASTER_LOG_FILE_sym:
    MASTER_LOG_FILE ;

MASTER_LOG_POS_sym:
    MASTER_LOG_POS ;

MASTER_PASSWORD_sym:
    MASTER_PASSWORD ;

MASTER_PORT_sym:
    MASTER_PORT ;

MASTER_SERVER_ID_sym:
    MASTER_SERVER_ID ;

MASTER_SSL_sym:
    MASTER_SSL ;

MASTER_SSL_CA_sym:
    MASTER_SSL_CA ;

MASTER_SSL_CAPATH_sym:
    MASTER_SSL_CAPATH ;

MASTER_SSL_CERT_sym:
    MASTER_SSL_CERT ;

MASTER_SSL_CIPHER_sym:
    MASTER_SSL_CIPHER ;

MASTER_SSL_CRL_sym:
    MASTER_SSL_CRL ;

MASTER_SSL_CRLPATH_sym:
    MASTER_SSL_CRLPATH ;

MASTER_SSL_KEY_sym:
    MASTER_SSL_KEY ;

MASTER_SSL_VERIFY_SERVER_CERT_sym:
    MASTER_SSL_VERIFY_SERVER_CERT ;

MASTER_USER_sym:
    MASTER_USER ;

MASTER_USE_GTID_sym:
    MASTER_USE_GTID ;

MASTER_HEARTBEAT_PERIOD_sym:
    MASTER_HEARTBEAT_PERIOD ;

MAX_SIZE_sym:
    MAX_SIZE ;

MAX_STATEMENT_TIME_sym:
    MAX_STATEMENT_TIME ;

MAX_USER_CONNECTIONS_sym:
    MAX_USER_CONNECTIONS ;

MAXVALUE_sym:
    MAXVALUE ;

MEDIUMINT:
    MIDDLEINT
    | INT3
    ;

MEDIUM_sym:
    MEDIUM ;

MEMORY_sym:
    MEMORY ;

MERGE_sym:
    MERGE ;

MESSAGE_TEXT_sym:
    MESSAGE_TEXT ;

MICROSECOND_sym:
    MICROSECOND ;

MIGRATE_sym:
    MIGRATE ;

MINUTE_sym:
    MINUTE
    | SQL_TSI_MINUTE
    ;

MINUTE_MICROSECOND_sym:
    MINUTE_MICROSECOND ;

MINUTE_SECOND_sym:
    MINUTE_SECOND ;

MINVALUE_sym:
    MINVALUE ;

MOD_sym:
    MOD ;

MODE_sym:
    MODE ;

MODIFIES_sym:
    MODIFIES ;

MODIFY_sym:
    MODIFY ;

MONITOR_sym:
    MONITOR ;

MONTH_sym:
    MONTH
    | SQL_TSI_MONTH
    ;

MUTEX_sym:
    MUTEX ;

MYSQL_sym:
    MYSQL ;

MYSQL_ERRNO_sym:
    MYSQL_ERRNO ;

NAME_sym:
    NAME ;

NAMES_sym:
    NAMES ;

NATIONAL_sym:
    NATIONAL ;

NCHAR_sym:
    NCHAR ;

NEVER_sym:
    NEVER ;

NEW_sym:
    NEW ;

NEXT_sym:
    NEXT ;

NEXTVAL_sym:
    NEXTVAL ;

NO_sym:
    NO ;

NOMAXVALUE_sym:
    NOMAXVALUE ;

NOMINVALUE_sym:
    NOMINVALUE ;

NOCACHE_sym:
    NOCACHE ;

NOCYCLE_sym:
    NOCYCLE ;

NO_WAIT_sym:
    NO_WAIT ;

NOWAIT_sym:
    NOWAIT ;

NODEGROUP_sym:
    NODEGROUP ;

NONE_sym:
    NONE ;

NOT_sym:
    NOT ;

#NOT2_sym:
#    NOT_sym ;

NOTFOUND_sym:
    NOTFOUND ;

NOW_sym:
    CURRENT_TIMESTAMP
    | NOW
    | LOCALTIME
    | LOCALTIMESTAMP
    ;

NULL_sym:
    NULL ;

NUMBER_MARIADB_sym:
    NUMBER ;

NUMERIC_sym:
    NUMERIC ;

NVARCHAR_sym:
    NVARCHAR ;

OF_sym:
    OF ;

OFFSET_sym:
    OFFSET ;

OLD_PASSWORD_sym:
    OLD_PASSWORD ;

ONE_sym:
    ONE ;

ONLINE_sym:
    ONLINE ;

ONLY_sym:
    ONLY ;

OPEN_sym:
    OPEN ;

OPTIONS_sym:
    OPTIONS ;

OR_sym:
    OR ;

ORDER_sym:
    ORDER ;

OTHERS_MARIADB_sym:
    OTHERS ;

OUT_sym:
    OUT ;

OVER_sym:
    OVER ;

OWNER_sym:
    OWNER ;

PACKAGE_MARIADB_sym:
    PACKAGE ;

PACK_KEYS_sym:
    PACK_KEYS ;

PAGE_sym:
    PAGE ;

PAGE_CHECKSUM_sym:
    PAGE_CHECKSUM ;

PARSER_sym:
    PARSER ;

PARSE_VCOL_EXPR_sym:
    PARSE_VCOL_EXPR ;

PERIOD_sym:
    PERIOD ;

PARTITION_sym:
    PARTITION ;

PARTITIONING_sym:
    PARTITIONING ;

PARTITIONS_sym:
    PARTITIONS ;

PASSWORD_sym:
    PASSWORD ;

PERSISTENT_sym:
    PERSISTENT ;

PHASE_sym:
    PHASE ;

PLUGIN_sym:
    PLUGIN ;

PLUGINS_sym:
    PLUGINS ;

PORT_sym:
    PORT ;

PORTION_sym:
    PORTION ;

PRECEDES_sym:
    PRECEDES ;

PRECEDING_sym:
    PRECEDING ;

PREPARE_sym:
    PREPARE ;

PRESERVE_sym:
    PRESERVE ;

PREV_sym:
    PREV ;

PREVIOUS_sym:
    PREVIOUS ;

PRIMARY_sym:
    PRIMARY ;

PROCEDURE_sym:
    PROCEDURE ;

PROCESSLIST_sym:
    PROCESSLIST ;

PROFILE_sym:
    PROFILE ;

PROFILES_sym:
    PROFILES ;

PROXY_sym:
    PROXY ;

QUARTER_sym:
    QUARTER
    | SQL_TSI_QUARTER
    ;

QUERY_sym:
    QUERY ;

RAISE_MARIADB_sym:
    RAISE ;

RANGE_sym:
    RANGE ;

RAW_MARIADB_sym:
    RAW ;

READ_sym:
    READ ;

READ_ONLY_sym:
    READ_ONLY ;

READ_WRITE_sym:
    READ_WRITE ;

READS_sym:
    READS ;

REBUILD_sym:
    REBUILD ;

RECOVER_sym:
    RECOVER ;

RECURSIVE_sym:
    RECURSIVE ;

REDO_BUFFER_SIZE_sym:
    REDO_BUFFER_SIZE ;

REDOFILE_sym:
    REDOFILE ;

REDUNDANT_sym:
    REDUNDANT ;

RELAYLOG_sym:
    RELAYLOG ;

RELAY_LOG_FILE_sym:
    RELAY_LOG_FILE ;

RELAY_LOG_POS_sym:
    RELAY_LOG_POS ;

RELEASE_sym:
    RELEASE ;

REMOVE_sym:
    REMOVE ;

REORGANIZE_sym:
    REORGANIZE ;

REPEATABLE_sym:
    REPEATABLE ;

REPLAY_sym:
    REPLAY ;

SLAVE:
    REPLICA ;

SLAVES:
    REPLICAS ;

REPEAT_sym:
    REPEAT ;

REQUIRE_sym:
    REQUIRE ;

RESET_sym:
    RESET ;

RESIGNAL_sym:
    RESIGNAL ;

RESTART_sym:
    RESTART ;

RESTORE_sym:
    RESTORE ;

RESUME_sym:
    RESUME ;

RETURNED_SQLSTATE_sym:
    RETURNED_SQLSTATE ;

RETURN_MARIADB_sym:
    RETURN ;

RETURNING_sym:
    RETURNING ;

RETURNS_sym:
    RETURNS ;

REUSE_sym:
    REUSE ;

REVERSE_sym:
    REVERSE ;

REGEXP:
    RLIKE ;

ROLE_sym:
    ROLE ;

ROLLBACK_sym:
    ROLLBACK ;

ROLLUP_sym:
    ROLLUP ;

ROUTINE_sym:
    ROUTINE ;

ROW_sym:
    ROW ;

ROWCOUNT_sym:
    ROWCOUNT ;

ROWS_sym:
    ROWS ;

ROWTYPE_MARIADB_sym:
    ROWTYPE ;

ROW_COUNT_sym:
    ROW_COUNT ;

ROW_FORMAT_sym:
    ROW_FORMAT ;

RTREE_sym:
    RTREE ;

SAVEPOINT_sym:
    SAVEPOINT ;

SCHEDULE_sym:
    SCHEDULE ;

DATABASE:
    SCHEMA ;

SCHEMA_NAME_sym:
    SCHEMA_NAME ;

DATABASES:
    SCHEMAS ;

SECOND_sym:
    SECOND
    | SQL_TSI_SECOND
    ;

SECOND_MICROSECOND_sym:
    SECOND_MICROSECOND ;

SECURITY_sym:
    SECURITY ;

SELECT_sym:
    SELECT ;

SENSITIVE_sym:
    SENSITIVE ;

SEPARATOR_sym:
    SEPARATOR ;

SEQUENCE_sym:
    SEQUENCE ;

SERIAL_sym:
    SERIAL ;

SERIALIZABLE_sym:
    SERIALIZABLE ;

SESSION_sym:
    SESSION ;

SERVER_sym:
    SERVER ;

SETVAL_sym:
    SETVAL ;

SHARE_sym:
    SHARE ;

SIGNAL_sym:
    SIGNAL ;

SIGNED_sym:
    SIGNED ;

SIMPLE_sym:
    SIMPLE ;

SLAVE_POS_sym:
    SLAVE_POS
    | REPLICA_POS
    ;

SNAPSHOT_sym:
    SNAPSHOT ;

SOCKET_sym:
    SOCKET ;

SOFT_sym:
    SOFT ;

SONAME_sym:
    SONAME ;

SOUNDS_sym:
    SOUNDS ;

SOURCE_sym:
    SOURCE ;

STAGE_sym:
    STAGE ;

STORED_sym:
    STORED ;

SPATIAL_sym:
    SPATIAL ;

SPECIFIC_sym:
    SPECIFIC ;

REF_SYSTEM_ID_sym:
    REF_SYSTEM_ID ;

SQL_sym:
    SQL ;

SQLEXCEPTION_sym:
    SQLEXCEPTION ;

SQLSTATE_sym:
    SQLSTATE ;

SQLWARNING_sym:
    SQLWARNING ;

SQL_CACHE_sym:
    SQL_CACHE ;

SQL_NO_CACHE_sym:
    SQL_NO_CACHE ;

SSL_sym:
    SSL ;

START_sym:
    START ;

STARTS_sym:
    STARTS ;

STATEMENT_sym:
    STATEMENT ;

STATS_AUTO_RECALC_sym:
    STATS_AUTO_RECALC ;

STATS_PERSISTENT_sym:
    STATS_PERSISTENT ;

STATS_SAMPLE_PAGES_sym:
    STATS_SAMPLE_PAGES ;

STATUS_sym:
    STATUS ;

STOP_sym:
    STOP ;

STORAGE_sym:
    STORAGE ;

STRING_sym:
    STRING ;

SUBCLASS_ORIGIN_sym:
    SUBCLASS_ORIGIN ;

SUBJECT_sym:
    SUBJECT ;

SUBPARTITION_sym:
    SUBPARTITION ;

SUBPARTITIONS_sym:
    SUBPARTITIONS ;

SUPER_sym:
    SUPER ;

SUSPEND_sym:
    SUSPEND ;

SWAPS_sym:
    SWAPS ;

SWITCHES_sym:
    SWITCHES ;

SYSTEM_TIME_sym:
    SYSTEM_TIME ;

TABLE_sym:
    TABLE ;

TABLE_NAME_sym:
    TABLE_NAME ;

TABLE_CHECKSUM_sym:
    TABLE_CHECKSUM ;

TEMPTABLE_sym:
    TEMPTABLE ;

TEXT_sym:
    TEXT ;

THAN_sym:
    THAN ;

THEN_sym:
    THEN ;

TIES_sym:
    TIES ;

TIME_sym:
    TIME ;

TIMESTAMP_ADD:
    TIMESTAMPADD ;

TIMESTAMP_DIFF:
    TIMESTAMPDIFF ;

TO_sym:
    TO ;

TRANSACTION_sym:
    TRANSACTION ;

TRANSACTIONAL_sym:
    TRANSACTIONAL ;

TRIGGER_sym:
    TRIGGER ;

TRIGGERS_sym:
    TRIGGERS ;

TRUE_sym:
    TRUE ;

TRUNCATE_sym:
    TRUNCATE ;

TYPE_sym:
    TYPE ;

TYPES_sym:
    TYPES ;

UNBOUNDED_sym:
    UNBOUNDED ;

UNCOMMITTED_sym:
    UNCOMMITTED ;

UNDEFINED_sym:
    UNDEFINED ;

UNDO_BUFFER_SIZE_sym:
    UNDO_BUFFER_SIZE ;

UNDOFILE_sym:
    UNDOFILE ;

UNDO_sym:
    UNDO ;

UNICODE_sym:
    UNICODE ;

UNION_sym:
    UNION ;

UNIQUE_sym:
    UNIQUE ;

UNKNOWN_sym:
    UNKNOWN ;

UNLOCK_sym:
    UNLOCK ;

UNINSTALL_sym:
    UNINSTALL ;

UNTIL_sym:
    UNTIL ;

UPDATE_sym:
    UPDATE ;

UPGRADE_sym:
    UPGRADE ;

USE_sym:
    USE ;

# TODO ES: What is static SYMBOL sql_functions in sql/lex.h ?
USER_sym:
    USER
#    | SESSION_USER
#    | SYSTEM_USER
    ;

RESOURCES:
    USER_RESOURCES ;

UTC_DATE_sym:
    UTC_DATE ;

UTC_TIME_sym:
    UTC_TIME ;

UTC_TIMESTAMP_sym:
    UTC_TIMESTAMP ;

VALUE_sym:
    VALUE ;

VARCHAR:
    VARCHARACTER ;

VARCHAR2_MARIADB_sym:
    VARCHAR2 ;

VIA_sym:
    VIA ;

VIEW_sym:
    VIEW ;

VIRTUAL_sym:
    VIRTUAL ;

VERSIONING_sym:
    VERSIONING ;

WAIT_sym:
    WAIT ;

WEEK_sym:
    WEEK
    | SQL_TSI_WEEK
    ;

WEIGHT_STRING_sym:
    WEIGHT_STRING ;

WHEN_sym:
    WHEN ;

WHILE_sym:
    WHILE ;

WINDOW_sym:
    WINDOW ;

WORK_sym:
    WORK ;

WRAPPER_sym:
    WRAPPER ;

WRITE_sym:
    WRITE ;

X509_sym:
    X509 ;


XA_sym:
    XA ;

XML_sym:
    XML ;

YEAR_sym:
    YEAR
    | SQL_TSI_YEAR
    ;

YEAR_MONTH_sym:
    YEAR_MONTH ;

#OR2_sym:
#    || ;

ADDDATE_sym:
    ADDDATE ;

CAST_sym:
    CAST ;

COUNT_sym:
    COUNT ;

CUME_DIST_sym:
    CUME_DIST ;

DATE_ADD_INTERVAL:
    DATE_ADD ;

DATE_SUB_INTERVAL:
    DATE_SUB ;

DATE_FORMAT_sym:
    DATE_FORMAT ;

DECODE_MARIADB_sym:
    DECODE ;

DENSE_RANK_sym:
    DENSE_RANK ;

EXTRACT_sym:
    EXTRACT ;

FIRST_VALUE_sym:
    FIRST_VALUE ;

GROUP_CONCAT_sym:
    GROUP_CONCAT ;

JSON_ARRAYAGG_sym:
    JSON_ARRAYAGG ;

JSON_OBJECTAGG_sym:
    JSON_OBJECTAGG ;

LAG_sym:
    LAG ;

LEAD_sym:
    LEAD ;

MAX_sym:
    MAX ;

MEDIAN_sym:
    MEDIAN ;

MIN_sym:
    MIN ;

NTH_VALUE_sym:
    NTH_VALUE ;

NTILE_sym:
    NTILE ;

POSITION_sym:
    POSITION ;

PERCENT_RANK_sym:
    PERCENT_RANK ;

PERCENTILE_CONT_sym:
    PERCENTILE_CONT ;

PERCENTILE_DISC_sym:
    PERCENTILE_DISC ;

RANK_sym:
    RANK ;

ROW_NUMBER_sym:
    ROW_NUMBER ;

STD_sym:
    STD
    | STDDEV
    | STDDEV_POP
    ;

STDDEV_SAMP_sym:
    STDDEV_SAMP ;

SUBDATE_sym:
    SUBDATE ;

SUBSTRING:
    SUBSTR
    | MID
    ;

SUM_sym:
    SUM ;

VARIANCE_sym:
    VARIANCE
    | VAR_POP
    ;

VAR_SAMP_sym:
    VAR_SAMP ;

#
# From sql/gen_lex_token.cc (rephrased)
#

NEG:
    ~
    ;

WITH_CUBE_sym:
    WITH CUBE
    ;

WITH_ROLLUP_sym:
    WITH ROLLUP
    ;

WITH_SYSTEM_sym:
    WITH SYSTEM
    ;

FOR_SYSTEM_TIME_sym:
    FOR SYSTEM_TIME
    ;

VALUES_IN_sym:
    VALUES IN
    ;

VALUES_LESS_sym:
    VALUES LESS
    ;

#NOT2_sym:
#    !
#    ;

#OR2_sym:
#    |
#    ;

PARAM_MARKER:
    ?
    ;

SET_VAR:
    :=
    ;

UNDERSCORE_CHARSET:
    _charset
    ;

END_OF_INPUT:
    ;

BIN_NUM:
#    (bin)
    _binary
    ;

DECIMAL_NUM:
#    (decimal)
    _decimal
    ;

FLOAT_NUM:
#    (float)
    _float
    ;

HEX_NUM:
#    (hex)
    _hex
    ;

LEX_HOSTNAME:
#    (hostname)
    _identifier
    ;

LONG_NUM:
#    (long)
    _bigint
    ;

NUM:
#    (num)
    _int | _float
    ;

# TODO ES: extend
TEXT_STRING:
#    (text)
    _char(16)
    ;

# TODO ES: extend
NCHAR_STRING:
#    (nchar)
    _char(16)
    ;

ULONGLONG_NUM:
#    (ulonglong)
    _bigint_unsigned
    ;

IDENT:
#    (id)
    _identifier
    ;

# TODO ES: expand
IDENT_QUOTED:
#    (id_quoted)
    _identifier_quoted
##### MY ADDITIONS, NOT A PART OF OFFICIAL GRAMMAR!
    | _table | _table | _table | _table | _table | _table | _table
    | _table | _table | _table | _table | _table | _table | _table
    | _field | _field | _field | _field | _field | _field | _field
    | _field | _field | _field | _field | _field | _field | _field
    ;

LOCATOR_sym:
    LOCATOR
    ;

UDF_RETURNS_sym:
    UDF_RETURNS
    ;

####################################
# Temporary guesses, possibly wrong
####################################

MYSQL_CONCAT_sym:
# pipe symbol
    { chr(124) } ;

OR2_sym:
# pipe symbol | double pipe
    { chr(124) } | { chr(124).chr(124) } ;

NOT2_sym:
    NOT_sym ;

HEX_STRING:
    _hex ;

####################################
# Internal technical additions
####################################

DECIMAL_NUM_unsigned:
    _decimal_unsigned
    ;

FLOAT_NUM_unsigned:
    _float_unsigned
    ;

LONG_NUM_unsigned:
    _bigint_unsigned
    ;

NUM_unsigned:
    _int_unsigned
    ;

