# Copyright (c) 2008,2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2020, 2022, MariaDB Corporation Ab.
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
  EXECUTOR_RETURNED_ROW_COUNTS
  EXECUTOR_AFFECTED_ROW_COUNTS
  EXECUTOR_EXPLAIN_COUNTS
  EXECUTOR_EXPLAIN_QUERIES
  EXECUTOR_ERROR_COUNTS
  EXECUTOR_STATUS_COUNTS
  EXECUTOR_SILENT_ERRORS_COUNT
  FETCH_METHOD_AUTO
  FETCH_METHOD_STORE_RESULT
  FETCH_METHOD_USE_RESULT
  EXECUTOR_FLAG_SILENT
  EXECUTOR_FLAG_SKIP_STATS
);

use strict;
use Carp;
use Data::Dumper;
use GenUtil;
use GenTest;
use GenTest::Constants;

use constant EXECUTOR_DSN      => 0;
use constant EXECUTOR_DBH      => 1;
use constant EXECUTOR_ID      => 2;
use constant EXECUTOR_RETURNED_ROW_COUNTS  => 3;
use constant EXECUTOR_AFFECTED_ROW_COUNTS  => 4;
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
use constant EXECUTOR_FETCH_METHOD    => 16;
use constant EXECUTOR_CONNECTION_ID    => 17;
use constant EXECUTOR_FLAGS      => 18;
use constant EXECUTOR_END_TIME      => 21;
use constant EXECUTOR_CURRENT_USER      => 22;
use constant EXECUTOR_VARDIR => 27;
use constant EXECUTOR_META_FILE_SIZE => 28;
use constant EXECUTOR_META_LOCATION => 29;
use constant EXECUTOR_META_LAST_CHECK => 30;
use constant EXECUTOR_META_LAST_LOAD_OK => 31;
use constant EXECUTOR_META_RELOAD_INTERVAL => 32;
use constant EXECUTOR_META_RELOAD_NOW => 33;
use constant EXECUTOR_SERVICE_DBH => 34;
use constant EXECUTOR_SILENT_ERRORS_COUNT => 35;
use constant EXECUTOR_VARIATORS => 36;
use constant EXECUTOR_VARIATOR_MANAGER => 37;
use constant EXECUTOR_SEED => 38;
use constant EXECUTOR_METADATA_RELOAD => 39;
use constant EXECUTOR_SERVER => 40;

use constant FETCH_METHOD_AUTO    => 0;
use constant FETCH_METHOD_STORE_RESULT  => 1;
use constant FETCH_METHOD_USE_RESULT  => 2;

use constant EXECUTOR_FLAG_SILENT  => 1;
use constant EXECUTOR_FLAG_SKIP_STATS => 2;

use constant EXECUTOR_DEFAULT_METADATA_RELOAD_INTERVAL => 60;

# Values

my %system_schema_cache;

1;

sub new {
    my $class = shift;
    my $executor = $class->SUPER::new({
        'channel' => EXECUTOR_CHANNEL,
        'dsn' => EXECUTOR_DSN,
        'server'  => EXECUTOR_SERVER,
        'end_time' => EXECUTOR_END_TIME,
        'fetch_method' => EXECUTOR_FETCH_METHOD,
        'id' => EXECUTOR_ID,
        'no-err-filter' => EXECUTOR_NO_ERR_FILTER,
        'seed' => EXECUTOR_SEED,
        'sqltrace' => EXECUTOR_SQLTRACE,
        'vardir' => EXECUTOR_VARDIR,
        'variators' => EXECUTOR_VARIATORS,
        'metadata_reload' => EXECUTOR_METADATA_RELOAD,
    }, @_);

    $executor->[EXECUTOR_FETCH_METHOD] = FETCH_METHOD_AUTO if not defined $executor->[EXECUTOR_FETCH_METHOD];
    $executor->[EXECUTOR_META_RELOAD_NOW] = 0;
    $executor->[EXECUTOR_DSN] = $executor->server->dsn() if not defined $executor->[EXECUTOR_DSN] and defined $executor->server;

    if ($executor->[EXECUTOR_VARIATORS] && scalar(@{$executor->[EXECUTOR_VARIATORS]})) {
      $executor->[EXECUTOR_VARIATOR_MANAGER] = GenTest::Transform->new();
      $executor->[EXECUTOR_VARIATOR_MANAGER]->setSeed($executor->[EXECUTOR_SEED] || 1);
      $executor->[EXECUTOR_VARIATOR_MANAGER]->initVariators($executor->[EXECUTOR_VARIATORS]);
    }

    return $executor;
}

