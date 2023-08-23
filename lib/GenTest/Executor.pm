# Copyright (c) 2008,2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2020, 2023, MariaDB
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

package GenTest::Executor;

require Exporter;
@ISA = qw(GenTest Exporter);

@EXPORT = qw(
  EXECUTOR_ENGINES
  EXECUTOR_EXPLAIN_COUNTS
  EXECUTOR_EXPLAIN_QUERIES
  EXECUTOR_ERROR_COUNTS
  EXECUTOR_STATUS_COUNTS
  EXECUTOR_FLAG_SKIP_STATS
  EXECUTOR_FLAG_NON_EXISTING_ALLOWED
  EXECUTOR_CURRENT_SCHEMA
  EXECUTOR_MAX_ROWS_THRESHOLD
  EXECUTOR_QNO
  EXECUTOR_CONNECTION
);

use strict;
use Carp;
use Data::Dumper;
use Constants;
use Constants::MariaDBErrorCodes;
use GenUtil;
use GenTest;

use constant EXECUTOR_DSN      => 0;
use constant EXECUTOR_CONNECTION  => 1;
use constant EXECUTOR_ID       => 2;
use constant EXECUTOR_QNO      => 3;
use constant EXECUTOR_ENGINES  => 4;
use constant EXECUTOR_EXPLAIN_COUNTS    => 5;
use constant EXECUTOR_EXPLAIN_QUERIES    => 6;
use constant EXECUTOR_ERROR_COUNTS    => 7;
use constant EXECUTOR_STATUS_COUNTS    => 8;
use constant EXECUTOR_DEFAULT_SCHEMA    => 9;
use constant EXECUTOR_SCHEMA_METADATA    => 10;
use constant EXECUTOR_COLLATION_METADATA  => 11;
use constant EXECUTOR_META_CACHE    => 12;
use constant EXECUTOR_CHANNEL      => 13;
use constant EXECUTOR_SQLTRACE      => 14;
use constant EXECUTOR_NO_ERR_FILTER             => 15;
use constant EXECUTOR_CONNECTION_ID    => 17;
use constant EXECUTOR_FLAGS      => 18;
use constant EXECUTOR_CURRENT_SCHEMA => 19;
use constant EXECUTOR_END_TIME      => 21;
use constant EXECUTOR_USER      => 22;
use constant EXECUTOR_VARDIR => 27;
use constant EXECUTOR_SEED => 38;
use constant EXECUTOR_SERVER => 40;
use constant EXECUTOR_META_NONSYSTEM_CACHE => 42;
use constant EXECUTOR_META_NONSYSTEM_TS => 43;
use constant EXECUTOR_META_SYSTEM_CACHE => 44;
use constant EXECUTOR_META_SYSTEM_TS => 45;
use constant EXECUTOR_THREAD_ID => 46;

use constant EXECUTOR_FLAG_SKIP_STATS => 1;
use constant EXECUTOR_FLAG_NON_EXISTING_ALLOWED => 2;

use constant EXECUTOR_MAX_ROWS_THRESHOLD  => 5000000;

my %reported_errors;

1;

sub new {
    my $class = shift;
    my $executor = $class->SUPER::new({
        'channel' => EXECUTOR_CHANNEL,
        'dsn' => EXECUTOR_DSN,
        'server'  => EXECUTOR_SERVER,
        'end_time' => EXECUTOR_END_TIME,
        'id' => EXECUTOR_ID,
        'thread_id' => EXECUTOR_THREAD_ID,
        'no-err-filter' => EXECUTOR_NO_ERR_FILTER,
        'seed' => EXECUTOR_SEED,
        'sqltrace' => EXECUTOR_SQLTRACE,
        'user' => EXECUTOR_USER,
        'vardir' => EXECUTOR_VARDIR,
    }, @_);

    $executor->[EXECUTOR_DSN] = $executor->server->dsn($executor->[EXECUTOR_USER]) if not defined $executor->[EXECUTOR_DSN] and defined $executor->server;
    $executor->[EXECUTOR_THREAD_ID]= 0 if not defined $executor->[EXECUTOR_THREAD_ID];
    $executor->[EXECUTOR_QNO]= 0;

    return $executor;
}

