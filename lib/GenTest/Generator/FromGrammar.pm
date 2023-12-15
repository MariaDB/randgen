# Copyright (C) 2008-2009 Sun Microsystems, Inc. All rights reserved.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2021, 2022, MariaDB Corporation Ab.
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

package GenTest::Generator::FromGrammar;

require Exporter;
@ISA = qw(GenTest::Generator GenTest);

use Cwd;
use List::Util qw(shuffle); # For some grammars
use Time::HiRes qw(time);
use File::Path qw(mkpath);

use strict;
use GenTest;
use Constants;
use GenTest::Generator;
use GenTest::Grammar;
use GenTest::Grammar::Rule;
use GenTest::Random;
use GenTest::Stack::Stack;
use GenUtil;

use constant GENERATOR_MAX_OCCURRENCES  => 10000;
use constant GENERATOR_MAX_LENGTH  => 10000000;

my $field_pos;
my $cwd = cwd();

sub new {
  my $class = shift;
  my $generator = $class->SUPER::new(@_);

  if (not defined $generator->prng()) {
    $generator->[GENERATOR_PRNG] = GenTest::Random->new(
      seed => $generator->[GENERATOR_SEED] || 0, compatibility => $generator->[GENERATOR_COMPATIBILITY]
    );
  }

  $generator->[GENERATOR_SEQ_ID] = 0;

  return $generator;
}

sub globalFrame {
    my ($self) = @_;
    $self->[GENERATOR_GLOBAL_FRAME] = GenTest::Stack::StackFrame->new()
        if not defined $self->[GENERATOR_GLOBAL_FRAME];
    return $self->[GENERATOR_GLOBAL_FRAME];
}

sub participatingRules {
  return $_[0]->[GENERATOR_PARTICIPATING_RULES];
}

#
# Generate a new query. We do this by iterating over the array containing grammar rules and expanding each grammar rule
# to one of its right-side components . We do that in-place in the array.
#
# Finally, we walk the array and replace all lowercase keywors with literals and such.
#

