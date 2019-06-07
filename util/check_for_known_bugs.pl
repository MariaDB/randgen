#!/usr/bin/perl

# Copyright (c) 2018, 2019, MariaDB Corporation Ab.
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

#################### FOR THE MOMENT THIS SCRIPT IS FOR TESTING PURPOSES

# Returns 0 if known bugs have been found, and 1 otherwise
# Non-option arguments are the files to check first, typically
# server error logs, stack traces and such.
# Files provided as option --last <file> (possibly multiple files)
# are to check last, if the arguments didn't help to detect anything

#!/usr/bin/perl

use DBI;
use Getopt::Long;
use strict;

my @last_choice_files= ();
my @signature_files= ();
my @signatures;

GetOptions (
  "last=s@" => \@last_choice_files,
  "signatures=s@" => \@signature_files,
);

@signature_files= resolve_files(@signature_files);
if (! scalar(@signature_files)) {
    print "FATAL ERROR: a path to file(s) with bug signatures must be provided\n";
    exit 1;
}

my @files= resolve_files(@ARGV);
@last_choice_files= resolve_files(@last_choice_files);

if (! scalar @files and ! scalar @last_choice_files) {
  print "No files found to check for signatures\n";
  exit 0;
}
#else {
#  print "The following files will be checked for signatures of known bugs: @files and as a last resort @last_choice_files\n";
#}

foreach my $f (@signature_files) {
    if (open(SIGNATURES, $f)) {
        while (<SIGNATURES>) {
            chomp $_;
            push @signatures, $_;
        }
        close(SIGNATURES);
    } else {
        print "ERROR: Could not open signature file $f: $!\n";
    }
}

my $ci= 'N/A';
my $page_url= "NULL";
if ($ENV{TRAVIS} eq 'true') {
  $ci= 'Travis';
  $page_url= "'https://travis-ci.org/elenst/travis-tests/jobs/".$ENV{TRAVIS_JOB_ID}."'";
} elsif (defined $ENV{AZURE_HTTP_USER_AGENT}) {
  $ci= 'Azure';
  $page_url= "'https://dev.azure.com/elenst/MariaDB tests/_build/results?buildId=".$ENV{BUILD_BUILDID}."'";
} elsif (defined $ENV{LOCAL_CI}) {
    $ci= 'Local-'.$ENV{LOCAL_CI};
}
my $test_result= (defined $ENV{TEST_RESULT} and $ENV{TEST_RESULT} !~ /\s/) ? $ENV{TEST_RESULT} : 'N/A';
my $server_branch= $ENV{SERVER_BRANCH} || 'N/A';
my $test_line= $ENV{SYSTEM_DEFINITIONNAME} || $ENV{TRAVIS_BRANCH} || $ENV{TEST_ALIAS} || 'N/A';

my %found_mdevs= ();
my %fixed_mdevs= ();
my %draft_mdevs= ();
my $matches_info= '';

my $mdev;
my $pattern;
my $signature_does_not_match= 0;
my $signature_lines_found= 0;

my $res= 1;