# Remains here for PopulateSchema and External scenario,
# when we don't have a server
sub newFromDSN {
  my $self= shift;
  my $dsn= shift;
  if ($dsn =~ m/^dbi:(?:mysql|mariadb):/i) {
    require GenTest::Executor::MRDB;
    return GenTest::Executor::MRDB->new(dsn => $dsn, @_);
  } else {
    croak("Unsupported dsn: $dsn");
  }
}

sub dsn {
  return $_[0]->[EXECUTOR_DSN];
}

sub newFromServer {
  my $self= shift;
  my $server= shift;
  if ($server->dsn =~ m/^dbi:(?:mysql|mariadb):/i) {
    require GenTest::Executor::MRDB;
    return GenTest::Executor::MRDB->new(server => $server, @_);
  } else {
    croak("Unsupported server type, dsn: $server->dsn");
  }
}

sub server {
  return $_[0]->[EXECUTOR_SERVER];
}

sub channel {
    return $_[0]->[EXECUTOR_CHANNEL];
}

sub sendError {
    my ($self, $msg) = @_;
    $self->channel->send($msg);
}

sub connection {
  return $_[0]->[EXECUTOR_CONNECTION];
}

sub user {
  if ($_[1]) {
    $_[0]->[EXECUTOR_USER]= $_[1];
  }
  return $_[0]->[EXECUTOR_USER];
}

sub sqltrace {
    my ($self, $sqltrace) = @_;
    $self->[EXECUTOR_SQLTRACE] = $sqltrace if defined $sqltrace;
    return $self->[EXECUTOR_SQLTRACE];
}

sub end_time {
  return $_[0]->[EXECUTOR_END_TIME];
}

sub set_end_time {
  $_[0]->[EXECUTOR_END_TIME] = $_[1];
}

sub id {
  return $_[0]->[EXECUTOR_ID];
}

sub threadId {
  return $_[0]->[EXECUTOR_THREAD_ID];
}

sub vardir {
  return $_[0]->[EXECUTOR_VARDIR];
}

sub connectionId {
  return $_[0]->[EXECUTOR_CONNECTION_ID];
}

sub setConnectionId {
  $_[0]->[EXECUTOR_CONNECTION_ID] = $_[1];
}

sub flags {
  return $_[0]->[EXECUTOR_FLAGS] || 0;
}

sub setFlags {
  $_[0]->[EXECUTOR_FLAGS] = $_[1];
}

## This array maps SQL State class (2 first letters) to a status. This
## list needs to be extended
my %class2status = (
    "07" => STATUS_SEMANTIC_ERROR, # dynamic SQL error
    "08" => STATUS_SEMANTIC_ERROR, # connection exception
    "22" => STATUS_SEMANTIC_ERROR, # data exception
    "23" => STATUS_SEMANTIC_ERROR, # integrity constraint violation
    "25" => STATUS_RUNTIME_ERROR,  # general query error state
    "42" => STATUS_SYNTAX_ERROR    # syntax error or access rule
                                   # violation

    );

sub defaultSchema {
    my ($self, $schema) = @_;
    if (defined $schema and $self->[EXECUTOR_DEFAULT_SCHEMA] ne $schema) {
      $schema='information_schema' if lc($schema) eq 'information_schema';
      sayDebug("Setting default schema to $schema");
        $self->[EXECUTOR_DEFAULT_SCHEMA] = $schema;
    }
    return $self->[EXECUTOR_DEFAULT_SCHEMA];
}

sub loadCollations {
    carp "loadCollations not defined for ". (ref $_[0]);
    return [[undef,undef]];
}

sub disconnect {
    my $executor = shift;
    $executor->[EXECUTOR_CONNECTION]= undef;
}

sub reportError {
    my ($self, $query, $err, $errstr, $execution_flags) = @_;

    my $msg = [$query,$err,$errstr];

#    if (defined $self->channel) {
#        $self->sendError($msg);
    if (not defined $reported_errors{$err}) {
        my $query_for_print= shorten_message($query);
        say("Executor#".$self->threadId().": Query: $query_for_print failed: $err $errstr (" . status2text(errorType($err)) . "). Further errors of this kind will be suppressed.");
        $reported_errors{$err}++;
    }
}

