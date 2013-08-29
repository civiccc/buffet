require 'benchmark'
require 'drb'
require 'thread'
require 'socket'

module Buffet
  class Master
    attr_reader :failures, :stats, :slave_exceptions

    def initialize project, slaves, specs, listener
      @project = project
      @slaves = slaves
      @stats = {:examples => 0, :failures => 0, :pending => 0}
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
      @specs = order_specs(specs)
      @listener = listener
      @halt_exception = nil
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

    def next_file_for slave_name
      file = @lock.synchronize { @specs.shift }
      if file
        slave = @slaves_stats[slave_name][:slave]
        @lock.synchronize { @slaves_stats[slave_name][:specs] << file }
        @listener.spec_taken slave, file if file
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
        slave.execute_in_project([
          Settings.worker_command,
          server_uri,
          slave.user_at_host,
          Settings.framework,
        ].join(' '))
      end.real

      @lock.synchronize { @slaves_stats[slave.name][:test_time] = time }

      @listener.slave_finished slave
    end
  end
end
