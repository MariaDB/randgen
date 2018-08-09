query_init_add:
  CREATE PROCEDURE IF NOT EXISTS { $last_sp= 'sp_grammar' } () BEGIN END 
;

query_add:
  sp_create_and_or_execute
;

sp_name:
    # This one is to be dealt with only in this thread
    { $last_sp= 'sp_'.abs($$) } 
    # This one is to be dealt with concurrently
  | { $last_sp= 'sp_grammar' }
  | { $last_sp= 'sp_grammar1' }
  | { $last_sp= 'sp_grammar2' }
;

sp_create_and_or_execute:
    sp_drop ; sp_create
  | sp_create_or_replace
  | sp_call | sp_call | sp_call | sp_call
;

sp_drop:
  DROP PROCEDURE IF EXISTS sp_name
;

sp_create:
  CREATE PROCEDURE IF NOT EXISTS sp_name () BEGIN sp_body ; END
;
sp_create_or_replace:
  CREATE OR REPLACE PROCEDURE sp_name () BEGIN sp_body ; END
;

sp_call:
    CALL $last_sp
  | CALL sp_name
;

sp_body:
  query | query | query ; sp_body
;
