query:
        transaction ;

transaction:
         XA START tx_id[invariant] ; body ; XA END tx_id[invariant] ; XA PREPARE tx_id[invariant] ; XA COMMIT tx_id[invariant] ; 

tx_id:
         ' _int_unsigned ' , ' _thread_id ' ;
body:
        stmt ;
#        stmt |
#        stmt ; stmt |
#        stmt ; stmt ; stmt |
#        stmt ; stmt ; stmt ; stmt ;

stmt:
#        insert | delete ;
        insert | update | delete ;


insert:
        INSERT INTO _table (`pk`) VALUES (_digit) ;
#        INSERT INTO _table (`pk`) VALUES (value) ;
#        INSERT INTO _table ( _field_no_pk , _field_no_pk ) VALUES ( value , value ) , ( value , value ) |
#        INSERT INTO _table ( _field_no_pk ) SELECT _field_key FROM _table AS X where ;

update:
	UPDATE _table AS X SET _field_no_pk = value where;

delete:
	DELETE FROM _table where_delete;

# Use an index at all times
where:
	|
	WHERE X . _field_key < value | 	# Use only < to reduce deadlocks
	WHERE X . _field_key IN ( value , value , value , value , value ) |
	WHERE X . _field_key BETWEEN small_digit AND large_digit |
	WHERE X . _field_key BETWEEN _tinyint_unsigned AND _int_unsigned |
	WHERE X . _field_key = ( subselect ) ;

where_delete:
        |
        WHERE (`pk`) = _digit |
	WHERE _field_key = value |
	WHERE _field_key IN ( value , value , value , value , value ) |
#	WHERE _field_key IN ( subselect )  |
	WHERE _field_key BETWEEN small_digit AND large_digit ;

subselect:
	SELECT _field_key FROM _table WHERE `pk` = value ;

large_digit:
	5 | 6 | 7 | 8 ;

small_digit:
	1 | 2 | 3 | 4 ;

value:
	_digit | _tinyint_unsigned | _int_unsigned ;
