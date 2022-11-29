#!/usr/bin/perl

# Copyright (c) 2008,2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2016, 2022, MariaDB Corporation Ab.
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

package GenTest::TestRunner;

@ISA = qw(GenTest);

use strict;
use Carp;
use Data::Dumper;
use File::Basename;
use File::Path 'mkpath';
use File::Copy;
use File::Spec;
use POSIX;
use Time::HiRes;

use GenData::GendataFromFile;
use GenData::GendataSimple;
use GenData::GendataAdvanced;
use GenTest;
use GenTest::Comparator;
use GenTest::Constants;
use GenTest::ErrorFilter;
use GenTest::Executor;
use GenTest::Filter::Regexp;
use GenTest::Grammar;
use GenTest::IPC::Channel;
use GenTest::IPC::Process;
use GenTest::Mixer;
use GenTest::Properties;
use GenTest::Reporter;
use GenTest::ReporterManager;
use GenTest::Result;
use GenTest::Validator;
use GenUtil;

use constant PROCESS_TYPE_PARENT  => 0;
use constant PROCESS_TYPE_PERIODIC  => 1;
use constant PROCESS_TYPE_CHILD    => 2;

use constant GT_CONFIG => 0;
use constant GT_CHANNEL => 5;

use constant GT_GRAMMARS => 6;
use constant GT_GENERATOR => 7;
use constant GT_REPORTER_MANAGER => 8;
use constant GT_TEST_START => 9;
use constant GT_TEST_END => 10;
use constant GT_QUERY_FILTERS => 11;
use constant GT_EXECUTORS => 12;
use constant GT_VARIATOR_MANAGER => 13;

sub new {
    my $class = shift;

    my $self = $class->SUPER::new({
        'config' => GT_CONFIG},@_);

    croak ("Need config") if not defined $self->config;
    return $self;
}

sub config {
    return $_[0]->[GT_CONFIG];
}

sub grammars {
    return $_[0]->[GT_GRAMMARS];
}

sub generator {
    return $_[0]->[GT_GENERATOR];
}

sub channel {
    return $_[0]->[GT_CHANNEL];
}

sub reporterManager {
    return $_[0]->[GT_REPORTER_MANAGER];
}

sub queryFilters {
    return $_[0]->[GT_QUERY_FILTERS];
}

