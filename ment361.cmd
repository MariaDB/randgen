# $1 is the basedir

perl ./runall-new.pl --grammar=./ment361.yy --duration=120 --threads=4 --ps-protocol --mysqld=--plugin-load-add=server_audit --mysqld=--server_audit_logging=ON --skip-gendata --vardir=/dev/shm/ment361 --basedir=$1
