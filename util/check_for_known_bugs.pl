#!/usr/bin/perl

# Copyright (c) 2018, 2025, MariaDB Corporation Ab.
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
my @strong_signatures;
my @weak_signatures;
my $result_status= '';

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
my $server_revno= $ENV{SERVER_REVNO} || 'N/A';
my $test_line= $ENV{SYSTEM_DEFINITIONNAME} || $ENV{TRAVIS_BRANCH} || $ENV{TEST_ALIAS} || 'N/A';

system("rm -rf /tmp/MDEV-* /tmp/MENT-* /tmp/TODO-*");

#my $server_version= ;
my @server_version= ();
if (`grep -a -m 1 "^Version: '" @files @last_choice_files` =~ /^Version: '(\d+)\.(\d+)\.(\d+)(?:-(\d+))?/s) {
  @server_version= ($1, $2, $3, $4);
  print "Server version: ".join('.',@server_version)."\n";
}

my $strong= 0;

foreach my $f (@signature_files) {
    if (open(SIGNATURES, $f)) {
        while (<SIGNATURES>) {
            chomp $_;
            if (/^\s*\#\s*Strong matches/i) {
                $strong= 1;
            } elsif (/^\s*\#\s*Weak matches/i) {
                $strong= 0;
            } elsif (/^\s*\#/) {
                next;
            } elsif ($strong) {
                push @strong_signatures, $_;
            } else {
                push @weak_signatures, $_;
            }
        }
        close(SIGNATURES);
    } else {
        print "ERROR: Could not open signature file $f: $!\n";
    }
}

my %closed_mdevs= ();
my %draft_mdevs= ();
my %found_mdevs= ();
my %fixed_in_future= ();

my $match_info;

if ($match_info= search_files_for_matches(\@files, \@last_choice_files, \@strong_signatures)) {
    print_result('strong', $match_info);
    exit 0;
}
if ($match_info= search_files_for_matches(\@files, \@last_choice_files, \@weak_signatures)) {
    print_result('weak', $match_info);
    exit 0;
}

print "Status: $result_status\n\n--- NO MATCHES FOUND ---------------\n\n";
register_result('no_match');

exit 1;

############ Subroutines

