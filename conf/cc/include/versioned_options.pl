# Copyright (c) 2023, MariaDB
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

########################################################################

# Version should/can be defined in the combinations options and passed here
my $version= shift;

foreach my $comb (keys %parameters) {
  my @opts= ();
  my $opts= $parameters{$comb};
  VERSIONS:
  foreach my $ver (reverse sort keys %$opts) {
    if ($ver le $version) {
      push @opts, (ref $opts->{$ver} eq 'ARRAY' ? @{$opts->{$ver}} : $opts->{$ver});
      last VERSIONS;
    }
  }
  $options{$comb}= [ @opts ];
}
return 1;
