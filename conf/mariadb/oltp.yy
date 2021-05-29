query_init:
  db ;

query:
    db |
    ==FACTOR:10== update |
    delete |
    ==FACTOR:2== insert
;

db:
  USE { $last_database = 'db1' } | USE { $last_database = 'db2' } ;

insert:
    insert_op INTO _table ( _field ) VALUES ( data_value_or_default ) |
    insert_op INTO _table ( _field, _field_next)  VALUES ( data_value_or_default, data_value_or_default ) |
    insert_op INTO _table (_field) SELECT /* _table */ _field FROM { $last_table } opt_limit |
    insert_op INTO _table SELECT * FROM { $last_table } opt_limit
;

opt_limit:
  ==FACTOR:0.1== |
  LIMIT _tinyint_unsigned |
  ==FACTOR:0.2== LIMIT _smallint_unsigned
;

data_value_or_default:
  ==FACTOR:5== val |
  DEFAULT
;

val:
  NULL | _smallint_unsigned | _string | 0 | '' |
  ==FACTOR:10== { "'".$prng->uint16(0,50000)."'" }
;

insert_op:
  ==FACTOR:4== INSERT IGNORE |
  REPLACE
;

update_where_cond:
  _field_pk = val | _field_pk <= val | _field_pk >= val | _field_pk != val | _field_pk <=> val
;

update:
    UPDATE IGNORE _table SET _field_no_pk = val WHERE update_where_cond |
    UPDATE IGNORE _table SET _field_no_pk = val, _field_no_pk = val WHERE update_where_cond
;

delete:
    ==FACTOR:3== DELETE FROM _table WHERE update_where_cond ORDER BY _field_pk LIMIT _tinyint_unsigned |
    DELETE FROM _table WHERE update_where_cond ORDER BY _field_pk LIMIT { $prng->uint16(100,1000) }
;
