#!/usr/bin/perl

# Copyright (c) 2008,2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2016, 2023, MariaDB
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
use Constants;
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
use Connection::Perl;

use constant TR_CONFIG => 0;
use constant TR_CHANNEL => 5;

use constant TR_GRAMMARS => 6;
use constant TR_GENERATOR => 7;
use constant TR_REPORTER_MANAGER => 8;
use constant TR_TEST_START => 9;
use constant TR_TEST_END => 10;
use constant TR_QUERY_FILTERS => 11;
use constant TR_EXECUTORS => 12;

# In seconds
use constant TR_META_RELOAD_INTERVAL => 20;

sub new {
    my $class = shift;

    my $self = $class->SUPER::new({
        'config' => TR_CONFIG},@_);

    croak ("Need config") if not defined $self->config;
    my $init_generator_result = $self->initGenerator();
    return $init_generator_result if $init_generator_result != STATUS_OK;
    return $self;
}

sub config {
    return $_[0]->[TR_CONFIG];
}

sub grammars {
    return $_[0]->[TR_GRAMMARS];
}

sub generator {
    return $_[0]->[TR_GENERATOR];
}

sub channel {
    return $_[0]->[TR_CHANNEL];
}

sub reporterManager {
    return $_[0]->[TR_REPORTER_MANAGER];
}

sub queryFilters {
    return $_[0]->[TR_QUERY_FILTERS];
}