sub run {
    my $self = shift;

    $SIG{TERM} = sub { exit(0) };
    $SIG{CHLD} = "IGNORE" if osWindows();

    $ENV{RQG_DEBUG} = 1 if $self->config->debug;

    $self->initSeed();
    if ($self->config->variators && @{$self->config->variators}) {
      $self->[GT_VARIATOR_MANAGER] = GenTest::Transform->new();
      $self->[GT_VARIATOR_MANAGER]->setSeed($self->config->property('seed'));
      $self->[GT_VARIATOR_MANAGER]->initVariators($self->config->variators);
    }

    say("-------------------------------\nConfiguration");
    $self->config->printProps;

    $self->[GT_CHANNEL] = GenTest::IPC::Channel->new();

    my $init_generator_result = $self->initGenerator();
    return $init_generator_result if $init_generator_result != STATUS_OK;

    $self->[GT_TEST_START] = time();
    $self->[GT_TEST_END] = $self->[GT_TEST_START] + $self->config->duration;

    my $init_reporters_result = $self->initReporters();
    return $init_reporters_result if $init_reporters_result != STATUS_OK;

    my $init_validators_result = $self->initValidators();
    return $init_validators_result if $init_validators_result != STATUS_OK;

    if (scalar(@{$self->config->filters})) {
        my @filters= ();
        foreach my $f (@{$self->config->filters}) {
            push @filters, GenTest::Filter::Regexp->new(file => $f);
        }
        $self->[GT_QUERY_FILTERS]= \@filters;
    }

    say("Starting ".$self->config->threads." processes, ".
        $self->config->queries." queries each, duration ".
        $self->config->duration." seconds.");

    ### Start central reporting thread ####

    my $errorfilter = GenTest::ErrorFilter->new(channel => $self->channel());
    my $errorfilter_p = GenTest::IPC::Process->new(object => $errorfilter);
    if (!osWindows()) {
        $errorfilter_p->start($self->config->servers);
    }

    ### Start worker children ###

    my %worker_pids;

    if ($self->config->threads > 0) {
        foreach my $worker_id (1..$self->config->threads) {
            my $worker_pid = $self->workerProcess($worker_id);
            $worker_pids{$worker_pid} = 1;
            Time::HiRes::sleep(0.1); # fork slowly for more predictability
        }
    }

    ### Main process

    if (osWindows()) {
        ## Important that this is done here in the parent after the last
        ## fork since on windows Process.pm uses threads
        $errorfilter_p->start();
    }

    # We are the parent process, wait for for all spawned processes to terminate
    my $total_status = STATUS_OK;
    my $reporter_status = STATUS_OK;

    ## Parent thread does not use channel
    $self->channel()->close;

    OUTER: while (1) {
        # Remaining Worker & Reporter processes that were spawned and haven't ended yet.
        my @spawned_pids = (keys %worker_pids);

        # Wait for processes to complete, i.e only processes spawned by workers & reporters.
        foreach my $spawned_pid (@spawned_pids) {
            my $child_pid = waitpid($spawned_pid, WNOHANG);
            next if $child_pid == 0;
            my $child_exit_status = $? > 0 ? ($? >> 8) : 0;

            $total_status = $child_exit_status if $child_exit_status > $total_status;

            if ($child_pid == -1) {
                say("Process with pid $spawned_pid (worker) no longer exists");
                last OUTER;
            } else {
                say("Process with pid $child_pid (worker) ended with status ".status2text($child_exit_status));
                delete $worker_pids{$child_pid};
            }

            last OUTER if $child_exit_status >= STATUS_CRITICAL_FAILURE;
            last OUTER if keys %worker_pids == 0;
        }
        $reporter_status = $self->reporterManager()->monitor(REPORTER_TYPE_PERIODIC);
        $total_status= $reporter_status if $reporter_status > $total_status;
        if ($reporter_status > STATUS_CRITICAL_FAILURE) {
          sayError("Reporters returned a critical failure, aborting");
          last;
        }
        sleep 10;
    }

    foreach my $worker_pid (keys %worker_pids) {
        say("Killing remaining worker process with pid $worker_pid...");
        kill(15, $worker_pid);
        foreach (1..5) {
            last unless kill(0, $worker_pid);
            sleep 1;
        }
        if (kill(0, $worker_pid)) {
            kill(9, $worker_pid);
        }
    }

    $errorfilter_p->kill();

    my $gentest_result= $self->reportResults($total_status);
    say("GenTest will exit with exit status ".status2text($gentest_result)." ($gentest_result)");
    return $gentest_result;

}

sub reportResults {
    my ($self, $total_status) = @_;

    my $reporter_manager = $self->reporterManager();
    my @report_results;

    # New report type REPORTER_TYPE_END, used with reporter's that processes information at the end of a test.
    if ($total_status == STATUS_OK) {
        @report_results = $reporter_manager->report(REPORTER_TYPE_SUCCESS | REPORTER_TYPE_ALWAYS | REPORTER_TYPE_END);
    } elsif (
        ($total_status == STATUS_LENGTH_MISMATCH) ||
        ($total_status == STATUS_CONTENT_MISMATCH)
    ) {
        @report_results = $reporter_manager->report(REPORTER_TYPE_DATA | REPORTER_TYPE_ALWAYS | REPORTER_TYPE_END);
    } elsif ($total_status == STATUS_SERVER_CRASHED) {
        say("Server crash reported, initiating post-crash analysis...");
        @report_results = $reporter_manager->report(REPORTER_TYPE_CRASH | REPORTER_TYPE_ALWAYS);
    } elsif ($total_status == STATUS_SERVER_DEADLOCKED) {
        say("Server deadlock reported, initiating analysis...");
        @report_results = $reporter_manager->report(REPORTER_TYPE_DEADLOCK | REPORTER_TYPE_ALWAYS | REPORTER_TYPE_END);
    } elsif ($total_status == STATUS_SERVER_KILLED) {
        $total_status = STATUS_OK;
        @report_results = $reporter_manager->report(REPORTER_TYPE_SERVER_KILLED | REPORTER_TYPE_ALWAYS | REPORTER_TYPE_END);
    } else {
        @report_results = $reporter_manager->report(REPORTER_TYPE_ALWAYS | REPORTER_TYPE_END);
    }

    my $report_status = shift @report_results;
    $total_status = $report_status if $report_status > $total_status;

    if ($total_status == STATUS_OK) {
        say("Test completed successfully.");
        return STATUS_OK;
    } else {
        say("Test completed with failure status ".status2text($total_status)." ($total_status)");
        return $total_status;
    }
}

