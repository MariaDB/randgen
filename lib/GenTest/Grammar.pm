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
use constant GRAMMAR_SERVER_VERSION_COMPATIBILITY => 5;

1;

sub new {
  my $class = shift;

  my $grammar = $class->SUPER::new({
    'grammar_file'   => GRAMMAR_FILE,
    'redefine_files'  => GRAMMAR_REDEFINES,
    'compatibility'  => GRAMMAR_SERVER_VERSION_COMPATIBILITY,
  }, @_);

  $grammar->[GRAMMAR_FEATURES]= [];
  $grammar->[GRAMMAR_RULES] = {};
  $grammar->[GRAMMAR_SERVER_VERSION_COMPATIBILITY]= (
    defined $grammar->[GRAMMAR_SERVER_VERSION_COMPATIBILITY]
    ? versionN6($grammar->[GRAMMAR_SERVER_VERSION_COMPATIBILITY])
    : '000000'
  );

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

sub check_compatibility {
  my ($grammar, $versions, $positive_check)= @_;
  sayDebug("Checking ".($positive_check ? 'compatibility' : 'incompatibility')." of ".$grammar->[GRAMMAR_SERVER_VERSION_COMPATIBILITY]." against $versions");
  return 1 if $grammar->[GRAMMAR_SERVER_VERSION_COMPATIBILITY] eq '0000';
  my $server_ver6= $grammar->[GRAMMAR_SERVER_VERSION_COMPATIBILITY];
  my $server_ver4= substr($server_ver6,0,4);
  my @compat_requirements= $versions=~ /([\d\.]+(?:e|-[0-9]+)?(?:,\s*[\d\.]+(?:e|-[0-9]+)?)*)/gs;
  my $compatible= 0;
  if ($positive_check) {
    my $max4= '0000';
    COMPAT:
    foreach my $cr (@compat_requirements) {
      my @cr= split /,/, $cr;
      foreach my $c (@cr) {
        my $compat6= versionN6($c);
        my $compat4= substr($compat6,0,4);
        $max4= $compat4 if $compat4 gt $max4;
        if ($compat4 eq $server_ver4) {
          # same major version;
          # if server version same or higher than compatibility, then compatible,
          # otherwise not compatible
          $compatible = ($server_ver6 ge $compat6);
          last COMPAT;
        }
      }
    }
    return $compatible || $max4 eq '0000' || $server_ver4 gt $max4;
  } else {
    my $min4= '9999';
    INCOMPAT:
    foreach my $ir (@compat_requirements) {
      my @ir= split /,/, $ir;
      foreach my $i (@ir) {
        my $incompat6= versionN6($i);
        my $incompat4= substr($incompat6,0,4);
        $min4= $incompat4 if $min4 gt $incompat4;
        if ($incompat4 eq $server_ver4) {
          # same major version;
          # if server version lower than incompatibility, then compatible,
          # otherwise not compatible
          $compatible = ($server_ver6 lt $incompat6);
          last INCOMPAT;
        }
      }
    }
    return $compatible || $min4 eq '9999' || $server_ver4 lt $min4;
  }
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

  # Grammars can have pragmas:
  # - #include <other grammar>
  # - #compatibility <version>[,<version>...]
  # - #feature <feature>[,<feature>...]

  while ($grammar_string =~ s{#compatibility\s+([-\d\.]+).*$}{}mi) {
    unless ($grammar->[GRAMMAR_SERVER_VERSION_COMPATIBILITY] eq '000000' or $grammar->check_compatibility($1,my $positive_check=1)) {
      sayWarning("Grammar ".$grammar->file." does not meet compatibility requirements, ignoring");
      return;
    }
  }

  while ($grammar_string =~ s{#include [<"](.*?)[>"]$}{
    {
      my $include_string;
      my $include_file = $1;
            open (IF, $1) or die "Unable to open include file $include_file: $!";
            read (IF, $include_string, -s $include_file) or die "Unable to open $include_file: $!";
      $include_string;
  }}mie) {};

  while ($grammar_string =~ s{#features?\s+([- \/\w\d,]+)}{}mi) {
    push @{$grammar->[GRAMMAR_FEATURES]}, map { s/^\s*(.*?)\s*$/$1/; $_ } split /,/, $1;
  }

  # Grammars can contain "reverse executable comments" -- imitation of feature MDEV-7381
  # Syntax is /*!!nnnnnn ... */.
  # If nnnnnn is less than the server version, it should be executed,
  # and we'll convert it into a normal executable comment.
  # Otherwise (if nnnnnn is greater or equal than the server version),
  # it shouldn't be executed, and we'll convert it into a normal comment.
  
  while ($grammar_string =~ s{\/\*\!\!(\d{6})}{
    {
      my $ver = $1;
      (isOlderVersion($grammar->[GRAMMAR_SERVER_VERSION_COMPATIBILITY],$ver)
        ? '/*!' : '/*');
  }}mie) {};

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

  foreach my $rule_string (@rule_strings) {
    my ($rule_name, $components_string) = $rule_string =~ m{^(.*?)\s*:(.*)$}is;
    $rule_name =~ s{[\r\n]}{}gsio;
    $rule_name =~ s{^\s*}{}gsio;

    next if $rule_name eq '';
    if (exists $rules{$rule_name}) {
      say("Warning: Rule $rule_name is defined twice.") ;
    }
    $rules{$rule_name} = $components_string;
  }

  # Now we have all the rules extracted from grammar files, time to parse

  foreach my $rule_name (keys %rules) {

    my $components_string = $rules{$rule_name};
    my @orig_component_strings = split (m{\|}, $components_string);

    #
    # First check the component for compatibility and incompatibility markers
    # /* compatibility X.Y.Z, A.B.C */ and similar markers are set when the component
    # requires a server version X.Y.Z or higher or A.B.C or higher
    # /* incompatibility X.Y.Z, A.B.C */ and similar markers are set when
    # the component is no longer applicable starting from X.Y.Z and A.B.C
    #
    # For the component to be compatible or incompatible, the compatibility marker
    # should have at least one match. That is, for the above example, if X.Y.Z == 10.2.37 and A.B.C == 10.3.18,
    # the server version should be (ver 10.1- or ver 10.2 and >= 10.2.37 OR ver 10.3 and >= 10.3.18 or ver 10.4+)
    # Thus, 10.2.41, 10.3.18 and 10.4.0 are compatible; 10.3.16 is not.
    #
    # For the component to be incompatible, it should either break compatibility rules above,
    # or there should be an incompatibility marker (comment) with a match.
    # For the incompatibility example above, to remain compatible,
    # the server version should be (ver 10.2 and < 10.2.37 OR ver 10.3 and < 10.3.18 or ver 10.4+)
    # Thus, 10.3.16 is compatible; 10.2.41, 10.3.18 and 10.4.0 are not.
    #
    # While it's a rare case, a component can have both incompatibility
    # and compatibility requirements

    my @compatible_component_strings= ();
    COMPONENT:
    foreach my $cs (@orig_component_strings)
    {
      # First check for incompatibilities
      if  ($cs=~ s/\/\*\s*incompatibility\s+([\d\.]+(?:e|-[0-9]+)?(?:,\s*[\d\.]+(?:e|-[0-9]+)?)*)\s*\*\///gs && $grammar->[GRAMMAR_SERVER_VERSION_COMPATIBILITY] ne '0000') {
        unless ($grammar->check_compatibility($1,my $positive=0)) {
          sayDebug("Component $cs is incompatible with the requested ".$grammar->[GRAMMAR_SERVER_VERSION_COMPATIBILITY]);
          next COMPONENT;
        }
      }
      if ($cs=~ s/\/\*\s*compatibility\s+([\d\.]+(?:e|-[0-9]+)?(?:,\s*[\d\.]+(?:e|-[0-9]+)?)*)\s*\*\///gs && $grammar->[GRAMMAR_SERVER_VERSION_COMPATIBILITY] ne '0000') {
        unless ($grammar->check_compatibility($1,my $positive=1)) {
          sayDebug("Component $cs is incompatible with the requested ".$grammar->[GRAMMAR_SERVER_VERSION_COMPATIBILITY]);
          next COMPONENT;
        }
      }
      push @compatible_component_strings, $cs;
    }
    if (scalar(@compatible_component_strings) == 0) {
      # If we removed all component strings due to incompability,
      # we can't ignore the rule itself, but we'll make it empty
      push @compatible_component_strings, '';
    }
    @orig_component_strings= @compatible_component_strings;

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
        if (defined $component_parts[$pos] and $component_parts[$pos] =~ m{\{}s) {
          $code_start = $pos if $nesting_level == 0;  # Code segment starts here
          my $bracket_count = ($component_parts[$pos] =~ tr/{//);
          $nesting_level = $nesting_level + $bracket_count;
        }

        if (defined $component_parts[$pos] and $component_parts[$pos] =~ m{\}}s) {
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
  if ($_[0]->[GRAMMAR_STRING] =~ m{RESULTSET_|ERROR_|QUERY_}s) {
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
