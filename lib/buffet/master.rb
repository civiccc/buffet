require 'benchmark'
require 'drb'
require 'thread'
require 'socket'

module Buffet
  class Master
    attr_reader :failures, :stats

    def initialize project, slaves, specs, listener
      @project = project
      @slaves = slaves
      @stats = {:examples => 0, :failures => 0, :pending => 0}
      @slaves_stats = Hash[@slaves.map do |slave|
        [slave.user_at_host, stats.dup.merge!(:slave => slave)]
      end]
      @stats[:slaves] = @slaves_stats
      @lock = Mutex.new
      @failures = []
      @specs = specs.shuffle # Never have the same test distribution
      @listener = listener
    end

    def run
      start_service

      @stats[:total_time] = Benchmark.measure do
        threads = @slaves.map do |slave|
          Thread.new do
            time = Benchmark.measure do
              prepare_slave slave
              run_slave slave
            end.real
            @lock.synchronize { @slaves_stats[slave.name][:total_time] = time }
          end
        end

        threads.each { |t| t.join }
      end.real

      stop_service
    end

    def next_file_for slave_name
      file = @lock.synchronize { @specs.shift }
      if file
        slave = @slaves_stats[slave_name][:slave]
        @listener.spec_taken slave, file if file
      end
      file
    end

    def example_passed slave_name, details
      @lock.synchronize do
        @stats[:examples] += 1
        @slaves_stats[slave_name][:examples] += 1
      end

      @listener.example_passed
    end

    def example_failed slave_name, details
      @lock.synchronize do
        @stats[:examples] += 1
        @stats[:failures] += 1
        @slaves_stats[slave_name][:failures] += 1
        @failures << details
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

        if Settings.has_prepare_script?
          slave.execute_in_project "#{Settings.prepare_script} #{Buffet.user} #{@project.name}"
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
      slave.execute_in_project(
        ".buffet/buffet-worker #{server_uri} #{slave.user_at_host} #{Settings.framework}")
      end.real
      @lock.synchronize { @slaves_stats[slave.name][:test_time] = time }

      @listener.slave_finished slave
    end
  end
end