sub stopChild {
    my ($self, $status) = @_;

    say("GenTest: child $$ is being stopped with status " . status2text($status));
    # Stopping executors explicitly to hopefully trigger statistics output
    foreach my $executor (@{$self->[GT_EXECUTORS]}) {
        if ($executor) {
            $executor->disconnect;
            undef $executor;
        }
    }
    croak "calling stopChild() for $$ without a \$status" if not defined $status;
    if (osWindows()) {
        exit $status;
    } else {
        safe_exit($status);
    }
}

sub workerProcess {
    my ($self, $worker_id) = @_;

    my $worker_pid = fork();
    $self->channel()->writer;

    if ($worker_pid != 0) {
        return $worker_pid;
    }

    $| = 1;
#    my $ctrl_c = 0;
#    local $SIG{INT} = sub { $ctrl_c = 1 };

    $self->generator()->setSeed($self->config->seed() + $worker_id);
    $self->generator()->setThreadId($worker_id);

    my @executors;
    foreach my $i (@{$self->config->active_servers}) {
        next unless $self->config->server_specific->{$i}->{dsn};
        my $executor = GenTest::Executor->newFromDSN(
          $self->config->server_specific->{$i}->{dsn},
          channel => (osWindows() ? undef : $self->channel()),
          metadata_reload => $self->config->metadata_reload,
          sqltrace => $self->config->sqltrace,
          vardir => $self->config->vardir,
          variators => $self->config->variators,
        );
        $executor->setId($i);
        push @executors, $executor;
    }
    $self->[GT_EXECUTORS] = \@executors;

    my $mixer = GenTest::Mixer->new(
        generator => $self->generator(),
        executors => \@executors,
        validators => $self->config->validators,
        properties =>  $self->config,
        filters => $self->queryFilters(),
        end_time => $self->[GT_TEST_END],
        restart_timeout => $self->config->property('restart-timeout'),
        variator_manager => $self->[GT_VARIATOR_MANAGER],
    );

    if (not defined $mixer) {
        sayError("GenTest failed to create a Mixer, status will be set to ENVIRONMENT_FAILURE");
        $self->stopChild(STATUS_ENVIRONMENT_FAILURE);
    }

    my $worker_result = 0;

    foreach my $i (1..$self->config->queries) {
        my $query_result = $mixer->next();
        $worker_result = $query_result if $query_result > $worker_result && $query_result > STATUS_TEST_FAILURE;

        if ($query_result > STATUS_CRITICAL_FAILURE) {
        say("GenTest: Server crash or critical failure (". status2text($query_result) . ") reported, the child will be stopped");
            undef $mixer;  # so that destructors are called
            $self->stopChild($query_result);
        }

        last if $query_result == STATUS_EOF;
#        last if $ctrl_c == 1;
        last if time() > $self->[GT_TEST_END];
    }

    foreach my $executor (@executors) {
        $executor->disconnect;
        undef $executor;
    }

    # Forcefully deallocate the Mixer so that Validator destructors are called
    undef $mixer;
    undef $self->[GT_QUERY_FILTERS];

    if ($worker_result > 0) {
        say("GenTest: Child worker process completed with error code $worker_result.");
        $self->stopChild($worker_result);
    } else {
        sayDebug("GenTest: Child worker process completed successfully.");
        $self->stopChild(STATUS_OK);
    }
}

