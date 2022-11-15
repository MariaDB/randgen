# MDEV-13756 Implement descending index

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
  [ '--redefine=conf/mariadb/features/desc_indexes-runtime.yy --redefine=conf/mariadb/features/desc_indexes-init.yy --variators=FullOrderBy' ],
  [
    '--grammar=conf/optimizer/range_access.yy --gendata=conf/optimizer/range_access.zz',
    '--grammar=conf/optimizer/range_access2.yy --gendata=conf/optimizer/range_access2.zz',
    '--grammar=conf/mariadb/range_access2.yy --gendata-advanced --partitions',
    '--grammar=conf/mariadb/optimizer.yy --gendata-advanced --partitions',
    '--grammar=conf/mariadb/optimizer.yy --gendata --views',
    '--grammar=conf/optimizer/optimizer_subquery_semijoin.yy --gendata --views',
    '--grammar=conf/optimizer/optimizer_no_subquery.yy --gendata --views',
    '--grammar=conf/optimizer/optimizer_access_exp.yy --gendata=conf/optimizer/range_access.zz',
  ],
  [ '--duration=350 --threads=4' ],
  [ @$views_combinations, '', '', '' ],

  ##### Engines and engine=specific options
  [
    {
      engines => [
        [ @$basic_engine_combinations_107 ],
      ],
      innodb => [
        [ '--engine=InnoDB' ],
        @$optional_innodb_variables_107,
      ],
    }
  ],
  [ @$optional_plugins_107 ],
  ##### Startup variables (general)
  [ @$optional_server_variables_107 ],
  [ @$optional_charsets_107 ],
];
