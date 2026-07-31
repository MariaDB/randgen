# Copyright (c) 2026, MariaDB
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

package ConfigCommon;


use strict;
use warnings;
use Exporter qw(import);

our @EXPORT_OK = qw(
    $version
    $combinations
    $scenarios
    @common_options
    @new_options
    %parameters
    %options
    $msan_safe
);

our (
    $version,
    $combinations,
    $scenarios,
    @common_options,
    @new_options,
    %parameters,
    %options,
    $msan_safe
);
# Config files may be parameterized depending on version number
$version = 999999;
$combinations = [];
$scenarios = {};
%parameters = ();
%options = ();
$msan_safe = 0;
@common_options = ();
# For ad-hoc testing, mostly feature testing
@new_options = ();

1;