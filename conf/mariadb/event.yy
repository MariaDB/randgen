query_init_add:
  { $ev = 0; '' } SET GLOBAL event_scheduler = ON
;

query_add:
  event_create
;

event_name:
  { 'ev_'.abs($$).'_'.$ev }
;

event_create:
  { $ev++; '' } CREATE EVENT event_name ON SCHEDULE EVERY _positive_digit SECOND ENDS CURRENT_TIMESTAMP + INTERVAL _tinyint_unsigned SECOND DO event_body
;

event_body:
  query | query | query ; event_body
;
