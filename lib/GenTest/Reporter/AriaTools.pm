# Copyright (c) 2025, MariaDB
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

package GenTest::Reporter::AriaTools;

require Exporter;
@ISA = qw(GenTest::Reporter);

use File::Basename qw(dirname);

use strict;
use GenUtil;
use GenTest;
use GenTest::Reporter;
use Constants;

sub report {
  my $reporter = shift;

  my $aria_chk = DBServer::MariaDB::_find(undef,
    [$reporter->server->serverVariable('basedir')],
    osWindows()?["storage/maria/Debug","storage/maria/RelWithDebInfo","storage/maria/Release","bin"]:["storage/maria","bin"],
    osWindows()?"aria_chk.exe":"aria_chk");
  unless (defined $aria_chk) {
    sayError("Could not find aria_chk");
    return STATUS_ENVIRONMENT_FAILURE;
  }
  my $aria_tool_location= dirname($aria_chk);

  my $tool_sandbox= $reporter->server->serverVariable('datadir');
  $tool_sandbox =~ s/[\/\\]$//;
  $tool_sandbox .='_for_aria_tools';
  $reporter->server->backupDatadir($tool_sandbox);

  my $vardir= $reporter->server->vardir;

  my $aria_dump_log = $aria_tool_location.'/aria_dump_log'.(osWindows()?'.exe':'');
  my $aria_ftdump = $aria_tool_location.'/aria_ftdump'.(osWindows()?'.exe':'');
  my $aria_pack = $aria_tool_location.'/aria_pack'.(osWindows()?'.exe':'');
  my $aria_read_log = $aria_tool_location.'/aria_read_log'.(osWindows()?'.exe':'');
  my @mai_files= glob("$tool_sandbox/*/*.MAI");
  my @aria_logs= glob("$tool_sandbox/aria_log.*");

  my $cmd="$aria_chk --datadir=$tool_sandbox @mai_files > $vardir/aria_chk.out 2>&1";
  say("Running aria_chk ($cmd)");
  system($cmd);
  if ($?) {
    sayError("aria_chk returned ".($?>>8).", see $vardir/aria_chk.out");
    return STATUS_CLIENT_FAILURE;
  }

  # aria_dump_log does not promise to work on multiple files
  foreach my $f (@aria_logs) {
    $cmd="$aria_dump_log $f >> $vardir/aria_dump_log.out 2>&1";
    say("Running aria_dump_log ($cmd)");
    system("$cmd");
    if ($?) {
      sayError("aria_dump_log returned ".($?>>8).", see $vardir/aria_dump_log.out");
      return STATUS_CLIENT_FAILURE;
    }
  }
  # Due to MDEV-36919 we have to pack one table at a time
  foreach my $f (@mai_files) {
    $cmd= "$aria_pack --datadir=$tool_sandbox $f >> $vardir/aria_pack.out 2>&1";
    say("Running aria_pack ($cmd)");
    system($cmd);
    if ($?) {
      my $res= ($?>>8);
      # Ignore "is too small to compress" error, there is nothing wrong with being small
      if ($res == 2) {
        system("tail -n 1 $vardir/aria_pack.out | grep 'too small to compress'");
        if ($?) {
          sayError("aria_pack returned $res, see $vardir/aria_pack.out");
          return STATUS_CLIENT_FAILURE;
        }
      }
    }
  }
  # Cannot do aria recover due to MDEV-35696
  #
  # $cmd= "$aria_chk -rq --datadir=".$reporter->server->serverVariable('datadir')." @mai_files > $vardir/aria_chk_recover.out 2>&1";
  # say("Running aria_chk recover ($cmd)");
  # system($cmd);
  # if ($?) {
  #   sayError("aria_chk -u returned ".($?>>8).", see $vardir/aria_chk_recover.out");
  #   return STATUS_CLIENT_FAILURE;
  # }
  # $cmd= "$aria_chk -u --datadir=".$reporter->server->serverVariable('datadir')." @mai_files > $vardir/aria_chk_unpack.out 2>&1";
  # say("Running aria_chk unpack ($cmd)");
  # system($cmd);
  # if ($?) {
  #   sayError("aria_chk -u returned ".($?>>8).", see $vardir/aria_chk_unpack.out");
  #   return STATUS_CLIENT_FAILURE;
  # }
  $cmd= "$aria_read_log --display-only --aria-log-dir-path=".$reporter->server->serverVariable('datadir')."  > $vardir/aria_read_log.out 2>&1";
  say("Running aria_read_log ($cmd)");
  system($cmd);
  if ($?) {
    sayError("aria_read_log returned ".($?>>8).", see $vardir/aria_read_log.out");
    return STATUS_CLIENT_FAILURE;
  }

  return STATUS_OK;
}

sub type {
  return REPORTER_TYPE_POST_SHUTDOWN ;
}

1;
