# Copyright (C) 2013 Monty Program Ab
# Copyright (c) 2022, MariaDB
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


package GenData::PopulateSchema;

@ISA = qw(GenData);

use strict;
use Carp;
use Data::Dumper;

use GenData;
use GenTest;
use Constants;
use GenTest::Random;
use GenTest::Executor;
use GenUtil;

use constant POPULATE_SCHEMA_DSN  => 1;
use constant POPULATE_SCHEMA_PORT => 2;
use constant POPULATE_SCHEMA_DB   => 3;

use DBServer::MariaDB;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    # These are values for populate-schema.pl
    $self->[POPULATE_SCHEMA_PORT]= undef;
    $self->[POPULATE_SCHEMA_DSN]= undef;
    $self->[POPULATE_SCHEMA_DB]= undef;
    return $self;
}

sub port {
  if (defined $_[1]) {
    $_[0]->[POPULATE_SCHEMA_PORT]= $_[1];
    $_[0]->[POPULATE_SCHEMA_DSN]= "dbi:mysql:host=127.0.0.1:port=$_[1]:user=root";
  } else {
    return $_[0]->[POPULATE_SCHEMA_PORT];
  }
}

sub db {
  if (defined $_[1]) {
    $_[0]->[POPULATE_SCHEMA_DB]= $_[1];
  } else {
    return $_[0]->[POPULATE_SCHEMA_DB];
  }
}

sub run {
    my ($self) = @_;

    my $schema_file = $self->spec_file();
    my $tables = $self->tables();

    my ($executor, $port);
    if ($self->server) {
      $executor = GenTest::Executor->newFromServer($self->server(), id => $self->executor_id);
      $port= $executor->server->port();
    } elsif ($self->[POPULATE_SCHEMA_DSN]) {
      $executor = GenTest::Executor->newFromDSN($self->[POPULATE_SCHEMA_DSN], id => $self->executor_id);
      $port= $self->port();
    } else {
      sayError("Don't know how to create executor");
      return STATUS_ENVIRONMENT_FAILURE;
    }

    $executor->init();

    # The specification file should be an SQL script, and we need to feed it to the server through the client

    my $mysql_client_path = 'mysql';
    my $basedir = $self->basedir();
    if ($basedir) {
        $mysql_client_path = DBServer::MariaDB->_find(
            [$basedir,$basedir.'/..',$basedir.'/../debug/',$basedir.'/../relwithdebinfo/'],
           ['client','bin'],
           'mysql.exe', 'mysql' );
    } else {
        say("WARNING: basedir was not defined, relying on MySQL client being on the default path");
    }
    unless ($mysql_client_path) {
        sayError("Could not find MySQL client");
        return STATUS_ENVIRONMENT_FAILURE;
    }

    # If the schema file was defined,
    # we only want to populate the tables that were created while loading the schema file,
    # so we'll store the list of existing tables with their creation times

    my @tables_to_populate = ();

    if ($schema_file) {
        $tables = $executor->execute("SELECT CONCAT(TABLE_SCHEMA, '.', TABLE_NAME), CREATE_TIME FROM INFORMATION_SCHEMA.TABLES "
                . "WHERE TABLE_SCHEMA NOT IN ('mysql','performance_schema','information_schema','sys')")->data();
        my %old_tables = ();
        foreach (@$tables) {
            $old_tables{$_->[0]} = $_->[1];
        }

        system("LD_LIBRARY_PATH=\$MSAN_LIBS:\$LD_LIBRARY_PATH $mysql_client_path --no-defaults --init-command='SET tx_read_only=OFF' --port=$port --protocol=tcp -uroot --force ".$self->db." < $schema_file");
        if ($?) {
            sayError("Failed to load $schema_file through MySQL client");
            return STATUS_ENVIRONMENT_FAILURE;
        }

        # Now we will get the list of tables again. If at least some new tables got populated, we'll assume that
        # the SQL file takes care of it. If all tables are empty, then we'll generate some data

        $tables = $executor->execute("SELECT CONCAT(TABLE_SCHEMA, '.', TABLE_NAME), CREATE_TIME FROM INFORMATION_SCHEMA.TABLES "
                . "WHERE TABLE_SCHEMA NOT IN ('mysql','performance_schema','information_schema','sys') AND TABLE_TYPE LIKE '%TABLE%'")->data();

        foreach (@$tables) {
          # Old table, don't touch
          next if (defined $old_tables{$_->[0]} and $old_tables{$_->[0]} eq $_->[1]);

          # Can't rely on TABLE_ROWS
          if ($executor->execute("SELECT 1 FROM $_->[0] LIMIT 1")->rows()) {
            say("Some tables were populated during SQL file execution, no need to generate data");
            @tables_to_populate= ();
            last;
          } else {
            push @tables_to_populate, $_->[0];
          }
        }
    }
    # If the table list was defined,
    # we want to populate the given tables
    else {
        @tables_to_populate = @$tables;
    }
    if (scalar (@tables_to_populate)) {
      my @row_counts= ( $self->rows() && scalar(@{$self->rows()}) ? @{$self->rows()} : (100) );
      say("Tables to populate: @tables_to_populate, row counts: @row_counts");
      my $i= 0;
      foreach my $t (@tables_to_populate) {
          populate_table($self, $executor, $t, $row_counts[$i++]);
          $i= 0 if $i > $#row_counts;
      }
    }

    return STATUS_OK;

}