# Remains here for PopulateSchema and External scenario,
# when we don't have a server
sub newFromDSN {
  my $self= shift;
  my $dsn= shift;
  if ($dsn =~ m/^dbi:(?:mysql|mariadb):/i) {
    require GenTest::Executor::MariaDB;
    return GenTest::Executor::MariaDB->new(dsn => $dsn, @_);
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
    require GenTest::Executor::MariaDB;
    return GenTest::Executor::MariaDB->new(server => $server, @_);
  } else {
    croak("Unsupported server type, dsn: $server->dsn");
  }
}

sub server {
  return $_[0]->[EXECUTOR_SERVER];
}

sub setMetadataReloadInterval {
  # Variate the interval a bit to avoid reloading in all threads at once
  my $interval= $_[1] + $_[0]->connectionId() % 10;
  if (not defined $_[0]->[EXECUTOR_META_RELOAD_INTERVAL] or $_[0]->[EXECUTOR_META_RELOAD_INTERVAL] >= $interval) {
    say("Metadata interval set to $interval for executor ".$_[0]->[EXECUTOR_ID]);
    $_[0]->[EXECUTOR_META_RELOAD_INTERVAL]= $interval;
  } else {
    sayWarning("Metadata interval $interval is ignored for executor ".$_[0]->[EXECUTOR_ID].", already set to ".$_[0]->[EXECUTOR_META_RELOAD_INTERVAL]);
  }
}

sub forceMetadataReload {
  sayDebug("Forcing metadata reload");
  $_[0]->[EXECUTOR_META_RELOAD_NOW]= 1;
}

sub metadataReloadInterval {
  return (defined $_[0]->[EXECUTOR_META_RELOAD_INTERVAL] ? $_[0]->[EXECUTOR_META_RELOAD_INTERVAL] : EXECUTOR_DEFAULT_METADATA_RELOAD_INTERVAL);
}

sub variate_and_execute {
  my ($self, $query, $gendata)= @_;
  if ($self->[EXECUTOR_VARIATOR_MANAGER]) {
    my $max_result= STATUS_OK;
    my @errs= ();
    my @errstrs= ();
    my $queries= $self->[EXECUTOR_VARIATOR_MANAGER]->variate_query($query,$self,$gendata);
    if ($queries && ref $queries eq 'ARRAY') {
      foreach my $q (@$queries) {
        if ($q =~ /^\d+$/) {
          sayError("Variators returned error code ".status2text($q)." instead of a query");
          $max_result = $q if $q > $max_result;
          next;
        }
        my $res= $self->execute($q);
        $max_result= $res->status() if $res->status() > $max_result;
        push @errs, $res->err if $res->err;
        push @errstrs, $res->errstr if $res->errstr;
      }
    } else {
      $max_result= STATUS_ENVIRONMENT_FAILURE;
    }
    return GenTest::Result->new(
                  query       => join ';', @$queries,
                  status      => $max_result,
                  err         => join ';', @errs,
                  errstr      => join ';', @errstrs,
                  sqlstate    => undef,
                  start_time  => undef,
                  end_time    => undef,
           );
  } else {
    return $self->execute($query);
  }
}

sub channel {
    return $_[0]->[EXECUTOR_CHANNEL];
}

sub sendError {
    my ($self, $msg) = @_;
    $self->channel->send($msg);
}

sub dbh {
  return $_[0]->[EXECUTOR_DBH];
}

sub setDbh {
  $_[0]->[EXECUTOR_DBH] = $_[1];
}

sub serviceDbh {
  return $_[0]->[EXECUTOR_SERVICE_DBH];
}

sub setServiceDbh {
  $_[0]->[EXECUTOR_SERVICE_DBH] = $_[1];
}

sub currentUser {
  return $_[0]->[EXECUTOR_CURRENT_USER];
}

sub setCurrentUser {
  $_[0]->[EXECUTOR_CURRENT_USER] = $_[1];
}

sub sqltrace {
    my ($self, $sqltrace) = @_;
    $self->[EXECUTOR_SQLTRACE] = $sqltrace if defined $sqltrace;
    return $self->[EXECUTOR_SQLTRACE];
}

