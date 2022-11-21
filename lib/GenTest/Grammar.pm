# Copyright (c) 2008,2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2016, 2022, MariaDB Corporation
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

package GenTest::Grammar;

require Exporter;
@ISA = qw(GenTest);

use strict;

use GenUtil;
use GenTest;
use GenTest::Constants;
use GenTest::Grammar::Rule;
use GenTest::Random;

use Data::Dumper;
use Carp;

use constant GRAMMAR_RULES     => 0;
use constant GRAMMAR_FILE      => 1;
use constant GRAMMAR_STRING    => 2;
use constant GRAMMAR_FEATURES  => 3;
use constant GRAMMAR_REDEFINES => 4;

1;

sub new {
  my $class = shift;

  my $grammar = $class->SUPER::new({
    'grammar_file'   => GRAMMAR_FILE,
    'redefine_files'  => GRAMMAR_REDEFINES,
  }, @_);

  $grammar->[GRAMMAR_FEATURES]= [];
  $grammar->[GRAMMAR_RULES] = {};

  if (defined $grammar->file()) {
    my $parse_result = $grammar->parseFromFile($grammar->file());
    return undef if $parse_result > STATUS_OK;
  }

  sayDebug("Found features @{$grammar->[GRAMMAR_FEATURES]}");

  return $grammar;
}

sub file {
  return $_[0]->[GRAMMAR_FILE];
}

sub string {
  return $_[0]->[GRAMMAR_STRING];
}

sub features {
  return $_[0]->[GRAMMAR_FEATURES];
}

sub toString {
  my $grammar = shift;
  my $rules = $grammar->rules();
  return join("\n\n", map { $grammar->rule($_)->toString() } sort keys %$rules);
}


sub parseFromFile {
  my ($grammar, $grammar_file) = @_;

  open (GF, $grammar_file) or die "Unable to open() grammar $grammar_file: $!";
  sayDebug("Reading grammar from file $grammar_file");
  read (GF, my $grammar_string, -s $grammar_file) or die "Unable to read() $grammar_file: $!";
  close (GF);

  $grammar->[GRAMMAR_STRING] = $grammar_string;
  return $grammar->parseFromString($grammar_string);
}

