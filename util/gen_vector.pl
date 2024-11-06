# Copyright (c) 2024 MariaDB
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

# The script generates random embeddings with given parameters
# Example of use:
# - generate a file with the desired parameters, e.g. /tmp/1.file
# - in the server, create a table e.g.
#   create or replace table t_base (pk int auto_increment primary key, t text, v blob as (vec_fromtext(t)) stored);
# - run
#   load data local infile '/data/1.file' into table t (t);
# - insert-select the data into other tables of your choice

use Getopt::Long;

use strict;

my $dimensions= 100;
my $rows= 1000;
my $min_value= 0;
my $max_value= 1;
my $seed= 1;
my $precision= 3;


GetOptions(
  'dim|dimensions=i'            => \$dimensions,
  'max|max-value|max_value=f' => \$max_value,
  'min|min-value|min_value=f' => \$min_value,
  'precision=i'                   => \$precision,
  'rows=i'                        => \$rows,
  'seed=i'                        => \$seed,
);

srand($seed);

for (my $i=0; $i<$rows; $i++) {
  my @vals= ();
  for (my $j=0; $j<$dimensions; $j++) {
    push @vals, sprintf("%.".$precision."f",$min_value + rand()*($max_value - $min_value));
  }
  print "[".(join ',', @vals)."]\n";
}