sub noErrFilter {
    my ($self, $no_err_filter) = @_;
    $self->[EXECUTOR_NO_ERR_FILTER] = $no_err_filter if defined $no_err_filter;
    return $self->[EXECUTOR_NO_ERR_FILTER];
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

sub setId {
  $_[0]->[EXECUTOR_ID] = $_[1];
}

sub vardir {
  return $_[0]->[EXECUTOR_VARDIR];
}

sub setVardir {
  $_[0]->[EXECUTOR_VARDIR]= $_[1];
}

sub fetchMethod {
  return $_[0]->[EXECUTOR_FETCH_METHOD];
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

sub findStatus {
    my ($self, $state) = @_;

    my $class = substr($state, 0, 2);
    if (defined $class2status{$class}) {
        return $class2status{$class};
    } else {
        return STATUS_UNKNOWN_ERROR;
    }
}

sub defaultSchema {
    my ($self, $schema) = @_;
    if (defined $schema and $self->[EXECUTOR_DEFAULT_SCHEMA] ne $schema) {
      $schema='information_schema' if lc($schema) eq 'information_schema';
      say("Setting default schema to $schema");
        $self->[EXECUTOR_DEFAULT_SCHEMA] = $schema;
    }
    return $self->[EXECUTOR_DEFAULT_SCHEMA];
}

sub currentSchema {
    croak "FATAL ERROR: currentSchema not defined for ". (ref $_[0]);
}

sub getCollationMetaData {
    carp "getCollationMetaData not defined for ". (ref $_[0]);
    return [[undef,undef]];
}


########### Metadata routines

sub cacheMetaData {
  my $self= shift;

  # Collation metadata is loaded only once
  if (not $self->[EXECUTOR_COLLATION_METADATA]) {
    my $meta= $self->getCollationMetaData();
    if ($meta) {
    } else {
      sayError("Executor failed to load collation metadata");
    }
    my $coll= {};
    foreach my $row (@$meta) {
        my ($collation, $charset) = @$row;
        $coll->{$collation} = $charset;
    }
    $self->[EXECUTOR_COLLATION_METADATA] = $coll;
    sayDebug("Executor has loaded collation metadata");
  }

  my ($system_meta, $non_system_meta);

  # System schema metadata is loaded only once
  if (not exists $system_schema_cache{$self->server->dsn()}) {
    $system_meta= $self->loadMetaData('system');
    if ($system_meta and scalar(keys %$system_meta)) {
      $system_schema_cache{$self->server->dsn()}= $system_meta;
      sayDebug("Executor has loaded system metadata");
    } else {
      sayError("Executor failed to load system metadata");
    }
  }

  if ($self->[EXECUTOR_META_RELOAD_NOW]
      or not defined $self->[EXECUTOR_META_LAST_CHECK] # Very first attempt
      or (not $self->[EXECUTOR_META_LAST_LOAD_OK] and time() > $self->[EXECUTOR_META_LAST_CHECK] + int($self->metadataReloadInterval()/5)) # Last load failed
      or ($self->[EXECUTOR_METADATA_RELOAD] and time() > $self->[EXECUTOR_META_LAST_CHECK] + $self->metadataReloadInterval()) # Reload interval exceeded
  )
  {
    $self->[EXECUTOR_META_LAST_LOAD_OK]= 0;
    # Non-system schema metadata is reloaded periodically
    $non_system_meta= $self->loadMetaData('non-system');

    if ($non_system_meta and scalar(%$non_system_meta)) {
      sayDebug("Executor has (re-)loaded non-system metadata");
      $self->[EXECUTOR_META_LAST_LOAD_OK]= 1;
    } elsif ($non_system_meta) {
      sayDebug("Executor has kept old non-system metadata");
      $non_system_meta= undef;
    } else {
      sayWarning("Executor has not loaded non-system metadata");
    }
    $self->[EXECUTOR_META_LAST_CHECK]= time();
    $self->[EXECUTOR_META_RELOAD_NOW] = 0;
  }

  my $all_meta;
  # Possible situations:
  # - system and non-system metadata was loaded, need to merge them and store
  # - in a previous load system metadata was loaded, now non-system metadata is reloaded, need to merge them and store
  # - in a previous load system metadata was loaded, now non-system metadata was not reloaded, need to keep things as is
  # - in a previous load system metadata failed to load, but non-system metadata was loaded; now system metadata is loaded,
  #   non-system is not, need to merge loaded system metadata with the old non-system metadata
  # - non-system metadata was loaded, but system metadata never was, need to store non-system metadata only

  if ($non_system_meta and $system_schema_cache{$self->server->dsn()}) {
    $all_meta= { %{$system_schema_cache{$self->server->dsn()}} };
    local $Data::Dumper::Maxdepth= 0;
    foreach my $s (keys %$non_system_meta) {
      $all_meta->{$s}= { %{$non_system_meta->{$s}} };
    }
    unless (defined $self->defaultSchema() and $self->defaultSchema() != '') {
      $self->defaultSchema((sort keys %$non_system_meta)[0]) ;
    }
  } elsif ($system_meta and $self->[EXECUTOR_SCHEMA_METADATA]) {
    $all_meta= { %{$self->[EXECUTOR_SCHEMA_METADATA]} };
    foreach my $s (keys %$system_meta) {
      $all_meta->{$s}= { %{$system_meta->{$s}} };
    }
    $self->[EXECUTOR_SCHEMA_METADATA]= $all_meta;
  } elsif ($non_system_meta) {
    $all_meta= { %$non_system_meta };
  }

  if ($all_meta) {
    $self->[EXECUTOR_SCHEMA_METADATA]= $all_meta;
    $self->[EXECUTOR_META_CACHE] = {};
    sayDebug("Executor has reloaded metadata");
  }
}

sub metaAllSchemas {
    my $self= shift;
    return [ @{$self->metaUserSchemas()}, @{$self->metaSystemSchemas()} ];
}

sub metaUserSchemas {
    my $self= shift;
    $self->cacheMetaData();
    if (not defined $self->[EXECUTOR_META_CACHE]->{USER_SCHEMAS}) {
        my $schemas = [sort keys %{$self->[EXECUTOR_SCHEMA_METADATA]}];
        if (not defined $schemas or $#$schemas < 0) {
            croak "No schemas found\n";
        };
        my @schemas;
        foreach my $s (@$schemas) {
          $s= 'information_schema' if lc($s) eq 'information_schema';
          if ($s !~ /^(?:mysql|performance_schema|information_schema|sys_schema|sys)$/) {
            push @schemas, $s;
          }
        }
        $self->[EXECUTOR_META_CACHE]->{USER_SCHEMAS} = [ @schemas ];
    }
    return $self->[EXECUTOR_META_CACHE]->{USER_SCHEMAS};
}

sub metaSystemSchemas {
    my $self= shift;
    $self->cacheMetaData();
    if (not defined $self->[EXECUTOR_META_CACHE]->{SYSTEM_SCHEMAS}) {
        my $schemas = [sort keys %{$self->[EXECUTOR_SCHEMA_METADATA]}];
        if (not defined $schemas or $#$schemas < 0) {
            croak "No schemas found\n";
        };
        my @schemas;
        foreach my $s (@$schemas) {
          $s= 'information_schema' if lc($s) eq 'information_schema';
          if ($s =~ /^(?:mysql|performance_schema|information_schema|sys_schema|sys)$/) {
            push @schemas, $s;
          }
        }
        $self->[EXECUTOR_META_CACHE]->{SYSTEM_SCHEMAS} = [ @schemas ];
    }
    return $self->[EXECUTOR_META_CACHE]->{SYSTEM_SCHEMAS};
}

sub metaTables {
    my ($self, $schema, $forced) = @_;
    $self->cacheMetaData();
    my $meta = $self->[EXECUTOR_SCHEMA_METADATA];

    $schema = $self->defaultSchema if (not defined $schema) || ($schema eq '');
    $schema='information_schema' if lc($schema) eq 'information_schema';
    my $cachekey = "TAB-$schema";

    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey})
    {
        my $tables = [sort ( keys %{$meta->{$schema}->{table}}, keys %{$meta->{$schema}->{view}}, keys %{$meta->{$schema}->{versioned}}, keys %{$meta->{$schema}->{sequence}} )];
        if (not defined $tables or $#$tables < 0) {
          if ($forced) {
            sayWarning "Schema '$schema' has no tables";
            $tables = [ '!non_existing_table' ];
          } else {
            $self->forceMetadataReload();
            return $self->metaTables($schema, 1);
          }
        }
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = $tables;
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};
}

