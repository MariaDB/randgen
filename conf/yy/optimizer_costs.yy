# Copyright (c) 2023, MariaDB Corporation Ab.
# Use is subject to license terms.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
# USA

#################################################################
# MDEV-26974 Improve selectivity and related costs in optimizer
#################################################################

#compatibility 11.0.0

query:
  SET optimizer_cost |
  SELECT opt_engine cost_var |
  SELECT cost_select_list FROM information_schema.optimizer_costs opt_engine_clause ;

cost_select_list:
  cost_var |
  engine |
  cost_select_list, cost_var |
  cost_select_list, engine
;

opt_engine_clause:
    ==FACTOR:3==
  | WHERE ENGINE = @@default_storage_engine
  | WHERE ENGINE = 'default'
  | WHERE ENGINE IN (SELECT ENGINE FROM INFORMATION_SCHEMA.ENGINES ) ;

optimizer_cost:
    GLOBAL opt_engine OPTIMIZER_DISK_READ_COST= val10000
  | GLOBAL opt_engine OPTIMIZER_DISK_READ_COST= { $prng->uint16(7000,15000) / 1000 } # 10.240000
  | GLOBAL opt_engine OPTIMIZER_DISK_READ_RATIO= val1
  | GLOBAL opt_engine OPTIMIZER_DISK_READ_RATIO= { $prng->uint16(150,300) / 10000 } # 0.020000
  | GLOBAL opt_engine OPTIMIZER_INDEX_BLOCK_COPY_COST= val1000
  | GLOBAL opt_engine OPTIMIZER_INDEX_BLOCK_COPY_COST= { $prng->uint16(200,500) / 10000 } # 0.035600
  | GLOBAL opt_engine OPTIMIZER_KEY_COMPARE_COST= val1000
  | GLOBAL opt_engine OPTIMIZER_KEY_COMPARE_COST= { $prng->uint16(70,170) / 10000 } # 0.011361
  | GLOBAL opt_engine OPTIMIZER_KEY_COPY_COST= val1000
  | GLOBAL opt_engine OPTIMIZER_KEY_COPY_COST= { $prng->uint16(90,200) / 10000 } # 0.015685
  | GLOBAL opt_engine OPTIMIZER_KEY_LOOKUP_COST= val1000
  | GLOBAL opt_engine OPTIMIZER_KEY_LOOKUP_COST= { $prng->uint16(250,700) / 1000 } # 0.435777
  | GLOBAL opt_engine OPTIMIZER_KEY_NEXT_FIND_COST= val1000
  | GLOBAL opt_engine OPTIMIZER_KEY_NEXT_FIND_COST= { $prng->uint16(500,1200) / 10000 } # 0.082347
  | GLOBAL opt_engine OPTIMIZER_ROWID_COMPARE_COST= val1000
  | GLOBAL opt_engine OPTIMIZER_ROWID_COMPARE_COST= { $prng->uint16(150,300) / 100000 } # 0.002653
  | GLOBAL opt_engine OPTIMIZER_ROWID_COPY_COST= val1000
  | GLOBAL opt_engine OPTIMIZER_ROWID_COPY_COST= { $prng->uint16(150,300) / 100000 } # 0.002653
  | GLOBAL opt_engine OPTIMIZER_ROW_COPY_COST= val1000
  | GLOBAL opt_engine OPTIMIZER_ROW_COPY_COST= { $prng->uint16(400,1000) / 10000 } # 0.060866
  | GLOBAL opt_engine OPTIMIZER_ROW_LOOKUP_COST= val1000
  | GLOBAL opt_engine OPTIMIZER_ROW_LOOKUP_COST= { $prng->uint16(80,180) / 1000 } # 0.130839
  | GLOBAL opt_engine OPTIMIZER_ROW_NEXT_FIND_COST= val1000
  | GLOBAL opt_engine OPTIMIZER_ROW_NEXT_FIND_COST= { $prng->uint16(300,700) / 10000 } # 0.045916
  | __global(50) OPTIMIZER_SCAN_SETUP_COST= val100000000
  | __global(50) OPTIMIZER_SCAN_SETUP_COST= { $prng->uint16(7000,15000) / 1000 } # 10.000000
  | __global(50) OPTIMIZER_WHERE_COST= val100000
  | __global(50) OPTIMIZER_WHERE_COST= { $prng->uint16(200,500) / 10000 } # 0.032000
;

cost_var:
  OPTIMIZER_DISK_READ_COST |
  OPTIMIZER_INDEX_BLOCK_COPY_COST |
  OPTIMIZER_KEY_COMPARE_COST |
  OPTIMIZER_KEY_COPY_COST |
  OPTIMIZER_KEY_LOOKUP_COST |
  OPTIMIZER_KEY_NEXT_FIND_COST |
  OPTIMIZER_DISK_READ_RATIO |
  OPTIMIZER_ROW_COPY_COST |
  OPTIMIZER_ROW_LOOKUP_COST |
  OPTIMIZER_ROW_NEXT_FIND_COST |
  OPTIMIZER_ROWID_COMPARE_COST |
  OPTIMIZER_ROWID_COPY_COST
;

val100000000:
  0 | 100000000 | DEFAULT | val_rand * 100000000 ;

val100000:
  0 | 100000 | DEFAULT | val_rand * 100000 ;

val10000:
  0 | 10000 | DEFAULT | val_rand * 10000 ;

val1000:
  0 | 1000 | DEFAULT | val_rand * 1000 ;

val1:
  0 | 1 | DEFAULT | val_rand ;

val_rand:
  RAND({ $prng->uint16(0,1000000) }) ;

opt_engine:
  ==FACTOR:10==
  | InnoDB .
  | MyISAM .
  | Aria .
  | HEAP .
  | MEMORY .
  | MERGE .
  | MRG_MyISAM .
  | ARCHIVE .
  | BLACKHOLE .
  | COLUMNSTORE .
  | CONNECT .
  | CSV .
  | EXAMPLE .
  | FEDERATED .
  | FEDERATEDX .
  | S3 .
  | MROONGA .
  | OQGRAPH .
  | PERFSCHEMA .
  | PERFORMANCE_SCHEMA .
  | RocksDB .
  | SEQUENCE .
  | SPHINX .
  | SPIDER .
;
  
