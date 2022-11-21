query:
  ==FACTOR:0.01== CREATE OR REPLACE TABLE { $last_table = $prng->arrayElement($executors->[0]->metaTables($last_database)); $last_table.'_MRG_BASE' } LIKE { $last_table }; ALTER TABLE { $last_table.'_MRG_BASE' } ENGINE=MyISAM; CREATE OR REPLACE TABLE { $last_table.'_MRG' } LIKE { $last_table.'_MRG_BASE' } ; ALTER TABLE { $last_table.'_MRG' } ENGINE=MERGE, UNION({ $last_table });
