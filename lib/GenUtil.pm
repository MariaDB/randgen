# Copyright (c) 2008, 2011, Oracle and/or its affiliates. All rights
# reserved.
# Copyright (c) 2022, MariaDB
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

package GenUtil;
use base 'Exporter';

@EXPORT = ('say', 'sayError', 'sayWarning', 'sayDebug', 'sayFile',
           'tmpdir', 'safe_exit', 'group_cleaner',
           'osWindows', 'osLinux', 'osSolaris', 'osMac',
           'isoTimestamp', 'isoUTCTimestamp', 'isoUTCSimpleTimestamp',
           'rqg_debug', 'unix2winPath', 'versionN6',
           'isNewerVersion', 'isOlderVersion',
           'shorten_message', 'set_expectation', 'unset_expectation',
           'intersect_arrays'
           );

use strict;

use Cwd;
use POSIX;
use Carp;
use Fcntl qw(:flock SEEK_END);
use File::Temp qw/ :POSIX /;
use GDBM_File;

use GenTest::Constants;

my $tmpdir;

1;

sub BEGIN {
  foreach my $tmp ($ENV{TMP}, $ENV{TEMP}, $ENV{TMPDIR}, '/tmp', '/var/tmp', cwd()."/tmp" ) {
    if (defined $tmp && -e $tmp) {
      $tmpdir = $tmp;
      last;
    }
  }

  if (defined $tmpdir) {
    if (($^O eq 'MSWin32') || ($^O eq 'MSWin64')) {
      $tmpdir = $tmpdir.'\\';
    } else {
      $tmpdir = $tmpdir.'/';
    }
  }

  croak("Unable to locate suitable temporary directory.") if not defined $tmpdir;
  return 1;
}

sub say {
  my $text = shift;
  my $level= shift; # ERROR or DEBUG or Warning or nothing
  $level= ($level ? '['.$level.']' : '');

  # Suppress warnings "Wide character in print".
  # We already know that our UTFs in some grammars are ugly.
  no warnings 'layer';

  if ($text =~ m{[\r\n]}is) {
    foreach my $line (split (m{[\r\n]}, $text)) {
      print "# ".isoTimestamp()." [$$]$level $line\n";
    }
  } else {
    print "# ".isoTimestamp()." [$$]$level $text\n";
  }
}

sub sayError {
  say(@_, 'ERROR');
}

sub sayWarning {
  say(@_, 'Warning');
}

sub sayDebug {
  say(@_, 'DEBUG') if rqg_debug();
}

sub sayFile {
  my ($file) = @_;

  say("--------- Contents of $file -------------");
  open FILE,$file;
  while (<FILE>) {
    say("| ".$_);
  }
  close FILE;
  say("----------------------------------");
}

sub tmpdir {
  return $tmpdir;
}

sub safe_exit {
  my $exit_status = shift;
  POSIX::_exit($exit_status);
}

sub osWindows {
  if (($^O eq 'MSWin32') || ($^O eq 'MSWin64')) {
    return 1;
  } else {
    return 0;
  }
}

sub osLinux {
  if ($^O eq 'linux') {
    return 1;
  } else {
    return 0;
  }
}

sub osSolaris {
  if ($^O eq 'solaris') {
    return 1;
  } else {
    return 0;
  }
}

sub osMac {
  if ($^O eq 'darwin') {
    return 1;
  } else {
    return 0;
  }
}

sub isoTimestamp {
  my $datetime = shift;

  my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = defined $datetime ? localtime($datetime) : localtime();
  return sprintf("%04d-%02d-%02dT%02d:%02d:%02d", $year+1900, $mon+1 ,$mday ,$hour, $min, $sec);
}

sub isoUTCTimestamp {
  my $datetime = shift;

  my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = defined $datetime ? gmtime($datetime) : gmtime();
  return sprintf("%04d-%02d-%02dT%02d:%02d:%02d", $year+1900, $mon+1 ,$mday ,$hour, $min, $sec);
}

