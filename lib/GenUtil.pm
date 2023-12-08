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
           'intersect_arrays', 'isFederatedEngine',
           'isCompatible'
           );

use strict;

use Cwd;
use POSIX;
use Carp;
use Fcntl qw(:flock SEEK_END);
use File::Temp qw/ :POSIX /;
use GDBM_File;

use Constants;

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
      print "# ".isoTimestamp()." [$$]$level ".shorten_message($line)."\n";
    }
  } else {
    print "# ".isoTimestamp()." [$$]$level ".shorten_message($text)."\n";
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
    $msg= '[ABRIDGED] '.$prefix.' <...> '.$suffix;
  }
  return $msg;
}

sub group_cleaner {
  return if osWindows();
  my $group_id= `ps -ho pgrp -p $$`;
  chomp $group_id;
#  system("ps -ho pgrp,pid,args | grep -v tee");
  my @pids= split /\n/, `ps -ho pgrp,pid,comm | grep -v tee`;
  my @group= ();
  my @immortals= ($group_id, $$);
  if ($ENV{RQG_IMMORTALS}) {
    push @immortals, split ',', $ENV{RQG_IMMORTALS};
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
  sayDebug("Cleaning the group $group_id (@group), keeping immortals (@immortals)");
  kill('KILL',@group);
  return STATUS_TEST_STOPPED;
}

# if $version is X.Y (or NNNN), that is major version only, then
# $max_min is used to fill the rest. If it's set to 0, then the result
# will be the minimal version, e.g. 10.6 => 100600. Otherwise it will be
# the maximum version, e.g. 10.6 => 100699.
# Usually if we convert the server version (or the test compatibility version),
# then it should be maximum, e.g. run.pl --compatibility=10.6 means that
# everything that's compatible with any 10.6 will do.
# If we convert the object/grammar compatibility, then it should be the minimum,
# e.g. 10.6 => 100600, because /* compatibility 10.6 */ means that
# any 10.6 server will do.
sub versionN6 {
  my ($version,$max_min) = @_;
  $max_min= '99' unless defined $max_min;
  if ($version =~ /([0-9]+)\.([0-9]+)(?:\.([0-9]*))?/) {
    return sprintf("%02d%02d%02d",int($1),int($2),(defined $3 ? int($3) : $max_min));
  } elsif ($version =~ /^\d{6}$/) {
    return $version;
  } elsif ($version =~ /^\d{4}$/) {
    return $version.$max_min;
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

# Checks whether an object is compatible with the server.
# It is applied when an object has a requirement for a minimal server version,
# e.g. syntax is only applicable to 10.11+.
# An object requirements may be a comma-separated list, e.g. '10.11,es-10.6', or '10.5.22,10.6.15,10.10.2' etc.
# For the server side, two values are provided -- one is the server version
# (or it can be a configured compatibility version), and another is a ES flag which can be true or false.
# Compatibility is checked in the following way:
# - if the server version is X.Y.Z and the object requirements list contains X.Y.N,
#   then the function only returns true if z >= N.
#   If z is not defined, it is considered to be 99. If N is not defined, it is considered to be 00.
#   e.g. isCompatible('10.4.30,10.6.15','10.6.14') returns false,
#   while isCompatible('10.4.30,10.6.15','10.6.16') and isCompatible('10.4.30,10.6.15','10.6') return true.
# - if the object requirements list doesn't contain the same major version as the server,
#   the function returns true if the server version is greater or equal at least one item
#   on the requirements list
# es-XX and A.B.C-N requirements are only satisfied if the server ES flag is true.

sub isCompatible {
  my ($object_compatibility, $server_version, $server_es)= @_;
  my $srv6= versionN6($server_version,'99');
  my $srv4= substr($srv6,0,4);
  $object_compatibility =~ s/ +//g;
  my @compat= split /,/, $object_compatibility;
  my $loose_compatibility= 0;
  foreach my $c (@compat) {
    next if $c =~ s/^es-// and not $server_es;
    next if $c =~ s/-\d+$// and not $server_es;
    my $c6= versionN6($c,'00');
    my $c4= substr($c6,0,4);
    if ($c4 eq $srv4) {
      return ($srv6 ge $c6);
    } elsif ($srv6 ge $c6) {
      $loose_compatibility= 1;
    }
  }
  return $loose_compatibility;
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

sub isFederatedEngine {
  my $engine= shift;
  return (lc($engine) eq 'federated' or lc($engine) eq 'spider');
}


1;