sub currentSchema {
  my ($executor,$schema) = @_;
  if (defined $schema) {
    sayDebug("Setting current schema to $schema");
    $executor->[EXECUTOR_CURRENT_SCHEMA]= $schema;
  }
  return $executor->[EXECUTOR_CURRENT_SCHEMA];
}


##############################
#### Metadata routines
##############################

#### Caching

sub cacheMetaData {
  my $self= shift;
  my ($collations, $non_system, $system);

  my $vardir= $self->server->vardir;

  # Collation metadata is loaded only once
  unless (defined $self->[EXECUTOR_COLLATION_METADATA]) {
    my @files= glob("$vardir/collations-*");
    if (scalar(@files)) {
      @files= reverse sort @files;
      unless (open(COLL,"$files[0]")) {
        sayError("Executor#".$self->threadId()." failed to open collations file: $!");
        return;
      }
      read(COLL, my $cont, -s "$files[0]");
      close(COLL);
      my $VAR1;
      eval ($cont);
      $collations= $VAR1;
      if ($collations) {
        my $coll= {};
        foreach my $row (@$collations) {
          my ($collation, $charset) = @$row;
          $coll->{$collation} = $charset;
        }
        $self->[EXECUTOR_COLLATION_METADATA] = $coll;
        sayDebug("Executor#".$self->threadId()." has loaded ".scalar(keys %$coll)." collations");
      } else {
        sayError("Executor#".$self->threadId()." failed to load collation metadata");
      }
    } else {
      sayWarning("Executor#".$self->threadId()." at ".$self->dsn." could not find a collation dump");
    }
  }
  my @files= glob("$vardir/system-metadata-*");
  if (scalar(@files)) {
    @files= reverse sort @files;
    if ($files[0] =~ /\/system-metadata-([\d\.]+)$/) {
      my $ts= $1;
      if (not defined $self->[EXECUTOR_META_SYSTEM_TS] or $self->[EXECUTOR_META_SYSTEM_TS] < $ts) {
        unless (open(META,"$files[0]")) {
          sayError("Executor#".$self->threadId()." failed to open system metadata file: $!");
          return;
        }
        read(META, my $cont, -s "$files[0]");
        close(META);
        my $VAR1;
        eval ($cont);
        $system= $VAR1;
        if ($system) {
          $self->[EXECUTOR_META_SYSTEM_TS]= $ts;
          $self->[EXECUTOR_META_SYSTEM_CACHE]= $system;
          sayDebug("Executor#".$self->threadId()." has loaded ".scalar(keys %$system)." system schemas");
        } else {
          sayError("Executor#".$self->threadId()." failed to load system metadata");
        }
      }
    }
  } else {
    sayWarning("Executor#".$self->threadId()." could not find a system metadata dump");
  }

  my @files= glob("$vardir/nonsystem-metadata-*");
  if (scalar(@files)) {
    @files= reverse sort @files;
    if ($files[0] =~ /\/nonsystem-metadata-([\d\.]+)$/) {
      my $ts= $1;
      if (not defined $self->[EXECUTOR_META_NONSYSTEM_TS] or $self->[EXECUTOR_META_NONSYSTEM_TS] < $ts) {
        unless (open(META,"$files[0]")) {
          sayError("Executor#".$self->threadId()." failed to open non-system metadata file: $!");
          return;
        }
        read(META, my $cont, -s "$files[0]");
        close(META);
        my $VAR1;
        eval ($cont);
        $non_system= $VAR1;
        if ($non_system) {
          $self->[EXECUTOR_META_NONSYSTEM_TS]= $ts;
          $self->[EXECUTOR_META_NONSYSTEM_CACHE]= $non_system;
          sayDebug("Executor#".$self->threadId()." has loaded ".scalar(keys %$non_system)." non-system schemas");
        } else {
          sayError("Executor#".$self->threadId()." failed to load non-system metadata");
        }
      }
    }
  } else {
    sayWarning("Executor#".$self->threadId()." could not find a non-system metadata dump");
  }

  unless ($system || $non_system) {
    sayDebug("Executor#".$self->threadId()." has not loaded either system- or non-system data, nothing to merge");
    return;
  }

  # If at least one of system- and non-system data was loaded, we need
  # to merge system- and non-system
  
  my $all_meta= { %{$self->[EXECUTOR_META_SYSTEM_CACHE]} };

  foreach my $s (keys %{$self->[EXECUTOR_META_NONSYSTEM_CACHE]}) {
    $all_meta->{$s}= { %{$self->[EXECUTOR_META_NONSYSTEM_CACHE]->{$s}} };
  }
  unless (defined $self->defaultSchema() and $self->defaultSchema() != '') {
    $self->defaultSchema((sort keys %{$self->[EXECUTOR_META_NONSYSTEM_CACHE]})[0]) ;
  }

  if ($all_meta) {
    $self->[EXECUTOR_SCHEMA_METADATA]= $all_meta;
    $self->[EXECUTOR_META_CACHE] = {};
    sayDebug("Executor#".$self->threadId()." has updated metadata");
  }

#  $Data::Dumper::Maxdepth= 0;
#  print Dumper $self->[EXECUTOR_SCHEMA_METADATA];
}

