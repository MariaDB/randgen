query:
  get_lock_r |
  release_lock_r |
  release_lock_r |
  INSERT INTO _table ( _field ) VALUES ( NULL ),( NULL ),( NULL ),( NULL ),( NULL ) |
  DELETE FROM _table ORDER BY _field LIMIT _digit
;

get_lock_r:
  DO GET_LOCK('a',5) ;

release_lock_r:
  DO RELEASE_LOCK('a') ;