# For several servers which will later participate in comparison,
# the initially generated data should be identical, otherwise no point
sub validateGenData {
  my $self = shift;

  return STATUS_OK if $self->config->property('multi-master');

  my @dsns= ();
  foreach my $i (@{$self->config->active_servers}) {
    push @dsns, $self->config->server_specific->{$i}->{dsn} if $self->config->server_specific->{$i}->{dsn};
  }
  return STATUS_OK if (scalar @dsns) <= 1;

  say("GenTest: Validating original datasets");
  my @exs= ();
  foreach my $dsn (@dsns) {
    my $e = GenTest::Executor->newFromDSN($dsn);
    $e->init();
    push @exs, $e;
  }
  my @dbs0= sort @{$exs[0]->metaSchemas(1)};
  foreach my $i (1..$#exs) {
    my @dbs= sort @{$exs[$i]->metaSchemas(1)};
    if ("@dbs0" ne "@dbs") {
      sayError("GenTest: Schemata mismatch after data generation between two servers (1 vs ".($i+1)."):\n\t@dbs0\n\t@dbs");
      return STATUS_CRITICAL_FAILURE;
    }
  }
  foreach my $db (@dbs0) {
    my @tbs0= sort @{$exs[0]->metaTables($db)};
    foreach my $i (1..$#exs) {
      my @tbs= sort @{$exs[1]->metaTables($db)};
      if ("@tbs0" ne "@tbs") {
        sayError("GenTest: Table list mismatch after data generation between two servers (1 vs ".($i+1)."):\n\t@tbs0\n\t@tbs");
        return STATUS_CRITICAL_FAILURE;
      }
    }
    # First, try to compare checksum, and only compare contents when checksums don't match
    my @checksum_mismatch= ();
    foreach my $t (@tbs0) {
      # Workaround for MDEV-22943 : don't run CHECKSUM on tables with virtual columns
      my $virt_cols= $exs[0]->dbh->selectrow_arrayref("SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='$db' AND TABLE_NAME='$t' AND IS_GENERATED='ALWAYS'");
      if ($exs[0]->dbh->err) {
        sayError("Check for virtual columns on server 1 for $db.$t ended with an error: ".($exs[0]->dbh->err)." ".($exs[0]->dbh->errstr));
        return STATUS_CRITICAL_FAILURE;
      } elsif ($virt_cols->[0] > 0) {
        sayDebug("Found ".($virt_cols->[0])." virtual columns on server 1 for $db.$t, skipping CHECKSUM");
        push @checksum_mismatch, $t;
        next;
      }
      my $cs0= $exs[0]->dbh->selectrow_arrayref("CHECKSUM TABLE $db.$t EXTENDED");
      if ($exs[0]->dbh->err) {
        sayError("CHECKSUM on server 1 for $db.$t ended with an error: ".($exs[0]->dbh->err)." ".($exs[0]->dbh->errstr));
        return STATUS_CRITICAL_FAILURE;
      }
      foreach my $i (1..$#exs) {
        my $cs= $exs[$i]->dbh->selectrow_arrayref("CHECKSUM TABLE $db.$t EXTENDED");
        if ($exs[$i]->dbh->err) {
          sayError("CHECKSUM on server ".($i+1)." for $db.$t ended with an error: ".($exs[$i]->dbh->err)." ".($exs[$i]->dbh->errstr));
          return STATUS_CRITICAL_FAILURE;
        }
        push @checksum_mismatch, $t if ($cs0->[1] ne $cs->[1]);
        sayDebug("Checksums for $db.$t: server 1: ".$cs0->[1].", server ".($i+1).": ".$cs->[1]);
      }
    }
    foreach my $t (@checksum_mismatch) {
      my $rs0= $exs[0]->execute("SELECT * FROM $db.$t");
      if ($exs[0]->dbh->err) {
        sayError("SELECT on server 1 from $db.$t ended with an error: ".($exs[0]->dbh->err)." ".($exs[0]->dbh->errstr));
        return STATUS_CRITICAL_FAILURE;
      }
      foreach my $i (1..$#exs) {
        my $rs= $exs[$i]->execute("SELECT * FROM $db.$t");
        if ($exs[$i]->dbh->err) {
          sayError("SELECT on server ".($i+1)." from $db.$t ended with an error: ".($exs[$i]->dbh->err)." ".($exs[$i]->dbh->errstr));
          return STATUS_CRITICAL_FAILURE;
        }
        if ( GenTest::Comparator::compare_as_unordered($rs0, $rs) != STATUS_OK ) {
          sayError("GenTest: Data mismatch after data generation between two servers (1 vs ".($i+1).") in table `$db`.`$t`");
          return STATUS_CONTENT_MISMATCH;
        }
      }
    }
  }
  say("GenTest: Original datasets are identical");
  return STATUS_OK;
}