sub systemSchemaPattern {
  my $list= '^(?:'.(join '|', $_[0]->server->systemSchemas()).')$';
  return qr/$list/;
}

sub schemaHasTables {
  my ($self, $schema) = @_;
  return scalar(@{$self->_collectShemaObjects($schema,'BASETAB')});
}

sub _collectSchemas {
    # user_or_system should be a constant 'USER_SCHEMAS' or 'SYSTEM_SCHEMAS'
    my ($self, $user_or_system, $non_empty)= @_;
#    $self->cacheMetaData();
    if (not defined $self->[EXECUTOR_META_CACHE]->{$user_or_system}) {
        my $schemas = [sort keys %{$self->[EXECUTOR_SCHEMA_METADATA]}];
        if (not defined $schemas or $#$schemas < 0) {
            croak "No schemas found\n";
        };
        my @schemas;
        foreach my $s (@$schemas) {
          $s= 'information_schema' if lc($s) eq 'information_schema';
          if ($user_or_system eq 'USER_SCHEMAS' and $s !~ $self->systemSchemaPattern()) {
            push @schemas, $s if (not $non_empty or $self->schemaHasTables($s));
          } elsif ($user_or_system eq 'SYSTEM_SCHEMAS' and $s =~ $self->systemSchemaPattern()) {
            push @schemas, $s;
          }
        }
        $self->[EXECUTOR_META_CACHE]->{$user_or_system} = [ @schemas ];
    }
    return $self->[EXECUTOR_META_CACHE]->{$user_or_system};
}

sub metaAllSchemas {
    my $self= shift;
    return [ @{$self->metaUserSchemas()}, @{$self->metaSystemSchemas()} ];
}

sub metaAllNonEmptySchemas {
    my $self= shift;
    return [ @{$self->metaNonEmptyUserSchemas()}, @{$self->metaSystemSchemas()} ];
}

sub metaNonEmptyUserSchemas {
    return $_[0]->metaUserSchemas(my $non_emtpty=1);
}

sub metaUserSchemas {
    my ($self, $non_empty)= @_;
    return $self->_collectSchemas('USER_SCHEMAS',$non_empty);
}

sub metaSystemSchemas {
    return $_[0]->_collectSchemas('SYSTEM_SCHEMAS');
}

# Tables, views, sequences, procedures, functions ...
sub _collectShemaObjects {
    my ($self, $schema, $type) = @_;
#    $self->cacheMetaData();
    my $meta = $self->[EXECUTOR_SCHEMA_METADATA];

    $schema = $self->defaultSchema if (not defined $schema) || ($schema eq '');
    $schema='information_schema' if lc($schema) eq 'information_schema';
    
    my @keys= ();
    if ($type eq 'TAB') {
      @keys= qw(table view versioned sequence);
    } elsif ($type eq 'BASETAB') {
      @keys= qw(table versioned);
    } elsif ($type eq 'SEQ') {
      @keys= qw(sequence);
    } elsif ($type eq 'VERSTAB') {
      @keys= qw(versioned);
    } elsif ($type eq 'VIEW') {
      @keys= qw(view);
    } elsif ($type eq 'PROC') {
      @keys= qw(procedure)
    } elsif ($type eq 'FUNC') {
      @keys= qw(function);
    } else {
      croak "Unknown object type $type"
    }
    my $cachekey = "$type-$schema";

    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey})
    {
      my @objects= ();
      my @schemas= ();
      if ($schema eq 'ANY') {
        @schemas= @{$self->metaAllSchemas()};
      } elsif ($schema eq 'NON-SYSTEM') {
        @schemas= @{$self->metaUserSchemas()};
      } else {
        @schemas= ($schema);
      }
      foreach my $s (sort @schemas) {
        foreach my $k (@keys) {
          next unless $meta->{$s}->{$k} && scalar(keys %{$meta->{$s}->{$k}});
          push @objects, map { [ $s, $_ ] } (sort keys %{$meta->{$s}->{$k}});
        }
      }
      if ($#objects < 0) {
        sayDebug("Haven't found any [ @keys ] objects for $schema schema(s)");
      }
      $self->[EXECUTOR_META_CACHE]->{$cachekey} = [ @objects ];
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};
}


