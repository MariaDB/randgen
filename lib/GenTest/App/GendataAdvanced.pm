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

sub varcharLength {
    return $_[0]->[GDS_VARCHAR_LENGTH] || 1;
}

sub run {
    my ($self) = @_;
    
    $prng = GenTest::Random->new( seed => 0 );

    my $executor = GenTest::Executor->newFromDSN($self->dsn());
    if ($executor->type != DB_MYSQL) {
        die "Only MySQL executor type is supported\n";
    }
    $executor->sqltrace($self->sqltrace);
    $executor->init();

    my $names = GDS_DEFAULT_NAMES;
    my $rows;

    if (defined $self->rows()) {
        $rows = [split(',', $self->rows())];
    } else {
        $rows = GDS_DEFAULT_ROWS;
    }

    foreach my $i (0..$#$names) {
        my $gen_table_result = $self->gen_table($executor, $names->[$i], $rows->[$i], $prng);
        return $gen_table_result if $gen_table_result != STATUS_OK;
    }

    $executor->execute("SET SQL_MODE= CONCAT(\@\@sql_mode,',NO_ENGINE_SUBSTITUTION')") if $executor->type == DB_MYSQL;
    return STATUS_OK;
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
sub random_pk_variation {
    return $prng->uint16(0,1) ? 'INTEGER AUTO_INCREMENT' : 'SERIAL';
}
sub random_or_predefined_vcol_kind {
    return ($_[0]->vcols() eq '' ? ($prng->uint16(0,1) ? 'PERSISTENT' : 'VIRTUAL') : $_[0]->vcols());
}


sub gen_table {
    my ($self, $executor, $name, $size, $prng) = @_;

    my $nullability = defined $self->[GDS_NOTNULL] ? 'NOT NULL' : '/*! NULL */';  
    ### NULL is not a valid ANSI constraint, (but NOT NULL of course,
    ### is)

    my $varchar_length = $self->varcharLength();

    my $engine = $self->engine();
    my $vcols = $self->vcols();
    my $views = $self->views();
    
    my ($nullable, $precision);
    
    # column_name => [ type, length, unsigned, zerofill, nullability, default, virtual ]

    my %columns = (
        pk      => [    random_pk_variation(),
                        undef,
                        undef,
                        undef,
                        undef,
                        undef,
                        undef
                    ],
        col_bit => [    'BIT',
                        $prng->uint16(0,64),
                        undef,
                        undef,
                        $nullable = random_null(),
                        ( $nullable eq 'NULL' ? undef : '0' ),
                        undef
                    ],
        col_int => [    random_int_type(),
                        $prng->uint16(0,64),
                        random_unsigned(),
                        random_zerofill(),
                        $nullable = random_null(),
                        ( $nullable eq 'NULL' ? undef : '0' ),
                        undef
                    ],
        col_dec => [    'DECIMAL',
                        $precision = $prng->uint16(0,65) . ',' . $prng->uint16(0,$precision),
                        random_unsigned(),
                        random_zerofill(),
                        $nullable = random_null(),
                        ( $nullable eq 'NULL' ? undef : '0' ),
                        undef
                    ],
        col_date => [   'DATE',
                        undef,
                        undef,
                        undef,
                        $nullable = random_null(),
                        ( $nullable eq 'NULL' ? undef : "'1900-01-01'" ),
                        undef
                    ],
        col_datetime => ['DATETIME',
                        $prng->uint16(0,6),
                        undef,
                        undef,
                        $nullable = random_null(),
                        ( $nullable eq 'NULL' ? undef : "'1900-01-01 00:00:00'" ),
                        undef
                    ],
        col_timestamp => ['TIMESTAMP',
                        $prng->uint16(0,6),
                        undef,
                        undef,
                        $nullable = random_null(),
                        ( $nullable eq 'NULL' ? undef : "'1971-01-01 00:00:00'" ),
                        undef
                    ],
        col_time    => ['TIME',
                        $prng->uint16(0,6),
                        undef,
                        undef,
                        $nullable = random_null(),
                        ( $nullable eq 'NULL' ? undef : "'00:00:00'" ),
                        undef
                    ],
        col_year    => ['YEAR',
                        undef,
                        undef,
                        undef,
                        $nullable = random_null(),
                        ( $nullable eq 'NULL' ? undef : "'1970'" ),
                        undef
                    ],
        col_char => [   random_char_type(),
                        $prng->uint16(0,255),
                        undef,
                        undef,
                        $nullable = random_null(),
                        ( $nullable eq 'NULL' ? undef : "''" ),
                        undef
                    ],
        col_varchar => [random_varchar_type(),
                        $prng->uint16(0,4096),
                        undef,
                        undef,
                        $nullable = random_null(),
                        ( $nullable eq 'NULL' ? undef : "''" ),
                        undef
                    ],
        col_blob => [   random_blob_type(),
                        undef,
                        undef,
                        undef,
                        $nullable = random_null(),
                        ( $nullable eq 'NULL' ? undef : "''" ),
                        undef
                    ],
        col_enum => [   random_enum_type(),
                        undef,
                        undef,
                        undef,
                        $nullable = random_null(),
                        ( $nullable eq 'NULL' ? undef : "''" ),
                        undef
                    ],
    );
    
    # TODO: add actual functions

    if (defined $vcols) {
        $columns{vcol_bit}= [   'BIT',
                                $prng->uint16(0,64),
                                undef,
                                undef,
                                undef,
                                undef,
                                'AS (col_bit) '.$self->random_or_predefined_vcol_kind()
                            ];
        $columns{vcol_int}= [   random_int_type(),
                                $prng->uint16(0,64),
                                undef,
                                random_zerofill(),
                                undef,
                                undef,
                                'AS (col_int) '.$self->random_or_predefined_vcol_kind()
                            ];
        my $precision = $prng->uint16(0,65);
        my $scale = $prng->uint16(0,($precision<=38?$precision:38));
        $columns{vcol_dec}= [   'DECIMAL',
                                "$precision,$scale",
                                undef,
                                random_zerofill(),
                                undef,
                                undef,
                                'AS (col_dec) '.$self->random_or_predefined_vcol_kind()
                            ];
        $columns{vcol_date}= [  'DATE',
                                undef,
                                undef,
                                undef,
                                undef,
                                undef,
                                'AS (col_date) '.$self->random_or_predefined_vcol_kind()
                            ];
        $columns{vcol_datetime}= ['DATETIME',
                                $prng->uint16(0,6),
                                undef,
                                undef,
                                undef,
                                undef,
                                'AS (col_datetime) '.$self->random_or_predefined_vcol_kind()
                            ];
        $columns{vcol_timestamp}= ['TIMESTAMP',
                                $prng->uint16(0,6),
                                undef,
                                undef,
                                undef,
                                undef,
                                'AS (col_timestamp) '.$self->random_or_predefined_vcol_kind()
                            ];
        $columns{vcol_time}= [  'TIME',
                                $prng->uint16(0,6),
                                undef,
                                undef,
                                undef,
                                undef,
                                'AS (col_time) '.$self->random_or_predefined_vcol_kind()
                            ];
        $columns{vcol_year}= [  'YEAR',
                                undef,
                                undef,
                                undef,
                                undef,
                                undef,
                                'AS (col_year) '.$self->random_or_predefined_vcol_kind()
                            ];
        $columns{vcol_char}= [  random_char_type(),
                                $prng->uint16(0,255),
                                undef,
                                undef,
                                undef,
                                undef,
                                'AS (col_char) '.$self->random_or_predefined_vcol_kind()
                            ];
        $columns{vcol_varchar}= [random_varchar_type(),
                                $prng->uint16(0,4096),
                                undef,
                                undef,
                                undef,
                                undef,
                                'AS (col_varchar) '.$self->random_or_predefined_vcol_kind()
                            ];
        $columns{vcol_blob}= [  random_blob_type(),
                                undef,
                                undef,
                                undef,
                                undef,
                                undef,
                                'AS (col_blob) '.$self->random_or_predefined_vcol_kind()
                            ];
        $columns{vcol_enum}= [  random_enum_type(),
                                undef,
                                undef,
                                undef,
                                undef,
                                undef,
                                'AS (col_enum) '.$self->random_or_predefined_vcol_kind()
                            ];
    }

    say("Creating ".$executor->getName()." table $name, size $size rows, engine $engine .");

    ### This variant is needed due to
    ### http://bugs.mysql.com/bug.php?id=47125

    $executor->execute("DROP TABLE /*! IF EXISTS */ $name");
    my $create_stmt = "CREATE TABLE $name ( \n";
    my @column_list = ();
    my $columns= $prng->shuffleArray([sort keys %columns]);
    foreach my $c (@$columns) {
        my $coldef= $columns{$c};
        unless ($c eq 'pk' or defined $coldef->[6]) {
            push @column_list, $c;
        }
        $create_stmt .= 
            "$c $coldef->[0]"         # type
            . ($coldef->[1] ? "($coldef->[1])" : '') # length
            . ($coldef->[2] ? " $coldef->[2]" : '')  # unsigned
            . ($coldef->[3] ? " $coldef->[3]" : '')  # zerofill
            . ($coldef->[4] ? " $coldef->[4]" : '')  # nullability
            . (defined $coldef->[5] ? " DEFAULT $coldef->[5]" : '')   # default
            . (defined $coldef->[6] ? " $coldef->[6]" : '') # virtual
            . ",\n";
    };
    $create_stmt .= "PRIMARY KEY(pk)\n";
    $create_stmt .= ")" . ($engine ne '' ? " ENGINE=$engine" : "");
    $executor->execute($create_stmt);
    
    if (defined $views) {
        if ($views ne '') {
            $executor->execute("CREATE ALGORITHM=$views VIEW view_".$name.' AS SELECT * FROM '.$name);
        } else {
            $executor->execute('CREATE VIEW view_'.$name.' AS SELECT * FROM '.$name);
        }
    }
    
    my $number_of_indexes= $prng->uint16(2,8);
    foreach (1..$number_of_indexes) {
        my $number_of_columns= $prng->uint16(1,4);
        # TODO: make it conditional depending on the version -- keys %columns vs @column_list
        my $cols= $prng->shuffleArray([keys %columns]);
        my @cols= @$cols[1..$number_of_columns];
        foreach my $i (0..$#cols) {
            my $c= $cols[$i];
            my $tp= $columns{$c}->[0];
            if ($tp eq 'TINYBLOB' or $tp eq 'TINYTEXT' or $tp eq 'BLOB' or $tp eq 'TEXT' or $tp eq 'MEDIUMBLOB' or $tp eq 'MEDIUMTEXT' or $tp eq 'LONGBLOB' or $tp eq 'LONGTEXT' or $tp eq 'CHAR' or $tp eq 'VARCHAR' or $tp eq 'BINARY' or $tp eq 'VARBINARY') {
                my $length= ( $columns{$c}->[1] and $columns{$c}->[1] < 64 ) ? $columns{$c}->[1] : 64;
                $cols[$i] = "$c($length)";
            }
        }
        $executor->execute("ALTER TABLE $name ADD " . ($prng->uint16(0,5) ? 'INDEX' : 'UNIQUE') . "(". join(',',@cols) . ")");
    }

    my @values;

    $executor->execute("START TRANSACTION");
    foreach my $row (1..$size) {
    
        my @row_values = ();
        my $val;
        
        foreach my $cname (@column_list) {
            
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
            elsif ($c->[0] eq 'CHAR' or $c->[0] eq 'VARCHAR' or $c->[0] eq 'BINARY' or $c->[0] eq 'VARBINARY' or $c->[0] eq 'TINYBLOB' or $c->[0] eq 'TINYTEXT' or $c->[0] eq 'BLOB' or $c->[0] eq 'TEXT' or $c->[0] eq 'MEDIUMBLOB' or $c->[0] eq 'MEDIUMTEXT' or $c->[0] eq 'LONGBLOB' or $c->[0] eq 'LONGTEXT') 
            {
                my $length= $prng->uint16(0,9) == 9 ? $prng->uint16(0,$c->[1]) : $prng->uint16(0,8);
                if ($c->[4] eq 'NOT NULL') {
                    $val = "'".$prng->string($length)."'";
                } else {
                    $val = $prng->uint16(0,9) == 9 ? "NULL" : "'".$prng->string($length)."'";
                }
            }
            push @row_values, $val;
        }
        # $rnd_int1, $rnd_int2, $rnd_date, $rnd_date, $rnd_time, $rnd_time, $rnd_datetime, $rnd_datetime, $rnd_varchar, $rnd_varchar)
        push @values, "\n(" . join(',',@row_values).")";

        ## We do one insert per 500 rows for speed
        if ($row % 500 == 0 || $row == $size) {
            my $insert_result = $executor->execute("
            INSERT IGNORE INTO $name (" . join(",",@column_list).") VALUES" . join(",",@values));
            return $insert_result->status() if $insert_result->status() != STATUS_OK;
            @values = ();
        }
    }
    $executor->execute("COMMIT");
    return STATUS_OK;
}

1;
