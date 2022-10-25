use strict;

our ($non_innodb_encryption_options, $innodb_encryption_options, $common_options, $ps_protocol_options, $perfschema_options_103);
our ($grammars_any_gendata, $grammars_specific_gendata, $gendata_files, $auto_gendata_combinations, $optional_redefines_103);
our ($views_combinations, $vcols_combinations, $threads_low_combinations, $binlog_combinations);
our ($optional_variators_103, $basic_engine_combinations_103, $extra_engine_combinations_103);
our ($non_crash_scenario_combinations_103, $scenario_combinations_103);
our ($optional_innodb_variables_103, $optional_plugins_103, $optional_server_variables_103, $optional_charsets_103);

require "$ENV{RQG_HOME}/conf/mariadb/include/parameter_presets";
require "$ENV{RQG_HOME}/conf/mariadb/include/combo.grammars";

$combinations = [
  [ $common_options ], # seed, reporters, timeouts
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
        [ '--validators=TransformerNoComparator' ], @$optional_variators_103,
      ],
      notransform => [ '' ]
    }
  ],
  ##### Engines and engine=specific options
  [
    {
      engines => [
        [ @$basic_engine_combinations_103, @$extra_engine_combinations_103 ],
        [ @$non_crash_scenario_combinations_103,
          '', '', '', '', '', '', '', '', '', '', ''
        ],
      ],
      innodb => [
        [ '--engine=InnoDB' ],
        [ @$scenario_combinations_103,
          '', '', '', '', '', '', '', '', '', '', '', '', '', '', '',
        ],
        @$optional_innodb_variables_103,
      ],
    }
  ],
  [ @$optional_redefines_103 ],
  [ @$optional_plugins_103 ],
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
    $perfschema_options_103 . ' --redefine=conf/runtime/performance_schema.yy',
  ],
  ##### Startup variables (general)
  [ @$optional_server_variables_103 ],
  [ @$optional_charsets_103 ],
];
