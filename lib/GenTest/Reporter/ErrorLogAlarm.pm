# Copyright (c) 2011,2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2022, MariaDB
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

package GenTest::Reporter::ErrorLogAlarm;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use GenUtil;
use GenTest;
use GenTest::Reporter;
use Constants;

# Modify this to look for other patterns in the error log.
# Note: do not modify $pattern to be defined using double quotes (") but leave as single quotes (')
# as double quotes require a different escaping sequence for "[" (namely "\\[" it seems)
my $pattern = '^Error:|^ERROR|\[ERROR\]|allocated at line|missing DBUG_RETURN|^safe_mutex:|Invalid.*old.*table or database|InnoDB: Warning|InnoDB: Error:|InnoDB: Operating system error|Error while setting value|\[Warning\] Invalid|debugger aborting';

# Modify this to filter out false positive patern matches (will improve over time)
my $reject_pattern =
    'Lock wait timeout exceeded'.
    '|Deadlock found when trying to get lock'.
    '|innodb_log_block_size has been changed'.
    '|Event Scheduler:'.
    '|because after adding it, the row size is'.
    '|referenced in foreign key constraints which are not compatible with the new table definition'.
    '|open and lock privilege tables'.
    '|Invalid roles_mapping table entry user'.
    '|Error in Log_event::read_log_event'.
    '|The table \'[^\(\)]+\' is full'.
    '|Incorrect information in file: .*\#sql-alter-.*frm'. # MDEV-27216 and alike
    '|Out of sort memory, consider increasing server sort buffer size'.
    '|Sort aborted:';

# Path to error log. Is assigned first time monitor() is called.
my $errorlog;

sub monitor {
    my $reporter = shift;

    if (not defined $errorlog) {
        $errorlog = $reporter->serverInfo('errorlog');
        if ($errorlog eq '') {
            # Error log was not found. Report the issue and continue.
            sayWarning("Error log not found! ErrorLogAlarm Reporter does not work as intended!");
            return STATUS_OK;
        } else {
            # INFO
            say("ErrorLogAlarm Reporter will monitor the log file ".$errorlog);
        }
    }

    if ((-e $errorlog) && (-s $errorlog > 0)) {
        open(LOG, $errorlog);
        while(my $line = <LOG>) {
            # Case insensitive search required for (observed) programming
            # incosistencies like "InnoDB: ERROR:" instead of "InnoDB: Error:"
            if(($line =~ m{$pattern}i) && ($line !~ m{$reject_pattern}i)) {
                sayError("ErrorLogAlarm reporter: Found a matching line: [ $line ]");
                close LOG;
                return STATUS_ALARM;
            }
        }
        close LOG;

        ## Alternative, non-portable implementation:
        #my $grepresult = system('grep '.$pattern.' '.$errorlog.' > /dev/null 2>&1');
        #if ($grepresult == 0) {
        #    say("ALARM $pattern found in error log file.");
        #    return STATUS_ALARM;
        #}

    }
    return STATUS_OK;
}


sub report {
    my $reporter = shift;
    my $logfile = $reporter->serverInfo('errorlog');
    my $description =
        'ErrorLogAlarm Reporter raised an alarm. Found pattern \''.$pattern.
        '\' in error log file '.$logfile;

    return STATUS_OK;
}


sub type {
    return REPORTER_TYPE_PERIODIC | REPORTER_TYPE_ALWAYS;
}

1;
