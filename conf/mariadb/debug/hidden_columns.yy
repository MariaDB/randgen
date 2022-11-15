query_add:
  set_debug_invisible
;

set_debug_invisible:
    SET debug_dbug= "+d,test_completely_invisible"
  | SET debug_dbug= "+d,test_pseudo_invisible"
  | SET debug_dbug="+d,test_invisible_index"
  | SET debug_dbug="+d,test_completely_invisible,test_invisible_index"
  | SET debug_dbug="+d,test_pseudo_invisible,test_invisible_index"
  | SET debug_dbug="+d,test_pseudo_invisible,test_completely_invisible"
  | SET debug_dbug="+d,test_pseudo_invisible,test_completely_invisible,test_invisible_index"
  | SET debug_dbug=""
  | SET debug_dbug=""
  | SET debug_dbug=""
;