sub metaBaseTables {
    my ($self, $schema) = @_;
    my $meta = $self->[EXECUTOR_SCHEMA_METADATA];

    $schema = $self->defaultSchema if (not defined $schema) || ($schema eq '');
    $schema='information_schema' if lc($schema) eq 'information_schema';

    my $cachekey = "BASETAB-$schema";

    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
        my $tables = [sort keys %{$meta->{$schema}->{table}}, keys %{$meta->{$schema}->{versioned}}];
        if (not defined $tables or $#$tables < 0) {
            sayWarning "Schema '$schema' has no base tables";
            $tables = [ '!non_existing_base_table' ];
        }
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = $tables;
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};
}

sub metaVersionedTables {
    my ($self, $schema) = @_;
    my $meta = $self->[EXECUTOR_SCHEMA_METADATA];

    $schema = $self->defaultSchema if (not defined $schema) || ($schema eq '');
    $schema='information_schema' if lc($schema) eq 'information_schema';

    my $cachekey = "VERSTAB-$schema";

    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
        my $tables = [sort keys %{$meta->{$schema}->{versioned}}];
        if (not defined $tables or $#$tables < 0) {
            sayWarning "Schema '$schema' has no versioned tables";
            $tables = [ '!non_existing_versioned_table' ];
        }
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = $tables;
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};
}

