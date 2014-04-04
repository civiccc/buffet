require 'benchmark'
require 'drb'
require 'thread'
require 'socket'

module Buffet
  class Master
    attr_reader :failures, :stats, :slave_exceptions, :spurious_failures

    def initialize project, slaves, specs, listener
      @project = project
      @slaves = slaves
      @stats = { :examples => 0, :failures => 0, :pending => 0, :spurious_failures => 0 }
      @slaves_stats = Hash[@slaves.map do |slave|
        [slave.user_at_host, stats.dup.merge!(:slave => slave, :specs => [])]
      end]
      @slave_exceptions = {}
      @max_slave_prepare_failures = [Settings.allowed_slave_prepare_failures,
                                     @slaves.count - 1].min
      @stats[:slaves] = @slaves_stats
      @lock = Mutex.new
      @condition = ConditionVariable.new
      @failures = []
      @spurious_failures = []
      @specs = order_specs(specs)
      @listener = listener
      @halt_exception = nil

      # How many times a particular spec file was queued
      @spec_queue_count = Hash.new { |h, k| h[k] = 0 }

      # Need this so when we get back an example result from a slave we can know
      # which spec it is from. This prevents the wrong file from being reported
      # in the case of shared examples.
      @current_spec_for_slave = {}

      # Store spec results on per spec per line basis
      @spec_results = Hash.new { |h, k| h[k] = [] }
    end

    def order_specs(specs)
      specs.map do |spec|
        [`wc -l #{spec}`.to_i, spec]
      end.sort.reverse.map(&:last)
    end

    def run
      start_service

      @stats[:total_time] = Benchmark.measure do
        @threads = @slaves.map do |slave|
          Thread.new do
            run_worker slave
          end
        end

        wait_for_workers
      end.real

      stop_service

      process_spec_results
    end

    def run_worker slave
      time = Benchmark.measure do
        begin
          prepare_slave slave
        rescue CommandError => ex
          slave_prepare_failed slave, ex
        rescue Exception => ex
          stop_run ex
        else
          begin
            run_slave slave
          rescue Exception => ex
            stop_run ex
          end
        end
      end.real

      @lock.synchronize do
        @slaves_stats[slave.name][:total_time] = time
        @condition.signal # Tell master this slave is finished
      end
    end

    def wait_for_workers
      @threads.count.times do
        @lock.synchronize do
          @condition.wait(@lock)

          raise @halt_exception if @halt_exception

          if slave_exceptions.count > @max_slave_prepare_failures
            raise 'Exceeded maximum number of allowed slave prepare failures'
          end
        end
      end
    end

    def stop_run ex
      @lock.synchronize do
        @halt_exception = ex
        @condition.signal # Alert master
      end
    end

    def next_file_for(slave_name, previous_spec)
      file = nil

      @lock.synchronize do
        if rerun_spec?(previous_spec)
          @spec_queue_count[previous_spec] += 1
          return previous_spec
        else
          if file = @specs.shift
            @spec_queue_count[file] += 1
            @current_spec_for_slave[slave_name] = file

            @slaves_stats[slave_name][:specs] << file
          end
        end
      end

      if file
        slave = nil
        @lock.synchronize do
          slave = @slaves_stats[slave_name][:slave]
        end
        @listener.spec_taken(slave, file)
      end

      file
    end

    def slave_prepare_failed slave, ex
      @listener.slave_prepare_failed slave, ex

      @lock.synchronize do
        slave_exceptions[slave.name] = ex

        @condition.signal # Alert master this slave failed
      end
    end

    def example_passed(slave_name, details)
      @lock.synchronize do
        @spec_results[@current_spec_for_slave[slave_name]] << details
      end

      @listener.example_passed
    end

    def example_failed(slave_name, details)
      @lock.synchronize do
        @spec_results[@current_spec_for_slave[slave_name]] << details
      end

      @listener.example_failed
    end

    def example_pending slave_name, details
     @lock.synchronize do
       @stats[:examples] += 1
       @stats[:pending] += 1
       @slaves_stats[slave_name][:pending] += 1
     end

     @listener.example_pending
    end

  private

    def server_uri
      @drb_server.uri
    end

    def start_service
      @drb_server = DRb.start_service("druby://#{ip}:0", self)
    end

    def stop_service
      DRb.stop_service
    end

    def ip
      result = Buffet.run! 'host `hostname -s`'
      result.stdout.chomp.match(/((\d+\.){3}\d+)/)[1]
    end

    def prepare_slave slave
      time = Benchmark.measure do
        @project.sync_to slave

        if Settings.prepare_command?
          slave.execute_in_project [
            Buffet.environment_to_shell_string(Settings.execution_environment),
            Settings.prepare_command,
          ].join(' ')
        end

        # Copy support files so they can be run on the remote machine
        slave.scp File.dirname(__FILE__) + '/../../support',
                  @project.support_dir_on_slave, :recurse => true
      end.real
      @lock.synchronize { @slaves_stats[slave.name][:prepare_time] = time }

      @listener.slave_prepared slave
    end

    def run_slave slave
      time = Benchmark.measure do
        slave.execute_in_project [
          Buffet.environment_to_shell_string(Settings.execution_environment),
          Settings.worker_command,
          server_uri,
          slave.user_at_host,
        ].join(' ')
      end.real

      @lock.synchronize { @slaves_stats[slave.name][:test_time] = time }

      @listener.slave_finished slave
    end

    def rerun_spec?(spec)
      spec && example_failed_last_run?(spec) && unconfirmed_failures(spec) > 0 &&
        @spec_queue_count[spec] <= Settings.failure_threshold
    end

    def example_count(spec)
      @spec_results[spec].count / @spec_queue_count[spec]
    end

    def example_failed_last_run?(spec)
      (1..example_count(spec)).any? do |i|
        @spec_results[spec][-i][:status] == :failed
      end
    end

    def confirmed_failures(spec)
      failure_counts_for_spec(spec).count do |failure_count|
        failure_count >= Settings.failure_threshold
      end
    end

    def unconfirmed_failures(spec)
      failure_counts_for_spec(spec).count do |failure_count|
        (1...Settings.failure_threshold).member?(failure_count)
      end
    end

    # Returns an array of failure counts over all spec runs for each example
    def failure_counts_for_spec(spec)
      example_result_list = @spec_results[spec]
      example_count = example_count(spec)

      (0...example_count).map do |i|
        example_result_list.select.
                            with_index { |_, j| j % example_count == i }.
                            count { |example_result| example_result[:status] == :failed }
      end
    end

    def process_spec_results
      @spec_results.each do |spec, example_results|
        next if example_results.empty?  # Can legitimately happen when spec has no examples

        slave_name = example_results.last[:slave_name]

        spec_examples_count = example_count(spec)
        @stats[:examples] += spec_examples_count
        @slaves_stats[slave_name][:examples] += spec_examples_count

        confirmed_failures = confirmed_failures(spec)
        @stats[:failures] += confirmed_failures
        @slaves_stats[slave_name][:failures] += confirmed_failures
        @failures += confirmed_failure_results(spec)

        spurious_failures = unconfirmed_failures(spec)
        @stats[:spurious_failures] += spurious_failures
        @slaves_stats[slave_name][:spurious_failures] += spurious_failures
        @spurious_failures += spurious_failure_results(spec)
      end
    end

    def confirmed_failure_results(spec)
      failures = []

      example_count = example_count(spec)

      failure_counts_for_spec(spec).each_with_index do |count, index|
        if count >= Settings.failure_threshold
          # Find first failure for spec
          failures << @spec_results[spec].
            select.
            with_index { |_, i| i % example_count == index }.
            find { |example_result| example_result[:status] == :failed }
        end
      end

      failures
    end

    def spurious_failure_results(spec)
      spurious_failures = []

      example_count = example_count(spec)

      failure_counts_for_spec(spec).each_with_index do |count, index|
        if (1...Settings.failure_threshold).member?(count)
          # Find first failure for spec
          spurious_failures << @spec_results[spec].
            select.
            with_index { |_, i| i % example_count == index }.
            find { |example_result| example_result[:status] == :failed }
        end
      end

      spurious_failures
    end
  end
end
