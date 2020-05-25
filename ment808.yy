# perl runall-trials.pl  --duration=350 --reporters=Deadlock --basedir=/data/bld/10.3-enterprise-rel --trials=5 --threads=4 --skip-gendata --gendata-advanced --engine=Aria --mysqld=--loose-log_output=FILE --mysqld=--loose-debug_assert_on_not_freed_memory=0 --scenario=MariaBackupIncremental --grammar=/archive/to_process/redo2.yy --vardir=/home/elenst/logs/redo1 --mtr-build-thread=51 --seed=1589504702 --output="exec_REDO_LOGREC_REDO_INDEX"
# --output=exec_REDO_LOGREC_REDO_INDEX
# --test-id=0521.133448.1433788


query:
        DELETE FROM _table ORDER BY _field LIMIT _digit |
        SELECT * FROM _table INTO OUTFILE { "'load_$last_table'" } ; LOAD DATA INFILE { "'load_$last_table'" } INTO TABLE { $last_table };;
