# Copyright (c) 2021, MariaDB Corporation Ab.
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

########################################################################
# Module initially created for MDEV-17399 (Add support for JSON_TABLE)
########################################################################

package GenTest::Transform::JsonTables;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenTest;
use GenTest::Transform;
use GenTest::Constants;
use Data::Dumper;

use constant REPLACEMENT_PROBABILITY_PCT => 75;

# Expression in round brackets
# b'..' and x'xxx' (bit-value and hex-value literals) are a special case
# of single-quote use, they can be split because spaces are not allowed there
my $single_quotes_template =
    qr{
        (
            [bx]?\'
                (                       # group 1 - inside quotes
                    (?:
                        (?> [^']+ )    # non-quotes
                    )*
                )
            \'
        )
}xi;
my $double_quotes_template =
    qr{
        (
            \"
                (                       # group 1 - inside quotes
                    (?:
                        (?> [^"]+ )    # non-quotes
                    )*
                )
            \"
        )
}xi;
my $comment_boundaries = qr{\/\*|\*\/};
# On some reason, round brackets don't work inside these patterns
# and need to be matched separately. Maybe they are not the only ones
my $comment_template =
    qr{
        (
            \/\*
                (                       # group 1 - inside comment boundaries
                    (?:
                        (?> (?:[^$comment_boundaries]|[\)\(])+ )    # non-comment-boundaries
                    )*
                )
            \*\/
        )
}xi;
my $executable_comment_boundaries = qr{\/\*\!|\*\/};
my $executable_comment_template =
    qr{
        (
            \/\*!
                (                       # group 1 - inside comment boundaries
                    (?:
                        (?> (?:[^$executable_comment_boundaries]|[\)\(])+ )    # non-comment-boundaries
                    )*
                )
            \*\/
        )
}xi;

my $parens_template =
    qr{
        (\s*
            \(
                (                       # group 1 - inside parens
                    (?:
                        (?> (?:$single_quotes_template|$double_quotes_template|$comment_template|[^()])+ )    # non-parens
                        |
                        (?1)            # recurse to group 1
                    )*
                )
            \)
        )
}xi;

# either a simple fragment without brackets
# or something in round brackets
my $part_select_template = qr{$parens_template|$comment_template|$executable_comment_template|$single_quotes_template|$double_quotes_template|[^();'" ]+|;}xi;

my %replaced_aliases= ();
my %encountered_aliases= ();

sub parse_query 
{
  my $self= shift;
  my $tmp_query= shift;
  my $inside_outer_from= shift;

  my $new_query= '';
  my $table_name= '';
  my $alias= '';
  my $select= '';
  # Context indicators
  my $skip_next_items= 0;
  my $in_from= 0;
  my $in_system_time= 0;
  my $in_partition_pruning= 0;

  sub append_token {
    my ($token, $new_query_ref, $select_ref)= @_;
    # If we are in SELECT collection, we'll add the result to the SELECT;
    # otherwise to the new query directly.
    # It's needed in many places
    if ($$select_ref) {
      $$select_ref.= " $token";
    } else {
      $$new_query_ref.= " $token";
    }
  }

  # Parse the query or query fragment
  while ($tmp_query =~ s/\s*($part_select_template)//xi)
  {
    my $token = $1;
    if ($token =~ /^$executable_comment_template$/xi) {
      if ($token =~ /^\/\*\!(\d+)\s+(.*?)\s*\*\// and not $self->executor->is_compatible($1)) {
        # Executable comment with incompatible version, treat as a usual comment
        append_token($token, \$new_query, \$select);
        next;
      } else {
        # Either the version is compatible, or no version at all.
        # Treat as if it weren't a comment - put the contents back to tmp_query
        $tmp_query= $2.' '.$tmp_query;
        next;
      }
    }
    elsif ($token =~ /^\s*$comment_template\s*$/xi) {
      # TODO: it puts the comment in a wrong position, but we can deal with it later
      append_token($token, \$new_query, \$select);
      next;
    }
    elsif ($skip_next_items) {
      append_token($token, \$new_query, \$select);
      $skip_next_items--;
      next;
    }

    # If the fragment starts with SELECT, we'll start collecting the complete SELECT
    #  or if there had, we ignore them).
    elsif (uc($token) eq 'SELECT') {
      $select= $token;
      $inside_outer_from= 0;
      $in_from= 0;
    }

    # SELECT ends either by one of the words below, or by semicolon, 
    # or when the fragment ends
    # TODO: there must be more
    elsif ($token =~ /^(?:UNION|INTO|RETURNING|;)/i) {
      append_token($token, \$new_query, \$select);
      if ($select) {
        $new_query.= ' '.$select;
        $select= '';
        $in_from= 0;
        $table_name= '';
        $alias= '';
      }
    }

    # Fragment in round brackets -- keep the brackets and process the contents
    elsif ($token =~ /^\s*\((.*)\)\s*$/is) {
      my $sq= $1;
      # We can still be in "in_from" after this, but can't stay in table reference.
      # Partition pruning would be an exception, but we have already ruled it out
      # when PARTITION clause was encountered.
      if ($table_name) {
        $select.= $self->json_table_to_append($table_name);
        $table_name= '';
      }
      # If we are in partition pruning, the contents of the brackets should be
      # a list of partitions, so for our purpose it doesn't count as a part of FROM
      my $res = ' (' . $self->parse_query($sq, ($in_from && not $in_partition_pruning)) . ')';
      $in_partition_pruning= 0;
      append_token($res, \$new_query, \$select);
    }

    # FROM list ends, but SELECT doesn't yet
    # TODO: Is it even important?
    elsif ($token =~ /^(WHERE|HAVING|GROUP|ORDER|LIMIT)$/i) {
      if ($table_name) {
        $select.= $self->json_table_to_append($table_name);
        $table_name= '';
      }
      $select.= " $token";
      $in_from= 0;
    }
    
    elsif ($inside_outer_from or ($select and $in_from))
    {
      if ($token =~ /^(,|STRAIGHT_JOIN|NATURAL|LEFT|RIGHT|JOIN|ON|USING|INNER|OUTER|IGNORE|FORCE|USE)$/i) {
        if ($table_name) {
          $select.= $self->json_table_to_append($table_name);
          $table_name= '';
        }
        if ($token ne 'STRAIGHT_JOIN' and $token ne 'JOIN' and $token ne ',') {
          $in_from= 0;
        }
        $select.= " $token";
      }
      elsif (uc($token) eq 'PARTITION') {
        # Partition pruning starts. There is no point replacing this table
        # with JSON now, as it won't work anyway. So, we'll just return it
        # to SELECT
        if ($table_name) {
          $select.= " $table_name";
          $table_name= '';
        }
        append_token($token, \$new_query, \$select);
        # The flag is needed because otherwise the following partition list
        # will be interpeted as a part of FROM list
        $in_partition_pruning= 1;
      }
      elsif (uc($token) eq 'FOR') {
        # FOR in SELECT list is probably FOR SYSTEM_TIME ...
        # No point to wait for alias anymore, if there is a table, work it
        if ($table_name) {
          $select.= $self->json_table_to_append($table_name);
          $table_name= '';
        }
        append_token($token, \$new_query, \$select);
        # Make a note that we are in SYSTEM_TIME clause now, it will help
        # parsing difficult ones, like FOR SYSTEM_TIME FROM .. TO
        $in_system_time= 1;
        $skip_next_items= 1;
      }
      elsif ($in_system_time and uc($token) eq 'ALL') {
        # End of FOR SYSTEM_TIME ALL clause
        $in_system_time= 0;
        append_token($token, \$new_query, \$select);
      }
      elsif ($in_system_time and uc($token) eq 'AS') {
        # In the middle of FOR SYSTEM_TIME AS OF ... clause.
        # Now we know that there are only 2 items left, so we can
        # "close" the clause automatically after skipping next 2
        $skip_next_items= 2;
        $in_system_time= 0;
        append_token($token, \$new_query, \$select);
      }
      elsif (uc($token) eq 'AS') {
      # AS can't be a table name. If we already have a table name,
      # further comes the alias; otherwise it probably belongs
      # to a previous subquery
        unless ($table_name) {
          $skip_next_items= 1;
          append_token($token, \$new_query, \$select);
        }
      }
      elsif ($in_system_time and uc($token) eq 'FROM') {
        # In the middle of FOR SYSTEM_TIME FROM ... TO ... clause
        # Now we know that there are 3 items left, so we can
        # "close" the clause automatically after skipping next 3
        $skip_next_items= 3;
        $in_system_time= 0;
        append_token($token, \$new_query, \$select);
      }
      elsif ($table_name and $token =~ /^(.*?)(,)?$/) {
        # Found the alias, we'll use it for the JSON table
        $select.= $self->json_table_to_append($table_name, $1).$2;
        $table_name= '';
      }
      # Identifier, assuming table name, still a chance for later alias
      else {
        $table_name= $token;
      }
    }

    # Not inside FROM: no conversion needed, just add the next part to the select
    elsif ($select) {
      # Our main part -- FROM list starts (or continues)
      # TODO: STRAIGHT_JOIN should also be here, but it needs to be distinguished
      # from SELECT STRAIGHT_JOIN variant
      if ($token =~ /^(?:FROM|JOIN)$/) {
        $in_from= 1;
      }
      $select .= " $token";
    }

    # Not inside SELECT: no conversion needed, just add the next part to the query
    else {
      $new_query .= " $token";
    }
  };

  # Final fragment, in case we have something left
  if ($select or $inside_outer_from) {
    if ($table_name) {
      $select.= $self->json_table_to_append($table_name);
      $table_name= '';
    }
    $new_query .= " $select";
  }

  return $new_query;
}

sub json_table_to_append
{
  my ($self, $table_name, $alias)= @_;

  # We don't want to convert DUAL or store it in encountered tables
  return ' DUAL' if $table_name eq 'DUAL';

  $alias= $table_name unless defined $alias;
  my $res= '';

  # We will replace REPLACEMENT_PROBABILITY_PCT % encountered tables
  if ($self->random->uint16(1,100) <= REPLACEMENT_PROBABILITY_PCT)
  {
    # Remove the prefix from a fully-qualified name, not needed for an alias
    $alias =~ s/.*\.(.+)$/$1/;
    # Number of columns in new JSON_TABLE
    my $colnum= $self->random->uint16(1,20);
    # First argument for JSON_TABLE
    my $jdoc= undef;
    # Sometimes we'll use a constant as the first argument (generated doc
    # or a loaded file), and sometimes we'll attempt to refer to a field
    # from a previously encountered table
    # TODO: Could also be a subquery
    if (scalar(keys %encountered_aliases) and $self->random->uint16(0,1))
    {
      # Trying to use a field. For this, we need (simultaneously):
      # - some luck (50%)
      # - previously encountered aliases
      # - the chosen alias should be a table for which metadata has known columns
      # TODO: it means that constant subqueries will never be referenced,
      #       need to do something about it (maybe)
      my $refalias= $self->random->arrayElement([ sort keys %encountered_aliases ]);
      if (defined $replaced_aliases{$refalias}) {
        $jdoc= $refalias.'.col'.$self->random->uint16(1,$replaced_aliases{$refalias});
      } else {
        my $reftable= $encountered_aliases{$refalias};
        $reftable =~ s/`//g;
        my $fields= $self->executor()->metaColumns($encountered_aliases{$reftable});
        if ($fields and scalar(@$fields)) {
          $jdoc= $refalias.'.'.$self->random->arrayElement($fields);
        }
      }
      # Make it a valid JSON doc for sure -- wrap into an array or object
      if (defined $jdoc) {
        $jdoc= ($self->random->uint16(0,1) ? "CONCAT('[\"',${jdoc},'\"]')" : "CONCAT('{\"contents\":\"',${jdoc},'\"}')");
      }
    }
    # If the above didn't succeed, jdoc remains undefined, so we fall back
    # to the random generation
    unless (defined $jdoc) {
      $jdoc= $self->random->json();
      if (substr($jdoc,0,9) eq 'LOAD_FILE' and $self->random->uint16(0,1)) {
        my $charsets= $self->executor()->metaCharactersets();
        # DISABLED due to MDEV-25188, MDEV-25192
#        if ($charsets and scalar(@$charsets)) {
#          my $charset= $self->random->arrayElement($charsets);
#          $jdoc= 'CONVERT('.$jdoc.' USING '.$charset.')';
#        }
      }
    }
    my $jtable= 'JSON_TABLE('.$jdoc.', '.$self->random->jsonPath().' '.$self->random->jsonTableColumnList($colnum).') AS '.$alias;
    $replaced_aliases{$alias}= $colnum;
    $res= " $jtable";
  } else
  { # Not doing replacement, returning the original table
    $res= ($table_name eq $alias ? " $table_name" : " $table_name AS $alias");
  }
  # Save the encountered alias for future references, regardless whether
  # replacement was performed or not
  $encountered_aliases{$alias}= $table_name;
  return $res;
}

# After table replacement was done, we need to replace aliasX.colname entires
# for tables which have been replaced with JSON_TABLE columns
sub replace_columns
{
  my ($self, $tmp_query)= @_;
  my $query= '';
  while ($tmp_query =~ s/\s*($part_select_template)//xi)
  {
    my $token= $1;
    if ($token =~ /^\s*\((.*)\)\s*$/is) {
      $query.= ' (' . $self->replace_columns($1) . ')';
    } elsif ($token =~ /^(\`[^\`]+\`|\w+)\s*\.\s*(\`[^\`]+\`|\w+)$/) {
      # TODO: We can't meaningfully replace unqualified column names, unfortunately
      my ($alias, $colname)= ($1,$2);
      $alias=~ s/^\`(.*)\`$/$1/;
      $colname=~ s/^\`(.*)\`$/$1/;
      if (my $colnum= $replaced_aliases{$alias}) {
        my $new_colname= 'col'.$self->random->uint16(1,$colnum);
        $token =~ s/^(.*)$colname(\`?)$/$1${new_colname}$2/;
      }
      $query.= " $token";
    } else {
      $query.= " $token";
    }
  }
  return $query;
}

sub variate {
  my ($self, $orig_query, $executor, $gendata_flag) = @_;
  # We won't touch gendata queries
  return $orig_query if $gendata_flag;
  # Don't touch queries which already have JSON_TABLEs
  return $orig_query if $orig_query =~ /JSON_TABLE/i;

  # We variate (by replacing tables and views on the FROM list with JSON tables)
  # statements which have SELECT .. FROM (except REVOKE .. SELECT .. FROM)
  if ($orig_query !~ /SELECT.*FROM.*/ or $orig_query =~ /REVOKE.*SELECT/) {
    return $orig_query;
  };

  $self->executor($executor) if $executor;

  sayDebug("JsonTables is processing query $orig_query");

  # Reset
  %replaced_aliases= ();
  %encountered_aliases= ();

  my $query= $self->parse_query($orig_query);

  if (scalar keys(%replaced_aliases)) {
    $query= $self->replace_columns($query);
  }
  # Workaround for MDEV-25138 (JSON_TABLE ())
  # and other potentially harmful spaces between function names and brackets
  $query=~ s/(\w)\s+\(/$1\(/g;

  sayDebug("JsonTables is returning query $query");
  return $query;
}

1;