sub initSeed {
    my $self = shift;

    return if not defined $self->config->seed();

    my $orig_seed = $self->config->seed();
    my $new_seed;

    if ($orig_seed eq 'time') {
        $new_seed = time();
    } elsif ($self->config->seed() eq 'epoch5') {
        $new_seed = time() % 100000;
    } elsif ($self->config->seed() eq 'random') {
        $new_seed = int(rand(32767));
    } else {
        $new_seed = $orig_seed;
    }

    if ($new_seed ne $orig_seed) {
        say("Converting --seed=$orig_seed to --seed=$new_seed");
        $self->config->property('seed', $new_seed);
    }
}

sub initGenerator {
    my $self = shift;

    my $generator_name = "GenTest::Generator::".$self->config->generator;
    say("Loading Generator $generator_name.") if rqg_debug();
    eval("use $generator_name");
    croak($@) if $@;

    if ($generator_name eq 'GenTest::Generator::FromGrammar') {
      if (not defined $self->config->grammars or (scalar(@{$self->config->grammars}) == 0)) {
          sayError("Grammar(s) not specified but Generator is $generator_name, status will be set to ENVIRONMENT_FAILURE");
          return STATUS_ENVIRONMENT_FAILURE;
      }
      my $redefining_grammar;
      foreach my $r (@{$self->config->redefines}) {
        my $rg= GenTest::Grammar->new(
          grammar_file => $r,
          compatibility => $self->config->compatibility
        );
        if (not defined $rg) {
          sayError("Could not initialize the redefining grammar from $r");
          return STATUS_ENVIRONMENT_FAILURE;
        }
        if ($rg->features && scalar @{$rg->features}) {
          $self->registerFeatures($rg->features);
        }
        if (defined $redefining_grammar) {
          $redefining_grammar->patch($rg)
        } else {
          $redefining_grammar= $rg;
        }
      }
      my @grammars= ();
      foreach my $g (@{$self->config->grammars}) {
        my $grammar= GenTest::Grammar->new(
                                  grammar_file => $g,
                                  redefine_files => $self->config->redefines,
                                  compatibility => $self->config->compatibility
                        );
        if (not defined $grammar) {
          sayError("Could not initialize the grammar from $g, status will be set to ENVIRONMENT_FAILURE");
          return STATUS_ENVIRONMENT_FAILURE;
        }
        $grammar->patch($redefining_grammar) if defined $redefining_grammar;
        if ($grammar->features && scalar @{$grammar->features}) {
          $self->registerFeatures($grammar->features);
        }
        push @grammars, $grammar;
      }
      $self->[GT_GRAMMARS]= [ @grammars ];
    }

    $self->[GT_GENERATOR] = $generator_name->new(
      grammars => $self->grammars(),
      annotate_rules => $self->config->property('annotate-rules'),
      parser => $self->config->parser,
      parser_mode => $self->config->parser_mode,
    );

    if (not defined $self->generator()) {
      sayError("Could not initialize the generator, status will be set to ENVIRONMENT_FAILURE");
      return STATUS_ENVIRONMENT_FAILURE;
    }
}

sub registerFeatures {
  my ($self, $features)= @_;
  my $dbh= DBI->connect($self->config->server_specific->{1}->{dsn});
  if ($dbh->err) {
    sayError("Could not connect to server ".$self->config->server_specific->{1}->{dsn}." to register features @{$features}: ".$dbh->err." ".$dbh->errstr);
    return;
  }
  $dbh->do("CREATE TABLE IF NOT EXISTS mysql.rqg_feature_registry (feature VARCHAR(64), PRIMARY KEY(feature))");
  if ($dbh->err) {
    sayError("Could not create mysql.rqg_feature_registry at ".$self->config->server_specific->{1}->{dsn}.": ".$dbh->err." ".$dbh->errstr);
    return;
  }
  my $feature_list= join ',', map { '("'.$_.'")' } (@$features);
  $dbh->do("REPLACE INTO mysql.rqg_feature_registry VALUES $feature_list");
  if ($dbh->err) {
    sayError("Could not register features @{$features} at".$self->config->server_specific->{1}->{dsn}.": ".$dbh->err." ".$dbh->errstr);
  }
  sayDebug("Registered features: @$features");
}

