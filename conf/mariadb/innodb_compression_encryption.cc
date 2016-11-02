#
# Configuration file for MDEV-11203
# and InnoDB compression/encryption in general
#

$combinations = [
    [
    '
        --no-mask
        --seed=time
        --threads=8
        --duration=600
        --queries=100M
        --reporters=QueryTimeout,Backtrace,ErrorLog,Deadlock,RestartConsistency
        --restart-timeout=30
        --mysqld=--log_output=FILE
        --grammar=conf/mariadb/innodb_compression_encryption.yy
        --gendata=conf/mariadb/innodb_compression_encryption.zz
        --mysqld=--innodb-use-atomic-writes
        --mysqld=--innodb-use-trim
        --mysqld=--innodb_flush_method=O_DIRECT
        --mysqld=--innodb_doublewrite=0
        --mysqld=--plugin-load-add=file_key_management.so
        --mysqld=--loose-file-key-management-filename=$RQG_HOME/conf/mariadb/encryption_keys.txt
        --mysqld=--innodb-encryption-threads=4
    '], 
    [ '','--mysqld=--innodb_use_fallocate' ],
    [ '','--mysqld=--innodb-encrypt-log' ],
    [ '','--mysqld=--innodb-encrypt-tables' ],
];
