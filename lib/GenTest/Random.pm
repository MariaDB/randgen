# Copyright (c) 2008,2010 Oracle and/or its affiliates. All rights reserved.
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

package GenTest::Random;

require Exporter;
@ISA = qw(GenTest);
@EXPORT = qw(
	FIELD_TYPE_NUMERIC
	FIELD_TYPE_STRING
	FIELD_TYPE_DATE
	FIELD_TYPE_TIME
	FIELD_TYPE_DATETIME
	FIELD_TYPE_TIMESTAMP
	FIELD_TYPE_ENUM
	FIELD_TYPE_SET
	FIELD_TYPE_YEAR
	FIELD_TYPE_BLOB
	FIELD_TYPE_DICT
	FIELD_TYPE_DIGIT
	FIELD_TYPE_LETTER
	FIELD_TYPE_NULL
	FIELD_TYPE_ASCII
	FIELD_TYPE_EMPTY

	FIELD_TYPE_HEX
	FIELD_TYPE_QUID
	FIELD_TYPE_JSON
);

#RV 15/9/14 - Disabled permanently as bugs reported with maxigen
#need to have this setting disabled. It also causes RQG runs more
#issues then not. This needs further research later to find the
#exact underlaying cause.
#use strict;

use Carp;
use GenTest;
use Cwd;

=pod

This module provides a clean interface to a pseudo-random number
generator.

There are quite a few of them on CPAN with various interfaces, so I
decided to create a uniform interface so that the underlying
pseudo-random function or module can be changed without affecting the
rest of the software.

The important thing to note is that several pseudo-random number
generators may be active at the same time, seeded with different
values. Therefore the underlying pseudo-random function must not rely
on perlfunc's srand() and rand() because those maintain a single
system-wide pseudo-random sequence.

This module is equipped with it's own Linear Congruential Random
Number Generator, see
http://en.wikipedia.org/wiki/Linear_congruential_generator For
efficiency, math is done in integer mode

=cut

use constant RANDOM_SEED		=> 0;
use constant RANDOM_GENERATOR		=> 1;
use constant RANDOM_VARCHAR_LENGTH	=> 2;
use constant RANDOM_STRBUF          	=> 3;

use constant FIELD_TYPE_NUMERIC		=> 2;
use constant FIELD_TYPE_STRING		=> 3;
use constant FIELD_TYPE_DATE		=> 4;
use constant FIELD_TYPE_TIME		=> 5;
use constant FIELD_TYPE_DATETIME	=> 6;
use constant FIELD_TYPE_TIMESTAMP	=> 7;
use constant FIELD_TYPE_YEAR		=> 8;

use constant FIELD_TYPE_ENUM		=> 9;
use constant FIELD_TYPE_SET		=> 10;
use constant FIELD_TYPE_BLOB		=> 11;

use constant FIELD_TYPE_DIGIT		=> 12;
use constant FIELD_TYPE_LETTER		=> 13;
use constant FIELD_TYPE_NULL		=> 14;
use constant FIELD_TYPE_DICT		=> 15;
use constant FIELD_TYPE_ASCII		=> 16;
use constant FIELD_TYPE_EMPTY		=> 17;

use constant FIELD_TYPE_HEX		=> 18;
use constant FIELD_TYPE_QUID		=> 19;

use constant FIELD_TYPE_BIT		=> 20;

use constant FIELD_TYPE_FLOAT		=> 21;

use constant FIELD_TYPE_JSON		=> 22;
use constant FIELD_TYPE_JSONPATH	=> 23;
use constant FIELD_TYPE_JSONKEY     => 24;
use constant FIELD_TYPE_JSONVALUE   => 25;
use constant FIELD_TYPE_JSONARRAY   => 26;
use constant FIELD_TYPE_JSONPAIR    => 27;
use constant FIELD_TYPE_JSONOBJECT  => 28;

use constant ASCII_RANGE_START		=> 97;
use constant ASCII_RANGE_END		=> 122;

