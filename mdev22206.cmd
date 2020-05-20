#!/bin/bash

if [ -z "$1" ] ; then
  echo "Usage: . ./mdev22206.cmd <basedir>"
else
  perl ./runall-new.pl --duration=300 --threads=2 --seed=1 --mysqld=--lock-wait-timeout=10 --mysqld=--innodb-lock-wait-timeout=5 --redefine=conf/mariadb/bulk_insert.yy --redefine=conf/mariadb/xa.yy --basedir=$1 --grammar=conf/runtime/information_schema.yy  --vardir1=/dev/shm/var_mdev22206
fi
