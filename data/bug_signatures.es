# Bug signatures for recognizing known bugs by server and test logs

##############################################################################
# Strong matches
##############################################################################

MENT-368:
=~ Assertion \`inline_mysql_file_tell(.*, file, (myf) (0)) == base_pos+ (16 + 5\*8 + 6\*4 + 11\*2 + 6 + 5\*2 + 1 + 16)'
=~ maria_create
=~ create_internal_tmp_table
MENT-361:
=~ AddressSanitizer: heap-use-after-free
=~ filter_query_type
=~ log_statement
=~ Prepared_statement
MENT-328:
=~ mariabackup: File '.*seq.*MAI' not found (Errcode: 2 "No such file or directory")
=~ Error on aria table file open .*seq.*MAI
=~ Version: '10\.3|Version: '10\.4
MENT-328:
=~ scenario=MariaBackup
=~ For  BASE TABLE ROW_FORMAT= .* : Error : Can't find file: '.*seq.*MAI' (errno: 2 "No such file or directory")
=~ status STATUS_BACKUP_FAILURE
=~ Version: '10\.3|Version: '10\.4
MENT-319:
=~ Assertion \`backup_flush_ticket == 0'
=~ backup_start
MENT-264:
=~ Error on file .*\.M.* open during .* table copy
MENT-263:
=~ server_audit2
=~ Assertion \`global_status_var\.global_memory_used == 0'
=~ mysqld_exit
=~ Version: '10\.4
MENT-189:
=~ InnoDB: Failing assertion: opt_no_lock
=~ recv_parse_log_recs
=~ xtrabackup_copy_log
MENT-189:
=~ Failing assertion: opt_no_lock
=~ backup_file_op_fail
=~ fil_name_parse
=~ recv_parse_or_apply_log_rec_body
#
# Fixed in the next release
#
MDEV-21899:
=~ Not applying DELETE_ROW_FORMAT_DYNAMIC due to corruption on
=~ Version: '10\.5
MDEV-21850:
=~ AddressSanitizer:
=~ page_cur_insert_rec_low
=~ page_cur_tuple_insert
=~ Version: '10\.5
# Currently in 10.5e due to rebase, but not in 10.4e yet
MDEV-21792:
=~ signal 8|AddressSanitizer: FPE
=~ dict_index_add_to_cache|os_file_create_simple_func
=~ create_index|prep_alter_part_table
=~ Version: '10\.4
# Currently in 10.5e due to rebase, but not in 10.4e yet
MDEV-20370:
=~ Assertion \`mtr->get_log_mode() == MTR_LOG_NO_REDO'
=~ page_cur_insert_rec_write_log
=~ Version: '10\.2|Version: '10\.3|Version: '10\.4
# Currently in 10.5e due to rebase, but not in 10.4e yet
MDEV-21658:
=~ Assertion \`log->blobs'
=~ row_log_table_apply_update
=~ ha_innobase::inplace_alter_table
=~ Version: '10\.4
# Currently in 10.5e due to rebase, but not in 10.4e yet
MDEV-21658:
=~ Assertion \`extra_size \|\| !is_instant'
=~ row_log_table_apply_op
=~ ha_innobase::inplace_alter_table
=~ Version: '10\.2|Version: '10\.3|Version: '10\.4
# Currently in 10.5e due to rebase, but not in 10.4e yet
MDEV-21645:
=~ AddressSanitizer:|signal 11
=~ innobase_get_computed_value
=~ row_merge_read_clustered_index
=~ ha_innobase::inplace_alter_table
=~ Version: '10\.4
# Currently in 10.5e due to rebase, but not in 10.4e yet
MDEV-21564:
=~ Assertion \`srv_undo_sources \|\| trx->undo_no == 0 \|\| (!purge_sys\.enabled() && (srv_is_being_started \|\| trx_rollback_is_active \|\| srv_force_recovery >= SRV_FORCE_NO_BACKGROUND)) \|\| ((trx->mysql_thd \|\| trx->internal) && srv_fast_shutdown)'|Assertion \`srv_undo_sources \|\| trx->undo_no == 0 \|\| ((srv_is_being_started \|\| trx_rollback_or_clean_is_active) && purge_sys->state == PURGE_STATE_INIT) \|\| (srv_force_recovery >= SRV_FORCE_NO_BACKGROUND && purge_sys->state == PURGE_STATE_DISABLED) \|\| ((trx->in_mysql_trx_list \|\| trx->internal) && srv_fast_shutdown)'
=~ trx_purge_add_undo_to_history
=~ trx_write_serialisation_history
=~ fts_optimize_words|dict_table_close|kill_server
=~ Version: '10\.2|Version: '10\.3|Version: '10\.4
# Currently in 10.5e due to rebase, but not in 10.4e yet
MDEV-21550:
=~ Assertion \`!table->fts->in_queue'|InnoDB: Failing assertion: !table->fts->in_queue
=~ fts_optimize_remove_table
=~ row_drop_table_for_mysql
=~ Version: '10\.2|Version: '10\.3|Version: '10\.4
# Currently in 10.5e due to rebase, but not in 10.4e yet
MDEV-17844:
=~ Assertion \`ulint(rec) == offsets[2]'
=~ rec_offs_validate
=~ page_zip_write_trx_id_and_roll_ptr
=~ row_undo
=~ Version: '10\.2|Version: '10\.3|Version: '10\.4

##############################################################################
# Weak matches
##############################################################################

#
# Fixed in the next release
#