use constant RANDOM_STRBUF_SIZE		=> 1024;

use constant JSON_STRUCT_OBJECT     => 0;
use constant JSON_STRUCT_ARRAY      => 1;

use constant JSON_VALUE_OBJECT      => 0;
use constant JSON_VALUE_ARRAY       => 1;
use constant JSON_VALUE_STRING      => 2;
use constant JSON_VALUE_NUMBER      => 3;
use constant JSON_VALUE_TRUE        => 4;
use constant JSON_VALUE_FALSE       => 5;
use constant JSON_VALUE_NULL        => 6;

use constant JSON_PATHLEG_MEMBER    => 0;
use constant JSON_PATHLEG_ARRAYLOC  => 1;
use constant JSON_PATHLEG_DBLASTER  => 2;


my %dict_exists;
my %dict_data;
my %data_dirs;

my %name2type = (
	'bit'			=> FIELD_TYPE_BIT,
	'bool'			=> FIELD_TYPE_NUMERIC,
	'boolean'		=> FIELD_TYPE_NUMERIC,
	'tinyint'		=> FIELD_TYPE_NUMERIC,
	'smallint'		=> FIELD_TYPE_NUMERIC,
	'mediumint'		=> FIELD_TYPE_NUMERIC,
	'int'			=> FIELD_TYPE_NUMERIC,
	'integer'		=> FIELD_TYPE_NUMERIC,
	'bigint'		=> FIELD_TYPE_NUMERIC,
	'float'			=> FIELD_TYPE_FLOAT,
	'double'		=> FIELD_TYPE_FLOAT,
	'double precision'	=> FIELD_TYPE_FLOAT,
	'decimal'		=> FIELD_TYPE_NUMERIC,
	'dec'			=> FIELD_TYPE_NUMERIC,
	'numeric'		=> FIELD_TYPE_NUMERIC,
	'fixed'			=> FIELD_TYPE_NUMERIC,
	'char'			=> FIELD_TYPE_STRING,
	'varchar'		=> FIELD_TYPE_STRING,
	'binary'		=> FIELD_TYPE_BLOB,
	'varbinary'		=> FIELD_TYPE_BLOB,
	'tinyblob'		=> FIELD_TYPE_BLOB,
	'blob'			=> FIELD_TYPE_BLOB,
	'mediumblob'		=> FIELD_TYPE_BLOB,
	'longblob'		=> FIELD_TYPE_BLOB,
	'tinytext'		=> FIELD_TYPE_STRING,
	'text'			=> FIELD_TYPE_STRING,
	'mediumtext'		=> FIELD_TYPE_STRING,
	'longtext'		=> FIELD_TYPE_STRING,
	'date'			=> FIELD_TYPE_DATE,
	'time'			=> FIELD_TYPE_TIME,
	'datetime'		=> FIELD_TYPE_DATETIME,
	'timestamp'		=> FIELD_TYPE_TIMESTAMP,
	'year'			=> FIELD_TYPE_YEAR,
	'enum'			=> FIELD_TYPE_ENUM,
	'set'			=> FIELD_TYPE_SET,
	'null'			=> FIELD_TYPE_NULL,
	'letter'		=> FIELD_TYPE_LETTER,
	'digit'			=> FIELD_TYPE_DIGIT,
	'data'			=> FIELD_TYPE_BLOB,
	'ascii'			=> FIELD_TYPE_ASCII,
	'string'		=> FIELD_TYPE_STRING,
	'empty'			=> FIELD_TYPE_EMPTY,

	'hex'			=> FIELD_TYPE_HEX,
	'quid'			=> FIELD_TYPE_QUID,
	'json'			=> FIELD_TYPE_JSON,
	'jsonpath'		=> FIELD_TYPE_JSONPATH,
	'jsonkey'       => FIELD_TYPE_JSONKEY,
	'jsonvalue'     => FIELD_TYPE_JSONVALUE,
	'jsonarray'     => FIELD_TYPE_JSONARRAY,
	'jsonpair'      => FIELD_TYPE_JSONPAIR,
	'jsonobject'    => FIELD_TYPE_JSONOBJECT
);

