$combinations = [
    ['
        --no-mask
        --seed=time
        --threads=2
        --duration=200
        --queries=100M
        --reporters=Backtrace,ErrorLog,Deadlock
        --grammar=conf/mariadb/oltp.yy
        --gendata=conf/mariadb/oltp.zz
        --genconfig=conf/mariadb/10.2-innodb.cnf.template
        --mysqld=--plugin-load=add=file_key_management
        --mysqld=--loose-file-key-management-filekey=/data/encryption_keys.txt
    '],
]
