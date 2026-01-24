#!/usr/bin/bash
#
# Copyright (c) 2025 MariaDB
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
#
########################################################################

# The script pre-generates a list of combinations and then executes them one by one.
# It allows more reliable cleanup between runs which is sometimes needed
# especially in remote systems like Jenkins, Azure etc.

set -o pipefail

set +e

opts=""
port_group=14000
workdir=""
archive=""
discard_logs=""
signatures="util/bug_signatures"

for arg in "$@" ; do
  val=`echo "$arg" | sed -e "s;--[^=]*=;;"`
  case $arg in
    --base-port=*)          port_group="$val" ;;
    --workdir=*|--vardir=*) workdir="$val" ;;
    --archive=*)            archive="$val" ;;
    --discard-logs*)        discard_logs=1 ;;
    --signatures=*)        signatures=$val ;;
    *)                      opts="$opts $arg" ;;
  esac
done

if [ -z "$workdir" ] ; then
  echo "ERROR: We really need a workdir"
  exit 1
else
  if [ -z "$archive" ] ; then
    archive="${workdir}/archive"
  fi

  # Remove last digit from the port number to make it a group,
  # hopefully 10 in the group is enough
  port_group=`echo $port_group | sed -e 's/[0-9]$//g'`

  mkdir -p $workdir $archive
  perl ./combinations.pl $opts --workdir=$workdir --dry-run > $workdir/combinations.txt
  comb_count=`grep -c "arguments:" $workdir/combinations.txt`
  echo "Number of combinations generated: $comb_count"

  t=0
  set -x
  result=0
  exec 3< $workdir/combinations.txt
  while IFS= read -r line <&3; do
    if [[ "$line" =~ Combinations.*:\ running ]] ; then
      echo ""
      echo "#####################################################"
      echo $line | sed -e 's/^.*Combinations.*: running/Running/g'
    elif [[ "$line" =~ Combinations.*:\ arguments: ]] ; then
      t=$((t+1))
      args=`echo $line | sed -e 's/.* arguments://g'`
      timeout -k 3600 3600 perl ./util/run-crash-test.pl $args --vardir=$workdir/var --workdir=/home/binlog/work 2>&1 | tee $archive/trial${t}.log
      res=$?
      if [ "$res" -gt "$result" ] ; then
        result=$res
      fi
      sleep 1
      echo "###################################" | tee -a $archive/results.txt
      echo "Log: trial${t}.log" | tee -a $archive/results.txt
      if [ "$res" != "0" ] ; then
        perl util/check_for_known_bugs.pl --signatures=$signatures $archive/trial${t}.log 2>&1 | tee -a $archive/results.txt
      else
        grep -a 'Test run ends with exit status' $archive/trial${t}.log >> $archive/results.txt
      fi
      echo "###################################" | tee -a $archive/results.txt
    fi
  done
  exec 3<&-
  (exit $result)
fi