my $cwd = cwd();

# Min and max values for integer data types

my %name2range = (
	'bool'		=> [0, 1],
	'boolean'	=> [0, 1],
        'tinyint'       => [-128, 127],
        'smallint'      => [-32768, 32767],
        'mediumint'     => [-8388608, 8388607],
        'int'           => [-2147483648, 2147483647],
        'integer'       => [-2147483648, 2147483647],
        'bigint'        => [-9223372036854775808, 9223372036854775807],
        'float'         => [-9223372036854775808, 9223372036854775807],
        'double'        => [-999999999999999999999999999999999999999999999999999999999999999999999999999999999, 999999999999999999999999999999999999999999999999999999999999999999999999999999999],
        'double_nano'   => [-0.00000000000000000000000000000000000000000000000000000000000000000001, 0.00000000000000000000000000000000000000000000000000000000000000000001],

        'tinyint_unsigned'      => [0, 255],
        'tinyint_positive'      => [1, 255],
        'smallint_unsigned'     => [0, 65535],
        'smallint_positive'     => [1, 65535],
        'mediumint_unsigned'    => [0, 16777215],
        'mediumint_positive'    => [1, 16777215],
        'int_unsigned'          => [0, 4294967295],
        'int_positive'          => [1, 4294967295],
        'integer_unsigned'      => [0, 4294967295],
        'integer_positive'      => [1, 4294967295],
        'bigint_unsigned'       => [0, 18446744073709551615],
        'bigint_positive'       => [1, 18446744073709551615]
);

my $prng_class;

1;

sub new {
    my $class = shift;

	my $prng = $class->SUPER::new({
		'seed'			=> RANDOM_SEED,
		'varchar_length'	=> RANDOM_VARCHAR_LENGTH
	}, @_ );


	$prng->setSeed($prng->seed() > 0 ? $prng->seed() : 1);

#	say("Initializing PRNG with seed '".$prng->seed()."' ...");

	$prng->[RANDOM_GENERATOR] = $prng->seed();

	return $prng;
}

sub seed {
	return $_[0]->[RANDOM_SEED];
}

sub setSeed {
	$_[0]->[RANDOM_SEED] = $_[1];
	$_[0]->[RANDOM_GENERATOR] = $_[1];
}

sub update_generator {
	{
		use integer;
		$_[0]->[RANDOM_GENERATOR] =
			$_[0]->[RANDOM_GENERATOR] * 1103515245 + 12345;
	}
}

### Random unsigned integer. 16 bit on 32-bit platforms, 48 bit on
### 64-bit platforms. For internal use in Random.pm. Use int() or
### uint16() instead.
sub urand {
    use integer;
    update_generator($_[0]);
    ## The lower bits are of bad statsictical quality in an LCG, so we
    ## just use the higher bits.

    ## Unfortunetaly, >> is an arithemtic shift so we shift right 15
    ## bits and have take the absoulte value off that to get a 16-bit
    ## unsigned random value.

    my $rand = $_[0]->[RANDOM_GENERATOR] >> 15;

    ## Can't use abs() since abs() is a function that use float (SIC!)
    if ($rand < 0) {
        return -$rand;
    } else {
        return $rand;
    }
}

### Random unsigned 16-bit integer
sub uint16 {
    use integer;
    # urand() is manually inlined for efficiency
    update_generator($_[0]);
    return $_[1] +
        ((($_[0]->[RANDOM_GENERATOR] >> 15) & 0xFFFF) % ($_[2] - $_[1] + 1));
}

### Signed 64-bit integer of any range.
### Slower, so use uint16 wherever possible.
sub int {
    my $rand;
    {
        use integer;
        # urand() is manually inlined for efficiency
        update_generator($_[0]);
        # Since this may be a 64-bit platform, we mask down to 16 bit
        # to ensure the division below becomes correct.
        $rand = ($_[0]->[RANDOM_GENERATOR] >> 15) & 0xFFFF;
    }
    return int($_[1] + (($rand / 0x10000) * ($_[2] - $_[1] + 1)));
}

