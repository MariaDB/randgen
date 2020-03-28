# SQL_MODE_ORACLE_SPECIFIC

statement:
          verb_clause
        | set_assign
        ;

sp_statement:
          statement
        | ident_cli_directly_assignable
          opt_sp_cparam_list
        | ident_cli_directly_assignable . ident
          opt_sp_cparam_list
        ;

sp_if_then_statements:
          sp_proc_stmts1_implicit_block
        ;

sp_case_then_statements:
          sp_proc_stmts1_implicit_block
        ;

reserved_keyword_udt:
          reserved_keyword_udt_not_param_type
        ;

# Keywords that start an SP block section.
keyword_sp_block_section:
          BEGIN_ORACLE_sym
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
        | COMPRESSED_sym
        | EXCEPTION_ORACLE_sym
        ;

keyword_sp_decl:
          keyword_sp_head
        | keyword_set_special_case
        | keyword_sp_var_and_label
        | keyword_sp_var_not_label
        | keyword_sysvar_type
        | keyword_verb_clause
        | WINDOW_sym
        ;

opt_truncate_table_storage_clause:
          _empty
        | DROP STORAGE_sym
        | REUSE_sym STORAGE_sym
        ;


ident_for_loop_index:
          ident_directly_assignable
        ;

row_field_name:
          ident_directly_assignable
        ;

while_body:
          expr_lex LOOP_sym
          sp_proc_stmts1 END LOOP_sym
        ;

for_loop_statements:
          LOOP_sym sp_proc_stmts1 END LOOP_sym
        ;


sp_control_label:
          labels_declaration_oracle
        ;

sp_block_label:
          labels_declaration_oracle
        ;


remember_end_opt:
        ;

sp_opt_default:
          _empty
        | DEFAULT expr
        | SET_VAR expr
        ;

sp_opt_inout:
          _empty
        | sp_parameter_type
        | IN_sym OUT_sym
        ;

sp_pdparam:
          sp_param_name sp_opt_inout type_with_opt_collate
        | sp_param_name sp_opt_inout sp_decl_ident . ident PERCENT_ORACLE_sym TYPE_sym
        | sp_param_name sp_opt_inout sp_decl_ident . ident . ident PERCENT_ORACLE_sym TYPE_sym
        | sp_param_name sp_opt_inout sp_decl_ident PERCENT_ORACLE_sym ROWTYPE_ORACLE_sym
        | sp_param_name sp_opt_inout sp_decl_ident . ident PERCENT_ORACLE_sym ROWTYPE_ORACLE_sym
        | sp_param_name sp_opt_inout ROW_sym row_type_body
        ;


sp_proc_stmts1_implicit_block:
          sp_proc_stmts1
        ;


remember_lex:
        ;

keyword_directly_assignable:
          keyword_data_type
        | keyword_cast_type
        | keyword_set_special_case
        | keyword_sp_var_and_label
        | keyword_sp_var_not_label
        | keyword_sysvar_type
        | FUNCTION_sym
        | WINDOW_sym
        ;

ident_directly_assignable:
          IDENT_sys
        | keyword_directly_assignable
        ;

ident_cli_directly_assignable:
          IDENT_cli
        | keyword_directly_assignable
        ;


set_assign:
          ident_cli_directly_assignable SET_VAR
          set_expr_or_default
        | ident_cli_directly_assignable . ident SET_VAR
          set_expr_or_default
        | COLON_ORACLE_sym ident . ident SET_VAR
          set_expr_or_default
        ;


labels_declaration_oracle:
          label_declaration_oracle
        | labels_declaration_oracle label_declaration_oracle
        ;

label_declaration_oracle:
          SHIFT_LEFT label_ident SHIFT_RIGHT
        ;

opt_exception_clause:
          _empty
        | EXCEPTION_ORACLE_sym
        ;

exception_handlers:
           exception_handler
         | exception_handlers exception_handler
        ;

exception_handler:
          WHEN_sym
          sp_hcond_list
          THEN_sym
          sp_proc_stmts1_implicit_block
        ;

sp_no_param:
          _empty
        ;

opt_sp_parenthesized_fdparam_list:
          sp_no_param
        | sp_parenthesized_fdparam_list
        ;

opt_sp_parenthesized_pdparam_list:
          sp_no_param
        | sp_parenthesized_pdparam_list
        ;


opt_sp_name:
          _empty
        | sp_name
        ;


