#!/usr/bin/env ruby

require 'drb'
require 'thread'
require 'socket'
require 'memoize'

module Buffet
  # The Buffet::Master class runs worker.rb on all of the host machines 
  # (including itself), and then distributes the tests to the workers.
  # The workers request more tests after they finish their current tests.
  class Master 
    extend Memoize

    # This will initialize the server.
    def initialize(working_dir, hosts) 
      @ip = Socket.gethostname.split('.').first # For druby
      @port = 8990 # For druby
      @hosts = hosts # All host machines
      @stats = {:examples => 0, :failure_count => 0} # Failures and total test #.
      @lock = Mutex.new # Lock objects touched by several threads to avoid race.
      @failure_list = [] # Details of the failure we have.
      @working_dir = working_dir # Directory we clone and run tests in.

      Dir.chdir(@working_dir) do
        @files = Dir["spec/**/*_spec.rb"].sort #This is specific to rspec.
      end
    end

    def next_file
      @lock.synchronize do
        @files_to_run.shift
      end
    end

    # These two methods are called on passes and fails, respectively.

    def example_passed(location)
      @lock.synchronize do
        @stats[:examples] += 1
      end
    end

    def example_failed(location, header, message, backtrace)
      @lock.synchronize do
        @stats[:examples] += 1
        @stats[:failure_count] += 1

        #TODO: This is lame. Need to find out why backtraces are being stifled.
        backtrace ||= "No backtrace found."

        @failure_list.push({:location => location, :header => header, :backtrace => backtrace.to_s})
      end
    end

    def server_addr
      "druby://#{@ip}:#{@port}"
    end

    def start_service
      @drb_thread = Thread.new do
        DRb.start_service("druby://0.0.0.0:#{@port}", self)
        DRb.thread.join
      end
    end

    def stop_service
      DRb.stop_service
      @drb_thread.join
    end

    # This is RSpec specific.
    def num_tests
      #TODO: maybe specify
      `grep -r "  it" #{@working_dir}/spec/ | wc`.to_i
    end

    memoize :num_tests

    # This will start distributing specs. It blocks until the tests are complete.
    #
    # It is necessary to have both initialize and start because otherwise it 
    # would be impossible to asynchronously check status. Say you had
    # server = Buffet::Master.new (...) and wanted to go server.get_updates in 
    # a separate thread. server does not actually get assigned until .new 
    # completes, which is after when you want to check status.
    #
    # The only way around this is to have two methods.

    def run
      Dir.chdir(@working_dir) do
        @files_to_run = @files.dup

        start_service
        @start_time = Time.now

        # Run worker on every host.
        threads = @hosts.map do |host|
          Thread.new do
            #TODO: Print an error if this fails
            #TODO: Maybe eventually pull these dirs out of settings.yml
            results = `ssh buffet@#{host} 'cd ~/buffet/working-directory; RAILS_ENV=test bundle exec ruby ~/buffet/lib/buffet/worker #{server_addr}'`
          end
        end

        threads.each do |t|
          t.join
        end
        @end_time = Time.now
        stop_service
      end

      results = ""
      @stats.each do |key, value|
        results += "#{key}: #{value}\n"
      end

      results += "\n"
      mins, secs = (@end_time - @start_time).divmod(60)
      results += "ran in %d mins %d secs\n" % [mins, secs]
      results
    end

    def get_current_stats
      @stats
    end

    def get_failures_list
      @failure_list
    end
  end
end