### Signed 64-bit float of any range.
sub float {
	my $rand;
	# urand() is manually inlined for efficiency
	update_generator($_[0]);
	# Since this may be a 64-bit platform, we mask down to 16 bit
	# to ensure the division below becomes correct.
	$rand = ($_[0]->[RANDOM_GENERATOR] >> 15) & 0xFFFF;
	return $_[1] + (($rand / 0x10000) * ($_[2] - $_[1] + 1));
}

sub digit {
	return $_[0]->uint16(0, 9);
}

sub positive_digit {
	return $_[0]->uint16(1, 9);
}

sub letter {
	return $_[0]->string(1);
}

sub hex {
	my ($prng, $length) = @_;
	$length = 4 if not defined $length;
	return '0x'.join ('', map { (0..9,'A'..'F')[$prng->int(0,15)] } (1..$prng->int(1,$length)) );
}

sub date {
	my $prng = shift;
	return sprintf('%04d-%02d-%02d',
                   $prng->uint16(1971,2035),
                   $prng->uint16(1,12),
                   $prng->uint16(1,28));
}

sub year {
	my $prng = shift;
	return $prng->uint16(1971,2035);
}

sub time {
	my $prng = shift;
	return sprintf('%02d:%02d:%02d.%06d',
                   $prng->uint16(0,23),
                   $prng->uint16(0,59),
                   $prng->uint16(0,59),
                   $prng->uint16(0,999999));
}

sub datetime {
	my $prng = shift;
	return $prng->date()." ".$prng->time();
}

sub timestamp {
	my $prng = shift;
	return sprintf('%04d%02d%02d%02d%02d%02d.%06d',
                   $prng->uint16(1971,2035),
                   $prng->uint16(1,12),
                   $prng->uint16(1,28),
                   $prng->uint16(0,23),
                   $prng->uint16(0,59),
                   $prng->uint16(0,59),
                   $prng->uint16(0,999999));
}

sub enum {
	my $prng = shift;
	return $prng->letter();
}

sub set {
	my $prng = shift;
	return join(',', map { $prng->letter() } (0..$prng->digit() ) );
}

sub string {
	use integer;

	my ($prng, $len) = @_;

	$len = defined $len ? $len : ($prng->[RANDOM_VARCHAR_LENGTH] || 1);

	# If the length is 0 or negative, return a zero-length string
	return '' if $len <= 0;

	# If the length is 1, just return one random character
        return chr($prng->uint16(ASCII_RANGE_START, ASCII_RANGE_END)) if $len == 1;

	# We store a random string of length RANDOM_STRBUF_SIZE which we fill with
	# random bytes. Each time a new string is requested, we shift the
	# string one byte right and generate a new string at the beginning
	# of the string.

	if (not defined $prng->[RANDOM_STRBUF]) {
		$prng->[RANDOM_STRBUF] = join('', map{ chr($prng->uint16(ASCII_RANGE_START, ASCII_RANGE_END)) } (1..RANDOM_STRBUF_SIZE) );
	} else {
		$prng->[RANDOM_STRBUF] = substr($prng->[RANDOM_STRBUF], 1).chr($prng->uint16(ASCII_RANGE_START, ASCII_RANGE_END));
	}

	my $actual_length = $prng->uint16(1,$len);

	if ($actual_length <= RANDOM_STRBUF_SIZE) {
		## If the wanted length fit in the buffer, just return a slice of it.
		return substr($prng->[RANDOM_STRBUF], 0, $actual_length);
	} else {
		## Otherwise wil fill repeatedly from the buffer
		my $res;
		while ($actual_length > RANDOM_STRBUF_SIZE){
			$res .= $prng->[RANDOM_STRBUF];
			$actual_length -= RANDOM_STRBUF_SIZE;
		}
		return $res.substr($prng->[RANDOM_STRBUF], $actual_length);
	}
}