sub search_files_for_matches
{
  my @files= @_;
  return $res unless scalar(@files);

  foreach (@signatures) {
    if (/^\# Weak matches/) {
      # Don't search for weak matches if strong ones have been found
      if ($matches_info) {
        print "\n--- STRONG matches ---------------------------------\n";
        print $matches_info;
        $matches_info= '';
        $res= 0;
        register_matches('strong');
        last;
      }
      $mdev= undef;
      next;
    }

    # Signature line starts with =~
    # (TODO: in future maybe also !~ for anti-patterns)
    if (/^\s*=~\s*(.*)/) {
      # If we have already found a pattern which does not match, don't check this signature further
      next if $signature_does_not_match;
      # Don't check other MDEV signatures if one was already found
      next if $found_mdevs{$mdev};
      $pattern= $1;
      chomp $pattern;
      $pattern=~ s/(\"|\?|\!|\(|\)|\[|\]|\&|\^|\~|\+|\/)/\\$1/g;
    }
    # MDEV line starts a new signature
    elsif(/^\s*(MDEV-\d+|TODO-\d+):\s*(.*)/) {
      my $new_mdev= $1;
      # Process the previous result, if there was any
      if ($signature_lines_found and not $signature_does_not_match) {
        process_found_mdev($mdev);
      }
      $mdev= $new_mdev;
      $signature_lines_found= 0;
      $signature_does_not_match= 0;
      next;
    }
    else {
      # Skip comments and whatever else
      next;
    }
    system("grep -h -E -e \"$pattern\" @files > /dev/null 2>&1");
    if ($?) {
      $signature_does_not_match= 1;
    } else {
      $signature_lines_found++;
    }
  }

  # If it's non-empty at this point, it's weak matches
  if ($matches_info) {
    print "\n--- WEAK matches -------------------------------\n";
    print $matches_info;
    print "--------------------------------------\n";
    $res= 0;
    register_matches('weak');
  }
  return $res;
}

if (search_files_for_matches(@files)) {
  # No matches found in main files, add the "last choice" files to the search
  search_files_for_matches(@files, @last_choice_files);
  if ($res) {
    print "\n--- NO MATCHES FOUND ---------------------------\n";
    register_no_match();
  }
}

if (keys %fixed_mdevs) {
  foreach my $m (sort keys %fixed_mdevs) {
    print "\n--- ATTENTION! FOUND FIXED MDEV: -----\n";
    print "\t$m - $fixed_mdevs{$m}\n";
  }
  print "--------------------------------------\n";
}

exit $res;

sub connect_to_db {
  if (defined $ENV{DB_USER}) {
    my $dbh= DBI->connect("dbi:mysql:host=$ENV{DB_HOST}:port=$ENV{DB_PORT}",$ENV{DB_USER}, $ENV{DBP}, { RaiseError => 1 } );
    if ($dbh) {
      return $dbh;
    } else {
      print "ERROR: Couldn't connect to the database to register the result\n";
    }
  }
  return undef;
}

sub register_matches
{
  my $type= shift; # Strong or weak, based on it, the table and the logic are chosen
  if (my $dbh= connect_to_db()) {
    if ( $type eq 'strong' ) {
      # For strong matches, we insert each of them separately into jira field
      foreach my $j (keys %found_mdevs) {
        my $fixdate= defined $fixed_mdevs{$j} ? "'$fixed_mdevs{$j}'" : 'NULL';
        my $draft= $draft_mdevs{$j} || 0;
        $dbh->do("REPLACE INTO travis.strong_match (ci, test_id, jira, fixdate, draft, test_result, url, server_branch, test_line) VALUES (\'$ci\',\'$ENV{TEST_ID}\',\'$j\', $fixdate, $draft, \'$test_result\', $page_url, \'$server_branch\', \'$test_line\')");
      }
    } elsif ( $type eq 'weak' ) {
      my $jiras= join ',', keys %found_mdevs;
      # For weak matches, we insert the concatenation into the notes field
      $dbh->do("REPLACE INTO travis.weak_match (ci, test_id, notes, test_result, url, server_branch, test_line) VALUES (\'$ci\',\'$ENV{TEST_ID}\',\'??? $jiras\', \'$test_result\', $page_url, \'$server_branch\', \'$test_line\')");
    }
  }
}

sub register_no_match
{
  if (my $dbh= connect_to_db()) {
    $dbh->do("REPLACE INTO travis.no_match (ci, test_id, test_result, url, server_branch, test_line) VALUES (\'$ci\',\'$ENV{TEST_ID}\', \'$test_result\', $page_url, \'$server_branch\', \'$test_line\')");
  }
}

sub process_found_mdev
{
  my $mdev= shift;

  $found_mdevs{$mdev}= 1;

  unless (-e "/tmp/$mdev.resolution") {
    system("wget https://jira.mariadb.org//rest/api/2/issue/$mdev?fields=resolution -O /tmp/$mdev.resolution -o /dev/null");
  }

  my $resolution= `cat /tmp/$mdev.resolution`;
  my $resolutiondate;
  if ($resolution=~ s/.*\"name\":\"([^\"]+)\".*/$1/) {
    unless (-e "/tmp/$mdev.resolutiondate") {
      system("wget https://jira.mariadb.org//rest/api/2/issue/$mdev?fields=resolutiondate -O /tmp/$mdev.resolutiondate -o /dev/null");
    }
    $resolution= uc($resolution);
    $resolutiondate= `cat /tmp/$mdev.resolutiondate`;
    unless ($resolutiondate=~ s/.*\"resolutiondate\":\"(\d\d\d\d-\d\d-\d\d).*/$1/) {
      $resolutiondate= '';
    }
  } else {
    $resolution= 'Unresolved';
  }

  $fixed_mdevs{$mdev} = $resolutiondate if $resolution eq 'FIXED';

  unless (-e "/tmp/$mdev.summary") {
    system("wget https://jira.mariadb.org//rest/api/2/issue/$mdev?fields=summary -O /tmp/$mdev.summary -o /dev/null");
  }

  my $summary= `cat /tmp/$mdev.summary`;
  if ($summary =~ /\{\"summary\":\"(.*?)\"\}/) {
    $summary= $1;
  }

  if ($mdev =~ /TODO/ or $summary =~ /^[\(\[]?draft/i) {
    $draft_mdevs{$mdev}= 1;
  }

  if ($resolution eq 'FIXED' and not -e "/tmp/$mdev.fixVersions") {
    system("wget https://jira.mariadb.org//rest/api/2/issue/$mdev?fields=fixVersions -O /tmp/$mdev.fixVersions -o /dev/null");
  }

  unless (-e "/tmp/$mdev.affectsVersions") {
    system("wget https://jira.mariadb.org//rest/api/2/issue/$mdev?fields=versions -O /tmp/$mdev.affectsVersions -o /dev/null");
  }

  my $affectsVersions= `cat /tmp/$mdev.affectsVersions`;
  my @affected = ($affectsVersions =~ /\"name\":\"(.*?)\"/g);

  $matches_info .= "$mdev: $summary\n";

  if ($resolution eq 'FIXED') {
    my $fixVersions= `cat /tmp/$mdev.fixVersions`;
    my @versions = ($fixVersions =~ /\"name\":\"(.*?)\"/g);
    $matches_info .= "Fix versions: @versions ($resolutiondate)\n";
  }
  else {
    $matches_info .= "RESOLUTION: $resolution". ($resolutiondate ? " ($resolutiondate)" : "") . "\n";
    $matches_info .= "Affects versions: @affected\n";
  }
  $matches_info .= "-------------\n";
}

sub resolve_files {
    # If a file with an exact name does not exist, it will prevent grep from working,
    # and other obscure problems might happen. So, we want to exclude such files.
    my @f1= glob "@_";
    my @f2;
    map { push @f2, $_ if -e $_ } @f1;
    return @f2;
}
