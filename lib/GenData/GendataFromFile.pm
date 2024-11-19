# Copyright (C) 2009, 2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2020, 2023, MariaDB
# Use is subject to license terms.
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

package GenData::GendataFromFile;
@ISA = qw(GenData);

use strict;
use Carp;
use Data::Dumper;

use GenData;
use GenData::PopulateSchema;
use GenTest;
use Constants;
use GenTest::Executor;
use GenTest::Random;
use GenUtil;

my $remote_created;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    return $self;
}

sub asc_desc_key {
    my $asc_desc= shift;
    return ($asc_desc == 1 ? ' ASC' : ($asc_desc == 2 ? ' DESC' : ''));
}

sub run {
    my $self= shift;

    my $executor = $self->executor();
    my $spec_file = $self->spec_file();
    my $prng = $self->rand();

    my ($tables, $fields, $data, $schemas);  # Specification as read
                                             # from the spec file.
    my $compatibility= '000000'; # by default compatible with anything
    my (@table_perms, @field_perms, @data_perms, @schema_perms);  # Specification
                                                                    # after
                                                                    # defaults
                                                                    # have
                                                                    # been
                                                                    # substituted
   my $short_column_names= $self->short_column_names; # Can also be set in the spec file by names => 'short' or names => 'full'


    if ($spec_file ne '') {
        open(CONF , $spec_file) or croak "unable to open gendata file '$spec_file': $!";
        read(CONF, my $spec_text, -s $spec_file);
        close(CONF);
        #
        # Usually the specification file is actually a perl script (all those .zz),
        #  so we read it by eval()-ing it
        #
        my $eval_res= ($self->debug()
                       ? eval ( $spec_text )
                       : eval { local $SIG{__WARN__} = sub {}; eval ( $spec_text ) }
                      );
        unless ($eval_res)
        {
          my $perl_errors= $@;
          say("Could not evaluate $spec_file as Perl, trying to feed it to the server as SQL");
          # ... but if it turns out to be something else, we'll try to interpret it
          # as an SQL file (e.g. a dump) and feed it directly to the server.
          # Run with --force in case of partial errors (e.g. some values don't work with the current server charset).
          # If it turns out that nothing is loaded at all, it will be a pointless test,
          # but such things should be caught at test implementation stage

          my $dbs= $executor->connection->get_column("SELECT schema_name from INFORMATION_SCHEMA.SCHEMATA ORDER BY schema_name");
          my %dbs_before= ();
          foreach (@$dbs) { $dbs_before{$_}= 1; };
          
          my @populate_rows= (defined $self->rows() ? split(',', $self->rows()) : (0));
          my $populate = GenData::PopulateSchema->new(spec_file => $spec_file,
                                               debug => $self->debug,
                                               seed => $self->seed,
                                               server => $self->server,
                                               rows => \@populate_rows,
                                               basedir => $executor->server->serverVariable('basedir'),
          );
          if ($populate->run() == STATUS_OK)
          {
            say("Loaded SQL file $spec_file and populated the tables");
            $dbs= $executor->connection->get_column("SELECT schema_name from INFORMATION_SCHEMA.SCHEMATA ORDER BY schema_name");
            if ($dbs && scalar(@$dbs)) {
              foreach (@$dbs) {
                unless ($dbs_before{$_}) {
                  say("New schema $_ was created");
                  # PS is a workaround for MENT-30190
                  $executor->execute("EXECUTE IMMEDIATE CONCAT('GRANT ALL ON ".$_.".* TO ',CURRENT_USER,' WITH GRANT OPTION')");
                  if ($executor->connection->err) {
                    sayError("Failed to grant permissions on database $_: ".$executor->connection->print_error);
                  }
                }
              }
            }
            return STATUS_OK;
          } else {
            croak "Unable to load $spec_file: $perl_errors";
          }
        }
    }

    unless (isCompatible($compatibility,$self->compatibility,$self->compatibility_es)) {
      sayWarning("$spec_file requires server $compatibility, not compatible with ".$self->compatibility.($self->compatibility_es ? " ES" : ""));
      return STATUS_OK;
    }

    $executor->execute("SET SQL_MODE= CONCAT(\@\@sql_mode,',NO_ENGINE_SUBSTITUTION'), ENFORCE_STORAGE_ENGINE= NULL");

    if (defined $schemas) {
        push(@schema_perms, @$schemas);
        $self->executor->defaultSchema($schema_perms[0]);
    } else {
        push(@schema_perms, $executor->defaultSchema());
    }

    my $engines;
    if (exists $tables->{engines}) {
      sayWarning("Engine(s) from test parameters (if there are any) will be ignored, the value from .zz file will be used instead: @{$tables->{engines}}");
      $engines= $tables->{engines};
    } elsif ((defined $self->engines()) && scalar(@{$self->engines()})) {
      $engines= [ @{$self->engines()} ];
    } else {
      $engines= [ '' ];
    }
    foreach my $e (@$engines) {
      if (isFederatedEngine($e)) {
        foreach my $s (@schema_perms) {
          unless ($self->setupRemote($s) == STATUS_OK) {
            sayError("Could not set up remote access for engine $e / schema $s");
            return STATUS_ENVIRONMENT_FAILURE;
          }
        }
        last;
      }
    }
    # Using default engine only
    unless (scalar (@$engines)) {
      $engines= [ '' ];
    }

    $table_perms[TABLE_ROW] = (defined $self->rows() ? [split(',', $self->rows())] : undef ) || $tables->{rows} || [0, 1, 2, 10, 100];
    $table_perms[TABLE_ENGINE] = $engines;
    $table_perms[TABLE_CHARSET] = $tables->{charsets} || [ undef ];
    $table_perms[TABLE_COLLATION] = $tables->{collations} || [ undef ];
    $table_perms[TABLE_PARTITION] = $tables->{partitions} || [ undef ];
    $table_perms[TABLE_PK] = $tables->{pk} || $tables->{primary_key} || [ 'integer auto_increment' ];
    $table_perms[TABLE_ROW_FORMAT] = $tables->{row_formats} || [ undef ];
    $table_perms[TABLE_EXTRA_OPTS] = $tables->{options} || [ undef ];

    $table_perms[TABLE_VIEWS] = $tables->{views} || (defined $self->views() ? [ $self->views() ] : undef );
    $table_perms[TABLE_MERGES] = $tables->{merges} || undef ;

    $table_perms[TABLE_NAMES] = $tables->{names} || [ ];


    $field_perms[FIELD_NAMES] = [];
    if ($fields->{names} and ref $fields->{names} eq 'ARRAY') {
      $field_perms[FIELD_NAMES] = $fields->{names};
    } elsif ($fields->{names} and ref $fields->{names} eq '') {
      if ($fields->{names} eq 'short') {
        $short_column_names= 1;
      } elsif ($fields->{names} eq 'full') {
        $short_column_names= 0;
      }
    }
    $field_perms[FIELD_SQLS] = $fields->{sqls} || [ ];
    $field_perms[FIELD_INDEX_SQLS] = $fields->{index_sqls} || [ ];
    $field_perms[FIELD_TYPE] = $fields->{types} || [ 'int', 'varchar', 'date', 'time', 'datetime' ];
    $field_perms[FIELD_NULLABILITY] = $fields->{null} || $fields->{nullability} || [ undef ];
    $field_perms[FIELD_DEFAULT] = $fields->{default} || [ undef ];
    $field_perms[FIELD_SIGN] = $fields->{sign} || [ undef ];
    $field_perms[FIELD_INDEX] = $fields->{indexes} || $fields->{keys} || [ undef ];
    $field_perms[FIELD_CHARSET] =  $fields->{charsets} || [ undef ];
    $field_perms[FIELD_COLLATION] = $fields->{collations} || [ undef ];

    $data_perms[DATA_NUMBER] = $data->{numbers} || ['digit', 'digit', 'digit', 'digit', 'digit', 'null' ]; # 20% NULL values
    $data_perms[DATA_STRING] = $data->{strings} || ['letter', 'letter', 'letter', 'letter', 'null' ];
    $data_perms[DATA_BLOB] = $data->{blobs} || [ 'data', 'data', 'data', 'data', 'null' ];
    $data_perms[DATA_TEMPORAL] = $data->{temporals} || [ 'date', 'time', 'datetime', 'year', 'timestamp', 'null' ];
    $data_perms[DATA_ENUM] = $data->{enum} || ['letter', 'letter', 'letter', 'letter', 'null' ];
    $data_perms[DATA_SPATIAL] = $data->{spatial} || ['point(0,0)', 'point(1.1,1.1)', 'null' ];

    my @tables = (undef);
    my @myisam_tables;

    foreach my $cycle (TABLE_ENGINE, TABLE_ROW, TABLE_CHARSET, TABLE_COLLATION, TABLE_PARTITION, TABLE_PK, TABLE_ROW_FORMAT, TABLE_EXTRA_OPTS) {
        @tables = map {
            my $old_table = $_;
            if (not defined $table_perms[$cycle]) {
                $old_table;  # Retain old table, no permutations at this stage.
            } else {
                # Create several new tables, one for each allowed value in the current $cycle
                map {
                    my $new_perm = $_;
                    my @new_table = defined $old_table ? @$old_table : [];
                    $new_table[$cycle] = (defined $new_perm ? lc($new_perm) : '');
                    \@new_table;
                } @{$table_perms[$cycle]};
            }
        } @tables;
    }

#
# Iteratively build the array of tables. We start with an empty array, and on each iteration
# we increase the size of the array to contain more combinations.
#
# Then we do the same for fields.
#

    my @fields = (undef);

    foreach my $cycle (FIELD_TYPE, FIELD_NULLABILITY, FIELD_DEFAULT, FIELD_SIGN, FIELD_INDEX, FIELD_CHARSET, FIELD_COLLATION) {
        @fields = map {
            my $old_field = $_;
            if (not defined $field_perms[$cycle]) {
                $old_field;  # Retain old field, no permutations at this stage.
            } elsif (
                ($cycle == FIELD_SIGN) &&
                ($old_field->[FIELD_TYPE] !~ m{int|float|double|dec|numeric|fixed}is)
                ) {
                $old_field;  # Retain old field, sign does not apply to non-integer types
            } elsif (
                ($cycle == FIELD_CHARSET) &&
                ($old_field->[FIELD_TYPE] =~ m{bit|int|bool|float|double|dec|numeric|fixed|blob|date|time|year|binary}is)
                ) {
                $old_field;  # Retain old field, charset does not apply to integer types
            } else {
                # Create several new fields, one for each allowed value in the current $cycle
                map {
                    my $new_perm = $_;
                    my @new_field = defined $old_field ? @$old_field : [];
                    $new_field[$cycle] = (defined $new_perm ? lc($new_perm) : undef);
                    \@new_field;
                } @{$field_perms[$cycle]};
            }
        } @fields;
    }

# If no fields were defined, continue with just the primary key.
    @fields = () if ($#fields == 0) && ($fields[0]->[FIELD_TYPE] eq '');
    my $field_no=0;
    foreach my $field_id (0..$#fields) {
        my $field = $fields[$field_id];
        next if not defined $field;
        my @field_copy = @$field;

        #   $field_copy[FIELD_INDEX] = 'nokey' if $field_copy[FIELD_INDEX] eq '';

        my $field_name;
        if ($#{$field_perms[FIELD_NAMES]} > -1) {
            $field_name = shift @{$field_perms[FIELD_NAMES]};
        } elsif ($short_column_names) {
            $field_name = 'c'.($field_no++);
        } else {
            $field_name = "col_".join('_', grep { $_ ne '' } @field_copy);
            $field_name =~ s{[^A-Za-z0-9]}{_}sgio;
            $field_name =~ s{ }{_}sgio;
            $field_name =~ s{_+}{_}sgio;
            $field_name =~ s{_+$}{}sgio;

        }
        $field->[FIELD_NAME] = $field_name;

        if (
            ($field_copy[FIELD_TYPE] =~ m{set|enum}is) &&
            ($field_copy[FIELD_TYPE] !~ m{\(}is )
            ) {
            #$field_copy[FIELD_TYPE] .= " (".join(',', map { "'$_'" } ('a'..'z') ).")";
            $field_copy[FIELD_TYPE] .= $prng->enumSetTypeValues();
        }

        if (
            ($field_copy[FIELD_TYPE] =~ m{char}is) &&
            ($field_copy[FIELD_TYPE] !~ m{\(}is)
            ) {
            $field_copy[FIELD_TYPE] .= ' (1)';
        }

        $field_copy[FIELD_CHARSET] = "CHARACTER SET ".$field_copy[FIELD_CHARSET] if $field_copy[FIELD_CHARSET] ne '';
        $field_copy[FIELD_COLLATION] = "COLLATE ".$field_copy[FIELD_COLLATION] if $field_copy[FIELD_COLLATION] ne '';

        my $key_len;

        if (
            ($field_copy[FIELD_TYPE] =~ m{blob|text|binary}is ) &&
            ($field_copy[FIELD_TYPE] !~ m{\(}is )
            ) {
            $key_len = " (255)";
        }

        if (
            ($field_copy[FIELD_INDEX] ne 'nokey') &&
            ($field_copy[FIELD_INDEX] ne '')
            ) {
            $field->[FIELD_INDEX_SQL] = $field_copy[FIELD_INDEX]." (`$field_name`$key_len".asc_desc_key($prng->uint16(0,2)).")";
        }

        delete $field_copy[FIELD_INDEX]; # do not include FIELD_INDEX in the field description

        $fields[$field_id]->[FIELD_SQL] = "`$field_name` ". join(' ' , grep { $_ ne '' } @field_copy);
    }

    foreach my $sql (@{$field_perms[FIELD_SQLS]}) {
        my $f = [];
        $f->[FIELD_SQL] = $sql;
        if ($sql =~ /^\s*`?\w+\`?\s+(\w+)/) { $f->[FIELD_TYPE] = lc($1) };
        if ($sql =~ /auto_increment/i) { $f->[FIELD_TYPE] .= ' auto_increment' };
        @fields = ( $f, @fields );
    }

    my %tnames = ();
    foreach my $table_id (0..$#tables) {
        my $table = $tables[$table_id];
        my @table_copy = @$table;

        if ($#{$table_perms[TABLE_NAMES]} > -1) {
            $table->[TABLE_NAME] = shift @{$table_perms[TABLE_NAMES]};
        } else {
            my $table_name;
            $table_name = "table".join('_', grep { $_ ne '' } @table_copy);
            $table_name =~ s{[^A-Za-z0-9]}{_}sgio;
            $table_name =~ s{ }{_}sgio;
            $table_name =~ s{_+}{_}sgio;
            # Remove trailing underscore when fractional seconds are used.
            $table_name =~ s{_$}{}s;
            $table_name =~ s{auto_increment}{autoinc}isg;
            $table_name =~ s{partition_by}{part_by}isg;
            $table_name =~ s{partition}{part}isg;
            $table_name =~ s{partitions}{parts}isg;
            $table_name =~ s{values_less_than}{}isg;
            $table_name =~ s{integer}{int}isg;

            # We don't want duplicate table names in case all parameters that affect the name are the same
            if ($tnames{$table_name}) {
                $table_name .= '_'.(++$tnames{$table_name});
            } else {
                $tnames{$table_name} = 1;
            }

            if (
                (uc($table_copy[TABLE_ENGINE]) eq 'MYISAM') ||
                ($table_copy[TABLE_ENGINE] eq '')
                ) {
                push @myisam_tables, $table_name;
            }

            $table->[TABLE_NAME] = $table_name;
        }

        $table_copy[TABLE_ENGINE] = "ENGINE=".$table_copy[TABLE_ENGINE] if $table_copy[TABLE_ENGINE] ne '';
        $table_copy[TABLE_ROW_FORMAT] = "ROW_FORMAT=".$table_copy[TABLE_ROW_FORMAT] if $table_copy[TABLE_ROW_FORMAT] ne '';
        $table_copy[TABLE_CHARSET] = "CHARACTER SET ".$table_copy[TABLE_CHARSET] if $table_copy[TABLE_CHARSET] ne '';
        $table_copy[TABLE_COLLATION] = "COLLATE ".$table_copy[TABLE_COLLATION] if $table_copy[TABLE_COLLATION] ne '';
        $table_copy[TABLE_PARTITION] = "/*!50100 PARTITION BY ".$table_copy[TABLE_PARTITION]." */" if $table_copy[TABLE_PARTITION] ne '';

        delete $table_copy[TABLE_ROW];  # Do not include number of rows in the CREATE TABLE
        delete $table_copy[TABLE_PK];  # Do not include PK definition at the end of CREATE TABLE

        $table->[TABLE_SQL] = join(' ' , grep { $_ ne '' } @table_copy);
    }

    foreach my $schema (@schema_perms) {
        $executor->execute("CREATE DATABASE IF NOT EXISTS $schema");
        # PS is a workaround for MENT-30190
        $executor->execute("EXECUTE IMMEDIATE CONCAT('GRANT ALL ON ".$schema.".* TO ',CURRENT_USER,' WITH GRANT OPTION')");

    foreach my $table_id (0..$#tables) {
        my $table = $tables[$table_id];
        my @table_copy = @$table;
        my @fields_copy = @fields;

        if (isFederatedEngine($table_copy[TABLE_ENGINE])) {
          say("Creating table: ${schema}_remote.$table_copy[TABLE_NAME]; engine: <default>; rows: $table_copy[TABLE_ROW]");
          $executor->execute("USE ${schema}_remote");
          $table->[TABLE_SQL] =~ s/ENGINE=\w+//;
        } else {
          say("Creating table: $schema.$table_copy[TABLE_NAME]; engine: $table_copy[TABLE_ENGINE]; rows: $table_copy[TABLE_ROW]");
          $executor->execute("USE $schema");
        }

        if ($table_copy[TABLE_PK] ne '') {
            my $pk_field;
            $pk_field->[FIELD_NAME] = 'pk';
            $pk_field->[FIELD_TYPE] = $table_copy[TABLE_PK];
            $pk_field->[FIELD_INDEX] = 'primary key';
            $pk_field->[FIELD_INDEX_SQL] = 'primary key (pk'.asc_desc_key($prng->uint16(0,2)).')';
            $pk_field->[FIELD_SQL] = 'pk '.$table_copy[TABLE_PK];
            push @fields_copy, $pk_field;
        }

        # Make field ordering in every table different.
        # This exposes bugs caused by different physical field placement

        $prng->shuffleArray(\@fields_copy);

        $executor->execute("DROP TABLE /*! IF EXISTS*/ $table->[TABLE_NAME]");

        # Compose the CREATE TABLE statement by joining all fields and indexes and appending the table options
        # Skip undefined fields.
        my @field_sqls = join(",\n", map { $_->[FIELD_SQL] } grep { $_->[FIELD_SQL] ne '' } @fields_copy);

        my @index_fields;
        @index_fields = grep { $_->[FIELD_INDEX_SQL] =~ s/DESC// if $table_copy[TABLE_ENGINE] =~ /rocksdb/i; $_->[FIELD_INDEX_SQL] ne '' } @fields_copy;

        foreach my $sql (@{$field_perms[FIELD_INDEX_SQLS]}) {
            my $f = [];
            $f->[FIELD_INDEX_SQL] = $sql;
            @index_fields = ( $f, @index_fields );
        }

        my $index_sqls = $#index_fields > -1 ? join(",\n", map { $_->[FIELD_INDEX_SQL] } @index_fields) : undef;

        my $res= $executor->execute(
          "CREATE TABLE `$table->[TABLE_NAME]` (\n".join(",\n/*Indices*/\n", grep { defined $_ } (@field_sqls, $index_sqls) ).") ".$table->[TABLE_SQL]);
        if (ref $res ne 'GenTest::Result' or $res->status() != STATUS_OK) {
          sayError("Table creation failed");
          next;
        }

# MDEV-26253 Can't find record
#        $executor->execute("ALTER TABLE `$table->[TABLE_NAME]` DISABLE KEYS");

        if ($table->[TABLE_ROW] > 100) {
            $executor->execute("SET AUTOCOMMIT=OFF");
            $executor->execute("START TRANSACTION");
        }

        my @row_buffer;
        foreach my $row_id (1..$table->[TABLE_ROW]) {
            my @data;
            foreach my $field (@fields_copy) {
                # Skip if no field type exists.
                next if not defined $field->[FIELD_TYPE];
                my $value;
                my $quote = 0;
                if ($field->[FIELD_TYPE] =~ m{auto_increment}is) {
                    $value = undef;    # Trigger auto-increment by inserting NULLS for PK
                } elsif ($field->[FIELD_INDEX] eq 'primary key') {
                    if ($field->[FIELD_TYPE] =~ m{^(datetime|timestamp)$}sgio) {
            $value = "FROM_UNIXTIME(UNIX_TIMESTAMP('2000-01-01') + $row_id)";
                  } elsif ($field->[FIELD_TYPE] =~ m{date}sgio) {
                    $value = "FROM_DAYS(TO_DAYS('2000-01-01') + $row_id)";
                  } elsif ($field->[FIELD_TYPE] =~ m{^time$}sgio) {
                    $value = "SEC_TO_TIME($row_id)";
                  # Support wider range for frastionl seconds precision with temporal datatypes.
                  } elsif ($field->[FIELD_TYPE] =~ m{^(timestamp|datetime|time)\((\d+)\)$}sgio) {
                    $value = "CURRENT_TIMESTAMP($2) + $row_id";
                  } elsif ($field->[FIELD_TYPE] =~ m{^(time)\((\d+)\)$}sgio) {
                    $value = "CURRENT_TIME($2) + $row_id";
                  } else {
                        $value = $row_id;  # Otherwise, insert sequential numbers
                  }
                } else {
                    my (@possible_values, $value_type);

                    if ($field->[FIELD_TYPE] =~ m{date|time|year}is) {
                        $value_type = DATA_TEMPORAL;
                        $quote = 1;
                    } elsif ($field->[FIELD_TYPE] =~ m{blob|text|binary}is) {
                        $value_type = DATA_BLOB;
                        $quote = 1;
                    } elsif ($field->[FIELD_TYPE] =~ m{int|float|double|dec|numeric|fixed|bool|bit}is) {
                        $value_type = DATA_NUMBER;
                    } elsif ($field->[FIELD_TYPE] eq 'enum') {
                        $value_type = DATA_ENUM;
                        $quote = 1;
                    } elsif ($field->[FIELD_TYPE] =~ m{geometry|point|linestring|polygon}is) {
                        $value_type = DATA_SPATIAL;
                    } else {
                        $value_type = DATA_STRING;
                        $quote = 1;
                    }

                    if ($field->[FIELD_NULLABILITY] eq 'not null') {
                        # Remove NULL from the list of allowed values
                        @possible_values = grep { lc($_) ne 'null' } @{$data_perms[$value_type]};
                    } else {
                        @possible_values = @{$data_perms[$value_type]};
                    }

                    croak("# Unable to generate data for field '$field->[FIELD_TYPE] $field->[FIELD_NULLABILITY]'") if $#possible_values == -1;

                    my $possible_value = $prng->arrayElement(\@possible_values);
                    $possible_value = $field->[FIELD_TYPE] if not defined $possible_value;

                    if ($prng->isFieldType($possible_value)) {
                        $value = $prng->fieldType($possible_value);
                    } else {
                        $value = $possible_value;    # A simple string literal as specified
                    }
                }

                ## Quote if necessary
                if ($value =~ m{load_file}is) {
                    push @data, defined $value ? $value : "NULL";
                } elsif ($quote) {
                    $value =~ s{'}{\\'}sgio;
                    push @data, defined $value ? "'$value'" : "NULL";
                } else {
                    push @data, defined $value ? $value : "NULL";
                }
            }

            push @row_buffer, " (".join(', ', @data).") ";

            if (
                (($row_id % 50) == 0) ||
                ($row_id == $table->[TABLE_ROW])
                ) {
                my $insert_result= $executor->execute("INSERT /*! IGNORE */ INTO $table->[TABLE_NAME] VALUES ".join(', ', @row_buffer));
                return $insert_result->status() if $insert_result->status() >= STATUS_CRITICAL_FAILURE;
                @row_buffer = ();
            }

            if (($row_id % 10000) == 0) {
                $executor->execute("COMMIT");
                say("# Progress: loaded $row_id out of $table->[TABLE_ROW] rows");
            }
        }
        $executor->execute("COMMIT");
# MDEV-26253 Can't find record
#        $executor->execute("ALTER TABLE `$table->[TABLE_NAME]` ENABLE KEYS");

        if (isFederatedEngine($table_copy[TABLE_ENGINE])) {
          $executor->execute("USE $schema");
          say("Creating table: $schema.$table_copy[TABLE_NAME]; engine: $table_copy[TABLE_ENGINE] (rows in remote: $table_copy[TABLE_ROW])");
          $self->createFederatedTable($table_copy[TABLE_ENGINE],$table->[TABLE_NAME],$schema);
        }
        if (defined $table_perms[TABLE_VIEWS]) {
          foreach my $view_id (0..$#{$table_perms[TABLE_VIEWS]}) {
            $self->createView($table_perms[TABLE_VIEWS]->[$view_id],$table->[TABLE_NAME],$schema);
          }
        }
    }
    }

    $executor->execute("COMMIT");

    if (
        (defined $table_perms[TABLE_MERGES]) &&
        ($#myisam_tables > -1)
        ) {
        foreach my $merge_id (0..$#{$table_perms[TABLE_MERGES]}) {
            my $merge_name = 'merge_'.$merge_id;
            $executor->execute("CREATE TABLE `$merge_name` LIKE `".$myisam_tables[0]."`");
            $executor->execute("ALTER TABLE `$merge_name` ENGINE=MERGE UNION(".join(',',@myisam_tables).") ".uc($table_perms[TABLE_MERGES]->[$merge_id]));
        }
    }

    $executor->execute("USE ".$schema_perms[0]);
    return STATUS_OK;
}

1;
