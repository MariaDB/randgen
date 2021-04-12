query:
  UPDATE IGNORE _table SET _field = data_value ORDER BY _field ;

thread1:
  BACKUP STAGE START; BACKUP STAGE BLOCK_COMMIT; BACKUP STAGE END ;

data_value:
  NULL | DEFAULT | '' | 0 ;
