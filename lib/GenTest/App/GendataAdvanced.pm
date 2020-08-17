# Copyright (C) 2009 Sun Microsystems, Inc. All rights reserved.
# Copyright (c) 2016 MariaDB Corporation Ab
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

package GenTest::App::GendataAdvanced;

@ISA = qw(GenTest);

use strict;
use DBI;
use GenTest;
use GenTest::Constants;
use GenTest::Random;
use GenTest::Executor;

use Data::Dumper;

use constant GDS_DEFAULT_DSN => 'dbi:mysql:host=127.0.0.1:port=9306:user=root:database=test';

use constant GDS_DSN => 0;
use constant GDS_ENGINE => 1;
use constant GDS_VIEWS => 2;
use constant GDS_SQLTRACE => 3;
use constant GDS_NOTNULL => 4;
use constant GDS_ROWS => 5;
use constant GDS_VARCHAR_LENGTH => 6;
use constant GDS_VCOLS => 7;
use constant GDS_EXECUTOR_ID => 8;
use constant GDS_PARTITIONS => 9;
use constant GDS_COMPATIBILITY => 10;

use constant GDS_DEFAULT_ROWS => [0, 1, 20, 100, 1000, 0, 1, 20, 100];
use constant GDS_DEFAULT_NAMES => ['t1', 't2', 't3', 't4', 't5', 't6', 't7', 't8', 't9'];

my $prng;

sub new {
    my $class = shift;

    my $self = $class->SUPER::new({
        'dsn' => GDS_DSN,
        'engine' => GDS_ENGINE,
        'views' => GDS_VIEWS,
        'sqltrace' => GDS_SQLTRACE,
        'notnull' => GDS_NOTNULL,
        'rows' => GDS_ROWS,
        'varchar_length' => GDS_VARCHAR_LENGTH,
        'vcols' => GDS_VCOLS,
        'executor_id' => GDS_EXECUTOR_ID,
        'partitions' => GDS_PARTITIONS,
        'compatibility' => GDS_COMPATIBILITY,
    },@_);

    if (not defined $self->[GDS_DSN]) {
        $self->[GDS_DSN] = GDS_DEFAULT_DSN;
    }
        
    return $self;
}

sub defaultDsn {
    return GDS_DEFAULT_DSN;
}

sub dsn {
    return $_[0]->[GDS_DSN];
}

sub engine {
    return $_[0]->[GDS_ENGINE];
}

sub vcols {
    return $_[0]->[GDS_VCOLS];
}

sub views {
    return $_[0]->[GDS_VIEWS];
}

sub sqltrace {
    return $_[0]->[GDS_SQLTRACE];
}

sub rows {
    return $_[0]->[GDS_ROWS];
}

sub partitions {
    return $_[0]->[GDS_PARTITIONS];
}

sub varcharLength {
    return $_[0]->[GDS_VARCHAR_LENGTH] || 1;
}

sub executor_id {
    return $_[0]->[GDS_EXECUTOR_ID] || '';
}

sub compatibility {
    return $_[0]->[GDS_COMPATIBILITY];
}

sub run {
    my ($self) = @_;

    say("Running GendataAdvanced");
    
    $prng = GenTest::Random->new( seed => 0 );

    my $executor = GenTest::Executor->newFromDSN($self->dsn());
    if ($executor->type != DB_MYSQL && $executor->type != DB_MARIADB) {
        die "Only MySQL executor type is supported\n";
    }
    $executor->sqltrace($self->sqltrace);
    $executor->setId($self->executor_id);
    $executor->init();

    my $names = GDS_DEFAULT_NAMES;
    my $rows;

    if (defined $self->rows()) {
        $rows = [split(',', $self->rows())];
    } else {
        $rows = GDS_DEFAULT_ROWS;
    }

    my $res= STATUS_OK;
    foreach my $i (0..$#$names) {
        my $gen_table_result = $self->gen_table($executor, $names->[$i], $rows->[$i], $prng);
        $res= $gen_table_result if $gen_table_result > $res;
    }

    $executor->execute("SET SQL_MODE= CONCAT(\@\@sql_mode,',NO_ENGINE_SUBSTITUTION')") if ($executor->type == DB_MYSQL || $executor->type == DB_MARIADB);
    return $res;
}