#-- JSON -----------------------------
#
# _json is a JSON value in a grammar.
# For JSON, we'll use terminology from here (to some extent):
# http://www.json.org/
# "structure" is either a OBJECT '{}', or ARRAY '[]'
# "member" is what OBJECT consists of -- a PAIR string:value
# VALUE is what ARRAY consists of, and also it's the right part of PAIR:
#  a string, or a number, or an OBJECT, or an ARRAY, or 'true', or 'false', or NULL

sub json {
	# Length here will be a number of structures on the 1st + 2nd level. That is,
	# length <= 0: empty string (invalid JSON)
	# length == 1: '[]' or '{}'
	# length == 2: '["a"]' or '[{}]' or '{"a":"b"}'
	# etc.

	my ($prng, $len) = @_;

	$len = defined $len ? $len : $prng->uint16(0,64);

	# If the length is 0 or negative, return a zero-length string
	return '' if $len <= 0;

    return $prng->json_struct($len-1);
}

sub json_struct {
	my ($prng, $len) = @_;
	return (
		$prng->arrayElement([JSON_STRUCT_ARRAY, JSON_STRUCT_OBJECT]) == JSON_STRUCT_ARRAY
		? $prng->json_array($len)
		: $prng->json_object($len)
	);
}

sub json_array {
	my ($prng, $len) = @_;

	my @contents = ();
	foreach (1..$len) {
		push @contents, $prng->json_value();
	}
	return '[' . join(',', @contents) . ']';
}

sub json_object {
	my ($prng, $len) = @_;

	my @contents = ();
	foreach (1..$len) {
		push @contents, $prng->json_pair();
	}
	return '{' . join(',', @contents) . '}';
}

sub json_value {
	my $prng = shift;

	my $value_type= $prng->json_value_type();

	if ($value_type == JSON_VALUE_OBJECT) {
		return $prng->json_object($prng->uint16(0,8));
	} elsif ($value_type == JSON_VALUE_ARRAY) {
		return $prng->json_array($prng->uint16(0,16));
	} elsif ($value_type == JSON_VALUE_STRING) {
		return '"'.$prng->string($prng->uint16(0,64)).'"';
	} elsif ($value_type == JSON_VALUE_NUMBER) {
		return $prng->int();
	} elsif ($value_type == JSON_VALUE_TRUE) {
		return 'true';
	} elsif ($value_type == JSON_VALUE_FALSE) {
		return 'false';
	} elsif ($value_type == JSON_VALUE_NULL) {
		return 'NULL';
	}
}

sub json_key {
	my $prng = shift;
	my $key = $prng->fromDictionary('english');
	$key =~ s/'//g;
	return $key;
}

sub json_pair {
	my $prng = shift;
	return '"'. $prng->json_key() . '": ' . $prng->json_value();
}

sub json_value_type {
	my $prng = shift;
	return $prng->arrayElement([
		JSON_VALUE_OBJECT,
		JSON_VALUE_ARRAY,
		JSON_VALUE_STRING, JSON_VALUE_STRING, JSON_VALUE_STRING, JSON_VALUE_STRING, JSON_VALUE_STRING, JSON_VALUE_STRING,
		JSON_VALUE_STRING, JSON_VALUE_STRING, JSON_VALUE_STRING, JSON_VALUE_STRING, JSON_VALUE_STRING, JSON_VALUE_STRING,
		JSON_VALUE_NUMBER, JSON_VALUE_NUMBER, JSON_VALUE_NUMBER, JSON_VALUE_NUMBER, JSON_VALUE_NUMBER, JSON_VALUE_NUMBER,
		JSON_VALUE_NUMBER, JSON_VALUE_NUMBER, JSON_VALUE_NUMBER, JSON_VALUE_NUMBER, JSON_VALUE_NUMBER, JSON_VALUE_NUMBER,
		JSON_VALUE_TRUE, JSON_VALUE_TRUE, JSON_VALUE_TRUE, JSON_VALUE_TRUE, JSON_VALUE_TRUE, JSON_VALUE_TRUE, JSON_VALUE_TRUE,
		JSON_VALUE_FALSE, JSON_VALUE_FALSE, JSON_VALUE_FALSE, JSON_VALUE_FALSE, JSON_VALUE_FALSE, JSON_VALUE_FALSE, JSON_VALUE_FALSE,
		JSON_VALUE_NULL, JSON_VALUE_NULL, JSON_VALUE_NULL, JSON_VALUE_NULL, JSON_VALUE_NULL, JSON_VALUE_NULL, JSON_VALUE_NULL
	]);
}

