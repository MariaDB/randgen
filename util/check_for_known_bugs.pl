# Returns 0 if known bugs have been found, and 1 otherwise
# Non-option arguments are the files to check first, typically
# server error logs, stack traces and such.
# Files provided as option --last <file> (possibly multiple files)
# are to check last, if the arguments didn't help to detect anything

#!/usr/bin/perl

use DBI;
use Getopt::Long;
use strict;

my @last_choice_files= ();

GetOptions (
  "last=s@" => \@last_choice_files,
);

# If a file with an exact name does not exist, it will prevent grep from working.
# So, we want to exclude such files

my @expected_files= glob "@ARGV";
my @files;
map { push @files, $_ if -e $_ } @expected_files;

if (scalar @last_choice_files) {
  my @last_files= glob "@last_choice_files";
  @last_choice_files= ();
  map { push @last_choice_files, $_ if -e $_ } @last_files;
}

if (! scalar @files and ! scalar @last_choice_files) {
  print "No files found to check for signatures\n";
  exit 0;
}
#else {
#  print "The following files will be checked for signatures of known bugs: @files\n";
#}

my $ci= 'N/A';
my $page_url= "NULL";
if ($ENV{TRAVIS} eq 'true') {
  $ci= 'Travis';
  $page_url= "'https://travis-ci.org/elenst/travis-tests/jobs/".$ENV{TRAVIS_JOB_ID}."'";
} elsif (defined $ENV{AZURE_HTTP_USER_AGENT}) {
  $ci= 'Azure';
  $page_url= "'https://dev.azure.com/elenst/MariaDB tests/_build/results?buildId=".$ENV{BUILD_BUILDID}."'";
} elsif (defined $ENV{LOCAL_CI}) {
    $ci= 'Local-'.$ENV{LOCAL_CI};
}
my $test_result= (defined $ENV{TEST_RESULT} and $ENV{TEST_RESULT} !~ /\s/) ? $ENV{TEST_RESULT} : 'N/A';
my $server_branch= $ENV{SERVER_BRANCH} || 'N/A';
my $test_line= $ENV{SYSTEM_DEFINITIONNAME} || $ENV{TRAVIS_BRANCH} || $ENV{TEST_ALIAS} || 'N/A';

my %found_mdevs= ();
my %fixed_mdevs= ();
my %draft_mdevs= ();
my $matches_info= '';

my $mdev;
my $pattern;
my $signature_does_not_match= 0;
my $signature_lines_found= 0;

my $res= 1;