sub random_null {
    return $prng->uint16(0,1) ? 'NULL' : 'NOT NULL' ;
}
sub random_unsigned {
    return $prng->uint16(0,1) ? 'UNSIGNED' : undef ;
}
sub random_zerofill {
    return $prng->uint16(0,1) ? 'ZEROFILL' : undef ;
}
sub random_int_type {
    return $prng->arrayElement(['TINYINT','SMALLINT','MEDIUMINT','INT','BIGINT']);
}
sub random_float_type {
    return $prng->uint16(0,1) ? 'FLOAT' : 'DOUBLE' ;
}
sub random_char_type {
    return $prng->uint16(0,1) ? 'CHAR' : 'BINARY' ;
}
sub random_varchar_type {
    return $prng->uint16(0,1) ? 'VARCHAR' : 'VARBINARY' ;
}
sub random_enum_type {
    return ($prng->uint16(0,1) ? 'ENUM' : 'SET') . "('','a','b','c','d','e','f','foo','bar')" ;
}
sub random_blob_type {
    return $prng->arrayElement(['TINYBLOB','TINYTEXT','BLOB','TEXT','MEDIUMBLOB', 'MEDIUMTEXT', 'LONGBLOB', 'LONGTEXT']);
}
sub random_autoinc_variation {
    return ('INTEGER AUTO_INCREMENT', 'SERIAL', 'BIGINT')[$prng->uint16(0,2)];
}
sub random_or_predefined_vcol_kind {
    return ($_[0]->vcols() eq '' ? ($prng->uint16(0,1) ? '/*!50701 STORED */ /*!100000 PERSISTENT */' : 'VIRTUAL') : $_[0]->vcols());
}
sub random_invisible {
    return $prng->uint16(0,5) ? undef : '/*!100303 INVISIBLE */' ;
}
sub random_compressed {
    return $prng->uint16(0,9) ? undef : '/*!100302 COMPRESSED */' ;
}
sub random_partition_type {
    return $prng->arrayElement(['HASH','KEY','RANGE','LIST']);
}