# For JSON Path, we'll use syntax from here:
# https://dev.mysql.com/doc/refman/5.7/en/json-path-syntax.html

sub jsonpath {
	my $prng = shift;

	my $path= '$';
	my $num_of_legs = $prng->uint16(0,4);
	foreach (1..$num_of_legs) {
		$path .= $prng->json_pathleg();
	}
	return $path;
}

sub json_pathleg {
	my $prng = shift;
	my $pathleg_type= $prng->arrayElement([JSON_PATHLEG_ARRAYLOC, JSON_PATHLEG_DBLASTER, JSON_PATHLEG_MEMBER]);

	if ($pathleg_type == JSON_PATHLEG_DBLASTER) {
		return '**';
	} elsif ($pathleg_type == JSON_PATHLEG_ARRAYLOC) {
		my $ind= $prng->uint16(-1,8);
		return '[' . ( $ind < 0 ? '*' : $ind ) . ']';
	} else { # MEMBER
		my $key= $prng->json_key();
		# Quoted string or identifier
		$key = $prng->uint16(0,2) ? $key : '"'.$key.'"';
		return '.' . ($prng->uint16(0,3) ? $key : '*');
	}
}

#-- END OF JSON -----------------------------

sub quid {
	my $prng = shift;

	return pack("c*", map {
		$prng->uint16(65,90);
                } (1..5));
}

sub bit {
	my ($prng, $length) = @_;
	$length = 1 if not defined $length;
	return 'b\''.join ('', map { $prng->int(0,1) } (1..$prng->int(1,$length)) ).'\'';
}

#
# Return a random array element from an array reference
#

