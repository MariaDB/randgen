#  Copyright (c) 2022, MariaDB Corporation
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; version 2 of the License.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA */

##############################################
# Data types via ALTER TABLE, except for GIS
##############################################

query_init:
  { $col=0; @enum_vals=(); foreach (1..65535) { push @enum_vals, "'".$_."'" }; '' } ;

query:
  { $null= $prng->uint16(0,3); '' } { _set_db('NON-SYSTEM') } ALTER IGNORE TABLE _table data_types_usage ;

data_types_usage:
  data_types_modify_column |
  data_types_change_column |
  ==FACTOR:0.0001== data_types_add_column
;

data_types_modify_column:
  MODIFY IF EXISTS _field data_types_column_definition ;

data_types_change_column:
  CHANGE IF EXISTS _field { $last_field } data_types_column_definition ;

data_types_add_column:
  ADD IF NOT EXISTS { 'dtypecol'.(++$col) } data_types_column_definition ;

data_types_column_definition:
# Bool
  BOOL data_types_nullable DEFAULT { $null ? $prng->arrayElement(['NULL',0,1]) : $prng->uint16(0,1) } |
# Integers
  TINYINT data_types_optional_int_length __signed(30) data_types_nullable DEFAULT { @defaults=(-128,0,127,$prng->uint16(-127,126)); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  TINYINT data_types_optional_int_length __unsigned __zerofill(10) data_types_nullable DEFAULT { @defaults=(0,255,$prng->uint16(1,254)); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  SMALLINT data_types_optional_int_length __signed(30) data_types_nullable DEFAULT { @defaults=(-32768,0,32767,$prng->uint16(-32767,32766)); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  SMALLINT data_types_optional_int_length __unsigned __zerofill(10) data_types_nullable DEFAULT { @defaults=(0,65535,$prng->uint16(1,65534)); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  MEDIUMINT data_types_optional_int_length __signed(30) data_types_nullable DEFAULT { @defaults=(-8388608,0,8388607,$prng->uint16(-8388607,8388606)); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  MEDIUMINT data_types_optional_int_length __unsigned __zerofill(10) data_types_nullable DEFAULT { @defaults=(0,16777215,$prng->uint16(1,16777214)); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  INT data_types_optional_int_length __signed(30) data_types_nullable DEFAULT { @defaults=(-2147483648,0,2147483647,$prng->int(-2147483647,2147483646)); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  INT data_types_optional_int_length __unsigned __zerofill(10) data_types_nullable DEFAULT { @defaults=(0,4294967295,$prng->int(1,4294967294)); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  BIGINT data_types_optional_int_length __signed(30) data_types_nullable DEFAULT { @defaults=(-9223372036854775808,0,9223372036854775807,$prng->int(-9223372036854775807,9223372036854775806)); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  BIGINT data_types_optional_int_length __unsigned __zerofill(10) data_types_nullable DEFAULT { @defaults=(0,18446744073709551615,$prng->int(1,18446744073709551614)); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
# Fixed
  DECIMAL data_types_optional_decimal_length __signed(10) data_types_nullable DEFAULT { @defaults=( "(- CAST(POW(10,".($m-$d).") AS UNSIGNED) + CAST(1/POW(10,$d) AS DECIMAL($d,$d)))" , 0.0, "(CAST(POW(10,".($m-$d).") AS UNSIGNED) - CAST(1/POW(10,$d) AS DECIMAL($d,$d)))", $prng->fixed(-10**($m-$d),10**($m-$d))); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  DECIMAL data_types_optional_decimal_length __unsigned __zerofill(10) data_types_nullable DEFAULT { @defaults=(0.0,"(CAST(POW(10,".($m-$d).") AS UNSIGNED) - CAST(1/POW(10,$d) AS DECIMAL($d,$d)))",$prng->fixed_unsigned(0,10**($m-$d))); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
# Floats
  FLOAT data_types_optional_float_length __signed(10) data_types_nullable DEFAULT { @defaults=( "(- CAST(POW(10,".($m-$d).") AS UNSIGNED) + CAST(1/POW(10,$d) AS DOUBLE($d,$d)))" , 0.0, "(CAST(POW(10,".($m-$d).") AS UNSIGNED) - CAST(1/POW(10,$d) AS DOUBLE($d,$d)))", $prng->float(-10**($m-$d),10**($m-$d))); push @defaults, 'NULL' if $null; push @defaults, -3.402823466E+38, -1.175494351E-38, 1.175494351E-38, 3.402823466E+38 unless $length; $prng->arrayElement(\@defaults) } |
  FLOAT data_types_optional_float_length __unsigned __zerofill(10) data_types_nullable DEFAULT { @defaults=(0.0,"(CAST(POW(10,".($m-$d).") AS UNSIGNED) - CAST(1/POW(10,$d) AS DOUBLE($d,$d)))",abs($prng->float(0,10**($m-$d)))); push @defaults, 'NULL' if $null; push @defaults, 1.175494351E-38, 3.402823466E+38 unless $length; $prng->arrayElement(\@defaults) } |
  DOUBLE data_types_optional_double_length __signed(10) data_types_nullable DEFAULT { @defaults=( "(- CAST(POW(10,".($m-$d).") AS UNSIGNED) + CAST(1/POW(10,$d) AS DOUBLE($d,$d)))" , 0.0, "(CAST(POW(10,".($m-$d).") AS UNSIGNED) - CAST(1/POW(10,$d) AS DOUBLE($d,$d)))", $prng->float(-10**($m-$d),10**($m-$d))); push @defaults, 'NULL' if $null; push @defaults, -1.79769313486231E+308, -2.22507385850720E-308, 2.22507385850720E-308, 1.79769313486231E+308 unless $length; $prng->arrayElement(\@defaults) } |
  DOUBLE data_types_optional_double_length __unsigned __zerofill(10) data_types_nullable DEFAULT { @defaults=(0.0,"(CAST(POW(10,".($m-$d).") AS UNSIGNED) - CAST(1/POW(10,$d) AS DOUBLE($d,$d)))",abs($prng->float(0,10**($m-$d)))); push @defaults, 'NULL' if $null; push @defaults, 2.22507385850720E-308, 1.79769313486231E+308 unless $length; $prng->arrayElement(\@defaults) } |
# Bit
  BIT data_types_optional_bit_length data_types_nullable DEFAULT { @defaults=("''",0,"b'0'",$maxval); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
# Strings
  { $max= 255; '' } BINARY data_types_optional_char_length data_types_nullable DEFAULT { @defaults=("''","REPEAT(".$prng->string(1).",$m)",$prng->string($m)); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  { $max= 255; '' } CHAR data_types_optional_char_length data_types_nullable DEFAULT { @defaults=("''","REPEAT(".$prng->string(1).",$m)",$prng->string($m)); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) }  |
  VARBINARY( { $m= $prng->uint16(0,65532) } ) data_types_nullable DEFAULT { @defaults=("''","REPEAT(".$prng->string(1).",$m)"); push @defaults,$prng->string($m) if $m < 64; push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  VARCHAR( { $m= $prng->uint16(0,65532) } ) data_types_nullable DEFAULT { @defaults=("''","REPEAT(".$prng->string(1).",$m)"); push @defaults,$prng->string($m) if $m < 64; push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
# Blobs
  { $max= 65535; '' } BLOB data_types_optional_char_length data_types_nullable DEFAULT { @defaults=("''","REPEAT(".$prng->string(1).",$m)"); push @defaults,$prng->string($m) if $m < 64; push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  { $max= 65535; '' } TEXT data_types_optional_char_length data_types_nullable DEFAULT { @defaults=("''","REPEAT(".$prng->string(1).",$m)"); push @defaults,$prng->string($m) if $m < 64; push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) }  |
  { $m= $prng->uint16(0,16777215); '' } MEDIUMBLOB data_types_nullable DEFAULT { @defaults=("''","REPEAT(".$prng->string(1).",$m)"); push @defaults,$prng->string($m) if $m < 64; push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  { $m= $prng->uint16(0,16777215); '' } MEDIUMTEXT data_types_nullable DEFAULT { @defaults=("''","REPEAT(".$prng->string(1).",$m)"); push @defaults,$prng->string($m) if $m < 64; push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  { $m= $prng->uint16(0,4294967295); '' } LONGBLOB data_types_nullable DEFAULT { @defaults=("''","REPEAT(".$prng->string(1).",$m)"); push @defaults,$prng->string($m) if $m < 64; push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  { $m= $prng->uint16(0,4294967295); '' } LONGTEXT data_types_nullable DEFAULT { @defaults=("''","REPEAT(".$prng->string(1).",$m)"); push @defaults,$prng->string($m) if $m < 64; push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  { $m= $prng->uint16(0,255); '' } TINYBLOB data_types_nullable DEFAULT { @defaults=("''","REPEAT(".$prng->string(1).",$m)"); push @defaults,$prng->string($m) if $m < 64; push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  { $m= $prng->uint16(0,255); '' } TINYTEXT data_types_nullable DEFAULT { @defaults=("''","REPEAT(".$prng->string(1).",$m)"); push @defaults,$prng->string($m) if $m < 64; push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
# Enum and set
  ENUM({ $m= ($prng->uint16(0,1000) ? $prng->uint16(1,32) : $prng->uint16(1,65535)); join ',', @enum_vals[0..$m-1] }) data_types_nullable DEFAULT { @defaults=("'1'","'$m'",1,$m,"'".$prng->uint16(1,$m)."'"); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  SET({ $m= $prng->uint16(1,64); join ',', @enum_vals[0..$m-1] }) data_types_nullable DEFAULT { @defaults=("'1'","'$m'",1,$m, "'".(join ',',(1..$m))."'" ,"'".$prng->uint16(1,$m)."'"); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
# Special strings
  /* compatibility 10.5.0 */ INET6 data_types_nullable DEFAULT { @defaults=("'::'","'ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff'",$prng->inet6); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  JSON data_types_nullable DEFAULT { @defaults=("'{}'",$prng->json(($prng->uint16(0,1000) ? $prng->uint16(0,128) : $prng->uint16(0,4294967295)))); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  /* compatibility 10.7.0,es-10.6 */ UUID data_types_nullable DEFAULT { @defaults=("'00000000-0000-0000-0000-000000000000'","'ffffffff-ffff-ffff-ffff-ffffffffffff'",$prng->uuid); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  /* compatibility 10.10.0 */ INET4 data_types_nullable DEFAULT { @defaults=("'0.0.0.0'","'255.255.255.255'","'".$prng->uint16(0,255).".".$prng->uint16(0,255).".".$prng->uint16(0,255).".".$prng->uint16(0,255)."'"); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
# Temporal
  DATE data_types_nullable DEFAULT { @defaults=("'1000-01-01'","'9999-12-31'","'0000-00-00'",$prng->date(),'DATE(NOW())','CURRENT_DATE'); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  TIME data_types_optional_ms data_types_nullable DEFAULT { @defaults=("'-838:59:59.999999'","'838:59:59.999999'","'00:00:00'","'00:00:00.0'","'00:00:00.000'","'00:00:00.000000'",$prng->time($m),"CURRENT_TIME($m)","TIME(NOW($m))"); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  DATETIME data_types_optional_ms data_types_nullable DEFAULT { @defaults=("'1000-01-01 00:00:00.000000'","'9999-12-31 23:59:59.999999'","'0000-00-00'",$prng->datetime($m),"CURRENT_TIMESTAMP($m)","NOW($m)"); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  TIMESTAMP data_types_optional_ms data_types_nullable DEFAULT { @defaults=("FROM_UNIXTIME(POW(10,-$m))","FROM_UNIXTIME(2147483648-POW(10,-$m))","CURRENT_TIMESTAMP($m)","NOW($m)"); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) } |
  YEAR data_types_nullable DEFAULT { @defaults=("0000","1901","2155",$prng->uint16(1901,2155),"YEAR(NOW())"); push @defaults, 'NULL' if $null; $prng->arrayElement(\@defaults) }
;

data_types_nullable:
  { $null ? 'NULL' : 'NOT NULL' };

data_types_optional_int_length:
  { $prng->uint16(0,4) ? '' : '('.$prng->uint16(0,255).')' };

data_types_optional_decimal_length:
  { $d= $prng->uint16(0,38); $m= $prng->uint16($d,65); if ($prng->uint16(0,4)) { $length= "($m,$d)" } elsif ($prng->uint16(0,2)) { $d=0; $length= "($m)" } else { $m=10; $d=0; $length= '' } };

data_types_optional_float_length:
  { $d= $prng->uint16(0,30); $m= $prng->uint16($d,$d+38); if ($prng->uint16(0,4)) { $m=68; $d=30; $length= '' } elsif ($prng->uint16(0,2)) { $length= "($m,$d)" } else { $d=0; $m=53 if $m > 53; $length= "($m)" } };

data_types_optional_double_length:
  { $d= $prng->uint16(0,30); $m= $prng->uint16($d,255); if ($prng->uint16(0,9)) { $m=308; $d=30; $length= '' } else { $length= "($m,$d)" } };

data_types_optional_bit_length:
  { $m= $prng->uint16(0,64); if ($prng->uint16(0,5)) { $length= "($m)" } else { $m=1; $length= '' }; $maxval= ''; for (1..$m) { $maxval.='1' }; $maxval= "b'$maxval'"; $length };

data_types_optional_char_length:
  { $m= $prng->uint16(0,$max); if ($prng->uint16(0,20)) { $length= "($m)" } else { $m=1; $length= '' } };

data_types_optional_ms:
  { $m= $prng->uint16(0,6); if ($prng->uint16(0,1)) { $length= "($m)" } else { $m=0; $length= '' } };
