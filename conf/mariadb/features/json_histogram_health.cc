# MDEV-26519 JSON histograms
# Test run for histogram health check and basic server stability

use strict;

our ($non_innodb_encryption_options, $innodb_encryption_options, $common_options, $ps_protocol_options, $perfschema_options_107);
our ($grammars_any_gendata, $grammars_specific_gendata, $gendata_files, $auto_gendata_combinations, $optional_redefines_107);
our ($views_combinations, $vcols_combinations, $threads_low_combinations, $binlog_combinations);
our ($optional_variators_107, $basic_engine_combinations_107);
our ($non_crash_scenario_combinations_107, $scenario_combinations_107);
our ($optional_innodb_variables_107, $optional_plugins_107, $optional_server_variables_107, $optional_charsets_107);

require "$ENV{RQG_HOME}/conf/mariadb/include/parameter_presets";
require "$ENV{RQG_HOME}/conf/mariadb/include/combo.grammars";

$combinations = [
  [ $common_options ], # seed, reporters, timeouts
  [ '
    --duration=180
    --reporters=JsonHistogram
    --rows=1,8,64,128,254,255,256,512,1200
    --redefine=conf/mariadb/features/histogram_analyze.yy
    --mysqld=--histogram-type=JSON_HB
    '
  ],
  [ '--mysqld=--histogram-size=64',
    '--mysqld=--histogram-size=128',
    '--mysqld=--histogram-size=255', '',
    '--mysqld=--histogram-size=8',
    '--mysqld=--histogram-size=1',
  ],
  [ @$threads_low_combinations ],
  [ @$views_combinations, '', '', '' ],
  [ @$vcols_combinations, '--vcols=STORED',
   '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''
  ],

  # Combinations of grammars and gendata
  [
    {
      specific =>
        [ @$grammars_specific_gendata ],

      generic => [
        [ @$grammars_any_gendata ],
        [ '--short-column-names' ],
        [ @$gendata_files ],
        [ @$auto_gendata_combinations,
          '--gendata-advanced', '--gendata-advanced', '--gendata-advanced'
        ],
      ],
    }
  ],
  ##### Transformers
  [ {
      transform => [
        [ '--validators=TransformerNoComparator' ], @$optional_variators_107,
      ],
      notransform => [ '' ]
    }
  ],
  ##### Engines and engine=specific options
  [
    {
      engines => [
        [ @$basic_engine_combinations_107 ],
        [ @$non_crash_scenario_combinations_107,
          '', '', '', '', '', '', '', '', '', '', ''
        ],
      ],
      innodb => [
        [ '--engine=InnoDB' ],
        [ @$scenario_combinations_107,
          '', '', '', '', '', '', '', '', '', '', '', '', '', '', '',
        ],
        @$optional_innodb_variables_107,
      ],
    }
  ],
  [ @$optional_redefines_107 ],
  [ @$optional_plugins_107 ],
  ##### PS protocol and low values of max-prepared-stmt-count
  [ '', '', '', '', '', '', '', '', '', '',
    $ps_protocol_options,
    '--mysqld=--max-prepared-stmt-count=0',
    '--mysqld=--max-prepared-stmt-count=1',
  ],
  ##### Encryption
  [ '', '', '', '', $non_innodb_encryption_options ],
  ##### Binary logging
  [ '', '',
    [ @$binlog_combinations ],
  ],
  ##### Performance schema
  [ '', '', '',
    $perfschema_options_107 . ' --redefine=conf/runtime/performance_schema.yy',
  ],
  ##### Startup variables (general)
  [ @$optional_server_variables_107 ],
  [ @$optional_charsets_107 ],
];
