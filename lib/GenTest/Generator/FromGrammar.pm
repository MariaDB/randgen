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

use strict;
use GenTest;
use GenTest::Constants;
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
      seed => $generator->[GENERATOR_SEED] || 0,
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

  my $grammars = $generator->[GENERATOR_GRAMMARS];

  my $prng = $generator->[GENERATOR_PRNG];
  my %rule_invariants = ();

  my %rule_counters;
  my %invariants;

  my $last_field;
  my $last_table;
  my $last_database;
  my $last_field_list_length;
  my $last_item;

  my $stack = GenTest::Stack::Stack->new();
  my $global = $generator->globalFrame();

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

      if (exists $grammar_rules->{$item}) {

        if (++($rule_counters->{$orig_item}) > GENERATOR_MAX_OCCURRENCES) {
          say("Rule $orig_item occured more than ".GENERATOR_MAX_OCCURRENCES()." times. Possible endless loop in grammar. Aborting.");
          return undef;
        }

        if ($invariant) {
          @{$rule_invariants->{$item}} = expand($rule_counters,$rule_invariants,$grammar_rules,($item)) unless defined $rule_invariants->{$item};
          @expansion = @{$rule_invariants->{$item}};
        } else {
          @expansion = expand($rule_counters,$rule_invariants,$grammar_rules,@{$grammar_rules->{$item}->[GenTest::Grammar::Rule::RULE_COMPONENTS]->[
            $prng->uint16(0, $#{$grammar_rules->{$item}->[GenTest::Grammar::Rule::RULE_COMPONENTS]})
          ]});

        }
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

          if (not $last_table) {
            # If we unset $last_table in a grammar, Executor will always use the first one
            # from the list for all _field rules and alike. We want it to be random still.
            # For _table rules and alike, it will be adjusted later
            $last_table = $prng->arrayElement($executors->[0]->metaTables($last_database));
          } elsif ($last_table =~ /\`?(.+)\`?\s*\.\`?(.+)\`?/) {
            # If a grammar set $last_table to a fully-qualified name, we want to split it
            # for further use
            ($last_database,$last_table)= ($1,$2);
          }

          if ($item eq '_letter') {
            $item = $prng->letter();
          } elsif ($item eq '_digit') {
            $item = $prng->digit();
          } elsif ($item eq '_word') {
            $item = $prng->word();
          } elsif ($item eq '_positive_digit') {
            $item = $prng->positive_digit();
          } elsif ($item eq '_table') {
            my $tables = $executors->[0]->metaTables($last_database);
            $last_table = $prng->arrayElement($tables);
            $item = '`'.$last_table.'`';
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
          } elsif ($item eq '_thread_id') {
            $item = $generator->threadId();
          } elsif ($item eq '_connection_id') {
            $item = $executors->[0]->connectionId();
          } elsif ($item eq '_current_user') {
            $item = $executors->[0]->currentUser();
          } elsif ($item eq '_thread_count') {
            $item = $ENV{RQG_THREADS};
          } elsif (($item eq '_database') || ($item eq '_db') || ($item eq '_schema')) {
            my $databases = $executors->[0]->metaSchemas();
            $last_database = $prng->arrayElement($databases);
            $item = '`'.$last_database.'`';
          } elsif (($item eq '_user_database') || ($item eq '_user_db') || ($item eq '_user_schema')) {
            my $databases = $executors->[0]->metaSchemas(my $non_system=1);
            $last_database = $prng->arrayElement($databases);
            $item = '`'.$last_database.'`';
          } elsif ($item eq '_table') {
            my $tables = $executors->[0]->metaTables($last_database);
            $last_table = $prng->arrayElement($tables);
            $item = '`'.$last_table.'`';
          } elsif ($item eq '_basetable') {
            my $tables = $executors->[0]->metaBaseTables($last_database);
            $last_table = $prng->arrayElement($tables);
            $item = '`'.$last_table.'`';
          } elsif ($item eq '_versionedtable') {
            my $tables = $executors->[0]->metaVersionedTables($last_database);
            $last_table = $prng->arrayElement($tables);
            $item = '`'.$last_table.'`';
          } elsif ($item eq '_view') {
            my $tables = $executors->[0]->metaViews($last_database);
            $last_table = $prng->arrayElement($tables);
            $item = '`'.$last_table.'`';
          } elsif ($item eq '_index') {
            my $indexes = $executors->[0]->metaIndexes($last_table, $last_database);
                        $last_field = $prng->arrayElement($indexes);
            $item = '`'.$last_field.'`';
          } elsif ($item eq '_field') {
            my $fields = $executors->[0]->metaColumns($last_table, $last_database);
                        $last_field = $prng->arrayElement($fields);
            $item = '`'.$last_field.'`';
          } elsif ($item eq '_field_list') {
            my $fields = $executors->[0]->metaColumns($last_table, $last_database);
            $item = '`'.join('`,`', @$fields).'`';
                        $last_field_list_length= scalar(@$fields);
          } elsif ($item eq '_field_count') {
            my $fields = $executors->[0]->metaColumns($last_table, $last_database);
            $item = $#$fields + 1;
          } elsif ($item eq '_field_next') {
            # Pick the next field that has not been picked recently and increment the $field_pos counter
            # (if there is more than one field in the table
            my $fields = $executors->[0]->metaColumns($last_table, $last_database);
            $item = '`'.($#$fields ? $fields->[$field_pos++ % $#$fields] : $fields->[0]).'`';
          } elsif ($item eq '_field_pk') {
            my $fields = $executors->[0]->metaColumnsIndexType('primary',$last_table, $last_database);
                        $last_field = $fields->[0];
            $item = '`'.$last_field.'`';
          } elsif ($item eq '_field_no_pk') {
            my $fields = $executors->[0]->metaColumnsIndexTypeNot('primary',$last_table, $last_database);
                        $last_field = $prng->arrayElement($fields);
            $item = '`'.$last_field.'`';
          } elsif (($item eq '_field_indexed') || ($item eq '_field_key')) {
            my $fields_indexed = $executors->[0]->metaColumnsIndexType('indexed',$last_table, $last_database);
                        $last_field = $prng->arrayElement($fields_indexed);
            $item = '`'.$last_field.'`';
          } elsif (($item eq '_field_unindexed') || ($item eq '_field_nokey')) {
            my $fields_unindexed = $executors->[0]->metaColumnsIndexTypeNot('indexed',$last_table, $last_database);
                        $last_field = $prng->arrayElement($fields_unindexed);
            $item = '`'.$last_field.'`';
          } elsif ($item =~ /^_field_list\((\d+)\)/) {
                        # Partial field list of a given length (or less, if there are not enough columns)
                        $last_field_list_length= $1;
            my $f = $executors->[0]->metaColumns($last_table, $last_database);
                        $last_field_list_length= scalar(@$f) if scalar(@$f) < $last_field_list_length;
                        my @fields= @{$prng->shuffleArray($f)}[0..$last_field_list_length-1];
            $item = '`'.join('`,`',@fields).'`';
          } elsif ($item =~ /^_field_([a-z]+)/) {
            my $fields = $executors->[0]->metaColumnsDataType($1,$last_table, $last_database);
                        $last_field = $prng->arrayElement($fields);
            $item = '`'.$last_field.'`';
          } elsif ($item =~ /^_field_([a-z]+)_(?:indexed|key)/) {
            my $fields = $executors->[0]->metaColumnsDataIndexType($1,'indexed',$last_table, $last_database);
                        $last_field = $prng->arrayElement($fields);
            $item = '`'.$last_field.'`';
          } elsif ($item eq '_collation') {
            my $collations = $executors->[0]->metaCollations();
            $item = '_'.$prng->arrayElement($collations);
          } elsif ($item eq '_collation_name') {
            my $collations = $executors->[0]->metaCollations();
            $item = $prng->arrayElement($collations);
          } elsif ($item eq '_charset') {
            my $charsets = $executors->[0]->metaCharactersets();
            $item = '_'.$prng->arrayElement($charsets);
          } elsif ($item eq '_charset_name') {
            my $charsets = $executors->[0]->metaCharactersets();
            $item = $prng->arrayElement($charsets);
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

  # If this is our first query, we look for a rule named "threadN_init" or "query_init"
  # in all grammars and concatenate them
  if ($generator->[GENERATOR_SEQ_ID] == 0)
  {
    foreach my $grammar (@$grammars) {
      $grammar_rules = $grammar->rules();
      if (exists $grammar_rules->{"thread".$generator->threadId()."_init"}) {
        $starting_rule= "thread".$generator->threadId()."_init";
      } elsif (exists $grammar_rules->{"query_init"}) {
        $starting_rule= "query_init";
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
  }
  else
  {
    if ($generator->[GENERATOR_SEQ_ID] == 1) {
      # Always reload metadata after the first rule, before expanding the next ones
      sayDebug("Reloading metadata after the first rule was executed");
      $executors->[0]->forceMetadataReload();
      $executors->[0]->cacheMetaData();
    }
    my $grammar= $prng->arrayElement($grammars);
    $grammar_rules= $grammar->rules();
    if (exists $grammar_rules->{"thread".$generator->threadId()}) {
      $starting_rule = $grammar_rules->{"thread".$generator->threadId()}->name();
    } else {
      $starting_rule = "query";
    }
    @sentence = expand(\%rule_counters,\%rule_invariants,$grammar_rules,($starting_rule));
  }

  $generator->[GENERATOR_SEQ_ID]++;

  my $sentence = join ('', map { defined $_ ? $_ : '' } @sentence);
  # Remove extra spaces while we are here
  while ($sentence =~ s/\.\s/\./s) {};
  while ($sentence =~ s/\s([\.,])/$1/s) {};
  while ($sentence =~ s/\s\s/ /s) {};
  while ($sentence =~ s/(\W)(AVG|BIT_AND|BIT_OR|BIT_XOR|COUNT|GROUP_CONCAT|MAX|MIN|STD|STDDEV_POP|STDDEV_SAMP|STDDEV|SUM|VAR_POP|VAR_SAMP|VARIANCE) /$1$2/s) {};

  $generator->[GENERATOR_PARTICIPATING_RULES] = [ keys %rule_counters ];

    # In new grammars, we will use ;; to indicate a delimiter in multi-statements
    # (as opposed to single ; withing stored procedures and such).
    # It will allow to use the syntax more freely.
    # However, there are many legacy grammars so far, for which the old
    # logic is preserved in elsif's below:
  # If this is a BEGIN ... END block or alike, then send it to server without splitting.
  # If the semicolon is inside a string literal, ignore it.
  # Otherwise, split it into individual statements so that the error and the result set from each statement
  # can be examined

  if (index($sentence, ';;') > -1) {

    my @sentences;

    @sentences = split (';;', $sentence);
        if ($generator->[GENERATOR_SEQ_ID] == 1) {
          sayDebug("Starting rule ($starting_rule) processed:\n@sentence");
        }
    return \@sentences;
  } elsif (
    # Stored procedures of all sorts
      (
        (index($sentence, 'CREATE') > -1 ) &&
        (index($sentence, 'BEGIN') > -1 || index($sentence, 'END') > -1)
      )
    or
    # MDEV-5317, anonymous blocks BEGIN NOT ATOMIC .. END
      (
        (index($sentence, 'BEGIN') > -1 ) &&
        (index($sentence, 'ATOMIC') > -1 ) &&
        (index($sentence, 'END') > -1 )
      )
    or
    # MDEV-5317, IF .. THEN .. [ELSE ..] END IF
      (
        (index($sentence, 'IF') > -1 ) &&
        (index($sentence, 'THEN') > -1 ) &&
        (index($sentence, 'END') > -1 )
      )
    or
    # MDEV-5317, CASE .. [WHEN .. THEN .. [WHEN .. THEN ..] [ELSE .. ]] END CASE
      (
        (index($sentence, 'CASE') > -1 ) &&
        (index($sentence, 'WHEN') > -1 ) &&
        (index($sentence, 'THEN') > -1 ) &&
        (index($sentence, 'END') > -1 )
      )
    or
    # MDEV-5317, LOOP .. END LOOP
      (
        (index($sentence, 'LOOP') > -1 ) &&
        (index($sentence, 'END') > -1 )
      )
    or
    # MDEV-5317, REPEAT .. UNTIL .. END REPEAT
      (
        (index($sentence, 'REPEAT') > -1 ) &&
        (index($sentence, 'UNTIL') > -1 ) &&
        (index($sentence, 'END') > -1 )
      )
    or
    # MDEV-5317, WHILE .. DO .. END WHILE
      (
        (index($sentence, 'WHILE') > -1 ) &&
        (index($sentence, 'DO') > -1 ) &&
        (index($sentence, 'END') > -1 )
      )
  ) {
        if ($generator->[GENERATOR_SEQ_ID] == 1) {
          sayDebug("Starting rule ($starting_rule) processed:\n$sentence");
        }
    return [ $sentence ];
  } elsif (index($sentence, ';') > -1) {

    my @sentences;

    # We want to split the sentence into separate statements, but we do not want
    # to split literals if a semicolon happens to be inside.
    # I am sure it could be done much smarter; feel free to improve it.
    # For now, we do the following:
    # - store and mask all literals (inside single or double quote marks);
    # - replace remaining semicolons with something expectedly unique;
    # - restore the literals;
    # - split the sentence, not by the semicolon, but by the unique substitution
    # Do not forget that there can also be escaped quote marks, which are not literal boundaries

    if (index($sentence, "'") > -1 or index($sentence, '"') > -1) {
      # Store literals in single quotes
      my @singles = ( $sentence =~ /(?<!\\)(\'.*?(?<!\\)\')/g );
      # Mask these literals
      $sentence =~ s/(?<!\\)\'.*?(?<!\\)\'/######SINGLES######/g;
      # Store remaining literals in double quotes
      my @doubles = ( $sentence =~ /(?<!\\)(\".*?(?<!\\)\")/g );
      # Mask these literals
      $sentence =~ s/(?<!\\)\".*?(?<!\\)\"/######DOUBLES######/g;
      # Replace remaining semicolons
      $sentence =~ s/;/######SEMICOLON######/g;

      # Restore literals in double quotes
      while ( $sentence =~ s/######DOUBLES######/$doubles[0]/ ) {
        shift @doubles;
      }
      # Restore literals in single quotes
      while ( $sentence =~ s/######SINGLES######/$singles[0]/ ) {
        shift @singles;
      }
      # split the sentence
      @sentences = split('######SEMICOLON######', $sentence);
    }
    else {
      @sentences = split (';', $sentence);
    }
        if ($generator->[GENERATOR_SEQ_ID] == 1) {
          sayDebug("Starting rule ($starting_rule) processed:\n@sentence");
        }
    return \@sentences;
  } else {
        if ($generator->[GENERATOR_SEQ_ID] == 1) {
          sayDebug("Starting rule ($starting_rule) processed:\n$sentence");
        }
    return [ $sentence ];
  }
}

1;