sub isoUTCSimpleTimestamp {
  my $datetime = shift;

  my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = defined $datetime ? gmtime($datetime) : gmtime();
  return sprintf("%04d%02d%02dT%02d%02d%02d", $year+1900, $mon+1 ,$mday ,$hour, $min, $sec);
}


# unix2winPath:
#   Converts the given file path from unix style to windows native style
#   by replacing all forward slashes to backslashes.
sub unix2winPath {
  my $path = shift;
  $path =~ s/\//\\/g; # replace "/" with "\"
  return $path;
}

sub rqg_debug {
  if ($ENV{RQG_DEBUG}) {
    return 1;
  } else {
    return 0;
  }
}

# array intersection
# (so that we don't need to require additional packages)

sub intersect_arrays {
  my ($a,$b) = @_;
  my %in_a = map {$_ => 1} @$a;
  return [ grep($in_a{$_},@$b) ];
}

# Shortens message for keeping output more sensible
sub shorten_message {
  my $msg= shift;
  if (length($msg) > 8191) {
    my ($prefix, $suffix) = (substr($msg,0,2000),substr($msg,-512));
    if (substr($prefix,1999) eq '\\') { chop $prefix };
    if (substr($suffix,0,1) eq "'" or substr($suffix,0,1) eq '"') { $suffix= substr($suffix,1) };
    $msg= $prefix.' <...> '.$suffix;
  }
  return $msg;
}

sub group_cleaner {
  return if osWindows();
  my $group_id= `ps -ho pgrp -p $$`;
  chomp $group_id;
  #system("ps -ho pgrp,pid,comm | grep -v tee");
  my @pids= split /\n/, `ps -ho pgrp,pid,comm | grep -v tee`;
  my @group= ();
  my @immortals= ($group_id, $$);
  if ($ENV{RQG_IMMORTALS}) {
    push @immortals, (split /,/, $ENV{RQG_IMMORTALS});
  }
  
  PP:
  foreach my $pp (@pids) {
    if ($pp =~ /^\s*(\d+)\s+(\d+)/) {
      my ($p1, $p2) = ($1, $2);
      next if $p1 != $group_id;
      foreach my $im (@immortals) {
        next PP if $im and $p2 == $im;
      }
      push @group, $p2;
    }
  }
#  system("ps -ef | grep -E '".join('|',@group)."'");
  say("Cleaning the group $group_id (@group), keeping immortals (@immortals)");
  kill('KILL',@group);
  return STATUS_EOF;
}

sub versionN6 {
  my $version = shift;
  if ($version =~ /([0-9]+)\.([0-9]+)(?:\.([0-9]*))?/) {
    return sprintf("%02d%02d%02d",int($1),int($2),(defined $3 ? int($3) : 0));
  } elsif ($version =~ /^\d{6}$/) {
    return $version;
  } else {
    sayError("Unknown version format: $version");
    confess();
    return $version;
  }
}

sub isNewerVersion {
  my ($ver1, $ver2)= @_;
  $ver1= versionN6($ver1);
  $ver2= versionN6($ver2);
  return $ver1 gt $ver2;
}

sub isOlderVersion {
  my ($ver1, $ver2)= @_;
  $ver1= versionN6($ver1);
  $ver2= versionN6($ver2);
  return $ver1 lt $ver2;
}

# Dictionary:
# - positive number in server-specific vardir: number of seconds to wait
#   for the server to come back
# - negative number in server-specific vardir (-1 normally): downtime
#   is expected, but there is no need to wait
# - 0 in server-specific vardir (treated the same as the absence of file):
#   downtime is not expected
# maybe TBC
sub set_expectation {
  my ($location, $text)= @_;
  if (open(WAITFILE,">$location/expect")) {
    print WAITFILE "$text\n";
    close(WAITFILE);
  } else {
    sayError("Could not create expectation flag at $location: $!");
  }
}

sub unset_expectation {
  my $location= shift;
  unlink("$location/expect");
}

1;