sub run {
    my $self = shift;

    my $total_status = STATUS_OK;

    $SIG{TERM} = sub { exit(0) };
    $SIG{CHLD} = "IGNORE" if osWindows();

    $self->initSeed();

    say("-------------------------------\nConfiguration");
    $self->config->printProps;

    $self->[TR_CHANNEL] = GenTest::IPC::Channel->new();

    $self->[TR_TEST_START] = time();
    $self->[TR_TEST_END] = $self->[TR_TEST_START] + $self->config->duration;

#    my $init_reporters_result = $self->initReporters();
#    return $init_reporters_result if $init_reporters_result != STATUS_OK;

    my $init_validators_result = $self->initValidators();
    return $init_validators_result if $init_validators_result != STATUS_OK;

    if (scalar(@{$self->config->filters})) {
        my @filters= ();
        foreach my $f (@{$self->config->filters}) {
            push @filters, GenTest::Filter::Regexp->new(file => $f);
        }
        $self->[TR_QUERY_FILTERS]= \@filters;
    }

    say("Starting ".$self->config->threads." processes, ".
        $self->config->queries." queries each, duration ".
        $self->config->duration." seconds.");

    ### Start central reporting thread ####

#    my $errorfilter = GenTest::ErrorFilter->new(channel => $self->channel());
#    my $errorfilter_p = GenTest::IPC::Process->new(object => $errorfilter);
#    if (!osWindows()) {
#        $errorfilter_p->start($self->config->servers);
#    }

    ### Dump metadata before starting the working processes ###
    #
    # There are three stages of metadata dump/load
    # 1. TestRunner triggers the dump before executors are started
    #    (gendata has already been run or isn't going to be).
    #    It's done synchronously. The server will produce the dump files
    #    and then executors will load the metadata upon initialization
    # 2. After executing the rule 0 (init rules) each executor will stop
    #    and wait till the metadata is dumped again. When all executors
    #    reach this stage, TestRunner will again trigger the dump
    #    and when it is finished, will let the executors continue.
    # 3. After that, TestRunner will start a background process which
    #    will be dumping the data periodically, and executors are supposed
    #    to pick it up automatically

    # TODO: for now, always the 1st server will be used as a metadata source.
    #       Further scenarios should be able to indicate which one to use.

    # Stage 1 -- initial data collection
    
    my $metadata_res= $self->config->server_specific->{1}->{server}->storeMetaData("all",my $maxtime=$self->[TR_TEST_END]-time());
    unless ($metadata_res == STATUS_OK) {
      sayError("Initial metadata dump failed, cannot continue");
      $total_status= STATUS_CRITICAL_FAILURE if $total_status < STATUS_CRITICAL_FAILURE;
      goto TESTEND;
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

    # Stage 2 -- data collection after init rules
    # each executor will create a flag after executing the first rule.
    # The dumper will be waiting for all flags to be created
    # We are dumping both non-system and system schemas, because init
    # could install plugins etc.
    $metadata_res= $self->config->server_specific->{1}->{server}->storeMetaData("schemata", my $maxtime=$self->[TR_TEST_END]-time(), my $waiters=$self->config->threads);
    unless ($metadata_res == STATUS_OK) {
      sayError("Metadata dump after the 1st rule failed, terminating the test");
      $total_status= STATUS_CRITICAL_FAILURE if $total_status < STATUS_CRITICAL_FAILURE;
      goto OUTER;
    }

    # Now the executors are re-caching the data asynchronously, while
    # Stage 3 starts -- a periodic dumper is created. It will be dumping
    # only non-system schemata
    # (unless the test is configured not to do it)

    my $metadata_pid;
    if ($self->config->metadata_reload) {
      $metadata_pid= $self->metadataDumper();
      $worker_pids{$metadata_pid}= 1;
    }

    ### Main process

#    if (osWindows()) {
#        ## Important that this is done here in the parent after the last
#        ## fork since on windows Process.pm uses threads
#        $errorfilter_p->start();
#    }

    # We are the parent process, wait for for all spawned processes to terminate
    my $reporter_status = STATUS_OK;

    ## Parent thread does not use channel
    $self->channel()->close;

    OUTER: while (1) {
        # Remaining Worker & Reporter processes that were spawned and haven't ended yet.
        my @spawned_pids = (keys %worker_pids);

        # Wait for processes to complete, i.e only processes spawned by workers & reporters.
        foreach my $spawned_pid (@spawned_pids) {
            my $processtype= ($spawned_pid == $metadata_pid ? "metadata" : "worker");
            my $child_pid = waitpid($spawned_pid, WNOHANG);
            next if $child_pid == 0;
            my $child_exit_status = $? > 0 ? ($? >> 8) : 0;

            $total_status = $child_exit_status if $child_exit_status > $total_status;

            if ($child_pid == -1) {
                say("Process with pid $spawned_pid ($processtype) no longer exists");
                last OUTER;
            } else {
                sayDebug("Process with pid $child_pid ($processtype) ended with status ".status2text($child_exit_status));
                delete $worker_pids{$child_pid};
            }

            last OUTER if $child_exit_status >= STATUS_CRITICAL_FAILURE;
            last OUTER if keys %worker_pids == 0;
        }
        $reporter_status = $self->reporterManager()->monitor(REPORTER_TYPE_PERIODIC);
        $total_status= $reporter_status if $reporter_status > $total_status;
        if ($reporter_status >= STATUS_CRITICAL_FAILURE) {
          sayError("Reporters returned a critical failure, aborting");
          last;
        } elsif ($reporter_status == STATUS_TEST_STOPPED) {
          say("Reporters indicated that the test has been stopped");
          last;
        }
        sleep 10;
    }

  WORKEND:
    # Doing it in two loops is faster than sleeping for each pid separately
    if (scalar(keys %worker_pids)) {
      foreach my $worker_pid (keys %worker_pids) {
          my $processtype= ($worker_pid == $metadata_pid ? "metadata" : "worker");
          say("Stopping remaining $processtype process with pid $worker_pid...");
          kill(15, $worker_pid);
      }
      sleep 1;
      foreach my $worker_pid (keys %worker_pids) {
          if (kill(0, $worker_pid)) {
            my $processtype= ($worker_pid == $metadata_pid ? "metadata" : "worker");
            say("Killing remaining $processtype process with pid $worker_pid...");
            kill(9, $worker_pid);
          }
      }
    }

  TESTEND:
#    $errorfilter_p->kill();

#    my $gentest_result= $self->reportResults($total_status);
    my $gentest_result= $total_status;
    sayDebug("TestRunner will exit with exit status ".status2text($gentest_result)." ($gentest_result)");
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
    } elsif ($total_status == STATUS_SERVER_CRASHED || $total_status == STATUS_SERVER_UNAVAILABLE) {
        say("Server crash may have occurred, initiating post-crash analysis...");
        @report_results = $reporter_manager->report(REPORTER_TYPE_CRASH | REPORTER_TYPE_ALWAYS);
    } elsif ($total_status == STATUS_SERVER_DEADLOCKED) {
        say("Server deadlock reported, initiating analysis...");
        @report_results = $reporter_manager->report(REPORTER_TYPE_DEADLOCK | REPORTER_TYPE_ALWAYS | REPORTER_TYPE_END);
    } elsif ($total_status == STATUS_SERVER_STOPPED) {
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

    sayDebug("TestRunner: child $$ is being stopped with status " . status2text($status));
    # Stopping executors explicitly to hopefully trigger statistics output
    foreach my $executor (@{$self->[TR_EXECUTORS]}) {
      undef $executor if $executor;
    }
    croak "calling stopChild() for $$ without a \$status" if not defined $status;
    if (osWindows()) {
        exit $status;
    } else {
        safe_exit($status);
    }
}

sub metadataDumper {
  my $self= shift;
  my $metadata_pid= fork();
  return $metadata_pid if ($metadata_pid != 0);

  # We don't want to sleep the whole interval, it may be too long
  # at the end of the test
  my $wait= TR_META_RELOAD_INTERVAL;
  # We will be reloading system data too, but not as often, only
  # every $wait_cycles of non-system data reload
  my $wait_cycles= 10;
  # No point reloading in the last seconds
  while (time() < $self->[TR_TEST_END] - int(TR_META_RELOAD_INTERVAL/10)) {
    if ($wait == 0) {
      $self->config->server_specific->{1}->{server}->storeMetaData("nonsystem", my $maxtime=$self->[TR_TEST_END]-time());
      $wait= TR_META_RELOAD_INTERVAL;
      $wait_cycles--;
      if ($wait_cycles == 0) {
        $self->config->server_specific->{1}->{server}->storeMetaData("system", my $maxtime=$self->[TR_TEST_END]-time());
        $wait_cycles= 10;
      }
    }
    sleep 1;
    $wait--;
  }
  $self->stopChild(STATUS_OK);
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
    foreach my $i (sort { $a <=> $b } keys %{$self->config->server_specific}) {
      my $so= $self->config->server_specific->{$i};
      next unless $so->{active};
        my $executor = GenTest::Executor->newFromServer(
          $so->{server},
          channel => (osWindows() ? undef : $self->channel()),
          id => $i,
          thread_id => $worker_id,
          sqltrace => $self->config->sqltrace,
          vardir => $self->config->vardir,
        );
        push @executors, $executor;
    }
    # Cache the original data (generated by gendata)
    $executors[0]->cacheMetaData();
    $self->[TR_EXECUTORS] = \@executors;

    my $mixer = GenTest::Mixer->new(
        generator => $self->generator(),
        executors => \@executors,
        validators => $self->config->validators,
        properties =>  $self->config,
        filters => $self->queryFilters(),
        end_time => $self->[TR_TEST_END],
    );

    if (not defined $mixer) {
        sayError("GenTest failed to create a Mixer, status will be set to ENVIRONMENT_FAILURE");
        $self->stopChild(STATUS_ENVIRONMENT_FAILURE);
    }

    # Cache metadata before the first rule (after gendata if it was configured)
    $executors[0]->cacheMetaData();

    # Execute the very first query (e.g. init rules)
    my $worker_result = $mixer->next();
    if ($worker_result >= STATUS_CRITICAL_FAILURE) {
      sayError("A critical failure (". status2text($worker_result) . ") occurred upon executing the first query");
      undef $mixer;
      $self->stopChild($worker_result);
    } elsif ($worker_result < STATUS_TEST_FAILURE) {
      $worker_result= STATUS_OK;
    }

    # If there was no critical failures, we are letting the dumper know
    # that we are ready for data reload
    open(FLAG,'>'.$self->config->server_specific->{1}->{server}->vardir.'/executor_'.$$.'_ready') && close(FLAG) || sayError("Could not create a waiting flag");
    while (-e $self->config->server_specific->{1}->{server}->vardir.'/executor_'.$$.'_ready') {
      sayDebug("Waiting for a new metadata dump after the first rule");
      sleep 1;
    }
    $executors[0]->cacheMetaData();
    my $last_metadata_reload= time();
    foreach my $i (1..$self->config->queries) {
        my $query_result = $mixer->next();
        $worker_result = $query_result if $query_result > $worker_result && $query_result > STATUS_TEST_FAILURE;

        if ($query_result >= STATUS_CRITICAL_FAILURE) {
        say("TestRunner: Server crash or critical failure (". status2text($query_result) . ") reported, the child will be stopped");
            undef $mixer;  # so that destructors are called
            $self->stopChild($query_result);
        }

        last if $query_result == STATUS_TEST_STOPPED;
#        last if $ctrl_c == 1;
        last if time() > $self->[TR_TEST_END];
        if ($self->config->metadata_reload && time() > $last_metadata_reload + int(TR_META_RELOAD_INTERVAL/2*3)) {
          $executors[0]->cacheMetaData();
          $last_metadata_reload= time();
        }
    }

    foreach my $executor (@executors) {
        $executor->disconnect;
        undef $executor;
    }

    # Forcefully deallocate the Mixer so that Validator destructors are called
    undef $mixer;
    undef $self->[TR_QUERY_FILTERS];

    if ($worker_result > 0) {
        say("TestRunner: Child worker process completed with error code ".status2text($worker_result)." ($worker_result)");
        $self->stopChild($worker_result);
    } else {
        sayDebug("TestRunner: Child worker process completed successfully.");
        $self->stopChild(STATUS_OK);
    }
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
    sayDebug("Loading Generator $generator_name.");
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
          compatibility => $self->config->compatibility,
          compatibility_es => $self->config->compatibility_es
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
                                  compatibility => $self->config->compatibility,
                                  compatibility_es => $self->config->compatibility_es
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
      $self->[TR_GRAMMARS]= [ @grammars ];
    }

    $self->[TR_GENERATOR] = $generator_name->new(
      compatibility => $self->config->compatibility,
      grammars => $self->grammars(),
      annotate_rules => $self->config->property('annotate-rules'),
      parser => $self->config->parser,
      parser_mode => $self->config->parser_mode,
      variators => $self->config->variators,
    );

    if (not defined $self->generator()) {
      sayError("Could not initialize the generator, status will be set to ENVIRONMENT_FAILURE");
      return STATUS_ENVIRONMENT_FAILURE;
    }
}

