#!/bin/bash

if [ -z "$1" ] ; then
  echo "Usage: . ./mdev22647.cmd <basedir>"
else
  perl ./runall-new.pl --basedir=$1 --grammar=mdev22647.yy --threads=2 --skip-gendata --vardir=/dev/shm/var_mdev22647 --duration=30
fi