sub parseFromString {
  my ($grammar, $grammar_string) = @_;

    while ($grammar_string =~ s{#include [<"](.*?)[>"]$}{
      {
        my $include_string;
        my $include_file = $1;
              open (IF, $1) or die "Unable to open include file $include_file: $!";
              read (IF, $include_string, -s $include_file) or die "Unable to open $include_file: $!";
        $include_string;
    }}mie) {};

    while ($grammar_string =~ s{#feature\s*<(.+)>.*}{}) {
      push @{$grammar->[GRAMMAR_FEATURES]}, $1;
    }

    # Strip comments. Note that this is not Perl-code safe, since perl fragments
    # can contain both comments with # and the $# expression. A proper lexer will fix this

    $grammar_string =~ s{#.*$}{}iomg;

    # Join lines ending in \

    $grammar_string =~ s{\\$}{ }iomg;

    # Strip end-line whitespace

    $grammar_string =~ s{\s+$}{}iomg;

    # Add terminating \n to ease parsing

    $grammar_string = $grammar_string."\n";

    my @rule_strings = split (";[ \t]*[\r\n]+", $grammar_string);

    my %rules;

      # Redefining grammars might want to *add* something to an existing rule
      # rather than replace them. For now we recognize additions only to init queries
      # and to the main queries ('query' and 'threadX'). Additions should end with '_add':
      # - query_add
      # - threadX_add
      # - query_init_add
      # _ threadX_init_add
      # Grammars can have multiple additions like these, they all will be stored
      # and appended to the corresponding rule.
      #
      # Additions to 'query' and 'threadX' will be appended as an option, e.g.
      #
      # In grammar files we have:
      #   query:
      #     rule1 | rule2;
      #   query_add:
      #     rule3;
      # In the resulting grammar we will have:
      #   query:
      #     rule1 | rule2 | rule3;
      #
      # Additions to '*_init' rules will be added as a part of a multiple-statement, e.g.
      #
      # In grammar files we have:
      #   query_init:
      #     rule4 ;
      #   query_init_add:
      #     rule5;
      # In the resulting grammar we will have:
      #   query_init:
      #     rule4 ; rule5;
      #
      # Also, we will add threadX_init_add to query_init (if it's not overridden for the given thread ID).
      # That is, if we have in the grammars
      # query_init: ...
      # query_init_add: ...
      # thread2_init_add: ...
      # thread3_init: ...
      #
      # then the resulting init sequence for threads will be:
      # 1: query_init; query_init_add
      # 2: query_init; query_init_add; thread2_init_add
      # 3: thread3_init


      my @query_adds = ();
      my %thread_adds = ();
      my @query_init_adds = ();
      my %thread_init_adds = ();

    foreach my $rule_string (@rule_strings) {
      my ($rule_name, $components_string) = $rule_string =~ m{^(.*?)\s*:(.*)$}sio;
      $rule_name =~ s{[\r\n]}{}gsio;
      $rule_name =~ s{^\s*}{}gsio;

      next if $rule_name eq '';

          if ($rule_name =~ /^query_add$/) {
              push @query_adds, $components_string;
          }
          elsif ($rule_name =~ /^thread(\d+)_add$/) {
              @{$thread_adds{$1}} = () unless defined $thread_adds{$1};
              push @{$thread_adds{$1}}, $components_string;
          }
          elsif ($rule_name =~ /^query_init_add$/) {
              push @query_init_adds, $components_string;
          }
          elsif ($rule_name =~ /^thread(\d+)_init_add$/) {
              @{$thread_init_adds{$1}} = () unless defined $thread_init_adds{$1};
              push @{$thread_init_adds{$1}}, $components_string;
          }
          else {
              say("Warning: Rule $rule_name is defined twice.") if exists $rules{$rule_name};
              $rules{$rule_name} = $components_string;
          }
      }

      if (@query_adds) {
          my $adds = join ' | ', @query_adds;
          $rules{'query'} = ( defined $rules{'query'} ? $rules{'query'} . ' | ' . $adds : $adds );
      }

      foreach my $tid (keys %thread_adds) {
          my $adds = join ' | ', @{$thread_adds{$tid}};
          $rules{'thread'.$tid} = ( defined $rules{'thread'.$tid} ? $rules{'thread'.$tid} . ' | ' . $adds : $adds );
      }

      if (@query_init_adds) {
          my $adds = join ';; ', @query_init_adds;
          $rules{'query_init'} = ( defined $rules{'query_init'} ? $rules{'query_init'} . ';; ' . $adds : $adds );
      }

      foreach my $tid (keys %thread_init_adds) {
          my $adds = join ';; ', @{$thread_init_adds{$tid}};
          $rules{'thread'.$tid.'_init'} = (
              defined $rules{'thread'.$tid.'_init'}
                  ? $rules{'thread'.$tid.'_init'} . ';; ' . $adds
                  : ( defined $rules{'query_init'}
                      ? $rules{'query_init'} . ';; ' . $adds
                      : $adds
                  )
          );
      }

      # Now we have all the rules extracted from grammar files, time to parse

    foreach my $rule_name (keys %rules) {

          my $components_string = $rules{$rule_name};

      my @orig_component_strings = split (m{\|}, $components_string);

          # Check for ==FACTOR:N== directives and adjust probabilities
          my $multiplier= 1;
          my %component_factors= ();
          my @modified_component_strings= ();
          for (my $i=0; $i<=$#orig_component_strings; $i++) {
              my $c= $orig_component_strings[$i];
              if ($c =~ s{^\s*==FACTOR:([\d+\.]+)==\s*}{}sgio) {
                  $component_factors{$i}= $1;
                  $multiplier= int(1/$1) if $1 > 0 and $multiplier < int(1/$1);
              }
              push @modified_component_strings, $c;
          }

          my @component_strings= ();
          for (my $i=0; $i<=$#modified_component_strings; $i++) {
              my $count= int ((defined $component_factors{$i} ? $component_factors{$i} : 1) * $multiplier) || 1;
              foreach (1..$count) {
                  push @component_strings, $modified_component_strings[$i];
              }
          }

      my @components;
      my %components;

      foreach my $component_string (@component_strings) {
        # Remove leading and trailing whitespace
        $component_string =~ s{^\s+}{}sgio;
        $component_string =~ s{\s+$}{}sgio;

        # Rempove repeating whitespaces
        $component_string =~ s{\s+}{ }sgio;

        # Split this so that each identifier is separated from all syntax elements
        # The identifier can start with a lowercase letter or an underscore , plus quotes

        $component_string =~ s{([_a-zA-Z0-9'"`\{\}\$\[\]]+)}{|$1|}sgio;

        # Revert overzealous splitting that splits things like _varchar(32)
        # or __on_off(33,33) into several tokens

        $component_string =~ s{\|(\d+)\|,\|(\d+)\|}{\|$1,$2\|}sgo;
        $component_string =~ s{([a-zA-Z0-9_]+)\|\(\|([,\d]+)\|\)}{$1($2)|}sgo;

        # Remove leading and trailing pipes
        $component_string =~ s{^\|}{}sgio;
        $component_string =~ s{\|$}{}sgio;

        $components{$component_string}++;

        my @component_parts = split (m{\|}, $component_string);

        #
        # If this grammar rule contains Perl code, assemble it between the various
        # component parts it was split into. This "reconstructive" step is definitely bad design
        # The way to do it properly would be to tokenize the grammar using a full-blown lexer
        # which should hopefully come up in a future version.
        #

        my $nesting_level = 0;
        my $pos = 0;
        my $code_start;

        while (1) {
          if (defined $component_parts[$pos] and $component_parts[$pos] =~ m{\{}so) {
            $code_start = $pos if $nesting_level == 0;  # Code segment starts here
            my $bracket_count = ($component_parts[$pos] =~ tr/{//);
            $nesting_level = $nesting_level + $bracket_count;
          }

          if (defined $component_parts[$pos] and $component_parts[$pos] =~ m{\}}so) {
            my $bracket_count = ($component_parts[$pos] =~ tr/}//);
            $nesting_level = $nesting_level - $bracket_count;
            if ($nesting_level == 0) {
              # Resemble the entire Perl code segment into a single string
              splice(@component_parts, $code_start, ($pos - $code_start + 1) , join ('', @component_parts[$code_start..$pos]));
              $pos = $code_start + 1;
              $code_start = undef;
            }
          }
          last if $pos > $#component_parts;
          $pos++;
        }

        push @components, \@component_parts;
      }

      my $rule = GenTest::Grammar::Rule->new(
        name => $rule_name,
        components => \@components
      );
      $rules{$rule_name} = $rule;
    }

  $grammar->[GRAMMAR_RULES] = \%rules;
  return STATUS_OK;
}

# First parameter is rule name, second is the grammar number
sub rule {
  return $_[0]->[GRAMMAR_RULES]->{$_[1]};
}

sub rules {
  return $_[0]->[GRAMMAR_RULES];
}

# Deletes from all grammars
sub deleteRule {
  delete $_[0]->[GRAMMAR_RULES]->{$_[1]};
}

sub cloneRule {
  my ($grammar, $old_rule_name, $new_rule_name) = @_;

  # Rule consists of
  # rule_name
  # pointer to array called components
  #   An element of components is a pointer to an array of component_parts

  my $components = $grammar->[GRAMMAR_RULES]->{$old_rule_name}->[1];

  my @new_components;
  for (my $idx=$#$components; $idx >= 0; $idx--) {
    my $component = $components->[$idx];
    my @new_component_parts = @$component;
    # We go from the highest index to the lowest.
    # So "push @new_components , \@new_component_parts ;" would give the wrong order
    unshift @new_components , \@new_component_parts ;
  }

  my $new_rule = GenTest::Grammar::Rule->new(
    name => $new_rule_name,
    components => \@new_components
  );
  $grammar->[GRAMMAR_RULES]->{$new_rule_name} = $new_rule;

}

#
# Check if the grammar is tagged with query properties such as RESULTSET_ or ERROR_1234
#
sub hasProperties {
  if ($_[0]->[GRAMMAR_STRING] =~ m{RESULTSET_|ERROR_|QUERY_}so) {
    return 1;
  } else {
    return 0;
  }
}

##
## Make a new grammar using the patch_grammar to replace old rules and
## add new rules.
##
sub patch {
    my ($self, $patch_grammar) = @_;

    sayDebug("Applying a patch to grammar ".$self->file);
    my $patch_rules = $patch_grammar->rules();
    my $rules = $self->rules();

    foreach my $ruleName (sort keys %$patch_rules) {
        if ($ruleName =~ /^query_init_add/) {
            if (defined $rules->{'query_init'}) {
                $rules->{'query_init'} .= '; ' . $patch_rules->{$ruleName}
            }
            else {
                $rules->{'query_init'} = $patch_rules->{$ruleName}
            }
        }
        elsif ($ruleName =~ /^thread(\d+)_init_add/) {
            if (defined $rules->{'thread'.$1.'_init'}) {
                $rules->{'thread'.$1.'_init'} .= '; ' . $patch_rules->{$ruleName}
            }
            else {
                $rules->{'thread'.$1.'_init'} = $patch_rules->{$ruleName}
            }
        }
        else {
            $rules->{$ruleName} = $patch_rules->{$ruleName};
        }
    }

    $self->[GRAMMAR_RULES]= $rules;
}


sub firstMatchingRule {
    my ($self, @ids) = @_;
    foreach my $x (@ids) {
        return $self->rule($x) if defined $self->rule($x);
    }
    return undef;
}

##
## The "body" of topGrammar
##

sub topGrammarX {
    my ($self, $level, $max, @rules) = @_;
    if ($max > 0) {
        my $result={};
        foreach my $rule (@rules) {
            foreach my $c (@{$rule->components()}) {
                my @subrules = ();
                foreach my $cp (@$c) {
                    push @subrules,$self->rule($cp) if defined $self->rule($cp);
                }
                my $componentrules =
                    $self->topGrammarX($level + 1, $max -1,@subrules);
                if (defined  $componentrules) {
                    foreach my $sr (keys %$componentrules) {
                        $result->{$sr} = $componentrules->{$sr};
                    }
                }
            }
            $result->{$rule->name()} = $rule;
        }
        return $result;
    } else {
        return undef;
    }
}


##
## Produce a new grammar which is the toplevel $level rules of this
## grammar
##

sub topGrammar {
    my ($self, $levels, @startrules) = @_;

    my $start = $self->firstMatchingRule(@startrules);

    my $rules = $self->topGrammarX(0,$levels, $start);

    return GenTest::Grammar->new(grammar_rules => $rules);
}

1;
