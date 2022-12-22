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

package GenTest::Generator::FromParser;

require Exporter;
@ISA = qw(GenTest::Generator GenTest);

use strict;
use Constants;
use GenTest::Random;
use GenTest::Generator;
use GenUtil;
use GenTest;
use Cwd;
use Carp;
use Data::Dumper;

use constant PARSER_MAX_DEPTH  => 3;
use constant PARSER_MODE_MARIADB => 1;
use constant PARSER_MODE_ORACLE  => 2;

my %parserRules= ();
my %parserTokens= ();

# Initialized and populated, but not used in the current logic
my %parserDefines= ();
my %parserStartExprTokens= ();
my @parserIncludes= ();
my @parserExecutableBlocks= ();
# There are some tokens which are only mentioned in %left / %right / %nonassoc
# e.g. EMPTY_FROM_CLAUSE. Not sure what it means, for now we'll use %left
# and %right as a sign that something may be an empty token
# (unless defined otherwise);
my @parserLeftsRights= ();

sub new {
  my $class = shift;
  my $generator = $class->SUPER::new(@_);

  if (not defined $generator->parser()) {
    croak("FATAL ERROR: Parser source directory not defined\n");
  }
  if (not defined $generator->parserMode() or $generator->parserMode() eq 'mariadb') {
    $generator->setParserMode(PARSER_MODE_MARIADB);
  } elsif ($generator->parserMode() eq 'oracle') {
    $generator->setParserMode(PARSER_MODE_ORACLE);
  } else {
    croak("FATAL ERROR: Unknown parser mode: ".$generator->parserMode()."\n");
  }

  $generator->parseParser($generator->parser());

  if (not defined $generator->prng()) {
    $generator->[GENERATOR_PRNG] = GenTest::Random->new(
      seed => $generator->[GENERATOR_SEED] || 0,
    );
  }
  return $generator;
}

