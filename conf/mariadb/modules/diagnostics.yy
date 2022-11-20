query:
  diag_query
;

diag_query:
  ==FACTOR:20== GET __current(20) DIAGNOSTICS diag_list |
                SET __global(5) max_error_count= { $prng->uint16(0,65537) }
;

diag_list:
  diag_stmt_property_list |
  CONDITION diag_cond_number diag_cond_property_list ;

diag_cond_number:
  ==FACTOR:10== 1 |
  ==FACTOR:5==  2 |
  ==FACTOR:1==  3 |
  ==FACTOR:0.1== { $prng->uint16(0,65537) }
;

diag_property_list:
  { $num= $prng->uint16(1,scalar(@props))
    ; @list= ()
    ; @new_props= @{$prng->shuffleArray(\@props)}[0..$num-1]
    ; for ($n=1; $n<=$num; $n++) {
        push @list, '@var'.$n.'= '.$new_props[$n-1]
      }
    ; join ', ', @list
  }
;

diag_stmt_property_list:
  { @props= qw(NUMBER ROW_COUNT); '' } diag_property_list ;

diag_cond_property_list:
  { @props= (
      'RETURNED_SQLSTATE',
      'MYSQL_ERRNO',
      'MESSAGE_TEXT',
      'CLASS_ORIGIN',
      'SUBCLASS_ORIGIN',
      'CONSTRAINT_CATALOG',
      'CONSTRAINT_SCHEMA',
      'CONSTRAINT_NAME',
      'CATALOG_NAME',
      'SCHEMA_NAME',
      'TABLE_NAME',
      'COLUMN_NAME',
      'CURSOR_NAME',
      'ROW_NUMBER /* compatibility 10.7.1 */'
    ); ''
  } diag_property_list;
;