sub search_files_for_matches
{
  my @files= @_;
  return $res unless scalar(@files);

  seek DATA, 0, 0;
  while (<DATA>) {
    if (/^\# Weak matches/) {
      # Don't search for weak matches if strong ones have been found
      if ($matches_info) {
        print "\n--- STRONG matches ---------------------------------\n";
        print $matches_info;
        $matches_info= '';
        $res= 0;
        register_matches('strong');
        last;
      }
      $mdev= undef;
      next;
    }

    # Signature line starts with =~
    # (TODO: in future maybe also !~ for anti-patterns)
    if (/^\s*=~\s*(.*)/) {
      # If we have already found a pattern which does not match, don't check this signature further
      next if $signature_does_not_match;
      # Don't check other MDEV signatures if one was already found
      next if $found_mdevs{$mdev};
      $pattern= $1;
      chomp $pattern;
      $pattern=~ s/(\"|\?|\!|\(|\)|\[|\]|\&|\^|\~|\+|\/)/\\$1/g;
    }
    # MDEV line starts a new signature
    elsif(/^\s*(MDEV-\d+|TODO-\d+):\s*(.*)/) {
      my $new_mdev= $1;
      # Process the previous result, if there was any
      if ($signature_lines_found and not $signature_does_not_match) {
        process_found_mdev($mdev);
      }
      $mdev= $new_mdev;
      $signature_lines_found= 0;
      $signature_does_not_match= 0;
      next;
    }
    else {
      # Skip comments and whatever else
      next;
    }
    system("grep -h -E -e \"$pattern\" @files > /dev/null 2>&1");
    if ($?) {
      $signature_does_not_match= 1;
    } else {
      $signature_lines_found++;
    }
  }

  # If it's non-empty at this point, it's weak matches
  if ($matches_info) {
    print "\n--- WEAK matches -------------------------------\n";
    print $matches_info;
    print "--------------------------------------\n";
    $res= 0;
    register_matches('weak');
  }
  return $res;
}

if (search_files_for_matches(@files)) {
  # No matches found in main files, add the "last choice" files to the search
  search_files_for_matches(@files, @last_choice_files);
  if ($res) {
    print "\n--- NO MATCHES FOUND ---------------------------\n";
    register_no_match();
  }
}

if (keys %fixed_mdevs) {
  foreach my $m (sort keys %fixed_mdevs) {
    print "\n--- ATTENTION! FOUND FIXED MDEV: -----\n";
    print "\t$m - $fixed_mdevs{$m}\n";
  }
  print "--------------------------------------\n";
}

exit $res;

sub connect_to_db {
  if (defined $ENV{DB_USER}) {
    my $dbh= DBI->connect("dbi:mysql:host=$ENV{DB_HOST}:port=$ENV{DB_PORT}",$ENV{DB_USER}, $ENV{DBP}, { RaiseError => 1 } );
    if ($dbh) {
      return $dbh;
    } else {
      print "ERROR: Couldn't connect to the database to register the result\n";
    }
  }
  return undef;
}

sub register_matches
{
  my $type= shift; # Strong or weak, based on it, the table and the logic are chosen
  if (my $dbh= connect_to_db()) {
    if ( $type eq 'strong' ) {
      # For strong matches, we insert each of them separately into jira field
      foreach my $j (keys %found_mdevs) {
        my $fixdate= defined $fixed_mdevs{$j} ? "'$fixed_mdevs{$j}'" : 'NULL';
        my $draft= $draft_mdevs{$j} || 0;
        $dbh->do("REPLACE INTO travis.strong_match (ci, test_id, jira, fixdate, draft, test_result, url, server_branch, test_line) VALUES (\'$ci\',\'$ENV{TEST_ID}\',\'$j\', $fixdate, $draft, \'$test_result\', $page_url, \'$server_branch\', \'$test_line\')");
      }
    } elsif ( $type eq 'weak' ) {
      my $jiras= join ',', keys %found_mdevs;
      # For weak matches, we insert the concatenation into the notes field
      $dbh->do("REPLACE INTO travis.weak_match (ci, test_id, notes, test_result, url, server_branch, test_line) VALUES (\'$ci\',\'$ENV{TEST_ID}\',\'??? $jiras\', \'$test_result\', $page_url, \'$server_branch\', \'$test_line\')");
    }
  }
}

sub register_no_match
{
  if (my $dbh= connect_to_db()) {
    $dbh->do("REPLACE INTO travis.no_match (ci, test_id, test_result, url, server_branch, test_line) VALUES (\'$ci\',\'$ENV{TEST_ID}\', \'$test_result\', $page_url, \'$server_branch\', \'$test_line\')");
  }
}

sub process_found_mdev
{
  my $mdev= shift;

  $found_mdevs{$mdev}= 1;

  unless (-e "/tmp/$mdev.resolution") {
    system("wget https://jira.mariadb.org//rest/api/2/issue/$mdev?fields=resolution -O /tmp/$mdev.resolution -o /dev/null");
  }

  my $resolution= `cat /tmp/$mdev.resolution`;
  my $resolutiondate;
  if ($resolution=~ s/.*\"name\":\"([^\"]+)\".*/$1/) {
    unless (-e "/tmp/$mdev.resolutiondate") {
      system("wget https://jira.mariadb.org//rest/api/2/issue/$mdev?fields=resolutiondate -O /tmp/$mdev.resolutiondate -o /dev/null");
    }
    $resolution= uc($resolution);
    $resolutiondate= `cat /tmp/$mdev.resolutiondate`;
    unless ($resolutiondate=~ s/.*\"resolutiondate\":\"(\d\d\d\d-\d\d-\d\d).*/$1/) {
      $resolutiondate= '';
    }
  } else {
    $resolution= 'Unresolved';
  }

  $fixed_mdevs{$mdev} = $resolutiondate if $resolution eq 'FIXED';

  unless (-e "/tmp/$mdev.summary") {
    system("wget https://jira.mariadb.org//rest/api/2/issue/$mdev?fields=summary -O /tmp/$mdev.summary -o /dev/null");
  }

  my $summary= `cat /tmp/$mdev.summary`;
  if ($summary =~ /\{\"summary\":\"(.*?)\"\}/) {
    $summary= $1;
  }

  if ($mdev =~ /TODO/ or $summary =~ /^[\(\[]?draft/i) {
    $draft_mdevs{$mdev}= 1;
  }

  if ($resolution eq 'FIXED' and not -e "/tmp/$mdev.fixVersions") {
    system("wget https://jira.mariadb.org//rest/api/2/issue/$mdev?fields=fixVersions -O /tmp/$mdev.fixVersions -o /dev/null");
  }

  unless (-e "/tmp/$mdev.affectsVersions") {
    system("wget https://jira.mariadb.org//rest/api/2/issue/$mdev?fields=versions -O /tmp/$mdev.affectsVersions -o /dev/null");
  }

  my $affectsVersions= `cat /tmp/$mdev.affectsVersions`;
  my @affected = ($affectsVersions =~ /\"name\":\"(.*?)\"/g);

  $matches_info .= "$mdev: $summary\n";

  if ($resolution eq 'FIXED') {
    my $fixVersions= `cat /tmp/$mdev.fixVersions`;
    my @versions = ($fixVersions =~ /\"name\":\"(.*?)\"/g);
    $matches_info .= "Fix versions: @versions ($resolutiondate)\n";
  }
  else {
    $matches_info .= "RESOLUTION: $resolution". ($resolutiondate ? " ($resolutiondate)" : "") . "\n";
    $matches_info .= "Affects versions: @affected\n";
  }
  $matches_info .= "-------------\n";
}

__DATA__

##############################################################################
# Strong matches
##############################################################################

MDEV-19680:
=~ Assertion \`!table \|\| (!table->read_set \|\| bitmap_is_set(table->read_set, field_index) \|\| (!(ptr >= table->record[0] && ptr < table->record[0] + table->s->reclength)))'|Assertion \`!table \|\| (!table->read_set \|\| bitmap_is_set(table->read_set, field_index))'
=~ Field_.*::val_.*
=~ Item_direct_view_ref::val_.*
=~ Aggregator_simple::add
MDEV-19674:
=~ Assertion \`marked_for_read()'
=~ Field_newdate::get_TIME|Field_timestampf::val_native
=~ TABLE::verify_constraints
=~ TABLE_LIST::view_check_option
=~ multi_update::do_updates
MDEV-19672:
=~ MariaDB Audit Plugin version .* STARTED
=~ safe_mutex: Trying to lock mutex at .*, when the mutex was already locked at .*
MDEV-19663:
=~ Got error 127 when reading table .*
=~ Table .* is marked as crashed and should be repaired
MDEV-19647:
=~ Assertion \`find(table)'
=~ dict_sys_t::prevent_eviction
=~ fts_optimize_add_table
=~ dict_load_columns
MDEV-19644:
=~ Server version: 10\.4|Server version: 10\.3
=~ AddressSanitizer: SEGV|signal 6|signal 11
=~ ha_partition::try_semi_consistent_read
=~ mysql_update
MDEV-19634:
=~ InnoDB: Using a partial-field key prefix in search, index .* of table .*\. Last data field length .* bytes, key ptr now exceeds key end by .* bytes
=~ Assertion \`0'
=~ row_sel_convert_mysql_key_to_innobase
=~ ha_innobase::records_in_range
=~ handler::multi_range_read_info_const
MDEV-19632:
=~ Slave SQL: Column .* of table .* cannot be converted from type 'tinyblob' to type 'longblob', Gtid .*, Internal MariaDB error code: 1677|Slave SQL: Column .* of table .* cannot be converted from type 'date' to type 'datetime'
MDEV-19631:
=~ Assertion \`0'
=~ st_select_lex_unit::optimize
=~ mysql_explain_union
=~ return_zero_rows
MDEV-19622:
=~ Assertion \`!table \|\| (!table->read_set \|\| bitmap_is_set(table->read_set, field_index))'|Assertion \`!table \|\| (!table->read_set \|\| bitmap_is_set(table->read_set, field_index) \|\| (!(ptr >= table->record[0] && ptr < table->record[0] + table->s->reclength)))'|Assertion \`marked_for_read()'
=~ ha_partition::set_auto_increment_if_higher
=~ ha_partition::update_row
MDEV-19621:
=~ signal 11|AddressSanitizer: SEGV on unknown address
=~ ha_innobase::commit_inplace_alter_table
=~ handler::ha_commit_inplace_alter_table
=~ mysql_inplace_alter_table
MDEV-19619:
=~ AddressSanitizer: heap-use-after-free
=~ Field_longlong::val_int
=~ ha_innobase::write_row
=~ read_sep_field
=~ mysql_load
MDEV-19619:
=~ Assertion \`tmp != ((long long) 0x8000000000000000LL)'
=~ TIME_from_longlong_datetime_packed
=~ Field_datetimef::get_TIME
=~ get_field_default_value
=~ fill_schema_table_by_open
MDEV-19619:
=~ signal 11
=~ create_tmp_table
=~ select_unit::create_result_table
=~ open_normal_and_derived_tables
=~ fill_schema_table_by_open
MDEV-19619:
=~ signal 11
=~ String::copy
=~ get_field_default_value
=~ get_schema_column_record
=~ fill_schema_table_by_open
MDEV-19619:
=~ signal 11
=~ Field::is_null_in_record
=~ create_tmp_table
=~ select_unit::create_result_table
=~ open_normal_and_derived_tables
MDEV-19619:
=~ signal 11
=~ row_sel_field_store_in_mysql_format_func
=~ row_search_mvcc
=~ ha_innobase::index_read
=~ READ_RECORD::read_record
MDEV-19619:
=~ Assertion \`prebuilt->mysql_prefix_len <= prebuilt->mysql_row_len'
=~ row_sel_dequeue_cached_row_for_mysql
=~ row_search_mvcc
=~ ha_innobase::general_fetch
MDEV-19619:
=~ InnoDB: Record in index .* of table .* was not found on update: TUPLE
=~ Assertion \`btr_validate_index(index, 0, false)'
=~ row_upd_sec_index_entry
=~ ha_innobase::delete_row
=~ read_sep_field
MDEV-19609:
=~ Slave SQL: Error 'You have an error in your SQL syntax .* near 'TYPE=
=~ CREATE TABLE
MDEV-19596:
=~ Assertion \`inited==NONE'
=~ handler::ha_index_read_idx_map
=~ Delayed_insert::handle_inserts
MDEV-19595:
=~ Table .* is marked as crashed and should be repaired
=~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
=~ Diagnostics_area::set_ok_status
=~ my_ok
=~ mysql_alter_table|Sql_cmd_truncate_table::execute|mysqld_show_create
MDEV-19576:
=~ Got error 175 when executing record redo_index
=~ Aria engine: Redo phase failed
=~ Aria recovery failed
MDEV-19536:
=~ AddressSanitizer: heap-use-after-free|signal 11|Invalid read of size
=~ is_temporary_table|Index_stat::set_full_table_name|Stat_table::Stat_table|statistics_for_tables_is_needed
=~ read_statistics_for_tables_if_needed
=~ fill_schema_table_by_open
MDEV-19536:
=~ signal 11
=~ read_statistics_for_tables_if_needed
=~ fill_schema_table_by_open
MDEV-19526:
=~ Assertion \`((val << shift) & mask) == (val << shift)'
=~ rec_set_bit_field_2
=~ page_cur_tuple_insert
MDEV-19522:
=~ Assertion \`val <= 4294967295u'
=~ fts_encode_int
=~ fts_cache_node_add_positions
=~ fts_commit_table
MDEV-19520:
=~ signal 11|AddressSanitizer: SEGV on unknown address
=~ Item_func_not::fix_fields
=~ st_select_lex::pushdown_from_having_into_where
=~ JOIN::optimize_inner
MDEV-19501:
=~ Failing assertion: ib_vector_size(optim->words) > 0
=~ fts_optimize_words
=~ fts_optimize_table|fts_optimize_index
MDEV-19493:
=~ signal 11|AddressSanitizer: heap-use-after-free
=~ lock_tables_check|get_lock_data|multi_update_check_table_access
=~ mysql_multi_update_prepare
MDEV-19418:
=~ Assertion \`ptr == a \|\| ptr == b'
=~ Field_bit::cmp
=~ group_concat_key_cmp_with_order
=~ tree_walk_left_root_right
=~ Item_func_group_concat::repack_tree
MDEV-19406:
=~ Assertion \`marked_for_write_or_computed()'|Assertion \`is_stat_field \|\| !table \|\| (!table->write_set \|\| bitmap_is_set(table->write_set, field_index) \|\| (!(ptr >= table->record[0] && ptr < table->record[0] + table->s->reclength))) \|\| (table->vcol_set && bitmap_is_set(table->vcol_set, field_index))'
=~ Field_date_common::store_TIME_with_warning
=~ Field::do_field_temporal
=~ multi_update::do_updates
MDEV-19406:
=~ Assertion \`bitmap_is_set_all(&table->s->all_set)'
=~ handler::ha_reset
=~ close_thread_table
MDEV-19400:
=~ Assertion \`!table->s->tmp_table'
=~ wait_while_table_is_used
=~ mysql_rm_table_no_locks
MDEV-19400:
=~ signal 11
=~ MDL_ticket::has_stronger_or_equal_type
=~ MDL_context::upgrade_shared_lock
=~ wait_while_table_is_used
=~ mysql_rm_table_no_locks
MDEV-19394:
=~ InnoDB: checksum mismatch in tablespace
=~ InnoDB: Operating system error number 2 in a file operation
=~ fil_load_single_table_tablespace
=~ recv_init_crash_recovery
=~ recv_scan_log_recs
MDEV-19361:
=~ Assertion \`marked_for_read()'
=~ Item_func_mul::int_op
=~ Item_func_hybrid_field_type::val_int_from_int_op
=~ TABLE::update_virtual_fields
MDEV-19361:
=~ signal 11|AddressSanitizer: SEGV on unknown address
=~ handler_index_cond_check
=~ row_search_idx_cond_check
=~ JOIN_TAB_SCAN::open
MDEV-19348:
=~ InnoDB: Database page corruption on disk or a failed file read of tablespace .* page .* You may have to recover from a backup
=~ InnoDB: Failed to read file .* at offset .* Page read from tablespace is corrupted
=~ mariabackup: innodb_init() returned 39 (Data structure corruption)
MDEV-19318:
=~ Assertion \`!(length < share->base\.min_block_length)'
=~ _ma_scan_block_record
=~ rr_sequential
=~ READ_RECORD::read_record
MDEV-19306:
=~ Assertion \`marked_for_read()'
=~ field_conv_incompatible
=~ TABLE::update_virtual_fields
MDEV-19304:
=~ signal 11|AddressSanitizer: SEGV on unknown address
=~ row_sel_field_store_in_mysql_format_func|row_sel_store_mysql_rec
=~ row_search_mvcc
=~ rr_sequential
MDEV-19304:
=~ AddressSanitizer: unknown-crash on address
=~ my_timestamp_from_binary
=~ Field_timestampf::get_timestamp
=~ Column_definition::Column_definition|TABLE::validate_default_values_of_unset_fields
MDEV-19304:
=~ AddressSanitizer: SEGV on unknown address|signal 11
=~ calc_row_difference
=~ handler::ha_update_row
MDEV-19304:
=~ AddressSanitizer: unknown-crash|AddressSanitizer: heap-use-after-free|AddressSanitizer: heap-buffer-overflow|AddressSanitizer: use-after-poison
=~ Field::cmp_binary
=~ compare_record
=~ mysql_update
MDEV-19304:
=~ AddressSanitizer: unknown-crash
=~ create_tmp_table
=~ select_unit::create_result_table
=~ mysql_derived_prepare
MDEV-19303:
=~ Conditional jump or move depends on uninitialised value
=~ mi_rrnd
=~ ha_sequence::rnd_pos
=~ rr_from_pointers
MDEV-19303:
=~ Uninitialised byte(s) found during client check request
=~ dtuple_validate
=~ page_cur_search_with_match_bytes
=~ rr_from_pointers
MDEV-19303:
=~ File too short; Expected more data in file
=~ Conditional jump or move depends on uninitialised value
=~ maria_rrnd
=~ ha_sequence::rnd_pos
=~ rr_from_pointers
MDEV-19302:
=~ Assertion \`!current_stmt_is_commit \|\| !rgi->tables_to_lock'
=~ Server version: 10\.4
=~ Query_log_event::do_apply_event
=~ apply_event_and_update_pos_apply
MDEV-19301:
=~ Assertion \`!is_valid_datetime() \|\| fraction_remainder(((item->decimals) < (6) ? (item->decimals) : (6))) == 0'
=~ Server version: 10\.4
=~ Datetime_truncation_not_needed::Datetime_truncation_not_needed
=~ Item_func_nullif::date_op
=~ Type_handler_temporal_result::Item_func_hybrid_field_type_get_date
MDEV-19299:
=~ AddressSanitizer: heap-use-after-free
=~ my_scan_weight_utf8_general_ci|my_utf8_uni
=~ my_strnncollsp_utf8_general_ci|my_strnncollsp_utf8
=~ sortcmp
=~ test_if_group_changed
MDEV-19297:
=~ InnoDB: Failing assertion: thr->magic_n == QUE_THR_MAGIC_N
=~ que_graph_free_recursive
=~ tdc_remove_table
MDEV-19273:
=~ signal 11|AddressSanitizer: SEGV on unknown address
=~ MDL_ticket::has_stronger_or_equal_type
=~ MDL_context::upgrade_shared_lock
=~ wait_while_table_is_used
MDEV-19273:
=~ Assertion \`thd->mdl_context\.is_lock_owner(MDL_key::TABLE, table->db\.str, table->table_name\.str, MDL_SHARED)'
=~ mysql_rm_table_no_locks
MDEV-19261:
=~ InnoDB: Failing assertion: dfield->type\.mtype == 0 \|\| dfield->len == len
=~ trx_undo_rec_get_partial_row
=~ row_purge_parse_undo_rec
=~ Server version: 10\.1
MDEV-19254:
=~ signal 11|AddressSanitizer: SEGV on unknown address|AddressSanitizer: heap-use-after-free
=~ maria_status
=~ ha_maria::info
=~ ha_partition
=~ open_and_process_table|open_and_lock_tables
MDEV-19225:
=~ InnoDB: InnoDB FTS: Doc ID cannot be 0
MDEV-19216:
=~ Assertion \`!strcmp(index->table->name\.m_name, "SYS_FOREIGN") \|\| !strcmp(index->table->name\.m_name, "SYS_FOREIGN_COLS")'
=~ btr_node_ptr_max_size
=~ btr_cur_search_to_nth_level
MDEV-19202:
=~ signal 11
=~ strlen
=~ dict_col_t::name
=~ rollback_instant
MDEV-19202:
=~ Assertion \`n'
=~ find_old_col_no
=~ dict_table_t::rollback_instant
MDEV-19198:
=~ Assertion \`(create_info->tmp_table()) \|\| thd->mdl_context\.is_lock_owner(MDL_key::TABLE, table->db.str, table->table_name\.str, MDL_EXCLUSIVE)'|Assertion \`(create_info->tmp_table()) \|\| thd->mdl_context\.is_lock_owner(MDL_key::TABLE, table->db, table->table_name, MDL_EXCLUSIVE)'|Assertion \`(create_info->options & 1) \|\| thd->mdl_context\.is_lock_owner(MDL_key::TABLE, table->db, table->table_name, MDL_EXCLUSIVE)'
=~ mysql_create_like_table
=~ mysql_execute_command
MDEV-19194:
=~ signal 11
=~ fk_prepare_copy_alter_table
=~ mysql_alter_table
MDEV-19194:
=~ AddressSanitizer: use-after-poison
=~ base_list_iterator::next_fast
=~ fk_prepare_copy_alter_table
=~ mysql_alter_table
MDEV-19190:
=~ Assertion \`part_share->auto_inc_initialized'
=~ ha_partition::get_auto_increment
=~ TABLE::update_generated_fields
=~ TABLE::period_make_insert|update_portion_of_time
MDEV-19189:
=~ AddressSanitizer: memcpy-param-overlap: memory ranges
=~ fill_alter_inplace_info
=~ mysql_alter_table
MDEV-19178:
=~ Assertion \`m_sp == __null'|signal 11|AddressSanitizer: heap-use-after-free
=~ create_view_field
=~ Field_iterator_view::create_item
=~ find_field_in_tables
MDEV-19175:
=~ signal 11|AddressSanitizer: SEGV on unknown address
=~ ha_partition::vers_can_native
=~ TABLE_SHARE::init_from_binary_frm_image
MDEV-19173:
=~ Assertion \`pos < table->n_def'
=~ dict_table_get_nth_col
=~ dict_table_get_col_name
=~ innodb_base_col_setup_for_stored
MDEV-19173:
=~ Assertion \`col_nr < table->n_def'
=~ dict_table_get_col_name
=~ innodb_base_col_setup_for_stored
=~ create_table_info_t::create_table_def
MDEV-19166:
=~ Assertion \`!is_zero_datetime()'
=~ Timestamp_or_zero_datetime::tv
=~ Item_cache_timestamp::to_datetime
MDEV-19131:
=~ Assertion \`table->versioned(VERS_TRX_ID) \|\| (table->versioned() && table->s->table_category == TABLE_CATEGORY_TEMPORARY)'
=~ Field_vers_trx_id::get_date
=~ Temporal_with_date::make_from_item
MDEV-19130:
=~ Assertion \`next_insert_id >= auto_inc_interval_for_cur_row\.minimum()'
=~ handler::update_auto_increment
=~ TABLE::update_generated_fields
=~ TABLE::period_make_insert
MDEV-19127:
=~ Assertion \`row_start_field'
=~ vers_prepare_keys
=~ mysql_create_frm_image
MDEV-19092:
=~ Assertion \`foreign->referenced_index != __null'|signal 11|Assertion \`new_index != __null'
=~ dict_mem_table_col_rename_low
=~ innobase_rename_or_enlarge_columns_cache
MDEV-19091:
=~ Assertion \`args[0] == args[2] \|\| thd->stmt_arena->is_stmt_execute()'
=~ Item_func_nullif::fix_length_and_dec
=~ Item_func::fix_fields
MDEV-19067:
=~ AddressSanitizer: heap-use-after-free
=~ ha_maria::store_lock
=~ get_lock_data
=~ mysql_lock_tables
MDEV-19066:
=~ AddressSanitizer: use-after-poison|AddressSanitizer: unknown-crash
=~ innobase_build_col_map
=~ prepare_inplace_alter_table_dict
=~ mysql_recreate_table|mysql_alter_table
MDEV-19055:
=~ Assertion \`(_my_thread_var())->thr_errno != 0'
=~ pagecache_read
=~ get_head_or_tail_page
=~ allocate_and_write_block_record
MDEV-19049:
=~ AddressSanitizer: stack-buffer-overflow
=~ Field_blob::get_key_image
=~ key_copy
=~ check_duplicate_long_entry_key
MDEV-19049:
=~ stack smashing detected
=~ __fortify_fail
=~ check_duplicate_long_entry_key
MDEV-19038:
=~ signal 11|AddressSanitizer: SEGV on unknown address
=~ calc_row_difference
=~ ha_innobase::update_row
=~ mysql_update
MDEV-19034:
=~ AddressSanitizer: unknown-crash
=~ get_date_time_separator
=~ str_to_datetime
=~ Field_temporal_with_date::store
MDEV-19020:
=~ AddressSanitizer: heap-use-after-free
=~ strxnmov
=~ mysql_load
MDEV-19014:
=~ pure virtual method called|signal 11|AddressSanitizer: heap-use-after-free
=~ Item_direct_view_ref::fix_fields
=~ sp_instr_stmt::exec_core
MDEV-19011:
=~ Assertion \`file->s->base.reclength < file->s->vreclength'
=~ ha_myisam::setup_vcols_for_repair
=~ ha_myisam::enable_indexes
=~ Sql_cmd_alter_table::execute
MDEV-18980:
=~ Assertion \`join->best_read < double(1\.79769313486231570814527423731704357e+308L)'
=~ greedy_search
=~ choose_plan
=~ make_join_statistics
MDEV-18977:
=~ Conditional jump or move depends on uninitialised value
=~ TABLE::prune_range_rowid_filters
=~ TABLE::init_cost_info_for_usable_range_rowid_filters
MDEV-18947:
=~ points to uninitialised byte
=~ pagecache_fwrite
=~ flush_cached_blocks
=~ flush_pagecache_blocks_with_filter
MDEV-18925:
=~ AddressSanitizer: heap-buffer-overflow
=~ Item_exists_subselect::is_top_level_item|Item_in_optimizer::is_top_level_item
=~ st_select_lex::update_used_tables
=~ JOIN::optimize
MDEV-18918:
=~ Slave SQL: Error 'Invalid default value for .*
=~ NOT NULL DEFAULT ''
MDEV-18911:
=~ Assertion \`(templ->is_virtual && !field) \|\| (field && field->prefix_len ? field->prefix_len == len : templ->mysql_col_len == len)'
=~ row_sel_field_store_in_mysql_format_func
=~ row_search_idx_cond_check
MDEV-18900:
=~ AddressSanitizer: heap-use-after-free
=~ my_strnncoll_binary
=~ Item_func_min_max::val_str
=~ end_send_group|AGGR_OP::put_record|make_sortkey
MDEV-18882:
=~ AddressSanitizer: heap-use-after-free
=~ Binary_string::copy|String::copy
=~ Item_func_make_set::val_str
=~ copy_fields
MDEV-18875:
=~ Assertion \`thd->transaction.stmt.ha_list == __null \|\| trans == &thd->transaction.stmt'
=~ ha_rollback_trans
=~ mysql_trans_commit_alter_copy_data|trans_commit_implicit
=~ ADD PERIOD|add period|LOCK TABLE
MDEV-18870:
=~ signal 11|AddressSanitizer: SEGV on unknown address
=~ row_upd_step
=~ row_update_for_mysql
=~ TABLE::delete_row
MDEV-18826:
=~ signal 11
=~ l_find
=~ MDL_map::remove
=~ MDL_context::release_transactional_locks
MDEV-18805:
=~ Warning: Enabling keys got errno 127 on
=~ AddressSanitizer: heap-buffer-overflow
=~ strmake_root
=~ Query_arena::strmake
=~ Column_definition::Column_definition
MDEV-18802:
=~ Assertion \`table->stat_initialized' failed
=~ dict_stats_update_if_needed
=~ row_update_cascade_for_mysql
=~ row_upd_step
MDEV-18794:
=~ Assertion \`!m_innodb' failed
=~ ha_partition::cmp_ref
=~ read_keys_and_merge_scans
MDEV-18788:
=~ at line 391: Event Scheduler: An error occurred when initializing system tables. Disabling the Event Scheduler
=~ FATAL ERROR: Upgrade failed
MDEV-18787:
=~ Assertion \`! is_set()' failed
=~ Diagnostics_area::set_eof_status
=~ mysqld_show_create
MDEV-18783:
=~ AddressSanitizer: heap-use-after-free|signal 11
=~ tree_search_next|hp_rb_make_key|tree_search_edge|check_one_key|check_one_rb_key
=~ tc_purge|tc_remove_table
=~ run_backup_stage|close_thread_tables
MDEV-18780:
=~  Assertion \`col->prtype == prtype'
=~ innobase_rename_or_enlarge_column_try
=~ commit_try_norebuild
MDEV-18776:
=~ Assertion \`0' failed
=~ mysql_execute_command
=~ SET STATEMENT
MDEV-18770:
=~ AddressSanitizer: memcpy-param-overlap|AddressSanitizer: heap-use-after-free
=~ my_strnxfrm_8bit_bin
=~ make_sortkey
=~ create_sort_index|find_all_keys
MDEV-18756:
=~ Use of uninitialised value of size
=~ DES_set_key_unchecked
=~ Item_func_des_encrypt::val_str
MDEV-18735:
=~ Conditional jump or move depends on uninitialised value
=~ promote_first_timestamp_column
=~ Sql_cmd_alter_table::execute
MDEV-18734:
=~ AddressSanitizer: heap-use-after-free|Invalid read of size
=~ my_strnxfrm_simple_internal
=~ Field_blob::sort_string
MDEV-18706:
=~ mysql_ha_read: Got error 149 when reading table
MDEV-18696:
=~ Assertion \`newtrn->used_instances != (void\*) tbl' failed
=~ _ma_set_trn_for_table
=~ thr_multi_lock
# Only fixed in 10.4!
MDEV-18694:
=~ mysql_socket\.fd != -1
=~ Protocol::send_error
=~ KILL_SERVER
MDEV-18693:
=~ AddressSanitizer: heap-use-after-free|signal 11
=~ _ma_remove_table_from_trnman
=~ wait_while_table_is_used
=~ reload_acl_and_cache
MDEV-18654:
=~ InnoDB: Failing assertion: sym_node->table != NULL
=~ pars_retrieve_table_def
=~ pars_insert_statement
MDEV-18624:
=~ AddressSanitizer: heap-use-after-free
=~ mysql_derived_prepare
=~ mysql_multi_update_prepare
=~ sp_instr_stmt::exec_core
MDEV-18602:
=~ InnoDB: Failing assertion: !recv_no_log_write
=~ mtr_commit
=~ xtrabackup_prepare_func
MDEV-18589:
=~ Assertion \`fil_space_t::physical_size(flags) == info\.page_size' failed
=~ xb_delta_open_matching_space
MDEV-18581:
=~ Assertion \`index->table == node->table'
=~ row_purge_remove_sec_if_poss_leaf|row_purge_upd_exist_or_extern_func
=~ row_purge_record_func
=~ row_purge_step
MDEV-18550:
=~ Assertion failure in file /home/travis/src/storage/innobase/fil/fil0fil.cc
=~ InnoDB: Failing assertion: success
=~ fil_node_open_file
=~ xb_load_single_table_tablespace
MDEV-18546:
=~ AddressSanitizer: heap-use-after-free
=~ innobase_get_computed_value
=~ row_vers_build_clust_v_col
MDEV-18500:
=~ (block)->n_pointers == 0
=~ btr_search_build_page_hash_index
MDEV-18496:
=~ mysqld: Unknown key id 1. Can't continue
=~ ma_crypt_post_write_hook
=~ _ma_flush_pending_blocks
MDEV-18496:
=~ mysqld: Unknown key id 1\. Can't continue
=~ Diagnostics_area::set_ok_status
=~ Assertion \`! is_set()' failed
=~ simple_rename_or_index_change
=~ Server version: 10\.1
MDEV-18496:
=~ mysqld: Unknown key id 1\. Can't continue
=~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
=~ simple_rename_or_index_change
MDEV-18457:
=~ Assertion \`(bitmap->map + (bitmap->full_head_size/6\*6)) <= full_head_end'
=~ _ma_check_bitmap
=~ set_page_bits
=~ _ma_write_init_block_record
MDEV-18456:
=~ Assertion \`item->maybe_null'
=~ Type_handler_temporal_result::make_sort_key
=~ create_sort_index
MDEV-18451:
=~ signal 11|AddressSanitizer: SEGV on unknown address
=~ maria_create_trn_for_mysql
=~ _ma_setup_live_state
=~ trans_commit_implicit
MDEV-18449:
=~ AddressSanitizer: heap-use-after-free
=~ my_strnncollsp_simple
=~ sortcmp
=~ sub_select
MDEV-18441:
=~ Assertion \`tables_opened == 1'
=~ Sql_cmd_alter_table::execute
=~ ADD .*FOREIGN KEY
MDEV-18418:
=~ Assertion \`mdl_ticket->m_type == MDL_SHARED_UPGRADABLE \|\| mdl_ticket->m_type == MDL_SHARED_NO_WRITE \|\| mdl_ticket->m_type == MDL_SHARED_NO_READ_WRITE'
=~ Server version: 10\.1
=~ MDL_context::upgrade_shared_lock
MDEV-18418:
=~ Assertion \`mdl_ticket->m_type == MDL_SHARED_UPGRADABLE \|\| mdl_ticket->m_type == MDL_SHARED_NO_WRITE \|\| mdl_ticket->m_type == MDL_SHARED_NO_READ_WRITE \|\| mdl_ticket->m_type == MDL_SHARED_READ \|\| mdl_ticket->m_type == MDL_SHARED_WRITE'
=~ MDL_context::upgrade_shared_lock
MDEV-18389:
=~ Cannot find index .* in InnoDB index dictionary
=~ InnoDB indexes are inconsistent with what defined in \.frm for table
=~ ha_innobase::index_type
=~ fill_schema_table_by_open
MDEV-18371:
=~ Conditional jump or move depends on uninitialised value|signal 11
=~ cmp_key_rowid_part_id
=~ QUICK_RANGE_SELECT::get_next
MDEV-18361:
=~ Assertion \`0'
=~ row_log_table_apply_ops
=~ commit_try_rebuild
=~ Sql_cmd_alter_table::execute
MDEV-18335:
=~ Assertion \`!error \|\| error == 137' failed
=~ subselect_rowid_merge_engine::init
=~ Item_func_not::val_int
MDEV-18335:
=~ AddressSanitizer: heap-buffer-overflow
=~ subselect_rowid_merge_engine::init
=~ Item_func_not::val_int
MDEV-18334:
=~ Assertion \`len <= col->len || ((col->mtype) == 5 || (col->mtype) == 14) || (col->len == 0 && col->mtype == 1)'
=~ rec_get_converted_size_comp_prefix_low
=~ row_undo_step
MDEV-18334:
=~ Assertion \`len <= field->col->len || ((field->col->mtype) == 5 || (field->col->mtype) == 14) || (field->col->len == 0 && field->col->mtype == 1)' failed
=~ rec_get_converted_size_comp_prefix_low
=~ row_upd_step
MDEV-18325:
=~ InnoDB: Error: page
=~ InnoDB: is in the future! Current system log sequence number
=~ Version: '10\.1
MDEV-18310:
=~ Got error 121 when executing undo undo_key_delete
MDEV-18293:
=~ signal 11|AddressSanitizer: SEGV
=~ row_sel_sec_rec_is_for_clust_rec
=~ ha_innobase::general_fetch
MDEV-18291:
=~ std::__cxx11::_List_base|std::_List_base
=~ dict_table_remove_from_cache|dict_sys_t::remove
=~ ha_delete_table|ha_innobase_inplace_ctx::~ha_innobase_inplace_ctx|Sql_cmd_truncate_table::handler_truncate|row_merge_drop_table
MDEV-18286:
=~ Assertion \`pagecache->cnt_for_resize_op == 0'
=~ check_pagecache_is_cleaned_up
=~ plugin_shutdown
MDEV-18285:
=~ Assertion \`! is_set()' failed
=~ Diagnostics_area::disable_status
=~ Prepared_statement::prepare
=~ DROP
MDEV-18260:
=~ Assertion \`!was_changed \|\| (block->status & 64) \|\| (block->status & 32)'
=~ pagecache_unlock_by_link
MDEV-18259:
=~ signal 11|AddressSanitizer: heap-use-after-free
=~ strlen|id_name_t::operator
=~ get_foreign_key_info
=~ ha_innobase::get_parent_foreign_key_list|ha_innobase::get_foreign_key_list
MDEV-18250:
=~ signal 11|exception
=~ dirname_length
=~ innobase_basename
=~ sync_arr_fill_sys_semphore_waits_table
MDEV-18244:
=~ signal 11|AddressSanitizer: SEGV on unknown address
=~ ha_innobase::update_thd
=~ ha_innobase::info_low
=~ ha_partition::update_next_auto_inc_val|ha_partition::update_row
MDEV-18216:
=~ signal 11
=~ Query_arena::set_query_arena
=~ THD::set_n_backup_active_arena
=~ Field::set_default
=~ CREATE.*VIEW
MDEV-18207:
=~ AddressSanitizer: heap-use-after-free|Invalid read of size
=~ _ma_get_status
=~ mysql_lock_tables
MDEV-18203:
=~ error 126 when executing undo undo_key_insert|error 126 when executing undo undo_key_delete
=~ Aria engine: Undo phase failed
=~ Plugin 'Aria' init function returned error
MDEV-18166:
=~ Assertion \`!table \|\| (!table->read_set \|\| bitmap_is_set(table->read_set, field_index) \|\| (!(ptr >= table->record[0] && ptr < table->record[0] + table->s->reclength)))'
=~ Field_varstring::val_str|Field_datetimef::get_TIME|Field_blob::val_str
=~ Item::save_in_field|Item_field::save_in_field
=~ TABLE::update_virtual_fields
MDEV-18166:
=~ Server version: 10\.4|Server version: 10\.3|Server version: 10\.2
=~ Assertion \`!table \|\| (!table->read_set \|\| bitmap_is_set(table->read_set, field_index) \|\| (!(ptr >= table->record[0] && ptr < table->record[0] + table->s->reclength)))'
=~ field_conv_incompatible
=~ TABLE::update_virtual_fields
MDEV-18156:
=~ InnoDB: Record in index .* of table .* was not found on update: TUPLE
=~ Assertion \`btr_validate_index(index, 0, false)'|Assertion \`0'
=~ row_upd_sec_index_entry
=~ row_update_for_mysql
MDEV-18153:
=~ Index for table .* is corrupt; try to repair it|InnoDB: Record in index .* of table .* was not found on update: TUPLE
=~ Assertion \`0'|Assertion \`btr_validate_index(index, 0)'|Assertion \`btr_validate_index(index, 0, false)'
=~ Server version: 10\.4
=~ row_upd_sec_index_entry
=~ row_update_for_mysql
MDEV-18151:
=~ Assertion \`0'
=~ Protocol::end_statement
=~ Server version: 10\.4
=~ IDENTIFIED.*WITH|IDENTIFIED.*VIA
MDEV-18088:
=~ Assertion \`share->in_trans == 0'
=~ maria_close
=~ Locked_tables_list::reopen_tables|close_all_tables_for_name|alter_close_table
MDEV-18082:
=~ Assertion \`! is_set()' failed
=~ Diagnostics_area::disable_status
=~ Prepared_statement::prepare
=~ EXPLAIN
MDEV-18078:
=~ Assertion \`trnman_has_locked_tables(trn) > 0'
=~ ha_maria::external_lock
=~ mysql_unlock_tables
MDEV-18069:
=~ signal 11
=~ MDL_lock::incompatible_granted_types_bitmap
=~ MDL_ticket::has_stronger_or_equal_type
=~ run_backup_stage
MDEV-18069:
=~ AddressSanitizer: heap-use-after-free
=~ MDL_ticket::has_stronger_or_equal_type
=~ MDL_context::upgrade_shared_lock
=~ run_backup_stage
MDEV-18068:
=~ Assertion \`this == ticket->get_ctx()'
=~ MDL_context::release_lock
=~ backup_end
MDEV-18067:
=~ Assertion \`ticket->m_duration == MDL_EXPLICIT'|AddressSanitizer: heap-use-after-free
=~ MDL_context::release_lock
=~ backup_end
=~ run_backup_stage
MDEV-18067:
=~ signal 11
=~ backup_end
=~ run_backup_stage
MDEV-18047:
=~ index->magic_n == 76789786|Assertion \`pos < index->n_def'|AddressSanitizer: heap-use-after-free
=~ dict_index_get_nth_field|dict_index_get_nth_col
=~ dict_foreign_qualify_index
=~ innobase_update_foreign_try
MDEV-18047:
=~ got signal 11
=~ dict_foreign_qualify_index
=~ innobase_update_foreign_try
MDEV-18047:
=~ AddressSanitizer: heap-use-after-free
=~ dict_index_get_nth_field
=~ innobase_update_foreign_try
MDEV-18046:
=~ Assertion \`(buf[0] & 0xe0) == 0x80'
=~ binlog_get_uncompress_len
=~ Rows_log_event::uncompress_buf
=~ mysql_show_binlog_events
MDEV-18046:
=~ AddressSanitizer: unknown-crash
=~ my_strndup
=~ Rotate_log_event::Rotate_log_event
=~ Log_event::read_log_event
=~ mysql_show_binlog_events
MDEV-18046:
=~ Assertion \`var_header_len >= 2'
=~ Rows_log_event::Rows_log_event
=~ Update_rows_log_event::Update_rows_log_event
=~ mysql_show_binlog_events
MDEV-18046:
=~ Assertion \`m_field_metadata_size <= (m_colcnt \* 2)'
=~ Table_map_log_event::Table_map_log_event
=~ mysql_show_binlog_events
MDEV-18046:
=~ signal 11
=~ my_bitmap_free
=~ Update_rows_log_event::~Update_rows_log_event
=~ mysql_show_binlog_events
MDEV-18018:
=~ signal 11|AddressSanitizer: heap-use-after-free
=~ TABLE_LIST::reinit_before_use
=~ sp_head::execute|Prepared_statement::execute
MDEV-18013:
=~ Assertion \`share->now_transactional'
=~ flush_log_for_bitmap
=~ pagecache_fwrite
=~ _ma_flush_table_files
MDEV-18003:
=~ Assertion \`grantee->counter > 0'
=~ merge_role_privileges
=~ traverse_role_graph_up
MDEV-17998:
=~ Assertion \`!table->pos_in_locked_tables'
=~ tc_release_table
=~ Locked_tables_list::unlink_all_closed_tables
MDEV-17998:
=~ AddressSanitizer: heap-use-after-free
=~ find_table_for_mdl_upgrade
=~ open_tables_check_upgradable_mdl
=~ mysql_alter_table
MDEV-17991:
=~ Out of memory
=~ Lex_input_stream::body_utf8_start
=~ MYSQLparse
MDEV-17974:
=~ signal 11|AddressSanitizer: use-after-poison
=~ sp_process_definer
=~ mysql_create_user
=~ Prepared_statement::execute|sp_head::execute
MDEV-17964:
=~ Assertion \`status == 0'
=~ add_role_user_mapping_action
=~ rebuild_role_grants
MDEV-17951:
=~ Assertion \`thd->transaction\.stmt\.is_empty() \|\| thd->in_sub_stmt \|\| (thd->state_flags & Open_tables_state::BACKUPS_AVAIL)'
=~ close_thread_tables
=~ Query_log_event::do_apply_event
MDEV-17939:
=~ Assertion \`++loop_count < 2'
=~ trx_undo_report_rename
=~ fts_drop_table
=~ mysql_alter_table
MDEV-17912:
=~ failed to decrypt .*  rc: -1  dstlen: 0  size: .*
=~ Got error 192 when executing record .*
=~ Aria engine: Redo phase failed
MDEV-17896:
=~ Assertion \`pfs->get_refcount() > 0'
=~ release_table_share|tdc_delete_share_from_hash
=~ purge_tables|close_all_tables_for_name|tdc_release_share
MDEV-17891:
=~ Assertion \`transactional_table \|\| !changed \|\| thd->transaction.stmt.modified_non_trans_table'
=~ select_insert::abort_result_set
=~ Server version: 10\.3|Server version: 10\.4
MDEV-17891:
=~ The table .* is full|Warning: Enabling keys got errno 121
=~ Assertion \`transactional_table \|\| !(info.copied \|\| info.deleted) \|\| thd->transaction.stmt.modified_non_trans_table'
=~ mysql_load
=~ Server version: 10\.3|Server version: 10\.4
MDEV-17890:
=~ InnoDB: Record in index .* was not found on update: TUPLE
=~ Assertion \`0'|signal 11
=~ row_upd_sec_index_entry|row_upd_build_difference_binary
MDEV-17869:
=~ AddressSanitizer: use-after-poison
=~ Item_change_list::rollback_item_tree_changes
=~ Prepared_statement::cleanup_stmt|sp_lex_keeper::reset_lex_and_exec_core
MDEV-17857:
=~ tmp != ((long long) 0x8000000000000000LL)
=~ TIME_from_longlong_datetime_packed
MDEV-17844:
=~ Assertion \`ulint(rec) == offsets[2]'
=~ rec_offs_validate
=~ page_zip_write_trx_id_and_roll_ptr
=~ row_undo
MDEV-17843:
=~ Assertion \`page_rec_is_leaf(rec)'
=~ lock_rec_queue_validate
=~ innodb_show_status
MDEV-17842:
=~ Assertion \`((copy & 0x00000003) == 0x02)'
=~ pfs_lock::allocated_to_free
=~ drop_table_share
MDEV-17837:
=~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
=~ Diagnostics_area::set_ok_status
=~ my_ok
=~ mysql_insert|CREATE .*PROCEDURE|mysql_rm_table|CREATE .*EVENT
MDEV-17699:
=~ AddressSanitizer: use-after-poison
=~ base_list_iterator::next_fast
=~ substitute_for_best_equal_field
=~ JOIN::optimize_stage2
MDEV-17678:
=~ AddressSanitizer: heap-use-after-free|signal 11
=~ Field::val_str|Field::is_null|ErrConvString::ptr
=~ field_unpack
=~ print_keydup_error
=~ ha_myisam::enable_indexes
MDEV-17636:
=~ Assertion \`pagecache->block_root[i]\.status == 0'
=~ check_pagecache_is_cleaned_up
=~ end_pagecache
MDEV-17627:
=~ Assertion \`inited==RND'
=~ handler::ha_rnd_end
=~ handler::ha_rnd_init_with_error|handler::read_first_row
MDEV-17622:
=~ Assertion \`block->type == PAGECACHE_EMPTY_PAGE \|\| block->type == type \|\| type == PAGECACHE_LSN_PAGE \|\| type == PAGECACHE_READ_UNKNOWN_PAGE \|\| block->type == PAGECACHE_READ_UNKNOWN_PAGE'
=~ pagecache_read
=~ _ma_scan_block_record
MDEV-17580:
=~ Server version: 10\.1|Server version: 10\.0
=~ Diagnostics_area::set_ok_status.*Assertion \`! is_set()'
=~ mysql_alter_table
=~ ADD CHECK
MDEV-17576:
=~ Assertion \`share->reopen == 1'
=~ maria_extra
=~ mysql_alter_table|mysql_create_or_drop_trigger
MDEV-17556:
=~ Assertion \`bitmap_is_set_all(&table->s->all_set)'
=~ handler::ha_reset
=~ close_thread_tables
MDEV-17361:
=~ signal 11|AddressSanitizer: SEGV on unknown address
=~ Query_arena::set_query_arena
=~ THD::set_n_backup_active_arena
=~ Field::set_default
MDEV-17275:
=~ Assertion \`thd->mdl_context\.is_lock_owner(MDL_key::TABLE, table_list->db, table_list->table_name, MDL_SHARED)'
=~ get_table_share
=~ get_table_share_with_discover
MDEV-17223:
=~ Assertion \`thd->killed != 0'
=~ ha_maria::enable_indexes
=~ handler::ha_end_bulk_insert
MDEV-17166:
=~ signal 11|AddressSanitizer: SEGV on unknown address
=~ heap_check_heap
=~ heap_close
=~ tc_purge
MDEV-17120:
=~ signal 11
=~ base_list::push_back
=~ multi_update::prepare
=~ sp_head::execute
MDEV-17120:
=~ AddressSanitizer: use-after-poison
=~ multi_update::prepare
=~ JOIN::prepare
=~ sp_instr_stmt::execute
MDEV-17091:
=~ Assertion \`part_id == m_last_part'
=~ ha_partition::delete_row
=~ mysql_delete
MDEV-17091:
=~ Assertion \`old_part_id == m_last_part'
=~ ha_partition::update_row
=~ mysql_update|Update_rows_log_event::do_exec_row|mysql_multi_update|mysql_load
MDEV-17019:
=~ signal 11
=~ multi_delete::~multi_delete
=~ Prepared_statement::execute
MDEV-17005:
=~ AddressSanitizer: heap-use-after-free|AddressSanitizer: heap-buffer-overflow
=~ innobase_get_computed_value
=~ row_upd_clust_step|row_ins_clust_index_entry
MDEV-17004:
=~ InnoDB: Assertion failure in thread .* in file ha_innodb.cc line
=~ innobase_get_fts_charset
=~ Server version: 10\.1|Server version: 10\.0
=~ ADD FULLTEXT
MDEV-16994:
=~ signal 11|Assertion \`!alloced \|\| !Ptr \|\| !Alloced_length \|\| (Alloced_length >= (str_length + 1))'
=~ String::c_ptr|base_list_iterator::next
=~ partition_info::prune_partition_bitmaps
=~ open_and_process_table
MDEV-16985:
=~ Assertion \`strcmp(share->unique_file_name,filename) \|\| share->last_version'
=~ test_if_reopen
=~ mi_open
=~ open_table_from_share
MDEV-16962:
=~ Assertion \`!error \|\| !ot_ctx.can_recover_from_failed_open()'
=~ open_purge_table
MDEV-16940:
=~ signal 11|AddressSanitizer: SEGV on unknown address
=~ unsafe_key_update
=~ mysql_multi_update_prepare
=~ sp_head::execute
MDEV-16932:
=~ AddressSanitizer: heap-use-after-free|AddressSanitizer: heap-buffer-overflow
=~ my_well_formed_char_length_utf8|lex_string_cmp|my_strcasecmp_utf8
=~ mysql_prepare_create_table
=~ sp_head::execute|Prepared_statement::execute
MDEV-16929:
=~ Assertion \`thd->transaction\.stmt\.is_empty() \|\| (thd->state_flags & Open_tables_state::BACKUPS_AVAIL)'
=~ open_normal_and_derived_tables
=~ mysql_test_create_view
=~ check_prepared_statement
=~ KILL_SERVER|KILL_CONNECTION
MDEV-16929:
=~ Assertion \`thd->transaction\.stmt\.is_empty() \|\| (thd->state_flags & Open_tables_state::BACKUPS_AVAIL)'
=~ open_normal_and_derived_tables
=~ mysql_table_grant
=~ KILL_SERVER|KILL_CONNECTION
MDEV-16887:
=~ Assertion \`n_idx > 0'
=~ trx_undo_log_v_idx
=~ trx_undo_report_row_operation
MDEV-16866:
=~ InnoDB: redo log checkpoint: 0 [ chk key ]:
=~ InnoDB: Redo log crypto: failed to decrypt log block. Reason could be
MDEV-16794:
=~ Server version: 10\.1|Server version: 10\.0
=~ Assertion \`thd->transaction\.stmt\.is_empty()'
=~ Locked_tables_list::unlock_locked_tables
=~ mysql_inplace_alter_table
MDEV-16788:
=~ Assertion \`ls->length < 0xFFFFFFFFL && ((ls->length == 0 && !ls->str) \|\| ls->length == strlen(ls->str))'
=~ String::q_append|Static_binary_string::q_append
=~ pack_vcols
MDEV-16788:
=~ AddressSanitizer: heap-use-after-free
=~ my_strcasecmp_utf8
=~ handle_if_exists_options
=~ Sql_cmd_alter_table::execute
MDEV-16745:
=~ Assertion \`thd->transaction\.stmt\.is_empty()'
=~ Prepared_statement::prepare|Sql_cmd_alter_table::execute
=~ KILL_CONNECTION|KILL_SERVER
MDEV-16745:
=~ Assertion \`thd->transaction\.stmt\.is_empty() \|\| thd->in_sub_stmt \|\| (thd->state_flags & Open_tables_state::BACKUPS_AVAIL)'
=~ close_thread_tables
=~ mysqld_show_create
=~ KILL_SERVER
MDEV-16699:
=~ AddressSanitizer: heap-use-after-free|signal 11
=~ my_strnncoll_binary
=~ Field_blob::cmp
MDEV-16664:
=~ InnoDB: Failing assertion: !other_lock \|\| wsrep_thd_is_BF(lock->trx->mysql_thd, FALSE) \|\| wsrep_thd_is_BF(other_lock->trx->mysql_thd, FALSE)
=~ lock_rec_queue_validate
=~ row_search_mvcc
MDEV-16659:
=~ Assertion \`anc_page->org_size == anc_page->size'
=~ d_search
=~ _ma_ck_real_delete
=~ ha_maria::delete_row
MDEV-16635:
=~ signal 11
=~ open_table
=~ open_and_lock_tables
=~ sequence_insert
=~ mysql_create_table_no_lock
MDEV-16549:
=~ Assertion \`context' failed|signal 11
=~ Item_direct_view_ref::fix_fields
=~ mysql_handle_single_derived
MDEV-16500:
=~ Assertion \`user_table->n_def > table->s->fields'
=~ Server version: 10\.1
=~ innobase_get_col_names
=~ Sql_cmd_alter_table::execute
MDEV-16222:
=~ InnoDB: tried to purge non-delete-marked record in index
=~ Assertion \`0'
=~ row_purge_remove_sec_if_poss_leaf
=~ row_purge
MDEV-16128:
=~ signal 11
=~ Item_func::print_op
=~ mysql_select
=~ Prepared_statement::execute|sp_instr_stmt::execute
MDEV-16128:
=~ pure virtual method called
=~ Item_func::convert_const_compared_to_int_field|Item_func::check_argument_types_like_args0
=~ setup_without_group
=~ Prepared_statement::execute|sp_instr_stmt::execute
MDEV-15977:
=~ Assertion \`! thd->in_sub_stmt' failed
=~ SEQUENCE::read_initial_values
=~ open_table_from_share
MDEV-15955:
=~ Assertion \`field_types == 0 \|\| field_types[field_pos] == MYSQL_TYPE_LONGLONG'
=~ Server version: 10\.1|Server version: 10\.0|Server version: 5\.5
=~ Protocol_text::store_longlong
=~ end_send_group
MDEV-15912:
=~ Failing assertion: purge_sys\.tail\.commit <= purge_sys\.rseg->last_commit
=~ TrxUndoRsegsIterator::set_next
=~ trx_purge_choose_next_log
MDEV-15800:
=~ Assertion \`next_insert_id >= auto_inc_interval_for_cur_row\.minimum()'
=~ handler::update_auto_increment
=~ mysql_load|select_insert::send_data
MDEV-15878:
=~ Assertion \`table->file->stats\.records > 0 \|\| error'
=~ join_read_const_table
=~ JOIN::optimize
=~ mysql_select|mysql_update
MDEV-15572:
=~ signal 11|AddressSanitizer: SEGV
=~ ha_maria::end_bulk_insert|ha_maria::extra
=~ select_insert::abort_result_set
MDEV-15534:
=~ Assertion \`m_lock_type == 2'
=~ handler::ha_drop_table
=~ free_tmp_table
=~ sp_instr_stmt::exec_core
MDEV-15534:
=~ mi_set_index_cond_func|ma_set_index_cond_func
=~ mark_used_tables_as_free_for_reuse
=~ sp_instr_stmt::exec_core
MDEV-15534:
=~ InnoDB: Failing assertion: prebuilt->magic_n == ROW_PREBUILT_ALLOCATED
=~ row_update_prebuilt_trx
=~ ha_innobase::external_lock
MDEV-15471:
=~ Assertion \`new_clustered == ctx->need_rebuild()'
=~ ha_innobase::commit_inplace_alter_table
=~ ha_partition::commit_inplace_alter_table
MDEV-15464:
=~ Assertion \`purge_sys\.purge_queue\.empty() \|\| purge_sys\.purge_queue\.top() != m_rsegs'
=~ TrxUndoRsegsIterator::set_next
=~ trx_purge_choose_next_log
MDEV-15458:
=~ AddressSanitizer: heap-buffer-overflow|signal 11|Conditional jump or move depends on uninitialised value|AddressSanitizer: heap-use-after-free|AddressSanitizer: SEGV on unknown address
=~ heap_scan
=~ handler::ha_rnd_next
=~ rr_sequential
=~ mysql_update
MDEV-15401:
=~ Item_direct_view_ref::used_tables() const: Assertion \`fixed' failed
=~ Item_func_nullif::update_used_tables
=~ Prepared_statement::execute
MDEV-15257:
=~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
=~ Diagnostics_area::set_ok_status|Diagnostics_area::set_error_status
=~ THD::raise_condition|my_ok
=~ mysql_prepare_create_table|mysql_alter_table
MDEV-15011:
=~ Server version: 10\.2|Server version: 10\.1|Server version: 10\.0|Server version: 5\.5
=~ AddressSanitizer: heap-buffer-overflow|signal 11
=~ decimal2bin
=~ my_decimal2binary
=~ find_all_keys
MDEV-15011:
=~ Server version: 10\.2|Server version: 10\.1|Server version: 10\.0|Server version: 5\.5
=~ signal 11
=~ push_back
=~ MDL_lock::Ticket_list::add_ticket
=~ MDL_context::try_acquire_lock_impl
MDEV-15011:
=~ Server version: 10\.2|Server version: 10\.1|Server version: 10\.0|Server version: 5\.5
=~ Error: Freeing overrun buffer
=~ sysmalloc: Assertion \`(old_top == initial_top (av) && old_size == 0) \|\| ((unsigned long) (old_size) >= MINSIZE && prev_inuse (old_top) && ((unsigned long) old_end & (pagesize - 1)) == 0)'
=~ ilink::operator new
MDEV-14996:
=~ Assertion \`!thd->get_stmt_da()->is_sent() \|\| thd->killed == KILL_CONNECTION'
=~ int ha_maria::external_lock
=~ THD::cleanup
=~ Status: KILL_CONNECTION|Status: KILL_SERVER
MDEV-14894:
=~ Assertion \`remove_type == TDC_RT_REMOVE_UNUSED \|\| thd->mdl_context\.is_lock_owner(MDL_key::TABLE, db, table_name, MDL_EXCLUSIVE)'
=~ tdc_remove_table
=~ mysql_rm_table_no_locks
MDEV-14854:
=~ Assertion \`trid >= info->s->state\.create_trid'
=~ transid_store_packed
=~ _ma_make_key
=~ ha_maria::write_row
MDEV-14557:
=~ Assertion \`m_sp == __null'
=~ Item_func_sp::init_result_field
=~ find_field_in_view
=~ sp_instr_stmt::exec_core
MDEV-14472:
=~ Assertion \`is_current_stmt_binlog_format_row()'
=~ THD::binlog_write_table_map
=~ write_locked_table_maps
MDEV-13644:
=~ void ilink::assert_linked(): Assertion \`prev != 0 && next != 0'
=~ unlink_not_visible_thd
=~ Status: KILL_SERVER
MDEV-11740:
=~ Assertion \`pos != (~(my_off_t) 0)' failed
=~ my_seek
=~ _mi_get_block_info
MDEV-11739:
=~ Failing assertion: templ->mysql_null_bit_mask|Assertion \`templ->mysql_null_bit_mask' failed
=~ row_sel_store_mysql_field_func
=~ row_search_mvcc
=~ DsMrr_impl::dsmrr_next
MDEV-11566:
=~ get_store_key
=~ get_best_combination
=~ Server version: 10\.2|Server version: 10\.1|Server version: 10\.0|Server version: 5\.5
MDEV-10945:
=~ Diagnostics_area::set_ok_status
=~ Status: KILL_BAD_DATA
=~ Server version: 10\.1|Server version: 10\.0|Server version: 5\.5
MDEV-10748:
=~ AddressSanitizer: heap-use-after-free|signal 11
=~ ha_maria::implicit_commit
=~ trans_commit_implicit
MDEV-10466:
=~ SEL_ARG::store_min
=~ ror_scan_selectivity
=~ SQL_SELECT::test_quick_select
MDEV-8089:
=~ Apc_target::make_apc_call
=~ fill_show_explain
=~ get_schema_tables_result
MDEV-5628:
=~ Server version: 10\.1|Server version: 10\.0|Server version: 5\.5
=~ Assertion \`! is_set()'
=~ Diagnostics_area::set_ok_status
=~ mysql_update
=~ ( SELECT 
MDEV-5628:
=~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())' failed
=~ Diagnostics_area::set_ok_status
=~ mysql_update
=~ ( SELECT 
TODO-842:
=~ signal 11|AddressSanitizer: use-after-poison
=~ mem_heap_dup
=~ row_log_table_get_pk_col
=~ row_upd_step
TODO-842:
=~ InnoDB: Failing assertion: err == DB_SUCCESS
=~ JOIN_CACHE::join_records
=~ rbt_eject_node
TODO-842:
=~ InnoDB: foreign constraints: secondary index is out of sync
=~ Assertion \`!"secondary index is out of sync"'
=~ dict_index_t::vers_history_row
=~ row_upd_check_references_constraints
TODO-842:
=~ InnoDB: Failing assertion: s_latch == rw_lock_own(&index->lock, 352)
=~ Version: '10\.1
=~ row_ins_scan_sec_index_for_duplicate
=~ mysql_load
TODO-842:
=~ InnoDB: Failing assertion: sym_node->table != NULL
=~ Version: '10\.1
=~ pars_retrieve_table_def
=~ fts_sync_index
TODO-842:
=~ AddressSanitizer: heap-buffer-overflow
=~ Field_timestamp_with_dec::sort_string
=~ Field::make_sort_key
=~ Bounded_queue
TODO-842:
=~ LeakSanitizer: detected memory leaks
=~ mem_heap_create_block_func
=~ mem_heap_add_block
=~ dtuple_create_with_vcol
TODO-842:
=~ signal 11
=~ Time_zone_system::gmt_sec_to_TIME
=~ Temporal_with_date::Temporal_with_date
=~ Arg_comparator::compare_datetime
TODO-842:
=~ signal 11
=~ wait_while_table_is_used
=~ mysql_rm_table_no_locks
=~ mysql_create_table
TODO-842:
=~ AddressSanitizer: SEGV on unknown address
=~ Query_arena::set_query_arena
=~ Field::set_default
=~ Item::remove_eq_conds
TODO-842:
=~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
=~ Diagnostics_area::set_ok_status
=~ BACKUP STAGE BLOCK_COMMIT
TODO-842:
=~ AddressSanitizer: heap-buffer-overflow
=~ update_const_equal_items
=~ join_read_const_table
=~ make_join_statistics
=~ mysql_multi_update
TODO-842:
=~ InnoDB: Failing assertion: !index->n_def \|\| i <= max_n_fields
=~ rem0rec\.cc
=~ rec_offs_validate
=~ rec_get_nth_cfield
TODO-842:
=~ AddressSanitizer: SEGV on unknown address
=~ check_fields
=~ mysql_update
=~ sp_instr_stmt::execute
TODO-842:
=~ Assertion \`Item_cache_temporal::field_type() == MYSQL_TYPE_TIME'
=~ Item_cache_temporal::val_time_packed
=~ Item_func_between::val_int
TODO-842:
=~ AddressSanitizer: heap-use-after-free
=~ Query_arena::strmake
=~ list_callback
=~ THD_list::iterate
TODO-842:
=~ AddressSanitizer: SEGV on unknown address
=~ Item_field::used_tables
=~ Item::const_item
=~ mysql_update
=~ sp_instr_stmt::execute
TODO-842:
=~ Server version: 10\.1
=~ InnoDB: Failing assertion: s_latch == rw_lock_own(&index->lock, 352)
=~ row_ins_scan_sec_index_for_duplicate
=~ row_ins_index_entry
TODO-842:
=~ InnoDB: Page .* log sequence number .* is in the future! Current system log sequence number .*
=~ InnoDB: Your database may be corrupt or you may have copied the InnoDB tablespace but not the InnoDB log files
=~ Assertion \`undo->state == 3'
=~ trx_undo_commit_cleanup
=~ trx_rollback_resurrected
TODO-842:
=~ Assertion \`log->blobs'
=~ row_log_table_apply_update
=~ row_log_table_apply_op
=~ ha_innobase::inplace_alter_table
TODO-842:
=~ Server version: 10\.1
=~ AddressSanitizer: heap-use-after-free
=~ row_ins_check_foreign_constraint
=~ row_ins_index_entry
TODO-842:
=~ AddressSanitizer: SEGV|signal 11
=~ mi_extra
=~ ha_partition::loop_extra_alter
=~ wait_while_table_is_used
=~ fast_alter_partition_table
TODO-842:
=~ AddressSanitizer: heap-use-after-free
=~ ib_vector_size
=~ fts_cache_append_deleted_doc_ids
=~ init_ftfuncs
TODO-842:
=~ AddressSanitizer: heap-use-after-free
=~ maria_status
=~ ha_partition::info
=~ ha_partition::update_create_info
=~ mysql_prepare_alter_table
TODO-842:
=~ Assertion \`inited==INDEX'
=~ opt_sum_query
=~ handler::ha_index_end
=~ JOIN::optimize
TODO-842:
=~ Assertion \`(uint) (res->buff[7] & 7) == page_type'
=~ get_head_or_tail_page
=~ allocate_and_write_block_record
=~ maria_write
TODO-842:
=~ Assertion \`m_status == DA_ERROR'
=~ Diagnostics_area::sql_errno
=~ trans_rollback_implicit
=~ mysql_admin_table
TODO-842:
=~ signal 11
=~ Server version: 10\.1
=~ lock_tables_check
=~ mysql_multi_update_prepare
TODO-842:
=~ Assertion \`0'
=~ Field_blob_compressed::get_key_image
=~ stored_field_make_mm_leaf
=~ calculate_cond_selectivity_for_table
TODO-842:
=~ Assertion \`pos < index->n_def'
=~ dict_index_get_nth_field
=~ dict_index_get_nth_col
=~ row_purge_parse_undo_rec
TODO-842:
=~ Assertion \`inited==NONE'
=~ handler::ha_index_init
=~ check_duplicate_long_entry_key
=~ ha_partition::copy_partitions
TODO-842:
=~ Conditional jump or move depends on uninitialised value
=~ row_ins_step
=~ row_update_vers_insert
=~ row_update_cascade_for_mysql
=~ row_ins_foreign_check_on_constraint
TODO-842:
=~ InnoDB: Failing assertion: thr_get_trx(thr)->error_state == DB_SUCCESS
=~ que_run_threads
=~ fts_eval_sql
=~ fts_config_set_value
TODO-842:
=~ AddressSanitizer: heap-use-after-free
=~ innobase_get_computed_value
=~ row_merge_read_clustered_index
=~ ha_innobase::inplace_alter_table
TODO-842:
=~ AddressSanitizer: use-after-poison
=~ ShowStatus::GetCount::operator
=~ innodb_show_mutex_status
=~ innobase_show_status
TODO-842:
=~ Assertion \`!m_freed'
=~ OSMutex::enter
=~ fil_space_crypt_close_tablespace
=~ fil_delete_tablespace
=~ fts_drop_tables
TODO-842:
=~ InnoDB: Failing assertion: index_cache->words == NULL
=~ fts_index_cache_init
=~ fts_sync_table
TODO-842:
=~ Assertion \`!((new_col->prtype ^ col->prtype) & ~256U)'
=~ row_log_table_apply_convert_mrec
=~ row_log_table_apply_op
=~ mysql_alter_table
TODO-842:
=~ Assertion \`update->n_fields < ulint(table->n_cols + table->n_v_cols)'
=~ upd_node_t::make_versioned_helper
=~ TABLE::delete_row

##############################################################################
# Weak matches
##############################################################################

MDEV-19320:
=~ Can't find record
MDEV-18929:
=~ Slave SQL: Error 'Table .* is not system-versioned' on query
MDEV-18805:
=~ Found too many records; Can't continue
=~ Number of rows changed from
MDEV-18805:
=~ signal 11
=~ Field::is_null_in_record
=~ Column_definition::Column_definition
=~ Create_field::Create_field
MDEV-18461:
=~ sure_page <= last_page
MDEV-18461:
=~ head_length == row_pos->length
MDEV-18460:
=~ THD::create_tmp_table_def_key
MDEV-18459:
=~ fil_op_write_log
MDEV-18458:
=~ EVP_MD_CTX_cleanup
MDEV-18454:
=~ ReadView::check_trx_id_sanity
MDEV-18453:
=~ rec_get_deleted_flag
MDEV-18421:
=~ foreign->foreign_table
MDEV-18414:
=~ Value_source::Converter_strntod::Converter_strntod
MDEV-18381:
=~ ha_innobase::store_lock
MDEV-18343:
=~ Mutex RW_LOCK_LIST created sync0debug\.cc
MDEV-18322:
=~ wrong page type
MDEV-18291:
=~ ha_innobase_inplace_ctx::
MDEV-18274:
=~ new_clustered ==
MDEV-18217:
=~ InnoDB: Summed data size
MDEV-18217:
=~ row_sel_field_store_in_mysql_format_func
MDEV-18213:
=~ Error: failed to execute query BACKUP STAGE BLOCK_COMMIT: Deadlock found when trying to get lock
MDEV-18209:
=~ Enabling keys got errno 0 on
MDEV-18200:
=~ InnoDB: Failing assertion: success
MDEV-18187:
=~ error 192 when executing record redo_index_new_page
MDEV-18171:
=~ _ma_write_blob_record
MDEV-18170:
=~ pcur\.old_rec_buf
MDEV-18169:
=~ n_fields <= ulint
MDEV-18168:
=~ general_log_write
MDEV-18158:
=~ Can't find record in
MDEV-18157:
=~ Explain_node::print_explain_for_children
MDEV-18147:
=~ templ->mysql_col_len >= len
MDEV-18146:
=~ field_ref + 12U
MDEV-18146:
=~ btr_page_reorganize_low
MDEV-18146:
=~ merge_page, index
MDEV-18141:
=~ Can't find record in
# Not fixed, but I don't want it to match
# MDEV-18065:
# =~ Fatal error: Can't open and lock privilege tables
MDEV-18063:
=~ is corrupt; try to repair it
MDEV-18062:
=~ ha_innobase::innobase_get_index
MDEV-18058:
=~ trx0i_s\.cc line
MDEV-18054:
=~ ret > 0
MDEV-18054:
=~ mach_read_from_1
MDEV-18047:
=~ Cannot find index .* in InnoDB index dictionary
=~ InnoDB indexes are inconsistent with what defined
=~ InnoDB could not find key no .* with name .* from dict cache for table
=~ contains .* indexes inside InnoDB, which is different from the number of indexes .* defined in the MariaDB
MDEV-18046:
=~ var_header_len >= 2
MDEV-18046:
=~ in Rotate_log_event::Rotate_log_event
MDEV-18046:
=~ m_field_metadata_size <=
MDEV-18046:
=~ in inline_mysql_mutex_destroy
MDEV-18046:
=~ Update_rows_log_event::~Update_rows_log_event
MDEV-18042:
=~ signal 11|AddressSanitizer: SEGV
=~ mysql_alter_table
=~ Sql_cmd_alter_table::execute
MDEV-18017:
=~ index->to_be_dropped
MDEV-17999:
=~ Invalid roles_mapping table entry user
MDEV-17978:
=~ mysqld_show_create_get_fields
MDEV-17977:
=~ Count >= rest_length
MDEV-17976:
=~ lock->magic_n == 22643
MDEV-17976:
=~ rec_get_offsets_func
MDEV-17971:
=~ Field_iterator_table::set
MDEV-17971:
=~ Field_iterator_table_ref::set_field_iterator
MDEV-17962:
=~ setup_jtbm_semi_joins
MDEV-17936:
=~ Field::is_null
MDEV-17897:
=~ block->frame
MDEV-17895:
=~ trx->dict_operation != TRX_DICT_OP_NONE
MDEV-17884:
=~ is marked as crashed and should be repaired
MDEV-17838:
=~ in Item_field::rename_fields_processor
MDEV-17834:
=~ row_upd_build_difference_binary
MDEV-17818:
=~ parse_vcol_defs
MDEV-17814:
=~ is_current_stmt_binlog_format_row
MDEV-17760:
=~ table->read_set, field_index
=~ Server version: 10\.1|Server version: 10\.0|Server version: 5\.5
MDEV-17717:
=~ table->pos_in_locked_tables
MDEV-17711:
=~ arena_for_set_stmt== 0
MDEV-17665:
=~ share->page_type == PAGECACHE_LSN_PAGE
MDEV-17659:
=~ File too short; Expected more data in file
MDEV-17619:
=~ Index file is crashed
MDEV-17619:
=~ Table is crashed and last repair failed
MDEV-17619:
=~ Incorrect key file for table
MDEV-17619:
=~ Got an error from thread_id=
MDEV-17619:
=~ Couldn't repair table
MDEV-17596:
=~ block->page\.flush_observer == __null
MDEV-17583:
=~ next_mrec == next_mrec_end
MDEV-17582:
=~ status_var\.local_memory_used == 0
MDEV-17551:
=~ _ma_state_info_write
MDEV-17539:
=~ Protocol::end_statement
MDEV-17538:
=~ == UNALLOCATED_PAGE
MDEV-17485:
=~ Operating system error number 80 in a file operation
MDEV-17466:
=~ dfield2->type\.mtypex
MDEV-17464:
=~ Operating system error number 2
MDEV-17356:
=~ table->read_set, field_index
MDEV_17344:
=~ Prepared_statement::~Prepared_statement
MDEV-17333:
=~ next_insert_id >= auto_inc_interval_for_cur_row\.minimum
MDEV-17307:
=~ Incorrect key file for table
MDEV-17225:
=~ log_descriptor\.bc\.buffer->prev_last_lsn
MDEV-17217:
=~ in make_sortkey
MDEV-17187:
=~ failed, the table has missing foreign key indexes
MDEV-17054:
=~ InnoDB needs charset 0 for doing a comparison, but MySQL cannot find that charset
MDEV-17054:
=~ in innobase_get_fts_charset
MDEV-17053:
=~ sync_check_iterate
MDEV-16789:
=~ in insert_fields
MDEV-16788:
=~ signal 11
=~ build_frm_image
=~ mysql_create_frm_image
=~ mysql_alter_table
# Need to check that it's happening with temporary tables, or at least there can be temporary tables involved
MDEV-16728:
=~ Slave SQL: Error 'Table .* doesn't exist' on query\. Default database: .*\. Query: 'RENAME TABLE .* Internal MariaDB error code: 1146
MDEV-16728:
=~ Slave SQL: Error 'Table .* already exists' on query\. Default database: .*\. Query: 'RENAME TABLE .* Internal MariaDB error code: 1050
MDEV-16728:
=~ Slave SQL: Error 'ALGORITHM=INPLACE is not supported for this operation. Try ALGORITHM=COPY' on query
MDEV-16539:
=~ THD::mark_tmp_table_as_free_for_reuse
MDEV-16523:
=~ level_and_file\.second->being_compacted
MDEV-16501:
=~ ->coll->strcasecmp
MDEV-16501:
=~ in dict_mem_table_col_rename
MDEV-16407:
=~ in MDL_key::mdl_key_init
MDEV-16407:
=~ Error: Freeing overrun buffer
MDEV-16397:
=~ Can't find record in
MDEV-16292:
=~ Item_func::print
MDEV-16242:
=~ Slave worker thread retried transaction
MDEV-16242:
=~ Can't find record
MDEV-16184:
=~ nest->counter > 0
MDEV-16171:
=~ in setup_table_map
MDEV-15949:
=~ space->n_pending_ops == 0
MDEV-15873:
=~ precision > 0
MDEV-15802:
=~ Item::delete_self
MDEV-15753:
=~ thd->is_error
MDEV-15657:
=~ file->inited == handler::NONE
MDEV-15656:
=~ is_last_prefix <= 0
MDEV-15653:
=~ lock_word <= 0x20000000
MDEV-15533:
=~ log->blobs
MDEV-15493:
=~ lock_trx_table_locks_remove
MDEV-15490:
=~ in trx_update_mod_tables_timestamp
MDEV-15486:
=~ String::needs_conversion
MDEV-15484:
=~ element->m_flush_tickets\.is_empty
MDEV-15482:
=~ Type_std_attributes::set
MDEV-15481:
=~ I_P_List_null_counter, I_P_List_fast_push_back
MDEV-15470:
=~ TABLE::mark_columns_used_by_index_no_reset
MDEV-15468:
=~ table_events_waits_common::make_row
MDEV-15329:
=~ in dict_table_check_for_dup_indexes
MDEV-15255:
=~ m_lock_type == 2
MDEV-15255:
=~ sequence_insert
MDEV-15226:
=~ Could not get index information for Index Number
MDEV-15164:
=~ ikey_\.type == kTypeValue
MDEV-15161:
=~ in get_addon_fields
MDEV-15013:
=~ trx->state == TRX_STATE_NOT_STARTED
MDEV-15011:
=~ Server version: 10\.2|Server version: 10\.1|Server version: 10\.0|Server version: 5\.5
=~ signal 11
=~ _mi_read_rnd_static_record
=~ mi_scan
=~ find_all_keys
MDEV-15011:
=~ Server version: 10\.2|Server version: 10\.1|Server version: 10\.0|Server version: 5\.5
=~ test_if_reopen
=~ mi_create
=~ ha_myisam::create
MDEV-15011:
=~ Server version: 10\.2|Server version: 10\.1|Server version: 10\.0|Server version: 5\.5
=~ Freeing overrun buffer  sql/opt_range\.cc:.*, sql/rpl_record\.cc:.*
=~ signal 11
MDEV-15011:
=~ Server version: 10\.2|Server version: 10\.1|Server version: 10\.0|Server version: 5\.5
=~ signal 11
=~ _db_enter_
=~ handler::ha_rnd_next
=~ find_all_keys
MDEV-15011:
=~ Server version: 10\.2|Server version: 10\.1|Server version: 10\.0|Server version: 5\.5
=~ signal 11
=~ JOIN::exec_inner
=~ mysql_select
MDEV-15011:
=~ Server version: 10\.2|Server version: 10\.1|Server version: 10\.0|Server version: 5\.5
=~ signal 11
=~ test_if_reopen
=~ mi_open
MDEV-15011:
=~ Server version: 10\.2|Server version: 10\.1|Server version: 10\.0|Server version: 5\.5
=~ Error in \`.*/mysqld': malloc(): memory corruption:
MDEV-14894:
=~ tdc_remove_table
MDEV-14894:
=~ table->in_use == thd
MDEV-14864:
=~ in mysql_prepare_create_table
MDEV-14864:
=~ in mysql_prepare_alter_table
MDEV-14846:
=~ prebuilt->trx, TRX_STATE_ACTIVE
MDEV-14846:
=~ state == TRX_STATE_FORCED_ROLLBACK
MDEV-14836:
=~ m_status == DA_ERROR
MDEV-14833:
=~ trx->error_state == DB_SUCCESS
MDEV-14711:
=~ fix_block->page\.file_page_was_freed
MDEV-14643:
=~ cursor->index->is_committed
MDEV-14642:
=~ table->s->db_create_options == part_table->s->db_create_options
MDEV-14264:
=~ binlog_cache_data::reset
MDEV-14040:
=~ in Field::is_real_null
MDEV-12978:
=~ log_calc_max_ages
MDEV-12329:
=~ 1024U, trx, rec, block
MDEV-12059:
=~ precision > 0
MDEV-11783:
=~ checksum_length == f->ptr
MDEV-9137:
=~ in _ma_ck_real_write_btree
MDEV-5924:
=~ Query_cache::register_all_tables

##############################################################################
# Fixed:
##############################################################################

# MDEV-4312: make_lock_and_pin
# MDEV-10130: share->in_trans == 0
# MDEV-10130: file->trn == trn
# MDEV-11071: thd->transaction.stmt.is_empty
# MDEV-11071: in THD::mark_tmp_table_as_free_for_reuse
# MDEV-11167: Can't find record
# MDEV-11539:
# =~ mi_open.c:67:
# =~ test_if_reopen
# MDEV-11741: table->s->all_set
# MDEV-11741: in ha_heap::rnd_next
# MDEV-11741: in handler::ha_reset
# MDEV-11741: mi_reset
# MDEV-11741: old_top == initial_top
# MDEV-14100: dict_index_get_n_unique_in_tree_nonleaf
# MDEV-14134: dberr_t row_upd_sec_index_entry
# MDEV-14409: page_rec_is_leaf
# MDEV-14440: inited==RND
# MDEV-14440: in ha_partition::external_lock
# MDEV-14440:
# =~ pure virtual method called
# MDEV-14695: n < m_size
# MDEV-14743: Item_func_match::init_search
# MDEV-14829: protocol.cc:588: void Protocol::end_statement
# MDEV-14943: type == PAGECACHE_LSN_PAGE
# MDEV-15060: row_log_table_apply_op
# MDEV-15114: mem_heap_dup
# MDEV-15114: dberr_t row_upd_sec_index_entry
# MDEV-15243: in Field_blob::pack
# MDEV-15475: table->read_set, field_index
# MDEV-15537: in mysql_prepare_alter_table
# MDEV-15551:
# =~ share->last_version
# MDEV-15626: old_part_id == m_last_part
# MDEV-15729: in Field::make_field
# MDEV-15729: Field::make_send_field
# MDEV-15729: send_result_set_metadata
# MDEV-15738: in my_strcasecmp_utf8
# MDEV-15797: thd->killed != 0
# MDEV-15380: is corrupt; try to repair it
# MDEV-15828: num_fts_index <= 1
# MDEV-15855: innobase_get_computed_value
# MDEV-15855: innobase_allocate_row_for_vcol
# MDEV-15872: row_log_table_get_pk_col
# MDEV-15872: in mem_heap_dup
# Not closed, but probably by mistake
# MDEV-15947:
# =~ Error: Freeing overrun buffer
# MDEV-15947:
# =~ in find_field_in_tables
# MDEV-16043: st_select_lex::fix_prepare_information
# MDEV-16043: thd->Item_change_list::is_empty
# MDEV-16153: Apc_target::disable
# MDEV-16166: Can't find record in
# MDEV-16217: table->read_set, field_index
# MDEV-16241: inited==RND
# MDEV-16429: table->read_set, field_index
# MDEV-16512: in find_field_in_tables
# MDEV-16682: == HEAD_PAGE
# MDEV-16682: in _ma_read_block_record
# MDEV-16779: rw_lock_own
# MDEV-16783: in mysql_delete
# MDEV-16783: !conds
# MDEV-16961: table->read_set, field_index
# MDEV-17021: length <= column->length
# MDEV-17021: in write_block_record
# MDEV-17027: table_list->table
# MDEV-17027: Field_iterator_table_ref::set_field_iterator
# MDEV-17027: in add_key_field
# MDEV-17167: table->get_ref_count
# MDEV-17215: in row_purge_remove_clust_if_poss_low
# MDEV-17215: in row_purge_upd_exist_or_extern_func
# MDEV-17219: !dt->fraction_remainder
# MDEV-17314: thd->transaction.stmt.is_empty
# MDEV-17349: table->read_set, field_index
# MDEV-17354: in add_key_field
# MDEV-17432: lock_trx_has_sys_table_locks
# MDEV-17470: Operating system error number 17 in a file operation
# MDEV-17470: returned OS error 71. Cannot continue operation
# MDEV-17479:
# =~ mysql_socket.fd != -1
# MDEV-17697: col.vers_sys_end
# MDEV-17755: table->s->reclength
# MDEV-17823: row_sel_sec_rec_is_for_clust_rec
# MDEV-17885: Could not remove temporary table
# MDEV-17901: row_parse_int
# MDEV-17938: block->magic_n == MEM_BLOCK_MAGIC_N
# MDEV-17938: dict_mem_table_free
# MDEV-17972:
# =~ is_valid_value_slow
# MDEV-17975: m_status == DA_OK_BULK
# MDEV-18072: == item->null_value
# MDEV-18076: in row_parse_int
# MDEV-18083:
# =~ heap-use-after-free|heap-buffer-overflow
# =~ push_warning_printf
# =~ Field::set_warning_truncated_wrong_value
# MDEV-18083:
# =~ AddressSanitizer: heap-use-after-free
# =~ THD::push_warning_truncated_value_for_field
# MDEV-18083:
# =~ in intern_close_table
# MDEV-18083:
# =~ tc_purge
# MDEV-18083:
# =~ tc_remove_all_unused_tables
# MDEV-18083:
# =~ make_truncated_value_warning
# MDEV-18083:
# =~ Column_definition::Column_definition
# MDEV-18183: id != LATCH_ID_NONE
# MDEV-18183: OSMutex::enter
# MDEV-18195:
# =~ Item::eq
# MDEV-18195:
# =~ lex_string_cmp
# MDEV-18218: btr_page_reorganize_low
# MDEV-18219:
# =~ index->n_core_null_bytes <=
# MDEV-18339:
# =~ AddressSanitizer: heap-buffer-overflow|AddressSanitizer: use-after-poison
# =~ Item_exists_subselect::is_top_level_item
# =~ Item_in_optimizer::eval_not_null_tables
# =~ st_select_lex::optimize_unflattened_subqueries
# MDEV-18339:
# =~ Conditional jump or move depends on uninitialised value
# =~ Item_in_optimizer::eval_not_null_tables
# =~ st_select_lex::optimize_unflattened_subqueries
# MDEV-18711:
# =~ Assertion \`key_info->key_part->field->flags & (1<< 30)'|fields_in_hash_keyinfo
# =~ setup_keyinfo_hash
# =~ Sql_cmd_alter_table::execute
# MDEV-18712:
# =~ Found index .* whose column info does not match that of MariaDB
# =~ InnoDB indexes are inconsistent with what defined in \.frm for table
# MDEV-18720:
# =~ Assertion \`inited==NONE'
# =~ handler::ha_index_init
# =~ check_duplicate_long_entry_key
# =~ vers_insert_history_row
# MDEV-18722:
# =~ Assertion \`templ->mysql_null_bit_mask'
# =~ row_sel_store_mysql_rec
# =~ check_duplicate_long_entry_key
# =~ handler::ha_write_row
# MDEV-18725:
# =~ Assertion failure in file .*innobase/fts/fts0fts\.cc
# =~ fts_get_charset
# =~ row_create_index_for_mysql
# MDEV-18731:
# =~ Assertion \`!trx->n_mysql_tables_in_use'
# =~ trx_free
# =~ innobase_close_connection
# MDEV-18747:
# =~ InnoDB: Failing assertion: table->get_ref_count() == 0
# =~ dict_table_remove_from_cache
# =~ THD::rm_temporary_table
# MDEV-18749:
# =~ Conditional jump or move depends on uninitialised value
# =~ rec_get_converted_size_comp_prefix_low
# =~ row_merge_buf_write
# =~ fts_parallel_tokenization
# MDEV-18755:
# =~ Assertion \`inited==INDEX' failed
# =~ ha_index_read_map
# =~ join_read_always_key
# MDEV-18755:
# =~ AddressSanitizer: heap-buffer-overflow
# =~ calculate_key_len
# =~ handler::prepare_index_key_scan_map
# =~ join_read_always_key
# =~ mysql_union
# MDEV-18763:
# =~ Conditional jump or move depends on uninitialised value
# =~ mi_rrnd
# =~ ha_myisam::rnd_pos
# MDEV-18775:
# =~ signal 11
# =~ dict_table_t::instant_column
# =~ commit_inplace_alter_table
# MDEV-18775:
# =~ Warning: assertion failed: f\.col->is_virtual()
# =~ dict_table_t::instant_column
# =~ mysql_inplace_alter_table
# MDEV-654:
# =~ share->now_transactional
# MDEV-5791:
# =~  in Field::is_real_null
# MDEV-6453:
# =~  int handler::ha_rnd_init
# MDEV-11080:
# =~ table->n_waiting_or_granted_auto_inc_locks > 0
# MDEV-13024:
# =~ in multi_delete::send_data
# MDEV-13103:
# =~ fil0pagecompress\.cc:[0-9]+: void fil_decompress_page
# MDEV-13202:
# =~ ltime->neg == 0
# MDEV-13231:
# =~ in _ma_unique_hash
# MDEV-13699:
# =~ == new_field->field_name\.length
# MDEV-13828:
# =~ in handler::ha_index_or_rnd_end
# MDEV-14407:
# =~ trx_undo_rec_copy
# MDEV-14410:
# =~ table->pos_in_locked_tables->table == table
# MDEV-14693:
# =~ clust_index->online_log
# MDEV-14697:
# =~ in TABLE::mark_default_fields_for_write
# MDEV-14762:
# =~ has_stronger_or_equal_type
# MDEV-14815:
# =~ in has_old_lock
# MDEV-14825:
# =~ col->ord_part
# MDEV-14862:
# =~ in add_key_equal_fields
# MDEV-14905:
# =~ purge_sys->state == PURGE_STATE_INIT
# MDEV-14906:
# =~ index->is_instant
# MDEV-14994:
# =~ join->best_read < double
# MDEV-15103:
# =~ virtual ha_rows ha_partition::part_records
# MDEV-15115:
# =~ dict_tf2_is_valid
# MDEV-15130:
# =~ table->s->null_bytes == 0
# MDEV-15130:
# =~ static void PFS_engine_table::set_field_char_utf8
# MDEV-15175:
# =~ Item_temporal_hybrid_func::val_str_ascii
# MDEV-15216:
# =~ m_can_overwrite_status
# MDEV-15217:
# =~ transaction\.xid_state\.xid\.is_null
# MDEV-15245:
# =~ myrocks::ha_rocksdb::position
# MDEV-15308:
# =~ ha_alter_info->alter_info->drop_list\.elements > 0
# MDEV-15319:
# =~ myrocks::ha_rocksdb::convert_record_from_storage_format
# MDEV-15330:
# =~ table->insert_values
# MDEV-15336:
# =~ ha_partition::print_error
# MDEV-15374:
# =~ trx_undo_rec_copy
# MDEV-15391:
# =~ join->best_read < double
# MDEV-15465:
# =~ Item_func_match::cleanup
# MDEV-15576:
# =~ item->null_value
# MDEV-15742:
# =~ m_lock_type == 1
# MDEV-15744:
# =~ Assertion \`derived->table'
# =~ mysql_derived_merge_for_insert
# =~ mysql_load
# MDEV-15812:
# =~ virtual handler::~handler
# MDEV-15816:
# =~ m_lock_rows == RDB_LOCK_WRITE
# MDEV-15950:
# =~ find_dup_table
# MDEV-15950:
# =~ find_table_in_list
# MDEV-16131:
# =~ id == DICT_INDEXES_ID
# MDEV-16154:
# =~ in myrocks::ha_rocksdb::load_auto_incr_value_from_index
# MDEV-16169:
# =~ space->referenced
# MDEV-16170:
# =~ Item_null_result::type_handler
# MDEV-16190:
# =~ in Item_null_result::field_type
# MDEV-16499:
# =~ from the internal data dictionary of InnoDB though the \.frm file for the table exists
# MDEV-16499:
# =~ is corrupted\. Please drop the table and recreate
# MDEV-16738:
# =~ == Item_func::MULT_EQUAL_FUNC
# MDEV-16792:
# =~ in Diagnostics_area::sql_errno
# MDEV-16903:
# =~ auto_increment_field_not_null
# MDEV-16905:
# =~ TABLE::verify_constraints
# MDEV-16918:
# =~ find_field_in_tables
# =~ setup_windows
# =~ Prepared_statement::execute
# MDEV-16957:
# =~ Field_iterator_natural_join::next
# MDEV-16971:
# =~ adjust_time_range_or_invalidate
# MDEV-16980:
# =~ == table_name_arg->length
# MDEV-16982:
# =~ in mem_heap_dup
# MDEV-16982:
# =~ row_mysql_convert_row_to_innobase
# MDEV-16992:
# =~ Field_iterator_table_ref::set_field_iterator
# MDEV-17015:
# =~ m_year <= 9999
# MDEV-17016:
# =~ auto_increment_safe_stmt_log_lock
# MDEV-17020:
# =~ length > 0
# MDEV-17051:
# =~ sec_mtr->has_committed
# MDEV-17055:
# =~ got signal 11|AddressSanitizer: heap-use-after-free
# =~ find_order_in_list
# =~ mysql_prepare_update
# =~ sp_head::execute_procedure
# MDEV-17070:
# =~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
# =~ mysql_load
# MDEV-17070:
# =~ Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
# =~ mysql_alter_table|Sql_cmd_truncate_table::execute|mysql_rm_table
# =~ is marked as crashed and should be repaired
# =~ #sql.*is marked as crashed and should be repaired
# MDEV-17070:
# =~ \`table->file->stats\.records > 0 \|\| error'
# =~ join_read_const_table
# =~ make_join_statistics
# =~ mysql_select
# =~ mysql_load
# MDEV-17070:
# =~ Assertion \`! is_set()'
# =~ my_eof
# =~ mysqld_show_create
# MDEV-17107:
# =~ table_list->table
# MDEV-17199:
# =~ pos < table->n_v_def
# MDEV-17216:
# =~ !dt->fraction_remainder
# MDEV-17257:
# =~ in get_datetime_value
# MDEV-17257:
# =~ in Item::field_type_for_temporal_comparison
# MDEV-17319:
# =~ ts_type != MYSQL_TIMESTAMP_TIME
# MDEV-17319:
# =~ int Field_temporal::store_invalid_with_warning
# MDEV-17595:
# =~ got signal 11
# =~ copy_data_between_tables
# =~ mysql_alter_table
# MDEV-17595:
# =~ Assertion \`thd->transaction\.stmt\.is_empty() \|\| (thd->state_flags & Open_tables_state::BACKUPS_AVAIL)' failed
# =~ close_tables_for_reopen
# =~ mysql_alter_table
# MDEV-17725:
# =~ Diagnostics_area::set_ok_status.*Assertion \`!is_set() \|\| (m_status == DA_OK_BULK && is_bulk_op())'
# =~ mysql_alter_table
# =~ ALTER .* ORDER BY
# MDEV-17725:
# =~ ORDER BY ignored as there is a user-defined clustered index in the table
# MDEV-17738:
# =~ Item::delete_self
# MDEV-17738:
# =~ st_select_lex::fix_prepare_information
# MDEV-17738:
# =~ TABLE_LIST::change_refs_to_fields
# MDEV-17738:
# =~ in change_group_ref
# MDEV-17741:
# =~ thd->Item_change_list::is_empty
# MDEV-17759:
# =~ precision > 0
# MDEV-17763:
# =~ len == 20U
# MDEV-17815:
# =~ index->table->name\.m_name
# MDEV-17816:
# =~ trx->dict_operation_lock_mode == RW_X_LATCH
# MDEV-17820:
# =~ == BTR_NO_LOCKING_FLAG
# MDEV-17821:
# =~ page_rec_is_supremum
# MDEV-17826:
# =~ dfield_is_ext
# MDEV-17831:
# =~ supports_instant
# MDEV-17854:
# =~ decimals <= 6
# MDEV-17892:
# =~ index->was_not_null
# MDEV-17893:
# =~ nulls < null_mask
# MDEV-17904:
# =~ fts_is_sync_needed
# MDEV-17923:
# =~ trx_undo_page_report_modify
# MDEV-17932:
# =~ get_username
# MDEV-17959:
# =~ thd->lex->select_stack_top == 0
# MDEV-17979:
# =~ Item::val_native
# MDEV-18016:
# =~ dict_table_check_for_dup_indexes
# MDEV-18016:
# =~ storage/innobase/dict/dict0dict\.cc line 6199|storage/innobase/dict/dict0dict\.cc line 6346|storage/innobase/dict/dict0dict\.cc line 6181
# =~ dict_table_check_for_dup_indexes
# =~ mysql_inplace_alter_table
# MDEV-18033:
# =~ n < update->n_fields
# MDEV-18039:
# =~ index->table->name\.m_name
# MDEV-18057:
# =~ node->state == 5
# MDEV-18070:
# =~ nanoseconds <= 1000000000
# MDEV-18077:
# =~ n < tuple->n_fields
# MDEV-18121:
# =~ type\.vers_sys_end
# MDEV-18122:
# =~ == m_prebuilt->table->versioned
# MDEV-18145:
# =~ Item_singlerow_subselect::val_native
# MDEV-18149:
# =~ row_parse_int
# MDEV-18150:
# =~ decimals_to_set <= 38
# MDEV-18152:
# =~ num_fts_index <= 1
# MDEV-18160:
# =~ index->n_fields >= n_core
# MDEV-18162:
# =~ dict_index_t::reconstruct_fields
# MDEV-18173:
# =~ col\.vers_sys_end
# MDEV-18173:
# =~ o->ind == vers_end
# MDEV-18173:
# =~ o->ind == vers_start
# MDEV-18185:
# =~ rename_table_in_prepare
# MDEV-18194:
# =~ which is outside the tablespace bounds
# MDEV-18204:
# =~ RocksDB: Problems validating data dictionary against \.frm files, exiting
# MDEV-18205:
# =~ str_length < len
# MDEV-18222:
# =~ heap->magic_n == MEM_BLOCK_MAGIC_N
# MDEV-18222:
# =~ innobase_rename_column_try
# MDEV-18222:
# =~ dict_foreign_remove_from_cache
# MDEV-18239:
# =~ mark_unsupported_function
# MDEV-18256:
# =~ heap->magic_n == MEM_BLOCK_MAGIC_N
# MDEV-18255:
# =~ Item_field::update_table_bitmaps
# MDEV-18256:
# =~ dict_foreign_remove_from_cache
# MDEV-18258:
# =~ append_identifier
# MDEV-18272:
# =~ cursor->index->is_committed
# MDEV-18272:
# =~ InnoDB: tried to purge non-delete-marked record in index
# MDEV-18315:
# =~ col->same_format
# MDEV-18316:
# =~ dict_col_t::instant_value
# MDEV-18369:
# =~ wsrep_handle_SR_rollback
# MDEV-18377:
# =~ recv_sys->mlog_checkpoint_lsn
# MDEV-18447:
# =~ Timestamp_or_zero_datetime::tv
# MDEV-18596:
# =~ AddressSanitizer: unknown-crash
# =~ row_mysql_store_col_in_innobase_format
# =~ ha_innobase::prepare_inplace_alter_table
# MDEV-18598:
# =~ Assertion \`is_string == dtype_is_string_type(mtype)' failed
# =~ innobase_rename_or_enlarge_columns_cache
# MDEV-18598:
# =~ Assertion \`index\.fields[i]\.col->same_format( \*oindex\.fields[i]\.col, true)' failed
# =~ dict_table_t::prepare_instant
# MDEV-18609:
# =~ Assertion \`!is_string || (\*af)->charset() == cf->charset' failed
# =~ innobase_rename_or_enlarge_columns_cache
# MDEV-18632:
# =~ Conditional jump or move depends on uninitialised value
# =~ wsrep_is_wsrep_xid
# =~ innobase_rollback
# MDEV-18668:
# =~ AddressSanitizer: use-after-poison|Invalid read of size|signal 11
# =~ st_select_lex::collect_fields_equal_to_grouping
# =~ st_select_lex::pushdown_from_having_into_where
# MDEV-18681:
# =~ AddressSanitizer: SEGV|signal 11
# =~ embedding_sjm
# =~ substitute_for_best_equal_field
# =~ JOIN::optimize_stage2
# MDEV-18707:
# =~ AddressSanitizer: heap-use-after-free
# =~ Field::is_null
# =~ Type_handler_int_result::Item_save_in_field
# =~ TABLE::update_virtual_fields
# =~ mysql_delete
# MDEV-18707:
# =~ signal 11
# =~ my_hash_sort_bin
# =~ calc_hash_for_unique
# =~ TABLE::update_virtual_fields
# MDEV-18708:
# =~ AddressSanitizer: SEGV|signal 11
# =~ Item_field::register_field_in_read_map
# =~ Item_args::walk_args
# =~ prepare_vcol_for_base_setup
# MDEV-18709:
# =~ signal 11|AddressSanitizer: heap-buffer-overflow
# =~ create_index
# =~ create_table_info_t::create_table
# =~ mysql_alter_table
# MDEV-18709:
# =~ signal 11|AddressSanitizer: global-buffer-overflow
# =~ get_innobase_type_from_mysql_type
# =~ create_index
# =~ Sql_cmd_alter_table::execute
# MDEV-18710:
# =~ Expression for field \`DB_ROW_HASH_1\` is refering to uninitialized field \`DB_ROW_HASH_1\`
# MDEV-18713:
# =~ Assertion \`strcmp(share->unique_file_name,filename) \|\| share->last_version'
# =~ test_if_reopen
# MDEV-18719:
# =~ (c\.prtype ^ o->prtype) & ~(256U \| (16384U|32768U))
# =~ dict_table_t::instant_column
# =~ ha_innobase::commit_inplace_alter_table
# MDEV-18719:
# =~ old \|\| col->same_format(\*old)
# =~ mysql_inplace_alter_table
# MDEV-18889:
# =~ my_strnncoll_binary
# =~ Field::cmp_offset
# =~ check_duplicate_long_entry_key
# =~ Version: '10\.4
# MDEV-18888:
# =~ signal 11|AddressSanitizer: SEGV on unknown address
# =~ Item_field::register_field_in_read_map
# =~ prepare_vcol_for_base_setup
# =~ Version: '10\.4
# MDEV-18876:
# =~ Assertion \`is_valid_time_slow()'
# =~ Time::valid_MYSQL_TIME_to_valid_value
# =~ Time::make_from_item
# =~ Item::print_value
# MDEV-18809:
# =~ Assertion \`key_info->key_part->field->flags & (1<< 30)'|signal 11
# =~ setup_keyinfo_hash
# =~ Sql_cmd_alter_table::execute
# MDEV-18801:
# =~ InnoDB: Failing assertion: field->col->mtype == type
# =~ row_sel_convert_mysql_key_to_innobase
# =~ get_key_scans_params
# MDEV-18801:
# =~ AddressSanitizer: heap-buffer-overflow|AddressSanitizer: SEGV on unknown address
# =~ row_sel_convert_mysql_key_to_innobase
# =~ get_key_scans_params
# MDEV-18800:
# =~ Assertion \`!pk->has_virtual()'
# =~ instant_alter_column_possible
# =~ ha_innobase::check_if_supported_inplace_alter
# MDEV-18800:
# =~ InnoDB: Failing assertion: pos != ULINT_UNDEFINED
# =~ row_build_row_ref_in_tuple
# =~ fts_add_doc_by_id
# =~ innobase_commit
# MDEV-18800:
# =~ Assertion \`n < rec_offs_n_fields(offsets)'
# =~ rec_get_nth_field_offs
# =~ row_search_mvcc
# =~ check_duplicate_long_entry_key
# MDEV-18798:
# =~ InnoDB: No matching column for \`DB_ROW_HASH_1\` in index
# =~ signal 11|AddressSanitizer: SEGV on unknown address
# =~ ha_innobase::commit_inplace_alter_table
# MDEV-18795:
# =~ Failing assertion: field->prefix_len > 0
# =~ row_sel_convert_mysql_key_to_innobase
# =~ get_key_scans_params|check_duplicate_long_entry_key
# MDEV-18793:
# =~ Using a partial-field key prefix in search, index
# =~ Assertion \`0'
# =~ row_sel_convert_mysql_key_to_innobase
# =~ get_key_scans_params
# MDEV-18793:
# =~ AddressSanitizer: unknown-crash
# =~ row_mysql_store_col_in_innobase_format
# =~ row_sel_convert_mysql_key_to_innobase
# =~ get_key_scans_params
# MDEV-18792:
# =~ AddressSanitizer: unknown-crash on address
# =~ _mi_pack_key
# =~ get_key_scans_params
# MDEV-18790:
# =~ signal 11|AddressSanitizer: SEGV on unknown address
# =~ fields_in_hash_keyinfo
# =~ check_duplicate_long_entries_update
# MDEV-18784:
# =~ Enabling keys got errno 127
# =~ AddressSanitizer: heap-use-after-free
# =~ Field_long::reset
# =~ convert_null_to_field_value_or_error
# =~ Item_null::save_in_field
# MDEV-18784:
# =~ Enabling keys got errno 127
# =~ signal 11
# =~ l_find
# =~ initialize_bucket
# MDEV-18784:
# =~ signal 11
# =~ l_find
# =~ l_search
# =~ lf_hash_search_using_hash_value
# =~ find_or_create_digest
# MDEV-18784:
# =~ AddressSanitizer: heap-use-after-free
# =~ Field::set_null
# =~ set_field_to_null_with_conversions
# =~ Item_null::save_in_field
# MDEV-18784:
# =~ AddressSanitizer: heap-use-after-free
# =~ field_conv_memcpy
# =~ Item_field::save_in_field
# MDEV-18679:
# =~ signal 11|AddressSanitizer: SEGV
# =~ JOIN::optimize
# =~ mysql_derived_optimize
# =~ st_select_lex::handle_derived
# MDEV-18640:
# =~ Conditional jump or move depends on uninitialised value
# =~ TABLE::prune_range_rowid_filters
# =~ TABLE::init_cost_info_for_usable_range_rowid_filters
# MDEV-18630:
# =~ Conditional jump or move depends on uninitialised value
# =~ ib_push_warning
# =~ dict_create_foreign_constraints_low
# MDEV-18800:
# =~ signal 11
# =~  ha_innobase::commit_inplace_alter_table
# =~ Sql_cmd_alter_table::execute
# MDEV-18467:
# =~ fix_semijoin_strategies_for_picked_join_order
# MDEV-371:
# =~ AddressSanitizer: use-after-poison
# =~ innobase_indexed_virtual_exist
# =~ ha_innobase::check_if_supported_inplace_alter
# =~ Sql_cmd_alter_table::execute
# MDEV-371:
# =~ Failing assertion: field->prefix_len > 0
# =~ row_sel_convert_mysql_key_to_innobase
# =~ check_duplicate_long_entry_key
# MDEV-371:
# =~ Assertion \`m_part_spec\.start_part >= m_part_spec\.end_part'
# =~ ha_partition::index_read_idx_map
# =~ mysql_load
# MDEV-371:
# =~ AddressSanitizer: SEGV on unknown address
# =~ Field_varstring::get_length
# =~ Create_field::Create_field
# MDEV-371:
# =~ Invalid read of size
# =~ Field::set_notnull
# =~ Field::load_data_set_value
# MDEV-371:
# =~ Index .* of .* has .* columns unique inside InnoDB, but MySQL is asking statistics for
# MDEV-18972:
# =~ InnoDB: Failing assertion: !cursor->index->is_committed()
# =~ row_ins_sec_index_entry_by_modify
# =~ row_update_vers_insert
# =~ row_upd_check_references_constraints
# MDEV-18904:
# =~ Assertion \`m_part_spec.start_part >= m_part_spec.end_part'
# =~ ha_partition::index_read_idx_map
# =~ handler::ha_index_read_idx_map
# MDEV-18901:
# =~ InnoDB: Record in index .* of table .* was not found on update: TUPLE
# =~ Assertion \`0'
# =~ row_upd_sec_index_entry
# =~ mysql_load
# =~ Version: '10\.4
# MDEV-18901:
# =~ InnoDB: Failing assertion: !cursor->index->is_committed()
# =~ row_ins_sec_index_entry_by_modify
# =~ mysql_load
# =~ Version: '10\.4
# MDEV-18887:
# =~ Conditional jump or move depends on uninitialised value
# =~ ha_key_cmp
# =~ sort_key_cmp
# =~ ha_myisam::repair
# MDEV-18881:
# =~ Assertion \`0'
# =~ make_sortkey
# =~ find_all_keys
# =~ create_sort_index
# MDEV-18879:
# =~ InnoDB: Apparent corruption in space .* page .* index .*
# =~ Assertion \`page_validate(buf_block_get_frame(left_block), cursor->index)'
# =~ btr_page_split_and_insert
# =~ row_update_cascade_for_mysql
# MDEV-18667:
# =~ AddressSanitizer: heap-use-after-free
# =~ make_date_time
# =~ Arg_comparator::compare_string
# =~ Item_func_nullif::compare
# MDEV-18626:
# =~ AddressSanitizer: stack-buffer-overflow
# =~ int10_to_str
# =~ make_date_time
# MDEV-18502:
# =~ find_field_in_tables
# =~ setup_without_group
# =~ mysql_select
# =~ sp_head::execute_procedure
# MDEV-18485:
# =~ signal 11|AddressSanitizer: heap-use-after-free|AddressSanitizer: SEGV on unknown address
# =~ my_timestamp_from_binary
# =~ Column_definition::Column_definition
# =~ mysql_alter_table
# MDEV-18485:
# =~ signal 11|AddressSanitizer: heap-use-after-free|AddressSanitizer: heap-buffer-overflow|AddressSanitizer: SEGV on unknown address
# =~ create_tmp_table
# =~ select_unit::create_result_table|select_union::create_result_table
# =~ TABLE_LIST::handle_derived
# MDEV-18485:
# =~ AddressSanitizer: heap-use-after-free
# =~ Field::is_null
# =~ Item_direct_view_ref::send
# MDEV-18485:
# =~ Field::is_null_in_record
# =~ Column_definition::Column_definition
# =~ mysql_alter_table
# MDEV-18090:
# =~ Assertion \`dict_table_get_n_cols(old_table) + dict_table_get_n_v_cols(old_table) >= table->s->fields + 3'
# =~ innobase_build_col_map
# =~ prepare_inplace_alter_table_dict
# MDEV-18086:
# =~ Assertion \`len <= col->len || ((col->mtype) == 5 || (col->mtype) == 14) || (col->len == 0 && col->mtype == 1)'
# =~ rec_get_converted_size_comp_prefix_low
# =~ btr_cur_optimistic_update
# MDEV-18084:
# =~ Assertion \`pos < table->n_v_def'
# =~ dict_table_get_nth_v_col
# =~ dict_index_contains_col_or_prefix
# =~ ha_innobase::change_active_index
# MDEV-18084:
# =~ signal 11
# =~ prepare_inplace_drop_virtual
# =~ ha_innobase::prepare_inplace_alter_table
# MDEV-17969:
# =~ Assertion \`name' failed
# =~ THD::push_warning_truncated_value_for_field
# =~ Field::set_datetime_warning
# MDEV-17643:
# =~ Assertion \`nr >= 0.0'
# =~ Item_sum_std::val_real
# =~ Protocol::send_result_set_row
# MDEV-14926:
# =~ AddressSanitizer: heap-use-after-free
# =~ make_date_time
# =~ Protocol::send_result_set_row
# MDEV-14926:
# =~ AddressSanitizer: heap-use-after-free
# =~ make_date_time
# =~ Item_func_octet_length::val_int
# =~ AGGR_OP::put_record|end_send_group
# MDEV-14926:
# =~ AddressSanitizer: heap-use-after-free
# =~ Item_func_date_format::val_str
# =~ copy_fields
# =~ end_send_group
# MDEV-18087:
# =~ mach_read_from_n_little_endian
# MDEV-18085:
# =~ len >= col->mbminlen
# MDEV-16958:
# =~ field_length < 5
# MDEV-14126:
# =~ page_get_page_no
# MDEV-19085:
# =~ Assertion \`row->fields[new_trx_id_col]\.type\.mtype == 8'
# =~ row_merge_read_clustered_index
# =~ ha_innobase::inplace_alter_table
# MDEV-19085:
# =~ Assertion \`!(col->prtype & 256U)'
# =~ row_merge_buf_add
# =~ ha_innobase::inplace_alter_table
# MDEV-19085:
# =~ Assertion \`n < tuple->n_fields'
# =~ dtuple_get_nth_field
# =~ row_merge_read_clustered_index
# =~ ha_innobase::inplace_alter_table
# MDEV-18891:
# =~  AddressSanitizer: heap-use-after-free
# =~ innobase_get_computed_value
# =~ row_upd_del_mark_clust_rec
# =~ Version: '10\.4
# MDEV-19186:
# =~ Assertion \`field->table == table'
# =~ create_tmp_table
# =~ JOIN::create_postjoin_aggr_table
# =~ JOIN::make_aggr_tables_info
# MDEV-19185:
# =~ Assertion \`select_lex->select_number == (0x7fffffff * 2U + 1U) || select_lex->select_number == 0x7fffffff || !output || !output->get_select(select_lex->select_number) || output->get_select(select_lex->select_number)->select_lex == select_lex'
# =~ JOIN::save_explain_data
# =~ JOIN::optimize
# MDEV-19185:
# =~ signal 11
# =~ incr_loops
# =~ subselect_single_select_engine::exec
# =~ and_new_conditions_to_optimized_cond
# MDEV-19048:
# =~ Assertion \`ctx.compare_type_handler()->cmp_type() != STRING_RESULT'
# =~ Field_num::get_equal_zerofill_const_item
# =~ st_select_lex::build_pushable_cond_for_having_pushdown
# MDEV-19030:
# =~ Assertion \`index->n_core_null_bytes <= (((index->n_nullable) + 7) / 8) \|\| (! leaf && index->n_core_fields != index->n_fields)'
# =~ Version: '10\.4
# =~ rec_init_offsets
# =~ row_purge_parse_undo_rec
# MDEV-18962:
# =~ AddressSanitizer: heap-buffer-overflow
# =~ Single_line_formatting_helper::on_add_str
# =~ Json_writer::add_str
# =~ TRP_ROR_INTERSECT::trace_basic_info
# MDEV-18942:
# =~ Conditional jump or move depends on uninitialised value
# =~ Json_writer::add_bool
# =~ print_keyuse_array_for_trace
# MDEV-18921:
# =~ signal 11
# =~ bitmap_bits_set|bitmap_is_set
# =~ pack_row|max_row_length
# =~ THD::binlog_update_row|THD::binlog_write_row
# MDEV-18853:
# =~ Assertion \`0'
# =~ Version: '10\.4
# =~ Protocol::end_statement
# =~ DELETE .* FOR PORTION
# MDEV-18852:
# =~ signal 11|AddressSanitizer: heap-use-after-free|AddressSanitizer: heap-buffer-overflow|AddressSanitizer: use-after-poison
# =~ Version: '10\.4
# =~ reinit_stmt_before_use
# =~ Prepared_statement::execute|sp_head::execute
# MDEV-18820:
# =~ Assertion \`lock_table_has(trx, index->table, LOCK_IX)'
# =~ lock_rec_insert_check_and_lock
# =~ btr_cur_optimistic_insert
# MDEV-18769:
# =~ Assertion \`fixed == 1'
# =~ Item_cond_or::val_int|Item_cond_and::val_int
# =~ has_value
# MDEV-18675:
# =~ signal 11|AddressSanitizer: SEGV on unknown address
# =~ COND_EQUAL::copy
# =~ and_new_conditions_to_optimized_cond
# MDEV-18675:
# =~ AddressSanitizer: SEGV on unknown address
# =~ and_new_conditions_to_optimized_cond
# MDEV-18656:
# =~ AddressSanitizer: unknown-crash
# =~ trx_undo_rec_get_pars
# =~ row_purge_parse_undo_rec
# =~ srv_task_execute
# MDEV-18595:
# =~ Assertion \`0' failed
# =~ Item_cache_timestamp::val_datetime_packed
# =~ Predicant_to_list_comparator::cmp_arg
# MDEV-18505:
# =~ InnoDB: Failing assertion: pos != ULINT_UNDEFINED
# =~ row_build_row_ref_in_tuple
# MDEV-18503:
# =~ Assertion \`native\.length() == binlen'
# =~ Type_handler_timestamp_common::make_sort_key
# MDEV-18417:
# =~ AddressSanitizer: unknown-crash
# =~ mach_read_from_4
# =~ mach_read_compressed|mach_read_next_compressed
# =~ trx_undo_rec_get_col_val
# =~ trx_undo_rec_get_partial_row
# MDEV-18402:
# =~ Assertion \`sec\.sec() <= 59'
# =~ Item_func_maketime::get_date
# =~ Time::make_from_item|Item::get_time
# MDEV-18302:
# =~ Assertion \`!((new_col->prtype ^ col->prtype) & ~256U)' failed
# =~ row_log_table_apply_convert_mrec
# =~ ha_innobase::inplace_alter_table
# MDEV-18240:
# =~ Assertion \`0' failed
# =~ Item_cache_timestamp::val_datetime_packed
# =~ Arg_comparator::compare_datetime
# MDEV-17942:
# =~ signal 11
# =~ mysql_show_grants
# =~ mysql_execute_command
# MDEV-15658:
# =~ expl_lock->trx == arg->impl_trx
# MDEV-19012:
# =~ signal 11|AddressSanitizer: SEGV on unknown address
# =~ Version: '10\.4
# =~ st_select_lex_unit::optimize
# =~ mysql_derived_optimize
# =~ TABLE_LIST::handle_derived
# MDEV-18899:
# =~ signal 11
# =~ Field::set_warning_truncated_wrong_value
# =~ Field_longstr::check_string_copy_error
# =~ Column_stat::get_stat_values
# MDEV-18690:
# =~ signal 11
# =~ Item_equal_iterator<List_iterator_fast, Item>::Item_equal_iterator
# =~ Item_field::find_item_equal
# =~ eliminate_item_equal
# =~ substitute_for_best_equal_field
# MDEV-18690:
# =~ AddressSanitizer: use-after-poison|signal 11
# =~ base_list::head
# =~ substitute_for_best_equal_field
# =~ JOIN::optimize_stage2
# MDEV-18309:
# =~ InnoDB: Operating system error number 2 in a file operation
# =~ InnoDB: Cannot open datafile for read-only:
# =~ OS error: 71
# MDEV-19224:
# =~ Assertion \`marked_for_read()'
# =~ Field_varstring::val_str|Field_varstring::val_real|Field_datetimef::get_TIME|Field_medium::val_int|Field_enum::val_int
# MDEV-8203:
# =~  rgi->tables_to_lock
# MDEV-19255:
# =~ signal 11
# =~ JOIN::save_explain_data_intern
# =~ st_join_table::save_explain_data
# =~ JOIN::build_explain
# MDEV-19255:
# =~ Assertion \`sel->quick'
# =~ JOIN::make_range_rowid_filters
# =~ JOIN::optimize_stage2
# MDEV-19164:
# =~ Assertion \`fixed'
# =~ Version: '10\.4
# =~ get_date_from_
# =~ Item_func_between::val_int
# MDEV-16654:
# =~ returned 38 for ALTER TABLE
# MDEV-16654:
# =~ ha_innodb::commit_inplace_alter_table
# MDEV-18321:
# =~ ha_innodb::commit_inplace_alter_table
# MDEV-18321:
# =~ ha_innobase::commit_inplace_alter_table
# MDEV-18139:
# =~ Table rename would cause two FOREIGN KEY constraints
# MDEV-19351:
# =~ Conditional jump or move depends on uninitialised value
# =~ statistics_for_command_is_needed
# =~ alloc_statistics_for_table_share
# =~ open_and_process_table
# MDEV-19351:
# =~ AddressSanitizer: heap-use-after-free|signal 11
# =~ is_temporary_table
# =~ read_statistics_for_tables_if_needed
# =~ fill_schema_table_by_open
# MDEV-19485:
# =~ [FATAL] InnoDB: Data field type 0, len 32
# =~ dfield_check_typed
# =~ row_search_index_entry
# =~ row_purge_del_mark
# MDEV-19485:
# =~ AddressSanitizer: global-buffer-overflow
# =~ rtree_get_geometry_mbr
# =~ row_build_spatial_index_key
# =~ row_purge_del_mark
# MDEV-19438:
# =~ Conditional jump or move depends on uninitialised value
# =~ Session_tracker::store
# =~ net_send_ok
# =~ Protocol::end_statement
# MDEV-19408:
# =~ Assertion \`trx->state == TRX_STATE_ACTIVE \|\| trx->state == TRX_STATE_PREPARED'
# =~ ReadView::copy_trx_ids
# =~ ReadView::prepare
# =~ MVCC::clone_oldest_view
# MDEV-19359:
# =~ AddressSanitizer: heap-use-after-free
# =~ copy_if_not_alloced
# =~ make_sortkey|SQL_SELECT::skip_record
# =~ find_all_keys
# =~ create_sort_index
# MDEV-19352:
# =~ signal 11|AddressSanitizer: SEGV on unknown address
# =~ alloc_histograms_for_table_share
# =~ read_histograms_for_table
# =~ read_statistics_for_tables_if_needed
# =~ get_all_tables
# MDEV-19352:
# =~ AddressSanitizer: heap-use-after-free|signal 11
# =~ is_temporary_table
# =~ read_statistics_for_tables_if_needed
# =~ fill_schema_table_by_open
# MDEV-19350:
# =~ signal 11
# =~ delete_tree_element
# =~ free_tree
# =~ Item_func_group_concat::repack_tree
# MDEV-18933:
# =~ InnoDB: Failing assertion: share->idx_trans_tbl.index_count == mysql_num_index
# =~ innobase_build_index_translation
# =~ open_table_uncached
# MDEV-18923:
# =~ Assertion \`!lex_string_cmp(system_charset_info, fk_info->referenced_table, &table->s->table_name)'
# =~ fk_truncate_illegal_if_parent
# =~ Sql_cmd_truncate_table::truncate_table
# MDEV-18923:
# =~ Assertion \`!((system_charset_info)->coll->strcasecmp((system_charset_info), (fk_info->referenced_table->str), (table->s->table_name\.str)))'
# =~ fk_truncate_illegal_if_parent
# =~ Sql_cmd_truncate_table::handler_truncate
# MDEV-18738:
# =~ AddressSanitizer: heap-use-after-free
# =~ copy_if_not_alloced
# =~ Item_copy_string::copy
# =~ end_send_group
# MDEV-18524:
# =~ Assertion \`!"invalid table name"' failed
# =~ innodb_find_table_for_vc
# =~ row_ins_check_foreign_constraint
# MDEV-18452:
# =~ AddressSanitizer: use-after-poison|AddressSanitizer: unknown-crash|signal 11|Invalid read of size
# =~ Field::set_default
# =~ Field_bit::set_default
# =~ fill_record_n_invoke_before_triggers
# MDEV-18452:
# =~ Version: '10.*-MariaDB-log'
# =~ AddressSanitizer: unknown-crash
# =~ Field::set_default
# =~ Item_default_value::save_in_field
# MDEV-18300:
# =~ AddressSanitizer: use-after-poison|AddressSanitizer: unknown-crash
# =~ Field_blob::get_key_image
# =~ Field::stored_field_make_mm_leaf
# =~ calculate_cond_selectivity_for_table
# MDEV-18220:
# =~ AddressSanitizer: heap-use-after-free
# =~ fts_get_table_name_prefix
# MDEV-17540:
# =~ Assertion \`table'|signal 11|AddressSanitizer: heap-use-after-free|AddressSanitizer: SEGV
# =~ dict_table_get_first_index|mem_heap_free
# =~ row_purge_upd_exist_or_extern_func
# =~ row_purge_step
# MDEV-16240:
# =~ Last data field length .* bytes, key ptr now exceeds key end by .* bytes
# =~ Assertion \`0' failed
# =~ row_sel_convert_mysql_key_to_innobase
# =~ multi_update::send_data
# MDEV-16060:
# =~ InnoDB: Failing assertion: ut_strcmp(index->name, key->name) == 0
# =~ ha_innobase::innobase_get_index
# =~ ha_innobase::info_low
# =~ open_table_from_share
# MDEV-16060:
# =~ Failing assertion: table->get_ref_count() == 0
# =~ row_merge_drop_table|dict_table_t::get_ref_count
# =~ Sql_cmd_alter_table::execute
# MDEV-16060:
# =~ Assertion \`user_table->get_ref_count() == 1' failed
# =~ commit_try_rebuild
# =~ Sql_cmd_alter_table::execute|Sql_cmd_optimize_table::execute
# MDEV-16060:
# =~ commit_try_rebuild
# MDEV-16060:
# =~ table->get_ref_count
# MDEV-15907:
# =~ AddressSanitizer: heap-use-after-free
# =~ strnmov
# =~ fill_effective_table_privileges
# MDEV-15881:
# =~ Assertion \`is_valid_value_slow()' failed
# =~ Datetime::Datetime
# =~ Arg_comparator::compare
# MDEV-14041:
# =~ signal 11
# =~ String::length
# =~ sortcmp
# =~ test_if_group_changed
# MDEV-18388:
# =~ thd->spcont
# MDEV-18020:
# =~ prebuilt->trx->check_foreigns
# MDEV-18020:
# =~ ctx->prebuilt->trx->check_foreigns
# MDEV-18020:
# =~ m_prebuilt->trx->check_foreigns
# MDEV-17830:
# =~ Item_null_result::field_type
# MDEV-19524:
# =~ AddressSanitizer: SEGV on unknown address|signal 11
# =~ Field_longstr::csinfo_change_allows_instant_alter
# =~ compare_keys_but_name
# =~ fill_alter_inplace_info
# MDEV-19486:
# =~ signal 11|AddressSanitizer: SEGV on unknown address
# =~ row_upd_step
# =~ ha_innobase::delete_row
# =~ AGGR_OP::end_send
# =~ sub_select_postjoin_aggr
# MDEV-19027:
# =~ Assertion \`table->n_def == (table->n_cols - 3)'|Assertion \`table->n_def == table->n_cols - 3'
# =~ dict_table_add_system_columns
# =~ create_table_info_t::create_table_def
# =~ ha_innobase::truncate
# MDEV-19027:
# =~ signal 11
# =~ dict_index_add_col
# =~ dict_index_build_internal_clust
# =~ dict_index_add_to_cache_w_vcol
# =~ que_thr_step
# MDEV-11015:
# =~ precision > 0