sub registerFeatures {
  my ($self, $features)= @_;
  my ($conn, $err)= Connection::Perl->new( server => $self->config->server_specific->{1}->{server}, role => 'super', name => 'FTR' );
  unless ($conn) {
    sayError("Could not connect to server to register features @{$features}, error $err");
    return;
  }
  $conn->execute("SET tx_read_only= 0, autocommit= 1");
  if ($conn->execute("SET STATEMENT enforce_storage_engine=NULL FOR CREATE TABLE IF NOT EXISTS mysql.rqg_feature_registry (feature VARCHAR(64), PRIMARY KEY(feature)) ENGINE=Aria") != STATUS_OK) {
    sayError("Could not create mysql.rqg_feature_registry: ".$conn->print_error);
    return;
  }
  my $feature_list= join ',', map { "('$_')" } (@$features);
  if ($conn->execute("REPLACE INTO mysql.rqg_feature_registry VALUES $feature_list") != STATUS_OK) {
    sayError("Could not register features @{$features}: ".$conn->print_error);
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

    # Remove duplicates
    my %reps=();
    map { $reps{$_}= 1 } (@{$self->config->reporters});
    $self->config->reporters([ keys %reps ]);

    say("Reporters: ".($#{$self->config->reporters} > -1 ? join(', ', @{$self->config->reporters}) : "(none)"));

    my $reporter_manager = GenTest::ReporterManager->new();

    foreach my $i (sort { $a <=> $b } keys %{$self->config->server_specific}) {
      my $so= $self->config->server_specific->{$i};
      next unless $so->{active};
        foreach my $reporter (@{$self->config->reporters}) {
            my $add_result = $reporter_manager->addReporter($reporter, {
                server => $so->{server},
                test_start => ( $self->[TR_TEST_START] || time ),
                test_end => ( $self->[TR_TEST_END] || ($self->[TR_TEST_START] + $self->config->duration) ),
                test_duration => $self->config->duration,
                properties => $self->config,
            });

            return $add_result if $add_result > STATUS_OK;
        }
    }

    $self->[TR_REPORTER_MANAGER] = $reporter_manager;
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

