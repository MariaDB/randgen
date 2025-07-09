#  Copyright (c) 2025, MariaDB
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

# Will fail on 10.6 but let it
thread1_init:
  INSTALL SONAME 'provider_bzip2' ;; INSTALL SONAME 'provider_lz4' ;; INSTALL SONAME 'provider_lzma' ;; INSTALL SONAME 'provider_lzo' ;; INSTALL SONAME 'provider_snappy' ;

query:
  SET GLOBAL INNODB_COMPRESSION_ALGORITHM = compression_alg ;

compression_alg:
  bzip2 | lz4 | lzma | lzo | snappy | zlib | DEFAULT ;
