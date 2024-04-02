# Copyright (c) 2008,2010 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2021, 2024, MariaDB
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
  FIELD_TYPE_YEAR
  FIELD_TYPE_BLOB
  FIELD_TYPE_TEXT
  FIELD_TYPE_INET6
  FIELD_TYPE_DICT
  FIELD_TYPE_DIGIT
  FIELD_TYPE_LETTER
  FIELD_TYPE_ASCII
  FIELD_TYPE_EMPTY
  FIELD_TYPE_FIXED
  FIELD_TYPE_UUID

  FIELD_TYPE_HEX
  FIELD_TYPE_QUID
  FIELD_TYPE_JSON

  FIELD_TYPE_IDENTIFIER
  FIELD_TYPE_IDENTIFIER_UNQUOTED
  FIELD_TYPE_IDENTIFIER_QUOTED

);

#RV 15/9/14 - Disabled permanently as bugs reported with maxigen
#need to have this setting disabled. It also causes RQG runs more
#issues then not. This needs further research later to find the
#exact underlaying cause.
#use strict;

use Carp;
use GenUtil;
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

use constant RANDOM_SEED    => 0;
use constant RANDOM_GENERATOR    => 1;
use constant RANDOM_STRBUF            => 2;
use constant RANDOM_COMPATIBILITY => 3;

use constant FIELD_TYPE_NUMERIC    => 2;
use constant FIELD_TYPE_STRING    => 3;
use constant FIELD_TYPE_DATE    => 4;
use constant FIELD_TYPE_TIME    => 5;
use constant FIELD_TYPE_DATETIME  => 6;
use constant FIELD_TYPE_TIMESTAMP  => 7;
use constant FIELD_TYPE_YEAR    => 8;

use constant FIELD_TYPE_BLOB    => 11;

use constant FIELD_TYPE_DIGIT    => 12;
use constant FIELD_TYPE_LETTER    => 13;
use constant FIELD_TYPE_DICT    => 15;
use constant FIELD_TYPE_ASCII    => 16;
use constant FIELD_TYPE_EMPTY    => 17;

use constant FIELD_TYPE_HEX    => 18;
use constant FIELD_TYPE_QUID    => 19;

use constant FIELD_TYPE_BIT    => 20;

use constant FIELD_TYPE_FLOAT    => 21;

use constant FIELD_TYPE_JSON    => 22;
use constant FIELD_TYPE_JSONPATH  => 23;
use constant FIELD_TYPE_JSONKEY     => 24;

use constant FIELD_TYPE_TEXT  => 29;
use constant FIELD_TYPE_INET6  => 30;

use constant FIELD_TYPE_JSONPATH_NO_WILDCARD  => 31;

use constant FIELD_TYPE_IDENTIFIER          => 32;
use constant FIELD_TYPE_IDENTIFIER_UNQUOTED => 33;
use constant FIELD_TYPE_IDENTIFIER_QUOTED   => 34;
use constant FIELD_TYPE_FIXED => 36;

use constant FIELD_TYPE_UUID  => 37;

use constant ASCII_RANGE_START    => 97;
use constant ASCII_RANGE_END    => 122;

use constant RANDOM_STRBUF_SIZE    => 1024;

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
  'bit'      => FIELD_TYPE_BIT,
  'bool'      => FIELD_TYPE_NUMERIC,
  'boolean'    => FIELD_TYPE_NUMERIC,
  'tinyint'    => FIELD_TYPE_NUMERIC,
  'smallint'    => FIELD_TYPE_NUMERIC,
  'mediumint'    => FIELD_TYPE_NUMERIC,
  'int'      => FIELD_TYPE_NUMERIC,
  'integer'    => FIELD_TYPE_NUMERIC,
  'bigint'    => FIELD_TYPE_NUMERIC,
  'float'      => FIELD_TYPE_FLOAT,
  'double'    => FIELD_TYPE_FLOAT,
  'double precision'  => FIELD_TYPE_FLOAT,
  'decimal'    => FIELD_TYPE_FIXED,
  'dec'      => FIELD_TYPE_FIXED,
  'numeric'    => FIELD_TYPE_FIXED,
  'fixed'      => FIELD_TYPE_FIXED,
  'char'      => FIELD_TYPE_STRING,
  'varchar'    => FIELD_TYPE_STRING,
  'binary'    => FIELD_TYPE_BLOB,
  'varbinary'    => FIELD_TYPE_BLOB,
  'tinyblob'    => FIELD_TYPE_BLOB,
  'blob'      => FIELD_TYPE_BLOB,
  'mediumblob'    => FIELD_TYPE_BLOB,
  'longblob'    => FIELD_TYPE_BLOB,
  'tinytext'    => FIELD_TYPE_TEXT,
  'text'      => FIELD_TYPE_TEXT,
  'mediumtext'    => FIELD_TYPE_TEXT,
  'longtext'    => FIELD_TYPE_TEXT,
  'date'      => FIELD_TYPE_DATE,
  'time'      => FIELD_TYPE_TIME,
  'datetime'    => FIELD_TYPE_DATETIME,
  'timestamp'    => FIELD_TYPE_TIMESTAMP,
  'year'      => FIELD_TYPE_YEAR,
