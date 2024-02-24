# Copyright (C) 2009 Sun Microsystems, Inc. All rights reserved.
# Copyright (c) 2016, 2022 MariaDB Corporation Ab
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

package GenData::GendataAdvanced;
@ISA = qw(GenData);

use strict;

use GenData;
use GenTest;
use Constants;
use GenTest::Random;
use GenTest::Executor;
use GenUtil;

use Data::Dumper;

use constant GDA_DEFAULT_ROWS => [0, 1, 20, 100, 1000, 0, 1, 20, 100];
use constant GDA_DEFAULT_DB => 'advanced_db';

my $prng;
my $remote_created;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    return $self;
}

sub run {
    my ($self) = @_;
    $prng = $self->rand();
    my $executor = $self->executor();
    my $rows;
    if (defined $self->rows()) {
        $rows = [split(',', $self->rows())];
    } else {
        $rows = GDA_DEFAULT_ROWS;
    }

    my $res= STATUS_OK;
    $executor->execute("SET SQL_MODE= CONCAT(\@\@sql_mode,',NO_ENGINE_SUBSTITUTION'), ENFORCE_STORAGE_ENGINE= NULL");
    say("GendataAdvanced is creating tables");
    $executor->execute("CREATE DATABASE IF NOT EXISTS ".$self->GDA_DEFAULT_DB);
    # PS is a workaround for MENT-30190
    $executor->execute("EXECUTE IMMEDIATE CONCAT('GRANT ALL ON ".$self->GDA_DEFAULT_DB.".* TO ',CURRENT_USER,' WITH GRANT OPTION')");

    my @engines= ($self->engine ? split /,/, $self->engine : '');

    my $res= STATUS_OK;
    foreach my $e (@engines) {
      if (isFederatedEngine($e) and not $remote_created) {
        unless ($self->setupRemote($self->GDA_DEFAULT_DB) == STATUS_OK) {
          sayError("Could not set up remote access for engine $e");
          return STATUS_ENVIRONMENT_FAILURE;
        }
        # Create remote tables with default engine
        foreach my $i (0..$#$rows) {
          my $gen_table_result = $self->gen_table($executor, 't'.($i+1), $rows->[$i], '', $self->GDA_DEFAULT_DB.'_remote');
          return $gen_table_result if $gen_table_result >= STATUS_CRITICAL_FAILURE;
        }
        $remote_created= 1;
      }

      foreach my $i (0..$#$rows) {
        my $name= ($e eq $self->engine ? 't'.($i+1) : 't'.($i+1).'_'.$e);
        my $gen_table_result = $self->gen_table($executor, $name, $rows->[$i], $e, $self->GDA_DEFAULT_DB);
        return $gen_table_result if $gen_table_result >= STATUS_CRITICAL_FAILURE;
        $res= $gen_table_result if $gen_table_result > $res;
      }
    }
    return $res;
}