sub next {
  my ($generator, $executors) = @_;

  # Suppress complaints "returns its argument for UTF-16 surrogate".
  # We already know that our UTFs in some grammars are ugly.
  no warnings 'surrogate';

  my $grammars= $generator->[GENERATOR_GRAMMARS];

  my $prng = $generator->[GENERATOR_PRNG];
  my %rule_invariants = ();

  my %rule_counters;
  my %invariants;

  my $last_index;
  my $last_field;
  my $last_table;
  my $last_charset;
  # last_database is what was set upon _database and _table and alike
  # work_database is what was requested via _set_db, it can be an actual
  # database name, or NON-SYSTEM, or ANY.
  # If work_database is NON-SYSTEM or ANY, then last_database is set
  # to the actual picked value
  # work_database is used to pick up tables or other database objects.
  # $executors->[0]->currentSchema is work_database resolved
  my $last_database;
  my $work_database;
  # Flag indicating that work_database is ANY or NON-SYSTEM (for convenience)
  my $work_database_non_specific= 1;
  my $last_field_list_length;
  my ($last_function, $last_procedure);
  my $last_item;

  my $stack = GenTest::Stack::Stack->new();
  my $global = $generator->globalFrame();

  sub _set_db {
    my $db= $work_database= $_[0];
    my $set_db_stmt= '';
    if ($db eq 'ANY') {
      $db= $prng->arrayElement($executors->[0]->metaAllNonEmptySchemas()) || $prng->arrayElement($executors->[0]->metaAllSchemas());
      $work_database_non_specific= 1;
    } elsif ($db eq 'NON-SYSTEM') {
      $db= $prng->arrayElement($executors->[0]->metaNonEmptyUserSchemas()) || $prng->arrayElement($executors->[0]->metaUserSchemas());
      $work_database_non_specific= 1;
    } else {
      $work_database_non_specific= 0;
    }
    if (not defined $executors->[0]->currentSchema() or $db ne $executors->[0]->currentSchema()) {
      $set_db_stmt= "USE $db /* EXECUTOR_FLAG_SKIP_STATS SKIP_VARIATION */ ;;";
      # Executor should do it later upon USE,
      # but it may be already needed for variation
      $executors->[0]->currentSchema($db);
    }
    return $set_db_stmt;
  }

  sub expand {
    my ($rule_counters, $rule_invariants, $grammar_rules, @sentence) = @_;
    my $item_nodash;
    my $orig_item;

    if ($#sentence > GENERATOR_MAX_LENGTH) {
      say("Sentence is now longer than ".GENERATOR_MAX_LENGTH()." symbols. Possible endless loop in grammar. Aborting.");
      return undef;
    }

    for (my $pos = 0; $pos <= $#sentence; $pos++) {
      $orig_item = $sentence[$pos];

      next if not defined $orig_item;
      next if $orig_item eq ' ';
      next if $orig_item eq uc($orig_item);

      my $item = $orig_item;
      my $invariant = 0;
      my @expansion = ();

      if ($item =~ m{^([a-z0-9_]+)\[invariant\]}is) {
        ($item, $invariant) = ($1, 1);
      }

      if ($invariant) {
        unless ($rule_invariants->{$item}) {
          $rule_invariants->{$item} = [ expand($rule_counters,$rule_invariants,$grammar_rules,($item)) ];
        }
        @expansion = @{$rule_invariants->{$item}};
      }
      
      elsif (exists $grammar_rules->{$item}) {

        if (++($rule_counters->{$orig_item}) > GENERATOR_MAX_OCCURRENCES) {
          say("Rule $orig_item occured more than ".GENERATOR_MAX_OCCURRENCES()." times. Possible endless loop in grammar. Aborting.");
          return undef;
        }

        @expansion = expand($rule_counters,$rule_invariants,$grammar_rules,@{$grammar_rules->{$item}->[GenTest::Grammar::Rule::RULE_COMPONENTS]->[
          $prng->uint16(0, $#{$grammar_rules->{$item}->[GenTest::Grammar::Rule::RULE_COMPONENTS]})
        ]});

        if ($generator->[GENERATOR_ANNOTATE_RULES]) {
          @expansion = ("/* rule: $item */ ", @expansion);
        }
      } else {
        if (
          (substr($item, 0, 1) eq '{') &&
          (substr($item, -1, 1) eq '}')
        ) {
          $item = eval("no strict;\n".$item);    # Code

          if ($@ ne '') {
            if ($@ =~ m{at .*? line}o) {
              say("Internal grammar error: $@");
              return undef;      # Code called die()
            } else {
              warn("Syntax error in Perl snippet $orig_item : $@");
              return undef;
            }
          }
        } elsif (substr($item, 0, 1) eq '$') {
          $item = eval("no strict;\n".$item.";\n");  # Variable
        } elsif (index($item,'__') == 0) {
            $item= $prng->auto(substr($item,2));
        } else {
          my $field_type = (substr($item, 0, 1) eq '_' ? $prng->isFieldType(substr($item, 1)) : undef);

          if ($item eq '_letter') {
            $item = $prng->letter();
          } elsif ($item eq '_digit') {
            $item = $prng->digit();
          } elsif ($item eq '_word') {
            $item = $prng->word();
          } elsif ($item eq '_positive_digit') {
            $item = $prng->positive_digit();
          } elsif ($item eq '_hex') {
            $item = $prng->hex();
          } elsif ($item eq '_cwd') {
            $item = "'".$cwd."'";
          } elsif (
            ($item eq '_tmpnam') ||
            ($item eq '_tmpfile')
          ) {
            # Create a new temporary file name and record it for unlinking at the next statement
            $generator->[GENERATOR_TMPNAM] = tmpdir()."gentest".abs($$).".tmp" if not defined $generator->[GENERATOR_TMPNAM];
            $item = "'".$generator->[GENERATOR_TMPNAM]."'";
            $item =~ s{\\}{\\\\}sgio if osWindows();  # Backslash-escape backslashes on Windows
          } elsif ($item eq '_tmptable') {
            $item = "tmptable".abs($$);
          } elsif ($item eq '_unix_timestamp') {
            $item = time();
          } elsif ($item eq '_pid') {
            $item = abs($$);
          } elsif ($item eq '_engine') {
            $item = $prng->arrayElement($executors->[0]->engines);
          } elsif ($item eq '_thread_id') {
            $item = $generator->threadId();
          } elsif ($item eq '_connection_id') {
            $item = $executors->[0]->connectionId();
          } elsif ($item eq '_current_user') {
            $item = $executors->[0]->user();
          } elsif ($item eq '_thread_count') {
            $item = $ENV{RQG_THREADS};
          } elsif (($item eq '_database') || ($item eq '_db') || ($item eq '_schema')) {
            $last_database = $prng->arrayElement($executors->[0]->metaAllSchemas());
            $item = '`'.$last_database.'`';
          } elsif (($item eq '_user_database') || ($item eq '_user_db') || ($item eq '_user_schema')) {
            $last_database = $prng->arrayElement($executors->[0]->metaUserSchemas());
            $item = '`'.$last_database.'`';
          } elsif ($item eq '_table' or $item eq '_view' or $item eq '_basetable' or $item eq '_versionedtable' or $item eq '_sequence') {
            my $obj;
            if ($item eq '_table') {
              $obj = $prng->arrayElement($executors->[0]->metaTables($work_database));
            } elsif ($item eq '_view') {
              $obj = $prng->arrayElement($executors->[0]->metaViews($work_database));
            } elsif ($item eq '_basetable') {
              $obj = $prng->arrayElement($executors->[0]->metaBaseTables($work_database));
            } elsif ($item eq '_versionedtable') {
              $obj = $prng->arrayElement($executors->[0]->metaVersionedTables($work_database));
            } elsif ($item eq '_sequence') {
              $obj = $prng->arrayElement($executors->[0]->metaSequences($work_database));
            }
            ($last_database, $last_table) = ($obj ? @$obj : ('!non_existing_database', '!non_existing_object'));
            $item = ($work_database_non_specific ? '`'.$last_database.'`.`'.$last_table.'`' : '`'.$last_table.'`');
          } elsif ($item eq '_procedure') {
            my $obj = $prng->arrayElement($executors->[0]->metaProcedures($work_database));
            ($last_database, $last_procedure) = ($obj ? @$obj : ('!non_existing_database', '!non_existing_object'));
            $item = ($work_database_non_specific ? '`'.$last_database.'`.`'.$last_procedure.'`' : '`'.$last_procedure.'`');
          } elsif ($item eq '_function') {
            my $obj = $prng->arrayElement($executors->[0]->metaFunctions($work_database));
            ($last_database, $last_procedure) = ($obj ? @$obj : ('!non_existing_database', '!non_existing_object'));
            $item = ($work_database_non_specific ? '`'.$last_database.'`.`'.$last_function.'`' : '`'.$last_function.'`');
          } elsif ($item eq '_index') {
            my $indexes = $executors->[0]->metaIndexes([$last_database,$last_table]);
                        $last_index = $prng->arrayElement($indexes);
            $item = '`'.$last_index.'`';
          } elsif ($item eq '_field') {
            my $fields = $executors->[0]->metaColumns([$last_database,$last_table]);
                        $last_field = $prng->arrayElement($fields);
            $item = '`'.$last_field.'`';
          } elsif ($item eq '_field_list') {
            my $fields = $executors->[0]->metaColumns([$last_database,$last_table]);
            $item = '`'.join('`,`', @$fields).'`';
                        $last_field_list_length= scalar(@$fields);
          } elsif ($item eq '_field_count') {
            my $fields = $executors->[0]->metaColumns([$last_database,$last_table]);
            $item = $#$fields + 1;
          } elsif ($item eq '_field_next') {
            # Pick the next field that has not been picked recently and increment the $field_pos counter
            # (if there is more than one field in the table
            my $fields = $executors->[0]->metaColumns([$last_database,$last_table]);
            $item = '`'.($#$fields ? $fields->[$field_pos++ % $#$fields] : $fields->[0]).'`';
          } elsif ($item eq '_field_pk') {
            my $fields = $executors->[0]->metaColumnsIndexType('primary',[$last_database,$last_table]);
                        $last_field = $fields->[0];
            $item = '`'.$last_field.'`';
          } elsif ($item eq '_field_no_pk') {
            my $fields = $executors->[0]->metaColumnsIndexTypeNot('primary',[$last_database,$last_table]);
                        $last_field = $prng->arrayElement($fields);
            $item = '`'.$last_field.'`';
          } elsif (($item eq '_field_indexed') || ($item eq '_field_key')) {
            my $fields_indexed = $executors->[0]->metaColumnsIndexType('indexed',[$last_database,$last_table]);
                        $last_field = $prng->arrayElement($fields_indexed);
            $item = '`'.$last_field.'`';
          } elsif (($item eq '_field_unindexed') || ($item eq '_field_nokey')) {
            my $fields_unindexed = $executors->[0]->metaColumnsIndexTypeNot('indexed',[$last_database,$last_table]);
                        $last_field = $prng->arrayElement($fields_unindexed);
            $item = '`'.$last_field.'`';
          } elsif ($item =~ /^_field_list\((\d+)\)/) {
                        # Partial field list of a given length (or less, if there are not enough columns)
                        $last_field_list_length= $1;
            my $f = $executors->[0]->metaColumns([$last_database,$last_table]);
                        $last_field_list_length= scalar(@$f) if scalar(@$f) < $last_field_list_length;
                        my @fields= @{$prng->shuffleArray($f)}[0..$last_field_list_length-1];
            $item = '`'.join('`,`',@fields).'`';
          } elsif ($item =~ /^_field_([a-z]+)_(?:indexed|key)/) {
            my $fields = $executors->[0]->metaColumnsDataIndexType($1,'indexed',[$last_database,$last_table]);
                        $last_field = $prng->arrayElement($fields);
            $item = '`'.$last_field.'`';
          } elsif ($item =~ /^_field_([a-z]+)/) {
            my $fields = $executors->[0]->metaColumnsDataType($1,[$last_database,$last_table]);
                        $last_field = $prng->arrayElement($fields);
            $item = '`'.$last_field.'`';
          } elsif ($item eq '_collation') {
            my $collations = $executors->[0]->metaCollations($last_charset);
            $item = '_'.$prng->arrayElement($collations);
          } elsif ($item eq '_timezone') {
            my $timezones = $executors->[0]->metaTimezones();
            $item = "'".$prng->arrayElement($timezones)."'";
          } elsif ($item eq '_collation_name') {
            my $collations = $executors->[0]->metaCollations($last_charset);
            $item = $prng->arrayElement($collations);
            # MDEV-28767 - binary collation causes syntax errors
            if ($item eq 'binary') {
              $item= '`binary`';
            }
          } elsif ($item eq '_charset') {
            my $charsets = $executors->[0]->metaCharactersets();
            $last_charset= $prng->arrayElement($charsets);
            $item = '_'.$last_charset;
          } elsif ($item eq '_charset_name') {
            my $charsets = $executors->[0]->metaCharactersets();
            $last_charset = $prng->arrayElement($charsets);
            $item= $last_charset;
          } elsif ( defined $field_type and
            (($field_type == FIELD_TYPE_NUMERIC) ||
             ($field_type == FIELD_TYPE_BLOB))
          ) {
            $item = $prng->fieldType($item);
          } elsif ($field_type) {
                        $item = substr($item,1);
            $item = $prng->fieldType($item);
          }

          # If the grammar initially contained a ` , restore it. This allows
          # The generation of constructs such as `table _digit` => `table 5`

          if (
            (substr($orig_item, -1) eq '`') &&
            (index($item, '`') == -1)
          ) {
            $item = $item.'`';
          }

        }
        $last_item= $item;
        @expansion = ($item);
      }
      splice(@sentence, $pos, 1, @expansion);

    }
    return @sentence;
  }

  #
  # If a temporary file has been left from a previous statement, unlink it.
  #

  unlink($generator->[GENERATOR_TMPNAM]) if defined $generator->[GENERATOR_TMPNAM];
  $generator->[GENERATOR_TMPNAM] = undef;

  my $starting_rule= '';
  my $grammar_rules;
  my @sentence= ();
  my $skip_variate= 0;

  # If this is our first query, we look for a rule named "threadN_init" or "query_init"
  # in all grammars and concatenate them
  if ($generator->[GENERATOR_SEQ_ID] == 0)
  {
    foreach my $grammar (@$grammars) {
      $grammar_rules = $grammar->rules();
      if (exists $grammar_rules->{"thread".$generator->threadId()."_init"}) {
        $starting_rule= "thread".$generator->threadId()."_init";
        $skip_variate= 1;
      } elsif (exists $grammar_rules->{"query_init"}) {
        $starting_rule= "query_init";
        $skip_variate= 1;
      } else {
        next;
      }
      @sentence = (@sentence, expand(\%rule_counters,\%rule_invariants,$grammar_rules,($starting_rule)), ';; ');
    }
    sayDebug("Starting rule ($starting_rule) expanded:\n@sentence");
    # Now when init rules (if any) have been used, we'll discard grammars
    # without 'query' rule
    my @new_grammars= ();
    foreach my $grammar (@$grammars) {
      if (exists $grammar->rules()->{query}) {
        push @new_grammars, $grammar;
      } else {
        sayWarning("Grammar ".$grammar->file." does not have 'query' rule and will be further ignored");
      }
    }
    unless (scalar (@new_grammars)) {
      sayError("There are no grammars for test flow generation");
      return STATUS_ENVIRONMENT_FAILURE;
    }
    $generator->[GENERATOR_GRAMMARS] = [ @new_grammars ];
    $generator->adjustWeights();
    
  }
  else
  {
    my $grammar_id= $prng->arrayElement($generator->[GENERATOR_GRAMMAR_POOL]);
    my $grammar = $generator->[GENERATOR_GRAMMARS]->[$grammar_id];
    sayDebug("Using ".$grammar->file." for query ".$generator->[GENERATOR_SEQ_ID]);
    $grammar_rules= $grammar->rules();
    if (exists $grammar_rules->{"thread".$generator->threadId()}) {
      $starting_rule = $grammar_rules->{"thread".$generator->threadId()}->name();
    } else {
      $starting_rule = "query";
    }
    @sentence = expand(\%rule_counters,\%rule_invariants,$grammar_rules,($starting_rule));
  }

  my $sentence = join ('', map { defined $_ ? $_ : '' } @sentence);
  # Remove extra spaces while we are here
  while ($sentence =~ s/\.\s/\./s) {};
  while ($sentence =~ s/\s([\.,])/$1/s) {};
  while ($sentence =~ s/\s\s/ /s) {};
  while ($sentence =~ s/(\W)(AVG|BIT_AND|BIT_OR|BIT_XOR|COUNT|GROUP_CONCAT|MAX|MIN|STD|STDDEV_POP|STDDEV_SAMP|STDDEV|SUM|VAR_POP|VAR_SAMP|VARIANCE) /$1$2/s) {};

  $generator->[GENERATOR_PARTICIPATING_RULES] = [ keys %rule_counters ];

  # In the grammars, we use ;; to indicate a delimiter in multi-statements
  # (as opposed to single ; withing stored procedures and such).

  my @sentences= split (';;', $sentence);
  sayDebug("Expanded into [ @sentences ]");

  if ((! $skip_variate) && $generator->variators && scalar(@{$generator->variators})) {
    my @variated= ();
    foreach my $s (@sentences) {
      my $queries= $generator->variateQuery($s,$executors->[0]);
      if (ref $queries eq 'ARRAY') {
        push @variated, @$queries;
      } else {
        sayError("A problem occurred during query variation");
        return undef;
      }
    }
    @sentences= @variated;
  }
  $generator->[GENERATOR_SEQ_ID]++;

 return \@sentences;
}

1;