#  'enum'      => FIELD_TYPE_ENUM,
#  'set'      => FIELD_TYPE_SET,
    'inet6'         => FIELD_TYPE_INET6,
    'uuid'         => FIELD_TYPE_UUID,
  'letter'    => FIELD_TYPE_LETTER,
  'digit'      => FIELD_TYPE_DIGIT,
  'data'      => FIELD_TYPE_BLOB,
  'ascii'      => FIELD_TYPE_ASCII,
  'string'    => FIELD_TYPE_STRING,
  'empty'      => FIELD_TYPE_EMPTY,

  'hex'      => FIELD_TYPE_HEX,
  'quid'      => FIELD_TYPE_QUID,
  'json'      => FIELD_TYPE_JSON,
  'jsonpath'    => FIELD_TYPE_JSONPATH,
  'jsonkey'       => FIELD_TYPE_JSONKEY,
  'jsonpath_no_wildcard'    => FIELD_TYPE_JSONPATH_NO_WILDCARD,

  'identifier'    => FIELD_TYPE_IDENTIFIER,
  'identifierUnquoted'    => FIELD_TYPE_IDENTIFIER_UNQUOTED,
  'identifierQuoted'      => FIELD_TYPE_IDENTIFIER_QUOTED,
  'name'          => FIELD_TYPE_IDENTIFIER,
  'name_unquoted' => FIELD_TYPE_IDENTIFIER_UNQUOTED,
  'name_quoted'   => FIELD_TYPE_IDENTIFIER_QUOTED,
);

my $cwd = cwd();
my $data_location= "$cwd/data/blobs";
my @json_files= glob("$data_location/*.json");
my @dictionaries= qw(chinese croatian english german hebrew japanese thai vietnamese states);

# Min and max values for integer data types