sub metaTables {
    my ($self, $schema) = @_;
    return $self->_collectShemaObjects($schema,'TAB');
}

sub metaBaseTables {
    my ($self, $schema) = @_;
    return $self->_collectShemaObjects($schema,'BASETAB');
}

sub metaSequences {
    my ($self, $schema) = @_;
    return $self->_collectShemaObjects($schema,'SEQ');
}

sub metaVersionedTables {
    my ($self, $schema) = @_;
    return $self->_collectShemaObjects($schema,'VERSTAB');
}

sub metaViews {
    my ($self, $schema) = @_;
    return $self->_collectShemaObjects($schema,'VIEW');
}

sub metaProcedures {
    my ($self, $schema, $forced) = @_;
    return $self->_collectShemaObjects($schema,'PROC');
}

sub metaFunctions {
    my ($self, $schema, $forced) = @_;
    return $self->_collectShemaObjects($schema,'FUNC');
}

# Internal (for now) function. It takes a table name and tries to return
# an existing tables for it when there is any leeway.
# - if the name is fully-qualified, it returns it as a pair ($table, $schema)
# - if the schema name is provided in the separate parameter, it tries
#   to find the table there first, but if there is none, it returns any
#   table with the requested name as a pair ($table, $schema)
# - if the schema name is not provided, it returns any table with the
#   requested name ($table, $schema)
# - if nothing is found, it returns undef and lets the caller decide what to do
sub _metaFindTable {
    my ($self, $table, $schema) = @_;
    my $meta = $self->[EXECUTOR_SCHEMA_METADATA];
    if (index($table,'.') > -1) {
      # If table is a fully-qualified name, split it into table and schema
      # and ignore the provided schema name
      if ($table=~ /`?([^`]*)`?\s*\.\s*`?([^`]*)`?/) {
        return ($1, $2);
      }
    }
    $table=~ s/^`(.*)`$/$1/;
    if (defined $schema) {
      $schema='information_schema' if lc($schema) eq 'information_schema';
      $schema=~ s/^`(.*)`$/$1/;
      if (
        (exists $meta->{$schema} and exists $meta->{$schema}->{table} and exists $meta->{$schema}->{table}->{$table})
        or
        (exists $meta->{$schema} and exists $meta->{$schema}->{view} and exists $meta->{$schema}->{view}->{$table})
        or
        (exists $meta->{$schema} and exists $meta->{$schema}->{versioned} and exists $meta->{$schema}->{versioned}->{$table})
        or
        (exists $meta->{$schema} and exists $meta->{$schema}->{sequence} and exists $meta->{$schema}->{sequence}->{$table})
      ) {
        return ($schema, $table);
      }
    }
    # If we are here, either schema was not defined, or we didn't find
    # the table in it
    foreach my $s (sort keys %$meta) {
      foreach my $t (sort keys %{$meta->{$s}->{table}}, keys %{$meta->{$s}->{view}}, keys %{$meta->{$s}->{versioned}}, keys %{$meta->{$s}->{sequence}}) {
        if ($t eq $table) {
          return ($s, $t);
        }
      }
    }
    sayWarning("metaFindTable: Could not find table $table in any schema");
    return ('!non_existing_database','!non_existing_object');
}


