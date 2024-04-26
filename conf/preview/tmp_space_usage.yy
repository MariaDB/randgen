query:
  SET GLOBAL MAX_TMP_TOTAL_SPACE_USAGE = space_usage_val |
  SET __session_x_global MAX_TMP_SESSION_SPACE_USAGE = space_usage_val ;

space_usage_val:
  DEFAULT |
  64*1024 |
  1024*1024 |
  4*1024*1024 |
  1024*1024*1024 |
  ==FACTOR:0.1== space_usage_val_invalid_value
;

space_usage_val_invalid_value:
  -2 | -1 | 0 | 1 | 2 | NULL;