sub search_files_for_matches
{
  my ($files_ref, $last_choice_files_ref, $signatures_ref)= @_;
  return undef unless scalar(@$signatures_ref);
  my @signatures= @$signatures_ref;

  foreach my $ref ($files_ref, $last_choice_files_ref)
  {
      my @files= @$ref;
      next unless scalar (@files);
      $result_status= `grep -a -h \"ends with exit status STATUS_\" @files | tail -n 1`;
      if ($result_status) {
        chomp $result_status;
        $result_status =~ s/.*ends with exit status (STATUS_\w+).*/$1/;
      }

      my $matches_info= '';

      my $mdev;
      my $nickname;
      my $pattern;
      my $signature_does_not_match= 0;
      my $signature_lines_found= 0;
      my $goal= '';

      foreach (@signatures) {
        # Signature line starts with =~ or !~
        # (TODO: in future maybe also !~ for anti-patterns)
        if (/^\s*(=~|!~)\s*(.*)/) {
          # If we have already found a pattern which does not match, don't check this signature further
          next if $signature_does_not_match;
          # Don't check other MDEV signatures if one was already found
          next if defined $found_mdevs{$mdev};
          $goal= ($1 eq '=~' ? 'match' : 'nomatch');
          $pattern= $2;
          chomp $pattern;
          $pattern=~ s/(\"|\?|\!|\(|\)|\&|\^|\~|\+|\/)/\\$1/g;
        }
        # MDEV line starts a new signature
        elsif(/^\s*(MDEV-\d+|MENT-\d+|TODO-\d+):\s*(.*)/) {
          my $new_mdev= $1;
          my $new_nickname= $2;
          # Process the previous result, if there was any
          if ($signature_lines_found and not $signature_does_not_match) {
            process_found_mdev($mdev, $nickname, \$matches_info);
          }
          $mdev= $new_mdev;
          $nickname= $new_nickname;
          $signature_lines_found= 0;
          $signature_does_not_match= 0;
          next;
        }
        else {
          # Skip anything that is not JIRA name or signature line
          next;
        }
        system("grep -a -h -E -e \"$pattern\" @files > /dev/null 2>&1");
        if (($goal eq 'match' and $?) or ($goal eq 'nomatch' and $? == 0)) {
          $signature_does_not_match= 1;
        } else {
          $signature_lines_found++;
        }
      }
      # Process last signature
      if ($signature_lines_found and not $signature_does_not_match) {
        process_found_mdev($mdev, $nickname, \$matches_info);
      }
      # Don't go through last choice files if matches were found in the main set
      return $matches_info if $matches_info;
  }
  # If we are here, nothing was found
  return undef;
}

sub print_result {
  my ($match_type, $matches_info)= @_; # match_type: strong or weak
  if ($matches_info) {
    print "Status: $result_status\n\n--- " . uc($match_type)." matches -------------------\n";
    print $matches_info;
    print "--------------------------------------\n\n";
    register_result($match_type);
  }

  if (keys %closed_mdevs) {
    foreach my $m (sort keys %closed_mdevs) {
      print "\n--- ATTENTION! FOUND CLOSED MDEV: -----\n";
      print "\t$m - $closed_mdevs{$m}\n";
      if ($fixed_in_future{$m}) {
        print "The fix version is in the future\n";
      }
    }
    print "--------------------------------------\n";
  }
}

sub connect_to_db {
  if ($ENV{DB_USER}) {
    my $dbh= DBI->connect("dbi:mysql:host=$ENV{DB_HOST}:port=$ENV{DB_PORT}:mysql_local_infile=1",$ENV{DB_USER}, $ENV{DBP}, { RaiseError => 1 } );
    if ($dbh) {
      return $dbh;
    } else {
      print "ERROR: Couldn't connect to the database to register the result\n";
    }
  }
  return undef;
}

sub register_result
{
    my $type= shift; # strong, weak or no_match
    if (my $dbh= connect_to_db()) {
        unlink('/tmp/test_result_digest');
        foreach my $f (@files) {
          system("cat $f >> /tmp/test_result_digest");
        }
        if ($type eq 'no_match') {
#            my $query= "INSERT INTO regression.result (ci, test_id, match_type, test_result, url, server_branch, server_rev, test_info) VALUES (\'$ci\',\'$ENV{TEST_ID}\', \'no_match\', \'$test_result\', $page_url, \'$server_branch\', \'$server_revno\', \'$test_line\')";
            my $query= "LOAD DATA LOCAL INFILE '/tmp/test_result_digest' INTO TABLE regression.result FIELDS TERMINATED BY 'xxxxxthisxxlinexxxshouldxxneverxxeverxxappearxxinxxanyxxfilexxxxxxxxxxxxxxxxxxxxxxxx' ESCAPED BY '' LINES TERMINATED BY 'XXXTHISXXLINEXXSHOULDXXNEVERXXEVERXXAPPEARXXINXXANYXXFILEXXXXXXXXXXXXXXXXXXXX' (digest) SET ci = '$ci', test_id = '$ENV{TEST_ID}', match_type = 'no_match', test_result = '$test_result', url = $page_url, server_branch = '$server_branch', server_rev = '$server_revno', test_info = '$test_line'";
            $dbh->do($query);
        }
        else {
            # First check if there were strong non-draft non-fixed matches.
            # If they exist, we will only register them.
            # Otherwise, we will register everything
            my %mdevs_to_register= ();
            if ($type eq 'strong') {
              foreach my $j (keys %found_mdevs) {
                if (not $draft_mdevs{$j} and not defined $closed_mdevs{$j}) {
                  $mdevs_to_register{$j}= $found_mdevs{$j};
                }
              }
            }
            if (scalar(keys %mdevs_to_register) == 0) {
              %mdevs_to_register= %found_mdevs;
            }

            foreach my $j (keys %mdevs_to_register) {
                my $fixdate= 'NULL';
                my $match_type= $type;
                if ($draft_mdevs{$j}) {
                    $match_type= 'draft';
                }
                my $notes= ($match_type eq 'strong' ? $j : $mdevs_to_register{$j}.' - '.$j);
                if (defined $closed_mdevs{$j} and not defined $fixed_in_future{$j}) {
                    $fixdate= "'$closed_mdevs{$j}'";
                    $match_type= 'fixed';
                }
                # Only register matches to fixed items if there is no better choice
                if ($match_type ne 'fixed' or scalar(keys %closed_mdevs) == scalar(keys %mdevs_to_register)) {
#                    my $query= "INSERT INTO regression.result (ci, test_id, notes, fixdate, match_type, test_result, url, server_branch, server_rev, test_info) VALUES (\'$ci\',\'$ENV{TEST_ID}\',\'$notes\', $fixdate, \'$match_type\', \'$test_result\', $page_url, \'$server_branch\', \'$server_revno\', \'$test_line\')";
                    my $query= "LOAD DATA LOCAL INFILE '/tmp/test_result_digest' INTO TABLE regression.result FIELDS TERMINATED BY 'xxxxxthisxxlinexxxshouldxxneverxxeverxxappearxxinxxanyxxfilexxxxxxxxxxxxxxxxxxxxxxxx' ESCAPED BY '' LINES TERMINATED BY 'XXXTHISXXLINEXXSHOULDXXNEVERXXEVERXXAPPEARXXINXXANYXXFILEXXXXXXXXXXXXXXXXXXXX' (digest) SET ci = '$ci', test_id = '$ENV{TEST_ID}', notes = '$notes', fixdate = $fixdate, match_type = '$match_type', test_result = '$test_result', url = $page_url, server_branch = '$server_branch', server_rev = '$server_revno', test_info = '$test_line'";
                    $dbh->do($query);
                }
            }
        }
        unlink('/tmp/test_result_digest');
    }
}

sub process_found_mdev
{
  my ($mdev, $nickname, $info_ref)= @_;

  $nickname =~ s/([\'\"])/\\$1/g;
  $found_mdevs{$mdev}= $nickname;

  if ($mdev =~ /^(?:MENT|TODO)-/) {
      # No point trying to retrieve information
      $$info_ref .= "\n$mdev: $nickname\n";
      if ($mdev =~ /^TODO-/) {
          $draft_mdevs{$mdev}= 1;
      }
  }
  else {
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

      $closed_mdevs{$mdev} = $resolutiondate if $resolution ne 'Unresolved';

      unless (-e "/tmp/$mdev.summary") {
        system("wget https://jira.mariadb.org//rest/api/2/issue/$mdev?fields=summary -O /tmp/$mdev.summary -o /dev/null");
      }

      my $summary= `cat /tmp/$mdev.summary`;
      if ($summary =~ /\{\"summary\":\"(.*?)\"\}/) {
        $summary= $1;
      }

      if ($summary =~ /^[\(\[]?draft/i) {
        $draft_mdevs{$mdev}= 1;
      }

      if ($resolution ne 'Unresolved' and not -e "/tmp/$mdev.fixVersions") {
        system("wget https://jira.mariadb.org//rest/api/2/issue/$mdev?fields=fixVersions -O /tmp/$mdev.fixVersions -o /dev/null");
      }

      unless (-e "/tmp/$mdev.affectsVersions") {
        system("wget https://jira.mariadb.org//rest/api/2/issue/$mdev?fields=versions -O /tmp/$mdev.affectsVersions -o /dev/null");
      }

      my $affectsVersions= `cat /tmp/$mdev.affectsVersions`;
      my @affected = ($affectsVersions =~ /\"name\":\"(.*?)\"/g);

      $$info_ref .= "\n$mdev: $nickname\n$summary\n";

      $$info_ref .= "RESOLUTION: $resolution". ($resolutiondate ? " ($resolutiondate)" : "") . "\n";
      $$info_ref .= "Affects versions: @affected\n";
      if ($resolution ne 'Unresolved') {
        my $fixVersions= `cat /tmp/$mdev.fixVersions`;
        my @versions = ($fixVersions =~ /\"name\":\"(.*?)\"/g);
        $$info_ref .= "Fix versions: @versions ($resolutiondate)\n";
        foreach my $v (sort @versions) {
          $v =~ /(\d+)\.(\d+)\.(\d+)/;
          if (
            # If minor fix version is higher than minor server version,
            # the fix is most likely not in the branch yet
            ($1 == $server_version[0] and $2 == $server_version[1] and $3 > $server_version[2])
            # If minor fix version is the same as the server version
            # and there is a 4th component in the server version (ES),
            # the can be not in the branch yet. If it is, the entry
            # should already be removed from bug signatures
            or ($1 == $server_version[0] and $2 == $server_version[1] and $3 == $server_version[2] and defined $server_version[3])
            # If minor fix version is the same as the server version
            # and there is a lower major fix version,
            # it's quite possible that the bug has been fixed in the lowest version,
            # but not merged up yet
            or ($1 == $server_version[0] and $2 == $server_version[1] and $3 == $server_version[2] and $v ne $versions[0])
          ) {
            $fixed_in_future{$mdev}= 1;
          }
        }
      }
   }
#   $$info_ref .= "-------------\n";
}

sub resolve_files {
    # If a file with an exact name does not exist, it will prevent grep from working,
    # and other obscure problems might happen. So, we want to exclude such files.
    my @f1= glob "@_";
    my @f2;
    map { push @f2, $_ if -e $_ } @f1;
    return @f2;
}