# Columns, indexes, ...
#
# tableref in column- and index-related methods is an arrayref [schema_name,table_name]
# objtype is COL or IND (for now)
# datatype is data type
# indextype is index-related type (primary, indexed, ordinary)
# not is negation (e.g. not indexed)
#
sub _collectTableObjects {
    my ($self, $tableref, $objtype, $datatype, $indextype, $not) = @_;
#    $self->cacheMetaData();
    my $meta = $self->[EXECUTOR_SCHEMA_METADATA];
    if (ref $tableref ne 'ARRAY') { confess() };
    my ($schema,$table)= @$tableref;
    $schema= 'information_schema' if lc($schema) eq 'information_schema';

    my $cachekey= ( $not ? $objtype.'NOT' : $objtype ). "-$schema-$table";
    if ($datatype) {
      $cachekey.= "-$datatype";
    }
    if ($indextype) {
      $cachekey.= "-$indextype";
    }
    my $objects= [];
    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
      my $objref;
      unless (defined $meta->{$schema}->{tables}->{$table}) {
        sayWarning("Table/view `$schema`.`$table` does not exist in the cache");
        return ['!non_existing_object'];
      }
      if ($meta->{$schema}->{tables}->{$table}->{$objtype}) {
        $objref = $meta->{$schema}->{tables}->{$table}->{$objtype};
      }
      unless (defined $objref && scalar(keys %$objref)) {
        sayDebug("Table/view `$schema`.`$table` has no ".($objtype eq 'COL' ? 'columns' : 'indexes'));
        return ['!non_existing_object'];
      }
      $objects= [ sort keys %$objref ];

      if ($objtype eq 'COL') {
        my ($cols_by_datatype, $cols_by_indextype);
        if (defined $datatype) {
          $cols_by_datatype = [sort grep {$objref->{$_}->[1] eq $datatype} keys %$objref];
          if (not defined $cols_by_datatype or $#$cols_by_datatype < 0) {
              sayDebug("Table/view '$table' in schema '$schema' has no '$datatype' columns. Using any column");
              $cols_by_datatype= [sort keys %$objref];
          }
        }
        if (defined $indextype) {
          if ($indextype eq 'indexed') {
            $cols_by_indextype = [sort grep { ($not ? ($objref->{$_}->[0] ne $indextype and $objref->{$_}->[0] ne 'primary') : ($objref->{$_}->[0] eq $indextype or $objref->{$_}->[0] eq 'primary')) } keys %$objref];
          } else {
            $cols_by_indextype = [sort grep { ($not ? $objref->{$_}->[0] ne $indextype : $objref->{$_}->[0] eq $indextype) } keys %$objref];
          }
          if (not defined $cols_by_indextype or $#$cols_by_indextype < 0) {
              sayDebug "Table/view '$table' in schema '$schema' has no ".($datatype ? "'$datatype' " : ' ')."columns which are ".($not? 'not ' : ' ')."'$indextype'. Using any column";
              $cols_by_indextype = [sort keys %$objref];
          }
        }

        if ($cols_by_datatype && $cols_by_indextype) {
          $objects= intersect_arrays($cols_by_datatype,$cols_by_indextype);
          unless (scalar(@$objects)) {
            # No intersection between index type and data type, fall back to one of those
            sayDebug("Table/view `$schema`.`$table` does not have $datatype $indextype columns, falling back to datatype only");
            $objects= $cols_by_datatype;
          }
        } elsif ($cols_by_datatype) {
          $objects= $cols_by_datatype;
        } elsif ($cols_by_indextype) {
          $objects= $cols_by_indextype;
        }
      }
      $self->[EXECUTOR_META_CACHE]->{$cachekey} = $objects;
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};
}

sub metaIndexes {
    my ($self, $tableref) = @_;
    return $self->_collectTableObjects($tableref,'IND');
}

sub metaColumns {
    my ($self, $tableref) = @_;
    return $self->_collectTableObjects($tableref,'COL');
}

sub metaColumnsIndexType {
    my ($self, $indextype, $tableref) = @_;
    return $self->_collectTableObjects($tableref,'COL',undef,$indextype);
}

sub metaColumnsDataType {
    my ($self, $datatype, $tableref) = @_;
    return $self->_collectTableObjects($tableref,'COL',$datatype);
}

sub metaColumnsDataIndexType {
    my ($self, $datatype, $indextype, $tableref) = @_;
    return $self->_collectTableObjects($tableref,'COL',$datatype,$indextype);
}