sub populate_table
{
    my ($self, $executor, $table_name, $rows) = @_;
    $rows = 100 unless defined $rows;
    my $prng = GenTest::Random->new(
        seed => $self->seed()
    );


    # TODO: be smarter about foreign keys
    $executor->execute("SET FOREIGN_KEY_CHECKS = 0");
    $executor->execute("SET GLOBAL FOREIGN_KEY_CHECKS = 0");


    # We don't select virtual columns, because won't include them into the list at all
    # Position 4 is reserved for a flag indicating that the column is used
    # in a single-column unique constraint. If it is, it will be set later
    my $columns = $executor->execute("SELECT COLUMN_TYPE, COALESCE(COLUMN_DEFAULT,'NULL'), IS_NULLABLE, EXTRA, 0, COLUMN_NAME "
            . "FROM INFORMATION_SCHEMA.COLUMNS WHERE CONCAT(TABLE_SCHEMA,'.',TABLE_NAME) = '$table_name' "
            . "AND EXTRA NOT IN ('VIRTUAL GENERATED', 'STORED GENERATED') ORDER BY ORDINAL_POSITION")->data();

    my $row_count = 0;
    my $trx_size = 0;
    my @column_list = ();

    foreach my $c (@$columns) {
        push @column_list, '`'.$c->[5].'`';
        my $unique= $executor->execute("SELECT constraint_name, max(ordinal_position) o "
          . "FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS NATURAL JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE "
          . "WHERE table_name ='$table_name' AND constraint_type in ('PRIMARY KEY','UNIQUE') "
          . "AND column_name = '$c->[5]' GROUP BY constraint_name HAVING o = 1")->data();
        # If there are unique keys which only consist of this column,
        # we will need to generate unique values
        if (scalar (@$unique)) {
          $c->[4]= 1;
        }
    }

    my $column_list = join ',', @column_list;

    $executor->execute('SET @innodb_flush_log_at_trx_commit_saved = @@innodb_flush_log_at_trx_commit');
    $executor->execute('SET GLOBAL innodb_flush_log_at_trx_commit=0');

    VALUES:
    while ($row_count < $rows)
    {
        if ($trx_size >= 1000000) {
            $executor->execute("COMMIT");
            $trx_size = 0;
        }
        if ($trx_size == 0) {
            $executor->execute("START TRANSACTION");
        }

        my %unique_values = ();
        my $stmt = "INSERT IGNORE INTO $table_name ($column_list) VALUES (";
        foreach (1..200) {

            foreach my $c (@$columns) {
                my $val;
                my $unique_ok = 0;
                do {
                    my @possible_vals = ();

                    # only use defaults if not a part of a unique key
                    if ($c->[4] == 0) {
                        if ($c->[2] eq 'YES') {
                            push @possible_vals, 'NULL';
                        }
                        if ($c->[1] ne 'NULL') {
                            push @possible_vals, $c->[1];
                        }
                        $unique_ok = 1;
                    }

                    if ($c->[3] eq 'auto_increment') {
                        push @possible_vals, 'NULL';
                        $unique_ok = 1;
                    }
                    else {
                        if ($c->[0] =~ /^((?:(?:big|small|medium|tiny)?int)|double|float|decimal|numeric)(?:\(\d+,?\d?\))?\s*(unsigned)?/) {
                            my $type = $1 . ($2 ? '_unsigned' : '');
                            push @possible_vals, ( $type, 'digit', 'tinyint_unsigned' );
                        }
                        elsif ($c->[0] =~ /^((?:(?:long|medium|tiny)?text)|(?:var)?(?:char|binary)\(\d+\)?)/) {
                            @possible_vals = (@possible_vals, 'letter','_english','_states', 'char(4)', '_english',$1);
                        }
                        elsif ($c->[0] =~ /geometry/) {
                            push @possible_vals, 'NULL';
                        }
                        elsif ($c->[0] =~ /enum\((.*?)\)/) {
                          push @possible_vals, split /,/, $1;
                        }
                        else {
                            push @possible_vals, $c->[0];
                        }
                    }
                    $val = $prng->arrayElement(\@possible_vals);

                    if ($val ne 'NULL' and $prng->isFieldType($val)) {
                        $val = $prng->fieldType($val);
                    }
                    unless ($val eq 'NULL' or $val =~ /^LOAD_.+\(/ or $val =~ /^CURRENT_TIMESTAMP/) {
                    $val =~ s{'}{\\'}sgio;
                        $val = "'".$val."'";
                    }

                    unless ($unique_ok) {
                        if (not defined ${$unique_values{$c->[5]}}->{$val}) {
                            ${$unique_values{$c->[5]}}->{$val} = 1;
                            $unique_ok = 1;
                        }
                    }
                } until $unique_ok;

                $stmt .= "$val,";

            }
            # remove the last comma in the value list and add the bracket
            chop $stmt;
            $stmt .= '),(';
            $row_count++;
            last if $row_count >= $rows;
        }
        chop $stmt; chop $stmt; # Remove the last ,(
        $executor->execute("$stmt");
        if ($row_count >= $rows) {
            say("Inserted ~$row_count rows into $table_name");
        }
        elsif ($row_count%10000 == 0) {
            say("Inserted ~$row_count rows...")
        }
    }

    $executor->execute("COMMIT");
    $executor->execute('SET GLOBAL innodb_flush_log_at_trx_commit = @innodb_flush_log_at_trx_commit_saved');
}

1;