opt_package_routine_end_name:
          _empty
        | ident
        ;

sp_tail_is:
          IS
        | AS
        ;

sp_instr_addr:

        ;

sp_body:
          opt_sp_decl_body_list
          BEGIN_ORACLE_sym
          sp_block_statements_and_exceptions
          END
        ;

create_package_chistic:
          COMMENT_sym TEXT_STRING_sys
        | sp_suid
        ;

create_package_chistics:
          create_package_chistic
        | create_package_chistics create_package_chistic
        ;

opt_create_package_chistics:
          _empty
        | create_package_chistics
        ;

opt_create_package_chistics_init:
          opt_create_package_chistics
        ;


package_implementation_executable_section:
          END
        | BEGIN_ORACLE_sym sp_block_statements_and_exceptions END
        ;


#  Inside CREATE PACKAGE BODY, package-wide items (e.g. variables)
#  must be declared before routine definitions.

package_implementation_declare_section:
          package_implementation_declare_section_list1
        | package_implementation_declare_section_list2
        | package_implementation_declare_section_list1
          package_implementation_declare_section_list2
        ;

package_implementation_declare_section_list1:
          package_implementation_item_declaration
        | package_implementation_declare_section_list1
          package_implementation_item_declaration
        ;

package_implementation_declare_section_list2:
          package_implementation_routine_definition
        | package_implementation_declare_section_list2
          package_implementation_routine_definition
        ;

package_routine_lex:
        ;


package_specification_function:
          remember_lex package_routine_lex ident
          opt_sp_parenthesized_fdparam_list
          RETURN_ORACLE_sym sf_return_type
          sp_c_chistics
        ;

package_specification_procedure:
          remember_lex package_routine_lex ident
          opt_sp_parenthesized_pdparam_list
          sp_c_chistics
        ;


package_implementation_routine_definition:
          FUNCTION_sym package_specification_function
                       package_implementation_function_body   { ';' }
        | PROCEDURE_sym package_specification_procedure
                        package_implementation_procedure_body { ';' }
        | package_specification_element
        ;


package_implementation_function_body:
          sp_tail_is remember_lex
          sp_body opt_package_routine_end_name
        ;

package_implementation_procedure_body:
          sp_tail_is remember_lex
          sp_body opt_package_routine_end_name
        ;


package_implementation_item_declaration:
          sp_decl_variable_list { ';' }
        ;

opt_package_specification_element_list:
          _empty
        | package_specification_element_list
        ;

package_specification_element_list:
          package_specification_element
        | package_specification_element_list package_specification_element
        ;

package_specification_element:
          FUNCTION_sym package_specification_function { ';' }
        | PROCEDURE_sym package_specification_procedure { ';' }
        ;

sp_decl_variable_list_anchored:
          sp_decl_idents_init_vars
          optionally_qualified_column_ident PERCENT_ORACLE_sym TYPE_sym
          sp_opt_default
        | sp_decl_idents_init_vars
          optionally_qualified_column_ident PERCENT_ORACLE_sym ROWTYPE_ORACLE_sym
          sp_opt_default
        ;

sp_param_name_and_type_anchored:
          sp_param_name sp_decl_ident . ident PERCENT_ORACLE_sym TYPE_sym
        | sp_param_name sp_decl_ident . ident . ident PERCENT_ORACLE_sym TYPE_sym
        | sp_param_name sp_decl_ident PERCENT_ORACLE_sym ROWTYPE_ORACLE_sym
        | sp_param_name sp_decl_ident . ident PERCENT_ORACLE_sym ROWTYPE_ORACLE_sym
        ;


sf_c_chistics_and_body_standalone:
          sp_c_chistics
          sp_tail_is
          sp_body
        ;

sp_tail_standalone:
          sp_name
          opt_sp_parenthesized_pdparam_list
          sp_c_chistics
          sp_tail_is
          sp_body
          opt_sp_name
        ;

drop_routine:
          DROP FUNCTION_sym opt_if_exists ident . ident
        | DROP FUNCTION_sym opt_if_exists ident
        | DROP PROCEDURE_sym opt_if_exists sp_name
        | DROP PACKAGE_ORACLE_sym opt_if_exists sp_name
        | DROP PACKAGE_ORACLE_sym BODY_ORACLE_sym opt_if_exists sp_name
        ;


