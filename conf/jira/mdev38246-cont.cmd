# Usage . --basedir=<basedir> --vardir=<vardir> [other options]

perl ./run.pl --base-port=38240 --compatibility=101115 --duration=20 --engine=Aria --grammar=conf/jira/mdev38246-cont.yy --mysqld=--aria-encrypt-tables=1  --mysqld=--file-key-management --mysqld=--file-key-management-filename=`pwd`/util/file_key_management_keys.txt --mysqld=--plugin-load-add=file_key_management  --queries=1 --scenario=MariaBackupFull --basedir=$1 --threads=1 --seed=1769956632 --rows=0 --nometadata-reload $*

