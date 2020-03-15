query:
    insert | insert | insert | insert |
    DELETE FROM _table WHERE _field_pk = _smallint_unsigned
;

insert:
    INSERT IGNORE INTO _table ( _field_pk ) VALUES ( NULL ) ;
