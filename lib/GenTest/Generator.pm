# Copyright (C) 2008-2009 Sun Microsystems, Inc. All rights reserved.
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

package GenTest::Generator;

# For the sake of simplicity, all GENERATOR_* properties are defined here
# even though most of them would pertain only to GenTest::Generator::FromGrammar

require Exporter;

@ISA = qw(Exporter GenTest);

@EXPORT = qw(
  GENERATOR_GRAMMARS
  GENERATOR_SEED
  GENERATOR_PRNG
  GENERATOR_TMPNAM
  GENERATOR_THREAD_ID
  GENERATOR_SEQ_ID
  GENERATOR_GLOBAL_FRAME
  GENERATOR_PARTICIPATING_RULES
  GENERATOR_ANNOTATE_RULES
  GENERATOR_PARSER
  GENERATOR_PARSER_MODE
  GENERATOR_GRAMMAR_POOL
);

use strict;

use GenUtil;

use constant GENERATOR_GRAMMARS            =>  2;
use constant GENERATOR_SEED                =>  3;
use constant GENERATOR_PRNG                =>  4;
use constant GENERATOR_TMPNAM              =>  5;
use constant GENERATOR_THREAD_ID           =>  6;
use constant GENERATOR_SEQ_ID              =>  7;
use constant GENERATOR_VARIATORS           =>  8;
use constant GENERATOR_GLOBAL_FRAME        => 12;
use constant GENERATOR_PARTICIPATING_RULES => 13;       # Stores the list of rules used in the last generated query
use constant GENERATOR_ANNOTATE_RULES      => 14;
use constant GENERATOR_PARSER              => 16;
use constant GENERATOR_PARSER_MODE         => 17;
use constant GENERATOR_GRAMMAR_POOL        => 18;

use constant VARIATION_PROBABILITY => 10; # Per cent

sub new {
  my $class = shift;
  my $generator = $class->SUPER::new({
    'grammars'       => GENERATOR_GRAMMARS,
    'seed'           => GENERATOR_SEED,
    'prng'           => GENERATOR_PRNG,
    'thread_id'      => GENERATOR_THREAD_ID,
    'annotate_rules' => GENERATOR_ANNOTATE_RULES,
    'parser'         => GENERATOR_PARSER,
    'parser_mode'    => GENERATOR_PARSER_MODE,
    'variators'      => GENERATOR_VARIATORS,
  }, @_);

  if ($generator->[GENERATOR_VARIATORS] && scalar(@{$generator->[GENERATOR_VARIATORS]})) {
    my @variators= ();
    foreach my $vn (@{$generator->[GENERATOR_VARIATORS]}) {
      eval ("require GenTest::Transform::'".$vn) or croak $@;
      my $variator = ('GenTest::Transform::'.$vn)->new();
      push @variators, $variator;
    }
    $generator->[GENERATOR_VARIATORS]= \@variators;
  }
  return $generator;
}

sub adjustWeights {
  my $generator= shift;
  if ($generator->[GENERATOR_GRAMMARS]) {
    # Adjust (normalize) grammar weights
    my $multiplier= 1;
    my @grammar_pool= ();
    foreach my $g (@{$generator->[GENERATOR_GRAMMARS]}) {
      $multiplier= int(1/$g->weight) if $g->weight > 0 and $multiplier < int(1/$g->weight);
    }
    for (my $i=0; $i<=$#{$generator->[GENERATOR_GRAMMARS]}; $i++) {
      my $factor= $generator->[GENERATOR_GRAMMARS]->[$i]->weight * $multiplier;
      foreach (1..$factor) {
        push @grammar_pool, $i;
      }
    }
    # GRAMMAR_POOL contains an array of (non-unique) grammar IDs from
    # GRAMMAR array, the count of each ID is based on the grammar weight
    $generator->[GENERATOR_GRAMMAR_POOL]= [ @grammar_pool ];
  }
}

sub prng {
  return $_[0]->[GENERATOR_PRNG];
}

sub grammars {
  return $_[0]->[GENERATOR_GRAMMARS];
}

sub variators {
  return $_[0]->[GENERATOR_VARIATORS];
}

sub threadId {
  return $_[0]->[GENERATOR_THREAD_ID];
}

sub parser {
  return $_[0]->[GENERATOR_PARSER];
}

sub parserMode {
  return $_[0]->[GENERATOR_PARSER_MODE];
}

sub setParserMode {
  $_[0]->[GENERATOR_PARSER_MODE]= $_[1];
}

sub setSeed {
  $_[0]->[GENERATOR_SEED] = $_[1];
  $_[0]->[GENERATOR_PRNG]->setSeed($_[1]) if defined $_[0]->[GENERATOR_PRNG];
}

sub setThreadId {
  $_[0]->[GENERATOR_THREAD_ID] = $_[1];
}

sub variateQuery {
  my ($self,$orig_query,$executor)= @_;
  # Do not variate queries with /*executorN */ comments
  return [ $orig_query ] if ($orig_query =~ /\/\*executor\d/);
  
  my @variators= @{$self->[GENERATOR_VARIATORS]};
  $self->prng->shuffleArray(\@variators);
  my @queries= ($orig_query);
  VARIATOR:
  foreach my $v (@variators) {
    next if isOlderVersion($executor->server->version(),$v->compatibility);
    my @new_queries= ();
    sayDebug("Original queries before variation: ".scalar(@queries)." [\n".(join "\n    ",@queries)."\n]");
    QUERY:
    foreach my $q (@queries) {
      next if $q =~ /^\s*$/;
      # Variation happens with the configured probability
      if ($self->prng->uint16(1,100) > VARIATION_PROBABILITY || $q =~ /SKIP_VARIATION/) {
        push @new_queries, $q;
        next QUERY;
      }
      my $qs= $v->variate($q,$executor);
      # Something went wrong
      if (ref $qs eq '') {
        sayWarning("Variator ".$v->name." returned a scalar");
        return $qs;
      }
      # flatten 2-level arrays (e.g. if there is TRANFORM_CLEANUP block)
      my @qs= ();
      foreach my $q (@$qs) {
        if (ref $q eq '') {
          push @qs, $q;
        } elsif (ref $q eq 'ARRAY') {
          push @qs, @$q;
        }
      }
      if (scalar(@qs) > 1 || ($qs[0] ne $q)) {
        sayDebug($v->name." variator modified the query\nfrom [ $q ] to [ \n".(join "\n    ", @qs)." \n]");
      } elsif (scalar(@$qs)==0) {
        sayWarning($v->name." returned an empty query");
      } else {
        sayDebug($v->name." variator apparently hasn't done anything");
      }
      push @new_queries, @qs;
    }
    @queries= @new_queries;
  }
  sayDebug("Final queries after variation: ".scalar(@queries)." [\n".(join "\n    ",@queries)."\n]");
  return \@queries;
}
1;
