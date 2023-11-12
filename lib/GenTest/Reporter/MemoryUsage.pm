# Copyright (c) 2021, 2023, MariaDB Corporation
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

package GenTest::Reporter::MemoryUsage;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use GenUtil;
use GenTest;
use Constants;
use GenTest::Result;
use GenTest::Reporter;
use GenTest::Executor::MRDB;
use Carp;
use Data::Dumper;

my ($first_mem, $max_mem, $first_cpu, $max_cpu, $max_mem_pct, $last_reported_mem, $conn, $memusage);

sub monitor {
  my $reporter= shift;
  my $pid= $reporter->serverInfo('pid');
#  system('ps -Ffyl -p '.$reporter->serverInfo('pid'));
  my $res= get_top_output($pid);
  if (defined $res) {
    my ($mem, $cpu, $mem_pct)= @$res;
    if (not defined $first_mem) {
      $first_mem= $mem;
      $reporter->[0]= $mem;
      $max_mem= $mem;
      $max_mem_pct= $mem_pct;
      say("MemoryUsage monitor for pid $pid: First recorded memory usage: ".format_mem_value($first_mem)." / ${max_mem_pct}%");
      $last_reported_mem= $first_mem;
    } elsif ($mem > $max_mem) {
      if (defined $last_reported_mem and $mem > $last_reported_mem * 1.1) {
        sayWarning("MemoryUsage monitor for pid $pid: memory usage has grown over 10% since the last report: ".format_mem_value($mem)." / ${max_mem_pct}% (started from ".format_mem_value($first_mem).")");
        $last_reported_mem= $mem;
      }
      $max_mem= $mem;
      $max_mem_pct= $mem_pct;
    }
    if (($reporter->server->serverVariable('performance_schema') eq '1') or ($reporter->server->serverVariable('performance_schema') eq 'ON')) {
      say("MemoryUsage monitor for pid $pid: memory usage: ".format_mem_value($mem));
      $conn = $reporter->connection unless $conn;
      unless ($conn) {
        sayWarning("MemoryUsage monitor could not connect to the server");
        return STATUS_SERVER_UNAVAILABLE;
      }
      $memusage= $conn->query("select event_name, sum_number_of_bytes_alloc, current_number_of_bytes_used, high_number_of_bytes_used from performance_schema.memory_summary_global_by_event_name order by current_number_of_bytes_used desc limit 5");
      say(Dumper($memusage)) if $memusage;
    }
    if (not defined $first_cpu) {
      $first_cpu= $cpu;
      $max_cpu= $cpu;
    } elsif ($cpu > $max_cpu) {
      $max_cpu= $cpu;
    }
  }
  return STATUS_OK;
}

sub report {
  my $reporter= shift;
  my $pid= $reporter->serverInfo('pid');
  my $res= get_top_output($pid);
  if (defined $res) {
    my ($mem, $cpu, $mem_pct)= @$res;
    say("MemoryUsage monitor for pid $pid: Final recorded memory usage: ".format_mem_value($mem). " / ${mem_pct}%");
  }
  return STATUS_OK;
}

sub get_top_output {
  my $pid= shift;
  return undef unless $pid;
  my ($mem, $unit, $cpu, $mem_pct);
  if (open(TOP, 'top -b -n 1 -p '.$pid.' |')) {
    while (<TOP>) {
#      say("MemoryUsage (line from top output): $_");
      # Skipping everything but the process for now, but may parse more in future
      next unless /^\s*$pid/;
      # PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
      if (/$pid\s+\w+\s+\d+\s+\d+\s+[\d\.]+[kmbgtp]?\s+([\d\.]+)([kmbgtp]?)\s+[\d\.]+[kmbgtp]?\s+\w\s+([\d\.]+)\s+([\d\.]+)/) {
        ($mem, $unit, $cpu, $mem_pct)= ($1, $2, $3, $4);
        if ($unit eq 'm' or $unit eq 'M') {
          $mem*= 1024;
        } elsif ($unit eq 'g' or $unit eq 'G') {
          $mem*= 1024*1024;
        } elsif ($unit eq 't' or $unit eq 'T') {
          $mem*= 1024*1024*1024;
        } elsif ($unit eq 'p' or $unit eq 'P') {
          $mem*= 1024*1024*1024*1024;
        }
      }
    }
    close(TOP);
    if (defined $mem) {
      return [$mem, $cpu, $mem_pct];
    } else {
      sayWarning("MemoryUsage monitor got empty output for pid $pid");
      return undef;
    }
  } else {
    logError("MemoryUsage monitor could not run top for pid $pid");
    return undef;
  }
}

sub format_mem_value {
  my $mem= shift;
  my @units= ('KiB','MiB','GiB','TiB','PiB');
  my $unit= 0;
  while ($mem > 1024) {
    $mem /= 1024;
    $unit++;
  }
  return sprintf("%.1f ",$mem).($units[$unit] || ' <in unknown units>');
}

sub type {
  return REPORTER_TYPE_PERIODIC | REPORTER_TYPE_ALWAYS;
}

1;