sub parseParser {
  my ($generator, $parser)= @_;
  unless (-e $parser and -d $parser) {
    croak("FATAL ERROR: Parser source directory $parser does not exist or not a directory\n");
  }
  foreach my $f ('sql_yacc.yy','gen_lex_token.cc','lex.h','sql_lex.cc') {
    unless (-e "$parser/sql/$f") {
      croak("FATAL ERROR: $parser/sql/$f does not exist\n");
    }
  }

  my $main_parser= `cat $parser/sql/sql_yacc.yy` || croak("FATAL ERROR: Could not read sql_yacc.yy\n");
  my $gen_lex_token= `cat $parser/sql/gen_lex_token.cc` || croak("FATAL ERROR: Could not read gen_lex_token.cc\n");
  my $lex_h= `cat $parser/sql/lex.h` || croak("FATAL ERROR: Could not read gen_lex.h\n");
  my $sql_lex_cc= `cat $parser/sql/sql_lex.cc` || croak("FATAL ERROR: Could not read sql_lex.cc\n");

  if ($generator->parserMode() == PARSER_MODE_ORACLE) {
    ###########################
    # For ORACLE mode, replace
    #    "/* Start SQL_MODE_ORACLE_SPECIFIC"
    # with
    #    "/* Start SQL_MODE_ORACLE_SPECIFIC */"
    # and
    #    "End SQL_MODE_ORACLE_SPECIFIC */"
    # with
    #    "/* End SQL_MODE_ORACLE_SPECIFIC */"
    # and
    #    "/* Start SQL_MODE_DEFAULT_SPECIFIC */"
    # with
    #    "/* Start SQL_MODE_DEFAULT_SPECIFIC"
    # and
    #    "/* End SQL_MODE_DEFAULT_SPECIFIC */"
    # with
    #    "End SQL_MODE_DEFAULT_SPECIFIC */"
    ###########################

    $main_parser =~ s/(\/\*\s*Start\s+SQL_MODE_ORACLE_SPECIFIC)/$1 \*\//g;
    $main_parser =~ s/(End\s+SQL_MODE_ORACLE_SPECIFIC\s*\*\/)/\/\* $1/g;
    $main_parser =~ s/(\/\*\s*Start\s+SQL_MODE_DEFAULT_SPECIFIC)\s*\*\//$1/g;
    $main_parser =~ s/\/\*\s*(End\s+SQL_MODE_DEFAULT_SPECIFIC\s*\*\/)/$1/g;
  }

  # Remove comments
  $main_parser =~ s/\/\/.*?\n//sg;
  while ($main_parser =~ s/\/\*.*?\*\///sg) {};

  # Extract executable blocks
  $main_parser= extract_executable_blocks($main_parser);

  %parserTokens= ($gen_lex_token =~ /set_token\s*\(\s*(\w+)\s*,\s*\"(.*?)\"\s*\)\s*;/gs);
  %parserStartExprTokens= ($gen_lex_token =~ /set_start_expr_token\s*\(\s*(\w+|[\'\"].*?[\'\"]\s*)()s*\)\s*;/gs);
  my @syms= ($lex_h =~ /\{\s*(\"[^\"]*\"\s*,\s*SYM\(\w+\))\}/gs);
  foreach my $s (@syms) {
    $s=~ /^\"(.*?)\"\s*,\s*SYM\((\w+)\)/s;
    $parserTokens{$2}= $1 unless exists $parserTokens{$2};
  }
  @syms= ($sql_lex_cc =~ /case\s+(\w+SYM:\s+return\s+\w+SYM);/gs);
  foreach my $s (@syms) {
    $s=~ /^(\w+):\s+return\s+(\w+SYM)/s;
    $parserTokens{$2}= $parserTokens{$1} unless exists $parserTokens{$2};
  }

  my $in_rule= undef;
  my $rule_desc= '';
  my @alternatives;

  while ($main_parser =~ s/^(.*?\n)//s) {
    my $line= $1;
    if ($line =~ /^\%(?:left|right|nonassoc)\s+(\w+)/) {
      push @parserLeftsRights, $1;
    } elsif ($line =~ /^\#define\s+(\w+)\s+(.*)/) {
      $parserDefines{$1}= $2;
    } elsif ($line =~ /^\#include\s+(\S+)/) {
      push @parserIncludes, $1;
    } elsif ($line =~ /^(\w+):\s*(.*?)\s*$/) {
      my ($name, $tail)= ($1, $2);
      # Store description for the previous rule
      if ($in_rule) {
        $parserRules{$in_rule}= $rule_desc;
        $rule_desc= '';
      }
      if ($tail =~ s/;$//) {
        # All rule on the same line
        $parserRules{$name}= $tail;
        $in_rule= undef;
      } elsif ($tail) {
        # The beginning of the rule on the same line as the name
        $rule_desc= $tail;
        $in_rule= $name;
      } else {
        # Normal rule start: ("name:")
        $in_rule= $name;
        $rule_desc= '';
      }
    } elsif ($in_rule) {
      if ($line =~ /^(.*);\s*$/) {
        $rule_desc.= $1;
        $parserRules{$in_rule}= $rule_desc;
        $in_rule= undef;
        $rule_desc= '';
      } else {
        $rule_desc.= $line;
      }
    }
  }

  foreach my $lr (@parserLeftsRights) {
    $parserTokens{$lr}= '' unless exists $parserTokens{$lr};
  }

  # Dirty hack: I don't know how these symbols are defined, exactly
  # or how extract this information from the parser files
  $parserTokens{COLON_ORACLE_SYM}= ':' unless defined $parserTokens{COLON_ORACLE_SYM};
  $parserTokens{IMPOSSIBLE_ACTION}= '' unless defined $parserTokens{IMPOSSIBLE_ACTION};
  $parserTokens{PERCENT_ORACLE_SYM}= '%' unless defined $parserTokens{PERCENT_ORACLE_SYM};
  $parserTokens{LEFT_PAREN_WITH}= '(' unless defined $parserTokens{LEFT_PAREN_WITH};
  $parserTokens{ORACLE_CONCAT_SYM}= $parserTokens{OR2_SYM} unless defined $parserTokens{ORACLE_CONCAT_SYM};
  $parserTokens{MYSQL_CONCAT_SYM}= $parserTokens{OR2_SYM} unless defined $parserTokens{MYSQL_CONCAT_SYM};
  $parserTokens{PARSE_VCOL_EXPR}= '' ;#unless defined $parserTokens{PARSE_VCOL_EXPR};
  $parserTokens{LEFT_PAREN_ALT}= '(' ;#unless defined $parserTokens{LEFT_PAREN_ALT};

  foreach my $r (keys %parserRules) {
    my $rule= $parserRules{$r};
    my @alternatives= ();
    # After all our cleanups, if the first or the last alternative
    # is empty, it can have no symbols at all
    if ($rule =~ s/^\|//) {
      push @alternatives, '';
    }
    if ($rule =~ s/\|$//) {
      push @alternatives, '';
    }
    while ($rule) {
      my $alt;
      if ($rule =~ s/^(.*?)\s\|\s//s) {
        $alt= $1;
      } else {
        $alt= $rule;
        $rule= '';
      }
      $alt=~ s/^\s*(.*?)\s*$/$1/s;
      while ($alt=~ s/\s+\s/ /s) {};
      push @alternatives, $alt;
    }
    $parserRules{$r} = [ @alternatives ];
  }

  sayDebug(Dumper \%parserRules);
}

sub next {
  my ($generator, $executors) = @_;

  no warnings 'recursion';
  sub expand {
    my ($rule, $depth)= @_;
    unless (defined $parserRules{$rule}) {
      sayError("$rule is not a rule, we shouldn't be here");
      return undef;
    }
    my @alternatives= @{$parserRules{$rule}};
    $generator->prng->shuffleArray(\@alternatives);
   ALTERNATIVE:
    while (scalar(@alternatives)) {
      my $alt= shift @alternatives;
      my $orig_alt= $alt;
      my $res= '';
      while ($alt) {
        if ($alt =~ s/^\s+//s) {
          # Strip leading spaces
        } elsif (
          # Ignore the possibility of executable comments and grammar elements
          # inside them for now, just leave it as is
          ($alt =~ s/^(\/\*.*?\*\/)//s)
          # Something in double quotes
          or ($alt =~ s/^(\".*?\")//)
          # Something in single quotes
          or ($alt =~ s/^\'(.*?)\'//)
        ) {
          my $part= $1;
          $res.= ($res=~/\w$/ ? ' ' : '').$part;
          # Don't know yet what to do with %prec
        } elsif ($alt =~ s/^\%prec(\s)/$1/s) {
          # Ignore %prec directives
          # $res.= '/* %prec */';
        } elsif ($alt =~ s/^(\S+)//) {
          # A word of sorts
          my $word= $1;
          if (defined $parserTokens{$word}) {
            $res.= ($res=~/\w$/ ? ' ' : '').$generator->convert_token($parserTokens{$word});
          } elsif (defined $parserRules{$word}) {
            if (defined $depth->{$word} and $depth->{$word} >= PARSER_MAX_DEPTH) {
              sayDebug("Max depth for rule $word has been reached, cannot use it anymore");
              $res= undef;
              next ALTERNATIVE;
            } else {
              $depth->{$word} = (defined $depth->{$word} ? $depth->{$word} + 1 : 1);
              sayDebug("Depth for $word is now: ".$depth->{$word});
              my $expansion= expand($word, { %$depth });
              if (defined $expansion) {
                $res.= ($res=~/\w$/ ? ' ' : '').$expansion;
              } else {
                sayDebug("Rule $word could not be expanded (deeper levels returned undef)");
                $res= undef;
                next ALTERNATIVE;
              }
            }
          } else {
            # Assuming a literal
            $res.= ($res=~/\w$/ ? ' ' : '').$word;
          }
        } else {
          croak("FATAL ERROR: Something else: '$alt'\n");
        }
      }
      if (defined $res) {
        sayDebug("Rule $rule has been expanded to $res");
        return $res;
      }
    }
    return undef;
  }
  sayDebug("QUERY START");
  my $query= expand('query');
  sayDebug("QUERY END");
  while ($query =~ s/\s+(\s)/$1/g) {};
  return [ $query ];
}

sub convert_token {
  my ($generator, $token)= @_;
  if ($token eq '(id)') {
    return $generator->prng->identifier;
  } elsif ($token eq '(id_quoted)') {
    return $generator->prng->identifierQuoted;
  } elsif ($token eq '(ulonglong)') {
    return $generator->prng->fieldType('int_unsigned');
  } elsif ($token eq '(long)') {
    return $generator->prng->fieldType('mediumint_unsigned');
  } elsif ($token eq '(num)') {
    return $generator->prng->fieldType('smallint_unsigned');
  } elsif ($token eq '(decimal)') {
    # TODO: replace with decimal
    return $generator->prng->fieldType('int_unsigned');
  } elsif ($token eq '(float)') {
    return $generator->prng->float;
  } elsif ($token eq '(text)') {
    # TODO: maybe need real "text"
    return $generator->prng->word('english');
  } elsif ($token eq '(hostname)') {
    # TODO: replace with something hostname-ish
    return $generator->prng->identifier;
  } elsif ($token eq '(bin)') {
    return $generator->prng->bit;
  } elsif ($token eq '(hex)') {
    return $generator->prng->hex;
  } else {
    return $token;
  }
}

sub extract_executable_blocks {
  my $item= shift;
  my $new_item= '';
  while ($item) {
    if ($item =~ s/^([^\{\}]+)\{/\{/s) {
      $new_item.= $1;
    }
    elsif ($item =~ s/^\{//s) {
      my $executable= '{';
      my $balance = 1;
      # For now, just extract the executable block and get ready to referencing
      # to it through a comment in the query. Probably we'll have to deal with it later
      while ($balance != 0 and $item) {
        $item =~ s/^(.*?)([\{\}])//s;
        if ($2 eq '{') {
          $balance++;
        } else {
          $balance--;
        }
        $executable .= $1.$2;
      }
      if ($balance and not $item) {
        die "Unbalanced brackets in the executable comment\n"
      }
      push @parserExecutableBlocks, $executable;
#      $new_item.= "/* exec".$#executable_blocks." */";
    }
    else {
      $new_item.= $item;
      $item= '';
    }
  }
  return $new_item;
}

1;