sub metaViews {
    my ($self, $schema) = @_;
    my $meta = $self->[EXECUTOR_SCHEMA_METADATA];

    $schema = $self->defaultSchema if (not defined $schema) || ($schema eq '');
    $schema='information_schema' if lc($schema) eq 'information_schema';

    my $cachekey = "VIEW-$schema";

    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
        my $tables = [sort keys %{$meta->{$schema}->{view}}];
        if (not defined $tables or $#$tables < 0) {
            sayWarning "Schema '$schema' has no views";
            $tables = [ '!non_existing_view' ];
        }
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = $tables;
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};

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
        return ($2, $1);
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
        return ($table, $schema);
      }
    }
    # If we are here, either schema was not defined, or we didn't find
    # the table in it
    foreach my $s (sort keys %$meta) {
      foreach my $t (sort keys %{$meta->{$s}->{table}}, keys %{$meta->{$s}->{view}}, keys %{$meta->{$s}->{versioned}}, keys %{$meta->{$s}->{sequence}}) {
        if ($t eq $table) {
          return ($t, $s);
        }
      }
    }
    sayWarning("metaFindTable: Could not find table $table in any schema");
    return undef;
}

sub metaIndexes {
    my ($self, $requested_table, $requested_schema, $forced) = @_;
    $self->cacheMetaData();
    my $meta = $self->[EXECUTOR_SCHEMA_METADATA];

    my ($table, $schema)= $self->_metaFindTable($requested_table,$requested_schema);
    $schema = $self->defaultSchema if (not defined $schema) || ($schema eq '');
    $schema='information_schema' if lc($schema) eq 'information_schema';
    $table = $self->metaBaseTables($schema)->[0] if not defined $table;

    my $cachekey="IND-$schema-$table";

    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
        my $inds;
        if ($meta->{$schema}->{table}->{$table}) {
            $inds = [sort keys %{$meta->{$schema}->{table}->{$table}->{key}}]
        } elsif ($meta->{$schema}->{versioned}->{$table}) {
            $inds = [sort keys %{$meta->{$schema}->{versioned}->{$table}->{key}}]
        } elsif ($meta->{$schema}->{sequence}->{$table}) {
            $inds = [sort keys %{$meta->{$schema}->{sequence}->{$table}->{key}}]
        } elsif ($forced) {
            sayWarning "In metaIndexes: Table/view '$table' in schema '$schema' has no indexes";
            return ['!non_existing_index'];
        } else {
            $self->forceMetadataReload();
            return $self->metaIndexes($requested_table, $requested_schema, 1);
        }
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = $inds;
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};
}

sub metaColumns {
    my ($self, $requested_table, $requested_schema, $forced) = @_;
    $self->cacheMetaData();
    my $meta = $self->[EXECUTOR_SCHEMA_METADATA];

    my ($table, $schema)= $self->_metaFindTable($requested_table,$requested_schema);
    $schema = $self->defaultSchema if (not defined $schema) || ($schema eq '');
    $schema='information_schema' if lc($schema) eq 'information_schema';
    $table = $self->metaTables($schema)->[0] if not defined $table;

    my $cachekey="COL-$schema-$table";

    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
        my $cols;
        if ($meta->{$schema}->{table}->{$table}->{col}) {
            $cols = [sort keys %{$meta->{$schema}->{table}->{$table}->{col}}]
        } elsif ($meta->{$schema}->{view}->{$table}->{col}) {
            $cols = [sort keys %{$meta->{$schema}->{view}->{$table}->{col}}]
        } elsif ($meta->{$schema}->{versioned}->{$table}->{col}) {
            $cols = [sort keys %{$meta->{$schema}->{versioned}->{$table}->{col}}]
        } elsif ($meta->{$schema}->{sequence}->{$table}->{col}) {
            $cols = [sort keys %{$meta->{$schema}->{sequence}->{$table}->{col}}]
        } elsif ($forced) {
            sayWarning "In metaColumns: Table/view '$table' in schema '$schema' has no columns";
            return ['!non_existing_column'];
        } else {
            $self->forceMetadataReload();
            return $self->metaColumns($requested_table, $requested_schema, 1);
        }
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = $cols;
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};
}