create_routine:
          create_or_replace definer_opt PROCEDURE_sym opt_if_not_exists
          sp_tail_standalone
        | create_or_replace definer opt_aggregate FUNCTION_sym opt_if_not_exists
          sp_name
          opt_sp_parenthesized_fdparam_list
          RETURN_ORACLE_sym sf_return_type
          sf_c_chistics_and_body_standalone
          opt_sp_name
        | create_or_replace no_definer opt_aggregate FUNCTION_sym opt_if_not_exists
          sp_name
          opt_sp_parenthesized_fdparam_list
          RETURN_ORACLE_sym sf_return_type
          sf_c_chistics_and_body_standalone
          opt_sp_name
        | create_or_replace no_definer opt_aggregate FUNCTION_sym opt_if_not_exists
          ident RETURNS_sym udf_type SONAME_sym TEXT_STRING_sys
        | create_or_replace definer_opt PACKAGE_ORACLE_sym
          opt_if_not_exists sp_name opt_create_package_chistics_init
          sp_tail_is
          remember_name
          opt_package_specification_element_list END
          remember_end_opt opt_sp_name
        | create_or_replace definer_opt PACKAGE_ORACLE_sym BODY_ORACLE_sym
          opt_if_not_exists sp_name opt_create_package_chistics_init
          sp_tail_is
          remember_name
          package_implementation_declare_section
          package_implementation_executable_section
          remember_end_opt opt_sp_name
        ;

opt_sp_decl_body_list:
          _empty
        | sp_decl_body_list
        ;

sp_decl_body_list:
          sp_decl_non_handler_list
          opt_sp_decl_handler_list
        | sp_decl_handler_list
        ;

sp_decl_non_handler_list:
          sp_decl_non_handler { ';' }
        | sp_decl_non_handler_list sp_decl_non_handler { ';' }
        ;

sp_decl_handler_list:
          sp_decl_handler { ';' }
        | sp_decl_handler_list sp_decl_handler { ';' }
        ;

opt_sp_decl_handler_list:
          _empty
        | sp_decl_handler_list
        ;

sp_decl_non_handler:
          sp_decl_variable_list
        | ident_directly_assignable CONDITION_sym FOR_sym sp_cond
        | ident_directly_assignable EXCEPTION_ORACLE_sym
        | CURSOR_sym ident_directly_assignable
          opt_parenthesized_cursor_formal_parameters
          IS sp_cursor_stmt
        ;


sp_proc_stmt:
          sp_labeled_block
        | sp_unlabeled_block
        | sp_labeled_control
        | sp_unlabeled_control
        | sp_labelable_stmt
        | labels_declaration_oracle sp_labelable_stmt
        ;

sp_labelable_stmt:
          sp_proc_stmt_statement
        | sp_proc_stmt_continue_oracle
        | sp_proc_stmt_exit_oracle
        | sp_proc_stmt_leave
        | sp_proc_stmt_iterate
        | sp_proc_stmt_goto_oracle
        | sp_proc_stmt_with_cursor
        | sp_proc_stmt_return
        | sp_proc_stmt_if
        | case_stmt_specification
        | NULL_sym
        ;

sp_proc_stmt_compound_ok:
          sp_proc_stmt_if
        | case_stmt_specification
        | sp_unlabeled_block
        | sp_unlabeled_control
        ;


sp_labeled_block:
          sp_block_label
          BEGIN_ORACLE_sym
          sp_block_statements_and_exceptions
          END
          sp_opt_label
        | sp_block_label
          DECLARE_ORACLE_sym
          sp_decl_body_list
          BEGIN_ORACLE_sym
          sp_block_statements_and_exceptions
          END
          sp_opt_label
        ;

opt_not_atomic:
          _empty
        | not ATOMIC_sym
        ;

sp_unlabeled_block:
          BEGIN_ORACLE_sym opt_not_atomic
          sp_block_statements_and_exceptions
          END
        | DECLARE_ORACLE_sym
          sp_decl_body_list
          BEGIN_ORACLE_sym
          sp_block_statements_and_exceptions
          END
        ;

sp_block_statements_and_exceptions:
          sp_instr_addr
          sp_proc_stmts
          opt_exception_clause
        ;

###########################################
# Redefines:
###########################################

COLON_ORACLE_sym:
    : ;

sp_handler:
          FUNCTION_sym
        | PROCEDURE_sym
        | PACKAGE_ORACLE_sym
        | PACKAGE_ORACLE_sym BODY_ORACLE_sym
        ;