sub gen_table {
    my ($self, $executor, $basename, $size, $prng) = @_;

    my $nullability = defined $self->[GDS_NOTNULL] ? 'NOT NULL' : '/*! NULL */';  
    ### NULL is not a valid ANSI constraint, (but NOT NULL of course,
    ### is)

    my $varchar_length = $self->varcharLength();

    my $engine = $self->engine();
    my $views = $self->views();
    my ($nullable, $precision);

    my $res= STATUS_OK;

    # column_name => [ type, length, unsigned, zerofill, nullability, default, virtual, invisible, compressed ]

    # Columns of different types are created with different probability.

    # id column is always created
    my %columns = (
        id      => [    random_autoinc_variation(),
                        undef,
                        undef,
                        undef,
                        undef,
                        undef,
                        undef,
                        random_invisible(),
                        undef
                    ]
    );
    # Bit columns are buggy and thus not very interesting. 10%
    if (!$prng->uint16(0,9)) {
        $columns{col_bit} = [   'BIT',
                                $prng->uint16(0,64),
                                undef,
                                undef,
                                $nullable = random_null(),
                                ( $nullable eq 'NULL' ? undef : '0' ),
                                undef,
                                ( $nullable eq 'NULL' ? undef : random_invisible() ),
                                undef
                            ]
    }
    # Int columns are common and important. 90%
    if ($prng->uint16(0,9)) {
        $columns{col_int} = [   random_int_type(),
                                $prng->uint16(0,64),
                                random_unsigned(),
                                random_zerofill(),
                                $nullable = random_null(),
                                ( $nullable eq 'NULL' ? undef : '0' ),
                                undef,
                                ( $nullable eq 'NULL' ? undef : random_invisible() ),
                                undef
                            ]
    }

    # Decimal columns are relatively common. 25%
    if (!$prng->uint16(0,3)) {
        $columns{col_dec} = [   'DECIMAL',
                                $precision = $prng->uint16(0,65) . ',' . $prng->uint16(0,$precision),
                                random_unsigned(),
                                random_zerofill(),
                                $nullable = random_null(),
                                ( $nullable eq 'NULL' ? undef : '0' ),
                                undef,
                                ( $nullable eq 'NULL' ? undef : random_invisible() ),
                                undef
                            ]
    }
    # Date columns are relatively common. 33%
    if (!$prng->uint16(0,2)) {
        $columns{col_date} = [  'DATE',
                                undef,
                                undef,
                                undef,
                                $nullable = random_null(),
                                ( $nullable eq 'NULL' ? undef : "'1900-01-01'" ),
                                undef,
                                ( $nullable eq 'NULL' ? undef : random_invisible() ),
                                undef
                            ]
    }

    # Datetime columns are fairly common and important. 50%
    if ($prng->uint16(0,1)) {
        $columns{col_datetime} = ['DATETIME',
                                $prng->uint16(0,6),
                                undef,
                                undef,
                                $nullable = random_null(),
                                ( $nullable eq 'NULL' ? undef : "'1900-01-01 00:00:00'" ),
                                undef,
                                ( $nullable eq 'NULL' ? undef : random_invisible() ),
                                undef
                            ]
    }

    # Timestamp columns are fairly common and important. 50%
    if ($prng->uint16(0,1)) {
        $columns{col_timestamp} = ['TIMESTAMP',
                                $prng->uint16(0,6),
                                undef,
                                undef,
                                $nullable = random_null(),
                                ( $nullable eq 'NULL' ? undef : "'1971-01-01 00:00:00'" ),
                                undef,
                                ( $nullable eq 'NULL' ? undef : random_invisible() ),
                                undef
                            ]
    }

    # Time columns are relatively common. 25%
    if (!$prng->uint16(0,3)) {
        $columns{col_time} = [ 'TIME',
                                $prng->uint16(0,6),
                                undef,
                                undef,
                                $nullable = random_null(),
                                ( $nullable eq 'NULL' ? undef : "'00:00:00'" ),
                                undef,
                                ( $nullable eq 'NULL' ? undef : random_invisible() ),
                                undef
                            ]
    }

    # Year columns aren't very common. 20%
    if (!$prng->uint16(0,4)) {
        $columns{col_year} = [  'YEAR',
                                undef,
                                undef,
                                undef,
                                $nullable = random_null(),
                                ( $nullable eq 'NULL' ? undef : "'1970'" ),
                                undef,
                                ( $nullable eq 'NULL' ? undef : random_invisible() ),
                                undef
                            ]
    }

    # Char columns are common and important. 75%
    if ($prng->uint16(0,3)) {
        $columns{col_char} = [ random_char_type(),
                                $prng->uint16(0,255),
                                undef,
                                undef,
                                $nullable = random_null(),
                                ( $nullable eq 'NULL' ? undef : "''" ),
                                undef,
                                ( $nullable eq 'NULL' ? undef : random_invisible() ),
                                undef
                            ]
    }

    # Varchar columns are common and important. 90%
    if ($prng->uint16(0,9)) {
        $columns{col_varchar} = [random_varchar_type(),
                                $prng->uint16(0,4096),
                                undef,
                                undef,
                                $nullable = random_null(),
                                ( $nullable eq 'NULL' ? undef : "''" ),
                                undef,
                                ( $nullable eq 'NULL' ? undef : random_invisible() ),
                                random_compressed()
                            ]
    }

    # Blob columns are relatively common. 33%
    if (!$prng->uint16(0,2)) {
        $columns{col_blob} = [ random_blob_type(),
                                undef,
                                undef,
                                undef,
                                $nullable = random_null(),
                                ( $nullable eq 'NULL' ? undef : "''" ),
                                undef,
                                ( $nullable eq 'NULL' ? undef : random_invisible() ),
                                random_compressed()
                            ]
    }

    # Enum columns are relatively common. 20%
    if (!$prng->uint16(0,4)) {
        $columns{col_enum} = [  random_enum_type(),
                                undef,
                                undef,
                                undef,
                                $nullable = random_null(),
                                ( $nullable eq 'NULL' ? undef : "''" ),
                                undef,
                                ( $nullable eq 'NULL' ? undef : random_invisible() ),
                                undef
                            ]
    }

    # INET6 data type was introduced in 10.5.0
    # INET6 columns shoudn't be very common, but they're new. 20% for now
    if ($self->compatibility ge '100500' and !$prng->uint16(0,4)) {
        $columns{col_inet6} = [ 'INET6',
                                undef,
                                undef,
                                undef,
                                $nullable = random_null(),
                                ( $nullable eq 'NULL' ? undef : "'::'" ),
                                undef,
                                ( $nullable eq 'NULL' ? undef : random_invisible() ),
                                undef
                            ]
    }

    # TODO: Add JSON

    # If `id` column is auto-increment, it must be a part of the primary key (or unique key)
    my $col= $columns{id};
    my $has_autoinc= $col->[0] =~ /AUTO_INCREMENT/;
    my %pk_columns= ($has_autoinc ? (id => 1) : ());

    if ($self->vcols)
    {
        # TODO: add actual functions for virtual columns

        # For simplicity, we keep the same probability as corresponding base columns have,
        # but the virtual column can only exist if the base column does.
        # So, 10% probability for virtual bit column means in fact 1%, etc.

        if ($columns{col_bit} and !$prng->uint16(0,9)) {
            $columns{vcol_bit}= [   'BIT',
                                    $prng->uint16(0,64),
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    'AS (col_bit) '.$self->random_or_predefined_vcol_kind(),
                                    random_invisible(),
                                    undef
                                ];
        }

        if ($columns{col_int} and $prng->uint16(0,9)) {
            $columns{vcol_int}= [   random_int_type(),
                                    $prng->uint16(0,64),
                                    undef,
                                    random_zerofill(),
                                    undef,
                                    undef,
                                    'AS (col_int) '.$self->random_or_predefined_vcol_kind(),
                                    random_invisible(),
                                    undef
                                ];
        }

        if ($columns{col_dec} and !$prng->uint16(0,3)) {
            my $precision = $prng->uint16(0,65);
            my $scale = $prng->uint16(0,($precision<=38?$precision:38));
            $columns{vcol_dec}= [   'DECIMAL',
                                    "$precision,$scale",
                                    undef,
                                    random_zerofill(),
                                    undef,
                                    undef,
                                    'AS (col_dec) '.$self->random_or_predefined_vcol_kind(),
                                    random_invisible(),
                                    undef
                                ];
        }

        if ($columns{col_date} and !$prng->uint16(0,2)) {
            $columns{vcol_date}= [  'DATE',
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    'AS (col_date) '.$self->random_or_predefined_vcol_kind(),
                                    random_invisible(),
                                    undef
                                ];
        }

        if ($columns{col_datetime} and $prng->uint16(0,1)) {
            $columns{vcol_datetime}= ['DATETIME',
                                    $prng->uint16(0,6),
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    'AS (col_datetime) '.$self->random_or_predefined_vcol_kind(),
                                    random_invisible(),
                                    undef
                                ];
        }

        if ($columns{col_timestamp} and $prng->uint16(0,1)) {
            $columns{vcol_timestamp}= ['TIMESTAMP',
                                    $prng->uint16(0,6),
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    'AS (col_timestamp) '.$self->random_or_predefined_vcol_kind(),
                                    random_invisible(),
                                    undef
                                ];
        }

        if ($columns{col_time} and !$prng->uint16(0,3)) {
            $columns{vcol_time}= [  'TIME',
                                    $prng->uint16(0,6),
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    'AS (col_time) '.$self->random_or_predefined_vcol_kind(),
                                    random_invisible(),
                                    undef
                                ];
        }

        if ($columns{col_year} and !$prng->uint16(0,4)) {
            $columns{vcol_year}= [  'YEAR',
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    'AS (col_year) '.$self->random_or_predefined_vcol_kind(),
                                    random_invisible(),
                                    undef
                                ];
        }

        if ($columns{col_char} and $prng->uint16(0,3)) {
            $columns{vcol_char}= [  random_char_type(),
                                    $prng->uint16(0,255),
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    'AS (col_char) '.$self->random_or_predefined_vcol_kind(),
                                    random_invisible(),
                                    undef
                                ];
        }

        if ($columns{col_varchar} and $prng->uint16(0,9)) {
            $columns{vcol_varchar}= [random_varchar_type(),
                                    $prng->uint16(0,4096),
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    'AS (col_varchar) '.$self->random_or_predefined_vcol_kind(),
                                    random_invisible(),
                                    undef
                                ];
        }

        if ($columns{col_blob} and !$prng->uint16(0,2)) {
            $columns{vcol_blob}= [  random_blob_type(),
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    'AS (col_blob) '.$self->random_or_predefined_vcol_kind(),
                                    random_invisible(),
                                    undef
                                ];
        }

        if ($columns{col_enum} and !$prng->uint16(0,4)) {
            $columns{vcol_enum}= [  random_enum_type(),
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    'AS (col_enum) '.$self->random_or_predefined_vcol_kind(),
                                    random_invisible(),
                                    undef
                                ];
        }

        if ($columns{col_inet6} and !$prng->uint16(0,4)) {
            $columns{vcol_inet6}= [ 'INET6',
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    'AS (col_inet6) '.$self->random_or_predefined_vcol_kind(),
                                    random_invisible(),
                                    undef
                                ];
        }
    }

    my @engines= ($engine ? split /,/, $engine : '');
    foreach my $e (@engines)
    {
      my $name = ( $e eq $engine ? $basename : $basename . '_'.$e );

      say("Creating ".$executor->getName()." table $name, size $size rows, " . ($e eq '' ? "default engine" : "engine $e"));

      ### This variant is needed due to
      ### http://bugs.mysql.com/bug.php?id=47125

      $executor->execute("DROP TABLE /*! IF EXISTS */ $name");
      my $create_stmt = "CREATE TABLE $name (";
      my @column_list = ();
      my @columns= ();
      foreach my $c (sort keys %columns) {
          my $coldef= $columns{$c};
          unless (($c eq 'id' and ($has_autoinc)) or defined $coldef->[6]) {
              push @column_list, $c;
          }
          push @columns, 
              "$c $coldef->[0]"         # type
              . ($coldef->[1] ? "($coldef->[1])" : '') # length
              . ($coldef->[2] ? " $coldef->[2]" : '')  # unsigned
              . ($coldef->[3] ? " $coldef->[3]" : '')  # zerofill
              . ($coldef->[4] ? " $coldef->[4]" : '')  # nullability
              . (defined $coldef->[5] ? " DEFAULT $coldef->[5]" : '')   # default
              . (defined $coldef->[6] ? " $coldef->[6]" : '') # virtual
              . ($coldef->[7] ? " $coldef->[7]" : '')  # invisible
              . ($coldef->[8] ? " $coldef->[8]" : '')  # compressed
          ;
      };
      my @create_table_columns= @columns;
      $prng->shuffleArray(\@create_table_columns);
      $create_stmt.= join ', ', @create_table_columns;
      my $pk_stmt= '';

      # Create PK for 90% of tables
      if ($prng->uint16(0,9))
      {
          my $num_of_columns_in_pk= $prng->uint16(1,4);
          my @cols= sort keys %columns;
          $prng->shuffleArray(\@cols);
          foreach my $c (@cols) {
            next if defined $columns{$c}->[8]; # Compressed columns cannot be in an index
            last if scalar(keys %pk_columns) >= $num_of_columns_in_pk;
            next if $pk_columns{$c};
            if ($columns{$c}->[0] =~ /BLOB|TEXT/) {
                $c= $c.'('.$prng->uint16(1,32).')';
            }
            $pk_columns{$c}= 1;
          }
          # For InnoDB and HEAP (TODO: and probably some other engines, but not MyISAM or Aria)
          # the auto-increment column has to be the first one in the primary key
          if ($has_autoinc and ($e =~ /InnoDB|MEMORY|HEAP/i or $e eq '' and $executor->serverVariable('default_storage_engine')))
          {
              delete $pk_columns{id};
              if (scalar(keys %pk_columns)) {
                  @cols= sort keys %pk_columns;
                  $prng->shuffleArray(\@cols);
                  unshift @cols, 'id';
              } else {
                  @cols= ('id');
              }
          } else {
              @cols= sort keys %pk_columns;
              $prng->shuffleArray(\@cols);
          }
          if ($has_autoinc) {
            # If there is an auto-increment column, we have to add PRIMARY KEY right away in the CREATE statement
            $create_stmt.= ', PRIMARY KEY('.(join ',', @cols).")";
          } else {
            # Otherwise, it is always better to add it separately, since it can fail
            $pk_stmt= "ALTER TABLE $name ADD PRIMARY KEY (".(join ',', @cols).")";
          }
      }
      elsif ($has_autoinc) {
          $create_stmt.= ", UNIQUE(id)";
      }
      $create_stmt .= ")" . ($e ne '' ? " ENGINE=$e" : "");

      $res= $executor->execute($create_stmt);
      if ($res->status != STATUS_OK) {
          sayError("Failed to create table $name: " . $res->errstr);
          return $res->status;
      }

      if ($pk_stmt) {
          $res= $executor->execute($pk_stmt);
          if ($res->status != STATUS_OK) {
              sayError("Failed to add primary key to table $name: " . $res->errstr);
          }
      }

      # partition 50% tables (if requested at all). Not all of them will succeed
      if ($self->partitions and $prng->uint16(0,1))
      {
          my $partition_type= $self->random_partition_type();
          my $partition_column= (scalar(keys %pk_columns) ? $prng->arrayElement([sort keys %pk_columns]) : 'id');
          my $part_stmt.= 'ALTER TABLE ' . $name . ' PARTITION BY ' .$partition_type.'('.$partition_column.') ';

          if ($partition_type eq 'KEY' or $partition_type eq 'HASH') {
              $part_stmt.= 'PARTITIONS '.$prng->uint16(1,20);
          } elsif ($partition_type eq 'RANGE') {
              my @parts= ();
              my $part_count= $prng->uint16(1,20);
              my $part_max_value= -1;
              my $max_value= $size || 1;
              for (my $i= 1; $i<$part_count; $i++) {
                  last if $part_max_value >= $max_value;
                  $part_max_value= $prng->uint16($part_max_value+1,$max_value);
                  push @parts, 'PARTITION p'.$i.' VALUES LESS THAN ('.$part_max_value.')';
              }
              push @parts, 'PARTITION pmax VALUES LESS THAN (MAXVALUE)';
              $part_stmt.= '('.(join ',',@parts).')';
          } elsif ($partition_type eq 'LIST') {
              my @vals= ();
              foreach my $i (0..($size*10 || 1)) {
                  push @vals, $i;
              }
              my @parts= ();
              my $n= 1;
              while (scalar(@vals)) {
                  my $part_val_count= $prng->uint16(1,scalar(@vals));
                  my @shuffled_vals= @vals;
                  $prng->shuffleArray(\@shuffled_vals);
                  my @part_vals= splice(@shuffled_vals,0,$part_val_count);
                  @vals= @shuffled_vals;
                  push @parts, 'PARTITION p'.$n++.' VALUES IN ('.(join ',', @part_vals).')';
              }
              $part_stmt.= '('.(join ',',@parts).')';
          }
          $res= $executor->execute($part_stmt);
          if ($res->status == STATUS_OK) {
              say("Table $name has been partitioned by $partition_type($partition_column)");
          } else {
              sayError("Failed to partition table $name by $partition_type($partition_column): " . $res->errstr);
          }
      }

      if (defined $views) {
          if ($views ne '') {
              $executor->execute("CREATE ALGORITHM=$views VIEW view_".$name.' AS SELECT * FROM '.$name);
          } else {
              $executor->execute('CREATE VIEW view_'.$name.' AS SELECT * FROM '.$name);
          }
      }

      # The limit for the number of indexes is purely arbitrary, there is no secret wisdom
      my $number_of_indexes= $prng->uint16(0,scalar(keys %columns)*2);

      foreach (1..$number_of_indexes)
      {
          my $number_of_columns= $prng->uint16(1,scalar(keys %columns));
          # TODO: make it conditional depending on the version -- keys %columns vs @column_list
          my @cols=();
          foreach my $c (sort keys %columns) {
              push @cols, $c;
          }
          $prng->shuffleArray(\@cols);
          @cols= @cols[0..$number_of_columns-1];
          foreach my $i (0..$#cols) {
              my $c= $cols[$i];
              next if defined $columns{$c}->[8]; # Compressed columns cannot be in an index
              my $tp= $columns{$c}->[0];
              if ($tp eq 'TINYBLOB' or $tp eq 'TINYTEXT' or $tp eq 'BLOB' or $tp eq 'TEXT' or $tp eq 'MEDIUMBLOB' or $tp eq 'MEDIUMTEXT' or $tp eq 'LONGBLOB' or $tp eq 'LONGTEXT' or $tp eq 'CHAR' or $tp eq 'VARCHAR' or $tp eq 'BINARY' or $tp eq 'VARBINARY')
              {
                  # Starting from 10.4.3, long unique blobs are allowed.
                  # For a non-unique index the column will be auto-sized by the server (with a warning)
                  if ($self->compatibility ge '100403' and $prng->uint16(0,1)) {
                    $cols[$i] = $c;
                  } else {
                    my $length= ( $columns{$c}->[1] and $columns{$c}->[1] < 64 ) ? $columns{$c}->[1] : 64;
                    $cols[$i] = "$c($length)";
                  }
              }
          }
          $executor->execute("ALTER TABLE $name ADD " . ($prng->uint16(0,5) ? 'INDEX' : 'UNIQUE') . "(". join(',',@cols) . ")");
      }

      my @values;

      $executor->execute("START TRANSACTION");
      foreach my $row (1..$size)
      {
          my @row_values = ();
          my $val;

          foreach my $cname (@column_list)
          {
              my $c = $columns{$cname};

              if ($c->[0] eq 'TINYINT' or $c->[0] eq 'SMALLINT' or $c->[0] eq 'MEDIUMINT' or $c->[0] eq 'INT' or $c->[0] eq 'BIGINT')
              {
                  # 10% NULLs, 10% tinyint_unsigned, 80% digits
                  my $pick = $prng->uint16(0,9);

                  if ($c->[4] eq 'NOT NULL') {
                      $val = ($pick == 8 ? $prng->int(0,255) : $prng->digit() );
                  } else {
                      $val = $pick == 9 ? "NULL" : ($pick == 8 ? $prng->int(0,255) : $prng->digit() );
                  }
              }
              elsif ($c->[0] eq 'BIT') {
                  if ($c->[4] eq 'NOT NULL') {
                      $val = $prng->bit($c->[1]);
                  } else {
                      $val = $prng->uint16(0,9) == 9 ? "NULL" : $prng->bit($c->[1]);
                  }
              }
              # ('','a','b','c','d','e','f','foo','bar')
              elsif ($c->[0] =~ /^(?:ENUM|SET)/) {
                  if ($c->[4] eq 'NOT NULL') {
                      $val = "'".$prng->arrayElement('','a','b','c','d','e','f','foo','bar')."'";
                  } else {
                      $val = $prng->uint16(0,9) == 9 ? "NULL" : "'".$prng->arrayElement('','a','b','c','d','e','f','foo','bar')."'";
                  }
              }
              elsif ($c->[0] eq 'FLOAT' or $c->[0] eq 'DOUBLE' or $c->[0] eq 'DECIMAL') {
                  if ($c->[4] eq 'NOT NULL') {
                      $val = $prng->float();
                  } else {
                      $val = $prng->uint16(0,9) == 9 ? "NULL" : $prng->float();
                  }
              }
              elsif ($c->[0] eq 'YEAR') {
                  if ($c->[4] eq 'NOT NULL') {
                      $val = $prng->year();
                  } else {
                      $val = $prng->uint16(0,9) == 9 ? "NULL" : $prng->year();
                  }
              }
              elsif ($c->[0] eq 'DATE') {
                  # 10% NULLS, 10% '1900-01-01', pick real date/time/datetime for the rest

                  $val = "'".$prng->date()."'";
                  $val = ($val, $val, $val, $val, $val, $val, $val, $val, "NULL", "'1900-01-01'")[$prng->uint16(0,9)];
              }
              elsif ($c->[0] eq 'TIME') {
                  # 10% NULLS, 10% '1900-01-01', pick real date/time/datetime for the rest

                  $val = "'".$prng->time()."'";
                  $val = ($val, $val, $val, $val, $val, $val, $val, $val, "NULL", "'00:00:00'")[$prng->uint16(0,9)];
              }
              elsif ($c->[0] eq 'DATETIME' or $c->[0] eq 'TIMESTAMP') {
              # 10% NULLS, 10% "1900-01-01 00:00:00', 20% date + " 00:00:00"

                  $val = $prng->datetime();
                  my $val_date_only = $prng->date();

                  if ($c->[4] eq 'NOT NULL') {
                      $val = ($val, $val, $val, $val, $val, $val, $val, $val_date_only." 00:00:00", $val_date_only." 00:00:00", '1900-01-01 00:00:00')[$prng->uint16(0,9)];
                  } else {
                      $val = ($val, $val, $val, $val, $val, $val, $val_date_only." 00:00:00", $val_date_only." 00:00:00", "NULL", '1900-01-01 00:00:00')[$prng->uint16(0,9)];
                  }
                  $val = "'".$val."'" if not $val eq "NULL";
              }
              elsif ($c->[0] eq 'CHAR' or $c->[0] eq 'VARCHAR' or $c->[0] eq 'BINARY' or $c->[0] eq 'VARBINARY' or $c->[0] eq 'TINYBLOB' or $c->[0] eq 'BLOB' or $c->[0] eq 'MEDIUMBLOB' or $c->[0] eq 'LONGBLOB')
              {
                  my $length= $prng->uint16(0,9) == 9 ? $prng->uint16(0,$c->[1]) : $prng->uint16(0,8);
                  if ($c->[4] eq 'NOT NULL') {
                      $val = "'".$prng->string($length)."'";
                  } else {
                      $val = $prng->uint16(0,9) == 9 ? "NULL" : "'".$prng->string($length)."'";
                  }
              }
              elsif ($c->[0] =~ /(TINY|MEDIUM|LONG)?TEXT/)
              {
                  my $maxlength= 65535;
                  if ($1 eq 'TINY') {
                    $maxlength= 255;
                  }
                  my $length= $prng->uint16(0,$maxlength);
                  if ($c->[4] eq 'NOT NULL') {
                      $val = "'".$prng->text($length)."'";
                  } else {
                      $val = $prng->uint16(0,5) ? "'".$prng->text($length)."'" : "NULL";
                  }
              }
              elsif ($c->[0] eq 'INET6') {
                  if ($c->[4] eq 'NOT NULL') {
                      $val = $prng->inet6();
                  } else {
                      $val = $prng->uint16(0,9) == 9 ? "NULL" : $prng->inet6();
                  }
              }
              push @row_values, $val;
          }
          # $rnd_int1, $rnd_int2, $rnd_date, $rnd_date, $rnd_time, $rnd_time, $rnd_datetime, $rnd_datetime, $rnd_varchar, $rnd_varchar)
          push @values, "\n(" . join(',',@row_values).")";

          ## We do one insert per 500 rows for speed
          if ($row % 500 == 0 || $row == $size) {
              $res = $executor->execute("
              INSERT IGNORE INTO $name (" . join(",",@column_list).") VALUES" . join(",",@values));
              if ($res->status() != STATUS_OK) {
                  sayError("Insert into table $name didn't succeed");
                  return $res->status();
              }
              @values = ();
          }
      }
      $executor->execute("COMMIT");
    }
    return STATUS_OK;
}

1;