sub metaColumnsIndexType {
    my ($self, $indextype, $table, $schema, $forced) = @_;
    $self->cacheMetaData();
    my $meta = $self->[EXECUTOR_SCHEMA_METADATA];

    $schema = $self->defaultSchema if (not defined $schema) || ($schema eq '');
    $schema='information_schema' if lc($schema) eq 'information_schema';
    $table = $self->metaTables($schema)->[0] if not defined $table;

    my $cachekey="COL-$indextype-$schema-$table";

    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
        my $colref;
        if ($meta->{$schema}->{table}->{$table}->{col}) {
            $colref = $meta->{$schema}->{table}->{$table}->{col}
        } elsif ($meta->{$schema}->{view}->{$table}->{col}) {
            $colref = $meta->{$schema}->{view}->{$table}->{col};
        } elsif ($meta->{$schema}->{versioned}->{$table}->{col}) {
            $colref = $meta->{$schema}->{versioned}->{$table}->{col};
        } elsif ($meta->{$schema}->{sequence}->{$table}->{col}) {
            $colref = $meta->{$schema}->{sequence}->{$table}->{col};
        } elsif ($forced) {
            sayWarning "In metaColumnsIndexType: Table/view '$table' in schema '$schema' has no columns";
            return ['!non_existing_column'];
        } else {
            $self->forceMetadataReload();
            return $self->metaColumnsIndexType($indextype, $table, $schema, 1);
        }

        # If the table is a view, don't bother looking for indexed columns, fall back to ordinary
        if ($meta->{$schema}->{view}->{$table} and ($indextype eq 'indexed' or $indextype eq 'primary')) {
            $indextype = 'ordinary'
        }
        my $cols;
        if ($indextype eq 'indexed') {
            $cols = [sort grep {$colref->{$_}->[0] eq $indextype or $colref->{$_}->[0] eq 'primary'} keys %$colref];
        } else {
            $cols = [sort grep {$colref->{$_}->[0] eq $indextype} keys %$colref];
        };
        if (not defined $cols or $#$cols < 0) {
            sayDebug "Table/view '$table' in schema '$schema' has no '$indextype' columns (Might be caused by use of --views option in combination with grammars containing _field_indexed). Using any column";
            return $self->metaColumns($table,$schema);
        }
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = $cols;
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};

}

sub metaColumnsDataType {
    my ($self, $datatype, $table, $schema) = @_;
    $self->cacheMetaData();
    my $meta = $self->[EXECUTOR_SCHEMA_METADATA];

    $schema = $self->defaultSchema if (not defined $schema) || ($schema eq '');
    $schema='information_schema' if lc($schema) eq 'information_schema';
    $table = $self->metaTables($schema)->[0] if not defined $table;

    my $cachekey="COL-$datatype-$schema-$table";

    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
        my $colref;
        if ($meta->{$schema}->{table}->{$table}->{col}) {
            $colref = $meta->{$schema}->{table}->{$table}->{col};
        } elsif ($meta->{$schema}->{view}->{$table}->{col}) {
            $colref = $meta->{$schema}->{view}->{$table}->{col};
        } elsif ($meta->{$schema}->{versioned}->{$table}->{col}) {
            $colref = $meta->{$schema}->{versioned}->{$table}->{col};
        } elsif ($meta->{$schema}->{sequence}->{$table}->{col}) {
            $colref = $meta->{$schema}->{sequence}->{$table}->{col};
        } else {
            sayWarning "In metaColumnsDataType: Table/view '$table' in schema '$schema' has no columns";
            return ['!non_existing_column'];
        }

        my $cols = [sort grep {$colref->{$_}->[1] eq $datatype} keys %$colref];
        if (not defined $cols or $#$cols < 0) {
            sayDebug "Table/view '$table' in schema '$schema' has no '$datatype' columns. Using any column";
            return $self->metaColumns($table,$schema);
        }
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = $cols;
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};

}