sub arrayElement {
    ## To avoid mod zero-problems in uint16 (See Bug#45857)
    return undef if $#{$_[1]} < 0;
	return $_[1]->[ $_[0]->uint16(0, $#{$_[1]}) ];
}

#
# Return a random value appropriate for this type of field
#

sub fieldType {
	my ($rand, $field_def) = @_;

	$field_def =~ s{ }{_}o;
	$field_def =~ s{^_}{}o;
	my ($field_base_type) = $field_def =~ m{^([A-Za-z]*)}o;
	my ($field_full_type) = $field_def =~ m{^([A-Za-z_]*)}o;
	my ($orig_field_length) = $field_def =~ m{\((.*?)\)}o;
	my $field_length = (defined $orig_field_length ? $orig_field_length : 1);
	my $field_type = $name2type{$field_base_type};

	if ($field_type == FIELD_TYPE_DIGIT) {
		return $rand->digit();
	} elsif ($field_type == FIELD_TYPE_LETTER) {
		return $rand->string(1);
	} elsif ($field_type == FIELD_TYPE_NUMERIC) {
		return $rand->int(@{$name2range{$field_full_type}});
	} elsif ($field_type == FIELD_TYPE_FLOAT) {
		return $rand->float(@{$name2range{$field_full_type}});
	} elsif ($field_type == FIELD_TYPE_STRING) {
		return $rand->string($field_length);
	} elsif ($field_type == FIELD_TYPE_DATE) {
		return $rand->date();
	} elsif ($field_type == FIELD_TYPE_YEAR) {
		return $rand->year();
	} elsif ($field_type == FIELD_TYPE_TIME) {
		return $rand->time();
	} elsif ($field_type == FIELD_TYPE_DATETIME) {
		return $rand->datetime();
	} elsif ($field_type == FIELD_TYPE_TIMESTAMP) {
		return $rand->timestamp();
	} elsif ($field_type == FIELD_TYPE_ENUM) {
		return $rand->enum();
	} elsif ($field_type == FIELD_TYPE_SET) {
		return $rand->set();
	} elsif ($field_type == FIELD_TYPE_BLOB) {
		return $rand->file("$cwd/data");
	} elsif ($field_type == FIELD_TYPE_NULL) {
		return undef;
	} elsif ($field_type == FIELD_TYPE_ASCII) {
		return $rand->string($field_length, [0, 255]);
	} elsif ($field_type == FIELD_TYPE_EMPTY) {
		return '';
	} elsif ($field_type == FIELD_TYPE_HEX) {
		return $rand->hex($field_length);
	} elsif ($field_type == FIELD_TYPE_QUID) {
		return $rand->quid();
	} elsif ($field_type == FIELD_TYPE_DICT) {
		return $rand->fromDictionary($field_base_type);
	} elsif ($field_type == FIELD_TYPE_BIT) {
		return $rand->bit($field_length);
	} elsif ($field_type == FIELD_TYPE_JSON) {
		return $rand->json($orig_field_length);
	} elsif ($field_type == FIELD_TYPE_JSONPATH) {
		return $rand->jsonpath();
	} elsif ($field_type == FIELD_TYPE_JSONKEY) {
		return $rand->json_key();
	} elsif ($field_type == FIELD_TYPE_JSONVALUE) {
		return $rand->json_value();
	} elsif ($field_type == FIELD_TYPE_JSONARRAY) {
		return $rand->json_array();
	} elsif ($field_type == FIELD_TYPE_JSONPAIR) {
		return $rand->json_pair();
	} elsif ($field_type == FIELD_TYPE_JSONOBJECT) {
		return $rand->json_object();
	} else {
		croak ("unknown field type $field_def");
	}
}

sub file {
	my ($prng, $dir) = @_;
	if (not exists $data_dirs{$dir}) {
		my @files = <$dir/*>;
		$data_dirs{$dir} = \@files;
	}

	return "LOAD_FILE('".$prng->arrayElement($data_dirs{$dir})."')";

}

sub isFieldType {
	my ($rand, $field_def) = @_;
	return undef if not defined $field_def;

	my ($field_name) = $field_def =~ m{^(?:_|)([A-Za-z]*)}o;

	if (exists $name2type{$field_name}) {
		return $name2type{$field_name};
	} elsif (exists $dict_exists{$field_name}) {
		return $dict_exists{$field_name};
	} else {
                my $dict_file = $ENV{RQG_HOME} ne '' ? $ENV{RQG_HOME}."/dict/$field_name.txt" : "dict/$field_name.txt";

                if (-e $dict_file) {
			$dict_exists{$field_name} = FIELD_TYPE_DICT;
			$name2type{$field_name} = FIELD_TYPE_DICT;
			return FIELD_TYPE_DICT;
		} else {
			$dict_exists{$field_name} = undef;
			return undef;
		}
	}
}

sub fromDictionary {
	my ($rand, $dict_name) = @_;

	if (not exists $dict_data{$dict_name}) {
		my $dict_file = $ENV{RQG_HOME} ne '' ? $ENV{RQG_HOME}."/dict/$dict_name.txt" : "dict/$dict_name.txt";

		open (DICT, $dict_file) or warn "# Unable to load $dict_file: $!";
		my @dict_data = map { chop; $_ } <DICT>;
		close DICT;
		$dict_data{$dict_name} = \@dict_data;
	}

	return $rand->arrayElement($dict_data{$dict_name});
}

sub shuffleArray {
	my ($rand, $array) = @_;
	my $i;
	for ($i = @$array; --$i; ) {
	        my $j = $rand->uint16(0, $i);
	        next if $i == $j;
	        @$array[$i,$j] = @$array[$j,$i];
	}
	return $array;
}

1;