sub random_null {
    return $prng->uint16(0,1) ? 'NULL' : 'NOT NULL' ;
}
sub random_unsigned {
    return $prng->uint16(0,1) ? 'UNSIGNED' : undef ;
}
sub random_zerofill {
    return $prng->uint16(0,9) ? undef : 'ZEROFILL' ;
}
sub random_int_type {
    return $prng->arrayElement(['TINYINT','SMALLINT','MEDIUMINT','INT','BIGINT']);
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

sub random_asc_desc_key {
    my ($asc_desc, $engine)= @_;
    # As of 10.8 RocksDB refuses to create DESC keys
    return '' if lc($engine) eq 'rocksdb';
    return ($asc_desc == 1 ? ' ASC' : ($asc_desc == 2 ? ' DESC' : ''));
}

sub gen_table {
    my ($self, $executor, $name, $size, $e, $db) = @_;

    say("Creating table $db.$name, size $size rows, " . ($e ? "engine $e" : "default engine"));

    # Remote table should already be created and populated by now,
    # just need the local one
    if (isFederatedEngine($e)) {
      $self->createFederatedTable($e,$name,$db);
      $self->createView($self->views(),$name,$db) if defined $self->views();
      return STATUS_OK;
    }

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
        my $precision = $prng->uint16(0,65);
        my $scale = $prng->uint16(0,($precision<=38?$precision:38));
        $columns{col_dec} = [   'DECIMAL',
                                "$precision,$scale",
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
                                ( $nullable eq 'NULL' ? undef : "1970" ),
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

    # Blob columns are relatively common, but currently buggy. 33% => 10%
    if (!$prng->uint16(0,9)) {
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

    # Spatial columns are hopefully not very common and they are also painful. 20%,
    # and only if configured explicitly
    if ($self->gis && !$prng->uint16(0,4)) {
    my $tp= $prng->geometryType();
        $columns{col_spatial} = [  $tp,
                                   undef,
                                   undef,
                                   undef,
                                   $nullable = random_null(),
                                   ( $nullable eq 'NULL' ? undef : $prng->spatial($tp) ),
                                   undef,
                                   ( $nullable eq 'NULL' ? undef : random_invisible() ),
                                   undef
                                ]
    }

    # INET6 data type was introduced in 10.5.0
    # INET6 columns shoudn't be very common. 10%
    if (isCompatible('100500',$self->compatibility,$self->compatibility_es) and !$prng->uint16(0,9)) {
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

    # UUID data type was introduced in 10.7.1
    # UUID columns shoudn't be very common, but they're new. 20% for now
    if (isCompatible('100701,es-1006',$self->compatibility,$self->compatibility_es) and !$prng->uint16(0,4)) {
        $columns{col_uuid} = [ 'UUID',
                                undef,
                                undef,
                                undef,
                                $nullable = random_null(),
                                ( $nullable eq 'NULL' ? undef : "'00000000000000000000000000000000'" ),
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

    # RocksDB does not support virtual columns
    if (defined $self->vcols and lc($e) ne 'rocksdb')
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
            my $virtual_type= $self->random_or_predefined_vcol_kind();
            my $length;
            if ($virtual_type =~ /(?:STORED|PERSISTENT)/) {
              # Lossy length conversion depends on TIME_ROUND_FRACTIONAL, warning in 10.4, error in 10.5+
              $length= $prng->uint16($columns{col_datetime}->[1],6)
            } else {
              $length= $prng->uint16(0,6);
            }
            $columns{vcol_datetime}= ['DATETIME',
                                    $length,
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    'AS (col_datetime) '.$virtual_type,
                                    random_invisible(),
                                    undef
                                ];
        }

        if ($columns{col_timestamp} and $prng->uint16(0,1)) {
            my $virtual_type= $self->random_or_predefined_vcol_kind();
            my $length;
            if ($virtual_type =~ /(?:STORED|PERSISTENT)/) {
              # Lossy length conversion depends on TIME_ROUND_FRACTIONAL, warning in 10.4, error in 10.5+
              $length= $prng->uint16($columns{col_timestamp}->[1],6)
            } else {
              $length= $prng->uint16(0,6);
            }
            $columns{vcol_timestamp}= ['TIMESTAMP',
                                    $length,
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    'AS (col_timestamp) '.$virtual_type,
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
          # Starting from 10.5, some combinations of column types produce an error
          # because "1105 Expression depends on the @@sql_mode value PAD_CHAR_TO_FULL_LENGTH"
            my $type= ($columns{col_char}->[0] eq 'CHAR' ? 'CHAR' : random_char_type());
            $columns{vcol_char}= [  $type,
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

        if ($columns{col_spatial} and !$prng->uint16(0,10)) {
            $columns{vcol_spatial}= [  $prng->geometryType(),
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    'AS (col_spatial) '.$self->random_or_predefined_vcol_kind(),
                                    random_invisible(),
                                    undef
                                ];
        }

        if ($columns{col_inet6} and !$prng->uint16(0,9)) {
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
        if ($columns{col_uuid} and !$prng->uint16(0,4)) {
            $columns{vcol_uuid}= [ 'UUID',
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    undef,
                                    'AS (col_uuid) '.$self->random_or_predefined_vcol_kind(),
                                    random_invisible(),
                                    undef
                                ];
        }
    }

    ### This variant is needed due to
    ### http://bugs.mysql.com/bug.php?id=47125

    $executor->execute("DROP TABLE IF EXISTS $db.$name");
    my $create_stmt = "CREATE TABLE $db.$name (";
    my @column_list = ();
    my @columns= ();
    foreach my $c (sort keys %columns) {
        # as of 10.8 RocksDB does not support geometry
        next if $e =~ /rocksdb/i and $c =~ /spatial/i;
        my $coldef= $columns{$c};
        # Virtual columns are not inserted into
        # Auto-increment columns are usually skipped (90%),
        # but sometimes used, mainly to get non-consequent unordered values
        unless (defined $coldef->[6] or ($c eq 'id' and ($has_autoinc) and $prng->uint16(0,9))) {
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
          if ($columns{$c}->[0] =~ /BLOB|TEXT|POINT|LINESTRING|POLYGON|GEOMETRY/) {
              $c= $c.'('.$prng->uint16(1,32).')';
          }
          $pk_columns{$c}= 1;
        }
        # For InnoDB and HEAP (TODO: and probably some other engines, but not MyISAM or Aria)
        # the auto-increment column has to be the first one in the primary key
        if ($has_autoinc and ($e =~ /InnoDB|MEMORY|HEAP/i or $e eq '' and $executor->server->serverVariable('default_storage_engine')))
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
          $create_stmt.= ', PRIMARY KEY('.(join ',', map {$_ . random_asc_desc_key($prng->uint16(0,2),$e) } @cols).")";
        } else {
          # Otherwise, it is always better to add it separately, since it can fail
          $pk_stmt= "ALTER TABLE $db.$name ADD PRIMARY KEY (".(join ',', map {$_ . random_asc_desc_key($prng->uint16(0,2),$e) } @cols).")";
        }
    }
    elsif ($has_autoinc) {
        $create_stmt.= ", UNIQUE(id)";
    }
    $create_stmt .= ")" . ($e ne '' ? " ENGINE=$e" : "");

    $res= $executor->execute($create_stmt);
    if ($res->status != STATUS_OK) {
        sayError("Failed to create table $db.$name: " . $res->errstr);
        return $res->status;
    }

    if ($pk_stmt) {
        $res= $executor->execute($pk_stmt);
        if ($res->status != STATUS_OK) {
            sayError("Failed to add primary key to table $db.$name: " . $res->errstr);
        }
    }

    # partition 50% tables (if requested at all). Not all of them will succeed
    if ($self->partitions and $prng->uint16(0,1))
    {
        my $partition_type= $self->random_partition_type();
        my $partition_column= (scalar(keys %pk_columns) ? $prng->arrayElement([sort keys %pk_columns]) : 'id');
        my $part_stmt.= 'ALTER TABLE ' . $db.'.'.$name . ' PARTITION BY ' .$partition_type.'('.$partition_column.') ';

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
            say("Table $db.$name has been partitioned by $partition_type($partition_column)");
        } else {
            sayError("Failed to partition table $db.$name by $partition_type($partition_column): " . $res->errstr);
        }
    }

    $self->createView($self->views(),$name,$db);

    # The limit for the number of indexes is purely arbitrary, there is no secret wisdom
    my $number_of_indexes= $prng->uint16(0,scalar(keys %columns)*2);

    foreach (1..$number_of_indexes)
    {
        my $number_of_columns= $prng->uint16(1,scalar(keys %columns));
        # TODO: make it conditional depending on the version -- keys %columns vs @column_list
        my @cols=();
        my $text_only= 1;
        foreach my $c (sort keys %columns) {
            push @cols, $c;
            $text_only= 0 if $columns{$c}->[0] !~ /BLOB|TEXT|CHAR|BINARY/;
        }
        $prng->shuffleArray(\@cols);
        @cols= @cols[0..$number_of_columns-1];
        my $ind_type= $prng->uint16(0,5) ? 'INDEX' : 'UNIQUE';
        if ($text_only and not $prng->uint16(0,3)) {
            $ind_type= 'FULLTEXT';
        }
        my @ind_cols;
        foreach my $i (0..$#cols) {
            my $c= $cols[$i];
            next if defined $columns{$c}->[8]; # Compressed columns cannot be in an index
            my $tp= $columns{$c}->[0];
            if ($tp =~ /BLOB|TEXT|CHAR|BINARY|POINT|LINESTRING|POLYGON|GEOMETRY/) {
                # Starting from 10.4.3, long unique blobs are allowed.
                # For a non-unique index the column will be auto-sized by the server (with a warning)
                if (($ind_type ne 'FULLTEXT') and (not isCompatible('100403',$self->compatibility,$self->compatibility_es) or (not $self->uhashkeys) or $prng->uint16(0,1))) {
                  my $length= ( $columns{$c}->[1] and $columns{$c}->[1] < 64 ) ? $columns{$c}->[1] : 64;
                  $c = "$c($length)";
                }
            }
            # DESC indexes: add ASC/DESC to the column
            $c.=random_asc_desc_key($prng->uint16(0,2),$e) if $ind_type ne 'FULLTEXT';
            push @ind_cols, $c;
        }
        if (scalar(@ind_cols)) {
          $executor->execute("ALTER TABLE $db.$name ADD " . $ind_type . "(". join(',',@ind_cols) . ")");
        }
    }
    if ($columns{col_spatial} and $columns{col_spatial}->[4] eq 'NOT NULL' and not $prng->uint16(0,3)) {
        $executor->execute("ALTER TABLE $db.$name ADD SPATIAL(". 'col_spatial' . ")");
    }
    if ($columns{vcol_spatial} and $columns{vcol_spatial}->[4] eq 'NOT NULL' and not $prng->uint16(0,9)) {
        $executor->execute("ALTER TABLE $db.$name ADD SPATIAL(". 'vcol_spatial' . ")");
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
                    $val = $prng->uint16(0,9) == 9 ? "NULL" : "'".$prng->arrayElement(['','a','b','c','d','e','f','foo','bar'])."'";
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

                $val = $prng->date();
                $val = ($val, $val, $val, $val, $val, $val, $val, $val, "NULL", "'1900-01-01'")[$prng->uint16(0,9)];
            }
            elsif ($c->[0] eq 'TIME') {
                # 10% NULLS, 10% '1900-01-01', pick real date/time/datetime for the rest

                $val = $prng->time();
                $val = ($val, $val, $val, $val, $val, $val, $val, $val, "NULL", "'00:00:00'")[$prng->uint16(0,9)];
            }
            elsif ($c->[0] eq 'DATETIME') {
            # 10% NULLS, 10% "1900-01-01 00:00:00', 20% date + " 00:00:00"

                $val = $prng->datetime();
                my $val_date_only = $prng->unquotedDate();
                $val = ($val, $val, $val, $val, $val, $val, "'".$val_date_only." 00:00:00'", "'".$val_date_only." 00:00:00'", "NULL", "'1900-01-01 00:00:00'")[$prng->uint16(0,9)];
            }
            elsif ($c->[0] eq 'TIMESTAMP') {
            # 10% special values
                $val = $prng->timestamp();
                # Don't try to insert NULLs into TIMESTAMP columns, it may end up as a current timestamp
                # due to non-standard behavior of TIMESTAMP columns
                my $special_value= ('0','0.000001','1','FROM_UNIXTIME(0)','FROM_UNIXTIME(0.000001)','FROM_UNIXTIME(POWER(2,31)-1)','FROM_UNIXTIME(POWER(2,32)-1)')[$prng->uint16(0,6)];
                $val = ($val, $val, $val, $val, $val, $val, $val, $val, $val, $special_value)[$prng->uint16(0,9)];
            }
            elsif ($c->[0] eq 'CHAR' or $c->[0] eq 'VARCHAR' or $c->[0] eq 'BINARY' or $c->[0] eq 'VARBINARY')
            {
                if ($c->[4] ne 'NOT NULL' and $prng->uint16(0,9) == 0) {
                  $val= "NULL";
                } else {
                  my $length= $prng->uint16(0,9) == 9 ? $prng->uint16(0,$c->[1]) : $prng->uint16(0,8);
                  $val = $prng->string($length);
                }
            }
            elsif ($c->[0] =~ /(TINY|MEDIUM|LONG)?BLOB/)
            {
              if ($c->[4] ne 'NOT NULL' and $prng->uint16(0,5) == 0) {
                $val= "NULL";
              } elsif ($prng->uint16(0,1)) {
                $val= $prng->loadFile();
              } else {
                my $length= $prng->uint16(0,64);
                $val= $prng->string($length);
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
                    $val = $prng->text($length);
                } else {
                    $val = $prng->uint16(0,5) ? $prng->text($length) : "NULL";
                }
            }
            elsif ($c->[0] eq 'INET6') {
                if ($c->[4] eq 'NOT NULL') {
                    $val = $prng->inet6();
                } else {
                    $val = $prng->uint16(0,9) == 9 ? "NULL" : $prng->inet6();
                }
            }
            elsif ($c->[0] =~ /POINT|LINESTRING|POLYGON|GEOMETRY/) {
                if ($c->[4] eq 'NOT NULL') {
                    $val = $prng->spatial($c->[0]);
                } else {
                    $val = $prng->uint16(0,9) == 9 ? "NULL" : $prng->spatial($c->[0]);
                }
            }
            push @row_values, $val;
        }
        # $rnd_int1, $rnd_int2, $rnd_date, $rnd_date, $rnd_time, $rnd_time, $rnd_datetime, $rnd_datetime, $rnd_varchar, $rnd_varchar)
        push @values, "\n(" . join(',',@row_values).")";

        ## We do one insert per 500 rows for speed
        if ($row % 500 == 0 || $row == $size) {
            $res = $executor->execute("INSERT IGNORE INTO $db.$name (" . join(",",@column_list).") VALUES" . join(",",@values));
            if ($res->status() != STATUS_OK) {
                sayError("Insert into table $db.$name didn't succeed");
                return $res->status();
            }
            @values = ();
        }
    }
    $executor->execute("COMMIT");

    return STATUS_OK;
}

1;
