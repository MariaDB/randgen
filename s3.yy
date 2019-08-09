query_add:
    query | query | query | query | query | query | s3_query ;

s3_query:
    ALTER TABLE _table ENGINE = s3_engine ;

s3_engine:
    S3 | Aria
;