sub initReporters {
    my $self = shift;

    # Initialize the array to avoid further checks on its existence
    if (not defined $self->config->reporters or $#{$self->config->reporters} < 0) {
      $self->config->reporters([]);
    }

    # If reporters were set to None or empty string explicitly,
    # remove the "None" reporter and don't add any reporters automatically
    my $no_reporters= 0;
    foreach my $i (0..$#{$self->config->reporters}) {
        if ($self->config->reporters->[$i] eq "None"
            or $self->config->reporters->[$i] eq '')
        {
          delete $self->config->reporters->[$i];
          $no_reporters= 1;
        }
    }

    if (not $no_reporters) {
      $self->config->reporters(['ErrorLog', 'Backtrace']) unless scalar(@{$self->config->reporters});
      push @{$self->config->reporters}, 'ReplicationConsistency' if $self->config->rpl_mode and $self->config->rpl_mode !~ /nosync/;
      push @{$self->config->reporters}, 'ReplicationSlaveStatus'
          if $self->config->rpl_mode;
    }

    # Remove duplicates
    my %reps=();
    map { $reps{$_}= 1 } (@{$self->config->reporters});
    $self->config->reporters([ keys %reps ]);

    say("Reporters: ".($#{$self->config->reporters} > -1 ? join(', ', @{$self->config->reporters}) : "(none)"));

    my $reporter_manager = GenTest::ReporterManager->new();

    foreach my $i (@{$self->config->active_servers}) {
        next unless $self->config->server_specific->{$i}->{dsn};
        foreach my $reporter (@{$self->config->reporters}) {
            my $add_result = $reporter_manager->addReporter($reporter, {
                dsn => $self->config->server_specific->{$i}->{dsn},
                test_start => $self->[GT_TEST_START],
                test_end => $self->[GT_TEST_END],
                test_duration => $self->config->duration,
                properties => $self->config
            });

            return $add_result if $add_result > STATUS_OK;
        }
    }

    $self->[GT_REPORTER_MANAGER] = $reporter_manager;
    return STATUS_OK;
}

sub initValidators {
    my $self = shift;

    if (not defined $self->config->validators or $#{$self->config->validators} < 0) {
        $self->config->validators([]);

        # In case of multi-master topology (e.g. Galera with multiple "masters"),
        # we don't want to compare results after each query.

        push @{$self->config->validators}, 'MarkErrorLog'
            if (defined $self->config->valgrind);

        if ($self->grammars()) {
          foreach my $grammar (@{$self->grammars}) {
            push @{$self->config->validators}, 'QueryProperties' if $grammar->hasProperties();
          }
        }
    } else {
        ## Remove the "None" validator
        foreach my $i (0..$#{$self->config->validators}) {
            delete $self->config->validators->[$i]
                if $self->config->validators->[$i] eq "None"
                or $self->config->validators->[$i] eq '';
        }
    }

    ## Add the transformer validator if --transformers is specified
    ## and transformer validator not allready specified.

    if (defined $self->config->transformers and
        $#{$self->config->transformers} >= 0)
    {
        my $hasTransformer = 0;
        foreach my $t (@{$self->config->validators}) {
            if ($t =~ /^Transformer/) {
                $hasTransformer = 1;
                last;
            }
        }
        push @{$self->config->validators}, 'Transformer' if !$hasTransformer;
    }

    say("Validators: ".(defined $self->config->validators and $#{$self->config->validators} > -1 ? join(', ', @{$self->config->validators}) : "(none)"));

    say("Transformers: ".join(', ', @{$self->config->transformers}))
        if defined $self->config->transformers and $#{$self->config->transformers} > -1;

    return STATUS_OK;
}

1;