my %name2range = (
  'bool'    => [0, 1],
  'boolean'  => [0, 1],
        'tinyint'       => [-128, 127],
        'smallint'      => [-32768, 32767],
        'mediumint'     => [-8388608, 8388607],
        'int'           => [-2147483648, 2147483647],
        'integer'       => [-2147483648, 2147483647],
        'int_signed'    => [-2147483648, 2147483647],
        'integer_signed' => [-2147483648, 2147483647],
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

# Don't use $ for now, it confuses RQG
#my @id_chars= qw($ _ A B C D E F G H I J K L M N O P Q R S T U V W Z Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9);
my @id_chars= qw(_ A B C D E F G H I J K L M N O P Q R S T U V W Z Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9);

my $prng_class;

1;

sub new {
    my $class = shift;

  my $prng = $class->SUPER::new({
    'seed'      => RANDOM_SEED,
    'compatibility' => RANDOM_COMPATIBILITY,
  }, @_ );


  $prng->setSeed($prng->seed() ? $prng->seed() : 1);

#  say("Initializing PRNG with seed '".$prng->seed()."' ...");

  $prng->[RANDOM_GENERATOR] = $prng->seed();
  $prng->[RANDOM_COMPATIBILITY] = $prng->compatibility() || '999999';

  return $prng;
}

sub seed {
  return $_[0]->[RANDOM_SEED];
}

sub compatibility {
  return $_[0]->[RANDOM_COMPATIBILITY];
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
    if (not defined $_[2]) {
      sayError("Second parameter not defined in uint16");
    }
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
    if (not defined $_[2]) {
      sayError("Second parameter not defined in int");
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

### Decimal/numeric value of any allowed length
sub fixed_unsigned {
  my ($prng, $m, $d)= @_;
  unless (defined $m) {
    $d= $prng->uint16(0,38);
    $m= $prng->uint16($d,65);
  }
  my $res1= $prng->int(0,10**($m-$d));
  my $res2= defined $d ? $res.= '.'.$prng->int(0,10**$d) : '';
  return sprintf("%.10g",$res1.'.'.$res2);
}

sub fixed {
  my ($prng, $m, $d)= @_;
  my $res= $prng->fixed_unsigned($m, $d);
  return ($prng->uint16(0,2) ? $res : '-'.$res);
}

sub digit {
  return $_[0]->uint16(0, 9);
}

sub positive_digit {
  return $_[0]->uint16(1, 9);
}

sub letter {
  return $_[0]->unquotedString(1);
}

sub hex {
  my ($prng, $length) = @_;
  $length = 4 if not defined $length;
  return '0x'.join ('', map { (0..9,'A'..'F')[$prng->int(0,15)] } (1..$prng->int(1,$length)) );
}

sub inet6 {
    my $prng = shift;
    my $num_parts= $prng->uint16(1,8);
    my @parts= ($num_parts == 8 ? () : (':'));
    foreach (1..(8-scalar(@parts))) {
        push @parts, join ('', map { (0..9,'a'..'f')[$prng->int(0,15)] } (1..$prng->int(1,4)));
    }
    my $res= join ':', @{$prng->shuffleArray(\@parts)};
    $res=~ s/:::/::/;
    return "'$res'";
}

sub uuid {
    my $prng = shift;
    return "'" . join ('', map { (0..9,'A'..'F')[$prng->int(0,15)] } (1..32) ) . "'";
}

sub spatial {
    my $prng= shift;
    my $tp= shift || $prng->geometryType();
    if ($tp eq 'GEOMETRY') {
        $tp= $prng->arrayElement(['POINT','LINESTRING','POLYGON','MULTIPOINT','MULTILINESTRING','MULTIPOLYGON','GEOMETRYCOLLECTION']);
    }
    return $tp."FromText('".$prng->spatial_text_value($tp)."')";
}

sub spatial_text_value {
    my ($prng, $tp)= @_;
    my $text= '';
    if ($tp eq 'GEOMETRYCOLLECTION') {
        my @geoms= ();
        my $size= $prng->uint16(1,10);
        foreach (1..$size) {
            my $tp2= $prng->arrayElement(['POINT','LINESTRING','POLYGON','MULTIPOINT','MULTILINESTRING','MULTIPOLYGON']);
            push @geoms, $prng->spatial_text_value($tp2);
            return 'GEOMETRYCOLLECTION('.(join ',', @geoms).')';
        }
    } else {
        if ($tp eq 'POINT') {
            return 'POINT('.$prng->spatial_xy().')';
        } elsif ($tp eq 'LINESTRING' or $tp eq 'POLYGON' or $tp eq 'MULTIPOINT') {
            my $point_num= $prng->uint16(1,8);
            my @points= ();
            foreach (1..$point_num) {
              push @points, $prng->spatial_xy();
            }
            if ($tp eq 'POLYGON') {
              push @points, $points[0];
              return $tp.'(('.(join ',', @points).'))';
            } else {
                return $tp.'('.(join ',', @points).')';
            }
        } elsif ($tp eq 'MULTILINESTRING' or $tp eq 'MULTIPOLYGON' ) {
            $part_num= $prng->uint16(1,6);
            my @parts= ();
            foreach (1..$part_num) {
                my $point_num= $prng->uint16(1,8);
                my @points= ();
                foreach (1..$point_num) {
                    push @points, $prng->spatial_xy();
                }
                if ($tp eq 'MULTIPOLYGON') {
                    push @points, $points[0];
                    push @parts, '(('.(join ',', @points).'))';
                } else {
                    push @parts, '('.(join ',', @points).')';
                }
            }
            return $tp.'('.(join ',', @parts).')';
        }
        return 'NULL';
    }
}

sub spatial_xy {
    my $prng= shift;
    return sprintf("%.2f %.2f",$prng->float(),$prng->float());
}

sub unquotedDate {
    my ($prng, $ts) = @_;
    # Something between 1960-01-01 and 2040-01-01 should be enough
    $ts= $prng->int(-2208994789,2208981600) if not defined $ts;
    my (undef,undef,undef,$mday,$mon,$year,undef,undef,undef)= localtime($ts);
    my $d= sprintf('%04d-%02d-%02d',$year+1900,$mon+1,$mday);
    return $d;
}

sub date {
    my ($prng, $ts) = @_;
    return "'".$prng->unquotedDate($ts)."'";
}

sub year {
  my $prng = shift;
  return $prng->uint16(1971,2035);
}

sub unquotedTime {
  my ($prng, $ts) = @_;
    if (defined $ts) {
        my ($sec,$min,$hour,undef,undef,undef,undef,undef,undef)= localtime($ts);
        return sprintf('%02d:%02d:%02d',$hour,$min,$sec);
    } else {
        return sprintf('%02d:%02d:%02d.%06d',
                   $prng->uint16(0,23),
                   $prng->uint16(0,59),
                   $prng->uint16(0,59),
                   $prng->uint16(0,999999));
    }
}

sub time {
  my ($prng, $ts) = @_;
  return "'".$prng->unquotedTime($ts)."'";
}

sub datetime {
  my ($prng, $ts) = @_;
  return "'".$prng->unquotedDate($ts)." ".$prng->unquotedTime($ts)."'";
}

sub timestamp {
    my ($prng, $ts) = @_;
    $ts= $prng->int(0,isCompatible('11.5.0',$prng->compatibility()) ? 4294967295 : 2147483647) if not defined $ts;
    my ($sec,$min,$hour,$mday,$mon,$year,undef,undef,undef)= localtime($ts);
    return sprintf('%04d%02d%02d%02d%02d%02d.%06d',$year+1900,$mon+1,$mday,$hour,$min,$sec,$prng->uint16(0,999999));
}

#sub enum {
#  my $prng = shift;
#  return $prng->letter();
#}
#
#sub set {
#  my $prng = shift;
#  return join(',', map { $prng->letter() } (0..$prng->digit() ) );
#}

sub text {
  my ($prng, $len)= @_;
  # If length is not defined, stick with the shortest text length
  $len= 255 unless defined $len;
  my $str= '';
  if ($len > 255) {
    my $f= $prng->file();
    my $fsize= (-s $f);
    my $tsize= $fsize;
    my $repeat= 1;
    while ($tsize < $len) {
      $repeat++;
      $tsize+= $fsize;
    }
    $str= ($repeat == 1 ? "LOAD_FILE('$f')" : "REPEAT(LOAD_FILE('$f'),$repeat)");
    if ($tsize > $len) {
      my $pos= $prng->int(1,$tsize-$len+1);
      $str= "SUBSTR($str,$pos,$len)";
    }
  } else {
    my $dict= $prng->arrayElement(\@dictionaries);
    while (my $remainder= $len - length($str)) {
      my $word= $prng->dictionaryWord($dict);
      if (length($word) < $remainder) {
        $str .= "$word ";
      }
      else {
        chop $str if $str;
        last;
      }
    }
    $str= "'".$str."'";
  }
  return $str;
}

sub unquotedString {
  use integer;

  my ($prng, $len) = @_;

  $len = defined $len ? $len : 1;
  my $str;

  # If the length is 0 or negative, return a zero-length string
  if ($len <= 0) {
    $str= '';
  } elsif ($len == 1) {
    $str= chr($prng->uint16(ASCII_RANGE_START, ASCII_RANGE_END));
  } else {
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
      $str= substr($prng->[RANDOM_STRBUF], 0, $actual_length);
    } else {
      ## Otherwise wil fill repeatedly from the buffer
      my $res;
      while ($actual_length > RANDOM_STRBUF_SIZE){
        $res .= $prng->[RANDOM_STRBUF];
        $actual_length -= RANDOM_STRBUF_SIZE;
      }
      $str= $res.substr($prng->[RANDOM_STRBUF], $actual_length);
    }
  }
  return $str;
}

sub string {
  my ($prng, $len) = @_;
  my $str= $prng->unquotedString($len);
  if (index($str,"'") == -1) {
    return "'".$str."'";
  } elsif (index($str,'"') == -1) {
    return '"'.$str.'"';
  } else {
    $str=~ s/(['"])/\\$1/g;
    return "'".$str."'";
  }
}


#-- JSON -----------------------------
#
# _json is a JSON value in a grammar.
# For JSON, we'll use terminology from here (to some extent):
# http://www.json.org/
# "structure" is either a OBJECT '{}', or ARRAY '[]'
# "value" is what ARRAY consists of, and also it's the right part of PAIR:
#    string, or number, or OBJECT, or ARRAY, or 'true', or 'false', or 'null'

sub json {
  my ($prng, $len) = @_;

  # IMPORTANT:
  # Length here is a number of structures on the 1st level,
  # not the length of the resulting string as one could think
  # That is,
  # length < 0: empty string or NULL (invalid JSON)
  # length == 0: '[]' or '{}'
  # length == 1: '["a"]' or '[{}]' or '{"a":"b"}' or '{"a":[1,2,3,4]}'
  # length == 2: '["a","b"]' or '{"a":"b","c":"d"}' or ...
  # etc.

  if (defined $len and $len < 0) {
    # If the length is negative, return an empty string
    # (assuming it was requested intentionally, as it's an invalid value)
    return ($prng->uint16(0,1) ? "''" : 'NULL');
  } elsif (defined $len) {
    return $prng->json_doc($len);
  } else {
    # If length isn't defined, we will either use a random value
    # or load a JSON file
    if (scalar(@json_files) and $prng->uint16(0,2)) {
      my $f= $prng->arrayElement(\@json_files);
      # TODO: randomize charset? or leave it to the grammar /variator
#      return "CONVERT(LOAD_FILE('$f') USING utf8)";
      return "LOAD_FILE('$f')";
    } else {
      $len = $prng->uint16(0,64);
      return $prng->json_doc($len);
    }
  }
}

sub json_doc {
  my ($prng, $len) = @_;
  return "'". (
    $prng->arrayElement([JSON_STRUCT_ARRAY, JSON_STRUCT_OBJECT]) == JSON_STRUCT_ARRAY
    ? $prng->jsonArray($len)
    : $prng->jsonObject($len)
  ) ."'";
}

# [ <[value [, value ...]]> ]
sub jsonArray {
  my ($prng, $len) = @_;
  $len= $prng->uint16(0,8) unless defined $len;

  my @contents = ();
  foreach (1..$len) {
    push @contents, $prng->jsonValue();
  }
  return '[' . join(',', @contents) . ']';
}

# { <[string : value [, string : value ... ]]> }
sub jsonObject {
  my ($prng, $len) = @_;
  $len= $prng->uint16(0,8) unless defined $len;

  my @contents = ();
  foreach (1..$len) {
    push @contents, $prng->jsonPair();
  }
  return '{' . join(',', @contents) . '}';
}

sub jsonValue {
  my $prng = shift;

  my $value_type= $prng->jsonValueType();

  if ($value_type == JSON_VALUE_OBJECT) {
    return $prng->jsonObject($prng->uint16(0,8));
  } elsif ($value_type == JSON_VALUE_ARRAY) {
    return $prng->jsonArray($prng->uint16(0,16));
  } elsif ($value_type == JSON_VALUE_STRING) {
    return $prng->jsonString();
  } elsif ($value_type == JSON_VALUE_NUMBER) {
    return $prng->urand();
  } elsif ($value_type == JSON_VALUE_TRUE) {
    return 'true';
  } elsif ($value_type == JSON_VALUE_FALSE) {
    return 'false';
  } elsif ($value_type == JSON_VALUE_NULL) {
    return 'null';
  }
}

sub jsonString {
  my ($prng, $len)= @_;
  $len= $prng->uint16(0,64) unless defined $len;
  return '"'.$prng->unquotedString($len).'"';
}

sub jsonKey {
  my $prng = shift;
  return $prng->jsonString();
}

sub jsonPair {
  my $prng = shift;
  return $prng->jsonString() . ': ' . $prng->jsonValue();
}

sub jsonValueType {
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

sub jsonPath {
  my $prng = shift;
  my $num_of_legs = shift || $prng->uint16(0,4);
  my $path= '$';
  foreach (1..$num_of_legs) {
    # Attach optional wildcard to the _previous_ element
    $path .= '**' if ($prng->uint16(0,1)) and $path !~ /\*$/;
    $path .= $prng->jsonPathLeg($prng->arrayElement([JSON_PATHLEG_ARRAYLOC, JSON_PATHLEG_MEMBER]),1);
  }
  return "'".$path."'";
}

# Some functions don't accept wild cards in JSON path
sub jsonPathNoWildcard {
  my $prng = shift;
  my $num_of_legs = shift || $prng->uint16(0,4);
  my $path= '$';
  foreach (1..$num_of_legs) {
    # Attach optional wildcard to the _previous_ element
    $path .= $prng->jsonPathLeg($prng->arrayElement([JSON_PATHLEG_ARRAYLOC, JSON_PATHLEG_MEMBER]));
  }
  return "'".$path."'";
}

sub jsonPathLeg {
  my $prng = shift;
  my $pathleg_type= shift;
  my $wildcards_allowed= shift;

  if ($pathleg_type == JSON_PATHLEG_DBLASTER and $wildcards_allowed) {
    return '.**';
  } elsif ($pathleg_type == JSON_PATHLEG_ARRAYLOC) {
    my $ind= $wildcards_allowed ? $prng->uint16(-1,8) : $prng->uint16(0,8);
    return '[' . ( $ind < 0 ? '*' : $ind ) . ']';
  } else { # MEMBER
    my $key= $prng->jsonKey();
    # Quoted string or identifier
    return '.' . ((! $wildcards_allowed or $prng->uint16(0,3)) ? $key : '*');
  }
}

#JSON_TABLE(
#    expr,
#    path COLUMNS (column_list)
#)   [AS] alias
#
#column_list:
#    column[, column][, ...]
#
#column:
#    name FOR ORDINALITY
#    |  name type PATH string path [on_empty] [on_error]
#    |  name type EXISTS PATH string path
#    |  NESTED [PATH] path COLUMNS (column_list)
#
#on_empty:
#    {NULL | DEFAULT json_string | ERROR} ON EMPTY
#
#on_error:
#    {NULL | DEFAULT json_string | ERROR} ON ERROR

sub jsonTable {
  my $prng= shift;
  my $number_of_columns= shift;
  my $alias= shift || $prng->letter();
  my $json_table= 'JSON_TABLE(';
  # TODO: add other variants of expr: JSON function, variable
  # CONVERT needed for MySQL
  $json_table.= $prng->json();
  $json_table.= ', ';
  $json_table.= $prng->jsonPath();
  $json_table.= ' '.$prng->jsonTableColumnList($number_of_columns).') AS '.$alias;
  return $json_table;
}

sub jsonOnEmptyOnError {
  my $prng= shift;
  my $r= $prng->uint16(1,3);
  if ($r == 1) {
    return ' NULL';
  } elsif ($r == 2) {
    return ' ERROR';
  } else {
    return ' DEFAULT '.$prng->jsonString();
  }
}

sub jsonTableColumnList {
  my $prng= shift;
  # TODO: maybe more columns
  my $colnum= shift || $prng->uint16(1,10);
  my $start_col= shift || 1;

  my @cols= ();
  my $c= $start_col;
  while ($c < $colnum + $start_col) {
    my $coltype= $prng->uint16(1,100);
    # 15% ORDINALITY
    # 40% PATH
    # 40% EXISTS
    # 5% NESTED
    my $col= '';
    if ($coltype <= 15) {
      $col= 'col'.($c++).' FOR ORDINALITY';
    } elsif ($coltype <= 55) {
      # TODO: make it any type
      $col= 'col'.($c++).' '.$prng->dataType().' PATH '.$prng->jsonPath();
      $col.= ($prng->uint16(0,1) ? $prng->jsonOnEmptyOnError().' ON EMPTY' : '');
      $col.= ($prng->uint16(0,1) ? $prng->jsonOnEmptyOnError().' ON ERROR' : '');
    } elsif ($coltype <= 95) {
      # TODO: make it any type, preferably int-like
      $col= 'col'.($c++).' '.$prng->dataType().' EXISTS PATH '.$prng->jsonPath();
    } elsif ($c < $colnum) {
      my $nested_colnum= $prng->uint16(1,$colnum-$c);
      $col= 'NESTED PATH '.$prng->jsonPath().' '.$prng->jsonTableColumnList($nested_colnum, $c);
      $c+= $nested_colnum;
    } else {
      redo;
    }
    push @cols, $col;
  }
  return 'COLUMNS ('.(join ', ', @cols).')';
}

#-- END OF JSON -----------------------------

sub quid {
  my $prng = shift;

  return "'". pack("c*", map {
    $prng->uint16(65,90);
                } (1..5)) ."'";
}

sub bit {
  my ($prng, $length) = @_;
  $length = 1 if not defined $length;
  return 'b\''.join ('', map { $prng->int(0,1) } (1..$prng->int(1,$length)) ).'\'';
}

sub identifier {
    return $_[0]->uint16(0,2) ? $_[0]->identifierUnquoted() : $_[0]->identifierQuoted();
}

### Unquoted identifier
sub identifierUnquoted {
    my $length= ( $_[0]->uint16(0,20) ? $_[0]->uint16(1,8) : $_[0]->uint16(1,64) );
    my @val= ();
    for (my $i=0; $i<$length; $i++) {
        my $c= $id_chars[$_[0]->uint16(0,$#id_chars)];
        push @val, $c;
    }
    # Unquoted identifier cannot consist only of digits
    my $res= join '', @val;
    if ($res =~ /^\d+$/) {
        my $i= $_[0]->uint16(0,length($res)-1);
        $res= substr($res,0,$i-1).$id_chars[$_[0]->uint16(0,53)].substr($res,$i+1);
    } elsif ($res =~ s/^(\d+e)\d/${1}e/i) {
      # Misinterpreted as a float value
    }
    return $res;
}

sub identifierQuoted {
    return '`'.($_[0]->identifierUnquoted()).'`';
}

#
# Return a random array element from an array reference
#

sub arrayElement {
    ## To avoid mod zero-problems in uint16 (See Bug#45857)
  return undef if $#{$_[1]} < 0;
  return $_[1]->[ $_[0]->uint16(0, $#{$_[1]}) ];
}

sub anyvalue {
  my ($rand, $maxlen)= @_;
  my @field_types= sort keys %name2type;
  return $rand->fieldType($rand->arrayElement(\@field_types).(defined $maxlen ? "($maxlen)":''));
}

#
# Return a random value appropriate for this type of field
#

sub fieldType {
  my ($rand, $field_def) = @_;

  $field_def =~ s{ }{_}o;
  $field_def =~ s{^_}{}o;
  my ($field_base_type) = $field_def =~ m{^([A-Za-z0-9]*)}o;
  my ($field_full_type) = $field_def =~ m{^([A-Za-z_]*)}o;
  my ($orig_field_length) = $field_def =~ m{\((.*?)\)}o;
  my $field_length = (defined $orig_field_length ? $orig_field_length : 1);
  my $field_type = $name2type{$field_full_type} || $name2type{$field_base_type};

  if ($field_type == FIELD_TYPE_DIGIT) {
    return $rand->digit();
  } elsif ($field_type == FIELD_TYPE_LETTER) {
    return $rand->unquotedString(1);
  } elsif ($field_type == FIELD_TYPE_NUMERIC) {
    return $rand->int(@{$name2range{$field_full_type}});
  } elsif ($field_type == FIELD_TYPE_FIXED) {
    return $rand->fixed();
  } elsif ($field_type == FIELD_TYPE_FLOAT) {
    return $rand->float(@{$name2range{$field_full_type}});
  } elsif ($field_type == FIELD_TYPE_STRING) {
    return $rand->string($field_length);
  } elsif ($field_type == FIELD_TYPE_TEXT) {
    return $rand->text($field_length);
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
#  } elsif ($field_type == FIELD_TYPE_ENUM) {
#    return $rand->enum();
#  } elsif ($field_type == FIELD_TYPE_SET) {
#    return $rand->set();
  } elsif ($field_type == FIELD_TYPE_INET6) {
    return $rand->inet6();
  } elsif ($field_type == FIELD_TYPE_UUID) {
    return $rand->uuid();
  } elsif ($field_type == FIELD_TYPE_BLOB) {
    return $rand->loadFile($data_location);
  } elsif ($field_type == FIELD_TYPE_ASCII) {
    return $rand->string($field_length, [0, 255]);
  } elsif ($field_type == FIELD_TYPE_EMPTY) {
    return "''";
  } elsif ($field_type == FIELD_TYPE_HEX) {
    return $rand->hex($field_length);
  } elsif ($field_type == FIELD_TYPE_QUID) {
    return $rand->quid();
  } elsif ($field_type == FIELD_TYPE_DICT) {
    return $rand->word($field_base_type);
  } elsif ($field_type == FIELD_TYPE_BIT) {
    return $rand->bit($field_length);
  } elsif ($field_type == FIELD_TYPE_JSON) {
    return $rand->json($orig_field_length);
  } elsif ($field_type == FIELD_TYPE_JSONPATH) {
    return $rand->jsonPath($field_length);
  } elsif ($field_type == FIELD_TYPE_JSONPATH_NO_WILDCARD) {
    return $rand->jsonPathNoWildcard($field_length);
  } elsif ($field_type == FIELD_TYPE_JSONKEY) {
    return $rand->jsonKey();
  } elsif ($field_type == FIELD_TYPE_IDENTIFIER) {
    return $rand->identifier();
  } elsif ($field_type == FIELD_TYPE_IDENTIFIER_QUOTED) {
    return $rand->identifierQuoted();
  } elsif ($field_type == FIELD_TYPE_IDENTIFIER_UNQUOTED) {
    return $rand->identifierUnquoted();
  } elsif ($field_type == FIELD_TYPE_DATATYPE) {
    return $rand->dataType($field_length);
  } else {
    croak ("unknown field type $field_def");
  }
}

sub file {
  my ($prng, $dir) = @_;
  $dir = $data_location unless $dir;
  if (not exists $data_dirs{$dir}) {
    my @files = <$dir/*>;
    $data_dirs{$dir} = \@files;
  }
  return $prng->arrayElement($data_dirs{$dir});
}

sub loadFile {
  my ($prng, $dir) = @_;
  $dir= $data_location unless $dir;
  return "LOAD_FILE('".$prng->file($dir)."')";

}

sub dataLocation {
  return "'".$data_location."'";
}

sub isFieldType {
  my ($rand, $field_def) = @_;
  return undef if not defined $field_def;

  my ($field_name) = $field_def =~ m{^(?:_|)([A-Za-z0-9]*)}o;

  if (exists $name2type{$field_name}) {
    return $name2type{$field_name};
  } elsif (exists $dict_exists{$field_name}) {
    return $dict_exists{$field_name};
  } else {
                my $dict_file = $ENV{RQG_HOME} ne '' ? $ENV{RQG_HOME}."/data/dict/$field_name.txt" : "data/dict/$field_name.txt";

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

sub loadDictionary {
  my $dict_name = shift;

  if (not exists $dict_data{$dict_name}) {
    my $dict_file = $ENV{RQG_HOME} ne '' ? $ENV{RQG_HOME}."/data/dict/$dict_name.txt" : "data/dict/$dict_name.txt";

    open (DICT, $dict_file) or warn "# Unable to load $dict_file: $!";
    my @dict_data = map { chop; $_ } <DICT>;
    close DICT;
    foreach my $i (0..$#dict_data) {
      $dict_data[$i] =~ s/[^\\](['"])/\\$1/g;
    }
    $dict_data{$dict_name} = \@dict_data;
  }
  return $dict_data{$dict_name};
}

sub dictionaryWord {
  my ($rand, $dict_name) = @_;
  return $rand->arrayElement(loadDictionary($dict_name));
}

sub word {
  my ($rand, $dict_name) = @_;
  $dict_name||= $rand->arrayElement(\@dictionaries);
  return "'".$rand->dictionaryWord($dict_name)."'";
}

sub shuffleArray {
  my ($rand, $array) = @_;
  my $i;
  return $array unless $array && scalar(@$array);
  for ($i = @$array; --$i; ) {
          my $j = $rand->uint16(0, $i);
          next if $i == $j;
          @$array[$i,$j] = @$array[$j,$i];
  }
  return $array;
}

#######################
# Data types
#
# TINYINT SMALLINT MEDIUMINT INT INTEGER BIGINT INT1 INT2 INT3 INT4 INT8
# DECIMAL DEC NUMERIC FIXED
# BOOLEAN BOOL
# FLOAT DOUBLE -DOUBLE PRECISION-
# BIT
# CHAR VARCHAR BINARY -CHAR BYTE- VARBINARY
# TINYBLOB BLOB MEDIUMBLOB LONGBLOB
# TINYTEXT TEXT MEDIUMTEXT LONGTEXT
# JSON
# INET6
# UUID
# ENUM SET
# DATE TIME DATETIME TIMESTAMP YEAR
# POINT LINESTRING POLYGON MULTIPOINT MULTILINESTRING MULTIPOLYGON GEOMETRYCOLLECTION GEOMETRY

sub dataType {
  my $prng= shift;
  # By priority, asc
  my $metatypes = [
    \&jsonType,
#    \&geometryType,
#    \&inet6Type,
#    \&uuidType,
    \&bitType,
    \&boolType,
#    \&enumSetType,
    \&floatType,
    \&blobType,
    \&decimalType,
    \&temporalType,
    \&varcharType,
    \&charType,
    \&intType,
  ];
  my $f= $metatypes->[int(sqrt($prng->uint16(0,scalar(@$metatypes)**2-1)))];
  return $prng->${f};
}

sub geometryType {
  my $prng= shift;
  my $geo_types= [
    'POINT',
    'LINESTRING',
    'POLYGON',
    'MULTIPOINT',
    'MULTILINESTRING',
    'MULTIPOLYGON',
    'GEOMETRYCOLLECTION',
    'GEOMETRY',
  ];
  return $prng->arrayElement($geo_types);
}

sub temporalType {
  my $prng= shift;
  my $temp_types= [
    'DATE',
    'TIME',
    'DATETIME',
    'TIMESTAMP',
    'YEAR',
  ];
  my $type= $prng->arrayElement($temp_types);
  if ($type ne 'DATE' and $type ne 'YEAR' and $prng->uint16(0,1)) {
    my $ms= ($prng->uint16(0,1) ? 6 : $prng->uint16(0,6));
    $type.= '('.$ms.')';
  } elsif ($type eq 'YEAR' and not $prng->uint16(0,9)) {
    $type.= '(4)';
  }
  return $type;
}

sub enumSetTypeValues {
  my ($prng, $length)= @_;
  $length= $prng->uint16(2,16) unless defined $length;
  my $vals= loadDictionary(($length <= 50 ? 'states' : 'towns'));
  $prng->shuffleArray($vals);
  my $value_list= join ', ', map {"'".$_."'"} @{$vals}[0..$length-1];
  return $type.'('.$value_list.')';
}

sub enumSetType {
  my $prng= shift;
  my ($type, $length, $valtype);
  if ($prng->uint16(0,2)) {
    $type= 'ENUM';
    $length= ($prng->uint16(0,4) ? $prng->uint16(1,8) :($prng->uint16(0,9) ? $prng->uint16(1,64) : ($prng->uint16(0,99) ? $prng->uint16(1,255) : $prng->uint16(65535))));
  } else {
    $type= 'SET';
    $length= ($prng->uint16(0,4) ? $prng->uint16(1,8) : $prng->uint16(1,64));
  }
  return $prng->enumSetTypeValues($length);
}

sub inet6Type {
  return 'INET6';
}

sub uuidType {
  return 'UUID';
}

sub jsonType {
  return 'JSON';
}

sub blobType {
  my $prng= shift;
  my $blob_types= [
    'TINYTEXT',
    'TINYBLOB',
    'TEXT',
    'BLOB',
    'MEDIUMTEXT',
    'MEDIUMBLOB',
    'LONGTEXT',
    'LONGBLOB',
  ];
  my $type= $prng->arrayElement($blob_types);
  # 20% of BLOB and TEXT with length
  if (($type eq 'BLOB' or $type eq 'TEXT') and not $prng->uint16(0,4)) {
    my $length= 1;
    if ($prng->uint16(0,4)) {
      $length= $prng->uint16(0,255);
    } elsif ($prng->uint16(0,4)) {
      $length= $prng->uint16(0,65535);
    } elsif ($prng->uint16(0,4)) {
      $length= $prng->uint16(0,16777215);
    } else {
      $length= $prng->uint16(0,4294967295);
    }
    $type.= '('.$length.')';
  }
  return $type;
}

sub varcharType {
  my $prng= shift;
  my $type= '';
  if ($prng->uint16(0,4)) {
    $type= 'VARCHAR';
    $type= 'NATIONAL '.$type unless $prng->uint16(0,99);
  } else {
    $type= 'VARBINARY';
  }
  $type= $type.'('.($prng->uint16(0,9) ? $prng->uint16(4,64) : ($prng->uint16(0,19) ? $prng->uint16(1,4096) : $prng->uint16(0,65532))).')';
  return $type;
}

sub charType {
  my $prng= shift;
  my $type= '';
  my $length= '('.($prng->uint16(0,4) ? $prng->uint16(1,16) : $prng->uint16(0,255)).')';
  if ($prng->uint16(0,4)) {
    $type= 'CHAR';
    $type= 'NATIONAL '.$type unless $prng->uint16(0,99);
    $type.= $length if $prng->uint16(0,9);
  } elsif ($prng->uint16(0,49)) {
    $type= 'BINARY';
    $type.= $length if $prng->uint16(0,9);
  } else {
    $type= 'CHAR BYTE';
  }
  return $type;
}

sub bitType {
  my $prng= shift;
  # 66% with M
  if ($prng->uint16(0,2)) {
    return 'BIT('.$prng->uint16(0,64).')';
  } else {
    return 'BIT';
  }
}

sub floatType {
  my $prng= shift;
  my $float_types= [
    'FLOAT',
    'DOUBLE',
    'DOUBLE PRECISION',
  ];
  my $type= $prng->arrayElement($float_types);
  # 80% with M
  if ($prng->uint16(0,4)) {
    my $m= $prng->uint16(0,255);
    $type.= '('.$m;
    # 50% with D for FLOAT, 100% for DOUBLE
    if ($type ne 'FLOAT' or $prng->uint16(0,1)) {
      my $n= $prng->uint16(0,($m < 30 ? $m : 30));
      $type.= ','.$n.')';
    } else {
      $type.= ')';
    }
  }
  return $type;
}

sub boolType {
  my $prng= shift;
  return ($prng->uint16(0,1) ? 'BOOL' : 'BOOLEAN');
}

sub decimalType {
  my $prng= shift;
  my $dec_types= [
    'DECIMAL',
    'DEC',
    'NUMERIC',
    'FIXED',
  ];
  my $type= $prng->arrayElement($dec_types);
  # 80% with M
  if ($prng->uint16(0,4)) {
    my $m= $prng->uint16(0,65);
    $type.= '('.$m;
    # 66% with D
    if ($prng->uint16(0,2)) {
      my $n= $prng->uint16(0,($m < 38 ? $m : 38));
      $type.= ','.$n.')';
    } else {
      $type.= ')';
    }
  }
  return $type;
}

sub intType {
  my $prng= shift;
  my $int_types= [
    'TINYINT',
    'SMALLINT',
    'MEDIUMINT',
    # Main type
    'INT','INT','INT','INT','INT','INT','INT','INT','INT',
    'INTEGER',
    'BIGINT',
    'INT1',
    'INT2',
    'INT3',
    'INT4',
    'INT8',
  ];
  my $type= $prng->arrayElement($int_types);
  # 20% with length
  if (not $prng->uint16(0,4)) {
    $type.= '('.$prng->uint16(0,16).')';
  }
  return $type;
}

#######################
#
# Auto rule
#
# Examples (double underscore has already been stripped)
# __not => NOT
# __not(50) => NOT with 50% probability, otherwise ''
# __not(30) => NOT with 30% probability, otherwise ''
# __on_x_off => ON or OFF, each with 50% probability
# __on_x_off(80) => ON with 80% probability, otherwise OFF
# __on_x_off(80,10) => ON with 80% probability, OFF with 10% probability, otherwise nothing
# __1_x_2_x_3_x_4 => 1 or 2 or 3 or 4, each with 25% probability
# __1_x_2_x_3_x_4(80) => 1 with 80% probability, otherwise 2 or 3 or 4 each with equal probability
# To summarize:
# - if no probability is provided, one of the items will be returned with equal probability
# - if there are less probabilities than items, the rest of the items will equally split
#   remaining probability, and one of the items will be returned
# - if probability for every item is provided, and its sums up to less than 100%,
#   then an empty value can be returned with remaining probability
# We won't check that the sum of probabilities is <= 100

sub auto {
  my ($rand, $rule)= @_;
  my @probabilities= ();
  if ($rule =~ s/\(([\d,]+)\)$//) {
    @probabilities= split /,/, $1;
  }
  my @items= split /_x_/, $rule;
  if (scalar(@probabilities) < scalar(@items)) {
    my $filler;
    if (scalar(@probabilities) == 0) {
      $filler= int(100/scalar(@items));
    } else {
      my $s= 0;
      foreach my $p (@probabilities) { $s+= $p };
      $filler= (100 - $s) / (scalar(@items) - scalar(@probabilities));
    }
    foreach my $i ($#probabilities+1..$#items) {
      $probabilities[$i]= $filler;
    }
    # To avoid rounding errors
    $probabilities[$#probabilities]+= 1;
  }

  my $r= $rand->uint16(1,100);
  foreach my $i (0..$#items) {
    if ($r <= $probabilities[$i]) {
      my $item= $items[$i];
      # To have an actual underscore in the item, we repeat it twice in the template
      # so, to get LOW_PRIORITY, it should be __low__priority
      $item=~ s/_/ /g;
      $item=~ s/  /\_/g;
      return uc($item) ;
    }
    $r-= $probabilities[$i];
  }
  return '';
}

1;