sub metaColumnsDataTypeIndexTypeNot {
    my ($self, $datatype, $indextype, $tableref) = @_;
    return $self->_collectTableObjects($tableref,'COL',$datatype,$indextype,my $not=1);
}

sub metaColumnsIndexTypeNot {
    my ($self, $indextype, $tableref) = @_;
    return $self->_collectTableObjects($tableref,'COL',undef,$indextype,my $not=1);
}

sub metaCollations {
    my ($self, $charset) = @_;
    return $self->metaCharsetCollations($charset) if (defined $charset);

    my $cachekey= "COLLATIONS";

    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
        my $coll = [sort keys %{$self->[EXECUTOR_COLLATION_METADATA]}];
        croak "FATAL ERROR: No Collations defined" if not defined $coll or $#$coll < 0;
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = $coll;
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};
}

sub metaCharsetCollations {
    my ($self, $charset) = @_;

    my $cachekey= "COLLATIONS-$charset";

    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
        croak "FATAL ERROR: No Collations defined" if not defined $self->[EXECUTOR_COLLATION_METADATA] or scalar(keys %{$self->[EXECUTOR_COLLATION_METADATA]}) == 0;
        my @colls= ();
        foreach my $c (keys %{$self->[EXECUTOR_COLLATION_METADATA]}) {
          next if $self->[EXECUTOR_COLLATION_METADATA]->{$c} ne "$charset";
          push @colls, $c;
        }
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = [ @colls ];
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};
}

sub metaCharactersets {
    my ($self) = @_;

    my $cachekey="CHARSETS";

    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
        my %charsets= reverse %{$self->[EXECUTOR_COLLATION_METADATA]};
        # Some collations come with a NULL charset these days
        delete $charsets{''};
        croak "FATAL ERROR: No character sets defined" if (scalar(keys %charsets) == 0);
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = [sort keys %charsets];
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};
}

sub metaColumnInfo {
    my ($self, $tableref) = @_;
#    $self->cacheMetaData();
    my $meta = $self->[EXECUTOR_SCHEMA_METADATA];
    my ($schema, $table)= @$tableref;

    my $cachekey="COLINFO-$schema-$table";

    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
      unless (defined $meta->{$schema}->{tables}->{$table}) {
        sayWarning("Table/view $schema.$table does not exist in the cache");
        return {}
      }
      unless (defined $meta->{$schema}->{tables}->{$table}->{COL} && scalar(keys %{$meta->{$schema}->{tables}->{$table}->{COL}})) {
          sayWarning "In metaColumnInfo: Table '$table' in schema '$schema' has no column info";
          return {}
      }
      $self->[EXECUTOR_META_CACHE]->{$cachekey} = $meta->{$schema}->{table}->{$table}->{COL};
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};
}


################### Public interface to be used from grammars
##

sub databases {
    my ($self, @args) = @_;
    return $self->metaAllSchemas(@args);
}

sub tables {
    my ($self, @args) = @_;
    return [ map { $_->[1] } (@{$self->metaTables(@args)}) ];
}

sub baseTables {
    my ($self, @args) = @_;
    return [ map { $_->[1] } (@{$self->metaBaseTables(@args)}) ];
}

sub columnMetaType {
    my ($self, $column, @args) = @_;
    my $col_info = $self->metaColumnInfo(@args);
    return ${$col_info->{$column}}[1];
}

sub columnMaxLength {
    my ($self, $column, @args) = @_;
    my $col_info = $self->metaColumnInfo(@args);
    return ${$col_info->{$column}}[3];
}

sub databaseExists {
  my ($self, $db, @args) = @_;
  my @dbs= @{$self->metaAllSchemas(@args)};
  foreach (@dbs) {
    return 1 if $_ eq $db;
  }
  return 0;
}

sub DESTROY {
    my $executor = shift;
    $executor->disconnect();
    if (scalar(keys %{$executor->[EXECUTOR_STATUS_COUNTS]})) {
      say("-----------------------");
      say("Statuses: for Executor#".$executor->threadId().": ".join(', ', map { status2text($_).": ".$executor->[EXECUTOR_STATUS_COUNTS]->{$_}." queries" } sort keys %{$executor->[EXECUTOR_STATUS_COUNTS]}));
      say("-----------------------");
    }
}

1;
