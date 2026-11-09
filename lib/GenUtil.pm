# Copyright (c) 2008, 2011, Oracle and/or its affiliates. All rights
# reserved.
# Copyright (c) 2022, 2026 MariaDB
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
           'rqg_debug', 'unix2winPath', 'win2unixPath', 'versionN6',
           'isNewerVersion', 'isOlderVersion',
           'shorten_message', 'set_expectation', 'unset_expectation',
           'intersect_arrays', 'isFederatedEngine',
           'isCompatible', 'shortClassName',
           'with_msan_libs', 'shell_quote', 'exe_name',
           'read_file', 'copy_dir', 'move_path', 'remove_path',
           'sort_file', 'diff_files', 'tee_stdout', 'find_in_path',
           'set_cleanup_root', 'adjust_args_for_windows'
           );

use strict;

use Cwd;
use POSIX;
use Carp;
use Fcntl qw(:flock SEEK_END);
use File::Temp qw/ :POSIX /;
use File::Basename qw(dirname);
use File::Compare qw(compare);
use File::Copy qw();
use File::Find qw();
use File::Path qw(mkpath remove_tree);
use File::Spec;

use Constants;

# On Windows, fork is emulated with threads, and each thread has its own
# C library locale. In a pseudo-process created by fork, the actual
# numeric locale is the system one (e.g. with a decimal comma), even though
# Perl reports it as "C". As a result, fractional numbers are stringified
# with a comma (1794173708,08145 instead of 1794173708.08145), which breaks
# generated SQL, file names, etc. To avoid it, fork is overridden so that
# the numeric locale is reset in the child.
# GenUtil is loaded before any module which forks, so the override
# applies to all of them
BEGIN {
  if ($^O eq 'MSWin32') {
    *CORE::GLOBAL::fork= sub {
      my $pid= CORE::fork();
      _reset_numeric_locale() if defined $pid and $pid == 0;
      return $pid;
    };
  }
}

sub _numeric_locale_ok {
  my $two= 2;
  my $half= 1/$two;
  return ("$half" eq '0.5');
}

# Since Perl may consider the locale already set to "C" and not call
# the C library, several ways are tried, until numbers are formatted
# correctly
sub _reset_numeric_locale {
  return if _numeric_locale_ok();
  foreach my $reset (
    sub { POSIX::setlocale(POSIX::LC_NUMERIC(), "C") },
    sub { POSIX::setlocale(POSIX::LC_NUMERIC(), ""); POSIX::setlocale(POSIX::LC_NUMERIC(), "C") },
    sub { POSIX::setlocale(POSIX::LC_ALL(), "C") },
  ) {
    $reset->();
    return if _numeric_locale_ok();
  }
  print STDERR "WARNING: Could not reset the numeric locale in pseudo-process $$, fractional numbers will be formatted according to the system locale\n";
}

my $tmpdir;
# The directory under which group_cleaner looks for leftover processes
# on Windows (see group_cleaner)
my $cleanup_root;

1;