sub metaColumnsDataIndexType {
    my ($self, $datatype, $indextype, $table, $schema) = @_;
    $self->cacheMetaData();
    my $meta = $self->[EXECUTOR_SCHEMA_METADATA];

    $schema = $self->defaultSchema if (not defined $schema) || ($schema eq '');
    $schema='information_schema' if lc($schema) eq 'information_schema';
    $table = $self->metaTables($schema)->[0] if not defined $table;

    my $cachekey="COL-$datatype-$indextype-$schema-$table";

    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
        my $colref;
        if ($meta->{$schema}->{table}->{$table}->{col}) {
            $colref = $meta->{$schema}->{table}->{$table}->{col};
        } elsif ($meta->{$schema}->{view}->{$table}->{col}) {
            $colref = $meta->{$schema}->{view}->{$table}->{col};
        } elsif ($meta->{$schema}->{versioned}->{$table}->{col}) {
            $colref = $meta->{$schema}->{versioned}->{$table}->{col};
        } elsif ($meta->{$schema}->{sequence}->{$table}->{col}) {
            $colref = $meta->{$schema}->{sequence}->{$table}->{col};
        } else {
            sayWarning "In metaColumnsDataIndexType: Table/view '$table' in schema '$schema' has no columns";
            return ['!non_existing_column'];
        }

        # If the table is a view, don't bother looking for indexed columns, fall back to ordinary
        if ($meta->{$schema}->{view}->{$table} and ($indextype eq 'indexed' or $indextype eq 'primary')) {
            $indextype = 'ordinary'
        }
        my $cols_by_datatype = [sort grep {$colref->{$_}->[1] eq $datatype} keys %$colref];
        if (not defined $cols_by_datatype or $#$cols_by_datatype < 0) {
            sayDebug "Table/view '$table' in schema '$schema' has no '$datatype' columns. Using any column";
            return $self->metaColumns($table,$schema);
        }
        my $cols_by_indextype;
        if ($indextype eq 'indexed') {
            $cols_by_indextype = [sort grep {$colref->{$_}->[0] eq $indextype or $colref->{$_}->[0] eq 'primary'} keys %$colref];
        } else {
            $cols_by_indextype = [sort grep {$colref->{$_}->[0] eq $indextype} keys %$colref];
        }
        if (not defined $cols_by_indextype or $#$cols_by_indextype < 0) {
            sayDebug "Table/view '$table' in schema '$schema' has no '$indextype' columns (Might be caused by use of --views option in combination with grammars containing _field_indexed). Using any column";
            return $self->metaColumns($table,$schema);
        }

        my $cols = GenTest::intersect_arrays($cols_by_datatype,$cols_by_indextype);
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = $cols;
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};

}

sub metaColumnsDataTypeIndexTypeNot {
    my ($self, $datatype, $indextype, $table, $schema) = @_;
    $self->cacheMetaData();
    my $meta = $self->[EXECUTOR_SCHEMA_METADATA];

    $schema = $self->defaultSchema if (not defined $schema) || ($schema eq '');
    $schema='information_schema' if lc($schema) eq 'information_schema';
    $table = $self->metaTables($schema)->[0] if not defined $table;

    my $cachekey="COL-$datatype-$indextype-$schema-$table";

    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
        my $colref;
        if ($meta->{$schema}->{table}->{$table}->{col}) {
            $colref = $meta->{$schema}->{table}->{$table}->{col};
        } elsif ($meta->{$schema}->{view}->{$table}->{col}) {
            $colref = $meta->{$schema}->{view}->{$table}->{col};
        } elsif ($meta->{$schema}->{versioned}->{$table}->{col}) {
            $colref = $meta->{$schema}->{versioned}->{$table}->{col};
        } elsif ($meta->{$schema}->{sequence}->{$table}->{col}) {
            $colref = $meta->{$schema}->{sequence}->{$table}->{col};
        } else {
            sayWarning "In metaColumnsDataTypeIndexTypeNot: Table/view '$table' in schema '$schema' has no columns";
            return ['!non_existing_column'];
        }

        # If the table is a view, don't bother looking for indexed columns, fall back to ordinary
        $indextype = 'unknown'
            if ($meta->{$schema}->{view}->{$table} and $indextype eq 'ordinary');
        my $cols_by_datatype = [sort grep {$colref->{$_}->[1] eq $datatype} keys %$colref];
        if (not defined $cols_by_datatype or $#$cols_by_datatype < 0) {
            sayDebug "Table/view '$table' in schema '$schema' has no '$datatype' columns. Using any column";
            return $self->metaColumns($table,$schema);
        }
        my $cols_by_indextype = [sort grep {$colref->{$_}->[0] ne $indextype} keys %$colref];
        if (not defined $cols_by_indextype or $#$cols_by_indextype < 0) {
            sayDebug "In metaColumnsDataTypeIndexTypeNot: Table '$table' in schema '$schema' has no columns which are not '$indextype'. Using any column";
            return $self->metaColumns($table,$schema);
        }
        my $cols = intersect_arrays($cols_by_datatype,$cols_by_indextype);
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = $cols;
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};

}

