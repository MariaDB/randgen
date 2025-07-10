#!/usr/bin/bash
#
# Copyright (c) 2021, 2025 MariaDB
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

for arg in "$@" ; do
  val=`echo "$arg" | sed -e "s;--[^=]*=;;"`
  case $arg in
    --base-port=*)          port_group="$val" ;;
    --workdir=*|--vardir=*) workdir="$val" ;;
    --archive=*)            archive="$val" ;;
    --discard-logs*)        discard_logs=1 ;;
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
  set +x
  result=0
  while IFS= read -r line; do
    if [[ "$line" =~ Combinations.*:\ running ]] ; then
      echo ""
      echo "#####################################################"
      echo $line | sed -e 's/^.*Combinations.*: running/Running/g'
    elif [[ "$line" =~ Combinations.*:\ arguments: ]] ; then
      t=$((t+1))
      args=`echo $line | sed -e 's/.* arguments://g'`
      timeout -k 3600 3600 perl ./run.pl $args --vardir=$workdir/var
      res=$?
      if [ "$res" -gt "$result" ] ; then
        result=$?
      fi
      sleep 1
      kill -11 `ps -ef | grep -E 'mysqld|mariadbd' | grep -E "port=$port_prefix" | grep -v grep | awk '{print $2}' | xargs`
      kill `ps -ef | grep run.pl | grep -v grep | awk '{print $2}' | xargs` || true
      sleep 1
      cp $workdir/var/trial.log  $archive/trial${t}.log
      if [ -z "$discard_logs" ] && [ "$res" != "0" ] ; then
        cp -r $workdir/var $archive/vardir1_${t}
      fi
    fi
  done < $workdir/combinations.txt
  (exit $result)
fi
