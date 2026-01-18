query_init:
  { _set_db('oltp_db') };

query:
  /* _table[invariant] */ oltp_query ;

oltp_query:
    ==FACTOR:10== dml |
    START TRANSACTION |
    COMMIT
;

dml:
    update | delete | insert ;

insert:
    INSERT IGNORE INTO _table ( _field_pk ) VALUES ( NULL ) |
    INSERT IGNORE INTO _table ( _field_int ) VALUES ( _smallint_unsigned ) |
    INSERT IGNORE INTO _table ( _field_char ) VALUES ( _string ) |
    INSERT IGNORE INTO _table ( _field_pk, _field_int)  VALUES ( NULL, _int ) |
    INSERT IGNORE INTO _table ( _field_pk, _field_char ) VALUES ( NULL, _string ) |
    INSERT IGNORE INTO _table ( _field_pk ) VALUES ( NULL ),( NULL ),( NULL ),( NULL )
;

update:
    index_update |
    non_index_update
;

delete:
    DELETE FROM _table WHERE _field_pk = _smallint_unsigned ;

index_update:
    UPDATE IGNORE _table SET _field_int_indexed = _field_int_indexed + 1 WHERE _field_pk = _smallint_unsigned ;

# It relies on char fields being unindexed.
# If char fields happen to be indexed in the table spec, then this update can be indexed as well. No big harm though.
non_index_update:
    UPDATE _table SET _field_char = _string WHERE _field_pk = _smallint_unsigned ;