sub metaColumnsIndexTypeNot {
    my ($self, $indextype, $table, $schema) = @_;
    $self->cacheMetaData();
    my $meta = $self->[EXECUTOR_SCHEMA_METADATA];

    $schema = $self->defaultSchema if (not defined $schema) || ($schema eq '');
    $schema='information_schema' if lc($schema) eq 'information_schema';
    $table = $self->metaTables($schema)->[0] if not defined $table;

    my $cachekey="COLNOT-$indextype-$schema-$table";

    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
        my $colref;
        if ($meta->{$schema}->{table}->{$table}->{col}) {
            $colref = $meta->{$schema}->{table}->{$table}->{col};
        } elsif ($meta->{$schema}->{view}->{$table}->{col}) {
            $colref = $meta->{$schema}->{view}->{$table}->{col};
        } elsif ($meta->{$schema}->{versioned}->{$table}->{col}) {
            $colref = $meta->{$schema}->{versioned}->{$table}->{col};
        } elsif ($meta->{$schema}->{sequence}->{$table}->{col}) {
            $colref = $meta->{$schema}->{sequence}->{$table}->{col};
        } else {
            sayWarning "In metaColumnsIndexTypeNot: Table/view '$table' in schema '$schema' has no columns";
            return ['!non_existing_column'];
        }

        # If the table is a view, don't bother looking for indexed columns, fall back to ordinary
        $indextype = 'unknown'
            if ($meta->{$schema}->{view}->{$table} and $indextype eq 'ordinary');
        my $cols = [sort grep {$colref->{$_}->[0] ne $indextype} keys %$colref];
        if (not defined $cols or $#$cols < 0) {
            sayDebug "In metaColumnsIndexTypeNot: Table '$table' in schema '$schema' has no columns which are not '$indextype'. Using any column";
            return $self->metaColumns($table,$schema);
        }
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = $cols;
    }
    return $self->[EXECUTOR_META_CACHE]->{$cachekey};
}

sub metaCollations {
    my ($self) = @_;

    my $cachekey="COLLATIONS";

    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
        my $coll = [sort keys %{$self->[EXECUTOR_COLLATION_METADATA]}];
        croak "FATAL ERROR: No Collations defined" if not defined $coll or $#$coll < 0;
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = $coll;
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
    my ($self, $table, $schema) = @_;
    $self->cacheMetaData();
    my $meta = $self->[EXECUTOR_SCHEMA_METADATA];

    $schema = $self->defaultSchema if (not defined $schema) || ($schema eq '');
    $schema='information_schema' if lc($schema) eq 'information_schema';
    $table = $self->metaTables($schema)->[0] if not defined $table;

    my $cachekey="COLINFO-$schema-$table";

    if (not defined $self->[EXECUTOR_META_CACHE]->{$cachekey}) {
        my $cols = ();
        if ($meta->{$schema}->{table}->{$table}->{col}) {
            $cols = $meta->{$schema}->{table}->{$table}->{col}
        } elsif ($meta->{$schema}->{view}->{$table}->{col}) {
            $cols = $meta->{$schema}->{view}->{$table}->{col}
        } elsif ($meta->{$schema}->{versioned}->{$table}->{col}) {
            $cols = $meta->{$schema}->{versioned}->{$table}->{col}
        } elsif ($meta->{$schema}->{sequence}->{$table}->{col}) {
            $cols = $meta->{$schema}->{sequence}->{$table}->{col}
        } else {
            sayWarning "In metaColumnInfo: Table '$table' in schema '$schema' has no columns";
        }
        $self->[EXECUTOR_META_CACHE]->{$cachekey} = $cols;
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
    return $self->metaTables(@args);
}

sub baseTables {
    my ($self, @args) = @_;
    return $self->metaBaseTables(@args);
}

sub versionedTables {
    my ($self, @args) = @_;
    return $self->metaVersionedTables(@args);
}

sub tableColumns {
    my ($self, @args) = @_;
    return $self->metaColumns(@args);
}

sub columnRealType {
    my ($self, $column, @args) = @_;
    my $col_info = $self->metaColumnInfo(@args);
    return $col_info->{$column}->[2];
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

1;