sub BEGIN {
  foreach my $tmp ($ENV{TMP}, $ENV{TEMP}, $ENV{TMPDIR}, '/tmp', '/var/tmp', cwd()."/tmp" ) {
    if (defined $tmp && -e $tmp) {
      $tmpdir = $tmp;
      last;
    }
  }

  if (defined $tmpdir) {
    # Forward slashes work for all file operations on Windows,
    # and unlike backslashes, they can be used in SQL strings
    # (e.g. for INTO OUTFILE) without escaping
    $tmpdir =~ s{\\}{/}g if (($^O eq 'MSWin32') || ($^O eq 'MSWin64'));
    $tmpdir = $tmpdir.'/';
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
  # On Windows fork is emulated with threads, child "processes" have
  # negative pids and POSIX::_exit would terminate the whole process
  # (the parent and all siblings), so a normal exit is used there
  if (osWindows() and $$ < 0) {
    exit($exit_status);
  }
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

# win2unixPath:
#   Converts the given file path from Windows native style to forward slashes,
#   which are understood by Windows API, Perl and the server, and don't need
#   escaping in SQL strings.
sub win2unixPath {
  my $path = shift;
  $path =~ s{\\}{/}g;
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
  if (length($msg) > 16383) {
    my ($prefix, $suffix) = (substr($msg,0,2000),substr($msg,-512));
    if (substr($prefix,1999) eq '\\') { chop $prefix };
    if (substr($suffix,0,1) eq "'" or substr($suffix,0,1) eq '"') { $suffix= substr($suffix,1) };
    $msg= '[ABRIDGED] '.$prefix.' <...> '.$suffix;
  }
  return $msg;
}

# Sets the directory under which group_cleaner searches for pid files
# of processes which should be killed (only used on Windows)
sub set_cleanup_root {
  $cleanup_root= shift;
}

# Process image names which group_cleaner is allowed to kill on Windows
my $cleanable_images= qr/^(?:mariadbd|mysqld|mariabackup|mariadb-backup)(?:-debug)?\.exe$/i;

sub _windows_image_name {
  my $pid= shift;
  my $out= `tasklist /FI "PID eq $pid" /FO CSV /NH 2>NUL`;
  return ($out =~ /^"([^"]+)"/ ? $1 : undef);
}

# Windows has no process groups. Instead, we find pid files of servers
# (and mariabackup) under the cleanup root, and kill the processes
# if they are still running and are what we expect them to be
# (pid files can be stale, and pids can be reused)
sub _group_cleaner_windows {
  return STATUS_TEST_STOPPED unless $cleanup_root and -d $cleanup_root;
  my @pidfiles;
  File::Find::find({
    no_chdir => 1,
    wanted => sub { push @pidfiles, $File::Find::name if /(?:^|\/)(?:mysql\.pid|mbackup_pid)$/ }
  }, $cleanup_root);
  foreach my $f (@pidfiles) {
    my $contents= read_file($f);
    next unless defined $contents and $contents =~ /(\d+)/;
    my $pid= $1;
    next unless kill(0, $pid);
    my $image= _windows_image_name($pid);
    if (defined $image and $image =~ $cleanable_images) {
      sayDebug("Killing leftover process $pid ($image) from $f");
      kill('KILL', $pid);
    }
  }
  return STATUS_TEST_STOPPED;
}

sub group_cleaner {
  return _group_cleaner_windows() if osWindows();

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

sub shortClassName {
  return (split /::/, ref($_[0]))[-1];
}

########################################################################
# Portability helpers
#
# These replace inline shell constructs (cp -r, rm -rf, mv, cat, sort,
# diff, tee, LD_LIBRARY_PATH=... prefix, '...' quoting), so that the
# same code can work on Linux and on Windows. On Linux they keep the
# previous behavior.
########################################################################

# Prepends the LD_LIBRARY_PATH setting for MSAN-instrumented libraries
# to a shell command line which runs a server or a client tool.
# It is done per command (rather than once in %ENV), so that other tools
# (gdb, diff, etc.) are not affected by instrumented libraries.
# On Windows the prefix is not valid shell syntax and is not needed.
sub with_msan_libs {
  my $cmd= shift;
  return $cmd if osWindows();
  return "LD_LIBRARY_PATH=\$MSAN_LIBS:\$LD_LIBRARY_PATH $cmd";
}

# Quotes an argument for the platform shell (sh on Unix, cmd.exe on Windows)
sub shell_quote {
  my $arg= shift;
  if (osWindows()) {
    $arg =~ s/"/\\"/g;
    return '"'.$arg.'"';
  } else {
    $arg =~ s/'/'\\''/g;
    return "'".$arg."'";
  }
}

# Appends .exe to a binary name on Windows, unless it already has an extension
sub exe_name {
  my $name= shift;
  return $name unless osWindows();
  return ($name =~ /\.(?:exe|bat|cmd|pl)$/i ? $name : $name.'.exe');
}

# Searches for an executable in PATH, returns its full path or undef
sub find_in_path {
  my $prog= shift;
  foreach my $dir (File::Spec->path()) {
    my $f= File::Spec->catfile($dir, exe_name($prog));
    return $f if -f $f and (osWindows() or -x $f);
  }
  return undef;
}

# Returns the contents of a file (a list of lines in the list context),
# or undef if the file cannot be read
sub read_file {
  my $file= shift;
  my $fh;
  unless (open($fh, '<', $file)) {
    sayDebug("Could not open $file for reading: $!");
    return undef;
  }
  binmode $fh;
  if (wantarray) {
    my @lines= <$fh>;
    close($fh);
    return @lines;
  }
  local $/= undef;
  my $contents= <$fh>;
  close($fh);
  return $contents;
}

# Recursive copy, an equivalent of "cp -r src dst" when dst does not exist,
# or "cp -r src/* dst/" when it does. Regular files are copied with
# permission bits. Returns 0 on success, non-zero on failure (like system())
sub copy_dir {
  my ($src, $dst)= @_;
  unless (-d $src) {
    sayError("copy_dir: source $src is not a directory");
    return 1;
  }
  my $errors= 0;
  mkpath($dst) unless -d $dst;
  $src= File::Spec->canonpath($src);
  File::Find::find({
    no_chdir => 1,
    wanted => sub {
      my $rel= File::Spec->abs2rel($File::Find::name, $src);
      return if $rel eq '.';
      my $target= File::Spec->catfile($dst, $rel);
      if (-d $File::Find::name) {
        mkpath($target) unless -d $target;
      } elsif (! File::Copy::cp($File::Find::name, $target)) {
        sayError("copy_dir: could not copy $File::Find::name to $target: $!");
        $errors++;
      }
    }
  }, $src);
  return ($errors ? 1 : 0);
}

# Equivalent of "mv src dst". Returns 0 on success, non-zero on failure
sub move_path {
  my ($src, $dst)= @_;
  if (File::Copy::move($src, $dst)) {
    return 0;
  }
  sayError("Could not move $src to $dst: $!");
  return 1;
}

# Equivalent of "rm -rf"
sub remove_path {
  foreach my $p (@_) {
    if (-d $p) {
      remove_tree($p);
    } elsif (-e $p or -l $p) {
      unlink($p);
    }
  }
}

# Sorts lines of a file (byte-wise, like LC_ALL=C sort).
# If $out is not defined, the file is sorted in place.
# Returns 0 on success, non-zero on failure
sub sort_file {
  my ($in, $out)= @_;
  $out= $in unless defined $out;
  my @lines= read_file($in);
  unless (@lines and defined $lines[0]) {
    return 1 unless -e $in;
    @lines= ();
  }
  $lines[-1] .= "\n" if scalar(@lines) and $lines[-1] !~ /\n$/;
  my $fh;
  unless (open($fh, '>', $out)) {
    sayError("Could not open $out for writing: $!");
    return 1;
  }
  binmode $fh;
  print $fh sort @lines;
  close($fh);
  return 0;
}

# Compares two files. Returns the status (0 if equal, 1 if different,
# 2 on error, as diff does) and the diff text (empty if files are equal).
# $opts are options for diff utility, e.g. '-a -u'.
# The external diff utility is used if available (on Windows it is shipped
# e.g. with Git for Windows); otherwise a primitive line-by-line comparison
# is printed.
sub diff_files {
  my ($f1, $f2, $opts)= @_;
  $opts= '-a -u' unless defined $opts;
  unless (-e $f1 and -e $f2) {
    my $msg= "diff: ".(-e $f1 ? $f2 : $f1).": No such file or directory\n";
    return (2, $msg);
  }
  return (0, '') if compare($f1, $f2) == 0;
  my $diff_bin= (osWindows() ? find_in_path('diff') : 'diff');
  if ($diff_bin) {
    my $cmd= join(' ', shell_quote($diff_bin), $opts, shell_quote($f1), shell_quote($f2));
    my $text= `$cmd`;
    return ($? >> 8, $text);
  }
  my @l1= read_file($f1);
  my @l2= read_file($f2);
  my $text= "--- $f1\n+++ $f2\n";
  my $max= (scalar(@l1) > scalar(@l2) ? scalar(@l1) : scalar(@l2));
  my $shown= 0;
  for (my $i= 0; $i < $max and $shown < 100; $i++) {
    my ($a, $b)= ($l1[$i], $l2[$i]);
    next if defined $a and defined $b and $a eq $b;
    $text.= "@@ line ".($i+1)." @@\n";
    $text.= "-$a" if defined $a;
    $text.= "+$b" if defined $b;
    $shown++;
  }
  $text.= "(the output is truncated, install diff utility for a full diff)\n" if $shown >= 100;
  return (1, $text);
}

# Redirects STDOUT (and STDERR, if $with_stderr is true) to the terminal
# and appends it to the file, like "| tee -ai file" (tee ignores SIGINT,
# so that the output of the cleanup is not lost upon Ctrl-C).
# Implemented in Perl, as tee is not available on Windows
sub tee_stdout {
  my ($file, $with_stderr)= @_;
  my $code= 'use strict; $SIG{INT}=q(IGNORE); my $f; open($f, q(>>), $ARGV[0]) or die qq(tee: cannot open $ARGV[0]: $!); binmode $f; binmode STDIN; binmode STDOUT; my $b; while (sysread(STDIN, $b, 65536)) { syswrite(STDOUT, $b); syswrite($f, $b) }';
  my $cmd= '| '.shell_quote($^X).' -e '.shell_quote($code).' '.shell_quote($file);
  open(STDOUT, $cmd) or croak("Could not redirect output to $file: $!");
  STDOUT->autoflush(1);
  if ($with_stderr) {
    open(STDERR, ">&STDOUT") or croak("Could not redirect STDERR: $!");
  }
}

# Values with % on the Windows command line get expanded
sub adjust_args_for_windows {
  if (($^O eq 'MSWin32') || ($^O eq 'MSWin64')) {
    my $argref = shift;
    for my $i (0..$#$argref) {
	  $argref->[$i] =~ s/\%/\%%/g;
    }
  }
}

1;
